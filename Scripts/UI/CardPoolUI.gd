extends Control
class_name CardPoolUI

signal card_clicked(card: CardInfo)
signal card_double_clicked(card: CardInfo, slot_index: int)
signal card_dragged(card: CardInfo, from_slot: int)

@export var pool_name: String = "card_pool"
@export var columns: int = 8
@export var rows: int = 2

var slot_count: int = 16  # 8×2 固定
var slots: Array[CardSlotUI] = []
var _btn_free: Button = null
var _btn_gold: Button = null
var _btn_gem: Button = null
var _free_cooldown: Control = null
var _gold_cooldown: Control = null
var _gem_cooldown: Control = null
var _free_cost_label: Label = null
var _gold_cost_label: Label = null
var _gem_cost_label: Label = null
var _free_countdown_label: Label = null
var _is_refreshing: bool = false
var auto_warm_enabled: bool = true
var _roll_ensure_elapsed: float = 0.0
var _draw_reveal_tweens: Array[Tween] = []
var _draw_reveal_generation: int = 0
var _refresh_column: Control = null
var _side_button_width: float = 110.0
var _side_button_height: float = 36.0

const DRAW_DROP_STAGGER_PER_CARD: float = 0.0625
const RAPID_DRAW_DROP_STAGGER_PER_CARD: float = 0.0125
const WHITE_DRAW_REVEAL_INTERVAL: float = 0.15
const ROLL_ENSURE_INTERVAL_SECONDS: float = 10.0
const SLOT_SPACING: float = 8.0
const BUTTON_LABEL_HEIGHT: float = 18.0
const ACTION_LABEL_GAP: float = 6.0
const AssetActionCooldownScript = preload("res://Scripts/UI/AssetActionCooldown.gd")
const CCRVisualStyle = preload("res://Scripts/UI/CCRVisualStyle.gd")

func configure_side_button_metrics(button_width: float, button_height: float) -> void:
	_side_button_width = maxf(70.0, button_width)
	_side_button_height = maxf(28.0, button_height)
	if is_node_ready():
		_apply_refresh_column_layout()

func _ready() -> void:
	setup_ui()
	# 先读取已有数据（解决竞态：信号发出后才创建本控件）
	if CardPoolSystem.current_pool.size() > 0:
		_refresh_display(CardPoolSystem.current_pool)
	# 再连接信号，保证后续更新也能收到
	CardPoolSystem.pool_updated.connect(_on_pool_updated)
	CardPoolSystem.refresh_failed.connect(_on_refresh_failed)
	CardPoolSystem.loading_started.connect(_on_refresh_loading_started)
	CardPoolSystem.loading_completed.connect(_on_refresh_loading_completed)
	GameManager.free_refresh_cooldown_updated.connect(_on_free_refresh_cooldown_updated)
	GameManager.free_refresh_ready.connect(_on_free_refresh_ready)
	GameManager.player_data.changed.connect(_on_player_data_changed)

	# 监听拖拽结束 → 刷新 UI
	if DragSystem != null:
		DragSystem.drag_ended.connect(_on_drag_ended)
		DragSystem.drag_cancelled.connect(_on_drag_cancelled)

	# 页面建立后立即准备下一条 roll，并周期性补偿网络失败；不再依赖鼠标悬浮。
	set_process(true)
	_auto_warm_next_refresh_roll.call_deferred()

func _process(delta: float) -> void:
	_roll_ensure_elapsed += delta
	if _roll_ensure_elapsed < ROLL_ENSURE_INTERVAL_SECONDS:
		return
	_roll_ensure_elapsed = 0.0
	_auto_warm_next_refresh_roll()


func _exit_tree() -> void:
	_cancel_scheduled_draw_reveals()

func setup_ui() -> void:
	# ── 卡槽网格（8×2 = 16 固定） ──
	_create_slot_grid()

	# ── 右侧刷新按钮列（垂直居中） ──
	_create_refresh_column()

