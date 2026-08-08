extends Control
class_name LoginUI

## LoginUI — 全屏登录/注册界面
## 覆盖整个画面，居中显示登录/注册面板
## 成功登录后自动关闭，失败时显示红色错误提示

signal login_completed()

const CountryCatalogScript = preload("res://Scripts/Data/CountryCatalog.gd")
const AvatarCatalogScript = preload("res://Scripts/Data/AvatarCatalog.gd")
const LoadingTutorialUIScript = preload("res://Scripts/UI/LoadingTutorialUI.gd")
const LoadingScreenScene = preload("res://Scenes/UI/LoadingScreen.tscn")
const CCRVisualStyle = preload("res://Scripts/UI/CCRVisualStyle.gd")
const AccountInputValidationScript = preload("res://Scripts/Data/AccountInputValidation.gd")
const LOGIN_BACKGROUND_PATH := "res://Resources/Backgrounds/login_background.png"
const LOADING_BACKGROUND_PATHS: Array[String] = [
	"res://Resources/Backgrounds/loading_appraisal_workbench.png",
	"res://Resources/Backgrounds/loading_collection_showcase.png",
	"res://Resources/Backgrounds/loading_cosmic_archive_corridor.png",
	"res://Resources/Backgrounds/loading_deep_space_museum_dome.png",
	"res://Resources/Backgrounds/loading_star_map_corridor.png",
]

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
var _username_row: HBoxContainer
var _password_row: HBoxContainer
var _email_row: HBoxContainer
var _username_status: Label
var _password_status: Label
var _email_status: Label
var _username_validation_state := "idle"
var _password_validation_state := "idle"
var _email_validation_state := "idle"
var _username_check_revision := 0
var _email_check_revision := 0
var _form_loading := false
var _language_row: HBoxContainer
var _language_label: Label
var _language_select: OptionButton
var _country_row: HBoxContainer
var _country_label: Label
var _country_select: OptionButton
var _avatar_row: HBoxContainer
var _avatar_label: Label
var _avatar_select: OptionButton
var _avatar_preview: TextureRect
var _submit_button: Button
var _switch_button: Button
var _exit_button: Button
var _loading_label: Label
var _login_background: TextureRect = null
var _loading_screen_ui: LoadingScreenUI = null
const LOGIN_QUEUE_MAX_POLLS := 180

# ══════════════════════════════════════════════════
#  生命周期
# ══════════════════════════════════════════════════

func _ready() -> void:
	_setup_ui()
	if not Localization.locale_changed.is_connected(_on_locale_changed):
		Localization.locale_changed.connect(_on_locale_changed)
	_update_mode()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_node_ready():
		_apply_fullscreen_layout()

# ══════════════════════════════════════════════════
#  界面搭建
# ══════════════════════════════════════════════════

