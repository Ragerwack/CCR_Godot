extends Node

func _ready() -> void:
	get_viewport().gui_embed_subwindows = true
	ApiClient.logout()
	Localization.set_locale("en")
	var main := MainUI.new()
	main.size = get_viewport().get_visible_rect().size
	add_child(main)
	await get_tree().process_frame
	for child in main.get_children():
		if child.has_method("_selected_country_code"):
			child.hide()
			break

	main.call("_set_game_ui_visible", true)
	var nav_buttons: NavButtons = main.get("_nav_buttons")
	if nav_buttons == null:
		_fail("navigation is missing")
		return
	nav_buttons.nav_button_clicked.emit("settings")
	await get_tree().process_frame
	await get_tree().process_frame

	var resolution_select := main.find_child("ResolutionSelect", true, false) as OptionButton
	if resolution_select == null:
		_fail("resolution dropdown is missing")
		return
	print("DROPDOWN_METRICS closed_name=%s closed_size=%s closed_rect=%s" % [resolution_select.name, resolution_select.size, resolution_select.get_global_rect()])
	await RenderingServer.frame_post_draw
	if not _save_screenshot("CCR_SETTINGS_DROPDOWN_CLOSED_SCREENSHOT_PATH"):
		return

	resolution_select.show_popup()
	await get_tree().process_frame
	var popup := resolution_select.get_popup()
	if popup == null or not popup.visible:
		_fail("resolution dropdown popup is not visible")
		return
	print("DROPDOWN_METRICS popup_name=%s popup_size=%s popup_position=%s item_count=%d" % [resolution_select.name, popup.size, popup.position, popup.item_count])
	_print_control_tree(popup)
	for index in range(popup.item_count):
		if popup.get_item_indent(index) <= 0:
			_fail("resolution dropdown popup item is not centered")
			return
	await RenderingServer.frame_post_draw

	if not _save_screenshot("CCR_SETTINGS_DROPDOWN_SCREENSHOT_PATH"):
		return

	popup.hide()
	for short_select_name in ["WindowModeSelect", "LanguageSelect"]:
		var short_select := main.find_child(short_select_name, true, false) as OptionButton
		if short_select == null:
			_fail("%s is missing" % short_select_name)
			return
		short_select.show_popup()
		await get_tree().process_frame
		var short_popup := short_select.get_popup()
		var short_scrollbar := CCRVisualStyle._find_internal_v_scrollbar(short_popup)
		if bool(short_popup.get_meta("ccr_settings_popup_embedded_scrollbar", true)) or (short_scrollbar != null and short_scrollbar.visible):
			_fail("%s still exposes the old vertical scrollbar" % short_select_name)
			return
		await RenderingServer.frame_post_draw
		var screenshot_key := "CCR_SETTINGS_WINDOW_MODE_DROPDOWN_SCREENSHOT_PATH" if short_select_name == "WindowModeSelect" else "CCR_SETTINGS_LANGUAGE_DROPDOWN_SCREENSHOT_PATH"
		if not _save_screenshot(screenshot_key):
			return
		short_popup.hide()

	main.call("_select_settings_tab", "controller")
	await get_tree().process_frame
	await get_tree().process_frame
	var controller_selects := main.find_children("*", "OptionButton", true, false)
	if controller_selects.is_empty():
		_fail("controller dropdown is missing")
		return
	var controller_select := controller_selects[0] as OptionButton
	controller_select.show_popup()
	await get_tree().process_frame
	var controller_popup := controller_select.get_popup()
	print("DROPDOWN_METRICS popup_name=ControllerBinding popup_size=%s popup_position=%s item_count=%d" % [controller_popup.size, controller_popup.position, controller_popup.item_count])
	var controller_scrollbar := CCRVisualStyle._find_internal_v_scrollbar(controller_popup)
	if bool(controller_popup.get_meta("ccr_settings_popup_embedded_scrollbar", true)) or (controller_scrollbar != null and controller_scrollbar.visible):
		_fail("controller binding dropdown still exposes the old vertical scrollbar")
		return
	await RenderingServer.frame_post_draw
	if not _save_screenshot("CCR_SETTINGS_CONTROLLER_DROPDOWN_SCREENSHOT_PATH"):
		return
	controller_popup.hide()

	main.call("_select_settings_tab", "profile")
	await get_tree().process_frame
	await get_tree().process_frame
	var region_select := main.find_child("RegionSelect", true, false) as OptionButton
	if region_select == null:
		_fail("region dropdown is missing")
		return
	print("DROPDOWN_METRICS closed_name=%s closed_size=%s closed_rect=%s" % [region_select.name, region_select.size, region_select.get_global_rect()])
	region_select.show_popup()
	await get_tree().process_frame
	await get_tree().process_frame
	var region_popup := region_select.get_popup()
	if region_popup == null or not region_popup.visible:
		_fail("region dropdown popup is not visible")
		return
	print("DROPDOWN_METRICS popup_name=%s popup_size=%s popup_position=%s item_count=%d center_bottom=%.1f" % [region_select.name, region_popup.size, region_popup.position, region_popup.item_count, main.get("_center_area").get_global_rect().end.y])
	_print_control_tree(region_popup)
	await RenderingServer.frame_post_draw
	if not _save_screenshot("CCR_SETTINGS_REGION_DROPDOWN_SCREENSHOT_PATH"):
		return
	var region_scrollbar := CCRVisualStyle._find_internal_v_scrollbar(region_popup)
	var region_thumb := region_scrollbar.get_node_or_null("CCRDropdownScrollThumb") as TextureRect if region_scrollbar != null else null
	if region_scrollbar == null or region_thumb == null:
		_fail("region dropdown scrollbar thumb is missing")
		return
	var expected_thumb_center_x := region_scrollbar.size.x * 0.5 + CCRVisualStyle.SETTINGS_DROPDOWN_PANEL_CONTENT_MARGIN
	if absf(region_thumb.position.x + region_thumb.size.x * 0.5 - expected_thumb_center_x) > 1.0:
		_fail("region dropdown scrollbar thumb is not centered on the visual track")
		return
	CCRVisualStyle._set_settings_popup_scrollbar_state(region_scrollbar, "pressed")
	if region_thumb.texture == null or not region_thumb.visible or not region_thumb.texture.resource_path.ends_with("dropdown_scroll_thumb_focus.png"):
		_fail("region dropdown scrollbar thumb disappeared while dragging")
		return
	await RenderingServer.frame_post_draw
	if not _save_screenshot("CCR_SETTINGS_REGION_DROPDOWN_DRAG_SCREENSHOT_PATH"):
		return
	CCRVisualStyle._set_settings_popup_scrollbar_state(region_scrollbar, "normal")
	var original_thumb_y := region_thumb.position.y
	region_scrollbar.value = maxf(region_scrollbar.min_value, region_scrollbar.max_value - region_scrollbar.page)
	CCRVisualStyle._layout_settings_popup_scrollbar_thumb(region_scrollbar)
	if region_thumb.position.y <= original_thumb_y + 1.0:
		_fail("region dropdown scrollbar thumb did not move")
		return
	await RenderingServer.frame_post_draw
	if not _save_screenshot("CCR_SETTINGS_REGION_DROPDOWN_BOTTOM_SCREENSHOT_PATH"):
		return

	print("SETTINGS_DROPDOWN_VISUAL_PROBE ok")
	get_tree().quit(0)

func _fail(message: String) -> void:
	push_error("SETTINGS_DROPDOWN_VISUAL_PROBE " + message)
	get_tree().quit(1)

func _save_screenshot(environment_key: String) -> bool:
	var screenshot_path := OS.get_environment(environment_key)
	if screenshot_path == "":
		return true
	var screenshot := get_viewport().get_texture().get_image()
	if screenshot == null or screenshot.is_empty() or screenshot.save_png(screenshot_path) != OK:
		_fail("dropdown screenshot could not be saved: " + environment_key)
		return false
	return true

func _print_control_tree(root: Node, depth: int = 0) -> void:
	for child in root.get_children(true):
		var details := ""
		if child is Control:
			var control := child as Control
			details = " size=%s pos=%s visible=%s" % [control.size, control.position, control.visible]
		print("DROPDOWN_TREE %s%s<%s>%s" % ["  ".repeat(depth), child.name, child.get_class(), details])
		_print_control_tree(child, depth + 1)
