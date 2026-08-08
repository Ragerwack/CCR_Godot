extends Node

func _ready() -> void:
	Localization.set_locale("zh-CN")
	GameManager.player_data.user_id = 42
	GameManager.player_data.nickname = "Nan"
	GameManager.player_data.country = "CN"
	GameManager.player_data.level = 18
	GameManager.player_data.gold = 1384
	GameManager.player_data.combat_power = 27
	GameManager.player_data.equipped_titles = [
		{"key": "collector.first", "name": "星海初藏"},
	]
	DeckSystem.player_decks.clear()
	_add_relic("relic-oldest", "white", 1, "cosmic_card_realm__particles", "万象卡域", "粒子", "2020-01-02")
	_add_relic("relic-white-second", "white", 2, "cosmic_card_realm__moon", "万象卡域", "月球背面的第一张照片", "2021-03-04")
	_add_relic("relic-blue", "blue", 21, "solar_system__sun", "太阳系", "太阳", "2022-05-06")

	var main := MainUI.new()
	main.size = get_viewport().get_visible_rect().size
	add_child(main)
	await get_tree().process_frame
	main.call("_set_game_ui_visible", true)

	var player_info := main.get("_player_info") as PlayerInfoUI
	var avatar_button := player_info.find_child("PlayerAvatarButton", true, false) as Button if player_info != null else null
	if avatar_button == null:
		return _fail("avatar button is missing")
	if not avatar_button.disabled:
		return _fail("avatar career entry should be disabled")
	if avatar_button.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		return _fail("disabled avatar button should not capture pointer input")
	if avatar_button.tooltip_text != "":
		return _fail("disabled avatar career entry should not show a tooltip")
	avatar_button.pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame

	if str(main.get("_current_view_id")) == "career":
		return _fail("disabled avatar click should not open career page")
	if main.get("_career_ui") != null:
		return _fail("disabled avatar click should not create career page")
	main.call("_show_career")
	await get_tree().process_frame
	if str(main.get("_current_view_id")) == "career" or main.get("_career_ui") != null:
		return _fail("disabled career page should ignore direct show requests")
	var nav_buttons := main.get("_nav_buttons") as NavButtons
	if nav_buttons == null or nav_buttons.selected_index < 0:
		return _fail("disabled career page should leave regular navigation selected")
	nav_buttons.nav_button_clicked.emit("vault")
	await get_tree().process_frame
	if str(main.get("_current_view_id")) != "vault":
		return _fail("regular navigation should keep working while career page is disabled")
	var career_ui := CareerUI.new()
	career_ui.size = get_viewport().get_visible_rect().size
	add_child(career_ui)
	await get_tree().process_frame
	for label_name in ["CareerPlayerId", "CareerLevelLabel", "CareerCombatPowerLabel"]:
		var label := career_ui.find_child(label_name, true, false) as Label
		if label == null or not _color_close(label.get_theme_color("font_color"), Color.BLACK):
			return _fail("career_identity_or_stat_text_is_not_black_%s" % label_name)

	print("CAREER_UI ok")
	get_tree().quit(0)

func _add_relic(id: String, color: String, deck_def_id: int, deck_key: String, series_name: String, deck_name: String, date: String) -> void:
	DeckSystem.add_synthesized_deck({
		"id": id,
		"color": color,
		"combat_power": 1,
		"status": "active",
		"created_date_beijing": date,
		"created_at": date + "T00:00:00.000Z",
		"series": {"id": 1, "name": series_name},
		"deck_def": {"id": deck_def_id, "name": deck_key, "description": deck_name},
	})

func _fail(message: String) -> void:
	push_error("CAREER_UI failed: " + message)
	get_tree().quit(1)

func _color_close(actual: Color, expected: Color) -> bool:
	return is_equal_approx(actual.r, expected.r) and is_equal_approx(actual.g, expected.g) and is_equal_approx(actual.b, expected.b) and is_equal_approx(actual.a, expected.a)
