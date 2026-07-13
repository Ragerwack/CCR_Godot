extends Node

func _ready() -> void:
	ApiClient.logout()
	Localization.set_locale("zh-CN")
	_prepare_player_data()

	var main := MainUI.new()
	add_child(main)
	await get_tree().process_frame
	main.call("_set_game_ui_visible", true)
	await get_tree().process_frame
	await get_tree().process_frame

	var pool_ui := main.get("_card_pool_ui") as CardPoolUI
	var hand_ui := main.get("_hand_area_ui") as HandAreaUI
	if pool_ui == null or hand_ui == null:
		return _fail("draw_areas_missing")

	var card := CardDataManager.get_cards_by_deck_id(1)[0] as CardInfo
	CardPoolSystem.current_pool[0] = card
	GameManager.player_data.pool_cards[0] = card
	CardPoolSystem.pool_updated.emit(CardPoolSystem.current_pool)
	await get_tree().process_frame

	main._on_card_pool_double_click(card, 0)
	if pool_ui.slots[0].card_display.visible or hand_ui.slots[0].card_display.visible:
		return _fail("pool_to_hand_endpoints_visible_during_flight")
	if CardPoolSystem.current_pool[0] != null or GameManager.player_data.hand_cards[0] != card:
		return _fail("pool_to_hand_data_not_moved")
	if _flying_card_count() != 1:
		return _fail("pool_to_hand_flying_copy_count_wrong")
	await get_tree().create_timer(DragSystem.QUICK_MOVE_TRANSFER_DURATION + 0.05).timeout
	if not hand_ui.slots[0].card_display.visible or _flying_card_count() != 0:
		return _fail("pool_to_hand_animation_not_completed")

	main._on_hand_double_click(card, 0)
	if hand_ui.slots[0].card_display.visible or pool_ui.slots[0].card_display.visible:
		return _fail("hand_to_pool_endpoints_visible_during_flight")
	if GameManager.player_data.hand_cards[0] != null or CardPoolSystem.current_pool[0] != card:
		return _fail("hand_to_pool_data_not_moved")
	if _flying_card_count() != 1:
		return _fail("hand_to_pool_flying_copy_count_wrong")
	await get_tree().create_timer(DragSystem.QUICK_MOVE_TRANSFER_DURATION + 0.05).timeout
	if not pool_ui.slots[0].card_display.visible or _flying_card_count() != 0:
		return _fail("hand_to_pool_animation_not_completed")

	print("QUICK_MOVE_ANIMATION ok duration=0.2 endpoints_hidden=true")
	get_tree().quit(0)

func _prepare_player_data() -> void:
	GameManager.player_data.pool_slots = 16
	GameManager.player_data.hand_slots = 16
	GameManager.player_data.pool_cards = []
	GameManager.player_data.hand_cards = []
	CardPoolSystem.current_pool = []
	for index in range(16):
		GameManager.player_data.pool_cards.append(null)
		GameManager.player_data.hand_cards.append(null)
		CardPoolSystem.current_pool.append(null)

func _flying_card_count() -> int:
	var count := 0
	for child in get_tree().root.get_children():
		if child is CardDisplay and child.z_index == 4096:
			count += 1
	return count

func _fail(reason: String) -> void:
	push_error("QUICK_MOVE_ANIMATION " + reason)
	get_tree().quit(1)
