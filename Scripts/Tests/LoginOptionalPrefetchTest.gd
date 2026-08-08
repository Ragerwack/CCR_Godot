extends Node

func _ready() -> void:
	Localization.set_locale("ko")
	GameManager.player_data = PlayerData.new()
	GameManager.vault_raw_slot_data = []
	GameManager.vault_slot_quote = {}
	GameManager.player_data.vault_cards = []
	GameManager.player_data.vault_slots = 0

	var results := {
		"level": {
			"success": true,
			"data": {
				"level": 6,
				"exp": 120,
				"expInLevel": 120,
				"expForNext": 400,
			},
		},
		"vault": {
			"success": true,
			"data": [
				{
					"slot_index": 0,
					"unlocked": true,
					"card_def_id": 101,
					"color": "blue",
					"card_def": {
						"id": 101,
						"series_id": 2,
						"deck_def_id": 3,
						"series_asset_id": 1,
						"deck_asset_id": 1,
						"card_asset_id": 1,
						"number": 1,
					},
				},
				{"slot_index": 1, "unlocked": true, "card_def_id": null},
				{"slot_index": 2, "unlocked": false, "card_def_id": null},
			],
		},
		"vault_quote": {
			"success": true,
			"data": {
				"next_slot_index": 2,
				"costs": {"gold": 20, "gem": 10},
			},
		},
		"config": {"success": true, "data": {}},
	}

	var summary: Dictionary = GameManager.call("_apply_optional_login_batch_results", results, true)
	if not bool(summary.get("vault", false)):
		return _fail("vault_prefetch_summary_false")
	if not bool(summary.get("vault_quote", false)):
		return _fail("vault_quote_prefetch_summary_false")
	if not GameManager.is_cache_loaded("vault"):
		return _fail("vault_cache_loaded_false")
	if GameManager.player_data.vault_cards.size() < 2:
		return _fail("vault_cards_not_loaded")
	var first_card: CardInfo = GameManager.player_data.vault_cards[0]
	if first_card == null or first_card.card_name != "각성의 순간":
		return _fail("vault_first_card_wrong")
	if GameManager.player_data.vault_cards[1] != null:
		return _fail("vault_empty_slot_wrong")
	if GameManager.player_data.vault_slots != 2:
		return _fail("vault_unlocked_count_wrong")
	if int(GameManager.vault_slot_quote.get("next_slot_index", -1)) != 2:
		return _fail("vault_quote_not_loaded")
	if int(GameManager.player_data.level) != 6:
		return _fail("level_not_applied")

	print("LOGIN_OPTIONAL_PREFETCH ok vault=true quote=true")
	get_tree().quit(0)

func _fail(message: String) -> void:
	push_error("LOGIN_OPTIONAL_PREFETCH " + message)
	get_tree().quit(1)
