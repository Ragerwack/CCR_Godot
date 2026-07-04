extends Node

const LoadingScreenScene := preload("res://Scenes/UI/LoadingScreen.tscn")
const LoadingTutorialUIScript := preload("res://Scripts/UI/LoadingTutorialUI.gd")

var _failed := false

func _ready() -> void:
	await _test_loading_screen_scene()
	if _failed:
		return
	await _test_loading_tutorial_background()
	if _failed:
		return
	await _test_splash_background()
	if _failed:
		return
	await _test_main_background()
	if _failed:
		return
	print("LOADING_BACKGROUND ok")
	get_tree().quit(0)

func _test_loading_screen_scene() -> void:
	var loading := LoadingScreenScene.instantiate()
	add_child(loading)
	await get_tree().process_frame
	if loading.name != "LoadingRoot":
		_fail("loading scene root name is wrong")
		return
	var background := loading.find_child("BackgroundImage", true, false) as TextureRect
	if background == null:
		_fail("loading background node missing")
		return
	if background.stretch_mode != TextureRect.STRETCH_SCALE:
		_fail("loading background is not stretch scale")
		return
	loading.set_tip("basic", "测试标题", "测试正文")
	loading.set_progress(42.0, "同步中")
	loading.set_server_status("服务器在线")
	loading.set_version("CCR test")
	loading.set_tip("rarity", "第二条标题", "第二条正文")
	await get_tree().create_timer(0.28).timeout
	var panel := loading.find_child("LoadingPanel", true, false) as PanelContainer
	if panel == null:
		_fail("loading panel missing")
		return
	var vp_size := get_viewport().get_visible_rect().size
	var expected_left := 0.14 if vp_size.x <= 1400.0 or vp_size.y <= 850.0 else 0.24
	var expected_right := 0.86 if vp_size.x <= 1400.0 or vp_size.y <= 850.0 else 0.76
	if absf(panel.anchor_left - expected_left) > 0.001 or absf(panel.anchor_right - expected_right) > 0.001:
		_fail("loading panel does not use responsive anchors")
		return
	var body := loading.find_child("TipBodyLabel", true, false) as Label
	if body == null or body.autowrap_mode == TextServer.AUTOWRAP_OFF:
		_fail("tip body wrapping is disabled")
		return
	if body.text != "测试正文":
		_fail("loading tip changed during one loading session")
		return
	var loading_content := loading.find_child("LoadingContent", true, false) as VBoxContainer
	if loading_content == null:
		_fail("loading content missing")
		return
	if loading_content.find_child("ProgressTextLabel", true, false) != null or loading_content.find_child("LoadingProgressBar", true, false) != null:
		_fail("login progress is still inside tip panel")
		return
	var bottom_right := loading.find_child("BottomRightInfo", true, false) as VBoxContainer
	if bottom_right == null:
		_fail("bottom right status area missing")
		return
	var progress_label := loading.find_child("ProgressTextLabel", true, false) as Label
	if progress_label == null or progress_label.get_parent() != bottom_right:
		_fail("progress label is not in bottom right status area")
		return
	var progress_bar := loading.find_child("LoadingProgressBar", true, false) as ProgressBar
	if progress_bar == null or progress_bar.get_parent() != bottom_right:
		_fail("progress bar is not in bottom right status area")
		return
	var label_names := [
		"TipCategoryLabel",
		"TipTitleLabel",
		"TipBodyLabel",
		"ProgressTextLabel",
		"ServerStatusLabel",
		"VersionLabel",
	]
	for label_name in label_names:
		var label := loading.find_child(label_name, true, false) as Label
		if label == null:
			_fail("loading label missing: " + label_name)
			return
		if not _label_has_white_font(label):
			_fail("loading label is not white: " + label_name)
			return
	var progress := loading.find_child("LoadingProgressBar", true, false) as ProgressBar
	if progress == null or progress.value <= 0.0:
		_fail("loading progress did not update")
		return
	loading.queue_free()

