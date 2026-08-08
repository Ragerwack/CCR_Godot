extends Node

func _ready() -> void:
	# 测试只隔离当前进程的登录态，不读写开发者本机保存的 token，也不访问线上账号。
	ApiClient._auth_token = ""
	ApiClient._refresh_token = ""
	GameManager.reset_account_state()
	GameManager.player_data.tutorial_completed = false
	GameManager.player_data.tutorial_state = "IDENTIFYING_COMPLETE_SET"

	var cards: Array = []
	for number in range(1, 6):
		cards.append(CardInfo.new({
			"id": str(7000 + number),
			"deck_definition_id": 701,
			"series_definition_id": 70,
			"series_name": "测试系列",
			"deck_name": "测试套组",
			"card_number": number,
			"color": "white",
		}))
	cards.append(CardInfo.new({"id": "8001", "deck_definition_id": 801, "card_number": 1, "color": "white"}))
	cards.append(CardInfo.new({"id": "8002", "deck_definition_id": 801, "card_number": 2, "color": "white"}))
	cards.shuffle()

	var controller := TutorialController.new()
	# 双保险：即使未来测试注入临时 token，也禁止教程状态保存 flush。
	controller.set("_server_save_in_flight", true)
	add_child(controller)
	# 新号卡池会以 8 个 null 保存已解锁空槽；教程不得把它误判为首抽后套组丢失。
	CardPoolSystem.current_pool = [null, null, null, null, null, null, null, null]
	controller.state = "WAITING_DRAW_PAGE_READY"
	controller.call("_reconcile_real_state")
	if controller.state == "ERROR_RECOVERABLE":
		return _fail("empty_unlocked_pool_slots_triggered_recovery_error")
	if bool(controller.call("_pool_has_collectible_cards", CardPoolSystem.current_pool)):
		return _fail("empty_unlocked_pool_slots_reported_as_cards")
	if not bool(controller.call("_pool_has_collectible_cards", cards)):
		return _fail("real_pool_cards_not_detected")
	controller.state = "IDENTIFYING_COMPLETE_SET"
	if not bool(controller.call("_identify_complete_set", cards)):
		return _fail("complete_set_not_identified")
	if GameManager.player_data.tutorial_target_definition_id != 701:
		return _fail("wrong_definition_id")
	if GameManager.player_data.tutorial_target_color != "white":
		return _fail("wrong_color")
	if GameManager.player_data.tutorial_target_card_instance_ids.size() != 5:
		return _fail("target_reference_count_wrong")
	controller.call("_apply_local_target", {
		"target_set_definition_id": null,
		"target_color": null,
		"relic_instance_id": null,
	})
	if GameManager.player_data.tutorial_target_definition_id != 701 or GameManager.player_data.tutorial_target_color != "white":
		return _fail("null_local_snapshot_overrode_server_target")

	GameManager.player_data.hand_cards = cards.filter(func(card): return card is CardInfo and card.deck_definition_id == 701)
	var collected: Array = controller.call("_actual_collected_numbers")
	if collected != [1, 2, 3, 4, 5]:
		return _fail("real_hand_state_not_reconciled=" + str(collected))

	# 手柄两段确认必须复用真实卡池→手牌迁移，而不是只改变教程视觉状态。
	GameManager.player_data.pool_slots = 8
	GameManager.player_data.hand_slots = 8
	CardPoolSystem.current_pool = cards.duplicate()
	GameManager.player_data.pool_cards = cards.duplicate()
	GameManager.player_data.hand_cards = []
	for _index in range(8):
		GameManager.player_data.hand_cards.append(null)
	var pool_ui := CardPoolUI.new()
	pool_ui.size = Vector2(1500, 360)
	add_child(pool_ui)
	var hand_ui := HandAreaUI.new()
	hand_ui.position = Vector2(0, 380)
	hand_ui.size = Vector2(1500, 360)
	add_child(hand_ui)
	var overlay := TutorialOverlay.new()
	add_child(overlay)
	controller.set("_overlay", overlay)
	controller.bind_page(pool_ui, hand_ui, null)
	controller.call("_connect_global_signals")
	controller.state = "WAITING_DRAW_PAGE_READY"
	controller.call("_show_draw_step")
	if str(overlay.get("_message_placement")) != TutorialOverlay.MESSAGE_PLACEMENT_LEFT:
		return _fail("draw_message_not_forced_left")

	# 首抽 confirm 返回的是局部 profile，不包含教程目标字段；应用它不能清空刚识别出的目标。
	GameManager.apply_profile({"id": GameManager.player_data.user_id, "gold": 100, "gems": 50})
	if GameManager.player_data.tutorial_target_definition_id != 701:
		return _fail("partial_profile_cleared_tutorial_definition")
	if GameManager.player_data.tutorial_target_color != "white":
		return _fail("partial_profile_cleared_tutorial_color")

	# 鼠标原生拖放完成信号必须按真实手牌状态把第一步推进到第二张牌。
	controller.state = "DRAGGING_CARD_1"
	await get_tree().process_frame
	var card_one: CardInfo = controller.get("_target_cards_by_number").get(1)
	var card_one_pool_index := CardPoolSystem.current_pool.find(card_one)
	if card_one == null or card_one_pool_index < 0:
		return _fail("mouse_drag_source_card_missing")
	if not bool(hand_ui.call("_handle_pool_to_hand", card_one, card_one_pool_index, 0)):
		return _fail("mouse_drag_real_move_failed")
	if controller.state != "DRAGGING_CARD_2":
		return _fail("mouse_drag_did_not_advance=" + controller.state)
	if GameManager.player_data.tutorial_collected_numbers != [1]:
		return _fail("mouse_drag_progress_not_saved=" + str(GameManager.player_data.tutorial_collected_numbers))

	# 线上旧状态可能停在拖牌步骤但目标字段为空；必须从真实卡池+手牌重新识别并自愈。
	GameManager.player_data.tutorial_target_definition_id = 0
	GameManager.player_data.tutorial_target_color = ""
	GameManager.player_data.tutorial_target_card_instance_ids = []
	controller.set("_target_cards_by_number", {})
	# 与 test4 的生产状态一致：服务端仍停在第一张，但真实手牌已经有第 1 张。
	controller.state = "DRAGGING_CARD_1"
	controller.call("_reconcile_real_state")
	if GameManager.player_data.tutorial_target_definition_id != 701 or GameManager.player_data.tutorial_target_color != "white":
		return _fail("missing_server_target_not_reidentified")
	if controller.state != "DRAGGING_CARD_2":
		return _fail("reidentified_progress_wrong=" + controller.state)

	# 双击使用 quick_move_to_hand，不会发出 card_dragged；真实手牌变化仍必须推进教程。
	var card_two: CardInfo = controller.get("_target_cards_by_number").get(2)
	CardPoolSystem.quick_move_to_hand(card_two, 1)
	await get_tree().process_frame
	await get_tree().process_frame
	if controller.state != "DRAGGING_CARD_3":
		return _fail("double_click_quick_move_did_not_advance=" + controller.state)

	# 手柄两段确认继续从第三张牌复用同一条真实迁移链。
	if not controller.handle_controller_action(ControllerInput.ACTION_DRAW_FREE):
		return _fail("controller_first_confirm_not_consumed")
	if not controller.handle_controller_action(ControllerInput.ACTION_DRAW_FREE):
		return _fail("controller_second_confirm_not_consumed")
	if GameManager.player_data.hand_cards.filter(func(card): return card is CardInfo and card.card_number == 3 and card.deck_definition_id == 701).size() != 1:
		return _fail("controller_move_did_not_reach_real_hand_state")
	var forge_button := hand_ui.get_synthesize_button()
	forge_button.disabled = false
	controller.state = "HIGHLIGHT_FORGE_BUTTON"
	controller.call("_show_forge_step")
	if str(overlay.get("_message_placement")) != TutorialOverlay.MESSAGE_PLACEMENT_LEFT:
		return _fail("forge_message_not_forced_left")

	for locale_code in Localization.SUPPORTED_LOCALES:
		Localization.set_locale(locale_code)
		for key in [
			"ui.tutorial.draw_first", "ui.tutorial.drag_first", "ui.tutorial.drag_progress",
			"ui.tutorial.select_card", "ui.tutorial.forge", "ui.tutorial.museum",
			"ui.tutorial.first_collectible", "ui.tutorial.error_continue",
			"ui.tutorial.controller_drag", "ui.tutorial.controller_move",
		]:
			if Localization.t(key, [2, 5] if key == "ui.tutorial.drag_progress" else []) == key:
				return _fail("missing_localization=" + locale_code + ":" + key)

	print("TUTORIAL_STATE_MACHINE ok definition=701 color=white numbers=1-5 locales=5")
	get_tree().quit(0)

func _fail(message: String) -> void:
	push_error("TUTORIAL_STATE_MACHINE " + message)
	get_tree().quit(1)
