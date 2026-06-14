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
var _free_countdown_label: Label = null
var _is_refreshing: bool = false
var auto_warm_enabled: bool = true

const DRAW_DROP_STAGGER_PER_CARD: float = 0.0625

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

func setup_ui() -> void:
	# ── 卡槽网格（8×2 = 16 固定） ──
	_create_slot_grid()

	# ── 右侧刷新按钮列（垂直居中） ──
	_create_refresh_column()

func _create_slot_grid() -> void:
	var slot_size = CardSlotUI.SLOT_SIZE
	var slot_spacing = 8
	var start_x = 40
	var start_y = 0

	for i in range(slot_count):
		var row = i / columns
		var col = i % columns
		var x = start_x + col * (slot_size.x + slot_spacing)
		var y = start_y + row * (slot_size.y + slot_spacing)

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

func _create_refresh_column() -> void:
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	# 锚点 right=1.0 时 offset 是从右边缘算起的边距，必须为 0 或负数才能可见
	vbox.offset_left = -120    # -(110 宽 + 10 右边距)
	vbox.offset_right = -10
	vbox.offset_top = -70      # 垂直居中: 高 140 → ±70
	vbox.offset_bottom = 70
	vbox.add_theme_constant_override("separation", 6)
	add_child(vbox)

	_btn_free = Button.new()
	_btn_free.custom_minimum_size = Vector2(110, 36)
	_btn_free.pressed.connect(_on_free_refresh)
	_btn_free.mouse_entered.connect(_on_free_refresh_hovered)
	vbox.add_child(_btn_free)

	_btn_gold = Button.new()
	_btn_gold.text = Localization.t("ui.card_pool.refresh.gold")
	_btn_gold.custom_minimum_size = Vector2(110, 36)
	_btn_gold.pressed.connect(_on_gold_refresh)
	_btn_gold.mouse_entered.connect(_on_gold_refresh_hovered)
	vbox.add_child(_btn_gold)

	_btn_gem = Button.new()
	_btn_gem.text = Localization.t("ui.card_pool.refresh.gem")
	_btn_gem.custom_minimum_size = Vector2(110, 36)
	_btn_gem.pressed.connect(_on_gem_refresh)
	_btn_gem.mouse_entered.connect(_on_gem_refresh_hovered)
	vbox.add_child(_btn_gem)

	_free_countdown_label = Label.new()
	_free_countdown_label.custom_minimum_size = Vector2(110, 34)
	_free_countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_free_countdown_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_free_countdown_label.add_theme_font_size_override("font_size", 11)
	_free_countdown_label.add_theme_color_override("font_color", Color(0.75, 0.85, 1.0, 0.9))
	vbox.add_child(_free_countdown_label)
	_update_refresh_buttons()

# ── 刷新回调 ──
func _on_free_refresh() -> void:
	if _is_refreshing:
		return
	if CardPoolSystem.do_refresh("free"):
		CardPoolSystem.refresh_pool("free")
	_update_refresh_buttons()

func _on_gem_refresh() -> void:
	if _is_refreshing:
		return
	if CardPoolSystem.do_refresh("gem"):
		CardPoolSystem.refresh_pool("gem")
	_update_refresh_buttons()

func _on_gold_refresh() -> void:
	if _is_refreshing:
		return
	var step_started := Time.get_ticks_msec()
	var total_started := step_started
	var gold_before := GameManager.player_data.gold
	var cost := maxi(1, int(gold_before * 0.01))
	CardPoolSystem.gold_draw_debug_click_started_msec = total_started
	if CardPoolSystem.do_refresh("gold"):
		_print_gold_draw_step(
			1,
			"done",
			"本地金币扣费检查",
			step_started,
			total_started,
			{"cost": cost, "gold_before": gold_before, "gold_after": GameManager.player_data.gold}
		)
		CardPoolSystem.refresh_pool("gold")
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
	CardPoolSystem.animate_next_pool_update = false
	_refresh_display(cards, should_animate)
	_update_refresh_buttons()
	_auto_warm_next_refresh_roll.call_deferred()

func _on_refresh_failed(_reason: String) -> void:
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

func _refresh_display(cards: Array, animate_draw: bool = false) -> void:
	# 固定 16 槽，无翻页
	var unlocked_count = GameManager.player_data.pool_slots
	for i in range(slot_count):
		if i >= slots.size():
			continue
		slots[i].set_slot_data_index(i)
		# 应用槽位锁定状态（前 N 个解锁，其余锁定）
		slots[i].set_unlocked(i < unlocked_count)
		if i < unlocked_count and i < cards.size():
			slots[i].set_card(cards[i], i)
			if animate_draw and cards[i] != null:
				slots[i].play_draw_drop_in(_draw_drop_delay_for_slot(i))
		else:
			slots[i].clear_slot()
		slots[i].visible = true


func _draw_drop_delay_for_slot(slot_idx: int) -> float:
	var row := int(slot_idx / columns)
	var col := slot_idx % columns
	return float(row * columns + col) * DRAW_DROP_STAGGER_PER_CARD


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

	_btn_free.disabled = _is_refreshing or free_remaining <= 0
	if _btn_gold != null:
		_btn_gold.disabled = _is_refreshing or GameManager.player_data.gold <= 0
	if _btn_gem != null:
		_btn_gem.disabled = _is_refreshing or GameManager.player_data.gems < 5

	if _free_countdown_label == null:
		return
	var cooldown := GameManager.get_free_refresh_cooldown()
	if not GameManager.is_using_newbie_free_refreshes() and cooldown > 0.0:
		_free_countdown_label.text = Localization.t("ui.card_pool.refresh.next_free", [_format_seconds(cooldown)])
		_free_countdown_label.visible = true
	else:
		_free_countdown_label.text = ""
		_free_countdown_label.visible = false

func _format_seconds(seconds: float) -> String:
	var total := ceili(maxf(0.0, seconds))
	var minutes := int(total / 60)
	var secs := total % 60
	return "%02d:%02d" % [minutes, secs]

func _auto_warm_next_refresh_roll() -> void:
	if not auto_warm_enabled:
		return
	if _is_refreshing:
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
	return ""
