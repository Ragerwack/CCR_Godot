extends Control
class_name SplashScreenUI

## SplashScreenUI — 全屏开机界面
## 显示 splash 背景图片 + 登录/注册表单
## 登录/注册成功后发射 login_completed 信号，父节点负责清理

signal login_completed()

# ══════════════════════════════════════════════════
#  状态
# ══════════════════════════════════════════════════

var _mode: String = "login"  # "login" | "register"

# UI 控件引用
var _panel: Panel
var _title: Label
var _error_label: Label
var _username_input: LineEdit
var _password_input: LineEdit
var _email_input: LineEdit
var _submit_button: Button
var _switch_button: Button
var _loading_label: Label
var _progress_ui = null
var _step_started_at: Dictionary = {}
var _last_submit: Dictionary = {}
var _login_flow_running: bool = false

const PREP_STEPS: Array[Dictionary] = [
	{"id": "connect", "label": "ui.login.prepare.step.connect"},
	{"id": "auth", "label": "ui.login.prepare.step.auth"},
	{"id": "session", "label": "ui.login.prepare.step.session"},
	{"id": "profile", "label": "ui.login.prepare.step.profile"},
	{"id": "config", "label": "ui.login.prepare.step.config"},
	{"id": "collection", "label": "ui.login.prepare.step.collection"},
	{"id": "daily", "label": "ui.login.prepare.step.daily"},
	{"id": "ui", "label": "ui.login.prepare.step.ui"},
]
const PREP_STATUS_PENDING := "pending"
const PREP_STATUS_RUNNING := "running"
const PREP_STATUS_SUCCESS := "success"
const PREP_STATUS_FAILED := "failed"

# ══════════════════════════════════════════════════
#  生命周期
# ══════════════════════════════════════════════════

func _ready() -> void:
	FileLogger.log("SplashScreenUI 启动")
	_setup_ui()
	_update_mode()
	# 跳过自动登录，每次都显示登录表单
	FileLogger.log("等待用户输入")


# ══════════════════════════════════════════════════
#  界面搭建
# ══════════════════════════════════════════════════

func _setup_ui() -> void:
	# 全屏覆盖
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	# ── 1. 全屏背景图片 ──
	var splash_texture := TextureRect.new()
	splash_texture.set_anchors_preset(Control.PRESET_FULL_RECT)
	splash_texture.texture = load("res://Resources/Splash/ChatGPT Image 2026年5月17日 14_58_15.png")
	splash_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(splash_texture)

	# ── 2. 半透明暗色遮罩 ──
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.4)
	add_child(bg)

	# ── 3. 居中登录面板 ──
	_panel = Panel.new()
	_panel.position = Vector2(
		(get_viewport_rect().size.x - 400) / 2.0,
		(get_viewport_rect().size.y - 350) / 2.0
	)
	_panel.size = Vector2(400, 350)
	add_child(_panel)

	# VBox 布局
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_TOP_LEFT)
	vbox.position = Vector2(25, 20)
	vbox.size = Vector2(350, 310)
	vbox.add_theme_constant_override("separation", 12)
	_panel.add_child(vbox)

	# ── 标题 ──
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 24)
	vbox.add_child(_title)

	vbox.add_child(_make_spacer(4))

	# ── 用户名 / 邮箱 ──
	_username_input = LineEdit.new()
	_username_input.placeholder_text = Localization.t("ui.login.email")
	_username_input.custom_minimum_size = Vector2(0, 36)
	vbox.add_child(_username_input)

	# ── 密码 ──
	_password_input = LineEdit.new()
	_password_input.placeholder_text = Localization.t("ui.login.password")
	_password_input.secret = true
	_password_input.custom_minimum_size = Vector2(0, 36)
	_password_input.text_submitted.connect(_on_submit)
	vbox.add_child(_password_input)

	# ── 邮箱（仅注册模式显示）──
	_email_input = LineEdit.new()
	_email_input.placeholder_text = Localization.t("ui.login.email")
	_email_input.custom_minimum_size = Vector2(0, 36)
	_email_input.text_submitted.connect(_on_submit)
	vbox.add_child(_email_input)

	# ── 错误提示 ──
	_error_label = Label.new()
	_error_label.add_theme_color_override("font_color", Color.RED)
	_error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_error_label.visible = false
	vbox.add_child(_error_label)

	# ── 加载指示 ──
	_loading_label = Label.new()
	_loading_label.text = Localization.t("ui.login.loading")
	_loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_loading_label.visible = false
	vbox.add_child(_loading_label)

	# ── 提交按钮 ──
	_submit_button = Button.new()
	_submit_button.pressed.connect(_on_submit)
	_submit_button.custom_minimum_size = Vector2(0, 40)
	vbox.add_child(_submit_button)

	# ── 模式切换 ──
	_switch_button = Button.new()
	_switch_button.flat = true
	_switch_button.pressed.connect(_on_switch_mode)
	_switch_button.add_theme_color_override("font_color", Color(0.3, 0.6, 1.0))
	vbox.add_child(_switch_button)

	# 首次聚焦用户名输入框
	_username_input.grab_focus()

