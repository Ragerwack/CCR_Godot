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
	_username_input.placeholder_text = "邮箱"
	_username_input.custom_minimum_size = Vector2(0, 36)
	vbox.add_child(_username_input)

	# ── 密码 ──
	_password_input = LineEdit.new()
	_password_input.placeholder_text = "密码"
	_password_input.secret = true
	_password_input.custom_minimum_size = Vector2(0, 36)
	_password_input.text_submitted.connect(_on_submit)
	vbox.add_child(_password_input)

	# ── 邮箱（仅注册模式显示）──
	_email_input = LineEdit.new()
	_email_input.placeholder_text = "邮箱"
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
	_loading_label.text = "加载中…"
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
		_title.text = "登录"
		_username_input.placeholder_text = "邮箱"
		_email_input.visible = false
		_submit_button.text = "登录"
		_switch_button.text = "没有账号？注册"
		_panel.size.y = 350
	else:
		_title.text = "注册"
		_email_input.visible = true
		_submit_button.text = "注册"
		_switch_button.text = "已有账号？登录"
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
	var username := _username_input.text.strip_edges()
	var password := _password_input.text

	if username == "" or password == "":
		_show_error("用户名和密码不能为空")
		return

	if _mode == "register":
		var email := _email_input.text.strip_edges()
		if email == "":
			_show_error("邮箱不能为空")
			return
		_do_register(username, password, email)
	else:
		_do_login(username, password)

# ══════════════════════════════════════════════════
#  登录 & 注册请求
# ══════════════════════════════════════════════════

func _do_login(username: String, password: String) -> void:
	FileLogger.log("手动登录: 发送登录请求 username=" + username)
	_set_loading(true)
	var resp := await ApiClient.login(username, password)
	_set_loading(false)

	if resp["success"]:
		FileLogger.log("手动登录: 登录成功")
		var data: Dictionary = resp["data"]
		GameManager.apply_login_user(data)
		_loading_label.text = "同步数据中…"
		_loading_label.visible = true
		FileLogger.log("手动登录: 开始同步数据")
		await GameManager.sync_all_from_server()
		_loading_label.visible = false
		FileLogger.log("手动登录: 全部完成，进入游戏")
		login_completed.emit()
		_close()
	else:
		FileLogger.warn("手动登录失败: " + resp.get("error", ""))
		_show_error(resp["error"])

func _do_register(username: String, password: String, email: String) -> void:
	_set_loading(true)
	var resp := await ApiClient.register(username, password, email)
	_set_loading(false)

	if resp["success"]:
		var data: Dictionary = resp["data"]
		GameManager.apply_login_user(data)
		_loading_label.text = "同步数据中…"
		_loading_label.visible = true
		await GameManager.sync_all_from_server()
		_loading_label.visible = false
		login_completed.emit()
		_close()
	else:
		_show_error(resp["error"])

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
