extends Node

func _ready() -> void:
	ApiClient._auth_token = ""
	GameManager.player_data.vault_slots = 4
	GameManager.vault_raw_slot_data = [
		{"slot_index": 0, "unlocked": true},
		{"slot_index": 1, "unlocked": true},
		{"slot_index": 2, "unlocked": true},
		{"slot_index": 3, "unlocked": false},
	]

	var card_a := _make_card(101, "测试卡A", 1)
	var card_b := _make_card(102, "测试卡B", 2)
	GameManager.player_data.vault_cards = [card_a, card_b, null, null]

	var vault_ui := VaultUI.new()
	add_child(vault_ui)
	await get_tree().process_frame

	if not await vault_ui._handle_vault_to_vault(card_a, 0, 1):
		return _fail("swap_returned_false")
	if GameManager.player_data.vault_cards[0] != card_b or GameManager.player_data.vault_cards[1] != card_a:
		return _fail("swap_data_wrong")

	if not await vault_ui._handle_vault_to_vault(card_a, 1, 2):
		return _fail("move_returned_false")
	if GameManager.player_data.vault_cards[1] != null or GameManager.player_data.vault_cards[2] != card_a:
		return _fail("move_to_empty_wrong")

	if await vault_ui._handle_vault_to_vault(card_a, 2, 3):
		return _fail("locked_target_allowed")
	if GameManager.player_data.vault_cards[2] != card_a or GameManager.player_data.vault_cards[3] != null:
		return _fail("locked_target_changed_data")

	print("VAULT_REORDER ok")
	get_tree().quit(0)


func _make_card(id_value: int, name: String, number: int) -> CardInfo:
	return CardInfo.new({
		"id": str(id_value),
		"series_name": "测试系列",
		"deck_name": "保险箱拖拽测试",
		"card_number": number,
		"color": "white",
		"card_name": name,
		"description": "保险箱换位测试卡。",
	})


func _fail(reason: String) -> void:
	push_error("VAULT_REORDER " + reason)
	get_tree().quit(1)
