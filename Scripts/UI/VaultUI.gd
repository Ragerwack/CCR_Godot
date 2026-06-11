extends Control
class_name VaultUI

signal card_clicked(card: CardInfo)
signal card_dragged(card: CardInfo, from_slot: int)

@export var columns: int = 8

var slot_count: int = 2
var slots: Array[CardSlotUI] = []
var _raw_slot_data: Array = []  # 服务端原始槽位数据（含 unlocked 等信息）
var _slot_viewport: ScrollContainer = null
var _slot_canvas: Control = null

# ── 选中合成相关 ──
var _selected_slots: Array[int] = []     # 选中的槽位索引（最多5个）
var _synthesize_btn: Button = null


const MAX_SELECT: int = 5
const SELECT_BORDER_COLOR: Color = Color(1.0, 0.84, 0.0, 0.7)  # 金色
const VAULT_COLUMNS: int = 8
const MAX_VISIBLE_ROWS: int = 4
const EXTRA_LOCKED_ROWS: int = 1

func _ready() -> void:
	columns = VAULT_COLUMNS
	slot_count = _calculate_render_slot_count()
	setup_ui()
	GameManager.player_data.changed.connect(_on_player_data_changed)

	# 监听拖拽事件
	if DragSystem != null:
		DragSystem.drag_ended.connect(_on_drag_ended)
		DragSystem.drag_cancelled.connect(_on_drag_cancelled)

func _load_from_server() -> void:
	await GameManager.sync_vault_from_server()
	_update_slot_count_from_server()
	refresh_display()

func setup_ui() -> void:
	# 标题
	var title = Label.new()
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.position = Vector2(0, 10)
	title.size = Vector2(400, 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.text = Localization.t("ui.vault.title")
	add_child(title)

	# 槽位标签
	var slot_label = Label.new()
	slot_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	slot_label.position = Vector2(0, 45)
	slot_label.size = Vector2(200, 25)
	slot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	slot_label.text = Localization.t("ui.vault.slot_count", [GameManager.player_data.vault_cards.size(), slot_count])
	slot_label.name = "SlotLabel"
	add_child(slot_label)

	_slot_viewport = ScrollContainer.new()
	_slot_viewport.name = "VaultSlotViewport"
	_slot_viewport.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_slot_viewport)

	_slot_canvas = Control.new()
	_slot_canvas.name = "VaultSlotCanvas"
	_slot_viewport.add_child(_slot_canvas)

	# ── 合成按钮（初始隐藏） ──
	_synthesize_btn = Button.new()
	_synthesize_btn.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_synthesize_btn.position = Vector2(0, -60)
	_synthesize_btn.size = Vector2(140, 40)
	_synthesize_btn.text = Localization.t("ui.synthesis.vault.count", [0])
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
	var render_rows := maxi(1, int(ceil(float(slot_count) / float(columns))))
	var visible_rows := mini(MAX_VISIBLE_ROWS, render_rows)
	var total_width = columns * slot_size.x + (columns - 1) * slot_spacing
	var content_height = render_rows * slot_size.y + (render_rows - 1) * slot_spacing
	var viewport_height = visible_rows * slot_size.y + (visible_rows - 1) * slot_spacing
	var available_width = size.x if size.x > 0.0 else get_viewport_rect().size.x
	var start_x = (available_width - total_width) / 2
	var start_y = 85.0

	if _slot_viewport != null:
		_slot_viewport.position = Vector2(start_x, start_y)
		_slot_viewport.size = Vector2(total_width, viewport_height)
		_slot_viewport.custom_minimum_size = _slot_viewport.size
	if _slot_canvas != null:
		_slot_canvas.size = Vector2(total_width, content_height)
		_slot_canvas.custom_minimum_size = _slot_canvas.size

	for i in range(slots.size(), slot_count):
		var slot = CardSlotUI.new()
		slot.slot_index = i
		slot.custom_minimum_size = slot_size
		slot.area_type = "vault"
		slot.can_drag_from = false  # 保险箱卡牌不可拖出
		slot.slot_clicked.connect(_on_slot_clicked)
		slot.card_dropped.connect(_on_card_dropped)
		slot.slot_unlock_requested.connect(func(idx: int): GameManager.handle_unlock_slot("vault", idx))
		slots.append(slot)
		if _slot_canvas != null:
			_slot_canvas.add_child(slot)
		else:
			add_child(slot)

	for i in range(slots.size()):
		var row = i / columns
		var col = i % columns
		var x = col * (slot_size.x + slot_spacing)
		var y = row * (slot_size.y + slot_spacing)
		slots[i].position = Vector2(x, y)
		slots[i].visible = i < slot_count

