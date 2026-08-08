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
	var login_language_select := splash.find_child("LoginLanguageSelect", true, false) as OptionButton
	if login_language_select == null or login_language_select.item_count != Localization.get_supported_locales().size():
		_fail("login language selector is missing supported locales")
		return
	Localization.set_locale("ko")
	await get_tree().process_frame
	if _language_option_text(login_language_select, "en") != "English" or _language_option_text(login_language_select, "ja") != "日本語" or _language_option_text(login_language_select, "ko") != "한국어":
		_fail("login language selector is not using native language names")
		return
	Localization.set_locale("en")
	await get_tree().process_frame
	login_language_select.select(1)
	login_language_select.item_selected.emit(1)
	await get_tree().process_frame
	if login_exit_button.text != "退出游戏":
		_fail("login language selector did not refresh login page text")
		return
	login_language_select.select(0)
	login_language_select.item_selected.emit(0)
	await get_tree().process_frame
	splash.call("_on_switch_mode")
	await get_tree().process_frame
	var register_avatar_select := splash.find_child("RegisterAvatarSelect", true, false) as OptionButton
	var register_avatar_preview := splash.find_child("RegisterAvatarPreview", true, false) as TextureRect
	var username_input := splash.get("_username_input") as LineEdit
	var password_input := splash.get("_password_input") as LineEdit
	var register_submit := splash.get("_submit_button") as Button
	var username_status := splash.find_child("RegisterUsernameStatus", true, false) as Label
	var password_status := splash.find_child("RegisterPasswordStatus", true, false) as Label
	var email_status := splash.find_child("RegisterEmailStatus", true, false) as Label
	if username_input == null or username_input.placeholder_text != "Game ID":
		_fail("register page does not label username as Game ID")
		return
	if username_status == null or password_status == null or email_status == null or register_submit == null or not register_submit.disabled:
		_fail("register field statuses or submit validation gate are missing")
		return
	password_input.text = "secret1"
	password_input.text_changed.emit("secret1")
	await get_tree().process_frame
	if password_status.text != "✓" or not register_submit.disabled:
		_fail("valid password does not show a check mark or incorrectly unlocks registration")
		return
	splash.call("_apply_registration_server_error", {"error_code": "USERNAME_TAKEN"})
	if username_status.text != "This ID is unavailable":
		_fail("server username rejection is not shown beside the registration field")
		return
	if register_avatar_select == null or register_avatar_select.item_count != 12 or register_avatar_preview == null or register_avatar_preview.texture == null:
		_fail("register page avatar selector or preview is missing")
		return
	register_avatar_select.select(2)
	register_avatar_select.item_selected.emit(2)
	await get_tree().process_frame
	if splash.call("_selected_avatar_id") != "basic.comet":
		_fail("register page selected avatar id is wrong")
		return
	splash.call("_on_switch_mode")
	await get_tree().process_frame

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
	var settings_language_select := center_area.find_child("LanguageSelect", true, false) as OptionButton
	if settings_language_select == null or _language_option_text(settings_language_select, "en") != "English" or _language_option_text(settings_language_select, "ko") != "한국어":
		_fail("settings language selector is not using native language names")
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
	if not _settings_rows_use_centered_two_column_alignment(center_area):
		_fail("basic settings rows are not centered with left labels and right controls")
		return
	if not _settings_volume_sliders_are_percent_adjustable(center_area):
		_fail("settings volume sliders are not adjustable in one percent increments")
		return
	if not _settings_action_buttons_have_no_prefix_icons(center_area):
		_fail("settings mute or logout buttons still have prefix icons")
		return
	main.call("_refresh_layout_after_resize")
	await get_tree().process_frame
	if not _settings_specific_labels_use_settings_color(center_area):
		_fail("settings text color was reset to the dark game text color after resize")
		return
	var controller_tab := center_area.find_child("ControllerSettingsTab", true, false) as Button
	if controller_tab == null:
		_fail("controller settings tab is missing")
		return
	controller_tab.pressed.emit()
	await get_tree().process_frame
	if not _settings_rows_use_centered_two_column_alignment(center_area):
		_fail("controller settings rows are not centered with left labels and right controls")
		return
	var controller_selects := center_area.find_children("ControllerBindingSelect_*", "OptionButton", true, false)
	if controller_selects.is_empty() or not _short_popup_has_no_scrollbar_and_matching_selection_icon(controller_selects[0] as OptionButton, CCRVisualStyle.SETTINGS_POPUP_HEIGHT_15_ITEMS):
		_fail("controller binding popup still uses the embedded old scrollbar or wrong selection color")
		return
	var reset_controller_button := center_area.find_child("ResetControllerButton", true, false) as Button
	if reset_controller_button == null or not _has_exit_dialog_button_visual(reset_controller_button, false):
		_fail("reset controller button does not use exit dialog button visual style")
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
	if not _settings_rows_use_centered_two_column_alignment(center_area):
		_fail("profile settings rows are not centered with left labels and right controls")
		return
	var region_select := center_area.find_child("RegionSelect", true, false) as OptionButton
	var avatar_change := center_area.find_child("AvatarChangeButton", true, false) as Button
	var profile_name_field := center_area.find_child("PlayerNameField", true, false) as LineEdit
	var profile_name_status := center_area.find_child("PlayerNameAvailabilityStatus", true, false) as Label
	var profile_name_save := center_area.find_child("PlayerNameSaveButton", true, false) as Button
	if profile_name_field == null or not profile_name_field.editable or profile_name_status == null or profile_name_save == null or not profile_name_save.disabled:
		_fail("profile Game ID rename controls or validation gate are missing")
		return
	if region_select == null or region_select.item_count != 196 or not _has_region_option(region_select, "HK", "China Hong Kong") or not _has_region_option(region_select, "TW", "China Taiwan"):
		_fail("UN region options or China Hong Kong/China Taiwan labels are missing")
		return
	if absf(region_select.size.x - 340.0) > 1.0 or region_select.alignment != HORIZONTAL_ALIGNMENT_CENTER:
		_fail("region dropdown width or alignment is wrong")
		return
	if region_select.get_popup().get_theme_font_size("font_size") != region_select.get_theme_font_size("font_size"):
		_fail("region dropdown popup font size does not match the closed dropdown")
		return
	region_select.show_popup()
	await get_tree().process_frame
	await get_tree().process_frame
	if not _region_popup_matches_fixed_asset_and_scrollbar(main, region_select):
		_fail("region dropdown popup size, bottom boundary, panel ratio, or draggable scrollbar is wrong")
		return
	region_select.get_popup().hide()
	if avatar_change == null:
		_fail("avatar change button is missing")
		return
	if not _has_exit_dialog_button_visual(avatar_change, false):
		_fail("avatar change button does not use exit dialog button visual style")
		return
	if not _has_profile_text_box_visual(center_area):
		_fail("profile settings text box is missing scheme C visual style")
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
	if not _color_close(exit_title.get_theme_color("font_color"), CCRVisualStyle.SETTINGS_TEXT) or not _color_close(exit_message.get_theme_color("font_color"), CCRVisualStyle.SETTINGS_TEXT):
		_fail("exit game dialog label text color is not the settings yellow-green")
		return
	if not _color_close(confirm_button.get_theme_color("font_color"), CCRVisualStyle.SETTINGS_TEXT) or not _color_close(cancel_button.get_theme_color("font_color"), CCRVisualStyle.SETTINGS_TEXT):
		_fail("exit game dialog button text color is not the settings yellow-green")
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