func _create_slot_grid() -> void:
	var slot_size = CardSlotUI.SLOT_SIZE
	var start_x = _centered_grid_start_x()
	var start_y = 0

	for i in range(slot_count):
		var row = i / columns
		var col = i % columns
		var x = start_x + col * (slot_size.x + SLOT_SPACING)
		var y = start_y + row * (slot_size.y + SLOT_SPACING)

		var slot = CardSlotUI.new()
		slot.slot_index = i
		slot.position = Vector2(x, y)
		slot.area_type = "pool"
		slot.slot_clicked.connect(_on_slot_clicked)
		slot.slot_double_clicked.connect(_on_slot_double_clicked)
		slot.card_dropped.connect(_on_card_dropped)
		slot.slot_unlock_requested.connect(func(idx: int): GameManager.handle_unlock_slot("pool", idx))
		slots.append(slot)
		add_child(slot)


func _grid_width() -> float:
	return columns * CardSlotUI.SLOT_SIZE.x + (columns - 1) * SLOT_SPACING


func _centered_grid_start_x() -> float:
	var viewport_width := get_viewport_rect().size.x
	var centered_global_left := maxf(0.0, (viewport_width - _grid_width()) * 0.5)
	var parent_global_x := global_position.x if is_inside_tree() else 0.0
	return maxf(0.0, centered_global_left - parent_global_x)

func _create_refresh_column() -> void:
	_refresh_column = Control.new()
	_refresh_column.name = "CardPoolRefreshColumn"
	_refresh_column.set_anchors_preset(Control.PRESET_TOP_LEFT)
	add_child(_refresh_column)

	_btn_free = Button.new()
	_btn_free.name = "DrawStaminaButton"
	_btn_free.pressed.connect(_on_free_refresh)
	_btn_free.mouse_entered.connect(_on_free_refresh_hovered)
	CCRVisualStyle.apply_relic_button(_btn_free, "draw_stamina")
	_refresh_column.add_child(_btn_free)
	_free_cooldown = _attach_action_cooldown(_btn_free)

	_free_cost_label = _create_refresh_cost_label()
	_refresh_column.add_child(_free_cost_label)

	_btn_gold = Button.new()
	_btn_gold.name = "DrawGoldButton"
	_btn_gold.text = Localization.t("ui.card_pool.refresh.gold")
	_btn_gold.pressed.connect(_on_gold_refresh)
	_btn_gold.mouse_entered.connect(_on_gold_refresh_hovered)
	CCRVisualStyle.apply_relic_button(_btn_gold, "draw_gold")
	_refresh_column.add_child(_btn_gold)
	_gold_cooldown = _attach_action_cooldown(_btn_gold)

	_gold_cost_label = _create_refresh_cost_label()
	_refresh_column.add_child(_gold_cost_label)

	_btn_gem = Button.new()
	_btn_gem.name = "DrawGemButton"
	_btn_gem.text = Localization.t("ui.card_pool.refresh.gem")
	_btn_gem.pressed.connect(_on_gem_refresh)
	_btn_gem.mouse_entered.connect(_on_gem_refresh_hovered)
	CCRVisualStyle.apply_relic_button(_btn_gem, "draw_gem")
	_refresh_column.add_child(_btn_gem)
	_gem_cooldown = _attach_action_cooldown(_btn_gem)

	_gem_cost_label = _create_refresh_cost_label()
	_refresh_column.add_child(_gem_cost_label)

	_free_countdown_label = Label.new()
	_free_countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_free_countdown_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_free_countdown_label.add_theme_font_size_override("font_size", 11)
	_free_countdown_label.add_theme_color_override("font_color", Color(0.75, 0.85, 1.0, 0.9))
	_refresh_column.add_child(_free_countdown_label)
	_apply_refresh_column_layout()
	_update_refresh_buttons()

func _create_refresh_cost_label() -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color(0.88, 0.92, 1.0, 0.92))
	return label

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_node_ready():
		_apply_refresh_column_layout()

