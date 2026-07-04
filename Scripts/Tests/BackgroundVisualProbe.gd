extends Node

func _ready() -> void:
	get_window().size = Vector2i(1280, 800)
	await _capture_login()
	await _capture_loading()
	await _capture_legacy_login()
	print("BACKGROUND_VISUAL_PROBE ok")
	get_tree().quit(0)

func _capture_login() -> void:
	ApiClient.logout()
	var splash := SplashScreenUI.new()
	add_child(splash)
	await get_tree().process_frame
	await get_tree().process_frame
	var bg := splash.find_child("LoginBackgroundImage", true, false) as TextureRect
	_assert_full_rect("login_root", splash)
	_assert_full_rect("login_bg", bg)
	splash.queue_free()
	await get_tree().process_frame

func _capture_loading() -> void:
	var splash := SplashScreenUI.new()
	add_child(splash)
	await get_tree().process_frame
	splash.call("_show_loading_screen_ui", "测试载入", "测试同步", 35.0)
	await get_tree().process_frame
	await get_tree().process_frame
	var loading := splash.find_child("LoginLoadingScreen", true, false) as LoadingScreenUI
	var bg := loading.find_child("BackgroundImage", true, false) as TextureRect
	_assert_full_rect("loading_root", loading)
	_assert_full_rect("loading_bg", bg)
	var panel := loading.find_child("LoadingPanel", true, false) as PanelContainer
	if panel == null:
		_fail("loading panel missing")
		return
	var panel_rect := panel.get_global_rect()
	if panel_rect.position.x <= 20.0 and panel_rect.position.y <= 20.0:
		_fail("loading panel is stuck at top-left: %s" % str(panel_rect))
		return
	splash.queue_free()
	await get_tree().process_frame

func _capture_legacy_login() -> void:
	var login := LoginUI.new()
	add_child(login)
	await get_tree().process_frame
	await get_tree().process_frame
	var bg := login.find_child("LoginBackgroundImage", true, false) as TextureRect
	_assert_full_rect("legacy_login_root", login)
	_assert_full_rect("legacy_login_bg", bg)
	login.call("_show_loading_screen_ui", "测试同步", 55.0)
	await get_tree().process_frame
	var loading := login.find_child("LoadingRoot", true, false) as LoadingScreenUI
	var loading_bg := loading.find_child("BackgroundImage", true, false) as TextureRect
	_assert_full_rect("legacy_loading_root", loading)
	_assert_full_rect("legacy_loading_bg", loading_bg)
	login.queue_free()
	await get_tree().process_frame

func _assert_full_rect(label: String, node: Control) -> void:
	if node == null:
		_fail(label + " missing")
		return
	var rect := node.get_global_rect()
	var vp_size := get_viewport().get_visible_rect().size
	if rect.size.x < vp_size.x - 1.0 or rect.size.y < vp_size.y - 1.0:
		_fail("%s is not fullscreen: rect=%s viewport=%s" % [label, str(rect), str(vp_size)])

func _fail(message: String) -> void:
	push_error("BACKGROUND_VISUAL_PROBE " + message)
	get_tree().quit(1)
