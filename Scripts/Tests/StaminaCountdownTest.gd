extends Node

func _ready() -> void:
	Localization.set_locale("zh-CN")
	_setup_zero_stamina_login_state()
	# 登录资料会按账号区域重新应用默认语言；测试需要在资料同步后固定中文断言。
	Localization.set_locale("zh-CN")

	var ui := CardPoolUI.new()
	ui.name = "StaminaCountdownCardPoolUI"
	ui.auto_warm_enabled = false
	add_child(ui)
	await get_tree().process_frame

	var countdown_label: Label = ui.get("_free_countdown_label")
	if countdown_label == null:
		_fail("countdown_label_missing")
		return
	if not countdown_label.visible:
		_fail("countdown_label_hidden")
		return
	if not countdown_label.text.begins_with("下次体力 "):
		_fail("countdown_label_text=%s" % countdown_label.text)
		return
	if GameManager.get_free_refresh_cooldown() <= 0.0:
		_fail("cooldown_not_started")
		return
	if not _assert_stamina_info_between_buttons(ui):
		return
	var first_countdown_text := countdown_label.text

	ui.queue_free()
	await get_tree().process_frame
	_setup_zero_stamina_missing_anchor_state()
	Localization.set_locale("zh-CN")
	var fallback_ui := CardPoolUI.new()
	fallback_ui.name = "StaminaCountdownMissingAnchorUI"
	fallback_ui.auto_warm_enabled = false
	add_child(fallback_ui)
	await get_tree().process_frame
	var fallback_label: Label = fallback_ui.get("_free_countdown_label")
	if fallback_label == null or not fallback_label.visible or not fallback_label.text.begins_with("下次体力 "):
		_fail("missing_anchor_countdown_hidden")
		return
	if GameManager.get_free_refresh_cooldown() <= 0.0:
		_fail("missing_anchor_cooldown_not_started")
		return

	print("STAMINA_COUNTDOWN ok text=%s cooldown=%d" % [first_countdown_text, ceili(GameManager.get_free_refresh_cooldown())])
	get_tree().quit(0)

func _setup_zero_stamina_login_state() -> void:
	var last_refresh_unix := Time.get_unix_time_from_system() - 30.0
	var last_refresh := Time.get_datetime_string_from_unix_time(int(last_refresh_unix), false) + "Z"
	GameManager.apply_login_user({
		"id": 1,
		"username": "stamina_test",
		"level": 1,
		"exp": 0,
		"gold": 1000,
		"gems": 50,
		"freeRefreshCount": 0,
		"newbieFreeRefreshCount": 0,
		"lastFreeRefreshTime": last_refresh,
		"country": "EARTH",
	})
	GameManager.player_data.pool_slots = 8
	GameManager.player_data.hand_slots = 8
	GameManager.player_data.pool_cards = []
	GameManager.player_data.hand_cards = []
	CardPoolSystem.current_pool = []
	CardPoolSystem._warm_rolls.clear()
	CardPoolSystem._warming_types.clear()
	for _i in range(8):
		GameManager.player_data.pool_cards.append(null)
		GameManager.player_data.hand_cards.append(null)
		CardPoolSystem.current_pool.append(null)

func _setup_zero_stamina_missing_anchor_state() -> void:
	_setup_zero_stamina_login_state()
	GameManager.free_refresh_count = 0
	GameManager.newbie_free_refresh_count = 0
	GameManager.last_free_refresh_time_unix = 0.0
	GameManager.call("_update_free_refresh_cooldown_from_state")

func _assert_stamina_info_between_buttons(ui: CardPoolUI) -> bool:
	var stamina_button := ui.find_child("DrawStaminaButton", true, false) as Button
	var gold_button := ui.find_child("DrawGoldButton", true, false) as Button
	var countdown_label: Label = ui.get("_free_countdown_label")
	var cost_label: Label = ui.get("_free_cost_label")
	if stamina_button == null or gold_button == null or countdown_label == null or cost_label == null:
		_fail("stamina_info_nodes_missing")
		return false
	var gap_top := stamina_button.global_position.y + stamina_button.size.y
	var gap_bottom := gold_button.global_position.y
	var countdown_center := countdown_label.global_position.y + countdown_label.size.y * 0.5
	var cost_center := cost_label.global_position.y + cost_label.size.y * 0.5
	if countdown_center <= gap_top or countdown_center >= gap_bottom or cost_center <= gap_top or cost_center >= gap_bottom:
		_fail("stamina_info_not_between_buttons")
		return false
	if countdown_center >= cost_center:
		_fail("stamina_countdown_not_above_cost")
		return false
	var expected_countdown_center := gap_top + (gap_bottom - gap_top) / 3.0
	var expected_cost_center := gap_top + (gap_bottom - gap_top) * 2.0 / 3.0
	if absf(countdown_center - expected_countdown_center) > 2.0 or absf(cost_center - expected_cost_center) > 2.0:
		_fail("stamina_info_not_evenly_distributed")
		return false
	return true

func _fail(message: String) -> void:
	push_error("STAMINA_COUNTDOWN " + message)
	get_tree().quit(1)