func _setup_ui() -> void:
	# 全屏覆盖
	_force_full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_STOP

	_login_background = TextureRect.new()
	_login_background.name = "LoginBackgroundImage"
	_force_full_rect(_login_background)
	_login_background.texture = load(LOGIN_BACKGROUND_PATH)
	_login_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_login_background.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(_login_background)

	# 居中面板
	_panel = Panel.new()
	_panel.position = Vector2(
		(get_viewport_rect().size.x - 400) / 2.0,
		(get_viewport_rect().size.y - 350) / 2.0
	)
	_panel.size = Vector2(400, 350)
	_panel.add_theme_stylebox_override("panel", _make_login_panel_style())
	add_child(_panel)

	# VBox 布局
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_TOP_LEFT)
	vbox.position = Vector2(25, 20)
	vbox.size = Vector2(350, 500)
	vbox.add_theme_constant_override("separation", 12)
	_panel.add_child(vbox)

	# ── 标题 ──
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 24)
	CCRVisualStyle.apply_dark_label(_title)
	vbox.add_child(_title)

	vbox.add_child(_make_spacer(4))

	_language_row = HBoxContainer.new()
	_language_label = Label.new()
	_language_label.custom_minimum_size = Vector2(100, 36)
	_language_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	CCRVisualStyle.apply_dark_label(_language_label)
	_language_row.add_child(_language_label)
	_language_select = OptionButton.new()
	_language_select.name = "LoginLanguageSelect"
	_language_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_language_select.custom_minimum_size = Vector2(0, 36)
	_language_select.item_selected.connect(_on_language_selected)
	_language_row.add_child(_language_select)
	vbox.add_child(_language_row)

	# ── 游戏ID / 邮箱 ──
	_username_input = LineEdit.new()
	_username_input.placeholder_text = Localization.t("ui.login.username")
	_username_input.custom_minimum_size = Vector2(0, 36)
	_username_input.text_changed.connect(_on_registration_username_changed)
	_username_status = _make_field_status_label("RegisterUsernameStatus")
	_username_row = _make_validated_field_row(_username_input, _username_status)
	vbox.add_child(_username_row)

	# ── 密码 ──
	_password_input = LineEdit.new()
	_password_input.placeholder_text = Localization.t("ui.login.password")
	_password_input.secret = true
	_password_input.custom_minimum_size = Vector2(0, 36)
	_password_input.text_submitted.connect(_on_submit)
	_password_input.text_changed.connect(_on_registration_password_changed)
	_password_status = _make_field_status_label("RegisterPasswordStatus")
	_password_row = _make_validated_field_row(_password_input, _password_status)
	vbox.add_child(_password_row)

	# ── 邮箱（仅注册模式显示）──
	_email_input = LineEdit.new()
	_email_input.placeholder_text = Localization.t("ui.login.email")
	_email_input.custom_minimum_size = Vector2(0, 36)
	_email_input.text_submitted.connect(_on_submit)
	_email_input.text_changed.connect(_on_registration_email_changed)
	_email_status = _make_field_status_label("RegisterEmailStatus")
	_email_row = _make_validated_field_row(_email_input, _email_status)
	vbox.add_child(_email_row)

	_country_row = HBoxContainer.new()
	_country_label = Label.new()
	_country_label.custom_minimum_size = Vector2(100, 36)
	_country_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	CCRVisualStyle.apply_dark_label(_country_label)
	_country_row.add_child(_country_label)
	_country_select = OptionButton.new()
	_country_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_country_select.custom_minimum_size = Vector2(0, 36)
	_country_row.add_child(_country_select)
	vbox.add_child(_country_row)
	_populate_country_options()

	_avatar_row = HBoxContainer.new()
	_avatar_label = Label.new()
	_avatar_label.custom_minimum_size = Vector2(100, 36)
	_avatar_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	CCRVisualStyle.apply_dark_label(_avatar_label)
	_avatar_row.add_child(_avatar_label)
	_avatar_preview = TextureRect.new()
	_avatar_preview.name = "RegisterAvatarPreview"
	_avatar_preview.custom_minimum_size = Vector2(36, 36)
	_avatar_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_avatar_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_avatar_row.add_child(_avatar_preview)
	_avatar_select = OptionButton.new()
	_avatar_select.name = "RegisterAvatarSelect"
	_avatar_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_avatar_select.custom_minimum_size = Vector2(0, 36)
	_avatar_select.item_selected.connect(_on_avatar_selected)
	_avatar_row.add_child(_avatar_select)
	vbox.add_child(_avatar_row)
	_populate_avatar_options()
	_populate_language_options()

	# ── 错误提示 ──
	_error_label = Label.new()
	CCRVisualStyle.apply_dark_label(_error_label, CCRVisualStyle.TEXT_ERROR)
	_error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_error_label.visible = false
	vbox.add_child(_error_label)

	# ── 加载指示 ──
	_loading_label = Label.new()
	_loading_label.text = Localization.t("ui.login.loading")
	_loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	CCRVisualStyle.apply_dark_label(_loading_label, CCRVisualStyle.TEXT_DARK_MUTED)
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

	# 登录前没有需要同步的游戏资产，退出应当立即可用。
	_exit_button = Button.new()
	_exit_button.name = "LoginExitButton"
	_exit_button.text = Localization.t("ui.login.exit_game")
	_exit_button.pressed.connect(_on_exit_game)
	vbox.add_child(_exit_button)

	# 首次聚焦用户名输入框
	_username_input.grab_focus()
	_apply_fullscreen_layout()

# ══════════════════════════════════════════════════
#  模式切换
# ══════════════════════════════════════════════════

