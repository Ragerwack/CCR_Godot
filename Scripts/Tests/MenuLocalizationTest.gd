extends Node

const CountryCatalogScript = preload("res://Scripts/Data/CountryCatalog.gd")

func _ready() -> void:
	ApiClient.logout()
	Localization.set_locale("en")
	var main := MainUI.new()
	main.size = get_viewport().get_visible_rect().size
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
	if not _has_supported_language_options(center_area):
		_fail("P1 supported language options are missing")
		return
	if not _has_settings_visuals(center_area):
		_fail("settings page is missing scheme C control visuals")
		return
	if not _settings_panel_matches_target(main, center_area):
		_fail("settings panel does not match target responsive size")
		return
	if not _settings_page_content_matches_target(main, center_area):
		_fail("settings page content does not match target 80 percent width")
		return
	if not _settings_volume_sliders_are_percent_adjustable(center_area):
		_fail("settings volume sliders are not adjustable in one percent increments")
		return
	if not _settings_action_buttons_have_no_prefix_icons(center_area):
		_fail("settings mute or logout buttons still have prefix icons")
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
	var avatar_scrolls := avatar_picker.find_children("*", "ScrollContainer", true, false)
	var avatar_scroll := avatar_scrolls[0] as ScrollContainer if not avatar_scrolls.is_empty() else null
	if avatar_scroll == null or not avatar_scroll.has_theme_stylebox_override("panel"):
		_fail("avatar picker scroll container is missing scheme C visual style")
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
	var zh_tw_entries: Array[Dictionary] = CountryCatalogScript.localized_entries("zh-TW")
	if zh_tw_entries.is_empty() or zh_tw_entries[0].get("label", "") != "地球" or not _has_region_label(zh_tw_entries, "HK", "中國香港"):
		_fail("traditional Chinese country catalog is missing")
		return

	Localization.set_locale("en", true, 1)
	await get_tree().process_frame
	if _screenshot_path_requested():
		splash.hide()
	nav_buttons.nav_button_clicked.emit("exit_game")
	await get_tree().process_frame
	var exit_dialog: Control = main.get("_exit_confirm_dialog")
	var exit_title := exit_dialog.get_node_or_null("Panel/TitleLabel") as Label if exit_dialog != null else null
	var exit_message := exit_dialog.get_node_or_null("Panel/MessageLabel") as Label if exit_dialog != null else null
	var confirm_button := exit_dialog.get_node_or_null("Panel/ConfirmButton") as Button if exit_dialog != null else null
	var cancel_button := exit_dialog.get_node_or_null("Panel/CancelButton") as Button if exit_dialog != null else null
	if exit_dialog == null or exit_title == null or exit_title.text != "Exit Game" or exit_message == null or exit_message.text != "Exit the game?":
		_fail("exit game confirmation dialog is missing")
		return
	if confirm_button == null or cancel_button == null:
		_fail("exit game confirmation controls are missing")
		return
	if exit_dialog.get_node_or_null("Panel/CloseButton") != null:
		_fail("exit game close button should not exist")
		return
	if confirm_button.text == "" or cancel_button.text == "":
		_fail("exit game button runtime text is wrong")
		return
	if confirm_button.mouse_default_cursor_shape != Control.CURSOR_ARROW or cancel_button.mouse_default_cursor_shape != Control.CURSOR_ARROW:
		_fail("exit game dialog controls do not use the CCR arrow cursor shape")
		return
	main.call("_apply_game_text_color")
	if not _color_close(exit_title.get_theme_color("font_color"), Color.WHITE) or not _color_close(confirm_button.get_theme_color("font_color"), Color.WHITE):
		_fail("exit game dialog text color is not white")
		return
	var screenshot_path := OS.get_environment("CCR_MENU_SCREENSHOT_PATH")
	if screenshot_path != "":
		await RenderingServer.frame_post_draw
		var screenshot := get_viewport().get_texture().get_image()
		if screenshot == null or screenshot.is_empty() or screenshot.save_png(screenshot_path) != OK:
			_fail("exit game dialog screenshot could not be saved")
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

func _has_supported_language_options(root: Node) -> bool:
	var language_select: OptionButton = null
	for select in root.find_children("*", "OptionButton", true, false):
		for i in range((select as OptionButton).item_count):
			if str((select as OptionButton).get_item_metadata(i)) == "zh-TW":
				language_select = select as OptionButton
				break
		if language_select != null:
			break
	if language_select == null or language_select.item_count != Localization.get_supported_locales().size():
		return false
	for locale in Localization.get_supported_locales():
		var found := false
		for i in range(language_select.item_count):
			if str(language_select.get_item_metadata(i)) == str(locale):
				found = true
				break
		if not found:
			return false
	return true

func _has_region_label(entries: Array[Dictionary], code: String, label: String) -> bool:
	for entry in entries:
		if entry.get("code", "") == code and entry.get("label", "") == label:
			return true
	return false

