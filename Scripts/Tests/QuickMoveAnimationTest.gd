extends Node

func _ready() -> void:
	# 测试只隔离当前进程，不持久清除开发者本机保存的登录凭据。
	ApiClient._auth_token = ""
	ApiClient._refresh_token = ""
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

	CardPoolSystem.current_pool[0] = null
	GameManager.player_data.pool_cards[0] = null
	GameManager.player_data.hand_cards[0] = card
	GameManager.player_data.vault_cards[0] = null
	GameManager.player_data.changed.emit()
	CardPoolSystem.pool_updated.emit(CardPoolSystem.current_pool)
	await get_tree().process_frame
	hand_ui._on_slot_clicked(0)
	main._on_hand_save_to_vault()
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	if hand_ui.slots[0].card_display.visible:
		return _fail("store_to_vault_source_visible_during_flight")
	if not await _wait_for_visible_card_display_count(card, 1, 0.5):
		return _fail("store_to_vault_visible_card_count_wrong_%d" % _visible_card_display_count(card))
	await get_tree().create_timer(1.45).timeout
	if GameManager.player_data.hand_cards[0] != null or GameManager.player_data.vault_cards[0] != card:
		return _fail("store_to_vault_data_not_moved")
	if hand_ui.slots[0].is_occupied:
		return _fail("store_to_vault_source_slot_not_empty")

	print("QUICK_MOVE_ANIMATION ok duration=0.2 endpoints_hidden=true store_source_hidden=true")
	get_tree().quit(0)

func _prepare_player_data() -> void:
	GameManager.player_data.pool_slots = 16
	GameManager.player_data.hand_slots = 16
	GameManager.player_data.vault_slots = 1
	GameManager.player_data.pool_cards = []
	GameManager.player_data.hand_cards = []
	GameManager.player_data.vault_cards = []
	CardPoolSystem.current_pool = []
	for index in range(16):
		GameManager.player_data.pool_cards.append(null)
		GameManager.player_data.hand_cards.append(null)
		CardPoolSystem.current_pool.append(null)
	GameManager.player_data.vault_cards.append(null)

func _flying_card_count() -> int:
	var count := 0
	for child in get_tree().root.get_children():
		if child is CardDisplay and child.z_index == 4096:
			count += 1
	return count

func _visible_card_display_count(card: CardInfo) -> int:
	var count := 0
	for node in _collect_nodes(get_tree().root):
		var display := node as CardDisplay
		if display == null or not display.visible or display.card == null:
			continue
		if display.card.get_uid() == card.get_uid():
			count += 1
	return count

func _wait_for_visible_card_display_count(card: CardInfo, expected_count: int, timeout_seconds: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(timeout_seconds * 1000.0)
	while Time.get_ticks_msec() <= deadline:
		if _visible_card_display_count(card) == expected_count:
			return true
		await get_tree().process_frame
	return false

func _collect_nodes(root: Node) -> Array[Node]:
	var nodes: Array[Node] = [root]
	for child in root.get_children():
		nodes.append_array(_collect_nodes(child))
	return nodes

func _fail(reason: String) -> void:
	push_error("QUICK_MOVE_ANIMATION " + reason)
	get_tree().quit(1)
