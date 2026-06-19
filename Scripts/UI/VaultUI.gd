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
var _gold_unlock_btn: Button = null
var _gold_unlock_cost_label: Label = null
var _gem_unlock_btn: Button = null
var _gem_unlock_cost_label: Label = null
var _unlock_buttons_busy: bool = false

# ── 选中合成相关 ──
var _selected_slots: Array[int] = []     # 单选槽位；保留数组形态便于复用现有高亮逻辑
var _synthesize_btn: Button = null


const SELECT_BORDER_COLOR: Color = Color(1.0, 0.84, 0.0, 0.7)  # 金色
const VAULT_COLUMNS: int = 8
const MAX_VISIBLE_ROWS: int = 4
const EXTRA_LOCKED_ROWS: int = 1
const VAULT_GRID_LEFT_MARGIN: float = 40.0
const UNLOCK_PANEL_WIDTH: float = 130.0
const UNLOCK_PANEL_RIGHT_MARGIN: float = 10.0

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
	await GameManager.sync_vault_slot_quote_from_server()
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
	_synthesize_btn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_synthesize_btn.offset_left = -120
	_synthesize_btn.offset_right = -10
	_synthesize_btn.offset_top = -46
	_synthesize_btn.offset_bottom = -10
	_synthesize_btn.custom_minimum_size = Vector2(110, 36)
	_synthesize_btn.text = Localization.t("ui.synthesis.vault.count", [0])
	_synthesize_btn.visible = true
	_synthesize_btn.disabled = true
	_synthesize_btn.pressed.connect(_on_synthesize_pressed)
	add_child(_synthesize_btn)

	_create_unlock_panel()
	_create_slot_grid()
	refresh_display()

func _create_unlock_panel() -> void:
	var panel_width := UNLOCK_PANEL_WIDTH

	var panel = VBoxContainer.new()
	panel.name = "VaultUnlockPanel"
	panel.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	panel.offset_left = -panel_width - UNLOCK_PANEL_RIGHT_MARGIN
	panel.offset_right = -UNLOCK_PANEL_RIGHT_MARGIN
	panel.offset_top = -72
	panel.offset_bottom = 72
	panel.add_theme_constant_override("separation", 8)
	add_child(panel)

	_gold_unlock_btn = Button.new()
	_gold_unlock_btn.custom_minimum_size = Vector2(panel_width, 38)
	_gold_unlock_btn.text = Localization.t("ui.vault.unlock_gold")
	_gold_unlock_btn.pressed.connect(func(): _on_unlock_slot_pressed("gold"))
	panel.add_child(_gold_unlock_btn)

	_gold_unlock_cost_label = Label.new()
	_gold_unlock_cost_label.custom_minimum_size = Vector2(panel_width, 24)
	_gold_unlock_cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gold_unlock_cost_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(_gold_unlock_cost_label)

	_gem_unlock_btn = Button.new()
	_gem_unlock_btn.custom_minimum_size = Vector2(panel_width, 38)
	_gem_unlock_btn.text = Localization.t("ui.vault.unlock_gem")
	_gem_unlock_btn.pressed.connect(func(): _on_unlock_slot_pressed("gem"))
	panel.add_child(_gem_unlock_btn)

	_gem_unlock_cost_label = Label.new()
	_gem_unlock_cost_label.custom_minimum_size = Vector2(panel_width, 24)
	_gem_unlock_cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gem_unlock_cost_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(_gem_unlock_cost_label)

func _create_slot_grid() -> void:
	var slot_size = CardSlotUI.SLOT_SIZE
	var slot_spacing = 8
	var render_rows := maxi(1, int(ceil(float(slot_count) / float(columns))))
	var visible_rows := mini(MAX_VISIBLE_ROWS, render_rows)
	var total_width = columns * slot_size.x + (columns - 1) * slot_spacing
	var content_height = render_rows * slot_size.y + (render_rows - 1) * slot_spacing
	var viewport_height = visible_rows * slot_size.y + (visible_rows - 1) * slot_spacing
	var available_width = size.x if size.x > 0.0 else get_viewport_rect().size.x
	var right_reserved = UNLOCK_PANEL_WIDTH + UNLOCK_PANEL_RIGHT_MARGIN + 10.0
	var start_x = VAULT_GRID_LEFT_MARGIN
	if start_x + total_width + right_reserved > available_width:
		start_x = maxf(8.0, (available_width - total_width - right_reserved) / 2.0)
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
		slot.can_drag_from = true
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

# ── 卡牌拖放到此槽位 ──
func _on_card_dropped(target_index: int, card: CardInfo, source: String, source_index: int) -> void:
	if source == "hand":
		var ok := await _handle_hand_to_vault(card, source_index, target_index)
		if ok:
			DragSystem.notify_drop_completed(card, source, "vault")
		else:
			DragSystem.cancel_drag()
		return

	if source == "vault":
		var ok := await _handle_vault_to_vault(card, source_index, target_index)
		if ok:
			DragSystem.notify_drop_completed(card, source, "vault")
		else:
			DragSystem.cancel_drag()
		return

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