# ══════════════════════════════════════════════════
#  模式切换
# ══════════════════════════════════════════════════

func _update_mode() -> void:
	_error_label.visible = false
	if _mode == "login":
		_title.text = Localization.t("ui.login.title.login")
		_username_input.placeholder_text = Localization.t("ui.login.email")
		_email_input.visible = false
		_submit_button.text = Localization.t("ui.login.submit.login")
		_switch_button.text = Localization.t("ui.login.switch.to_register")
		_panel.size.y = 350
	else:
		_title.text = Localization.t("ui.login.title.register")
		_email_input.visible = true
		_submit_button.text = Localization.t("ui.login.submit.register")
		_switch_button.text = Localization.t("ui.login.switch.to_login")
		_panel.size.y = 400

	# 重新居中
	_panel.position = Vector2(
		(get_viewport_rect().size.x - 400) / 2.0,
		(get_viewport_rect().size.y - _panel.size.y) / 2.0
	)

	_username_input.grab_focus()

func _on_switch_mode() -> void:
	_mode = "register" if _mode == "login" else "login"
	_update_mode()

# ══════════════════════════════════════════════════
#  提交
# ══════════════════════════════════════════════════

func _on_submit(_unused: String = "") -> void:
	if _login_flow_running:
		return
	var username := _username_input.text.strip_edges()
	var password := _password_input.text

	if username == "" or password == "":
		_show_error(Localization.t("ui.login.error.missing_username_password"))
		return

	if _mode == "register":
		var email := _email_input.text.strip_edges()
		if email == "":
			_show_error(Localization.t("ui.login.error.missing_email"))
			return
		_do_register(username, password, email)
	else:
		_do_login(username, password)

# ══════════════════════════════════════════════════
#  登录 & 注册请求
# ══════════════════════════════════════════════════

func _do_login(username: String, password: String) -> void:
	_last_submit = {"mode": "login", "username": username, "password": password, "email": ""}
	await _run_login_preparation(_last_submit)

func _do_register(username: String, password: String, email: String) -> void:
	_last_submit = {"mode": "register", "username": username, "password": password, "email": email}
	await _run_login_preparation(_last_submit)

