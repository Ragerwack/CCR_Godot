extends Node


func _ready() -> void:
	await get_tree().process_frame
	var cards: Array[CardInfo] = CardDataManager.get_cards_by_deck_id(1)
	if cards.size() < 5:
		return _fail("cards_missing")

	GameManager.player_data.hand_slots = 16
	GameManager.player_data.hand_cards.clear()
	for i in range(5):
		var card := CardInfo.new(cards[i].to_dict())
		card.color = CardColor.ColorType.PURPLE
		GameManager.player_data.hand_cards.append(card)
	for i in range(11):
		GameManager.player_data.hand_cards.append(null)

	var hand_ui := HandAreaUI.new()
	add_child(hand_ui)
	await get_tree().process_frame
	hand_ui.refresh_display()

	for i in range(5):
		if not hand_ui.slots[i].is_occupied:
			return _fail("initial_slot_empty_" + str(i))

	var indices := [0, 1, 2, 3, 4]
	hand_ui.hide_synthesis_slots_for_animation(indices)
	GameManager.player_data.changed.emit()
	await get_tree().process_frame
	for i in range(5):
		if hand_ui.slots[i].is_occupied:
			return _fail("hidden_slot_redrawn_" + str(i))

	hand_ui.clear_synthesis_animation_hidden_slots()
	hand_ui.refresh_display()
	for i in range(5):
		if not hand_ui.slots[i].is_occupied:
			return _fail("slot_not_restored_after_clear_" + str(i))

	print("HAND_SYNTHESIS_HIDDEN_SLOTS ok")
	get_tree().quit(0)


func _fail(reason: String) -> void:
	push_error("HAND_SYNTHESIS_HIDDEN_SLOTS " + reason)
	get_tree().quit(1)