func _on_player_data_changed() -> void:
	refresh_display()

# ── 卡牌拖放到此槽位（仅接收来自手牌的拖放） ──
func _on_card_dropped(target_index: int, card: CardInfo, source: String, source_index: int) -> void:
	if source != "hand":
		DragSystem.cancel_drag()
		return  # 保险箱只接收手牌拖入

	var ok := await _handle_hand_to_vault(card, source_index, target_index)
	if ok:
		DragSystem.notify_drop_completed(card, source, "vault")
	else:
		DragSystem.cancel_drag()


func _handle_hand_to_vault(card: CardInfo, hand_idx: int, vault_target_idx: int) -> bool:
	var hand = GameManager.player_data.hand_cards
	var vault = GameManager.player_data.vault_cards
	if hand_idx < 0 or hand_idx >= hand.size() or hand[hand_idx] == null:
		print("[VaultUI] 手牌槽位无效")
		return false

	var target_idx := vault_target_idx
	if target_idx < 0 or target_idx >= GameManager.player_data.vault_slots or not _is_vault_slot_unlocked(target_idx):
		target_idx = -1
	elif target_idx < vault.size() and vault[target_idx] != null:
		target_idx = -1

	if target_idx < 0:
		for i in range(GameManager.player_data.vault_slots):
			if not _is_vault_slot_unlocked(i):
				continue
			if i >= vault.size() or vault[i] == null:
				target_idx = i
				break

	if target_idx < 0:
		print("[VaultUI] 保险箱已满")
		return false

	var sync_resp := await GameManager.sync_pool_hand_layout()
	if not sync_resp.get("success", false):
		print("[VaultUI] 存保险箱前同步失败: ", sync_resp.get("error", ""))
		return false

	var resp := await ApiClient.move_to_vault("hand", hand_idx, target_idx)
	if not resp.get("success", false):
		print("[VaultUI] 存保险箱失败: ", resp.get("error", ""))
		return false

	hand[hand_idx] = null

	while vault.size() <= target_idx:
		vault.append(null)
	vault[target_idx] = card

	# 选中状态可能因数据变化而失效，清除
	_clear_selection()
	GameManager.player_data.changed.emit()
	card_dragged.emit(card, target_idx)
	return true


func refresh_display() -> void:
	var render_started := Time.get_ticks_msec()
	FileLogger.perf("ui_render_start", {"page": "vault", "component": "slot_grid"})
	var cards = GameManager.player_data.vault_cards
	_raw_slot_data = GameManager.vault_raw_slot_data
	_update_slot_count_from_server()
	_create_slot_grid()
	for i in range(slot_count):
		if i >= slots.size():
			continue
		# 应用锁定状态
		var unlocked := _is_vault_slot_unlocked(i)
		slots[i].set_unlocked(unlocked)
		
		if i < cards.size() and cards[i] != null:
			slots[i].set_card(cards[i], i)
		else:
			slots[i].clear_slot()

		# 恢复选中高亮
		_update_slot_selection_visual(i)

	var label = get_node_or_null("SlotLabel") as Label
	if label != null:
		label.text = Localization.t("ui.vault.slot_count", [_count_occupied(cards), _count_unlocked_slots()])

	# 更新合成按钮状态
	_update_synthesize_button()
	FileLogger.perf("ui_render_done", {"page": "vault", "component": "slot_grid", "slots": slot_count, "total_ms": Time.get_ticks_msec() - render_started})

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
		_synthesize_btn.text = Localization.t("ui.synthesis.vault.count", [count])
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
		_synthesize_btn.text = Localization.t("ui.synthesis.vault.invalid", [count])
		_synthesize_btn.disabled = true
		return

	# 验证合成条件：同名同色同系列编号1-5
	var valid = _validate_synthesis_cards(selected_cards)
	_synthesize_btn.visible = true
	if valid:
		_synthesize_btn.text = Localization.t("ui.synthesis.vault.valid")
		_synthesize_btn.disabled = false
	else:
		_synthesize_btn.text = Localization.t("ui.synthesis.vault.invalid", [5])
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
	_synthesize_btn.text = Localization.t("ui.synthesis.crafting")

	# 调用后端 API：保险箱合成
	var resp = await ApiClient.synthesize(_selected_slots.duplicate(), "vault")

	if resp["success"]:
		_synthesize_btn.text = Localization.t("ui.synthesis.vault.done")
		var result_data: Dictionary = resp["data"]

		# 清除保险箱中被消耗的卡牌，优先使用服务端返回的槽位，避免本地选择顺序漂移。
		var sorted_indices = _extract_consumed_indices(result_data)
		if sorted_indices.is_empty():
			sorted_indices = _selected_slots.duplicate()
		sorted_indices.sort()
		for i in range(sorted_indices.size() - 1, -1, -1):
			var idx = sorted_indices[i]
			if idx < vault.size():
				vault[idx] = null  # 置空

		# 添加套牌
		var deck_data = result_data.get("deck", {})
		if not deck_data.is_empty():
			DeckSystem.add_synthesized_deck(deck_data)

		# 清除选中状态
		_clear_selection()
		GameManager.player_data.changed.emit()

		var profile_resp := await ApiClient.get_profile()
		if profile_resp.get("success", false):
			GameManager.apply_profile(profile_resp["data"])
		await GameManager.sync_vault_from_server()
		await GameManager.sync_decks_from_server()
		refresh_display()

		_synthesize_btn.text = Localization.t("ui.synthesis.vault.count", [0])
		_synthesize_btn.visible = false
	else:
		_synthesize_btn.text = Localization.t("ui.synthesis.vault.failed")
		_synthesize_btn.disabled = false
		_update_synthesize_button()
		print("[VaultUI] 合成失败: ", resp.get("error", "未知错误"))
		await get_tree().create_timer(2.0).timeout
		_update_synthesize_button()