func _language_option_text(select: OptionButton, locale_code: String) -> String:
	if select == null:
		return ""
	for index in range(select.item_count):
		if str(select.get_item_metadata(index)) == locale_code:
			return select.get_item_text(index)
	return ""

func _has_settings_visuals(root: Node) -> bool:
	var panel := root.find_child("SettingsRelicPanel", true, false) as Panel
	var resolution_select := root.find_child("ResolutionSelect", true, false) as OptionButton
	var mute_toggle := root.find_child("MuteToggleButton", true, false) as Button
	var page_scroll := root.find_child("SettingsPageScroll", true, false) as ScrollContainer
	var music_slider := root.find_child("MusicVolumeSlider", true, false) as HSlider
	var sfx_slider := root.find_child("SfxVolumeSlider", true, false) as HSlider
	var logout_button := root.find_child("SettingsLogoutButton", true, false) as Button
	var sliders := root.find_children("*", "HSlider", true, false)
	if panel == null or not panel.has_theme_stylebox_override("panel"):
		return false
	var panel_style := panel.get_theme_stylebox("panel") as StyleBoxTexture
	if panel_style == null or panel_style.texture == null:
		return false
	if not _has_settings_tab_text_display_boxes(root):
		return false
	if resolution_select == null or not resolution_select.has_theme_stylebox_override("normal"):
		return false
	if absf(resolution_select.size.x - 340.0) > 1.0:
		return false
	if resolution_select.alignment != HORIZONTAL_ALIGNMENT_CENTER:
		return false
	for node in panel.find_children("*", "OptionButton", true, false):
		var select := node as OptionButton
		if select == null or absf(select.size.x - 340.0) > 1.0 or select.alignment != HORIZONTAL_ALIGNMENT_CENTER:
			return false
	if not _has_dropdown_box_assets(resolution_select):
		return false
	if resolution_select.get_popup() == null or not resolution_select.get_popup().has_theme_stylebox_override("panel"):
		return false
	var popup_panel := resolution_select.get_popup().get_theme_stylebox("panel") as StyleBoxTexture
	if popup_panel == null or popup_panel.texture == null or str(resolution_select.get_popup().get_meta("ccr_settings_popup_asset", "")) != "dropdown_menu_panel_5_items.png":
		return false
	if not _has_unsliced_dropdown_texture(popup_panel) or popup_panel.texture.get_size() != Vector2(340, CCRVisualStyle.SETTINGS_POPUP_HEIGHT_5_ITEMS):
		return false
	if not _popup_hover_is_limited_to_text_area(resolution_select.get_popup()):
		return false
	if not _short_popup_has_no_scrollbar_and_matching_selection_icon(resolution_select, CCRVisualStyle.SETTINGS_POPUP_HEIGHT_5_ITEMS):
		return false
	var window_mode_select := root.find_child("WindowModeSelect", true, false) as OptionButton
	if window_mode_select == null:
		return false
	var window_popup_panel := window_mode_select.get_popup().get_theme_stylebox("panel") as StyleBoxTexture
	if window_popup_panel == null or window_popup_panel.texture == null or str(window_mode_select.get_popup().get_meta("ccr_settings_popup_asset", "")) != "dropdown_menu_panel_2_items.png":
		return false
	if not _short_popup_has_no_scrollbar_and_matching_selection_icon(window_mode_select, CCRVisualStyle.SETTINGS_POPUP_HEIGHT_2_ITEMS):
		return false
	var language_select := root.find_child("LanguageSelect", true, false) as OptionButton
	if not _short_popup_has_no_scrollbar_and_matching_selection_icon(language_select, CCRVisualStyle.SETTINGS_POPUP_HEIGHT_5_ITEMS):
		return false
	if root.find_child("AudioEnabledCheckBox", true, false) != null:
		return false
	if not _has_boolean_toggle_assets(mute_toggle):
		return false
	if mute_toggle.size.x > 150.0:
		return false
	if logout_button == null or not _has_exit_dialog_button_visual(logout_button, true):
		return false
	if page_scroll == null or not page_scroll.has_theme_stylebox_override("panel"):
		return false
	var vbar := page_scroll.get_v_scroll_bar()
	var hbar := page_scroll.get_h_scroll_bar()
	if vbar == null or hbar == null:
		return false
	if not vbar.has_theme_stylebox_override("grabber") or not vbar.has_theme_icon_override("increment"):
		return false
	if not _has_vertical_scrollbar_assets(vbar):
		return false
	if not hbar.has_theme_stylebox_override("grabber") or not hbar.has_theme_icon_override("increment"):
		return false
	if not _has_horizontal_scrollbar_assets(music_slider) or not _has_horizontal_scrollbar_assets(sfx_slider):
		return false
	if sliders.size() < 2:
		return false
	for node in sliders:
		var slider := node as HSlider
		if slider == null or not slider.has_theme_stylebox_override("slider") or not slider.has_theme_icon_override("grabber"):
			return false
		if slider.size.x > 380.0:
			return false
	return true

