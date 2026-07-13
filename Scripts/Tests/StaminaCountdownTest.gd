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

	print("STAMINA_COUNTDOWN ok text=%s cooldown=%d" % [countdown_label.text, ceili(GameManager.get_free_refresh_cooldown())])
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

func _fail(message: String) -> void:
	push_error("STAMINA_COUNTDOWN " + message)
	get_tree().quit(1)