func _update_mode() -> void:
	_error_label.visible = false
	_password_input.placeholder_text = Localization.t("ui.login.password")
	_email_input.placeholder_text = Localization.t("ui.login.email")
	_loading_label.text = Localization.t("ui.login.loading")
	_exit_button.text = Localization.t("ui.login.exit_game")
	if _mode == "login":
		_title.text = Localization.t("ui.login.title.login")
		_username_input.placeholder_text = Localization.t("ui.login.email")
		_email_row.visible = false
		_username_status.visible = false
		_password_status.visible = false
		_country_row.visible = false
		_avatar_row.visible = false
		_submit_button.text = Localization.t("ui.login.submit.login")
		_switch_button.text = Localization.t("ui.login.switch.to_register")
		_panel.size.y = 398
	else:
		_title.text = Localization.t("ui.login.title.register")
		_username_input.placeholder_text = Localization.t("ui.login.username")
		_email_row.visible = true
		_username_status.visible = true
		_password_status.visible = true
		_email_status.visible = true
		_country_row.visible = true
		_avatar_row.visible = true
		_submit_button.text = Localization.t("ui.login.submit.register")
		_switch_button.text = Localization.t("ui.login.switch.to_login")
		_panel.size.y = 560
		_refresh_registration_validation()

	_update_registration_submit_enabled()

	# 重新居中
	_center_login_panel()

	_username_input.grab_focus()

func _on_switch_mode() -> void:
	_mode = "register" if _mode == "login" else "login"
	_update_mode()

func _on_exit_game() -> void:
	get_tree().quit()

# ══════════════════════════════════════════════════
#  提交
# ══════════════════════════════════════════════════

func _on_submit(_unused: String = "") -> void:
	var username := _username_input.text.strip_edges()
	var password := _password_input.text

	if username == "" or password == "":
		_show_error(Localization.t("ui.login.error.missing_username_password"))
		return

	if _mode == "register":
		if not _registration_form_ready():
			_show_error(Localization.t("ui.account.status.complete_form"))
			return
		var email := _email_input.text.strip_edges()
		if email == "":
			_show_error(Localization.t("ui.login.error.missing_email"))
			return
		_do_register(username, password, email, _selected_country_code(), _selected_avatar_id())
	else:
		_do_login(username, password)

# ══════════════════════════════════════════════════
#  登录 & 注册请求
# ══════════════════════════════════════════════════

func _do_login(username: String, password: String) -> void:
	_set_loading(true)
	var resp := await ApiClient.login(username, password)
	_set_loading(false)

	if resp["success"]:
		await _finish_successful_auth(resp)
	elif str(resp.get("error_code", "")) == "QUEUE_REQUIRED":
		var retry := await _wait_for_queue(func(): return await ApiClient.login(username, password), resp)
		if retry.get("success", false):
			await _finish_successful_auth(retry)
		else:
			_show_error(retry.get("error", resp["error"]))
	else:
		_show_error(resp["error"])

func _do_register(username: String, password: String, email: String, country: String, avatar: String) -> void:
	_set_loading(true)
	var resp := await ApiClient.register(username, password, email, country, avatar)
	_set_loading(false)

	if resp["success"]:
		await _finish_successful_auth(resp)
	elif str(resp.get("error_code", "")) == "QUEUE_REQUIRED":
		var retry := await _wait_for_queue(func(): return await ApiClient.register(username, password, email, country, avatar), resp)
		if retry.get("success", false):
			await _finish_successful_auth(retry)
		else:
			_apply_registration_server_error(retry)
			_show_error(retry.get("error", resp["error"]))
	else:
		_apply_registration_server_error(resp)
		_show_error(resp["error"])

func _apply_registration_server_error(resp: Dictionary) -> void:
	var code := str(resp.get("error_code", ""))
	if code in ["USERNAME_TAKEN", "USERNAME_UNAVAILABLE"]:
		_username_validation_state = "invalid"
		_set_field_status(_username_status, "invalid", "ui.account.status.id_unavailable")
	elif code in ["EMAIL_TAKEN", "EMAIL_UNAVAILABLE"]:
		_email_validation_state = "invalid"
		_set_field_status(_email_status, "invalid", "ui.account.status.email_unavailable")
	_update_registration_submit_enabled()

