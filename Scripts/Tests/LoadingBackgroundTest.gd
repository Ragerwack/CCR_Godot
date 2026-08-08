extends Node

const LoadingScreenScene := preload("res://Scenes/UI/LoadingScreen.tscn")
const LoadingTutorialUIScript := preload("res://Scripts/UI/LoadingTutorialUI.gd")
const CCRVisualStyle := preload("res://Scripts/UI/CCRVisualStyle.gd")

var _failed := false

func _ready() -> void:
	await _test_loading_screen_scene()
	if _failed:
		return
	await _test_loading_tutorial_background()
	if _failed:
		return
	await _test_loading_tutorial_locales()
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
	Localization.set_locale("zh-CN")
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
	loading.set_tip("basic", "合成圣物的条件", "合成圣物需要凑齐同一个卡组、同一种颜色、编号不同的 5 张子卡。例如：同一套卡组的白色 1/5、2/5、3/5、4/5、5/5，可以合成一个白色圣物。", "同卡组、同颜色、5 个不同编号，才能合成圣物。")
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
	var is_small := vp_size.x <= 1400.0 or vp_size.y <= 850.0
	var expected_left := 0.14 if is_small else 0.24
	var expected_right := 0.86 if is_small else 0.76
	var expected_top := 0.45 if is_small else 0.56
	var expected_bottom := 0.84 if is_small else 0.88
	if absf(panel.anchor_left - expected_left) > 0.001 or absf(panel.anchor_right - expected_right) > 0.001 or absf(panel.anchor_top - expected_top) > 0.001 or absf(panel.anchor_bottom - expected_bottom) > 0.001:
		_fail("loading panel does not use responsive anchors")
		return
	var body := loading.find_child("TipBodyLabel", true, false) as Label
	if body == null or body.autowrap_mode == TextServer.AUTOWRAP_OFF:
		_fail("tip body wrapping is disabled")
		return
	if body.text != "合成圣物需要凑齐同一个卡组、同一种颜色、编号不同的 5 张子卡。例如：同一套卡组的白色 1/5、2/5、3/5、4/5、5/5，可以合成一个白色圣物。":
		_fail("loading tip changed during one loading session")
		return
	var short_tip := loading.find_child("TipShortLabel", true, false) as Label
	if short_tip == null or short_tip.text != Localization.t("ui.loading_tip.short_prefix") + " · 同卡组、同颜色、5 个不同编号，才能合成圣物。" or short_tip.autowrap_mode == TextServer.AUTOWRAP_OFF or short_tip.clip_text:
		_fail("loading short tip did not render")
		return
	var title := loading.find_child("TipTitleLabel", true, false) as Label
	if title == null or title.clip_text or not title.visible or not body.visible or not short_tip.visible:
		_fail("loading title, body, and short tip are not all visible")
		return
	if title.global_position.y >= body.global_position.y or body.global_position.y >= short_tip.global_position.y:
		_fail("loading tip is not ordered as title, body, short tip")
		return
	if not panel.get_global_rect().encloses(title.get_global_rect()) or not panel.get_global_rect().encloses(body.get_global_rect()) or not panel.get_global_rect().encloses(short_tip.get_global_rect()):
		_fail("loading tip content exceeds its panel")
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
		"TipShortLabel",
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
	var title := tutorial.find_child("TipTitleLabel", true, false) as Label
	var body := tutorial.find_child("TipBodyLabel", true, false) as Label
	var short_tip := tutorial.find_child("TipShortLabel", true, false) as Label
	if title == null or title.text.is_empty() or body == null or body.text.is_empty() or short_tip == null or short_tip.text.is_empty():
		_fail("tutorial title, body, or short tip is missing")
		return
	for tip in LoadingTutorialUIScript.LOADING_TUTORIAL_TIPS:
		var visible_tip := "%s\n%s\n%s\n%s" % [str(tip.get("category", "")), str(tip.get("title", "")), str(tip.get("body", "")), str(tip.get("short_tip", ""))]
		if visible_tip.contains("relic") or visible_tip.contains("Relic") or visible_tip.contains("红"):
			_fail("Chinese tutorial tip exposes relic or red-card wording: " + str(tip.get("id", "unknown")))
			return
		for hidden_feature in ["鉴定", "橱窗", "拍卖行"]:
			if visible_tip.contains(hidden_feature):
				_fail("Chinese tutorial tip exposes an unreleased feature: " + str(tip.get("id", "unknown")))
				return
	for tip in LoadingTutorialUIScript.LOADING_TUTORIAL_TIPS_EN:
		var english_tip_text := JSON.stringify(tip).to_lower()
		if english_tip_text.contains("red card") or english_tip_text.contains("red-card"):
			_fail("English tutorial tip exposes red-card wording: " + str(tip.get("id", "unknown")))
			return
	var background := tutorial.find_child("BackgroundImage", true, false) as TextureRect
	if background == null or background.texture == null:
		_fail("tutorial loading background missing")
		return
	if background.stretch_mode != TextureRect.STRETCH_SCALE:
		_fail("tutorial loading background is not stretch scale")
		return
	tutorial.queue_free()