func _apply_refresh_column_layout() -> void:
	if _refresh_column == null:
		return
	var button_size := Vector2(_side_button_width, _side_button_height)
	for button in [_btn_free, _btn_gold, _btn_gem]:
		var typed_button := button as Button
		if typed_button != null:
			typed_button.custom_minimum_size = button_size
			typed_button.size = button_size
			# 体力、金币、宝石统一按导航按钮的 2/3 高度显示；右侧按钮高为导航按钮的 4/3。
			CCRVisualStyle.configure_relic_button_metrics(typed_button, _side_button_height, 0.5)
			typed_button.add_theme_font_size_override("font_size", _action_font_size())
	for label in [_free_cost_label, _gold_cost_label, _gem_cost_label]:
		var typed_label := label as Label
		if typed_label != null:
			typed_label.custom_minimum_size = Vector2(_side_button_width, BUTTON_LABEL_HEIGHT)
			typed_label.size = Vector2(_side_button_width, BUTTON_LABEL_HEIGHT)
	if _free_countdown_label != null:
		_free_countdown_label.custom_minimum_size = Vector2(_side_button_width, maxf(26.0, _side_button_height * 0.70))
		_free_countdown_label.size = _free_countdown_label.custom_minimum_size
	# 三种抽卡按钮分别对齐第一行中心、两行中线和第二行中心。
	# 这样体力/宝石抽卡会直接对应玩家正在查看的两排卡牌。
	var first_row_center_y := CardSlotUI.SLOT_SIZE.y * 0.5
	var second_row_center_y := CardSlotUI.SLOT_SIZE.y + SLOT_SPACING + CardSlotUI.SLOT_SIZE.y * 0.5
	var gold_center_y := (first_row_center_y + second_row_center_y) * 0.5
	var button_centers := [first_row_center_y, gold_center_y, second_row_center_y]
	var buttons := [_btn_free, _btn_gold, _btn_gem]
	var cost_labels := [_free_cost_label, _gold_cost_label, _gem_cost_label]
	for index in range(buttons.size()):
		var button := buttons[index] as Button
		var cost_label := cost_labels[index] as Label
		if button != null:
			button.position = Vector2.ZERO + Vector2(0.0, float(button_centers[index]) - _side_button_height * 0.5)
		if cost_label != null and button != null:
			cost_label.position = Vector2(0.0, button.position.y + _side_button_height)
	if _free_countdown_label != null:
		_free_countdown_label.position = Vector2(0.0, _btn_gem.position.y + _side_button_height + BUTTON_LABEL_HEIGHT)
	var content_height := size.y
	if _free_countdown_label != null:
		content_height = maxf(content_height, _free_countdown_label.position.y + _free_countdown_label.size.y)
	_refresh_column.size = Vector2(_side_button_width, content_height)
	_refresh_column.position = Vector2(_right_region_center_x() - _side_button_width * 0.5, 0.0)

func _action_font_size() -> int:
	if _side_button_width < 120.0:
		return 12 if Localization.locale == "en" else 13
	return 15 if Localization.locale == "en" else 16

func _right_region_center_x() -> float:
	var viewport_width := get_viewport_rect().size.x
	var grid_right := _centered_grid_start_x() + _grid_width()
	var global_center := (grid_right + viewport_width) * 0.5
	var parent_global_x := global_position.x if is_inside_tree() else 0.0
	return global_center - parent_global_x

func _grid_height() -> float:
	return rows * CardSlotUI.SLOT_SIZE.y + (rows - 1) * SLOT_SPACING

func controller_refresh(refresh_type: String) -> void:
	match refresh_type:
		"free":
			_on_free_refresh()
		"gem":
			_on_gem_refresh()
		"gold":
			_on_gold_refresh()

# ── 刷新回调 ──
func _on_free_refresh() -> void:
	if _is_refreshing:
		return
	if not _try_start_refresh_cooldown(_free_cooldown):
		return
	CardPoolSystem.request_refresh("free")
	_update_refresh_buttons()

func _on_gem_refresh() -> void:
	if _is_refreshing:
		return
	if not _try_start_refresh_cooldown(_gem_cooldown):
		return
	CardPoolSystem.request_refresh("gem")
	_update_refresh_buttons()