func _has_boolean_toggle_assets(toggle: Button) -> bool:
	if toggle == null or not toggle.has_theme_icon_override("icon") or not toggle.toggle_mode:
		return false
	var original_active := toggle.button_pressed
	CCRVisualStyle.apply_settings_toggle_button(toggle, false)
	CCRVisualStyle._layout_settings_toggle_knob(toggle, false, false)
	var normal_base := toggle.get_theme_stylebox("normal") as StyleBoxTexture
	var knob := toggle.find_child("CCRSettingsToggleKnob", false, false) as TextureRect
	if normal_base == null or normal_base.texture == null or not normal_base.texture.resource_path.ends_with("toggle_base_normal.png"):
		CCRVisualStyle.apply_settings_toggle_button(toggle, original_active)
		return false
	if not _has_unsliced_dropdown_texture(normal_base) or knob == null or knob.texture == null or not knob.texture.resource_path.ends_with("toggle_knob_normal.png"):
		CCRVisualStyle.apply_settings_toggle_button(toggle, original_active)
		return false
	if absf(knob.size.y - toggle.size.y) > 1.0 or absf(knob.size.x / knob.size.y - knob.texture.get_size().x / knob.texture.get_size().y) > 0.01:
		CCRVisualStyle.apply_settings_toggle_button(toggle, original_active)
		return false
	var inactive_x := knob.position.x
	CCRVisualStyle.apply_settings_toggle_button(toggle, true)
	CCRVisualStyle._layout_settings_toggle_knob(toggle, true, false)
	var active_base := toggle.get_theme_stylebox("normal") as StyleBoxTexture
	var active_valid := (
		active_base != null
		and active_base.texture != null
		and active_base.texture.resource_path.ends_with("toggle_base_focus.png")
		and _has_unsliced_dropdown_texture(active_base)
		and knob.texture != null
		and knob.texture.resource_path.ends_with("toggle_knob_focus.png")
		and knob.position.x > inactive_x + 10.0
	)
	CCRVisualStyle.apply_settings_toggle_button(toggle, original_active)
	CCRVisualStyle._layout_settings_toggle_knob(toggle, original_active, false)
	return active_valid

