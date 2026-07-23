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
	var stamina_button := ui.find_child("DrawStaminaButton", true, false) as Button
	var cost_label: Label = ui.get("_free_cost_label")
	if countdown_label == null:
		_fail("countdown_label_missing")
		return
	if stamina_button == null or stamina_button.text != "体力抽卡":
		_fail("stamina_button_text_wrong")
		return
	if countdown_label.get_theme_font_size("font_size") != 18 or cost_label == null or cost_label.get_theme_font_size("font_size") != 18:
		_fail("stamina_hint_font_size_wrong")
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
	if not _assert_natural_stamina_full_sfx():
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

func _assert_natural_stamina_full_sfx() -> bool:
	var original_sfx := AudioManager.sfx_volume
	var original_muted := AudioManager.is_muted
	AudioManager.reload_sfx_library()
	AudioManager.set_muted(false)
	AudioManager.set_sfx_volume(0.8)
	GameManager.player_data.level = 2
	GameManager.free_refresh_max_count = 2
	GameManager.free_refresh_count = 1
	GameManager.newbie_free_refresh_count = 0
	GameManager.free_refresh_cooldown = 0.0
	GameManager.last_free_refresh_time_unix = Time.get_unix_time_from_system() - float(GameManager.call("_stamina_recovery_seconds"))
	GameManager.call("_recover_one_free_refresh_local")
	var played := AudioManager.get_last_played_sfx_event()
	AudioManager.set_sfx_volume(original_sfx)
	AudioManager.set_muted(original_muted)
	if GameManager.free_refresh_count != 2:
		_fail("natural_stamina_not_full")
		return false
	if played != "stamina_full":
		_fail("natural_stamina_full_sfx=%s" % played)
		return false
	return true

func _assert_stamina_info_between_buttons(ui: CardPoolUI) -> bool:
	var stamina_button := ui.find_child("DrawStaminaButton", true, false) as Button
	var gold_button := ui.find_child("DrawGoldButton", true, false) as Button
	var gem_button := ui.find_child("DrawGemButton", true, false) as Button
	var countdown_label: Label = ui.get("_free_countdown_label")
	var cost_label: Label = ui.get("_free_cost_label")
	var gold_cost_label: Label = ui.get("_gold_cost_label")
	var gem_cost_label: Label = ui.get("_gem_cost_label")
	if stamina_button == null or gold_button == null or gem_button == null:
		_fail("stamina_info_buttons_missing")
		return false
	if countdown_label == null or cost_label == null or gold_cost_label == null or gem_cost_label == null:
		_fail("stamina_info_nodes_missing")
		return false
	var stamina_top := stamina_button.global_position.y
	var stamina_bottom := stamina_top + stamina_button.size.y
	var gold_top := gold_button.global_position.y
	var gold_bottom := gold_top + gold_button.size.y
	var gem_top := gem_button.global_position.y
	var gem_bottom := gem_top + gem_button.size.y
	var countdown_bottom := countdown_label.global_position.y + countdown_label.size.y
	var stamina_cost_top := cost_label.global_position.y
	var gold_cost_top := gold_cost_label.global_position.y
	var gold_cost_bottom := gold_cost_top + gold_cost_label.size.y
	var gem_cost_top := gem_cost_label.global_position.y
	if not (countdown_bottom <= stamina_top and stamina_cost_top >= stamina_bottom and gold_cost_top >= gold_bottom and gold_cost_bottom <= gem_top and gem_cost_top >= gem_bottom):
		_fail("draw_hint_order_wrong")
		return false
	var expected_gap := stamina_cost_top - stamina_bottom
	var distances := [
		stamina_top - countdown_bottom,
		stamina_cost_top - stamina_bottom,
		gold_cost_top - gold_bottom,
		gem_top - gold_cost_bottom,
		gem_cost_top - gem_bottom,
	]
	for distance in distances:
		if absf(float(distance) - expected_gap) > 1.0:
			_fail("draw_hint_gap_not_equal expected=%.2f actual=%.2f" % [expected_gap, float(distance)])
			return false
	var gold_cost_center := gold_cost_label.global_position.y + gold_cost_label.size.y * 0.5
	var gold_gem_gap_center := gold_bottom + (gem_top - gold_bottom) * 0.5
	if absf(gold_cost_center - gold_gem_gap_center) > 1.0:
		_fail("gold_cost_not_centered_between_buttons")
		return false
	if expected_gap < 6.0:
		_fail("draw_hint_gap_too_small=%.2f" % expected_gap)
		return false
	return true

func _fail(message: String) -> void:
	push_error("STAMINA_COUNTDOWN " + message)
	get_tree().quit(1)