func _on_gold_refresh() -> void:
	if _is_refreshing:
		return
	if not _try_start_refresh_cooldown(_gold_cooldown):
		return
	var step_started := Time.get_ticks_msec()
	var total_started := step_started
	var gold_before := GameManager.player_data.gold
	var cost := maxi(1, int(gold_before * 0.01))
	var buffered := CardPoolSystem.has_pending_confirm() or ApiClient.has_pending_asset_requests()
	CardPoolSystem.gold_draw_debug_click_started_msec = total_started
	if CardPoolSystem.request_refresh("gold"):
		_print_gold_draw_step(
			1,
			"done",
			"缓冲下一次金币抽卡" if buffered else "本地金币扣费检查",
			step_started,
			total_started,
			{
				"buffered": buffered,
				"cost": cost,
				"gold_before": gold_before,
				"gold_after": GameManager.player_data.gold,
			}
		)
	else:
		_print_gold_draw_step(
			1,
			"failed",
			"本地金币扣费检查",
			step_started,
			total_started,
			{"cost": cost, "gold_before": gold_before}
		)
		CardPoolSystem.gold_draw_debug_click_started_msec = 0
	_update_refresh_buttons()

func _print_gold_draw_step(step: int, status: String, name: String, step_started: int, total_started: int, details: Dictionary = {}) -> void:
	var now := Time.get_ticks_msec()
	var parts: Array[String] = [
		"gold-draw step %d: %s" % [step, status],
		name,
		"step_ms=%d" % (now - step_started),
		"total_ms=%d" % (now - total_started),
	]
	var keys := details.keys()
	keys.sort()
	for key in keys:
		parts.append("%s=%s" % [str(key), str(details[key])])
	print(" | ".join(parts))

func _on_free_refresh_hovered() -> void:
	if not _is_refreshing and GameManager.get_free_refresh_remaining() > 0:
		CardPoolSystem.warm_refresh_roll("free")

func _on_gem_refresh_hovered() -> void:
	if not _is_refreshing and GameManager.player_data.gems >= 5:
		CardPoolSystem.warm_refresh_roll("gem")

func _on_gold_refresh_hovered() -> void:
	if not _is_refreshing and GameManager.player_data.gold > 0:
		CardPoolSystem.warm_refresh_roll("gold")

# ── 卡槽点击 → 转派为 card_clicked ──
func _on_slot_clicked(index: int) -> void:
	if index < slots.size() and slots[index].is_occupied:
		var card = slots[index].get_card()
		if card != null:
			card_clicked.emit(card)

# ── 卡槽双击 → 转派为 card_double_clicked（含槽位索引） ──
func _on_slot_double_clicked(index: int) -> void:
	if index < slots.size() and slots[index].is_occupied:
		var card = slots[index].get_card()
		if card != null:
			card_double_clicked.emit(card, index)

# ── 卡牌拖放到此槽位 ──
func _on_card_dropped(target_index: int, card: CardInfo, source: String, source_index: int) -> void:
	# 只处理目标是卡池的拖放
	if source == "hand":
		if _handle_hand_to_pool(card, source_index, target_index):
			DragSystem.notify_drop_completed(card, source, "pool")
		else:
			DragSystem.cancel_drag()
	elif source == "pool":
		if _handle_pool_to_pool(card, source_index, target_index):
			DragSystem.notify_drop_completed(card, source, "pool")
		else:
			DragSystem.cancel_drag()


func _handle_hand_to_pool(card: CardInfo, hand_idx: int, target_pool_idx: int) -> bool:
	var hand = GameManager.player_data.hand_cards
	var pool = CardPoolSystem.current_pool
	if target_pool_idx < 0 or target_pool_idx >= GameManager.player_data.pool_slots:
		print("[CardPoolUI] 目标卡池槽位无效")
		return false

	hand_idx = _resolve_card_index(hand, card, hand_idx)
	if hand_idx < 0:
		print("[CardPoolUI] 源手牌槽位无效")
		return false

	while pool.size() <= target_pool_idx:
		pool.append(null)
	var target_card = pool[target_pool_idx]
	if target_card != null:
		DragSystem.play_swap_animation("hand", hand_idx, "pool", target_pool_idx, card, target_card)
	pool[target_pool_idx] = card
	hand[hand_idx] = target_card
	GameManager.player_data.pool_cards = pool.duplicate()
	GameManager.mark_pool_hand_layout_dirty("hand_to_pool")

	GameManager.player_data.changed.emit()
	card_dragged.emit(card, hand_idx)
	return true


