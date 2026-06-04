extends Control
class_name SynthesisPanelUI

# 合成面板 — 选择5张手牌合成套牌

signal synthesis_completed(deck_data: Dictionary)
signal synthesis_cancelled()

@export var columns: int = 8
@export var max_select: int = 5

var _hand_slots: Array[CardSlotUI] = []
var _selected_indices: Array[int] = []
var _all_hand_cards: Array = []  # 手牌数据 [{slot_index, card_def_id, color, card_def}]
var _synthesize_button: Button = null
var _status_label: Label = null
var _error_label: Label = null
var _title_label: Label = null
var _back_button: Button = null
var _select_all_button: Button = null
var _highlight_color: Color = Color(0.2, 0.8, 0.2, 0.3)  # 可合成高亮
var _selected_highlight: Color = Color(0.2, 0.5, 1.0, 0.4)  # 选中高亮

func _ready() -> void:
	setup_ui()

func setup_ui() -> void:
	# 标题
	_title_label = Label.new()
	_title_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_title_label.position = Vector2(0, 10)
	_title_label.size = Vector2(400, 30)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.text = "合成套牌 [选择5张同系列/同卡组/同色卡牌]"
	add_child(_title_label)

	# 合成按钮
	_synthesize_button = Button.new()
	_synthesize_button.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_synthesize_button.position = Vector2(-60, -60)
	_synthesize_button.size = Vector2(120, 40)
	_synthesize_button.text = "合成 (0/5)"
	_synthesize_button.disabled = true
	_synthesize_button.pressed.connect(_on_synthesize_pressed)
	add_child(_synthesize_button)

	# 一键选择按钮
	_select_all_button = Button.new()
	_select_all_button.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_select_all_button.position = Vector2(70, -60)
	_select_all_button.size = Vector2(120, 40)
	_select_all_button.text = "快速选择"
	_select_all_button.pressed.connect(_on_select_all_pressed)
	add_child(_select_all_button)

	# 返回按钮
	_back_button = Button.new()
	_back_button.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_back_button.position = Vector2(10, 10)
	_back_button.size = Vector2(60, 30)
	_back_button.text = "< 返回"
	_back_button.pressed.connect(_on_back_pressed)
	add_child(_back_button)

	# 状态显示
	_status_label = Label.new()
	_status_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_status_label.position = Vector2(-200, -30)
	_status_label.size = Vector2(400, 24)
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.text = ""
	add_child(_status_label)

	# 错误提示
	_error_label = Label.new()
	_error_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_error_label.position = Vector2(-200, -10)
	_error_label.size = Vector2(400, 24)
	_error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_error_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	_error_label.text = ""
	add_child(_error_label)

	# 合成系统已作为 Autoload 全局可用
	SynthesisSystem.synthesis_succeeded.connect(_on_synthesis_succeeded)
	SynthesisSystem.synthesis_failed.connect(_on_synthesis_failed)


	# 创建手牌槽位网格
	_create_hand_grid()
	load_hand_cards()

func _create_hand_grid() -> void:
	var slot_size = Vector2(80, 112)
	var slot_spacing = 8
	var start_x = 60
	var start_y = 60
	var max_cols = 8

	for i in range(32):  # 固定32个槽位（与HandAreaUI一致）
		var col = i % max_cols
		var row = i / max_cols
		var x = start_x + col * (slot_size.x + slot_spacing)
		var y = start_y + row * (slot_size.y + slot_spacing)

		var slot = CardSlotUI.new()
		slot.slot_index = i
		slot.position = Vector2(x, y)
		slot.slot_clicked.connect(_on_slot_clicked.bind(i))
		_hand_slots.append(slot)
		add_child(slot)

func load_hand_cards() -> void:
	# 从 GameManager 获取手牌数据（本地缓存）
	var cards = GameManager.player_data.hand_cards
	_all_hand_cards.clear()

	for i in range(cards.size()):
		var slot_data = {
			"slot_index": i,
			"card": cards[i],
			"series_name": cards[i].series_name,
			"deck_name": cards[i].deck_name,
			"card_number": cards[i].card_number,
			"color": cards[i].color,
		}
		_all_hand_cards.append(slot_data)

	refresh_display()

func refresh_display() -> void:
	var hand_size = _all_hand_cards.size()

	for i in range(_hand_slots.size()):
		if i < hand_size:
			var card_data = _all_hand_cards[i]
			_hand_slots[i].set_card(card_data["card"], i)
			_hand_slots[i].visible = true

			# 高亮选中
			if _selected_indices.has(i):
				_set_slot_highlight(_hand_slots[i], _selected_highlight)
			else:
				_set_slot_highlight(_hand_slots[i], Color.TRANSPARENT)
		else:
			_hand_slots[i].clear_slot()
			_hand_slots[i].visible = _hand_slots[i].slot_index < max(16, hand_size)

	update_button_state()

func _set_slot_highlight(slot: CardSlotUI, color: Color) -> void:
	for child in slot.get_children():
		if child is ColorRect and child.name == "Highlight":
			child.color = color
			return
	var highlight = ColorRect.new()
	highlight.name = "Highlight"
	highlight.set_anchors_preset(Control.PRESET_FULL_RECT)
	highlight.color = color
	slot.add_child(highlight)