func _has_horizontal_scrollbar_assets(slider: HSlider) -> bool:
	if slider == null:
		return false
	if slider.custom_minimum_size.x < 300.0 or slider.custom_minimum_size.y < 34.0:
		return false
	var rail := slider.get_theme_stylebox("slider") as StyleBoxTexture
	if rail != null:
		return false
	var visible_track := slider.find_child("CCRHorizontalScrollbarTrack", false, false) as TextureRect
	var visible_thumb := slider.find_child("CCRHorizontalScrollbarThumb", false, false) as TextureRect
	if visible_track == null or visible_track.texture == null or not visible_track.visible or visible_track.z_index <= 0:
		return false
	if visible_thumb == null or visible_thumb.texture == null or not visible_thumb.visible or visible_thumb.z_index <= visible_track.z_index:
		return false
	if visible_track.size.x < 300.0 or visible_track.size.y < 30.0:
		return false
	if visible_thumb.size.x < 20.0 or visible_thumb.size.y < 20.0:
		return false
	var original_value := slider.value
	var original_thumb_x := visible_thumb.position.x
	slider.value = slider.max_value if original_value < slider.max_value else slider.min_value
	var thumb_moved := not is_equal_approx(visible_thumb.position.x, original_thumb_x)
	slider.value = original_value
	if not thumb_moved:
		return false
	return visible_track.texture.resource_path.ends_with("horizontal_scrollbar_track_normal.png") and visible_thumb.texture.resource_path.ends_with("horizontal_scrollbar_thumb_normal.png")