func _finish_successful_auth(resp: Dictionary) -> void:
	var data: Dictionary = resp["data"]
	if data.has("user") and data["user"] is Dictionary:
		if _mode == "register":
			Localization.save_account_locale_preference(Localization.locale, int(data["user"].get("id", 0)))
		GameManager.apply_login_user(data["user"])
	if _mode == "register":
		var avatar_id := _selected_avatar_id()
		var user_avatar := ""
		if data.has("user") and data["user"] is Dictionary:
			user_avatar = str(data["user"].get("avatar", ""))
		if user_avatar != avatar_id:
			var avatar_resp := await ApiClient.update_profile({"avatar": avatar_id})
			if avatar_resp.get("success", false):
				GameManager.apply_profile(avatar_resp["data"])
			else:
				_show_error(str(avatar_resp.get("error", Localization.t("ui.profile.save_failed"))))
				return
	if data.has("draw_key") and data["draw_key"] is Dictionary:
		GameManager.apply_draw_key(data["draw_key"])
	_loading_label.text = Localization.t("ui.login.syncing")
	_loading_label.visible = true
	_show_loading_screen_ui(Localization.t("ui.login.syncing"), 55.0)
	await GameManager.sync_initial_card_pool_from_server()
	GameManager.sync_optional_login_data_background.call_deferred(true)
	_loading_label.visible = false
	login_completed.emit()
	_close()

func _wait_for_queue(retry_callable: Callable, auth_resp: Dictionary) -> Dictionary:
	var queue_data: Dictionary = auth_resp.get("data", {}) if auth_resp.get("data", {}) is Dictionary else {}
	var ticket_id := str(queue_data.get("ticket_id", ""))
	if ticket_id == "":
		return auth_resp
	Config.set_value("queue", "ticket_id", ticket_id)
	for _poll_index in range(LOGIN_QUEUE_MAX_POLLS):
		var position := int(queue_data.get("position", 0))
		var wait_seconds := int(queue_data.get("estimated_wait_seconds", 0))
		_show_error(Localization.t("ui.login.queue.waiting", [position, wait_seconds]))
		await get_tree().create_timer(maxf(2.0, float(queue_data.get("poll_after_seconds", 10)))).timeout
		var status_resp := await ApiClient.queue_status(ticket_id)
		if not status_resp.get("success", false):
			return status_resp
		queue_data = status_resp.get("data", {}) if status_resp.get("data", {}) is Dictionary else {}
		if bool(queue_data.get("admitted", false)):
			return await retry_callable.call()
	return {"success": false, "error": Localization.t("ui.login.queue.timeout"), "error_type": "network", "status_code": 0}

func _populate_country_options() -> void:
	var selected_code := _selected_country_code()
	_country_label.text = Localization.t("ui.login.country")
	_country_select.tooltip_text = Localization.t("ui.login.country.hint")
	_country_select.clear()
	var selected_index := 0
	var entries: Array[Dictionary] = CountryCatalogScript.localized_entries(Localization.locale)
	for index in range(entries.size()):
		var entry: Dictionary = entries[index]
		_country_select.add_item(str(entry["label"]))
		_country_select.set_item_metadata(index, str(entry["code"]))
		if str(entry["code"]) == selected_code:
			selected_index = index
	_country_select.select(selected_index)

func _populate_language_options() -> void:
	if _language_select == null:
		return
	_language_label.text = Localization.t("ui.login.language")
	_language_select.clear()
	var selected_index := 0
	var locales := Localization.get_supported_locales()
	for index in range(locales.size()):
		var locale_code := str(locales[index])
		_language_select.add_item(Localization.language_label(locale_code))
		_language_select.set_item_metadata(index, locale_code)
		if locale_code == Localization.locale:
			selected_index = index
	_language_select.select(selected_index)

func _populate_avatar_options() -> void:
	if _avatar_select == null:
		return
	var selected_id := _selected_avatar_id()
	_avatar_label.text = Localization.t("ui.login.avatar")
	_avatar_select.tooltip_text = Localization.t("ui.login.avatar.hint")
	_avatar_select.clear()
	var selected_index := 0
	for index in range(AvatarCatalogScript.AVATARS.size()):
		var avatar: Dictionary = AvatarCatalogScript.AVATARS[index]
		var avatar_id := str(avatar["id"])
		_avatar_select.add_item(Localization.t(str(avatar["name_key"])))
		_avatar_select.set_item_metadata(index, avatar_id)
		if avatar_id == selected_id:
			selected_index = index
	_avatar_select.select(selected_index)
	_update_avatar_preview()

func _selected_country_code() -> String:
	if _country_select == null or _country_select.item_count == 0 or _country_select.selected < 0:
		return "EARTH"
	return str(_country_select.get_item_metadata(_country_select.selected))