func _handle_pool_to_pool(card: CardInfo, source_pool_idx: int, target_pool_idx: int) -> bool:
	var pool = CardPoolSystem.current_pool
	if target_pool_idx < 0 or target_pool_idx >= GameManager.player_data.pool_slots:
		print("[CardPoolUI] 目标卡池槽位无效")
		return false

	source_pool_idx = _resolve_card_index(pool, card, source_pool_idx)
	if source_pool_idx < 0:
		print("[CardPoolUI] 源卡池槽位无效")
		return false

	while pool.size() <= maxi(source_pool_idx, target_pool_idx):
		pool.append(null)
	if source_pool_idx == target_pool_idx:
		return true

	var target_card = pool[target_pool_idx]
	if target_card != null:
		DragSystem.play_swap_animation("pool", source_pool_idx, "pool", target_pool_idx, card, target_card)
	pool[target_pool_idx] = pool[source_pool_idx]
	pool[source_pool_idx] = target_card
	GameManager.player_data.pool_cards = pool.duplicate()
	GameManager.mark_pool_hand_layout_dirty("pool_to_pool")

	GameManager.player_data.changed.emit()
	card_dragged.emit(card, source_pool_idx)
	return true


func _resolve_card_index(cards: Array, card: CardInfo, preferred_idx: int) -> int:
	if preferred_idx >= 0 and preferred_idx < cards.size() and cards[preferred_idx] != null:
		return preferred_idx
	for i in range(cards.size()):
		if cards[i] != null and cards[i].get_uid() == card.get_uid():
			return i
	return -1


# ── 卡池数据更新 ──
func _on_pool_updated(cards: Array) -> void:
	var should_animate := bool(CardPoolSystem.animate_next_pool_update)
	var rapid_animation := bool(CardPoolSystem.rapid_next_pool_update)
	CardPoolSystem.animate_next_pool_update = false
	CardPoolSystem.rapid_next_pool_update = false
	_refresh_display(cards, should_animate, rapid_animation)
	_update_refresh_buttons()
	_auto_warm_next_refresh_roll.call_deferred()

func _on_refresh_failed(_reason: String) -> void:
	AudioManager.play_sfx("error_soft")
	_update_refresh_buttons()

func _on_refresh_loading_started() -> void:
	_is_refreshing = true
	_update_refresh_buttons()

func _on_refresh_loading_completed() -> void:
	_is_refreshing = false
	_update_refresh_buttons()
	_auto_warm_next_refresh_roll.call_deferred()

func _on_free_refresh_cooldown_updated(_remaining: float) -> void:
	_update_refresh_buttons()

func _on_free_refresh_ready() -> void:
	_update_refresh_buttons()
	_auto_warm_next_refresh_roll.call_deferred()

func _on_player_data_changed() -> void:
	_update_refresh_buttons()
	_auto_warm_next_refresh_roll.call_deferred()

func _refresh_display(cards: Array, animate_draw: bool = false, rapid_animation: bool = false) -> void:
	_cancel_scheduled_draw_reveals()
	# 固定 16 槽，无翻页
	var unlocked_count = GameManager.player_data.pool_slots
	var draw_delays: Array[float] = []
	if animate_draw:
		draw_delays = _draw_drop_delays(cards, rapid_animation)
	for i in range(slot_count):
		if i >= slots.size():
			continue
		slots[i].set_slot_data_index(i)
		# 应用槽位锁定状态（前 N 个解锁，其余锁定）
		slots[i].set_unlocked(i < unlocked_count)
		if i < unlocked_count and i < cards.size():
			var card = cards[i]
			if animate_draw and card != null:
				slots[i].clear_slot()
				_schedule_draw_card_reveal(
					slots[i],
					card,
					i,
					draw_delays[i] if i < draw_delays.size() else _draw_drop_delay_for_slot(i, rapid_animation),
					_draw_reveal_generation
				)
			else:
				slots[i].set_card(card, i)
		else:
			slots[i].clear_slot()
		slots[i].visible = true


