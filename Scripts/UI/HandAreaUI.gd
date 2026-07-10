extends Control
class_name HandAreaUI

signal card_clicked(card: CardInfo)
signal card_double_clicked(card: CardInfo, slot_index: int)
signal card_dragged(card: CardInfo, from_slot: int)
signal synthesize_requested()
signal discard_requested()
signal vault_save_requested()

@export var columns: int = 8
@export var rows_visible: int = 2   # 可见行数
@export var total_rows: int = 4     # 总行数（2 页）

var slot_count: int = 16           # 2×8 每页
var total_slots: int = 32          # 4×8 总计
var slots: Array[CardSlotUI] = []
var current_page: int = 0
var _slots_clip: Control = null
var _slots_layer: Control = null
var _page_animating: bool = false
var _selected_hand_index: int = -1
var _btn_synth: Button = null
var _btn_discard: Button = null
var _btn_vault: Button = null
var _synth_cooldown: Control = null
var _discard_cooldown: Control = null
var _vault_cooldown: Control = null
var _synthesis_hidden_indices: Dictionary = {}

const AssetActionCooldownScript = preload("res://Scripts/UI/AssetActionCooldown.gd")

const PAGE_ROLL_DURATION: float = 0.32
const SLOT_SPACING: float = 8.0
const SLOT_CLIP_PADDING: Vector2 = Vector2(24.0, 24.0)

func _ready() -> void:
	setup_ui()
	GameManager.player_data.changed.connect(_on_player_data_changed)

	# 监听拖拽事件
	if DragSystem != null:
		DragSystem.drag_ended.connect(_on_drag_ended)
		DragSystem.drag_cancelled.connect(_on_drag_cancelled)

func _input(event: InputEvent) -> void:
	if _selected_hand_index < 0:
		return
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if not mb.pressed:
		return
	if mb.button_index != MOUSE_BUTTON_LEFT and mb.button_index != MOUSE_BUTTON_RIGHT:
		return
	if _is_point_over_action_button(mb.position):
		return
	var selected_slot := _visible_slot_for_global_index(_selected_hand_index)
	if selected_slot != null and selected_slot.get_global_rect().has_point(mb.position):
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			clear_selection()
		return
	clear_selection()

func setup_ui() -> void:
	_create_slot_grid()
	_create_action_column()

func _create_slot_grid() -> void:
	_slots_clip = Control.new()
	_slots_clip.clip_contents = true
	_slots_clip.position = Vector2(_centered_grid_start_x(), 0.0) - SLOT_CLIP_PADDING
	_slots_clip.size = _grid_size() + SLOT_CLIP_PADDING * 2.0
	add_child(_slots_clip)

	_slots_layer = Control.new()
	_slots_layer.position = SLOT_CLIP_PADDING
	_slots_layer.size = _grid_size()
	_slots_clip.add_child(_slots_layer)

	var slot_size = CardSlotUI.SLOT_SIZE
	var start_x = 0.0
	var start_y = 0

	for i in range(slot_count):  # 16 可见槽
		var row = i / columns
		var col = i % columns
		var x = start_x + col * (slot_size.x + SLOT_SPACING)
		var y = start_y + row * (slot_size.y + SLOT_SPACING)

		var slot = CardSlotUI.new()
		slot.slot_index = i
		slot.position = Vector2(x, y)
		slot.area_type = "hand"
		slot.slot_clicked.connect(_on_slot_clicked)
		slot.slot_double_clicked.connect(_on_slot_double_clicked)
		slot.card_dropped.connect(_on_card_dropped)
		slot.slot_unlock_requested.connect(func(idx: int): GameManager.handle_unlock_slot("hand", idx))
		slots.append(slot)
		_slots_layer.add_child(slot)