func _test_loading_tutorial_background() -> void:
	var tutorial := LoadingTutorialUIScript.new()
	add_child(tutorial)
	await get_tree().process_frame
	tutorial.setup_for_level(1)
	await get_tree().process_frame
	var background := tutorial.find_child("BackgroundImage", true, false) as TextureRect
	if background == null or background.texture == null:
		_fail("tutorial loading background missing")
		return
	if background.stretch_mode != TextureRect.STRETCH_SCALE:
		_fail("tutorial loading background is not stretch scale")
		return
	tutorial.queue_free()

func _test_splash_background() -> void:
	ApiClient.logout()
	var splash := SplashScreenUI.new()
	add_child(splash)
	await get_tree().process_frame
	var background := splash.find_child("LoginBackgroundImage", true, false) as TextureRect
	if background == null or background.texture == null:
		_fail("login background missing")
		return
	if background.stretch_mode != TextureRect.STRETCH_SCALE:
		_fail("login background is not stretch scale")
		return
	var login_texture_path := background.texture.resource_path
	splash.call("_show_login_background")
	await get_tree().process_frame
	if background.texture == null or background.texture.resource_path != login_texture_path:
		_fail("login form background changed away from login background")
		return
	splash.call("_show_loading_screen_ui", "测试载入", "测试同步", 35.0)
	await get_tree().process_frame
	var loading_screen := splash.find_child("LoginLoadingScreen", true, false) as LoadingScreenUI
	if loading_screen == null:
		_fail("login loading screen missing")
		return
	var loading_background := loading_screen.find_child("BackgroundImage", true, false) as TextureRect
	if loading_background == null or loading_background.texture == null:
		_fail("login loading screen background missing")
		return
	if loading_background.stretch_mode != TextureRect.STRETCH_SCALE:
		_fail("login loading screen background is not stretch scale")
		return
	if loading_background.texture.resource_path == login_texture_path:
		_fail("login loading screen reused login background")
		return
	var tip_body := loading_screen.find_child("TipBodyLabel", true, false) as Label
	if tip_body == null or tip_body.text == "测试同步":
		_fail("login progress was written into loading tip box")
		return
	var loading_progress := loading_screen.find_child("ProgressTextLabel", true, false) as Label
	if loading_progress == null or loading_progress.text != "测试同步":
		_fail("login progress was not written to bottom right status area")
		return
	splash.queue_free()

func _test_main_background() -> void:
	var main := MainUI.new()
	add_child(main)
	await get_tree().process_frame
	var background := main.find_child("MainBackgroundImage", false, false) as TextureRect
	if background == null or background.texture == null:
		_fail("main background missing")
		return
	if background.get_index() != 0:
		_fail("main background is not bottom child")
		return
	var splash := main.find_child("SplashScreenUI", false, false) as SplashScreenUI
	if splash == null:
		_fail("main did not show splash login screen")
		return
	if background.visible:
		_fail("main background is visible behind login screen")
		return
	var center_area := main.find_child("CenterArea", false, false) as Control
	if center_area == null:
		_fail("main center area missing")
		return
	if center_area.visible:
		_fail("card slots are visible behind login screen")
		return
	if background.stretch_mode != TextureRect.STRETCH_SCALE:
		_fail("main background is not stretch scale")
		return
	var slot_shadow := main.find_child("SlotShadow", true, false) as Panel
	if slot_shadow == null:
		_fail("card slot shadow missing")
		return
	var title_label := main.find_child("MuseumTitle", true, false) as Label
	if title_label != null:
		_fail("museum title should be hidden")
		return
	var exp_value_label := main.find_child("ExpValueLabel", true, false) as Label
	if exp_value_label == null:
		_fail("exp value label missing")
		return
	if not _label_has_white_font(exp_value_label):
		_fail("exp value label is not white")
		return
	main.queue_free()

func _label_has_white_font(label: Label) -> bool:
	if label == null or not label.has_theme_color_override("font_color"):
		return false
	var color := label.get_theme_color("font_color")
	return (
		is_equal_approx(color.r, 1.0)
		and is_equal_approx(color.g, 1.0)
		and is_equal_approx(color.b, 1.0)
		and is_equal_approx(color.a, 1.0)
	)

func _fail(message: String) -> void:
	_failed = true
	push_error("LOADING_BACKGROUND " + message)
	get_tree().quit(1)