func _selected_avatar_id() -> String:
	if _avatar_select == null or _avatar_select.item_count == 0 or _avatar_select.selected < 0:
		return AvatarCatalogScript.DEFAULT_AVATAR_ID
	var avatar_id := str(_avatar_select.get_item_metadata(_avatar_select.selected))
	return avatar_id if AvatarCatalogScript.is_known_avatar(avatar_id) else AvatarCatalogScript.DEFAULT_AVATAR_ID

func _on_language_selected(index: int) -> void:
	if _language_select == null or index < 0 or index >= _language_select.item_count:
		return
	Localization.set_locale(str(_language_select.get_item_metadata(index)))

func _on_avatar_selected(_index: int) -> void:
	_update_avatar_preview()

func _update_avatar_preview() -> void:
	if _avatar_preview == null:
		return
	_avatar_preview.texture = AvatarCatalogScript.get_texture(_selected_avatar_id())

func _on_locale_changed(_locale: String) -> void:
	_populate_language_options()
	_populate_country_options()
	_populate_avatar_options()
	_update_mode()

# ══════════════════════════════════════════════════
#  UI 状态控制
# ══════════════════════════════════════════════════

func _set_loading(loading: bool) -> void:
	_form_loading = loading
	_update_registration_submit_enabled()
	_switch_button.disabled = loading
	_exit_button.disabled = loading
	_username_input.editable = not loading
	_password_input.editable = not loading
	_email_input.editable = not loading
	_country_select.disabled = loading
	_language_select.disabled = loading
	_avatar_select.disabled = loading
	_loading_label.visible = loading
	_error_label.visible = false

func _make_validated_field_row(input: LineEdit, status: Label) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(input)
	row.add_child(status)
	return row

func _make_field_status_label(node_name: String) -> Label:
	var label := Label.new()
	label.name = node_name
	label.custom_minimum_size = Vector2(132, 36)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 12)
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return label

func _set_field_status(label: Label, state: String, text_key: String = "") -> void:
	if label == null:
		return
	match state:
		"valid":
			label.text = "✓"
			label.add_theme_color_override("font_color", Color(0.12, 0.62, 0.32))
		"checking":
			label.text = Localization.t("ui.account.status.checking")
			label.add_theme_color_override("font_color", Color(0.42, 0.48, 0.56))
		"invalid":
			label.text = Localization.t(text_key)
			label.add_theme_color_override("font_color", Color(0.78, 0.18, 0.18))
		_:
			label.text = ""

func _refresh_registration_validation() -> void:
	if _mode != "register":
		return
	_on_registration_password_changed(_password_input.text)
	_on_registration_username_changed(_username_input.text)
	_on_registration_email_changed(_email_input.text)

func _on_registration_password_changed(value: String) -> void:
	if _mode != "register":
		return
	var error_key := AccountInputValidationScript.password_error_key(value)
	_password_validation_state = "valid" if error_key == "" else "invalid"
	_set_field_status(_password_status, _password_validation_state, error_key)
	_update_registration_submit_enabled()

func _on_registration_username_changed(value: String) -> void:
	_username_check_revision += 1
	var revision := _username_check_revision
	if _mode != "register":
		return
	var candidate := value.strip_edges()
	var error_key := AccountInputValidationScript.username_error_key(candidate)
	if error_key != "":
		_username_validation_state = "invalid"
		_set_field_status(_username_status, "invalid", error_key)
		_update_registration_submit_enabled()
		return
	_username_validation_state = "checking"
	_set_field_status(_username_status, "checking")
	_update_registration_submit_enabled()
	await get_tree().create_timer(0.45).timeout
	if revision != _username_check_revision or _mode != "register" or candidate != _username_input.text.strip_edges():
		return
	var resp := await ApiClient.check_registration_availability({"username": candidate})
	if revision != _username_check_revision or candidate != _username_input.text.strip_edges():
		return
	var result: Dictionary = resp.get("data", {}).get("username", {}) if resp.get("success", false) else {}
	if bool(result.get("available", false)):
		_username_validation_state = "valid"
		_set_field_status(_username_status, "valid")
	else:
		_username_validation_state = "invalid"
		_set_field_status(_username_status, "invalid", "ui.account.status.id_unavailable")
	_update_registration_submit_enabled()