func _create_action_column() -> void:
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	# 锚点 right=1.0 时 offset 是从右边缘算起的边距，必须为 0 或负数才能可见
	vbox.offset_left = -120    # -(110 宽 + 10 右边距)
	vbox.offset_right = -10
	vbox.offset_top = -100     # 垂直居中: 高 200 → ±100
	vbox.offset_bottom = 100
	vbox.add_theme_constant_override("separation", 6)
	add_child(vbox)

	# 翻页按钮
	var btn_page = Button.new()
	btn_page.text = Localization.t("ui.hand.page")
	btn_page.custom_minimum_size = Vector2(100, 36)
	btn_page.pressed.connect(_on_page_flip)
	vbox.add_child(btn_page)

	# 合成
	_btn_synth = Button.new()
	_btn_synth.text = Localization.t("ui.hand.synthesize")
	_btn_synth.custom_minimum_size = Vector2(100, 36)
	_btn_synth.disabled = true
	vbox.add_child(_btn_synth)
	_synth_cooldown = _attach_action_cooldown(_btn_synth)
	_btn_synth.pressed.connect(func():
		if _try_start_button_cooldown(_synth_cooldown):
			synthesize_requested.emit()
	)

	# 丢弃
	_btn_discard = Button.new()
	_btn_discard.text = Localization.t("ui.hand.discard")
	_btn_discard.custom_minimum_size = Vector2(100, 36)
	_btn_discard.disabled = true
	vbox.add_child(_btn_discard)
	_discard_cooldown = _attach_action_cooldown(_btn_discard)
	_btn_discard.pressed.connect(func():
		if _try_start_button_cooldown(_discard_cooldown):
			discard_requested.emit()
	)

	# 存入保险箱
	_btn_vault = Button.new()
	_btn_vault.text = Localization.t("ui.hand.store_vault")
	_btn_vault.custom_minimum_size = Vector2(100, 36)
	_btn_vault.disabled = true
	vbox.add_child(_btn_vault)
	_vault_cooldown = _attach_action_cooldown(_btn_vault)
	_btn_vault.pressed.connect(func():
		if _try_start_button_cooldown(_vault_cooldown):
			vault_save_requested.emit()
	)

# ── 翻页 ──
func _on_page_flip() -> void:
	if _page_animating:
		return
	clear_selection()
	var max_page = max(0, ceili(float(total_slots) / float(slot_count)) - 1)
	var next_page = (current_page + 1) % (max_page + 1)
	_roll_to_page(next_page)


func _grid_size() -> Vector2:
	var slot_size = CardSlotUI.SLOT_SIZE
	return Vector2(
		columns * slot_size.x + (columns - 1) * SLOT_SPACING,
		rows_visible * slot_size.y + (rows_visible - 1) * SLOT_SPACING
	)


func _centered_grid_start_x() -> float:
	var viewport_width := get_viewport_rect().size.x
	var centered_global_left := maxf(0.0, (viewport_width - _grid_size().x) * 0.5)
	var parent_global_x := global_position.x if is_inside_tree() else 0.0
	return maxf(0.0, centered_global_left - parent_global_x)