func _handle_vault_to_vault(card: CardInfo, source_vault_idx: int, target_vault_idx: int) -> bool:
	var vault = GameManager.player_data.vault_cards
	if target_vault_idx < 0 or target_vault_idx >= GameManager.player_data.vault_slots or not _is_vault_slot_unlocked(target_vault_idx):
		print("[VaultUI] 目标保险箱槽位无效")
		return false

	source_vault_idx = _resolve_card_index(vault, card, source_vault_idx)
	if source_vault_idx < 0:
		print("[VaultUI] 源保险箱槽位无效")
		return false
	if not _is_vault_slot_unlocked(source_vault_idx):
		print("[VaultUI] 源保险箱槽位未解锁")
		return false

	while vault.size() <= maxi(source_vault_idx, target_vault_idx):
		vault.append(null)
	if source_vault_idx == target_vault_idx:
		return true

	var old_vault := vault.duplicate()
	var target_card = vault[target_vault_idx]
	if target_card != null:
		DragSystem.play_swap_animation("vault", source_vault_idx, "vault", target_vault_idx, card, target_card)
	vault[target_vault_idx] = vault[source_vault_idx]
	vault[source_vault_idx] = target_card
	_clear_selection()

	GameManager.player_data.changed.emit()
	card_dragged.emit(card, source_vault_idx)

	if ApiClient.is_logged_in():
		var sync_resp := await ApiClient.sync_vault_layout(vault)
		if not sync_resp.get("success", false):
			print("[VaultUI] 保险箱布局同步失败: ", sync_resp.get("error", ""))
			GameManager.player_data.vault_cards = old_vault
			await GameManager.sync_vault_from_server()
			GameManager.player_data.changed.emit()
			return false

	return true


func _resolve_card_index(cards: Array, card: CardInfo, preferred_idx: int) -> int:
	if preferred_idx >= 0 and preferred_idx < cards.size() and cards[preferred_idx] != null:
		return preferred_idx
	for i in range(cards.size()):
		if cards[i] != null and cards[i].get_uid() == card.get_uid():
			return i
	return -1


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

	_update_unlock_buttons()

	# 更新合成按钮状态
	_update_synthesize_button()
	FileLogger.perf("ui_render_done", {"page": "vault", "component": "slot_grid", "slots": slot_count, "total_ms": Time.get_ticks_msec() - render_started})

func _update_unlock_buttons() -> void:
	var quote: Dictionary = GameManager.vault_slot_quote
	var costs: Dictionary = quote.get("costs", {})
	var gold_cost := int(costs.get("gold", 20))
	var gem_cost := int(costs.get("gem", 10))
	var has_quote := not quote.is_empty()

	if _gold_unlock_btn != null:
		_gold_unlock_btn.disabled = _unlock_buttons_busy
	if _gem_unlock_btn != null:
		_gem_unlock_btn.disabled = _unlock_buttons_busy
	if _gold_unlock_cost_label != null:
		_gold_unlock_cost_label.text = Localization.t("ui.vault.unlock_gold_cost", [gold_cost]) if has_quote else Localization.t("ui.vault.unlock_cost_loading")
	if _gem_unlock_cost_label != null:
		_gem_unlock_cost_label.text = Localization.t("ui.vault.unlock_gem_cost", [gem_cost]) if has_quote else Localization.t("ui.vault.unlock_cost_loading")

func _on_unlock_slot_pressed(currency: String) -> void:
	if _unlock_buttons_busy:
		return
	_unlock_buttons_busy = true
	_update_unlock_buttons()

	var quote: Dictionary = GameManager.vault_slot_quote
	if quote.is_empty():
		var quote_resp := await GameManager.sync_vault_slot_quote_from_server()
		if not quote_resp.get("success", false):
			print("[VaultUI] 获取保险箱解锁报价失败: ", quote_resp.get("error", ""))
			_unlock_buttons_busy = false
			_update_unlock_buttons()
			return
		quote = GameManager.vault_slot_quote
	var slot_index := int(quote.get("next_slot_index", _count_unlocked_slots()))
	await GameManager.handle_unlock_slot("vault", slot_index, currency)

	_unlock_buttons_busy = false
	if is_inside_tree():
		refresh_display()

func _on_slot_clicked(index: int) -> void:
	if index >= slots.size():
		return
	var slot = slots[index]
	if not slot.is_occupied or not slot.is_unlocked():
		return

	# 保险箱和手牌一样，一次只允许选中一张卡牌。
	if _selected_slots.has(index):
		_selected_slots.erase(index)
	else:
		for old in _selected_slots.duplicate():
			_update_slot_selection_visual(old)
		_selected_slots.clear()
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
		highlight.position = Vector2(-2, -2)
		highlight.size = slot.size + Vector2(4, 4)
		highlight.color = SELECT_BORDER_COLOR
		highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(highlight)

