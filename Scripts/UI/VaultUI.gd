extends Control
class_name VaultUI

signal card_clicked(card: CardInfo)
signal card_dragged(card: CardInfo, from_slot: int)

@export var columns: int = 8

var slot_count: int = 2  # 初始2格，最高9格
var slots: Array[CardSlotUI] = []
var _raw_slot_data: Array = []  # 服务端原始槽位数据（含 unlocked 等信息）

# ── 选中合成相关 ──
var _selected_slots: Array[int] = []     # 选中的槽位索引（最多5个）
var _synthesize_btn: Button = null


const MAX_SELECT: int = 5
const SELECT_BORDER_COLOR: Color = Color(1.0, 0.84, 0.0, 0.7)  # 金色

func _ready() -> void:
	slot_count = GameManager.player_data.vault_slots
	setup_ui()
	GameManager.player_data.changed.connect(_on_player_data_changed)

	# 如果已登录，从服务端加载
	if ApiClient.is_logged_in():
		_load_from_server()

	# 监听拖拽事件
	if DragSystem != null:
		DragSystem.drag_ended.connect(_on_drag_ended)
		DragSystem.drag_cancelled.connect(_on_drag_cancelled)

func _load_from_server() -> void:
	var resp = await ApiClient.get_cards("vault")
	if resp["success"]:
		_raw_slot_data = resp["data"] as Array
		GameManager.player_data.vault_cards = ApiClient.card_slots_to_array_sorted(resp["data"])
		refresh_display()