func _roll_to_page(next_page: int) -> void:
	if next_page == current_page or _slots_layer == null or _slots_clip == null:
		return

	_page_animating = true
	var old_page := current_page
	var forward := next_page > old_page
	if old_page == 0 and next_page > old_page:
		forward = true
	elif next_page == 0 and old_page > next_page:
		forward = false
	var direction := 1.0 if forward else -1.0
	var roll_distance := _grid_size().y

	var incoming_layer := Control.new()
	incoming_layer.size = _grid_size()
	incoming_layer.position = SLOT_CLIP_PADDING + Vector2(0, roll_distance * direction)
	_slots_clip.add_child(incoming_layer)
	_populate_page_layer(incoming_layer, next_page, false)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_slots_layer, "position:y", SLOT_CLIP_PADDING.y - roll_distance * direction, PAGE_ROLL_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(incoming_layer, "position:y", SLOT_CLIP_PADDING.y, PAGE_ROLL_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.finished.connect(func():
		current_page = next_page
		refresh_display()
		_slots_layer.position = SLOT_CLIP_PADDING
		incoming_layer.queue_free()
		_page_animating = false
	)


func _populate_page_layer(layer: Control, page: int, register_slots: bool = true) -> void:
	var cards = GameManager.player_data.hand_cards
	var hand_slots_unlocked = GameManager.player_data.hand_slots
	var start_idx = page * slot_count
	var slot_size = CardSlotUI.SLOT_SIZE
	var start_x = 0.0
	var start_y = 0

	for i in range(slot_count):
		var global_idx = start_idx + i
		var row = i / columns
		var col = i % columns
		var slot := CardSlotUI.new()
		slot.slot_index = i
		slot.position = Vector2(start_x + col * (slot_size.x + SLOT_SPACING), start_y + row * (slot_size.y + SLOT_SPACING))
		slot.area_type = "hand"
		slot.can_drag_from = false
		slot.register_drag_slot = register_slots
		slot.set_slot_data_index(global_idx)
		layer.add_child(slot)
		slot.set_unlocked(global_idx < hand_slots_unlocked)
		if not _is_synthesis_hidden(global_idx) and global_idx < hand_slots_unlocked and global_idx < cards.size() and cards[global_idx] != null:
			slot.set_card(cards[global_idx], global_idx)
		else:
			slot.clear_slot()

# ── 卡槽点击 ──
func _on_slot_clicked(index: int) -> void:
	var global_idx = current_page * slot_count + index
	var click_button := _slot_click_button(index)
	if index < slots.size() and slots[index].is_occupied:
		var card = slots[index].get_card()
		if card != null:
			if _selected_hand_index == global_idx:
				if click_button == MOUSE_BUTTON_RIGHT:
					clear_selection()
			else:
				if click_button == MOUSE_BUTTON_LEFT:
					_select_hand_slot(global_idx)
				else:
					clear_selection()
					return
			if click_button == MOUSE_BUTTON_LEFT:
				card_clicked.emit(card)
	elif click_button == MOUSE_BUTTON_LEFT or click_button == MOUSE_BUTTON_RIGHT:
		clear_selection()

# ── 卡槽双击 → 转派为 card_double_clicked（含全局索引） ──
func _on_slot_double_clicked(index: int) -> void:
	var global_idx = current_page * slot_count + index
	if index < slots.size() and slots[index].is_occupied:
		var card = slots[index].get_card()
		if card != null:
			card_double_clicked.emit(card, global_idx)

# ── 卡牌拖放到此槽位 ──
func _on_card_dropped(target_slot_index: int, card: CardInfo, source: String, source_index: int) -> void:
	var global_target = current_page * slot_count + target_slot_index

	if source == "pool":
		if _handle_pool_to_hand(card, source_index, global_target):
			DragSystem.notify_drop_completed(card, source, "hand")
		else:
			DragSystem.cancel_drag()

	elif source == "hand":
		if _handle_hand_to_hand(card, source_index, global_target):
			DragSystem.notify_drop_completed(card, source, "hand")
		else:
			DragSystem.cancel_drag()


func _handle_pool_to_hand(card: CardInfo, source_pool_idx: int, target_hand_idx: int) -> bool:
	var pool = CardPoolSystem.current_pool
	var hand = GameManager.player_data.hand_cards
	var max_slots = GameManager.player_data.hand_slots
	if target_hand_idx >= max_slots:
		print("[HandAreaUI] 目标手牌槽位超出解锁范围")
		return false

	source_pool_idx = _resolve_card_index(pool, card, source_pool_idx)
	if source_pool_idx < 0:
		print("[HandAreaUI] 源卡池槽位无效")
		return false

	while hand.size() <= target_hand_idx:
		hand.append(null)
	while pool.size() <= source_pool_idx:
		pool.append(null)
	var target_card = hand[target_hand_idx]
	if target_card != null:
		DragSystem.play_swap_animation("pool", source_pool_idx, "hand", target_hand_idx, card, target_card)
	hand[target_hand_idx] = card
	pool[source_pool_idx] = target_card
	GameManager.player_data.pool_cards = pool.duplicate()
	GameManager.mark_pool_hand_layout_dirty("pool_to_hand")
	if _selected_hand_index == target_hand_idx or _selected_hand_index == source_pool_idx:
		clear_selection()

	GameManager.player_data.changed.emit()
	card_dragged.emit(card, target_hand_idx)
	return true


func _handle_hand_to_hand(card: CardInfo, source_hand_idx: int, target_hand_idx: int) -> bool:
	var hand = GameManager.player_data.hand_cards
	var max_slots = GameManager.player_data.hand_slots
	if target_hand_idx < 0 or target_hand_idx >= max_slots:
		print("[HandAreaUI] 目标手牌槽位无效")
		return false

	source_hand_idx = _resolve_card_index(hand, card, source_hand_idx)
	if source_hand_idx < 0:
		print("[HandAreaUI] 源手牌槽位无效")
		return false

	while hand.size() <= maxi(source_hand_idx, target_hand_idx):
		hand.append(null)
	if source_hand_idx == target_hand_idx:
		return true

	var target_card = hand[target_hand_idx]
	if target_card != null:
		DragSystem.play_swap_animation("hand", source_hand_idx, "hand", target_hand_idx, card, target_card)
	hand[target_hand_idx] = hand[source_hand_idx]
	hand[source_hand_idx] = target_card
	GameManager.mark_pool_hand_layout_dirty("hand_to_hand")
	clear_selection()

	GameManager.player_data.changed.emit()
	card_dragged.emit(card, source_hand_idx)
	return true


func _resolve_card_index(cards: Array, card: CardInfo, preferred_idx: int) -> int:
	if preferred_idx >= 0 and preferred_idx < cards.size() and cards[preferred_idx] != null:
		return preferred_idx
	for i in range(cards.size()):
		if cards[i] != null and cards[i].get_uid() == card.get_uid():
			return i
	return -1


# ── 数据变更 ──
func _on_player_data_changed() -> void:
	_ensure_selection_valid()
	refresh_display()


# ── 全局拖拽事件 ──

func _on_drag_ended(_card: CardInfo, _from: String, _to: String) -> void:
	_refresh_all()


func _on_drag_cancelled() -> void:
	_refresh_all()


func _refresh_all() -> void:
	refresh_display()
	# CardPoolUI 也通过 DragSystem.drag_ended 获得刷新


func refresh_display() -> void:
	var cards = GameManager.player_data.hand_cards
	var hand_slots_unlocked = GameManager.player_data.hand_slots
	var start_idx = current_page * slot_count
	var end_idx = start_idx + slot_count

	for i in range(slot_count):
		var global_idx = start_idx + i
		if i < slots.size():
			slots[i].set_slot_data_index(global_idx)
			# 应用槽位锁定状态（前 N 个解锁，其余锁定）
			slots[i].set_unlocked(global_idx < hand_slots_unlocked)
			if not _is_synthesis_hidden(global_idx) and global_idx < hand_slots_unlocked and global_idx < cards.size() and cards[global_idx] != null:
				slots[i].set_card(cards[global_idx], global_idx)
			else:
				slots[i].clear_slot()
			slots[i].set_selected(global_idx == _selected_hand_index)
			slots[i].visible = true

	_update_action_buttons()


func clear_selection() -> void:
	_selected_hand_index = -1
	for slot in slots:
		slot.set_selected(false)
	_update_action_buttons()


func _slot_click_button(index: int) -> int:
	if index >= 0 and index < slots.size():
		return slots[index].last_click_button_index
	return MOUSE_BUTTON_LEFT


func _visible_slot_for_global_index(global_idx: int) -> CardSlotUI:
	var local_idx := global_idx - current_page * slot_count
	if local_idx < 0 or local_idx >= slots.size():
		return null
	return slots[local_idx]


func _is_point_over_action_button(global_point: Vector2) -> bool:
	for button in [_btn_synth, _btn_discard, _btn_vault]:
		var btn := button as Button
		if btn != null and btn.is_inside_tree() and btn.get_global_rect().has_point(global_point):
			return true
	return false


func get_selected_hand_index() -> int:
	_ensure_selection_valid()
	return _selected_hand_index


func get_selected_synthesis_indices() -> Array[int]:
	_ensure_selection_valid()
	if _selected_hand_index < 0:
		return []
	var cards = GameManager.player_data.hand_cards
	if _selected_hand_index >= cards.size() or cards[_selected_hand_index] == null:
		return []
	return _find_synthesizable_indices_for_card(cards[_selected_hand_index])

func get_synthesis_animation_sources(indices: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var cards = GameManager.player_data.hand_cards
	for global_idx in indices:
		var idx := int(global_idx)
		var card: CardInfo = cards[idx] if idx >= 0 and idx < cards.size() else null
		var visible_slot: CardSlotUI = null
		var local_idx := idx - current_page * slot_count
		if local_idx >= 0 and local_idx < slots.size():
			var slot := slots[local_idx]
			if slot != null and slot.is_inside_tree() and slot.is_occupied:
				visible_slot = slot
		result.append({
			"index": idx,
			"card": card,
			"global_rect": visible_slot.get_global_rect() if visible_slot != null else Rect2(),
			"visible": visible_slot != null,
		})
	return result


func hide_synthesis_slots_for_animation(indices: Array) -> void:
	_synthesis_hidden_indices.clear()
	for global_idx in indices:
		var idx := int(global_idx)
		_synthesis_hidden_indices[idx] = true
		var local_idx := idx - current_page * slot_count
		if local_idx < 0 or local_idx >= slots.size():
			continue
		var slot := slots[local_idx] as CardSlotUI
		if slot == null:
			continue
		slot.clear_slot()
		slot.set_selected(false)
	if _btn_synth != null:
		_btn_synth.disabled = true
	if _btn_discard != null:
		_btn_discard.disabled = true
	if _btn_vault != null:
		_btn_vault.disabled = true

func clear_synthesis_animation_hidden_slots() -> void:
	_synthesis_hidden_indices.clear()

func _is_synthesis_hidden(global_idx: int) -> bool:
	return _synthesis_hidden_indices.has(global_idx)


func _select_hand_slot(global_idx: int) -> void:
	_selected_hand_index = global_idx
	refresh_display()


func _ensure_selection_valid() -> void:
	if _selected_hand_index < 0:
		return
	if _is_synthesis_hidden(_selected_hand_index):
		_selected_hand_index = -1
		return
	var cards = GameManager.player_data.hand_cards
	if _selected_hand_index >= cards.size() or cards[_selected_hand_index] == null:
		_selected_hand_index = -1


func _update_action_buttons() -> void:
	_ensure_selection_valid()
	var has_selection := _selected_hand_index >= 0
	if _btn_discard != null:
		_btn_discard.disabled = (not has_selection) or _is_button_cooling_down(_discard_cooldown)
	if _btn_vault != null:
		_btn_vault.disabled = (not (has_selection and _has_unlocked_vault_space())) or _is_button_cooling_down(_vault_cooldown)
	if _btn_synth != null:
		_btn_synth.disabled = (not (has_selection and get_selected_synthesis_indices().size() == 5)) or _is_button_cooling_down(_synth_cooldown)


func _try_start_button_cooldown(cooldown: Control) -> bool:
	if cooldown == null:
		return true
	var accepted: bool = cooldown.try_start()
	_update_action_buttons()
	if accepted:
		var timer := get_tree().create_timer(cooldown.duration_seconds)
		timer.timeout.connect(_update_action_buttons)
	return accepted


func _is_button_cooling_down(cooldown: Control) -> bool:
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


func _has_unlocked_vault_space() -> bool:
	var vault_cards = GameManager.player_data.vault_cards
	for i in range(GameManager.player_data.vault_slots):
		if i >= vault_cards.size() or vault_cards[i] == null:
			return true
	return false


func _find_synthesizable_indices_for_card(selected_card: CardInfo) -> Array[int]:
	if selected_card == null:
		return []
	var cards = GameManager.player_data.hand_cards
	var by_number: Dictionary = {}
	for i in range(cards.size()):
		var card = cards[i]
		if card == null:
			continue
		if card.series_name != selected_card.series_name:
			continue
		if card.deck_name != selected_card.deck_name:
			continue
		if card.color != selected_card.color:
			continue
		var number := int(card.card_number)
		if number < 1 or number > 5:
			continue
		if not by_number.has(number):
			by_number[number] = i

	var result: Array[int] = []
	for number in [1, 2, 3, 4, 5]:
		if not by_number.has(number):
			return []
		result.append(int(by_number[number]))
	return result