func _on_slot_clicked(idx: int) -> void:
	if idx >= _all_hand_cards.size():
		return

	if _selected_indices.has(idx):
		_selected_indices.erase(idx)
	else:
		if _selected_indices.size() >= max_select:
			# 满了，移除第一个选择
			_selected_indices.pop_front()
		_selected_indices.append(idx)

	refresh_display()
	_check_auto_highlight()

func update_button_state() -> void:
	var count = _selected_indices.size()
	_synthesize_button.text = "合成 (%d/5)" % count
	_synthesize_button.disabled = (count != 5)

	if count == 5:
		# 检查是否满足合成条件
		var valid = _validate_selection()
		if valid:
			_synthesize_button.text = "合成 (5/5) ✓"
			_error_label.text = ""
		else:
			_synthesize_button.text = "合成 (5/5) ✗"
			_error_label.text = "选中的卡牌不符合合成条件"
	else:
		_error_label.text = ""

func _validate_selection() -> bool:
	if _selected_indices.size() != 5:
		return false

	var cards: Array = []
	for idx in _selected_indices:
		if idx < _all_hand_cards.size():
			cards.append(_all_hand_cards[idx])

	if cards.size() != 5:
		return false

	# 检查同一系列、同一卡组、同色、编号1-5
	var series = cards[0]["series_name"]
	var deck = cards[0]["deck_name"]
	var color = cards[0]["color"]
	var numbers: Array[int] = []

	for c in cards:
		if c["series_name"] != series:
			return false
		if c["deck_name"] != deck:
			return false
		if c["color"] != color:
			return false
		numbers.append(c["card_number"])

	numbers.sort()
	return numbers == [1, 2, 3, 4, 5]

func _check_auto_highlight() -> void:
	# 高亮所有可能的可合成组合
	for i in range(_hand_slots.size()):
		if not _selected_indices.has(i) and i < _all_hand_cards.size():
			_set_slot_highlight(_hand_slots[i], Color.TRANSPARENT)

func _on_select_all_pressed() -> void:
	# 自动查找可合成组合
	var cards = _all_hand_cards.duplicate()
	var found = _find_synthesizable_combo(cards)
	if found.size() == 5:
		_selected_indices = found.duplicate()
	else:
		# 清除选择
		_selected_indices.clear()
		_status_label.text = "未找到可合成组合"
		await get_tree().create_timer(2.0).timeout
		_status_label.text = ""
	refresh_display()

func _find_synthesizable_combo(cards: Array) -> Array:
	# 按 series|deck|color 分组，找恰好有5张且编号1-5的组合
	var groups: Dictionary = {}
	for i in range(cards.size()):
		var c = cards[i]
		var key = "%s|%s|%d" % [c["series_name"], c["deck_name"], c["color"]]
		if not groups.has(key):
			groups[key] = []
		groups[key].append({"index": i, "number": c["card_number"]})

	for key in groups:
		var group: Array = groups[key]
		if group.size() == 5:
			var group_numbers: Array[int] = []
			for g in group:
				group_numbers.append(g["number"])
			group_numbers.sort()
			if group_numbers == [1, 2, 3, 4, 5]:
				# 找到！返回槽位索引
				var result: Array = []
				for g in group:
					result.append(g["index"])
				return result

	return []

func _on_synthesize_pressed() -> void:
	if _selected_indices.size() != 5:
		return

	if not _validate_selection():
		_error_label.text = "选中的卡牌不符合合成条件: 需要同系列、同卡组、同色、编号1-5"
		return

	_synthesize_button.disabled = true
	_synthesize_button.text = "合成中..."
	_status_label.text = "正在合成..."
	_error_label.text = ""

	# 调用合成系统（请求后端API，从手牌合成）
	SynthesisSystem.synthesize(_selected_indices.duplicate(), "hand")

func _on_synthesis_succeeded(result: Dictionary) -> void:
	_status_label.text = "合成成功! 奖励金币: %d" % result.get("gold_reward", 0)
	_synthesize_button.disabled = true
	_synthesize_button.text = "已合成"

	# 更新本地数据 — 从高到低移除避免索引偏移
	var consumed = result.get("consumed_slots", [])
	var indices_to_remove: Array[int] = []
	for slot in consumed:
		var idx = slot.get("slot_index", -1)
		if idx >= 0:
			indices_to_remove.append(idx)
	indices_to_remove.sort()
	for i in range(indices_to_remove.size() - 1, -1, -1):
		GameManager.player_data.remove_from_hand_at(indices_to_remove[i])

	# 更新金币
	var gold = result.get("gold_reward", 0)
	if gold > 0:
		GameManager.player_data.add_gold(gold)

	# 更新套牌
	var deck_data = result.get("deck", {})
	if not deck_data.is_empty():
		DeckSystem.add_synthesized_deck(deck_data)

	synthesis_completed.emit(result)

	# 延迟刷新
	await get_tree().create_timer(1.0).timeout
	load_hand_cards()
	_selected_indices.clear()

func _on_synthesis_failed(reason: String) -> void:
	_status_label.text = ""
	_error_label.text = "合成失败: " + reason
	_synthesize_button.disabled = _selected_indices.size() != 5
	update_button_state()

	await get_tree().create_timer(3.0).timeout
	_error_label.text = ""

func _on_back_pressed() -> void:
	synthesis_cancelled.emit()
