extends Node

const CCRVisualStyle := preload("res://Scripts/UI/CCRVisualStyle.gd")

func _ready() -> void:
	# 回归测试只能隔离当前进程，不能清除开发者本机保存的真实登录凭据。
	ApiClient._auth_token = ""
	ApiClient._refresh_token = ""

	var main := MainUI.new()
	main.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame

	var splash := main.find_child("SplashScreenUI", false, false) as Control
	if splash == null:
		return _fail("initial_login_splash_missing")
	main.call("_show_splash_screen")
	await get_tree().process_frame

	var splash_count := 0
	for child in main.get_children():
		if child.name == "SplashScreenUI":
			splash_count += 1
	if splash_count != 1:
		return _fail("duplicate_login_splash=%d" % splash_count)
	if splash.z_index != 4096:
		return _fail("login_splash_z_index_wrong=%d" % splash.z_index)

	var nav_buttons := main.get("_nav_buttons") as NavButtons
	var center_area := main.get("_center_area") as Control
	if nav_buttons == null or center_area == null:
		return _fail("game_ui_nodes_missing")
	if nav_buttons.is_visible_in_tree() or center_area.is_visible_in_tree():
		return _fail("game_ui_visible_behind_login")
	for icon_node in main.find_children(CCRVisualStyle.BUTTON_ICON_NODE_NAME, "TextureRect", true, false):
		var icon := icon_node as TextureRect
		if icon != null and icon.is_visible_in_tree():
			return _fail("game_button_icon_visible=" + str(icon.get_parent().name))

	if bool(ApiClient.call("_should_invalidate_access_token", "https://ccrgame.com/api/auth/login")):
		return _fail("login_401_invalidates_access_token")
	if bool(ApiClient.call("_should_emit_auth_expired", "https://ccrgame.com/api/auth/login")):
		return _fail("login_401_emits_global_auth_expired")
	if not bool(ApiClient.call("_should_emit_auth_expired", "https://ccrgame.com/api/user/profile")):
		return _fail("protected_401_does_not_emit_auth_expired")

	print("LOGIN_OVERLAY_ISOLATION ok splash=1 icons_hidden=true login_401_global_signal=false")
	get_tree().quit(0)

func _fail(message: String) -> void:
	push_error("LOGIN_OVERLAY_ISOLATION " + message)
	get_tree().quit(1)