func _has_settings_visuals(root: Node) -> bool:
	var panel := root.find_child("SettingsRelicPanel", true, false) as Panel
	var resolution_select := root.find_child("ResolutionSelect", true, false) as OptionButton
	var sliders := root.find_children("*", "HSlider", true, false)
	if panel == null or not panel.has_theme_stylebox_override("panel"):
		return false
	var panel_style := panel.get_theme_stylebox("panel") as StyleBoxTexture
	if panel_style == null or panel_style.texture == null:
		return false
	if resolution_select == null or not resolution_select.has_theme_stylebox_override("normal"):
		return false
	if resolution_select.get_popup() == null or not resolution_select.get_popup().has_theme_stylebox_override("panel"):
		return false
	if sliders.size() < 2:
		return false
	for node in sliders:
		var slider := node as HSlider
		if slider == null or not slider.has_theme_stylebox_override("slider") or not slider.has_theme_icon_override("grabber"):
			return false
	return true

func _settings_panel_matches_target(main: MainUI, root: Node) -> bool:
	var panel := root.find_child("SettingsRelicPanel", true, false) as Panel
	if panel == null:
		return false
	var expected_rect := main.call("_settings_panel_rect") as Rect2
	return panel.position.distance_to(expected_rect.position) <= 1.0 and panel.size.distance_to(expected_rect.size) <= 1.0

func _settings_page_content_matches_target(main: MainUI, root: Node) -> bool:
	var panel := root.find_child("SettingsRelicPanel", true, false) as Panel
	var scroll := root.find_child("SettingsPageScroll", true, false) as ScrollContainer
	var content := root.find_child("SettingsPageContent", true, false) as VBoxContainer
	if panel == null or scroll == null or content == null:
		return false
	var panel_margin := main.call("_settings_panel_content_margin", panel.size) as Vector2
	var expected_frame_width := float(main.call("_settings_page_frame_width", panel.size, panel_margin))
	var expected_width := float(main.call("_settings_page_content_width", panel.size, panel_margin))
	var panel_rect := panel.get_global_rect()
	var scroll_rect := scroll.get_global_rect()
	var content_rect := content.get_global_rect()
	var expected_scroll_center_x := panel_rect.position.x + panel_margin.x + (panel.size.x - panel_margin.x * 2.0) * 0.5
	if absf(scroll.custom_minimum_size.x - expected_frame_width) > 1.0 or absf(scroll.size.x - expected_frame_width) > 2.0:
		return false
	if absf(content.custom_minimum_size.x - expected_width) > 1.0 or absf(content.size.x - expected_width) > 1.0:
		return false
	return absf(scroll_rect.get_center().x - expected_scroll_center_x) <= 1.0 and absf(content_rect.get_center().x - scroll_rect.get_center().x) <= 1.0

func _settings_volume_sliders_are_percent_adjustable(root: Node) -> bool:
	var sliders := root.find_children("*", "HSlider", true, false)
	if sliders.size() < 2:
		return false
	var music_slider := sliders[0] as HSlider
	var sfx_slider := sliders[1] as HSlider
	if music_slider == null or sfx_slider == null:
		return false
	if music_slider.min_value != 0.0 or music_slider.max_value != 1.0 or absf(music_slider.step - 0.01) > 0.0001 or music_slider.rounded:
		return false
	if sfx_slider.min_value != 0.0 or sfx_slider.max_value != 1.0 or absf(sfx_slider.step - 0.01) > 0.0001 or sfx_slider.rounded:
		return false
	var original_bgm := AudioManager.bgm_volume
	var original_sfx := AudioManager.sfx_volume
	music_slider.value = 0.37
	sfx_slider.value = 0.22
	var accepts_first_values := absf(AudioManager.bgm_volume - 0.37) <= 0.001 and absf(AudioManager.sfx_volume - 0.22) <= 0.001
	music_slider.value = 0.89
	var accepts_second_value := absf(AudioManager.bgm_volume - 0.89) <= 0.001
	AudioManager.set_bgm_volume(original_bgm)
	AudioManager.set_sfx_volume(original_sfx)
	return accepts_first_values and accepts_second_value

func _settings_action_buttons_have_no_prefix_icons(root: Node) -> bool:
	var found_mute := false
	var found_logout := false
	for child in root.find_children("*", "Button", true, false):
		var button := child as Button
		if button == null:
			continue
		if button.text == "Mute" or button.text == "Muted":
			found_mute = true
		if button.text == "Logout":
			found_logout = true
		if button.text.begins_with("🔊") or button.text.begins_with("🔇") or button.text.begins_with("🚪"):
			return false
	return found_mute and found_logout

func _has_region_option(select: OptionButton, code: String, label: String) -> bool:
	for index in range(select.item_count):
		if str(select.get_item_metadata(index)) == code and select.get_item_text(index) == label:
			return true
	return false

func _color_close(a: Color, b: Color, epsilon: float = 0.01) -> bool:
	return absf(a.r - b.r) <= epsilon and absf(a.g - b.g) <= epsilon and absf(a.b - b.b) <= epsilon and absf(a.a - b.a) <= epsilon

func _screenshot_path_requested() -> bool:
	return OS.get_environment("CCR_MENU_SCREENSHOT_PATH") != ""

func _fail(message: String) -> void:
	push_error("MENU_LOCALIZATION " + message)
	get_tree().quit(1)