func _on_registration_email_changed(value: String) -> void:
	_email_check_revision += 1
	var revision := _email_check_revision
	if _mode != "register":
		return
	var candidate := value.strip_edges()
	var error_key := AccountInputValidationScript.email_error_key(candidate)
	if error_key != "":
		_email_validation_state = "invalid"
		_set_field_status(_email_status, "invalid", error_key)
		_update_registration_submit_enabled()
		return
	_email_validation_state = "checking"
	_set_field_status(_email_status, "checking")
	_update_registration_submit_enabled()
	await get_tree().create_timer(0.45).timeout
	if revision != _email_check_revision or _mode != "register" or candidate != _email_input.text.strip_edges():
		return
	var resp := await ApiClient.check_registration_availability({"email": candidate})
	if revision != _email_check_revision or candidate != _email_input.text.strip_edges():
		return
	var result: Dictionary = resp.get("data", {}).get("email", {}) if resp.get("success", false) else {}
	if bool(result.get("available", false)):
		_email_validation_state = "valid"
		_set_field_status(_email_status, "valid")
	else:
		_email_validation_state = "invalid"
		_set_field_status(_email_status, "invalid", "ui.account.status.email_unavailable")
	_update_registration_submit_enabled()

func _registration_form_ready() -> bool:
	return _username_validation_state == "valid" and _password_validation_state == "valid" and _email_validation_state == "valid"

func _update_registration_submit_enabled() -> void:
	if _submit_button == null:
		return
	_submit_button.disabled = _form_loading or (_mode == "register" and not _registration_form_ready())

func _show_error(msg: String) -> void:
	_error_label.text = msg
	_error_label.visible = true

func _apply_fullscreen_layout() -> void:
	_force_full_rect(self)
	if _login_background != null:
		_force_full_rect(_login_background)
	if _loading_screen_ui != null:
		_force_full_rect(_loading_screen_ui)
		if _loading_screen_ui.has_method("apply_fullscreen_layout"):
			_loading_screen_ui.call("apply_fullscreen_layout")
	_center_login_panel()

func _center_login_panel() -> void:
	if _panel == null:
		return
	var vp_size := _viewport_size()
	_panel.position = Vector2(
		(vp_size.x - _panel.size.x) / 2.0,
		(vp_size.y - _panel.size.y) / 2.0
	)

func _force_full_rect(control: Control) -> void:
	if control == null:
		return
	control.set_anchors_preset(Control.PRESET_TOP_LEFT)
	control.offset_left = 0.0
	control.offset_top = 0.0
	control.position = Vector2.ZERO
	control.size = _viewport_size()

func _viewport_size() -> Vector2:
	var vp_size := get_viewport_rect().size
	if vp_size.x <= 0.0 or vp_size.y <= 0.0:
		return DisplayServer.window_get_size()
	return vp_size

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

func _show_loading_screen_ui(status: String, progress: float) -> void:
	if _login_background != null:
		_login_background.texture = load(LOGIN_BACKGROUND_PATH)
	if _loading_screen_ui == null:
		_loading_screen_ui = LoadingScreenScene.instantiate() as LoadingScreenUI
		_force_full_rect(_loading_screen_ui)
		add_child(_loading_screen_ui)
	_force_full_rect(_loading_screen_ui)
	if _loading_screen_ui.has_method("apply_fullscreen_layout"):
		_loading_screen_ui.call("apply_fullscreen_layout")
	var path := LOADING_BACKGROUND_PATHS[randi() % LOADING_BACKGROUND_PATHS.size()] if not LOADING_BACKGROUND_PATHS.is_empty() else ""
	if path != "":
		_loading_screen_ui.set_background(load(path))
	var tip := LoadingTutorialUIScript.pick_tip_for_locale(maxi(1, GameManager.player_data.level), Localization.locale)
	var category := str(tip.get("category", Localization.t("ui.loading_tip.default_category")))
	_loading_screen_ui.set_tip(category, str(tip.get("title", Localization.t("ui.login.prepare.title"))), str(tip.get("body", "")), str(tip.get("short_tip", "")))
	_loading_screen_ui.set_progress(progress, status)
	_loading_screen_ui.set_server_status(Localization.t("ui.login.loading.online"))
	_loading_screen_ui.set_version("CCR")

func _make_login_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.74)
	style.border_color = Color(0.08, 0.10, 0.13, 0.24)
	style.set_border_width_all(1)
	style.set_corner_radius_all(14)
	style.shadow_color = Color(0, 0, 0, 0.24)
	style.shadow_size = 18
	style.shadow_offset = Vector2(0, 8)
	return style
