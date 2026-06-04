extends Node

# CCR 数据层
const _CCRData = preload("res://Scripts/Data/CCRData.gd")

signal drag_started(card: CardInfo, from: String)
signal drag_ended(card: CardInfo, from: String, to: String)
signal drag_cancelled()

enum DropTarget { NONE, POOL, HAND, VAULT, DECK_PANEL }

var dragging_card: CardInfo = null
var dragging_from: String = ""
var dragging_index: int = -1

# ── 拖拽高亮协调（同一时刻只有一个槽位高亮） ──
var _highlighted_target: Node = null


func start_drag(card: CardInfo, from: String, index: int = -1) -> void:
	dragging_card = card
	dragging_from = from
	dragging_index = index
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
	drag_cancelled.emit()
	_reset_drag()


func _reset_drag() -> void:
	dragging_card = null
	dragging_from = ""
	dragging_index = -1
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
		pool.remove_at(idx)


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


func _clear_highlight_target() -> void:
	if _highlighted_target != null and _highlighted_target.has_method("clear_drop_highlight"):
		_highlighted_target.clear_drop_highlight()
	_highlighted_target = null