func _run_login_preparation(payload: Dictionary) -> void:
	_login_flow_running = true
	_set_loading(true)
	await _show_progress_ui()
	FileLogger.perf("login_prepare_start", {"mode": payload.get("mode", "login")})

	_start_step("connect", Localization.t("ui.login.prepare.current.connect"))
	_start_step("auth", Localization.t("ui.login.prepare.current.auth"))

	var auth_started := Time.get_ticks_msec()
	var auth_resp: Dictionary
	if payload.get("mode", "login") == "register":
		auth_resp = await ApiClient.register(payload["username"], payload["password"], payload["email"])
	else:
		auth_resp = await ApiClient.login(payload["username"], payload["password"])
	var auth_ms := Time.get_ticks_msec() - auth_started
	FileLogger.perf("login_prepare_auth_done", {
		"mode": payload.get("mode", "login"),
		"success": auth_resp.get("success", false),
		"error_type": auth_resp.get("error_type", ""),
		"total_ms": auth_ms,
	})

	if not auth_resp.get("success", false):
		var is_network_error := str(auth_resp.get("error_type", "")) == "network"
		_finish_step("connect", PREP_STATUS_FAILED if is_network_error else PREP_STATUS_SUCCESS, auth_resp.get("error", ""))
		_finish_step("auth", PREP_STATUS_FAILED, auth_resp.get("error", ""))
		_fail_preparation(auth_resp.get("error", Localization.t("ui.login.prepare.retry_hint")))
		return

	_finish_step("connect", PREP_STATUS_SUCCESS)
	_finish_step("auth", PREP_STATUS_SUCCESS)

	var data: Dictionary = auth_resp["data"]
	if data.has("user") and data["user"] is Dictionary:
		GameManager.apply_login_user(data["user"])
	if data.has("draw_key") and data["draw_key"] is Dictionary:
		GameManager.apply_draw_key(data["draw_key"])

	_start_step("session", Localization.t("ui.login.prepare.current.session"))
	_finish_step("session", PREP_STATUS_SUCCESS, Localization.t("ui.login.prepare.detail.session_saved"))
	_start_step("profile")
	_start_step("collection")

	var batch_started := Time.get_ticks_msec()
	var base := ApiClient.get_api_base_url()
	var results := await ApiClient.batch_request([
		{"key": "profile", "url": base + "/user/profile", "timeout": 45.0},
		{"key": "level", "url": base + "/player/level", "timeout": 45.0},
		{"key": "pool", "url": base + "/game/cards?type=pool", "timeout": 45.0},
		{"key": "hand", "url": base + "/game/cards?type=hand", "timeout": 45.0},
	])
	FileLogger.perf("login_prepare_parallel_done", {"total_ms": Time.get_ticks_msec() - batch_started})

	var failed_messages: Array[String] = []
	_apply_critical_login_results(results, failed_messages)

	if not failed_messages.is_empty():
		_fail_preparation(failed_messages[0])
		return

	_start_step("config")
	_finish_step("config", PREP_STATUS_SUCCESS, Localization.t("ui.login.prepare.detail.background"))
	_start_step("daily")
	_finish_step("daily", PREP_STATUS_SUCCESS, Localization.t("ui.login.prepare.detail.background"))

	_start_step("ui", Localization.t("ui.login.prepare.current.ui"))
	var ui_started := Time.get_ticks_msec()
	await get_tree().process_frame
	_finish_step("ui", PREP_STATUS_SUCCESS)
	FileLogger.perf("login_prepare_ui_done", {"ui_render_ms": Time.get_ticks_msec() - ui_started})

	if _progress_ui != null:
		_progress_ui.show_success()
	FileLogger.perf("login_prepare_done", {"success": true})
	GameManager.sync_optional_login_data_background.call_deferred(true)
	await get_tree().create_timer(0.35).timeout
	login_completed.emit()
	_close()