func _clear_selection() -> void:
	_selected_slots.clear()
	for i in slots.size():
		_update_slot_selection_visual(i)
	_update_synthesize_button()

func _update_synthesize_button() -> void:
	if _synthesize_btn == null:
		return

	var count = _selected_slots.size()
	if count <= 0:
		_synthesize_btn.visible = true
		_synthesize_btn.text = Localization.t("ui.synthesis.vault.count", [0])
		_synthesize_btn.disabled = true
		return

	var vault = GameManager.player_data.vault_cards
	var selected_idx := int(_selected_slots[0])
	if selected_idx < 0 or selected_idx >= vault.size() or vault[selected_idx] == null:
		_synthesize_btn.visible = true
		_synthesize_btn.text = Localization.t("ui.synthesis.vault.count", [0])
		_synthesize_btn.disabled = true
		return

	var synthesis_indices := _find_synthesizable_indices_for_card(vault[selected_idx], selected_idx)
	_synthesize_btn.visible = true
	if synthesis_indices.size() == 5:
		_synthesize_btn.text = Localization.t("ui.synthesis.vault.valid")
		_synthesize_btn.disabled = false
	else:
		_synthesize_btn.text = Localization.t("ui.synthesis.vault.count", [1])
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
	if _selected_slots.size() != 1:
		return

	var vault = GameManager.player_data.vault_cards
	var selected_idx := int(_selected_slots[0])
	if selected_idx < 0 or selected_idx >= vault.size() or vault[selected_idx] == null:
		return
	var selected_slots := _find_synthesizable_indices_for_card(vault[selected_idx], selected_idx)
	if selected_slots.size() != 5:
		return

	_synthesize_btn.disabled = true
	_synthesize_btn.text = Localization.t("ui.synthesis.vault.done")

	_apply_vault_synthesis_pending_removal(selected_slots)
	_confirm_vault_synthesis_background(selected_slots)

func _find_synthesizable_indices_for_card(selected_card: CardInfo, selected_idx: int) -> Array[int]:
	if selected_card == null:
		return []
	var vault = GameManager.player_data.vault_cards
	var by_number: Dictionary = {}
	var selected_number := int(selected_card.card_number)
	if selected_number >= 1 and selected_number <= 5:
		by_number[selected_number] = selected_idx
	for i in range(vault.size()):
		var card = vault[i]
		if card == null or i == selected_idx:
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

func _confirm_vault_synthesis_background(selected_slots: Array) -> void:
	var resp = await ApiClient.synthesize(selected_slots, "vault")
	if resp["success"]:
		var result_data: Dictionary = resp["data"]
		_apply_vault_synthesis_confirmed_result(result_data)
		_sync_after_vault_synthesis_success_background()
	else:
		print("[VaultUI] 合成失败: ", resp.get("error", "未知错误"))
		await _recover_after_vault_synthesis_failure()

func _apply_vault_synthesis_pending_removal(selected_slots: Array) -> void:
	var vault = GameManager.player_data.vault_cards
	var sorted_indices := selected_slots.duplicate()
	sorted_indices.sort()
	for i in range(sorted_indices.size() - 1, -1, -1):
		var idx = sorted_indices[i]
		if idx < vault.size():
			vault[idx] = null

	_clear_selection()
	GameManager.player_data.changed.emit()
	refresh_display()

	if _synthesize_btn != null:
		_synthesize_btn.text = Localization.t("ui.synthesis.vault.count", [0])
		_synthesize_btn.visible = true
		_synthesize_btn.disabled = true

func _apply_vault_synthesis_confirmed_result(result_data: Dictionary) -> void:
	var rewards: Dictionary = result_data.get("rewards", {})
	var gold := int(result_data.get("gold_reward", rewards.get("gold", 0)))
	if gold > 0:
		GameManager.player_data.add_gold(gold)

	var gems := int(rewards.get("gems", 0))
	if gems > 0:
		GameManager.player_data.add_gems(gems)

	var deck_data = result_data.get("deck", {})
	if not deck_data.is_empty():
		DeckSystem.add_synthesized_deck(deck_data)

	GameManager.player_data.changed.emit()

func _sync_after_vault_synthesis_success_background() -> void:
	await GameManager.sync_reward_state_from_server()
	await GameManager.sync_decks_from_server()
	if is_inside_tree():
		refresh_display()

func _recover_after_vault_synthesis_failure() -> void:
	if _synthesize_btn != null:
		_synthesize_btn.text = Localization.t("ui.synthesis.vault.failed")
		_synthesize_btn.disabled = false
	await GameManager.sync_vault_from_server()
	await GameManager.sync_decks_from_server()
	if is_inside_tree():
		refresh_display()
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
