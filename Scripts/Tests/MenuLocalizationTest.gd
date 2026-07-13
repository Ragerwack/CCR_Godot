extends Node

const CountryCatalogScript = preload("res://Scripts/Data/CountryCatalog.gd")

func _ready() -> void:
	ApiClient.logout()
	Localization.set_locale("en")
	var main := MainUI.new()
	add_child(main)
	await get_tree().process_frame

	var menu_button: Button = main.get("_menu_button")
	var center_area: Control = main.get("_center_area")
	var nav_buttons: NavButtons = main.get("_nav_buttons")
	if menu_button != null:
		_fail("top-right settings button still exists")
		return
	if center_area == null or nav_buttons == null:
		_fail("main center area or navigation is missing")
		return

	var splash: Node = null
	for child in main.get_children():
		if child.has_method("_selected_country_code"):
			splash = child
			break
	if splash == null or splash.call("_selected_country_code") != "EARTH":
		_fail("registration nationality does not default to EARTH")
		return
	var login_exit_button := splash.find_child("LoginExitButton", true, false) as Button
	if login_exit_button == null or login_exit_button.text != "Exit Game":
		_fail("login exit button is missing or not localized")
		return

	main.call("_set_game_ui_visible", true)
	var player_info := main.get("_player_info") as PlayerInfoUI
	if player_info == null:
		_fail("player info is missing")
		return
	var avatar_host := player_info.find_child("AvatarHost", true, false) as ColorRect
	var avatar_image := player_info.find_child("AvatarImage", true, false) as TextureRect
	var expected_avatar_height := float(main.call("_target_player_avatar_height"))
	if avatar_host == null or avatar_image == null:
		_fail("avatar nodes are missing")
		return
	if avatar_host.color.a > 0.01:
		_fail("avatar host still has visible color frame")
		return
	if absf(avatar_host.size.y - expected_avatar_height) > 1.0 or absf(avatar_image.size.y - expected_avatar_height) > 1.0:
		_fail("avatar size was not doubled")
		return
	nav_buttons.nav_button_clicked.emit("settings")
	await get_tree().process_frame
	if not _has_text(center_area, "Settings") or not _has_text(center_area, "Resolution") or not _has_resolution_option(center_area) or not _has_window_mode_option(center_area):
		_fail("English basic settings page, language selector, resolution selector, or window mode selector is missing")
		return
	var profile_tab := center_area.find_child("ProfileSettingsTab", true, false) as Button
	if profile_tab == null:
		_fail("player information settings tab is missing")
		return
	profile_tab.pressed.emit()
	await get_tree().process_frame
	if not _has_text(center_area, "Player Information") or not _has_text(center_area, "Region"):
		_fail("English player information settings page is missing")
		return
	var region_select := center_area.find_child("RegionSelect", true, false) as OptionButton
	var avatar_change := center_area.find_child("AvatarChangeButton", true, false) as Button
	if region_select == null or region_select.item_count != 196 or not _has_region_option(region_select, "HK", "China Hong Kong") or not _has_region_option(region_select, "TW", "China Taiwan"):
		_fail("UN region options or China Hong Kong/China Taiwan labels are missing")
		return
	if avatar_change == null:
		_fail("avatar change button is missing")
		return
	avatar_change.pressed.emit()
	await get_tree().process_frame
	var avatar_picker := main.find_child("AvatarPickerPopup", false, false) as PopupPanel
	if avatar_picker == null or avatar_picker.find_children("AvatarOption_*", "Button", true, false).size() != 12:
		_fail("avatar picker does not expose all 12 unlocked basic avatars")
		return
	avatar_picker.hide()
	avatar_picker.queue_free()
	await get_tree().process_frame
	Localization.set_locale("zh-CN", true, 1)
	await get_tree().process_frame
	if not _has_text(center_area, "设置") or not _has_text(center_area, "玩家信息设置") or not _has_text(center_area, "区域"):
		_fail("settings page did not refresh after language change")
		return

	var entries: Array[Dictionary] = CountryCatalogScript.localized_entries("en")
	if entries.is_empty() or entries[0].get("code", "") != "EARTH":
		_fail("country catalog does not default to EARTH")
		return
	var found_china := false
	var found_china_hong_kong := false
	var found_china_taiwan := false
	for entry in entries:
		if entry.get("code", "") == "CN" and entry.get("label", "") == "China":
			found_china = true
		if entry.get("code", "") == "HK" and entry.get("label", "") == "China Hong Kong":
			found_china_hong_kong = true
		if entry.get("code", "") == "TW" and entry.get("label", "") == "China Taiwan":
			found_china_taiwan = true
	if not found_china or not found_china_hong_kong or not found_china_taiwan:
		_fail("country catalog is missing China/CN")
		return

	Localization.set_locale("en", true, 1)
	await get_tree().process_frame
	nav_buttons.nav_button_clicked.emit("exit_game")
	await get_tree().process_frame
	var exit_dialog: ConfirmationDialog = main.get("_exit_confirm_dialog")
	if exit_dialog == null or exit_dialog.title != "Exit Game" or exit_dialog.dialog_text.find("server connection") < 0:
		_fail("exit game confirmation dialog is missing")
		return
	exit_dialog.hide()

	# 测试结束恢复首次启动默认语言，避免污染本机后续图形验证。
	Localization.set_locale("en")
	print("MENU_LOCALIZATION ok")
	get_tree().quit(0)

func _has_text(root: Node, expected: String) -> bool:
	for child in root.find_children("*", "Label", true, false):
		if child.text == expected:
			return true
	return false

func _has_resolution_option(root: Node) -> bool:
	var resolution_select: OptionButton = root.find_child("ResolutionSelect", true, false)
	if resolution_select == null or resolution_select.item_count != DisplaySettings.get_supported_resolutions().size():
		return false
	for i in range(resolution_select.item_count):
		var resolution: Vector2i = resolution_select.get_item_metadata(i)
		if not DisplaySettings.is_supported_resolution(resolution):
			return false
		if resolution.y * 8 == resolution.x * 5 and resolution_select.get_item_text(i).find("(16:10)") < 0:
			return false
	return true

func _has_window_mode_option(root: Node) -> bool:
	var window_mode_select: OptionButton = root.find_child("WindowModeSelect", true, false)
	if window_mode_select == null or window_mode_select.item_count != 2:
		return false
	return bool(window_mode_select.get_item_metadata(0)) == true and bool(window_mode_select.get_item_metadata(1)) == false

func _has_region_option(select: OptionButton, code: String, label: String) -> bool:
	for index in range(select.item_count):
		if str(select.get_item_metadata(index)) == code and select.get_item_text(index) == label:
			return true
	return false

func _fail(message: String) -> void:
	push_error("MENU_LOCALIZATION " + message)
	get_tree().quit(1)