func _has_vertical_scrollbar_assets(scrollbar: VScrollBar) -> bool:
	if scrollbar == null or scrollbar.custom_minimum_size.x < 68.0:
		return false
	var native_track := scrollbar.get_theme_stylebox("scroll") as StyleBoxTexture
	var native_thumb := scrollbar.get_theme_stylebox("grabber") as StyleBoxTexture
	if native_track != null or native_thumb != null:
		return false
	var visible_track := scrollbar.find_child("CCRVerticalScrollbarTrack", false, false) as NinePatchRect
	var visible_thumb := scrollbar.find_child("CCRVerticalScrollbarThumb", false, false) as TextureRect
	if visible_track == null or visible_track.texture == null or not visible_track.visible or visible_track.z_index <= 0:
		return false
	if visible_track.patch_margin_top != CCRVisualStyle.SETTINGS_VERTICAL_SCROLLBAR_TRACK_END_MARGIN or visible_track.patch_margin_bottom != CCRVisualStyle.SETTINGS_VERTICAL_SCROLLBAR_TRACK_END_MARGIN:
		return false
	if visible_thumb == null or visible_thumb.texture == null or not visible_thumb.visible or visible_thumb.z_index <= visible_track.z_index:
		return false
	if visible_track.size.y < 20.0 or visible_thumb.size.x < 40.0 or visible_thumb.size.y < 60.0:
		return false
	for state in ["normal", "focus", "pressed", "disabled"]:
		CCRVisualStyle._set_vertical_scrollbar_state(scrollbar, state)
		if not visible_track.texture.resource_path.ends_with("vertical_scrollbar_track_%s.png" % state):
			return false
		if not visible_thumb.texture.resource_path.ends_with("vertical_scrollbar_thumb_%s.png" % state):
			return false
	CCRVisualStyle._set_vertical_scrollbar_state(scrollbar, "normal")
	return true

func _popup_hover_is_limited_to_text_area(popup: PopupMenu) -> bool:
	if popup == null:
		return false
	var hover := popup.get_theme_stylebox("hover") as StyleBoxTexture
	if hover == null or hover.texture == null:
		return false
	var image := hover.texture.get_image()
	if image == null or image.is_empty() or image.get_size() != Vector2i(CCRVisualStyle.SETTINGS_DROPDOWN_SIZE.x, CCRVisualStyle.SETTINGS_POPUP_HOVER_HEIGHT):
		return false
	var text_end_x := int(roundf(float(CCRVisualStyle.SETTINGS_DROPDOWN_SIZE.x) * CCRVisualStyle.SETTINGS_DROPDOWN_TEXT_RATIO))
	var left_border := image.get_pixel(1, 1)
	var right_pane := image.get_pixel(text_end_x + 8, 1)
	var far_right := image.get_pixel(image.get_width() - 2, image.get_height() / 2)
	return left_border.a > 0.5 and right_pane.a < 0.01 and far_right.a < 0.01

func _has_dropdown_box_assets(select: OptionButton) -> bool:
	if select == null:
		return false
	var normal := select.get_theme_stylebox("normal") as StyleBoxTexture
	var hover := select.get_theme_stylebox("hover") as StyleBoxTexture
	var pressed := select.get_theme_stylebox("pressed") as StyleBoxTexture
	var disabled := select.get_theme_stylebox("disabled") as StyleBoxTexture
	if normal == null or hover == null or pressed == null or disabled == null:
		return false
	if normal.texture == null or hover.texture == null or pressed.texture == null or disabled.texture == null:
		return false
	if normal.texture.get_size() != Vector2(340, 60) or hover.texture.get_size() != Vector2(340, 60) or pressed.texture.get_size() != Vector2(340, 60) or disabled.texture.get_size() != Vector2(340, 60):
		return false
	return (
		normal.texture.resource_path.ends_with("dropdown_box_normal.png")
		and hover.texture.resource_path.ends_with("dropdown_box_focus.png")
		and pressed.texture.resource_path.ends_with("dropdown_box_pressed.png")
		and disabled.texture.resource_path.ends_with("dropdown_box_disabled.png")
		and _has_unsliced_dropdown_texture(normal)
		and _has_unsliced_dropdown_texture(hover)
		and _has_unsliced_dropdown_texture(pressed)
		and _has_unsliced_dropdown_texture(disabled)
	)