func _schedule_draw_card_reveal(slot: CardSlotUI, card: CardInfo, card_index: int, delay: float, generation: int) -> void:
	if slot == null or card == null:
		return
	if delay <= 0.0:
		_reveal_draw_card(slot, card, card_index, generation)
		return
	var reveal_tween := create_tween()
	_draw_reveal_tweens.append(reveal_tween)
	reveal_tween.tween_interval(delay)
	reveal_tween.tween_callback(func():
		_reveal_draw_card(slot, card, card_index, generation)
	)
	reveal_tween.finished.connect(func():
		_draw_reveal_tweens.erase(reveal_tween)
	)


func _reveal_draw_card(slot: CardSlotUI, card: CardInfo, card_index: int, generation: int) -> void:
	if generation != _draw_reveal_generation:
		return
	if not is_instance_valid(slot):
		return
	slot.set_card(card, card_index)
	slot.play_draw_drop_in(0.0)


func _cancel_scheduled_draw_reveals() -> void:
	_draw_reveal_generation += 1
	for tween in _draw_reveal_tweens:
		if tween != null and tween.is_valid():
			tween.kill()
	_draw_reveal_tweens.clear()


func _draw_drop_delay_for_slot(slot_idx: int, rapid_animation: bool = false) -> float:
	var row := int(slot_idx / columns)
	var col := slot_idx % columns
	var stagger := RAPID_DRAW_DROP_STAGGER_PER_CARD if rapid_animation else DRAW_DROP_STAGGER_PER_CARD
	return float(row * columns + col) * stagger


func _draw_drop_delays(cards: Array, rapid_animation: bool = false) -> Array[float]:
	var delays: Array[float] = []
	var next_presentation_start := 0.0
	for i in range(mini(slot_count, cards.size())):
		# 白卡是抽卡主力，只承担短 reveal 间隔；其他颜色保持完整演出屏障。
		delays.append(next_presentation_start)
		var current_card = cards[i]
		next_presentation_start += _draw_presentation_duration(current_card)
	return delays

func _draw_presentation_duration(card: CardInfo) -> float:
	var base_duration := CardSlotUI.DRAW_DROP_COMPLETE_DURATION
	if card == null:
		return base_duration
	match card.color:
		CardColor.ColorType.WHITE:
			return WHITE_DRAW_REVEAL_INTERVAL
		CardColor.ColorType.GREEN:
			return maxf(base_duration, CardSlotUI.DRAW_DROP_TOTAL_DURATION + CardSlotUI.GREEN_RARITY_SHINE_DURATION)
		CardColor.ColorType.BLUE:
			return CardSlotUI.BLUE_DRAW_FLIP_DURATION + maxf(base_duration, CardSlotUI.DRAW_DROP_TOTAL_DURATION + CardSlotUI.BLUE_RARITY_SHINE_DURATION)
		CardColor.ColorType.PURPLE:
			return CardSlotUI.PURPLE_DRAW_PRESENTATION_DURATION
		CardColor.ColorType.ORANGE:
			return CardSlotUI.ORANGE_DRAW_PRESENTATION_DURATION
		CardColor.ColorType.BLACK:
			return CardSlotUI.BLACK_DRAW_PRESENTATION_DURATION
	return base_duration


# ── 全局拖拽事件 ──

func _on_drag_ended(_card: CardInfo, _from: String, _to: String) -> void:
	_refresh_all()


func _on_drag_cancelled() -> void:
	_refresh_all()