func _test_loading_tutorial_locales() -> void:
	for tip in LoadingTutorialUIScript.LOADING_TUTORIAL_TIPS_JA:
		var ja_tip_text := JSON.stringify(tip)
		for forbidden_term in ["レリック", "カタログ"]:
			if ja_tip_text.contains(str(forbidden_term)):
				_fail("Japanese loading tip contains forbidden term %s: %s" % [forbidden_term, str(tip.get("id", "unknown"))])
				return
	for tip in LoadingTutorialUIScript.LOADING_TUTORIAL_TIPS_KO:
		var ko_tip_text := JSON.stringify(tip)
		for forbidden_term in ["렐릭", "카탈로그"]:
			if ko_tip_text.contains(str(forbidden_term)):
				_fail("Korean loading tip contains forbidden term %s: %s" % [forbidden_term, str(tip.get("id", "unknown"))])
				return
	for locale in Localization.get_supported_locales():
		Localization.set_locale(str(locale))
		var tutorial := LoadingTutorialUIScript.new()
		add_child(tutorial)
		await get_tree().process_frame
		tutorial.setup_for_level(30)
		await get_tree().process_frame
		var title := tutorial.find_child("TipTitleLabel", true, false) as Label
		var body := tutorial.find_child("TipBodyLabel", true, false) as Label
		var short_tip := tutorial.find_child("TipShortLabel", true, false) as Label
		if title == null or title.text.is_empty() or body == null or body.text.is_empty() or short_tip == null or short_tip.text.is_empty():
			_fail("localized tutorial text missing for " + str(locale))
			return
		if not short_tip.text.begins_with(Localization.t("ui.loading_tip.short_prefix") + " · "):
			_fail("localized tutorial short prefix wrong for " + str(locale) + ": " + short_tip.text)
			return
		if str(locale) in ["en", "ja", "ko"] and short_tip.text.contains("短提示"):
			_fail("non-Chinese tutorial short prefix contains Chinese for " + str(locale))
			return
		tutorial.queue_free()
		await get_tree().process_frame
	Localization.set_locale("en")

func _test_splash_background() -> void:
	# 测试只隔离当前进程的登录态，不改写开发者本机保存的 token。
	ApiClient._auth_token = ""
	ApiClient._refresh_token = ""
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
	main.call("_show_splash_screen")
	var splash_count := 0
	for child in main.get_children():
		if child.name == "SplashScreenUI":
			splash_count += 1
	if splash_count != 1:
		_fail("main created duplicate splash after login failure")
		return
	if splash.z_index != 4096:
		_fail("login splash is not above game button icons")
		return
	if background.visible:
		_fail("main background is visible behind login screen")
		return
	var nav_buttons := main.get("_nav_buttons") as NavButtons
	if nav_buttons == null or nav_buttons.is_visible_in_tree():
		_fail("navigation is visible behind login screen")
		return
	var center_area := main.find_child("CenterArea", false, false) as Control
	if center_area == null:
		_fail("main center area missing")
		return
	if center_area.visible:
		_fail("card slots are visible behind login screen")
		return
	for icon_node in main.find_children(CCRVisualStyle.BUTTON_ICON_NODE_NAME, "TextureRect", true, false):
		var icon := icon_node as TextureRect
		if icon != null and icon.is_visible_in_tree():
			_fail("game button icon is visible behind login: " + str(icon.get_parent().name))
			return
	if bool(ApiClient.call("_should_invalidate_access_token", "https://ccrgame.com/api/auth/login")):
		_fail("login 401 invalidates an existing access token")
		return
	if bool(ApiClient.call("_should_emit_auth_expired", "https://ccrgame.com/api/auth/login")):
		_fail("login 401 emits global auth expired")
		return
	if not bool(ApiClient.call("_should_emit_auth_expired", "https://ccrgame.com/api/user/profile")):
		_fail("protected endpoint 401 does not emit auth expired")
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