func _has_unsliced_dropdown_texture(style: StyleBoxTexture) -> bool:
	return (
		is_zero_approx(style.texture_margin_left)
		and is_zero_approx(style.texture_margin_top)
		and is_zero_approx(style.texture_margin_right)
		and is_zero_approx(style.texture_margin_bottom)
	)

func _short_popup_has_no_scrollbar_and_matching_selection_icon(select: OptionButton, expected_height: int) -> bool:
	if select == null:
		return false
	var popup := select.get_popup()
	if popup == null or bool(popup.get_meta("ccr_settings_popup_embedded_scrollbar", true)):
		return false
	if popup.get_theme_font_size("font_size") != select.get_theme_font_size("font_size"):
		return false
	if int(popup.get_meta("ccr_settings_popup_divider_x", -1)) != CCRVisualStyle.SETTINGS_POPUP_DIVIDER_END_X:
		return false
	if popup.min_size != Vector2i(340, expected_height) or popup.max_size != Vector2i(340, expected_height):
		return false
	var panel := popup.get_theme_stylebox("panel") as StyleBoxTexture
	var closed := select.get_theme_stylebox("normal") as StyleBoxTexture
	if panel == null or panel.texture == null or panel.texture.get_size() != Vector2(340, expected_height):
		return false
	if closed == null or closed.texture == null or not _dropdown_dividers_are_aligned(closed.texture.get_image(), panel.texture.get_image()):
		return false
	var scrollbar := CCRVisualStyle._find_internal_v_scrollbar(popup)
	if scrollbar != null and scrollbar.visible:
		return false
	for icon_name in ["checked", "radio_checked"]:
		if not popup.has_theme_icon_override(icon_name):
			return false
		var icon := popup.get_theme_icon(icon_name)
		if not _icon_uses_color(icon, CCRVisualStyle.SETTINGS_TEXT):
			return false
	return true

func _dropdown_dividers_are_aligned(closed_image: Image, popup_image: Image) -> bool:
	if closed_image == null or closed_image.is_empty() or popup_image == null or popup_image.is_empty():
		return false
	var closed_center := _vertical_divider_center(closed_image)
	var popup_center := _vertical_divider_center(popup_image)
	return absf(closed_center - popup_center) <= 1.0 and absf(popup_center - 270.0) <= 2.0

func _vertical_divider_center(image: Image) -> float:
	var weighted_x := 0.0
	var total_weight := 0.0
	var y_start := maxi(8, int(roundf(float(image.get_height()) * 0.2)))
	var y_end := mini(image.get_height() - 8, int(roundf(float(image.get_height()) * 0.8)))
	for x in range(260, 282):
		var brightness := 0.0
		for y in range(y_start, y_end):
			var pixel := image.get_pixel(x, y)
			brightness += (pixel.r + pixel.g + pixel.b) / 3.0
		weighted_x += float(x) * brightness
		total_weight += brightness
	return weighted_x / total_weight if total_weight > 0.0 else -1.0

func _icon_uses_color(icon: Texture2D, expected: Color) -> bool:
	if icon == null:
		return false
	var image := icon.get_image()
	if image == null or image.is_empty():
		return false
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var pixel := image.get_pixel(x, y)
			if pixel.a >= 0.95:
				return absf(pixel.r - expected.r) <= 0.02 and absf(pixel.g - expected.g) <= 0.02 and absf(pixel.b - expected.b) <= 0.02
	return false