func setup_ui() -> void:
	# 标题
	var title = Label.new()
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.position = Vector2(0, 10)
	title.size = Vector2(400, 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.text = "保险箱"
	add_child(title)

	# 槽位标签
	var slot_label = Label.new()
	slot_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	slot_label.position = Vector2(0, 45)
	slot_label.size = Vector2(200, 25)
	slot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	slot_label.text = "%d / %d 格" % [GameManager.player_data.vault_cards.size(), slot_count]
	slot_label.name = "SlotLabel"
	add_child(slot_label)

	# ── 合成按钮（初始隐藏） ──
	_synthesize_btn = Button.new()
	_synthesize_btn.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_synthesize_btn.position = Vector2(0, -60)
	_synthesize_btn.size = Vector2(140, 40)
	_synthesize_btn.text = "✨ 合成 (0/5)"
	_synthesize_btn.visible = false
	_synthesize_btn.disabled = true
	_synthesize_btn.pressed.connect(_on_synthesize_pressed)
	add_child(_synthesize_btn)

	_create_slot_grid()
	refresh_display()

func _create_slot_grid() -> void:
	# 保险箱格子大一些，居中显示，预留底部合成按钮空间
	var slot_size = Vector2(100, 140)
	var slot_spacing = 15
	var total_width = slot_count * slot_size.x + (slot_count - 1) * slot_spacing
	var start_x = (size.x - total_width) / 2
	var start_y = 85.0

	for i in range(slot_count):
		var x = start_x + i * (slot_size.x + slot_spacing)
		var slot = CardSlotUI.new()
		slot.slot_index = i
		slot.position = Vector2(x, start_y)
		slot.custom_minimum_size = slot_size
		slot.area_type = "vault"
		slot.can_drag_from = false  # 保险箱卡牌不可拖出
		slot.slot_clicked.connect(_on_slot_clicked)
		slot.card_dropped.connect(_on_card_dropped)
		slot.slot_unlock_requested.connect(func(idx: int): GameManager.handle_unlock_slot("vault", idx))
		slots.append(slot)
		add_child(slot)

func _on_player_data_changed() -> void:
	refresh_display()

# ── 卡牌拖放到此槽位（仅接收来自手牌的拖放） ──
func _on_card_dropped(target_index: int, card: CardInfo, source: String, source_index: int) -> void:
	if source != "hand":
		DragSystem.cancel_drag()
		return  # 保险箱只接收手牌拖入

	_handle_hand_to_vault(card, source_index, target_index)
	DragSystem.notify_drop_completed(card, source, "vault")


func _handle_hand_to_vault(card: CardInfo, hand_idx: int, vault_target_idx: int) -> void:
	var hand = GameManager.player_data.hand_cards
	if hand_idx < hand.size() and hand[hand_idx] != null:
		hand[hand_idx] = null  # 清空手牌槽

	# 加入保险箱目标槽
	var vault = GameManager.player_data.vault_cards
	while vault.size() <= vault_target_idx:
		vault.append(null)
	if vault_target_idx < vault.size():
		if vault[vault_target_idx] != null:
			# 目标已占用，找下一个空槽
			var placed = false
			for i in range(GameManager.player_data.vault_slots):
				if i >= vault.size():
					vault.append(card)
					placed = true
					break
				if vault[i] == null:
					vault[i] = card
					placed = true
					break
			if not placed:
				hand[hand_idx] = card  # 回退
				print("[VaultUI] 保险箱已满")
				return
		else:
			vault[vault_target_idx] = card
	else:
		vault.append(card)

	# 选中状态可能因数据变化而失效，清除
	_clear_selection()
	GameManager.player_data.changed.emit()
	card_dragged.emit(card, vault_target_idx)


func refresh_display() -> void:
	var cards = GameManager.player_data.vault_cards
	for i in range(slot_count):
		if i >= slots.size():
			continue
		# 应用锁定状态
		var unlocked = true
		if i < _raw_slot_data.size():
			unlocked = _raw_slot_data[i].get("unlocked", true)
		slots[i].set_unlocked(unlocked)
		
		if i < cards.size() and cards[i] != null:
			slots[i].set_card(cards[i], i)
		else:
			slots[i].clear_slot()

		# 恢复选中高亮
		_update_slot_selection_visual(i)

	var label = get_node_or_null("SlotLabel") as Label
	if label != null:
		label.text = "%d / %d 格" % [cards.size(), slot_count]

	# 更新合成按钮状态
	_update_synthesize_button()

func _on_slot_clicked(index: int) -> void:
	if index >= slots.size():
		return
	var slot = slots[index]
	if not slot.is_occupied or not slot.is_unlocked():
		return

	# 切换选中状态
	if _selected_slots.has(index):
		_selected_slots.erase(index)
	else:
		if _selected_slots.size() >= MAX_SELECT:
			# 移除最旧的选择
			var old = _selected_slots.pop_front()
			_update_slot_selection_visual(old)
		_selected_slots.append(index)

	# 更新视觉
	for i in slots.size():
		_update_slot_selection_visual(i)

	_update_synthesize_button()

	var card = slot.get_card()
	if card != null:
		card_clicked.emit(card)

func _update_slot_selection_visual(slot_idx: int) -> void:
	if slot_idx >= slots.size():
		return
	var slot = slots[slot_idx]
	var is_selected = _selected_slots.has(slot_idx)

	# 清理旧选中框、序号背景和序号标签
	var to_remove: Array[Node] = []
	for child in slot.get_children():
		if child is ColorRect and child.name in ["VaultSelectHighlight", "VaultSelectNumBg"]:
			to_remove.append(child)
		if child is Label and child.name == "VaultSelectNum":
			to_remove.append(child)
	for node in to_remove:
		slot.remove_child(node)
		node.queue_free()

	if is_selected:
		var highlight = ColorRect.new()
		highlight.name = "VaultSelectHighlight"
		highlight.set_anchors_preset(Control.PRESET_FULL_RECT)
		highlight.position = Vector2(-2, -2)
		highlight.size = slot.size + Vector2(4, 4)
		highlight.color = SELECT_BORDER_COLOR
		highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(highlight)

		# 右上角显示序号
		var order = _selected_slots.find(slot_idx)
		if order >= 0:
			var num_label = Label.new()
			num_label.name = "VaultSelectNum"
			num_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
			num_label.position = Vector2(-4, 4)
			num_label.size = Vector2(20, 20)
			num_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			num_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			num_label.text = str(order + 1)
			num_label.add_theme_font_size_override("font_size", 12)
			num_label.add_theme_color_override("font_color", Color(0, 0, 0, 1))
			# 背景圆
			var bg = ColorRect.new()
			bg.name = "VaultSelectNumBg"
			bg.set_anchors_preset(Control.PRESET_TOP_RIGHT)
			bg.position = Vector2(-6, 2)
			bg.size = Vector2(24, 24)
			bg.color = SELECT_BORDER_COLOR
			bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slot.add_child(bg)
			slot.add_child(num_label)

func _clear_selection() -> void:
	_selected_slots.clear()
	for i in slots.size():
		_update_slot_selection_visual(i)
	_update_synthesize_button()

func _update_synthesize_button() -> void:
	if _synthesize_btn == null:
		return

	var count = _selected_slots.size()
	if count < 5:
		_synthesize_btn.visible = count > 0
		_synthesize_btn.text = "✨ 合成 (%d/5)" % count
		_synthesize_btn.disabled = true
		return

	# 选中5张，检查合成条件
	var vault = GameManager.player_data.vault_cards
	var selected_cards: Array[CardInfo] = []
	for idx in _selected_slots:
		if idx < vault.size() and vault[idx] != null:
			selected_cards.append(vault[idx])

	if selected_cards.size() < 5:
		_synthesize_btn.visible = true
		_synthesize_btn.text = "✨ 合成 (%d/5) ✗" % count
		_synthesize_btn.disabled = true
		return

	# 验证合成条件：同名同色同系列编号1-5
	var valid = _validate_synthesis_cards(selected_cards)
	_synthesize_btn.visible = true
	if valid:
		_synthesize_btn.text = "✨ 合成 (5/5) ✓"
		_synthesize_btn.disabled = false
	else:
		_synthesize_btn.text = "✨ 合成 (5/5) ✗"
		_synthesize_btn.disabled = true

func _validate_synthesis_cards(cards: Array[CardInfo]) -> bool:
	if cards.size() != 5:
		return false

	var series = cards[0].series_name
	var deck = cards[0].deck_name
	var color = cards[0].color
	var numbers: Array[int] = []

	for c in cards:
		if c.series_name != series or c.deck_name != deck or c.color != color:
			return false
		numbers.append(c.card_number)

	numbers.sort()
	return numbers == [1, 2, 3, 4, 5]

func _on_synthesize_pressed() -> void:
	if _selected_slots.size() != 5:
		return

	var vault = GameManager.player_data.vault_cards
	var selected_cards: Array[CardInfo] = []
	for idx in _selected_slots:
		if idx < vault.size() and vault[idx] != null:
			selected_cards.append(vault[idx])

	if not _validate_synthesis_cards(selected_cards):
		return

	_synthesize_btn.disabled = true
	_synthesize_btn.text = "合成中..."

	# 调用后端 API：保险箱合成
	var resp = await ApiClient.synthesize(_selected_slots.duplicate(), "vault")

	if resp["success"]:
		_synthesize_btn.text = "✅ 合成成功"
		var result_data: Dictionary = resp["data"]

		# 清除保险箱中被消耗的卡牌（按索引排序后从高到低删除）
		var sorted_indices = _selected_slots.duplicate()
		sorted_indices.sort()
		for i in range(sorted_indices.size() - 1, -1, -1):
			var idx = sorted_indices[i]
			if idx < vault.size():
				vault[idx] = null  # 置空

		# 金币奖励
		var gold = result_data.get("gold_reward", 0)
		if gold > 0:
			GameManager.player_data.add_gold(gold)

		# 添加套牌
		var deck_data = result_data.get("deck", {})
		if not deck_data.is_empty():
			DeckSystem.add_synthesized_deck(deck_data)

		# 清除选中状态
		_clear_selection()
		GameManager.player_data.changed.emit()

		# 延迟刷新
		await get_tree().create_timer(1.5).timeout
		_synthesize_btn.text = "✨ 合成 (0/5)"
		_synthesize_btn.visible = false
	else:
		_synthesize_btn.text = "❌ 合成失败"
		_synthesize_btn.disabled = false
		_update_synthesize_button()
		print("[VaultUI] 合成失败: ", resp.get("error", "未知错误"))
		await get_tree().create_timer(2.0).timeout
		_update_synthesize_button()

# ── 全局拖拽事件 ──

func _on_drag_ended(_card: CardInfo, _from: String, _to: String) -> void:
	_refresh_all()


func _on_drag_cancelled() -> void:
	_refresh_all()


func _refresh_all() -> void:
	refresh_display()
