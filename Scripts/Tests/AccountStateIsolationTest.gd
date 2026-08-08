extends Node

const SplashScreenUIScript = preload("res://Scripts/UI/SplashScreenUI.gd")

func _ready() -> void:
	# 测试只需禁用本进程网络，不得调用 logout() 清除开发者真实本地登录凭据。
	ApiClient._auth_token = ""
	ApiClient._refresh_token = ""
	GameManager.reset_account_state()

	var host := Control.new()
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(host)

	var player_info := PlayerInfoUI.new()
	player_info.size = Vector2(280, 150)
	host.add_child(player_info)

	var currency := CurrencyUI.new()
	currency.position = Vector2(300, 0)
	currency.size = Vector2(420, 60)
	host.add_child(currency)
	await get_tree().process_frame

	var bound_player_data := GameManager.player_data
	GameManager.apply_login_user({
		"id": 9000001,
		"username": "nan",
		"level": 27,
		"exp": 9000,
		"gold": 987654321,
		"gems": 7654321,
		"combatPower": 456,
		"freeRefreshCount": 18,
		"newbieFreeRefreshCount": 0,
		"profileVersion": 0,
		"relicInventoryVersion": 0,
	})
	await get_tree().process_frame
	if not _assert_ui_values(player_info, currency, "nan", 27, 456, 987654321, 7654321, 18, 27, "nan"):
		return

	GameManager.reset_account_state()
	if GameManager.player_data != bound_player_data:
		return _fail("logout_replaced_player_data_object")
	GameManager.apply_login_user({
		"id": 9000002,
		"username": "test1",
		"level": 1,
		"exp": 0,
		"gold": 100,
		"gems": 50,
		"combatPower": 0,
		"freeRefreshCount": 0,
		"newbieFreeRefreshCount": 100,
		"profileVersion": 0,
		"relicInventoryVersion": 0,
	})
	await get_tree().process_frame
	if not _assert_ui_values(player_info, currency, "test1", 1, 0, 100, 50, 100, 100, "test1"):
		return

	# 旧账号的迟到 profile 不能把新账号重新改回 nan。
	GameManager.apply_profile({
		"id": 9000001,
		"username": "nan",
		"level": 40,
		"gold": 999999999,
		"gems": 999999999,
		"combatPower": 999999,
	})
	await get_tree().process_frame
	if GameManager.player_data.user_id != 9000002 or GameManager.player_data.nickname != "test1":
		return _fail("stale_profile_changed_current_account_identity")
	if GameManager.player_data.gold != 100 or GameManager.player_data.gems != 50:
		return _fail("stale_profile_changed_current_account_wallet")

	var merged_registration_user: Dictionary = SplashScreenUIScript.merge_authenticated_user_profile(
		{
			"id": 9000003,
			"username": "test_merge",
			"gold": 100,
			"gems": 50,
			"level": 1,
			"combatPower": 0,
			"freeRefreshCount": 0,
			"newbieFreeRefreshCount": 100,
		},
		{
			"id": 9000003,
			"username": "test_merge",
			"avatar": "basic.comet",
			"profileVersion": 2,
		}
	)
	for required_key in ["gold", "gems", "level", "combatPower", "freeRefreshCount", "newbieFreeRefreshCount"]:
		if not merged_registration_user.has(required_key):
			return _fail("registration_profile_merge_lost_" + required_key)

	print("ACCOUNT_STATE_ISOLATION ok player_object_stable=true stale_profile_rejected=true partial_profile_merged=true account=test1")
	get_tree().quit(0)

func _assert_ui_values(
	player_info: PlayerInfoUI,
	currency: CurrencyUI,
	expected_name: String,
	expected_level: int,
	expected_combat: int,
	expected_gold: int,
	expected_gems: int,
	expected_stamina: int,
	expected_stamina_max: int,
	stage: String
) -> bool:
	var id_label := player_info.find_child("PlayerIdLabel", true, false) as Label
	var level_roll := player_info.find_child("LevelNumberRoll", true, false) as AssetNumberRoll
	var combat_roll := player_info.find_child("CombatPowerNumberRoll", true, false) as AssetNumberRoll
	var gold_roll := currency.find_child("GoldNumberRoll", true, false) as AssetNumberRoll
	var gems_roll := currency.find_child("GemsNumberRoll", true, false) as AssetNumberRoll
	var stamina_roll := currency.find_child("StaminaNumberRoll", true, false) as AssetNumberRoll
	if id_label == null or level_roll == null or combat_roll == null or gold_roll == null or gems_roll == null or stamina_roll == null:
		_fail(stage + "_ui_nodes_missing")
		return false
	if id_label.text != expected_name:
		_fail("%s_id_wrong expected=%s actual=%s" % [stage, expected_name, id_label.text])
		return false
	if level_roll.get_display_text() != Localization.t("ui.player.level_short", [expected_level]):
		_fail(stage + "_level_wrong=" + level_roll.get_display_text())
		return false
	if combat_roll.get_display_text() != Localization.t("ui.player.combat_power_short", [expected_combat]):
		_fail(stage + "_combat_wrong=" + combat_roll.get_display_text())
		return false
	if gold_roll.get_display_text() != str(expected_gold) or gems_roll.get_display_text() != str(expected_gems):
		_fail("%s_wallet_wrong gold=%s gems=%s" % [stage, gold_roll.get_display_text(), gems_roll.get_display_text()])
		return false
	if stamina_roll.get_display_text() != "%d/%d" % [expected_stamina, expected_stamina_max]:
		_fail(stage + "_stamina_wrong=" + stamina_roll.get_display_text())
		return false
	return true

func _fail(message: String) -> void:
	push_error("ACCOUNT_STATE_ISOLATION " + message)
	get_tree().quit(1)