func _has_settings_tab_text_display_boxes(root: Node) -> bool:
	for tab_name in ["BasicSettingsTab", "ControllerSettingsTab", "ProfileSettingsTab"]:
		var tab := root.find_child(tab_name, true, false) as Button
		if tab == null or tab.custom_minimum_size != Vector2(220, 60):
			return false
		var normal := tab.get_theme_stylebox("normal") as StyleBoxTexture
		var hover := tab.get_theme_stylebox("hover") as StyleBoxTexture
		var pressed := tab.get_theme_stylebox("pressed") as StyleBoxTexture
		if normal == null or hover == null or pressed == null:
			return false
		if normal.texture == null or hover.texture == null or pressed.texture == null:
			return false
		if not _has_unsliced_dropdown_texture(normal) or not _has_unsliced_dropdown_texture(hover) or not _has_unsliced_dropdown_texture(pressed):
			return false
		var expected_normal := "line_edit_focus.png" if tab.button_pressed else "line_edit_normal.png"
		if not normal.texture.resource_path.ends_with(expected_normal):
			return false
		if not hover.texture.resource_path.ends_with("line_edit_focus.png") or not pressed.texture.resource_path.ends_with("line_edit_pressed.png"):
			return false
	return true

func _has_exit_dialog_button_visual(button: Button, destructive: bool) -> bool:
	if button == null:
		return false
	var normal := button.get_theme_stylebox("normal") as StyleBoxTexture
	var hover := button.get_theme_stylebox("hover") as StyleBoxTexture
	var pressed := button.get_theme_stylebox("pressed") as StyleBoxTexture
	if normal == null or hover == null or pressed == null:
		return false
	if normal.texture == null or hover.texture == null or pressed.texture == null:
		return false
	var expected := "exit_dialog_confirm_button.png" if destructive else "exit_dialog_cancel_button.png"
	if not normal.texture.resource_path.ends_with(expected) or not hover.texture.resource_path.ends_with(expected) or not pressed.texture.resource_path.ends_with(expected):
		return false
	if normal.texture.get_size() != Vector2(260, 80):
		return false
	return (
		absf(normal.texture_margin_left - 52.0) <= 0.1
		and absf(normal.texture_margin_top - 24.0) <= 0.1
		and _color_close(button.get_theme_color("font_color"), CCRVisualStyle.SETTINGS_TEXT)
		and _color_close(button.get_theme_color("font_hover_color"), CCRVisualStyle.SETTINGS_TEXT)
	)

func _settings_specific_labels_use_settings_color(root: Node) -> bool:
	for label_node in root.find_children("*", "Label", true, false):
		var label := label_node as Label
		if label != null and label.text == "Resolution":
			return _color_close(label.get_theme_color("font_color"), CCRVisualStyle.SETTINGS_TEXT)
	return false

func _has_profile_text_box_visual(root: Node) -> bool:
	var player_name_field := root.find_child("PlayerNameField", true, false) as LineEdit
	if player_name_field == null:
		return false
	if not player_name_field.editable:
		return false
	if player_name_field.alignment != HORIZONTAL_ALIGNMENT_CENTER:
		return false
	if player_name_field.size.x > 360.0:
		return false
	var normal := player_name_field.get_theme_stylebox("normal") as StyleBoxTexture
	var read_only := player_name_field.get_theme_stylebox("read_only") as StyleBoxTexture
	return (
		normal != null
		and read_only != null
		and normal.texture != null
		and read_only.texture != null
		and normal.texture.resource_path.ends_with("line_edit_normal.png")
		and read_only.texture.resource_path.ends_with("line_edit_disabled.png")
		and _has_unsliced_dropdown_texture(normal)
		and _has_unsliced_dropdown_texture(read_only)
	)