func _extract_consumed_indices(result_data: Dictionary) -> Array[int]:
	var consumed = result_data.get("consumed_slots", [])
	var indices: Array[int] = []
	for slot in consumed:
		if slot is Dictionary:
			var idx := int(slot.get("slot_index", -1))
			if idx >= 0:
				indices.append(idx)
	return indices

# ── 全局拖拽事件 ──

func _on_drag_ended(_card: CardInfo, _from: String, _to: String) -> void:
	_refresh_all()


func _on_drag_cancelled() -> void:
	_refresh_all()


func _refresh_all() -> void:
	refresh_display()

func _update_slot_count_from_server() -> void:
	var max_server_index := -1
	for raw in _raw_slot_data:
		if raw is Dictionary:
			max_server_index = maxi(max_server_index, int(raw.get("slot_index", -1)))

	var server_slots := max_server_index + 1
	var card_slots = GameManager.player_data.vault_cards.size()
	if server_slots > 0:
		GameManager.player_data.vault_slots = maxi(GameManager.player_data.vault_slots, server_slots)
	elif card_slots > 0:
		GameManager.player_data.vault_slots = maxi(GameManager.player_data.vault_slots, card_slots)
	slot_count = _calculate_render_slot_count()

func _calculate_render_slot_count() -> int:
	var unlocked_count := _count_unlocked_slots()
	var highest_needed_index := maxi(0, unlocked_count - 1)
	for i in range(GameManager.player_data.vault_cards.size()):
		if GameManager.player_data.vault_cards[i] != null:
			highest_needed_index = maxi(highest_needed_index, i)

	var unlocked_rows := maxi(1, int(ceil(float(highest_needed_index + 1) / float(VAULT_COLUMNS))))
	var rows_to_render := unlocked_rows + EXTRA_LOCKED_ROWS
	return rows_to_render * VAULT_COLUMNS

func _count_occupied(cards: Array) -> int:
	var count := 0
	for card in cards:
		if card != null:
			count += 1
	return count

func _count_unlocked_slots() -> int:
	if _raw_slot_data.is_empty():
		return GameManager.player_data.vault_slots
	var count := 0
	for raw in _raw_slot_data:
		if raw is Dictionary and raw.get("unlocked", false):
			count += 1
	return count

func _is_vault_slot_unlocked(index: int) -> bool:
	if index < 0:
		return false
	for raw in _raw_slot_data:
		if raw is Dictionary and int(raw.get("slot_index", -1)) == index:
			return raw.get("unlocked", false)
	return _raw_slot_data.is_empty() and index < GameManager.player_data.vault_slots