func _refresh_all() -> void:
	_refresh_display(CardPoolSystem.current_pool)
	# 通知手牌区也刷新（通过 DragSystem 的 drag_ended 信号，HandAreaUI 也监听）

func _update_refresh_buttons() -> void:
	if _btn_free == null:
		return
	var free_remaining := GameManager.get_free_refresh_remaining()
	if GameManager.is_using_newbie_free_refreshes():
		_btn_free.text = Localization.t("ui.card_pool.refresh.free_newbie", [free_remaining])
	else:
		_btn_free.text = Localization.t("ui.card_pool.refresh.free_regular", [free_remaining])

	_btn_free.disabled = _is_refreshing or free_remaining <= 0 or _is_refresh_cooling_down(_free_cooldown)
	if _btn_gold != null:
		_btn_gold.disabled = _is_refreshing or GameManager.player_data.gold <= 0 or _is_refresh_cooling_down(_gold_cooldown)
	if _btn_gem != null:
		_btn_gem.disabled = _is_refreshing or GameManager.player_data.gems < 5 or _is_refresh_cooling_down(_gem_cooldown)

	if _free_cost_label != null:
		_free_cost_label.text = Localization.t("ui.card_pool.refresh.cost_stamina", [1])
	if _gold_cost_label != null:
		_gold_cost_label.text = Localization.t("ui.card_pool.refresh.cost_gold", [_get_gold_refresh_cost()])
	if _gem_cost_label != null:
		_gem_cost_label.text = Localization.t("ui.card_pool.refresh.cost_gem", [5])

	if _free_countdown_label == null:
		return
	var cooldown := GameManager.get_free_refresh_cooldown()
	if not GameManager.is_using_newbie_free_refreshes() and cooldown > 0.0:
		_free_countdown_label.text = Localization.t("ui.card_pool.refresh.next_free", [_format_seconds(cooldown)])
		_free_countdown_label.visible = true
	else:
		_free_countdown_label.text = ""
		_free_countdown_label.visible = false


func _try_start_refresh_cooldown(cooldown: Control) -> bool:
	if cooldown == null:
		return true
	var accepted: bool = cooldown.try_start()
	_update_refresh_buttons()
	if accepted:
		var timer := get_tree().create_timer(cooldown.duration_seconds)
		timer.timeout.connect(_update_refresh_buttons)
	return accepted


func _is_refresh_cooling_down(cooldown: Control) -> bool:
	return cooldown != null and cooldown.is_cooling_down()


func _attach_action_cooldown(button: Button) -> Control:
	var existing := button.get_node_or_null("AssetActionCooldown") as Control
	if existing != null:
		return existing
	var cooldown := AssetActionCooldownScript.new() as Control
	cooldown.name = "AssetActionCooldown"
	cooldown.set_anchors_preset(Control.PRESET_FULL_RECT)
	cooldown.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cooldown.z_index = 128
	button.add_child(cooldown)
	return cooldown


func _get_gold_refresh_cost() -> int:
	return maxi(1, int(GameManager.player_data.gold * 0.01))

func _format_seconds(seconds: float) -> String:
	var total := ceili(maxf(0.0, seconds))
	var minutes := int(total / 60)
	var secs := total % 60
	return "%02d:%02d" % [minutes, secs]

func _auto_warm_next_refresh_roll() -> void:
	if not auto_warm_enabled:
		return
	if GameManager.player_data.user_id <= 0:
		return
	if _is_refreshing:
		return
	if CardPoolSystem.has_pending_confirm() or ApiClient.has_pending_asset_requests():
		return
	var refresh_type := _preferred_refresh_type_for_warm()
	if refresh_type == "":
		return
	CardPoolSystem.warm_refresh_roll(refresh_type)

func _preferred_refresh_type_for_warm() -> String:
	if GameManager.get_free_refresh_remaining() > 0:
		return "free"
	if GameManager.player_data.gems >= 5:
		return "gem"
	if GameManager.player_data.gold > 0:
		return "gold"
	# prepare 不扣费。即使当前资源不足，也保留下一次可消费的服务器 roll。
	return "free"
