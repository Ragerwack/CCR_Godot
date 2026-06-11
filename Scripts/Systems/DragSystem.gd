extends Node

# CCR 数据层
const _CCRData = preload("res://Scripts/Data/CCRData.gd")

signal drag_started(card: CardInfo, from: String)
signal drag_ended(card: CardInfo, from: String, to: String)
signal drag_cancelled()
signal return_to_source_requested(card: CardInfo, from: String, source_index: int, start_global_position: Vector2)

enum DropTarget { NONE, POOL, HAND, VAULT, DECK_PANEL }

var dragging_card: CardInfo = null
var dragging_from: String = ""
var dragging_index: int = -1
var dragging_card_offset: Vector2 = Vector2.ZERO

# ── 拖拽高亮协调（同一时刻只有一个槽位高亮） ──
var _highlighted_target: Node = null

const TRANSFER_ANIMATION_DURATION: float = 0.24


func start_drag(card: CardInfo, from: String, index: int = -1, card_offset: Vector2 = Vector2.ZERO) -> void:
	dragging_card = card
	dragging_from = from
	dragging_index = index
	dragging_card_offset = card_offset
	drag_started.emit(card, from)


func end_drag(target: DropTarget) -> void:
	if dragging_card == null:
		return
	var target_name = _target_to_string(target)
	drag_ended.emit(dragging_card, dragging_from, target_name)
	_reset_drag()


## 根据源和目标字符串完成拖拽数据迁移（纯本地）
func end_drag_str(card: CardInfo, src: String, dst: String) -> bool:
	dragging_card = card
	dragging_from = src
	var ok = handle_card_move(card, src, dst)
	drag_ended.emit(card, src, dst)
	_reset_drag()
	return ok


func cancel_drag() -> void:
	if dragging_card != null:
		var release_pos := get_viewport().get_mouse_position() - dragging_card_offset
		return_to_source_requested.emit(dragging_card, dragging_from, dragging_index, release_pos)
	drag_cancelled.emit()
	_reset_drag()


func _reset_drag() -> void:
	dragging_card = null
	dragging_from = ""
	dragging_index = -1
	dragging_card_offset = Vector2.ZERO
	_clear_highlight_target()


## 拖放成功完成后调用：发出 drag_ended 信号并重置状态（不操作数据）
func notify_drop_completed(card: CardInfo, src: String, dst: String) -> void:
	dragging_card = card
	dragging_from = src
	drag_ended.emit(card, src, dst)
	_reset_drag()


func _target_to_string(t: DropTarget) -> String:
	match t:
		DropTarget.POOL: return "pool"
		DropTarget.HAND: return "hand"
		DropTarget.VAULT: return "vault"
		DropTarget.DECK_PANEL: return "deck_panel"
	return "none"


func is_dragging() -> bool:
	return dragging_card != null


# ══════════════════════════════════════════════════
#  数据迁移（纯本地，不调 API）
# ══════════════════════════════════════════════════

func handle_card_move(card: CardInfo, from: String, to: String) -> bool:
	# 1. 从源区域移除
	match from:
		"pool":
			_remove_from_pool(card)
		"hand":
			_remove_from_hand(card)
		"vault":
			GameManager.player_data.remove_from_vault(card)

	# 2. 添加到目标区域
	match to:
		"pool":
			return _add_to_pool(card)
		"hand":
			return _add_to_hand(card)
		"vault":
			return GameManager.player_data.add_to_vault(card)
	return false


func _remove_from_pool(card: CardInfo) -> void:
	var pool = CardPoolSystem.current_pool
	var idx = -1
	for i in range(pool.size()):
		if pool[i] != null and pool[i].get_uid() == card.get_uid():
			idx = i
			break
	if idx >= 0:
		pool[idx] = null


func _remove_from_hand(card: CardInfo) -> void:
	var hand = GameManager.player_data.hand_cards
	for i in range(hand.size()):
		if hand[i] != null and hand[i].get_uid() == card.get_uid():
			hand[i] = null
			return
	# fallback: try remove_from_hand
	GameManager.player_data.remove_from_hand(card)


func _add_to_pool(card: CardInfo) -> bool:
	var pool = CardPoolSystem.current_pool
	var max_slots = GameManager.player_data.pool_slots
	# 找第一个空槽
	for i in range(max_slots):
		if i >= pool.size():
			pool.append(card)
			return true
		if pool[i] == null:
			pool[i] = card
			return true
	return false


func _add_to_hand(card: CardInfo) -> bool:
	var hand = GameManager.player_data.hand_cards
	var max_slots = GameManager.player_data.hand_slots
	# 找第一个空槽
	for i in range(max_slots):
		if i >= hand.size():
			hand.append(card)
			return true
		if hand[i] == null:
			hand[i] = card
			return true
	return false


# ══════════════════════════════════════════════════
#  高亮协调
# ══════════════════════════════════════════════════

## 设置当前高亮的拖放目标（自动清除上一目标）
func set_highlight_target(node: Node) -> void:
	if _highlighted_target == node:
		return
	if _highlighted_target != null and _highlighted_target.has_method("clear_drop_highlight"):
		_highlighted_target.clear_drop_highlight()
	_highlighted_target = node


func clear_highlight_target(node: Node = null) -> void:
	if node != null and _highlighted_target != node:
		return
	_clear_highlight_target()


func _clear_highlight_target() -> void:
	if _highlighted_target != null and _highlighted_target.has_method("clear_drop_highlight"):
		_highlighted_target.clear_drop_highlight()
	_highlighted_target = null


func play_swap_animation(source_area: String, source_index: int, target_area: String, target_index: int, source_card: CardInfo, target_card: CardInfo) -> void:
	if source_card == null or target_card == null:
		return
	var source_slot := _find_slot(source_area, source_index)
	var target_slot := _find_slot(target_area, target_index)
	if source_slot == null or target_slot == null:
		return

	var source_start := get_viewport().get_mouse_position() - dragging_card_offset
	var source_end: Vector2 = target_slot.global_position
	var target_start: Vector2 = target_slot.global_position
	var target_end: Vector2 = source_slot.global_position

	source_slot.hide_for_transfer(TRANSFER_ANIMATION_DURATION)
	target_slot.hide_for_transfer(TRANSFER_ANIMATION_DURATION)
	_play_transfer_card(source_card, source_index, source_start, source_end)
	_play_transfer_card(target_card, target_index, target_start, target_end)


func _find_slot(area: String, data_index: int) -> CardSlotUI:
	for node in get_tree().get_nodes_in_group("card_slots"):
		if node is CardSlotUI and node.area_type == area and node.slot_data_index == data_index:
			return node
	return null


func _play_transfer_card(card: CardInfo, card_index: int, start_global_position: Vector2, end_global_position: Vector2) -> void:
	var anim_card := CardDisplay.new()
	anim_card.custom_minimum_size = CardSlotUI.SLOT_SIZE
	anim_card.size = CardSlotUI.SLOT_SIZE
	anim_card.z_index = 4096
	anim_card.hover_uses_slot_bounds = true
	anim_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_tree().root.add_child(anim_card)
	anim_card.global_position = start_global_position
	anim_card.set_card(card, card_index)

	var tween := anim_card.create_tween()
	tween.tween_property(anim_card, "global_position", end_global_position, TRANSFER_ANIMATION_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.finished.connect(func(): anim_card.queue_free())