func _region_popup_matches_fixed_asset_and_scrollbar(main: MainUI, select: OptionButton) -> bool:
	var popup := select.get_popup()
	if popup == null or not popup.visible or popup.size.x != 340:
		return false
	var panel_style := popup.get_theme_stylebox("panel") as StyleBoxTexture
	var closed_style := select.get_theme_stylebox("normal") as StyleBoxTexture
	if panel_style == null or panel_style.texture == null or str(popup.get_meta("ccr_settings_popup_asset", "")) != "dropdown_menu_panel_region.png":
		return false
	if closed_style == null or closed_style.texture == null or not _dropdown_dividers_are_aligned(closed_style.texture.get_image(), panel_style.texture.get_image()):
		return false
	if panel_style.texture.get_size() != Vector2(340, 533) or not _has_unsliced_dropdown_texture(panel_style):
		return false
	var center_area := main.get("_center_area") as Control
	if center_area == null or popup.position.y < int(roundf(select.get_global_rect().end.y)):
		return false
	if popup.position.y + popup.size.y > int(floorf(center_area.get_global_rect().end.y - 4.0)) + 1:
		return false
	var scrollbar := CCRVisualStyle._find_internal_v_scrollbar(popup)
	if scrollbar == null or not scrollbar.visible or scrollbar.size.x < 68.0:
		return false
	var thumb := scrollbar.get_node_or_null("CCRDropdownScrollThumb") as TextureRect
	if thumb == null or thumb.texture == null or not thumb.visible or not thumb.texture.resource_path.ends_with("dropdown_scroll_thumb_normal.png"):
		return false
	CCRVisualStyle._set_settings_popup_scrollbar_state(scrollbar, "pressed")
	if thumb.texture == null or not thumb.visible or not thumb.texture.resource_path.ends_with("dropdown_scroll_thumb_focus.png"):
		return false
	CCRVisualStyle._set_settings_popup_scrollbar_state(scrollbar, "normal")
	if thumb.size.x <= 0.0 or thumb.size.y <= 0.0 or absf(thumb.size.x / thumb.size.y - thumb.texture.get_size().x / thumb.texture.get_size().y) > 0.01:
		return false
	var expected_thumb_center_x := scrollbar.size.x * 0.5 + CCRVisualStyle.SETTINGS_DROPDOWN_PANEL_CONTENT_MARGIN
	if absf(thumb.position.x + thumb.size.x * 0.5 - expected_thumb_center_x) > 1.0:
		return false
	var original_value := scrollbar.value
	var original_y := thumb.position.y
	scrollbar.value = maxf(scrollbar.min_value, scrollbar.max_value - scrollbar.page)
	CCRVisualStyle._layout_settings_popup_scrollbar_thumb(scrollbar)
	var moved := thumb.position.y > original_y + 1.0
	scrollbar.value = original_value
	CCRVisualStyle._layout_settings_popup_scrollbar_thumb(scrollbar)
	return moved

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

func _settings_rows_use_centered_two_column_alignment(root: Node) -> bool:
	var content := root.find_child("SettingsPageContent", true, false) as VBoxContainer
	if content == null:
		return false
	var content_rect := content.get_global_rect()
	var checked_rows := 0
	for child in content.get_children():
		if not child is HBoxContainer:
			continue
		var row := child as HBoxContainer
		if row.name == "AvatarSettingsControls":
			continue
		var children := row.get_children()
		if children.size() < 2 or not children[0] is Label or not children[children.size() - 1] is Control:
			continue
		var label := children[0] as Label
		var control := children[children.size() - 1] as Control
		var row_rect := row.get_global_rect()
		if absf(row_rect.position.x - content_rect.position.x) > 1.0 or absf(row_rect.end.x - content_rect.end.x) > 1.0:
			return false
		if label.horizontal_alignment != HORIZONTAL_ALIGNMENT_LEFT or (label.size_flags_horizontal & Control.SIZE_EXPAND) == 0:
			return false
		if absf(label.get_global_rect().position.x - content_rect.position.x) > 1.0:
			return false
		if absf(control.get_global_rect().end.x - content_rect.end.x) > 1.0:
			return false
		checked_rows += 1
	var action_names := ["SettingsLogoutButton", "ResetControllerButton"]
	for action_name in action_names:
		var action := root.find_child(action_name, true, false) as Control
		if action != null and absf(action.get_global_rect().end.x - content_rect.end.x) > 1.0:
			return false
	return checked_rows > 0

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
	var found_mute_label := false
	var found_logout := false
	for label_node in root.find_children("*", "Label", true, false):
		var label := label_node as Label
		if label != null and (label.text == "Mute" or label.text == "Muted"):
			found_mute_label = true
	for child in root.find_children("*", "Button", true, false):
		var button := child as Button
		if button == null:
			continue
		if button.text == "Logout":
			found_logout = true
		if button.text.begins_with("🔊") or button.text.begins_with("🔇") or button.text.begins_with("🚪"):
			return false
	return found_mute_label and found_logout

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