func _apply_critical_login_results(results: Dictionary, failed_messages: Array[String]) -> void:
	var profile_resp: Dictionary = results.get("profile", {})
	var level_resp: Dictionary = results.get("level", {})
	if profile_resp.get("success", false):
		GameManager.apply_profile(profile_resp["data"])
	if level_resp.get("success", false):
		GameManager._apply_level_info(level_resp["data"])
	if profile_resp.get("success", false) and level_resp.get("success", false):
		_finish_step("profile", PREP_STATUS_SUCCESS)
	else:
		var resp := profile_resp if not profile_resp.get("success", false) else level_resp
		_finish_step("profile", PREP_STATUS_FAILED, resp.get("error", ""))
		failed_messages.append(_step_error_text("profile", resp))

	var collection_keys := ["pool", "hand"]
	var collection_ok := true
	var collection_error := ""
	for key in collection_keys:
		var resp: Dictionary = results.get(key, {})
		if not resp.get("success", false):
			collection_ok = false
			if collection_error == "":
				collection_error = resp.get("error", "")
			continue
		GameManager._apply_card_slots(key, resp["data"])
	if collection_ok:
		_finish_step("collection", PREP_STATUS_SUCCESS)
	else:
		_finish_step("collection", PREP_STATUS_FAILED, collection_error)
		failed_messages.append(Localization.t("ui.login.prepare.step.collection") + ": " + collection_error)

func _step_error_text(step_id: String, resp: Dictionary) -> String:
	return _step_label(step_id) + ": " + str(resp.get("error", "未知错误"))

func _show_progress_ui() -> void:
	_panel.visible = false
	if _progress_ui == null:
		_progress_ui = Control.new()
		_progress_ui.set_script(load("res://Scripts/UI/LoginPreparationUI.gd"))
		_progress_ui.connect("retry_requested", _on_progress_retry)
		_progress_ui.connect("back_requested", _on_progress_back)
		add_child(_progress_ui)
	_progress_ui.visible = true
	var steps: Array[Dictionary] = []
	for step in PREP_STEPS:
		steps.append({"id": step["id"], "label": Localization.t(step["label"])})
	_progress_ui.set_steps(steps)

func _start_step(step_id: String, current_text: String = "") -> void:
	_step_started_at[step_id] = Time.get_ticks_msec()
	if _progress_ui != null:
		_progress_ui.set_step(step_id, PREP_STATUS_RUNNING)
		if current_text != "":
			_progress_ui.set_current(current_text)
	FileLogger.perf("login_prepare_step_start", {"step": step_id})

func _finish_step(step_id: String, status: String, detail: String = "") -> void:
	var elapsed := Time.get_ticks_msec() - int(_step_started_at.get(step_id, Time.get_ticks_msec()))
	if _progress_ui != null:
		_progress_ui.set_step(step_id, status, elapsed, detail)
	FileLogger.perf("login_prepare_step_done", {
		"step": step_id,
		"status": status,
		"total_ms": elapsed,
		"detail": detail,
	})

func _fail_preparation(message: String) -> void:
	_login_flow_running = false
	_set_loading(false)
	FileLogger.perf("login_prepare_done", {"success": false, "error": message})
	if _progress_ui != null:
		var hint := message
		if hint == "":
			hint = Localization.t("ui.login.prepare.retry_hint")
		_progress_ui.show_failure(hint)

func _on_progress_retry() -> void:
	if _login_flow_running or _last_submit.is_empty():
		return
	await _run_login_preparation(_last_submit)

func _on_progress_back() -> void:
	_login_flow_running = false
	_set_loading(false)
	if _progress_ui != null:
		_progress_ui.visible = false
	_panel.visible = true
	_error_label.visible = false

func _step_label(step_id: String) -> String:
	for step in PREP_STEPS:
		if step["id"] == step_id:
			return Localization.t(step["label"])
	return step_id

# ══════════════════════════════════════════════════
#  UI 状态控制
# ══════════════════════════════════════════════════

func _set_loading(loading: bool) -> void:
	_submit_button.disabled = loading
	_switch_button.disabled = loading
	_username_input.editable = not loading
	_password_input.editable = not loading
	_email_input.editable = not loading
	_loading_label.visible = loading
	_error_label.visible = false

func _show_error(msg: String) -> void:
	_error_label.text = msg
	_error_label.visible = true

func _close() -> void:
	var parent := get_parent()
	if parent:
		parent.remove_child(self)
	queue_free()

# ══════════════════════════════════════════════════
#  工具
# ══════════════════════════════════════════════════

func _make_spacer(height: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, height)
	return c
