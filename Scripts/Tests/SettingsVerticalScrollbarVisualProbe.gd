extends Node

func _ready() -> void:
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
	main.call("_select_settings_tab", "controller")
	await get_tree().process_frame
	await get_tree().process_frame
	var page_content := main.find_child("SettingsPageContent", true, false)
	if page_content == null:
		_fail("settings page content is missing")
		return
	for node in page_content.find_children("*", "OptionButton", true, false):
		var select := node as OptionButton
		if select != null and (absf(select.size.x - 340.0) > 1.0 or select.alignment != HORIZONTAL_ALIGNMENT_CENTER):
			_fail("controller dropdown width or alignment is wrong")
			return

	var page_scroll := main.find_child("SettingsPageScroll", true, false) as ScrollContainer
	if page_scroll == null:
		_fail("settings page scroll container is missing")
		return
	var scrollbar := page_scroll.get_v_scroll_bar()
	if scrollbar == null:
		_fail("vertical scrollbar is missing")
		return
	var track := scrollbar.find_child("CCRVerticalScrollbarTrack", false, false) as NinePatchRect
	var thumb := scrollbar.find_child("CCRVerticalScrollbarThumb", false, false) as TextureRect
	if not scrollbar.visible or track == null or thumb == null:
		_fail("vertical scrollbar parts are not visible")
		return
	var top_thumb_y := thumb.position.y
	await RenderingServer.frame_post_draw
	if not _save_screenshot("CCR_SETTINGS_VERTICAL_SCROLLBAR_TOP_SCREENSHOT_PATH"):
		return

	scrollbar.value = maxf(scrollbar.min_value, scrollbar.max_value - scrollbar.page)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	if thumb.position.y <= top_thumb_y:
		_fail("vertical scrollbar thumb did not move")
		return
	if not _save_screenshot("CCR_SETTINGS_VERTICAL_SCROLLBAR_BOTTOM_SCREENSHOT_PATH"):
		return

	print("SETTINGS_VERTICAL_SCROLLBAR_VISUAL_PROBE ok")
	get_tree().quit(0)

func _save_screenshot(environment_key: String) -> bool:
	var screenshot_path := OS.get_environment(environment_key)
	if screenshot_path == "":
		return true
	var screenshot := get_viewport().get_texture().get_image()
	if screenshot == null or screenshot.is_empty() or screenshot.save_png(screenshot_path) != OK:
		_fail("vertical scrollbar screenshot could not be saved: " + environment_key)
		return false
	return true

func _fail(message: String) -> void:
	push_error("SETTINGS_VERTICAL_SCROLLBAR_VISUAL_PROBE " + message)
	get_tree().quit(1)
