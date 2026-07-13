extends Node


func _ready() -> void:
	await get_tree().process_frame

	GameManager.player_data.hand_slots = 16
	GameManager.player_data.vault_slots = 16
	GameManager.player_data.vault_cards = []
	GameManager.player_data.hand_cards = [
		_make_card(101, "选择测试A", 1),
		_make_card(102, "选择测试B", 2),
	]
	for i in range(14):
		GameManager.player_data.hand_cards.append(null)

	var hand_ui := HandAreaUI.new()
	hand_ui.size = Vector2(1200, 600)
	add_child(hand_ui)
	await get_tree().process_frame
	hand_ui.refresh_display()
	await get_tree().process_frame

	var slot0 := hand_ui.slots[0] as CardSlotUI
	var slot1 := hand_ui.slots[1] as CardSlotUI
	if slot0 == null or slot1 == null or not slot0.is_occupied or not slot1.is_occupied:
		return _fail("hand_slots_not_ready")

	var bg := slot0.card_display.get("_card_bg") as ColorRect
	if bg == null:
		return _fail("card_background_missing")
	var bg_before := bg.color
	slot0.set_selected(true)
	if bg.color != bg_before:
		return _fail("selected_changed_card_background")
	slot0.set_selected(false)

	var selected_highlight := slot0.find_child("SelectedHighlight", false, false) as Panel
	if selected_highlight == null:
		return _fail("selected_highlight_missing")
	if selected_highlight.get_index() >= slot0.card_display.get_index():
		return _fail("selected_highlight_above_card")

	slot0.last_click_button_index = MOUSE_BUTTON_LEFT
	hand_ui._on_slot_clicked(0)
	if hand_ui.get_selected_hand_index() != 0:
		return _fail("left_click_did_not_select")

	slot0.last_click_button_index = MOUSE_BUTTON_LEFT
	hand_ui._on_slot_clicked(0)
	if hand_ui.get_selected_hand_index() != 0:
		return _fail("left_click_same_card_cleared")

	slot0.last_click_button_index = MOUSE_BUTTON_RIGHT
	hand_ui._on_slot_clicked(0)
	if hand_ui.get_selected_hand_index() != -1:
		return _fail("right_click_same_card_not_cleared")

	slot0.last_click_button_index = MOUSE_BUTTON_LEFT
	hand_ui._on_slot_clicked(0)
	slot1.last_click_button_index = MOUSE_BUTTON_LEFT
	hand_ui._on_slot_clicked(1)
	if hand_ui.get_selected_hand_index() != 1:
		return _fail("left_click_other_card_did_not_switch")

	slot1.last_click_button_index = MOUSE_BUTTON_RIGHT
	hand_ui._on_slot_clicked(1)
	if hand_ui.get_selected_hand_index() != -1:
		return _fail("right_click_selected_other_not_cleared")

	slot0.last_click_button_index = MOUSE_BUTTON_LEFT
	hand_ui._on_slot_clicked(0)
	hand_ui._input(_mouse_press(MOUSE_BUTTON_LEFT, Vector2(2, 2)))
	if hand_ui.get_selected_hand_index() != -1:
		return _fail("outside_left_click_not_cleared")

	slot0.last_click_button_index = MOUSE_BUTTON_LEFT
	hand_ui._on_slot_clicked(0)
	var discard_button := hand_ui.get("_btn_discard") as Button
	if discard_button == null:
		return _fail("discard_button_missing")
	hand_ui._input(_mouse_press(MOUSE_BUTTON_LEFT, discard_button.get_global_rect().get_center()))
	if hand_ui.get_selected_hand_index() != 0:
		return _fail("action_button_click_cleared_selection")

	var hand_center := hand_ui.get_global_rect().get_center()
	hand_ui._input(_mouse_press(MOUSE_BUTTON_WHEEL_UP, hand_center))
	await get_tree().create_timer(HandAreaUI.PAGE_ROLL_DURATION + 0.08).timeout
	if hand_ui.current_page != 1:
		return _fail("wheel_up_did_not_page_hand")
	hand_ui._input(_mouse_press(MOUSE_BUTTON_WHEEL_DOWN, hand_center))
	await get_tree().create_timer(HandAreaUI.PAGE_ROLL_DURATION + 0.08).timeout
	if hand_ui.current_page != 0:
		return _fail("wheel_down_did_not_page_hand")

	print("HAND_SELECTION_BEHAVIOR ok")
	get_tree().quit(0)


func _mouse_press(button: MouseButton, position: Vector2) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = true
	event.position = position
	event.global_position = position
	return event


func _make_card(id_value: int, name: String, number: int) -> CardInfo:
	return CardInfo.new({
		"id": str(id_value),
		"series_name": "选择测试系列",
		"deck_name": "选择测试卡组",
		"card_number": number,
		"color": "white",
		"card_name": name,
		"description": "手牌选中行为测试卡。",
	})


func _fail(reason: String) -> void:
	push_error("HAND_SELECTION_BEHAVIOR " + reason)
	get_tree().quit(1)
