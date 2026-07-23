extends Control
class_name MainUI

@export var enable_debug: bool = false

const TodayDecksUIScript = preload("res://Scripts/UI/TodayDecksUI.gd")
const LevelUpPopupUIScript = preload("res://Scripts/UI/LevelUpPopupUI.gd")
const SynthesisAnimationOverlayScript = preload("res://Scripts/UI/SynthesisAnimationOverlay.gd")
const CCRVisualStyle = preload("res://Scripts/UI/CCRVisualStyle.gd")
const AvatarCatalog = preload("res://Scripts/Data/AvatarCatalog.gd")
const MAIN_BACKGROUND_PATH := "res://Resources/Backgrounds/main_background.png"
const EXIT_DIALOG_PANEL_PATH := CCRVisualStyle.DIALOG_PANEL_PATH
const EXIT_DIALOG_CONFIRM_BUTTON_PATH := CCRVisualStyle.DIALOG_CONFIRM_BUTTON_PATH
const EXIT_DIALOG_CANCEL_BUTTON_PATH := CCRVisualStyle.DIALOG_CANCEL_BUTTON_PATH
const EXIT_DIALOG_PANEL_SIZE := CCRVisualStyle.DIALOG_PANEL_SIZE
const SETTINGS_PAGE_FRAME_WIDTH_RATIO := 0.90
const SETTINGS_PAGE_CONTENT_WIDTH_RATIO := 0.80

const LEFT_PANEL_WIDTH: int = 120
const TOP_BAR_HEIGHT: int = 90
const EXP_BAR_RATIO: float = 0.024   # 接近 MMORPG 底部细经验条的屏占比
const EXP_BAR_MIN_HEIGHT: int = 16
const EXP_BAR_MAX_HEIGHT: int = 24
const CARD_SLOT_HEIGHT_RATIO: float = 0.21
const CARD_GRID_COLUMNS: int = 8
const CARD_GRID_SPACING: float = 8.0
const PLAYER_INFO_FONT_SIZE: int = 18
const PLAYER_INFO_VERTICAL_PADDING: float = 70.0
const LEVEL_STAMINA_FLIGHT_DURATION: float = 1.0
const LEVEL_STAMINA_REVERSE_RATIO: float = 0.20
const LEVEL_STAMINA_START_SCALE: float = 3.0
const LEVEL_STAMINA_END_SCALE: float = 0.5

var _player_info: PlayerInfoUI
var _currency: CurrencyUI
var _nav_buttons: NavButtons
var _center_area: Control
var _exp_bar_ui: ExpBarUI
var _menu_button: Button = null
var _level_up_popup: Control = null
var _main_background: TextureRect = null
var _reconnect_overlay: Control = null
var _exit_confirm_dialog: Control = null

# 子面板
var _today_decks_ui: Control = null
var _card_pool_ui: CardPoolUI = null
var _hand_area_ui: HandAreaUI = null
var _vault_ui: VaultUI = null
var _synthesis_panel: SynthesisPanelUI = null
var _deck_collection_ui: DeckCollectionUI = null

# 加载遮罩
var _loading_overlay: ColorRect = null
var _current_view_id: String = "card_pool"
var _view_before_menu: String = "card_pool"
var _game_ui_active: bool = false
var _synthesis_animation_running: bool = false
var _hand_action_animation_running: bool = false
var _layout_refresh_queued: bool = false
var _settings_tab: String = "basic"

func _ready() -> void:
	setup_ui()

	GameManager.scene_changed.connect(_on_scene_changed)
	GameManager.player_leveled_up.connect(_on_player_leveled_up)
	_nav_buttons.nav_button_clicked.connect(_on_nav_button)
	ApiClient.auth_expired.connect(_on_auth_expired)
	ApiClient.session_reconnect_required.connect(_on_session_reconnect_required)
	SessionManager.session_status_changed.connect(_on_session_status_changed)
	Localization.locale_changed.connect(_on_locale_changed)
	DisplaySettings.resolution_changed.connect(_on_display_resolution_changed)
	ControllerInput.controller_action_pressed.connect(_on_controller_action_pressed)

	# 总是先显示开机界面（全屏覆盖在一切之上）
	_show_splash_screen()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_node_ready():
		_queue_layout_refresh()

# ══════════════════════════════════════════════════
#  开机界面（Splash Screen）
# ══════════════════════════════════════════════════

func _show_splash_screen() -> void:
	# 隐藏所有游戏UI组件（导航栏、PlayerInfo、经验条等）
	_set_game_ui_visible(false)

	var splash := Control.new()
	splash.name = "SplashScreenUI"
	splash.set_script(load("res://Scripts/UI/SplashScreenUI.gd"))
	splash.connect("login_completed", _on_splash_completed)
	add_child(splash)

func _set_game_ui_visible(visible: bool) -> void:
	_game_ui_active = visible
	if _main_background: _main_background.visible = visible
	if _center_area: _center_area.visible = visible
	if _player_info: _player_info.visible = visible
	if _currency: _currency.visible = visible
	if _nav_buttons: _nav_buttons.visible = visible
	if _exp_bar_ui: _exp_bar_ui.visible = visible
	if _menu_button: _menu_button.visible = visible

func _on_splash_completed() -> void:
	# 显示游戏UI，进入主界面
	_set_game_ui_visible(true)
	AudioManager.play_game_music_loop()
	SessionManager.start_session()
	_initialize_card_pool.call_deferred()
	refresh_current_view.call_deferred()

func _deferred_server_sync() -> void:
	_show_loading_light(true)
	await GameManager.sync_all_from_server()
	_show_loading_light(false)
	# 同步完成后刷新当前视图，确保数据填充到 UI
	refresh_current_view()

func _initialize_card_pool() -> void:
	if not ApiClient.is_logged_in():
		return
	# 如果卡池已有数据（从 sync_all 并行加载得到），跳过加载
	if CardPoolSystem.current_pool.size() > 0:
		return
	_show_loading_light(true)
	await CardPoolSystem.load_pool_from_server()
	_show_loading_light(false)

# ══════════════════════════════════════════════════
#  加载遮罩
# ══════════════════════════════════════════════════

func _show_loading(show: bool) -> void:
	if show:
		if _loading_overlay == null:
			_loading_overlay = ColorRect.new()
			_loading_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
			_loading_overlay.color = Color(0, 0, 0, 0.3)
			_loading_overlay.mouse_filter = Control.MOUSE_FILTER_STOP

			# 添加加载文字提示
			var label = Label.new()
			label.name = "LoadingLabel"
			label.set_anchors_preset(Control.PRESET_CENTER)
			label.position = Vector2(0, -100)
			label.size = Vector2(200, 40)
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.text = Localization.t("ui.login.loading")
			label.add_theme_font_size_override("font_size", 18)
			label.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
			_loading_overlay.add_child(label)

			add_child(_loading_overlay)
		_loading_overlay.visible = true
	else:
		if _loading_overlay != null:
			# 完全清除遮罩，防止残留阻塞点击
			remove_child(_loading_overlay)
			_loading_overlay.queue_free()
			_loading_overlay = null

## 轻量加载提示 — 不阻挡点击，仅显示半透明遮罩 + 加载文字
var _loading_light: ColorRect = null

func _show_loading_light(show: bool) -> void:
	if show:
		if _loading_light == null:
			_loading_light = ColorRect.new()
			_loading_light.set_anchors_preset(Control.PRESET_FULL_RECT)
			_loading_light.color = Color(0, 0, 0, 0.15)  # 更淡
			_loading_light.mouse_filter = Control.MOUSE_FILTER_IGNORE  # 不阻挡点击

			var label = Label.new()
			label.name = "LoadingLabel"
			label.set_anchors_preset(Control.PRESET_CENTER)
			label.position = Vector2(0, -100)
			label.size = Vector2(200, 40)
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.text = Localization.t("ui.login.syncing")
			label.add_theme_font_size_override("font_size", 14)
			label.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
			_loading_light.add_child(label)

			add_child(_loading_light)
		_loading_light.visible = true
	else:
		if _loading_light != null:
			remove_child(_loading_light)
			_loading_light.queue_free()
			_loading_light = null

# ══════════════════════════════════════════════════
#  登录 & 认证过期
# ══════════════════════════════════════════════════

func _show_login() -> void:
	_set_game_ui_visible(false)
	var login_ui := Control.new()
	login_ui.set_script(load("res://Scripts/UI/LoginUI.gd"))
	login_ui.connect("login_completed", _on_login_completed)
	login_ui.name = "LoginUI"
	add_child(login_ui)

func _on_login_completed() -> void:
	_set_game_ui_visible(true)
	AudioManager.play_game_music_loop()
	SessionManager.start_session()
	_initialize_card_pool()
	refresh_current_view()

func _on_auth_expired() -> void:
	SessionManager.stop_session()
	_show_splash_screen()

func _on_session_reconnect_required(reason: String) -> void:
	SessionManager.stop_session()
	_show_reconnect_overlay(reason)

func _on_session_status_changed(status: String) -> void:
	if status == "reconnecting":
		_show_reconnect_overlay(Localization.t("ui.reconnect.reason_unstable"))
	elif status == "online":
		_hide_reconnect_overlay()

func _show_reconnect_overlay(reason: String = "") -> void:
	if is_instance_valid(_reconnect_overlay):
		var reason_label := _reconnect_overlay.get_node_or_null("Panel/VBox/ReasonLabel") as Label
		if reason_label != null:
			reason_label.text = reason
		return
	_reconnect_overlay = Control.new()
	_reconnect_overlay.name = "ReconnectOverlay"
	_reconnect_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_reconnect_overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0, 0, 0, 0.52)
	_reconnect_overlay.add_child(shade)

	var panel := Panel.new()
	panel.name = "Panel"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.size = Vector2(460, 220)
	panel.position = -panel.size / 2.0
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.05, 0.06, 0.09, 0.94)
	panel_style.border_color = Color(0.55, 0.72, 1.0, 0.55)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", panel_style)
	_reconnect_overlay.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 24
	vbox.offset_top = 22
	vbox.offset_right = -24
	vbox.offset_bottom = -22
	vbox.add_theme_constant_override("separation", 14)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = Localization.t("ui.reconnect.title")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(title)

	var reason_label := Label.new()
	reason_label.name = "ReasonLabel"
	reason_label.text = reason if reason != "" else Localization.t("ui.reconnect.reason_idle")
	reason_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reason_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reason_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.86))
	vbox.add_child(reason_label)

	var reconnect_btn := Button.new()
	reconnect_btn.name = "ReconnectButton"
	reconnect_btn.text = Localization.t("ui.reconnect.button")
	reconnect_btn.pressed.connect(_on_reconnect_pressed)
	vbox.add_child(reconnect_btn)

	add_child(_reconnect_overlay)

func _hide_reconnect_overlay() -> void:
	if is_instance_valid(_reconnect_overlay):
		_reconnect_overlay.queue_free()
	_reconnect_overlay = null

func _on_reconnect_pressed() -> void:
	if not ApiClient.has_refresh_token():
		_hide_reconnect_overlay()
		_on_auth_expired()
		return
	var button := _reconnect_overlay.get_node_or_null("Panel/VBox/ReconnectButton") as Button if is_instance_valid(_reconnect_overlay) else null
	if button != null:
		button.disabled = true
		button.text = Localization.t("ui.reconnect.connecting")
	var resp := await ApiClient.refresh_session()
	if not resp.get("success", false):
		_hide_reconnect_overlay()
		_on_auth_expired()
		return
	var data: Dictionary = resp.get("data", {}) if resp.get("data", {}) is Dictionary else {}
	if data.has("user") and data["user"] is Dictionary:
		GameManager.apply_login_user(data["user"])
	if data.has("draw_key") and data["draw_key"] is Dictionary:
		GameManager.apply_draw_key(data["draw_key"])
	SessionManager.start_session()
	await GameManager.sync_all_from_server()
	_hide_reconnect_overlay()
	refresh_current_view()

func _on_player_leveled_up(level: int, rewards: Array[String]) -> void:
	if not _game_ui_active:
		GameManager.complete_pending_level_stamina_refill()
		return
	if is_instance_valid(_level_up_popup):
		_level_up_popup.queue_free()
	_level_up_popup = LevelUpPopupUIScript.new()
	_level_up_popup.setup(level, rewards)
	_level_up_popup.dismissed.connect(func():
		GameManager.complete_pending_level_stamina_refill()
		_level_up_popup = null
	)
	add_child(_level_up_popup)
	_play_level_up_stamina_refill_behind_popup.call_deferred(_level_up_popup)
	AudioManager.play_sfx("level_up", 1.0, 0.0)

func _play_level_up_stamina_refill_behind_popup(popup: Control) -> void:
	if not is_instance_valid(popup) or not GameManager.has_pending_level_stamina_refill():
		return
	var target_rect := _currency.get_resource_icon_global_rect("stamina") if is_instance_valid(_currency) else Rect2()
	var texture := CCRVisualStyle.icon("status_stamina")
	if texture == null:
		GameManager.complete_pending_level_stamina_refill()
		return
	var target_reference := maxf(target_rect.size.x, target_rect.size.y)
	if target_reference <= 1.0:
		target_reference = 22.0
	var start_size := Vector2.ONE * target_reference * LEVEL_STAMINA_START_SCALE
	var end_size := Vector2.ONE * target_reference * LEVEL_STAMINA_END_SCALE
	var start_center := get_viewport_rect().size * 0.5
	var target_center := target_rect.get_center()
	if target_rect.size.x <= 1.0 or target_rect.size.y <= 1.0:
		target_center = Vector2(get_viewport_rect().size.x - 80.0, 28.0)
	var icon := TextureRect.new()
	icon.name = "LevelUpStaminaReward"
	icon.texture = texture
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.size = start_size
	icon.position = start_center - start_size * 0.5
	icon.pivot_offset = start_size * 0.5
	popup.add_child(icon)
	popup.move_child(icon, mini(1, popup.get_child_count() - 1))

	var away := (start_center - target_center).normalized()
	if away.length() <= 0.01:
		away = Vector2.DOWN
	var reverse_center := start_center + away * maxf(48.0, start_size.x * 0.42)
	var control_center := reverse_center.lerp(target_center, 0.52) + away.rotated(PI * 0.5) * 72.0
	var reverse_ratio := LEVEL_STAMINA_REVERSE_RATIO
	var tween := create_tween()
	tween.tween_method(func(progress: float):
		if not is_instance_valid(icon):
			return
		var center := start_center
		if progress <= reverse_ratio:
			var local := progress / reverse_ratio
			var eased := 1.0 - pow(1.0 - local, 3.0)
			center = start_center.lerp(reverse_center, eased)
		else:
			var local := (progress - reverse_ratio) / (1.0 - reverse_ratio)
			var accelerated := local * local * local
			center = _level_reward_quadratic_bezier(reverse_center, control_center, target_center, accelerated)
		var next_size := start_size.lerp(end_size, progress)
		icon.size = next_size
		icon.position = center - next_size * 0.5
		if progress > 0.86:
			icon.modulate.a = 1.0 - (progress - 0.86) / 0.14
	, 0.0, 1.0, LEVEL_STAMINA_FLIGHT_DURATION).set_trans(Tween.TRANS_LINEAR)
	tween.tween_callback(func():
		if is_instance_valid(icon):
			AudioManager.play_sfx("stamina_full", 1.0, 0.0)
		GameManager.complete_pending_level_stamina_refill()
		if is_instance_valid(icon):
			icon.queue_free()
	)

func _level_reward_quadratic_bezier(a: Vector2, b: Vector2, c: Vector2, t: float) -> Vector2:
	var p := clampf(t, 0.0, 1.0)
	return a * (1.0 - p) * (1.0 - p) + b * 2.0 * (1.0 - p) * p + c * p * p

func _on_logout_pressed() -> void:
	SessionManager.stop_session()
	ApiClient.logout()
	GameManager.player_data = PlayerData.new()
	GameManager.free_refresh_count = 1
	GameManager.free_refresh_cooldown = 0.0
	GameManager.newbie_free_refresh_count = 0
	GameManager.last_free_refresh_time_unix = 0.0
	CardPoolSystem.current_pool.clear()
	_show_splash_screen()

func _restore_current_nav_selection() -> void:
	if not is_instance_valid(_nav_buttons):
		return
	match _current_view_id:
		"today_decks", "card_pool", "vault", "deck_panel", "settings":
			_nav_buttons.select_by_id(_current_view_id)
		_: _nav_buttons.select_by_id("card_pool")

func _show_exit_game_dialog() -> void:
	_restore_current_nav_selection()
	if not is_instance_valid(_exit_confirm_dialog):
		_exit_confirm_dialog = _build_exit_game_dialog()
		_exit_confirm_dialog.name = "ExitGameConfirmDialog"
		add_child(_exit_confirm_dialog)
	_update_exit_game_dialog_text()
	_exit_confirm_dialog.show()

func _build_exit_game_dialog() -> Control:
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 2000

	var shade := ColorRect.new()
	shade.name = "ExitDialogShade"
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.0, 0.0, 0.0, 0.58)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(shade)

	var panel := Control.new()
	panel.name = "Panel"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.size = EXIT_DIALOG_PANEL_SIZE
	panel.position = -panel.size / 2.0
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(panel)

	var panel_texture := TextureRect.new()
	panel_texture.name = "PanelTexture"
	panel_texture.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel_texture.texture = load(EXIT_DIALOG_PANEL_PATH)
	panel_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	panel_texture.stretch_mode = TextureRect.STRETCH_SCALE
	panel_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(panel_texture)

	var title := Label.new()
	title.name = "TitleLabel"
	title.position = Vector2(220, 86)
	title.size = Vector2(520, 42)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	panel.add_child(title)

	var message := Label.new()
	message.name = "MessageLabel"
	message.position = Vector2(206, 148)
	message.size = Vector2(548, 72)
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(message)

	var cancel_button := _make_exit_dialog_button(
		"CancelButton",
		EXIT_DIALOG_CANCEL_BUTTON_PATH,
		Vector2(205, 272),
		Localization.t("ui.exit_game.cancel")
	)
	cancel_button.pressed.connect(_on_exit_game_cancelled)
	panel.add_child(cancel_button)

	var confirm_button := _make_exit_dialog_button(
		"ConfirmButton",
		EXIT_DIALOG_CONFIRM_BUTTON_PATH,
		Vector2(495, 272),
		Localization.t("ui.exit_game.confirm")
	)
	confirm_button.pressed.connect(_on_exit_game_confirmed)
	panel.add_child(confirm_button)

	_apply_exit_game_dialog_style(overlay)
	return overlay

func _make_exit_dialog_button(node_name: String, texture_path: String, button_position: Vector2, text: String) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.position = button_position
	button.size = Vector2(260, 80)
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_ARROW
	button.add_theme_stylebox_override("normal", _make_exit_texture_style(texture_path, Vector2(52, 24), Color.WHITE))
	button.add_theme_stylebox_override("hover", _make_exit_texture_style(texture_path, Vector2(52, 24), Color(1.12, 1.12, 1.12, 1.0)))
	button.add_theme_stylebox_override("pressed", _make_exit_texture_style(texture_path, Vector2(52, 24), Color(0.84, 0.90, 0.95, 1.0)))
	button.add_theme_stylebox_override("hover_pressed", _make_exit_texture_style(texture_path, Vector2(52, 24), Color(0.84, 0.90, 0.95, 1.0)))
	button.add_theme_stylebox_override("disabled", _make_exit_texture_style(texture_path, Vector2(52, 24), Color(0.55, 0.58, 0.62, 0.78)))
	button.add_theme_stylebox_override("focus", _make_exit_texture_style(texture_path, Vector2(52, 24), Color(1.12, 1.12, 1.12, 1.0)))
	return button

func _make_exit_texture_style(texture_path: String, margin: Vector2, modulate_color: Color) -> StyleBoxTexture:
	return CCRVisualStyle.make_dialog_texture_style(texture_path, margin, modulate_color)

func _update_exit_game_dialog_text() -> void:
	if not is_instance_valid(_exit_confirm_dialog):
		return
	var title := _exit_confirm_dialog.get_node_or_null("Panel/TitleLabel") as Label
	var message := _exit_confirm_dialog.get_node_or_null("Panel/MessageLabel") as Label
	var confirm_button := _exit_confirm_dialog.get_node_or_null("Panel/ConfirmButton") as Button
	var cancel_button := _exit_confirm_dialog.get_node_or_null("Panel/CancelButton") as Button
	if title != null:
		title.text = Localization.t("ui.exit_game.title")
	if message != null:
		message.text = Localization.t("ui.exit_game.message")
	if confirm_button != null:
		confirm_button.text = Localization.t("ui.exit_game.confirm")
		confirm_button.disabled = false
	if cancel_button != null:
		cancel_button.text = Localization.t("ui.exit_game.cancel")
		cancel_button.disabled = false
	_apply_exit_game_dialog_style(_exit_confirm_dialog)

func _apply_exit_game_dialog_style(dialog: Control) -> void:
	var title := dialog.get_node_or_null("Panel/TitleLabel") as Label
	if title != null:
		title.add_theme_font_size_override("font_size", 26)
		title.add_theme_color_override("font_color", Color.WHITE)
		title.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.88))
		title.add_theme_constant_override("shadow_offset_x", 0)
		title.add_theme_constant_override("shadow_offset_y", 2)
	var message := dialog.get_node_or_null("Panel/MessageLabel") as Label
	if message != null:
		message.add_theme_font_size_override("font_size", 20)
		message.add_theme_color_override("font_color", Color(0.94, 0.98, 1.0, 1.0))
		message.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.82))
		message.add_theme_constant_override("shadow_offset_x", 0)
		message.add_theme_constant_override("shadow_offset_y", 1)
	for node_name in ["ConfirmButton", "CancelButton"]:
		var button := dialog.get_node_or_null("Panel/" + node_name) as Button
		if button == null:
			continue
		button.add_theme_font_size_override("font_size", 20)
		button.add_theme_color_override("font_color", Color.WHITE)
		button.add_theme_color_override("font_hover_color", Color(0.90, 0.98, 1.0, 1.0))
		button.add_theme_color_override("font_pressed_color", Color(0.88, 0.96, 1.0, 1.0))
		button.add_theme_color_override("font_hover_pressed_color", Color(0.88, 0.96, 1.0, 1.0))
		button.add_theme_color_override("font_focus_color", Color.WHITE)
		button.add_theme_color_override("font_disabled_color", Color(0.78, 0.84, 0.90, 0.94))
		button.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.90))
		button.add_theme_constant_override("outline_size", 2)

func _on_exit_game_cancelled() -> void:
	if is_instance_valid(_exit_confirm_dialog):
		_exit_confirm_dialog.hide()
	_restore_current_nav_selection()

func _on_exit_game_confirmed() -> void:
	var ok_button := _exit_confirm_dialog.get_node_or_null("Panel/ConfirmButton") as Button if is_instance_valid(_exit_confirm_dialog) else null
	var cancel_button := _exit_confirm_dialog.get_node_or_null("Panel/CancelButton") as Button if is_instance_valid(_exit_confirm_dialog) else null
	if ok_button != null:
		ok_button.disabled = true
		ok_button.text = Localization.t("ui.exit_game.syncing")
	if cancel_button != null:
		cancel_button.disabled = true
	await _shutdown_session_before_quit()
	get_tree().quit()

func _shutdown_session_before_quit() -> void:
	if ApiClient.is_logged_in() and (_card_pool_ui != null or _hand_area_ui != null):
		await GameManager.sync_pool_hand_layout()
	SessionManager.stop_session()
	ApiClient.logout()

# ══════════════════════════════════════════════════
#  UI 搭建
# ══════════════════════════════════════════════════

func setup_ui() -> void:
	var vp_size = get_viewport_rect().size
	var exp_bar_h = _exp_bar_height(vp_size)
	_configure_card_slot_size(vp_size)
	var left_region := _left_region_width(vp_size)
	var avatar_height := _target_player_avatar_height(vp_size)
	var side_button_width := _side_button_width(vp_size)

	_main_background = TextureRect.new()
	_main_background.name = "MainBackgroundImage"
	_main_background.set_anchors_preset(Control.PRESET_FULL_RECT)
	_main_background.texture = load(MAIN_BACKGROUND_PATH)
	_main_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_main_background.stretch_mode = TextureRect.STRETCH_SCALE
	_main_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_main_background)

	# ── 顶部栏：PlayerInfo（左上）+ Currency（右上贴边） ──
	_player_info = PlayerInfoUI.new()
	_player_info.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_player_info.position = Vector2.ZERO
	_player_info.size = _player_info_size(vp_size)
	_player_info.configure_text_font_size(PLAYER_INFO_FONT_SIZE)
	_player_info.configure_avatar_size(avatar_height)
	add_child(_player_info)

	_currency = CurrencyUI.new()
	_currency.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	# 体力、金币、宝石和 Roll 状态灯按导航按钮高度响应式缩放，文字仍由客户端实时绘制。
	_currency.configure_icon_size(_currency_icon_size(vp_size))
	add_child(_currency)
	_apply_currency_layout(vp_size)

	# ── 左侧导航 ──
	_nav_buttons = NavButtons.new()
	_nav_buttons.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_nav_buttons.offset_left = 0
	_nav_buttons.offset_right = left_region
	_nav_buttons.offset_top = _nav_region_top(vp_size)
	_nav_buttons.offset_bottom = vp_size.y - exp_bar_h
	_nav_buttons.configure_button_metrics(side_button_width, _nav_button_height(vp_size))
	add_child(_nav_buttons)

	# ── 内容区：全屏宽度，具体页面按卡槽网格边界避让左右区域 ──
	_center_area = Control.new()
	_center_area.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_center_area.position = Vector2.ZERO
	_center_area.size = Vector2(vp_size.x, vp_size.y - exp_bar_h)
	_center_area.name = "CenterArea"
	add_child(_center_area)
	# 内容区是全屏 Control，必须压在左侧导航下方，否则透明区域会截获导航按钮点击。
	move_child(_center_area, 1)

	# ── 底部经验条 ──
	_exp_bar_ui = ExpBarUI.new()
	add_child(_exp_bar_ui)

	# 默认视图
	_show_card_pool()
	_apply_game_text_color()

	if enable_debug:
		_setup_debug_panel()

func _on_display_resolution_changed(_size: Vector2i) -> void:
	_queue_layout_refresh()

func _queue_layout_refresh() -> void:
	if _layout_refresh_queued:
		return
	_layout_refresh_queued = true
	call_deferred("_refresh_layout_after_resize")

func _refresh_layout_after_resize() -> void:
	_layout_refresh_queued = false
	if _center_area == null:
		return
	_apply_shell_layout()
	_rebuild_current_view()
	_apply_game_text_color()

func _apply_shell_layout() -> void:
	var vp_size := get_viewport_rect().size
	var exp_bar_h := _exp_bar_height(vp_size)
	_configure_card_slot_size(vp_size)
	var left_region := _left_region_width(vp_size)
	var avatar_height := _target_player_avatar_height(vp_size)
	if is_instance_valid(_nav_buttons):
		_nav_buttons.offset_left = 0
		_nav_buttons.offset_right = left_region
		_nav_buttons.offset_top = _nav_region_top(vp_size)
		_nav_buttons.offset_bottom = vp_size.y - exp_bar_h
		_nav_buttons.configure_button_metrics(_side_button_width(vp_size), _nav_button_height(vp_size))
	if is_instance_valid(_center_area):
		_center_area.position = Vector2.ZERO
		_center_area.size = Vector2(vp_size.x, vp_size.y - exp_bar_h)
	if is_instance_valid(_exp_bar_ui):
		_exp_bar_ui.offset_top = -exp_bar_h
	if is_instance_valid(_player_info):
		_player_info.size = _player_info_size(vp_size)
		_player_info.configure_text_font_size(PLAYER_INFO_FONT_SIZE)
		_player_info.configure_avatar_size(avatar_height)
	_apply_currency_layout(vp_size)

func _rebuild_current_view() -> void:
	match _current_view_id:
		"today_decks": _show_today_decks()
		"card_pool": _show_card_pool()
		"vault": _show_vault()
		"deck_panel": _show_deck_collection()
		"synthesis": _show_synthesis_panel()
		"settings": _show_settings()
		_: pass

func _configure_card_slot_size(vp_size: Vector2) -> void:
	var aspect := CardSlotUI.SLOT_SIZE.x / CardSlotUI.SLOT_SIZE.y
	var slot_h_by_height := maxf(1.0, vp_size.y * CARD_SLOT_HEIGHT_RATIO)
	var available_width := maxf(320.0, vp_size.x - 64.0)
	var max_slot_width := maxf(1.0, (available_width - 7.0 * 8.0) / 8.0)
	var slot_h := minf(slot_h_by_height, max_slot_width / aspect)
	var slot_size := Vector2(roundf(slot_h * aspect), roundf(slot_h))
	CardSlotUI.configure_slot_size(slot_size)

func _exp_bar_height(vp_size: Vector2) -> int:
	return clampi(int(vp_size.y * EXP_BAR_RATIO), EXP_BAR_MIN_HEIGHT, EXP_BAR_MAX_HEIGHT)

func _card_grid_width() -> float:
	return CARD_GRID_COLUMNS * CardSlotUI.SLOT_SIZE.x + (CARD_GRID_COLUMNS - 1) * CARD_GRID_SPACING

func _left_region_width(vp_size: Vector2 = Vector2.ZERO) -> float:
	var size_for_calc := vp_size if vp_size.x > 0.0 else get_viewport_rect().size
	return maxf(0.0, (size_for_calc.x - _card_grid_width()) * 0.5)

func _content_region_rect(vp_size: Vector2 = Vector2.ZERO) -> Rect2:
	var size_for_calc := vp_size if vp_size.x > 0.0 else get_viewport_rect().size
	var left := _left_region_width(size_for_calc)
	return Rect2(Vector2(left, 0.0), Vector2(maxf(0.0, size_for_calc.x - left), maxf(0.0, size_for_calc.y - _exp_bar_height(size_for_calc))))

func _side_button_width(vp_size: Vector2 = Vector2.ZERO) -> float:
	return roundf(_left_region_width(vp_size) * 0.8)

func _target_player_avatar_height(vp_size: Vector2 = Vector2.ZERO) -> float:
	var desired := roundf(CardSlotUI.SLOT_SIZE.y * CardDisplay.ART_RECT_RATIO.size.y * 1.80)
	var side_width := _left_region_width(vp_size)
	var max_fit := maxf(52.0, side_width * 0.78)
	return roundf(clampf(desired, 52.0, max_fit))

func _nav_button_height(vp_size: Vector2 = Vector2.ZERO) -> float:
	return roundf(_target_player_avatar_height(vp_size) * 0.25)

func _right_button_height(vp_size: Vector2 = Vector2.ZERO) -> float:
	return roundf(_target_player_avatar_height(vp_size) / 3.0)

func _currency_icon_size(vp_size: Vector2 = Vector2.ZERO) -> float:
	return roundf(_nav_button_height(vp_size) * 2.0 / 3.0)

func _apply_currency_layout(vp_size: Vector2 = Vector2.ZERO) -> void:
	if not is_instance_valid(_currency):
		return
	var icon_size := _currency_icon_size(vp_size)
	var row_width := maxf(260.0, icon_size * 4.0 + 170.0)
	_currency.configure_icon_size(icon_size)
	# 18px 字体在不同 Godot/系统字体环境下的实际最小高度可能超过 36px。
	# 高度也按内容计算，避免只修复横向扩展后仍切掉数字上下边缘。
	var row_height := maxf(36.0, _currency.get_required_row_height())
	_currency.offset_right = -55.0
	_currency.offset_top = 10.0
	_currency.offset_bottom = 10.0 + row_height
	_currency.configure_layout(row_width)

func _nav_region_top(vp_size: Vector2 = Vector2.ZERO) -> float:
	var avatar_height := _target_player_avatar_height(vp_size)
	var side_width := _left_region_width(vp_size)
	var avatar_top := maxf(4.0, (side_width - avatar_height) * 0.5)
	return avatar_top + avatar_height + PLAYER_INFO_VERTICAL_PADDING

func _player_info_size(vp_size: Vector2 = Vector2.ZERO) -> Vector2:
	var side_width := _left_region_width(vp_size)
	var avatar_height := _target_player_avatar_height(vp_size)
	var avatar_top := maxf(4.0, (side_width - avatar_height) * 0.5)
	return Vector2(side_width, avatar_top + avatar_height + PLAYER_INFO_VERTICAL_PADDING)

func _make_content_region_host(node_name: String) -> Control:
	var rect := _content_region_rect(get_viewport_rect().size)
	var host := Control.new()
	host.name = node_name
	host.set_anchors_preset(Control.PRESET_TOP_LEFT)
	host.position = rect.position
	host.size = rect.size
	return host

# ══════════════════════════════════════════════════
#  导航
# ══════════════════════════════════════════════════

func _on_nav_button(id: String) -> void:
	if id == "exit_game":
		_show_exit_game_dialog()
		return
	if id == "auction":
		AudioManager.play_auction_music_loop()
	else:
		AudioManager.play_game_music_loop()
	var switch_started := Time.get_ticks_msec()
	FileLogger.perf("scene_switch_start", {"target": id})
	if id != "card_pool" and (_card_pool_ui != null or _hand_area_ui != null):
		GameManager.sync_pool_hand_layout_background("leave_card_pool_to_" + id)

	FileLogger.perf("ui_render_start", {"target": id})
	match id:
		"today_decks": _show_today_decks()
		"card_pool": _show_card_pool()
		"vault": _show_vault()
		"deck_panel": _show_deck_collection()
		"auction": _show_message(Localization.t("ui.nav.auction"))
		"ladder": _show_message(Localization.t("ui.nav.ladder"))
		"mail": _show_message(Localization.t("ui.nav.mail"))
		"settings": _show_settings()
	FileLogger.perf("ui_render_done", {"target": id})
	FileLogger.perf("scene_switch_done", {"target": id, "total_ms": Time.get_ticks_msec() - switch_started})
	_refresh_page_data_background.call_deferred(id)

# ══════════════════════════════════════════════════
#  中央视图切换
# ══════════════════════════════════════════════════

func _show_card_pool() -> void:
	_current_view_id = "card_pool"
	_nav_buttons.select_by_id("card_pool")
	_clear_center()

	_card_pool_ui = CardPoolUI.new()
	_card_pool_ui.configure_side_button_metrics(_side_button_width(), _right_button_height())
	_card_pool_ui.card_double_clicked.connect(_on_card_pool_double_click)

	_hand_area_ui = HandAreaUI.new()
	_hand_area_ui.configure_side_button_metrics(_side_button_width(), _right_button_height())
	# 连接手牌区操作信号
	_hand_area_ui.synthesize_requested.connect(_on_hand_synthesize)
	_hand_area_ui.discard_requested.connect(_on_hand_discard)
	_hand_area_ui.vault_save_requested.connect(_on_hand_save_to_vault)
	_hand_area_ui.card_double_clicked.connect(_on_hand_double_click)

	# 计算卡槽总高度：卡池顶部、两区间距、手牌底部到经验条顶部三段等距
	var slot_h = int(CardSlotUI.SLOT_SIZE.y)
	var slot_spacing = 8
	var pool_total_h = 2 * slot_h + slot_spacing
	var hand_total_h = 2 * slot_h + slot_spacing
	var vertical_gap = maxf(0.0, (_center_area.size.y - pool_total_h - hand_total_h) / 3.0)

	# 卡池区（上半固定高度，不拉伸）
	var pool_container = Control.new()
	pool_container.position = Vector2(0, vertical_gap)
	pool_container.size = Vector2(_center_area.size.x, pool_total_h)
	_center_area.add_child(pool_container)

	_card_pool_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	pool_container.add_child(_card_pool_ui)

	# 手牌区（下半固定高度，不拉伸）
	var hand_container = Control.new()
	hand_container.position = Vector2(0, vertical_gap * 2.0 + pool_total_h)
	hand_container.size = Vector2(_center_area.size.x, hand_total_h)
	_center_area.add_child(hand_container)

	_hand_area_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	hand_container.add_child(_hand_area_ui)
	_hand_area_ui.refresh_display()
	_apply_game_text_color(_center_area)

func _show_today_decks() -> void:
	_current_view_id = "today_decks"
	_nav_buttons.select_by_id("today_decks")
	_clear_center()
	var host := _make_content_region_host("TodayDecksContentRegion")
	_center_area.add_child(host)
	_today_decks_ui = TodayDecksUIScript.new()
	_today_decks_ui.configure_layout(_exp_bar_height(get_viewport_rect().size))
	_today_decks_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	host.add_child(_today_decks_ui)
	_apply_game_text_color(_center_area)

func _sync_before_leaving_card_pool() -> Dictionary:
	if _card_pool_ui == null and _hand_area_ui == null:
		return {"success": true}
	return await GameManager.sync_pool_hand_layout()

func _show_vault() -> void:
	_current_view_id = "vault"
	_nav_buttons.select_by_id("vault")
	_clear_center()
	var host := _make_content_region_host("VaultContentRegion")
	_center_area.add_child(host)
	_vault_ui = VaultUI.new()
	_vault_ui.configure_side_button_metrics(_side_button_width(), _right_button_height())
	_vault_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	if is_instance_valid(_nav_buttons):
		_vault_ui.set_synthesis_reward_target_rects(
			_nav_buttons.get_button_global_rect("deck_panel"),
			_nav_buttons.get_button_global_rect("vault"),
			_currency.get_resource_icon_global_rect("gold") if is_instance_valid(_currency) else Rect2(),
			_currency.get_resource_icon_global_rect("gems") if is_instance_valid(_currency) else Rect2(),
			_currency.get_resource_icon_global_rect("stamina") if is_instance_valid(_currency) else Rect2()
		)
	host.add_child(_vault_ui)
	_apply_game_text_color(_center_area)

func _show_deck_collection() -> void:
	_current_view_id = "deck_panel"
	_nav_buttons.select_by_id("deck_panel")
	_clear_center()
	var host := _make_content_region_host("MuseumContentRegion")
	_center_area.add_child(host)
	_deck_collection_ui = DeckCollectionUI.new()
	_deck_collection_ui.configure_layout(_exp_bar_height(get_viewport_rect().size))
	_deck_collection_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	host.add_child(_deck_collection_ui)
	_apply_game_text_color(_center_area)

func _refresh_page_data_background(id: String) -> void:
	match id:
		"vault":
			if ApiClient.is_logged_in():
				await GameManager.sync_vault_from_server()
				await GameManager.sync_vault_slot_quote_from_server()
				if is_instance_valid(_vault_ui):
					_vault_ui.refresh_display()
					_apply_game_text_color(_vault_ui)
		"deck_panel":
			if ApiClient.is_logged_in():
				await GameManager.sync_decks_from_server()
				if is_instance_valid(_deck_collection_ui):
					_deck_collection_ui.render_decks()
					_apply_game_text_color(_deck_collection_ui)

func _show_synthesis_panel() -> void:
	_current_view_id = "synthesis"
	_clear_center()
	_synthesis_panel = SynthesisPanelUI.new()
	_synthesis_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_synthesis_panel.synthesis_completed.connect(_on_synthesis_completed)
	_synthesis_panel.synthesis_cancelled.connect(_on_synthesis_cancelled)
	_center_area.add_child(_synthesis_panel)
	_apply_game_text_color(_center_area)

func _on_synthesis_completed(_result: Dictionary) -> void:
	pass

func _on_synthesis_cancelled() -> void:
	_show_card_pool()

func _show_message(msg: String) -> void:
	_current_view_id = "message"
	_clear_center()
	var label = Label.new()
	label.set_anchors_preset(Control.PRESET_CENTER)
	label.size = Vector2(400, 100)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.text = msg
	_center_area.add_child(label)
	_apply_game_text_color(_center_area)

func _show_menu() -> void:
	_show_settings()

func _show_settings() -> void:
	if _current_view_id != "settings":
		_view_before_menu = _current_view_id
	_current_view_id = "settings"
	_nav_buttons.select_by_id("settings")
	_clear_center()
	var menu_panel = _build_menu_panel()
	_center_area.add_child(menu_panel)
	_apply_game_text_color(_center_area)
	_apply_settings_visuals(menu_panel)

func _build_menu_panel() -> Control:
	var panel = Control.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)

	var panel_rect := _settings_panel_rect()
	var panel_margin := _settings_panel_content_margin(panel_rect.size)
	var frame := Panel.new()
	frame.name = "SettingsRelicPanel"
	frame.set_anchors_preset(Control.PRESET_TOP_LEFT)
	frame.position = panel_rect.position
	frame.size = panel_rect.size
	CCRVisualStyle.apply_settings_panel(frame)
	panel.add_child(frame)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.offset_left = panel_margin.x
	margin.offset_top = panel_margin.y
	margin.offset_right = -panel_margin.x
	margin.offset_bottom = -panel_margin.y
	frame.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	var title = Label.new()
	title.text = Localization.t("ui.menu.title")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	CCRVisualStyle.apply_settings_label(title)
	vbox.add_child(title)

	var tab_row := HBoxContainer.new()
	tab_row.alignment = BoxContainer.ALIGNMENT_CENTER
	tab_row.add_theme_constant_override("separation", 8)
	for tab_data in [
		{"id": "basic", "name": "BasicSettingsTab", "text": Localization.t("ui.settings.tab.basic")},
		{"id": "controller", "name": "ControllerSettingsTab", "text": Localization.t("ui.settings.tab.controller")},
		{"id": "profile", "name": "ProfileSettingsTab", "text": Localization.t("ui.settings.tab.profile")},
	]:
		var tab_button := Button.new()
		tab_button.name = str(tab_data["name"])
		tab_button.text = str(tab_data["text"])
		tab_button.toggle_mode = true
		tab_button.button_pressed = _settings_tab == str(tab_data["id"])
		tab_button.custom_minimum_size = Vector2(150, 36)
		tab_button.set_meta("ccr_settings_tab", true)
		CCRVisualStyle.apply_settings_tab_button(tab_button, tab_button.button_pressed)
		tab_button.pressed.connect(_select_settings_tab.bind(str(tab_data["id"])))
		tab_row.add_child(tab_button)
	vbox.add_child(tab_row)

	var separator := HSeparator.new()
	vbox.add_child(separator)

	var page_scroll := ScrollContainer.new()
	page_scroll.name = "SettingsPageScroll"
	page_scroll.custom_minimum_size.x = _settings_page_frame_width(panel_rect.size, panel_margin)
	page_scroll.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	page_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	CCRVisualStyle.apply_settings_scroll_container(page_scroll)
	vbox.add_child(page_scroll)

	var page_content_host := MarginContainer.new()
	page_content_host.name = "SettingsPageContentHost"
	var page_frame_width := _settings_page_frame_width(panel_rect.size, panel_margin)
	var page_content_width := _settings_page_content_width(panel_rect.size, panel_margin)
	var page_side_margin := maxf(0.0, (page_frame_width - page_content_width) * 0.5)
	page_content_host.custom_minimum_size.x = page_frame_width
	page_content_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_content_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page_content_host.add_theme_constant_override("margin_left", int(roundf(page_side_margin)))
	page_content_host.add_theme_constant_override("margin_right", int(roundf(page_side_margin)))
	page_scroll.add_child(page_content_host)

	var page_content := VBoxContainer.new()
	page_content.name = "SettingsPageContent"
	page_content.custom_minimum_size.x = page_content_width
	page_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_content.add_theme_constant_override("separation", 10)
	page_content_host.add_child(page_content)

	match _settings_tab:
		"controller": _build_controller_settings_page(page_content)
		"profile": _build_profile_settings_page(page_content)
		_: _build_basic_settings_page(page_content)

	_apply_settings_font_delta(panel, 2)
	_apply_settings_visuals(panel)
	return panel

func _settings_panel_rect() -> Rect2:
	var vp_size := get_viewport_rect().size
	var content_rect := _content_region_rect(vp_size)
	var panel_size := Vector2(
		roundf(content_rect.size.x * 0.80),
		roundf(vp_size.y * 2.0 / 3.0)
	)
	panel_size.y = minf(panel_size.y, maxf(320.0, _center_area.size.y - 24.0 if is_instance_valid(_center_area) else panel_size.y))
	panel_size.x = maxf(640.0, panel_size.x)
	panel_size.x = minf(panel_size.x, maxf(320.0, content_rect.size.x - 24.0))
	var panel_position := Vector2(
		content_rect.position.x + (content_rect.size.x - panel_size.x) * 0.5,
		maxf(12.0, ((_center_area.size.y if is_instance_valid(_center_area) else vp_size.y) - panel_size.y) * 0.5)
	)
	return Rect2(panel_position, panel_size)

func _settings_panel_content_margin(panel_size: Vector2) -> Vector2:
	return Vector2(
		clampf(panel_size.x * 0.052, 42.0, 72.0),
		clampf(panel_size.y * 0.095, 42.0, 68.0)
	)

func _settings_page_frame_width(panel_size: Vector2, panel_margin: Vector2) -> float:
	var original_width := maxf(1.0, panel_size.x - panel_margin.x * 2.0)
	return roundf(original_width * SETTINGS_PAGE_FRAME_WIDTH_RATIO)

func _settings_page_content_width(panel_size: Vector2, panel_margin: Vector2) -> float:
	var original_width := maxf(1.0, panel_size.x - panel_margin.x * 2.0)
	return roundf(original_width * SETTINGS_PAGE_CONTENT_WIDTH_RATIO)

func _select_settings_tab(tab_id: String) -> void:
	if _settings_tab == tab_id:
		return
	_settings_tab = tab_id
	_show_settings()

func _build_basic_settings_page(vbox: VBoxContainer) -> void:

	var music_row = _make_slider_row(Localization.t("ui.menu.music_volume"), AudioManager.bgm_volume, func(v): AudioManager.set_bgm_volume(v))
	vbox.add_child(music_row)

	var sfx_row = _make_slider_row(Localization.t("ui.menu.sfx_volume"), AudioManager.sfx_volume, func(v): AudioManager.set_sfx_volume(v))
	vbox.add_child(sfx_row)

	var resolution_row := HBoxContainer.new()
	var resolution_label := Label.new()
	resolution_label.text = Localization.t("ui.menu.resolution")
	resolution_label.custom_minimum_size = Vector2(120, 30)
	CCRVisualStyle.apply_settings_label(resolution_label)
	resolution_row.add_child(resolution_label)
	var resolution_select := OptionButton.new()
	resolution_select.name = "ResolutionSelect"
	resolution_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var current_resolution := DisplaySettings.get_current_resolution()
	var selected_resolution_index := 0
	var resolution_index := 0
	for resolution in DisplaySettings.get_supported_resolutions():
		resolution_select.add_item(DisplaySettings.resolution_label(resolution))
		resolution_select.set_item_metadata(resolution_index, resolution)
		if resolution == current_resolution:
			selected_resolution_index = resolution_index
		resolution_index += 1
	resolution_select.select(selected_resolution_index)
	CCRVisualStyle.apply_settings_option_button(resolution_select)
	resolution_select.item_selected.connect(func(index: int):
		var selected_resolution: Vector2i = resolution_select.get_item_metadata(index)
		DisplaySettings.apply_resolution(selected_resolution, true)
	)
	resolution_row.add_child(resolution_select)
	vbox.add_child(resolution_row)

	var window_mode_row := HBoxContainer.new()
	var window_mode_label := Label.new()
	window_mode_label.text = Localization.t("ui.menu.window_mode")
	window_mode_label.custom_minimum_size = Vector2(120, 30)
	CCRVisualStyle.apply_settings_label(window_mode_label)
	window_mode_row.add_child(window_mode_label)
	var window_mode_select := OptionButton.new()
	window_mode_select.name = "WindowModeSelect"
	window_mode_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	window_mode_select.add_item(Localization.t("ui.menu.window_mode.fullscreen"))
	window_mode_select.set_item_metadata(0, true)
	window_mode_select.add_item(Localization.t("ui.menu.window_mode.windowed"))
	window_mode_select.set_item_metadata(1, false)
	window_mode_select.select(0 if DisplaySettings.is_fullscreen_enabled() else 1)
	CCRVisualStyle.apply_settings_option_button(window_mode_select)
	window_mode_select.item_selected.connect(func(index: int):
		var fullscreen := bool(window_mode_select.get_item_metadata(index))
		DisplaySettings.apply_window_mode(fullscreen, true)
	)
	window_mode_row.add_child(window_mode_select)
	vbox.add_child(window_mode_row)

	var language_row := HBoxContainer.new()
	var language_label := Label.new()
	language_label.text = Localization.t("ui.menu.language")
	language_label.custom_minimum_size = Vector2(120, 30)
	CCRVisualStyle.apply_settings_label(language_label)
	language_row.add_child(language_label)
	var language_select := OptionButton.new()
	language_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var selected_language_index := 0
	var supported_locales := Localization.get_supported_locales()
	for i in range(supported_locales.size()):
		var locale_code := str(supported_locales[i])
		language_select.add_item(Localization.language_label(locale_code))
		language_select.set_item_metadata(i, locale_code)
		if locale_code == Localization.locale:
			selected_language_index = i
	language_select.select(selected_language_index)
	CCRVisualStyle.apply_settings_option_button(language_select)
	language_select.item_selected.connect(func(index: int):
		var selected_locale := str(language_select.get_item_metadata(index))
		_apply_language_selection.call_deferred(selected_locale)
	)
	language_row.add_child(language_select)
	vbox.add_child(language_row)

	var mute_btn = Button.new()
	mute_btn.text = Localization.t("ui.menu.mute") if not AudioManager.is_muted else Localization.t("ui.menu.muted")
	mute_btn.custom_minimum_size = Vector2(0, 42)
	CCRVisualStyle.apply_settings_button(mute_btn)
	mute_btn.pressed.connect(func():
		AudioManager.toggle_mute()
		mute_btn.text = Localization.t("ui.menu.mute") if not AudioManager.is_muted else Localization.t("ui.menu.muted")
	)
	vbox.add_child(mute_btn)

	var sep = HSeparator.new()
	vbox.add_child(sep)

	var logout_btn = Button.new()
	logout_btn.text = Localization.t("ui.menu.logout")
	logout_btn.custom_minimum_size = Vector2(0, 42)
	logout_btn.set_meta("ccr_settings_destructive", true)
	CCRVisualStyle.apply_settings_button(logout_btn, false, true)
	logout_btn.pressed.connect(_on_logout_pressed)
	vbox.add_child(logout_btn)

func _build_controller_settings_page(vbox: VBoxContainer) -> void:
	var controller_title := Label.new()
	controller_title.text = Localization.t("ui.controller.title")
	controller_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controller_title.add_theme_font_size_override("font_size", 18)
	CCRVisualStyle.apply_settings_label(controller_title)
	vbox.add_child(controller_title)

	for action_id in ControllerInput.get_action_ids():
		vbox.add_child(_make_controller_binding_row(action_id))

	var reset_controller_btn := Button.new()
	reset_controller_btn.text = Localization.t("ui.controller.reset")
	reset_controller_btn.custom_minimum_size = Vector2(0, 42)
	CCRVisualStyle.apply_settings_button(reset_controller_btn)
	reset_controller_btn.pressed.connect(func():
		ControllerInput.reset_bindings()
		_show_settings()
	)
	vbox.add_child(reset_controller_btn)

func _build_profile_settings_page(vbox: VBoxContainer) -> void:
	var profile_title := Label.new()
	profile_title.text = Localization.t("ui.profile.title")
	profile_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	profile_title.add_theme_font_size_override("font_size", 18)
	CCRVisualStyle.apply_settings_label(profile_title)
	vbox.add_child(profile_title)

	var avatar_row := HBoxContainer.new()
	avatar_row.alignment = BoxContainer.ALIGNMENT_CENTER
	avatar_row.add_theme_constant_override("separation", 14)
	var avatar_preview := TextureRect.new()
	avatar_preview.name = "ProfileAvatarPreview"
	avatar_preview.texture = AvatarCatalog.get_texture(GameManager.player_data.avatar_id)
	avatar_preview.custom_minimum_size = Vector2(96, 96)
	avatar_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	avatar_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	avatar_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	avatar_row.add_child(avatar_preview)
	var avatar_column := VBoxContainer.new()
	var avatar_label := Label.new()
	avatar_label.text = Localization.t("ui.profile.avatar")
	CCRVisualStyle.apply_settings_label(avatar_label)
	avatar_column.add_child(avatar_label)
	var change_avatar_btn := Button.new()
	change_avatar_btn.name = "AvatarChangeButton"
	change_avatar_btn.text = Localization.t("ui.profile.avatar.change")
	change_avatar_btn.custom_minimum_size = Vector2(210, 42)
	CCRVisualStyle.apply_settings_button(change_avatar_btn)
	change_avatar_btn.pressed.connect(_show_avatar_picker)
	avatar_column.add_child(change_avatar_btn)
	avatar_row.add_child(avatar_column)
	vbox.add_child(avatar_row)

	var region_row := HBoxContainer.new()
	var region_label := Label.new()
	region_label.text = Localization.t("ui.profile.region")
	region_label.custom_minimum_size = Vector2(150, 32)
	CCRVisualStyle.apply_settings_label(region_label)
	region_row.add_child(region_label)
	var region_select := OptionButton.new()
	region_select.name = "RegionSelect"
	region_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	region_select.custom_minimum_size = Vector2(0, 42)
	var selected_region_index := 0
	var region_index := 0
	for entry in CountryCatalog.localized_entries(Localization.locale):
		var code := str(entry["code"])
		region_select.add_item(str(entry["label"]))
		region_select.set_item_metadata(region_index, code)
		if code == GameManager.player_data.country:
			selected_region_index = region_index
		region_index += 1
	region_select.select(selected_region_index)
	CCRVisualStyle.apply_settings_option_button(region_select)
	_configure_region_popup_bounds(region_select)
	region_row.add_child(region_select)
	vbox.add_child(region_row)

	var status_label := Label.new()
	status_label.name = "ProfileSaveStatus"
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 14)
	CCRVisualStyle.apply_settings_label(status_label, true)
	vbox.add_child(status_label)
	region_select.item_selected.connect(func(index: int):
		var region_code := str(region_select.get_item_metadata(index))
		if region_code != GameManager.player_data.country:
			_save_region(region_code, region_select, status_label)
	)

func _configure_region_popup_bounds(select: OptionButton) -> void:
	var popup := select.get_popup()
	if popup == null:
		return
	popup.max_size = Vector2i(0, int(get_viewport_rect().size.y * 0.9))
	popup.about_to_popup.connect(func():
		_clamp_region_popup_bounds.call_deferred(select)
	)

func _clamp_region_popup_bounds(select: OptionButton) -> void:
	if select == null or not select.is_inside_tree():
		return
	var popup := select.get_popup()
	if popup == null:
		return
	var select_rect := select.get_global_rect()
	var viewport_height := get_viewport_rect().size.y
	var min_y := int(maxf(0.0, select_rect.position.y - select_rect.size.y))
	var max_bottom := int(viewport_height * 0.9)
	var popup_position := popup.position
	if popup_position.y < min_y:
		popup_position.y = min_y
	popup.position = popup_position
	var max_height := maxi(int(select_rect.size.y), max_bottom - popup_position.y)
	popup.max_size = Vector2i(0, max_height)
	if popup.size.y > max_height:
		popup.size = Vector2i(popup.size.x, max_height)

func _apply_settings_font_delta(root: Node, delta: int) -> void:
	for child in root.get_children():
		if child is Label or child is Button or child is OptionButton:
			var control := child as Control
			var current := control.get_theme_font_size("font_size")
			if current <= 0:
				current = 16
			control.add_theme_font_size_override("font_size", current + delta)
		_apply_settings_font_delta(child, delta)

func _apply_settings_visuals(root: Node) -> void:
	for child in root.get_children():
		if child is Label:
			CCRVisualStyle.apply_settings_label(child as Label)
		elif child is OptionButton:
			CCRVisualStyle.apply_settings_option_button(child as OptionButton)
		elif child is HSlider:
			CCRVisualStyle.apply_settings_slider(child as HSlider)
		elif child is Button:
			if child.has_meta("ccr_settings_tab"):
				CCRVisualStyle.apply_settings_tab_button(child as Button, (child as Button).button_pressed)
			else:
				CCRVisualStyle.apply_settings_button(child as Button, false, child.has_meta("ccr_settings_destructive"))
		elif child is ScrollContainer:
			CCRVisualStyle.apply_settings_scroll_container(child as ScrollContainer)
		_apply_settings_visuals(child)

func _show_avatar_picker() -> void:
	var popup := PopupPanel.new()
	popup.name = "AvatarPickerPopup"
	popup.exclusive = true
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 20
	root.offset_top = 18
	root.offset_right = -20
	root.offset_bottom = -18
	root.add_theme_constant_override("separation", 10)
	popup.add_child(root)
	var title := Label.new()
	title.text = Localization.t("ui.profile.avatar.select")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	CCRVisualStyle.apply_settings_label(title)
	root.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	CCRVisualStyle.apply_settings_scroll_container(scroll)
	root.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(grid)
	for avatar_id in AvatarCatalog.get_unlocked_avatar_ids():
		var avatar_data := AvatarCatalog.get_avatar(avatar_id)
		var avatar_button := Button.new()
		avatar_button.name = "AvatarOption_" + avatar_id.replace(".", "_")
		avatar_button.custom_minimum_size = Vector2(138, 138)
		avatar_button.tooltip_text = Localization.t(str(avatar_data["name_key"]))
		CCRVisualStyle.apply_settings_avatar_button(avatar_button)
		avatar_button.pressed.connect(_select_avatar.bind(avatar_id, popup))
		var texture := TextureRect.new()
		texture.texture = AvatarCatalog.get_texture(avatar_id)
		texture.set_anchors_preset(Control.PRESET_FULL_RECT)
		texture.offset_left = 6
		texture.offset_top = 6
		texture.offset_right = -6
		texture.offset_bottom = -6
		texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		avatar_button.add_child(texture)
		grid.add_child(avatar_button)
	add_child(popup)
	popup.popup_centered(Vector2i(720, 560))

func _select_avatar(avatar_id: String, popup: PopupPanel) -> void:
	if not AvatarCatalog.is_known_avatar(avatar_id) or avatar_id == GameManager.player_data.avatar_id:
		popup.queue_free()
		return
	var resp := await ApiClient.update_profile({"avatar": avatar_id})
	popup.queue_free()
	if resp.get("success", false):
		GameManager.apply_profile(resp["data"])
	_show_settings()

func _save_region(region_code: String, select: OptionButton, status_label: Label) -> void:
	select.disabled = true
	status_label.text = Localization.t("ui.profile.saving")
	var resp := await ApiClient.update_profile({"country": region_code})
	if resp.get("success", false):
		GameManager.apply_profile(resp["data"])
		status_label.text = Localization.t("ui.profile.saved")
	else:
		status_label.text = Localization.t("ui.profile.save_failed")
		select.disabled = false

func _apply_language_selection(selected_locale: String) -> void:
	Localization.set_locale(selected_locale, true, GameManager.player_data.user_id)

func _return_from_menu() -> void:
	match _view_before_menu:
		"today_decks": _show_today_decks()
		"vault": _show_vault()
		"deck_panel": _show_deck_collection()
		"synthesis": _show_synthesis_panel()
		"settings": _show_settings()
		_: _show_card_pool()

func _on_locale_changed(_locale: String) -> void:
	_nav_buttons.refresh_labels()
	if is_instance_valid(_player_info):
		_player_info.refresh()
	if not _game_ui_active:
		return
	var localized_data_view := _current_view_id
	match _current_view_id:
		"today_decks": _show_today_decks()
		"settings": _show_settings()
		"vault": _show_vault()
		"deck_panel": _show_deck_collection()
		"synthesis": _show_synthesis_panel()
		_: _show_card_pool()
	_refresh_localized_server_data.call_deferred(localized_data_view)

func _refresh_localized_server_data(view_id: String) -> void:
	if not ApiClient.is_logged_in():
		return
	match view_id:
		"today_decks":
			var key_resp := await ApiClient.get_draw_key()
			if key_resp.get("success", false):
				GameManager.apply_draw_key(key_resp["data"])
		"card_pool", "synthesis": await GameManager.sync_initial_card_pool_from_server()
		"vault": await GameManager.sync_vault_from_server()
		"deck_panel": await GameManager.sync_decks_from_server()
		_: return
	if _current_view_id != view_id:
		return
	match view_id:
		"today_decks": _show_today_decks()
		"vault": _show_vault()
		"deck_panel": _show_deck_collection()
		"synthesis": _show_synthesis_panel()
		_: _show_card_pool()

func _make_slider_row(label_text: String, default_val: float, callback: Callable) -> HBoxContainer:
	var row = HBoxContainer.new()
	var lbl = Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(100, 30)
	row.add_child(lbl)

	var slider = HSlider.new()
	slider.min_value = 0
	slider.max_value = 1
	slider.step = 0.01
	slider.rounded = false
	slider.value = default_val
	slider.mouse_filter = Control.MOUSE_FILTER_STOP
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(callback)
	row.add_child(slider)

	return row

func _make_controller_binding_row(action_id: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = Localization.t(ControllerInput.get_action_label_key(action_id))
	label.custom_minimum_size = Vector2(210, 28)
	row.add_child(label)

	var select := OptionButton.new()
	select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var current_binding := ControllerInput.get_binding(action_id)
	var selected_index := 0
	var index := 0
	for option in ControllerInput.get_binding_options():
		var binding_id := str(option.get("id", ""))
		select.add_item(Localization.t(str(option.get("label_key", ""))))
		select.set_item_metadata(index, binding_id)
		if binding_id == current_binding:
			selected_index = index
		index += 1
	select.select(selected_index)
	select.item_selected.connect(func(item_index: int):
		ControllerInput.set_binding(action_id, str(select.get_item_metadata(item_index)))
	)
	row.add_child(select)
	return row

func _apply_game_text_color(root: Node = null) -> void:
	var target := root if root != null else self
	# 卡牌内部文字由 CardDisplay 按稀有度独立管理。页面级主题如果继续递归，
	# 会在页面切换、后台同步和 resize 时把卡牌标题染回统一深色，随后卡牌
	# 自身刷新又改回稀有度颜色，形成玩家看到的颜色反复跳变。
	if target is CardDisplay:
		(target as CardDisplay).refresh_title_text_color()
		return
	for child in target.get_children():
		if child.name == "ExitGameConfirmDialog":
			_apply_exit_game_dialog_style(child as Control)
			continue
		if child is Label:
			if child.name != "ExpValueLabel":
				CCRVisualStyle.apply_dark_label(child as Label)
		_apply_game_text_color(child)

func _on_controller_action_pressed(action_id: String) -> void:
	if not _game_ui_active:
		return
	match action_id:
		ControllerInput.ACTION_NAV_PREV:
			if is_instance_valid(_nav_buttons):
				_nav_buttons.select_next_enabled(-1)
		ControllerInput.ACTION_NAV_NEXT:
			if is_instance_valid(_nav_buttons):
				_nav_buttons.select_next_enabled(1)
		ControllerInput.ACTION_HAND_PAGE:
			if _current_view_id == "card_pool" and is_instance_valid(_hand_area_ui):
				_hand_area_ui.request_page_flip()
		ControllerInput.ACTION_DRAW_FREE:
			if is_instance_valid(_card_pool_ui):
				_card_pool_ui.controller_refresh("free")
		ControllerInput.ACTION_DRAW_GEM:
			if is_instance_valid(_card_pool_ui):
				_card_pool_ui.controller_refresh("gem")
		ControllerInput.ACTION_DRAW_GOLD:
			if is_instance_valid(_card_pool_ui):
				_card_pool_ui.controller_refresh("gold")
		ControllerInput.ACTION_SYNTHESIZE:
			_handle_controller_synthesize()
		ControllerInput.ACTION_STORE_VAULT:
			if _activate_focused_slot_for_area("hand"):
				_on_hand_save_to_vault()
		ControllerInput.ACTION_DISCARD:
			if _activate_focused_slot_for_area("hand"):
				_on_hand_discard()

func _handle_controller_synthesize() -> void:
	if _current_view_id == "vault":
		_activate_focused_slot_for_area("vault")
		if is_instance_valid(_vault_ui):
			_vault_ui.controller_synthesize()
		return
	if _activate_focused_slot_for_area("hand"):
		_on_hand_synthesize()

func _activate_focused_slot_for_area(area_type: String) -> bool:
	var focus_owner := get_viewport().gui_get_focus_owner()
	if not focus_owner is CardSlotUI:
		return false
	var slot := focus_owner as CardSlotUI
	if slot.area_type != area_type:
		return false
	slot.controller_activate()
	return true

# ══════════════════════════════════════════════════
#  手牌区操作（来自 HandAreaUI 信号）
# ══════════════════════════════════════════════════

func _on_hand_synthesize() -> void:
	if _synthesis_animation_running or _hand_action_animation_running or not is_instance_valid(_hand_area_ui):
		return
	var selected_indices := _hand_area_ui.get_selected_synthesis_indices()
	if selected_indices.size() != 5:
		return

	# 先等此前的抽卡布局确认等资产请求排空，再启动合成视觉流程。
	# 否则合成请求会在 ApiClient 队列尾部等待，而画面已经先走到 relic 阶段。
	_synthesis_animation_running = true
	await _wait_for_prior_asset_operations()
	if not is_inside_tree() or not is_instance_valid(_hand_area_ui):
		_synthesis_animation_running = false
		return
	selected_indices = _hand_area_ui.get_selected_synthesis_indices()
	if selected_indices.size() != 5:
		_synthesis_animation_running = false
		return
	var animation_sources := _hand_area_ui.get_synthesis_animation_sources(selected_indices)

	var old_pool_cards: Array = CardPoolSystem.current_pool.duplicate()
	if old_pool_cards.is_empty() and not GameManager.player_data.pool_cards.is_empty():
		old_pool_cards = GameManager.player_data.pool_cards.duplicate()
	var old_hand_cards: Array = GameManager.player_data.hand_cards.duplicate()

	_hand_area_ui.hide_synthesis_slots_for_animation(selected_indices)
	var overlay = SynthesisAnimationOverlayScript.new()
	overlay.name = "SynthesisAnimationOverlay"
	overlay.setup(
		animation_sources,
		_nav_buttons.get_button_global_rect("deck_panel") if is_instance_valid(_nav_buttons) else Rect2(),
		true
	)
	get_tree().root.add_child(overlay)
	var completion := {"done": false, "success": false, "result": {}, "error": ""}
	_confirm_hand_synthesis_for_animation.call_deferred(
		selected_indices.duplicate(),
		old_pool_cards,
		old_hand_cards,
		overlay,
		completion
	)
	await overlay.play()
	await _wait_for_synthesis_completion(completion)
	_synthesis_animation_running = false

	if completion.get("success", false):
		_apply_hand_synthesis_pending_removal(selected_indices)
		_apply_synthesis_confirmed_result(completion.get("result", {}))
		if is_instance_valid(_hand_area_ui):
			_hand_area_ui.clear_synthesis_animation_hidden_slots()
			_hand_area_ui.clear_selection()
			_hand_area_ui.refresh_display()
		_sync_after_synthesis_success_background()
	else:
		push_error("合成失败: ", completion.get("error", "未知错误"))
		await _recover_after_synthesis_failure()


func _wait_for_prior_asset_operations() -> void:
	while is_inside_tree() and (
		CardPoolSystem.has_pending_confirm()
		or ApiClient.has_pending_asset_requests()
	):
		await get_tree().process_frame

func _wait_for_synthesis_completion(completion: Dictionary) -> void:
	while is_inside_tree() and not bool(completion.get("done", false)):
		await get_tree().process_frame

func _play_hand_synthesis_animation(animation_sources: Array[Dictionary]) -> void:
	if animation_sources.is_empty() or get_tree() == null:
		return
	var overlay = SynthesisAnimationOverlayScript.new()
	overlay.name = "SynthesisAnimationOverlay"
	overlay.setup(animation_sources, _nav_buttons.get_button_global_rect("deck_panel") if is_instance_valid(_nav_buttons) else Rect2())
	get_tree().root.add_child(overlay)
	await overlay.play()

func _play_hand_card_store_animation(animation_source: Dictionary) -> void:
	await _play_hand_single_card_animation([animation_source], "store")

func _play_hand_card_discard_animation(animation_source: Dictionary) -> void:
	await _play_hand_single_card_animation([animation_source], "discard")

func _play_hand_single_card_animation(animation_sources: Array[Dictionary], mode: String) -> void:
	if animation_sources.is_empty() or get_tree() == null:
		return
	var overlay = SynthesisAnimationOverlayScript.new()
	overlay.name = "HandCardActionAnimationOverlay"
	overlay.setup(animation_sources, _nav_buttons.get_button_global_rect("deck_panel") if is_instance_valid(_nav_buttons) else Rect2())
	get_tree().root.add_child(overlay)
	match mode:
		"store":
			await overlay.play_store_to_nav()
		"discard":
			await overlay.play_discard()
		_:
			overlay.queue_free()

func _confirm_hand_synthesis_for_animation(
	selected_indices: Array,
	old_pool_cards: Array,
	old_hand_cards: Array,
	overlay: SynthesisAnimationOverlay,
	completion: Dictionary
) -> void:
	var sync_resp := await ApiClient.sync_pool_hand_layout(old_pool_cards, old_hand_cards)
	if not sync_resp.get("success", false):
		completion["error"] = "合成前同步失败: " + str(sync_resp.get("error", ""))
		completion["done"] = true
		if is_instance_valid(overlay):
			overlay.set_reward_items([], false)
		return

	var resp := await ApiClient.synthesize(selected_indices, "hand")
	if resp.get("success", false):
		var result: Dictionary = resp.get("data", {})
		completion["success"] = true
		completion["result"] = result
		completion["done"] = true
		if is_instance_valid(overlay):
			overlay.set_reward_items(_resolve_synthesis_reward_targets(result), true)
	else:
		completion["error"] = str(resp.get("error", "未知错误"))
		completion["done"] = true
		if is_instance_valid(overlay):
			overlay.set_reward_items([], false)

func _resolve_synthesis_reward_targets(result: Dictionary) -> Array[Dictionary]:
	var resolved: Array[Dictionary] = []
	for raw_entry in SynthesisAnimationOverlay.extract_reward_entries(result):
		var entry: Dictionary = raw_entry.duplicate()
		match str(entry.get("type", "")):
			"gold":
				entry["target_rect"] = _currency.get_resource_icon_global_rect("gold") if is_instance_valid(_currency) else Rect2()
			"gems":
				entry["target_rect"] = _currency.get_resource_icon_global_rect("gems") if is_instance_valid(_currency) else Rect2()
			"stamina":
				entry["target_rect"] = _currency.get_resource_icon_global_rect("stamina") if is_instance_valid(_currency) else Rect2()
			"slot":
				var target := _resolve_slot_reward_target(str(entry.get("slot_type", "")), int(entry.get("slot_index", -1)))
				entry.merge(target, true)
		resolved.append(entry)
	return resolved

func _resolve_slot_reward_target(slot_type: String, slot_index: int) -> Dictionary:
	if slot_type == "vault" and is_instance_valid(_nav_buttons):
		return {"target_rect": _nav_buttons.get_button_global_rect("vault")}
	var visible_target: Dictionary = {}
	if slot_type == "hand" and is_instance_valid(_hand_area_ui):
		visible_target = _hand_area_ui.get_reward_unlock_target(slot_index)
	elif slot_type == "pool" and is_instance_valid(_card_pool_ui):
		visible_target = _card_pool_ui.get_reward_unlock_target(slot_index)
	if not visible_target.is_empty():
		return visible_target
	# 手牌翻页后不可见（以及当前页不存在）的解锁目标统一飞出屏幕下方。
	var viewport_size := get_viewport_rect().size
	return {"target_rect": Rect2(Vector2(viewport_size.x * 0.5 - 21.0, viewport_size.y + 48.0), Vector2(42.0, 42.0))}

func _apply_hand_synthesis_pending_removal(selected_indices: Array) -> void:
	var indices := selected_indices.duplicate()
	indices.sort()
	for i in range(indices.size() - 1, -1, -1):
		GameManager.player_data.remove_from_hand_at(indices[i])
	GameManager.player_data.changed.emit()

func _apply_synthesis_confirmed_result(result: Dictionary) -> void:
	var rewards: Dictionary = result.get("rewards", {})
	var gold := int(result.get("gold_reward", rewards.get("gold", 0)))
	if gold > 0:
		GameManager.player_data.add_gold(gold)

	var gems := int(rewards.get("gems", 0))
	if gems > 0:
		GameManager.player_data.add_gems(gems)

	var exp_result: Dictionary = result.get("exp_result", {})
	if not exp_result.is_empty():
		GameManager.apply_exp_result(exp_result, true)

	var deck_data: Dictionary = result.get("deck", {})
	if not deck_data.is_empty():
		DeckSystem.add_synthesized_deck(deck_data)

	GameManager.player_data.changed.emit()

func _sync_after_synthesis_success_background() -> void:
	await GameManager.sync_reward_state_from_server()
	await GameManager.sync_decks_from_server()
	if is_instance_valid(_hand_area_ui):
		_hand_area_ui.refresh_display()

func _recover_after_synthesis_failure() -> void:
	await GameManager.sync_initial_card_pool_from_server()
	await GameManager.sync_decks_from_server()
	if is_instance_valid(_hand_area_ui):
		_hand_area_ui.clear_synthesis_animation_hidden_slots()
		_hand_area_ui.clear_selection()
		_hand_area_ui.refresh_display()

func _on_hand_discard() -> void:
	if _synthesis_animation_running or _hand_action_animation_running or not is_instance_valid(_hand_area_ui):
		return
	var idx := _hand_area_ui.get_selected_hand_index()
	if idx < 0:
		return
	var hand_cards = GameManager.player_data.hand_cards
	if idx >= hand_cards.size() or hand_cards[idx] == null:
		_hand_area_ui.clear_selection()
		return

	var old_pool_cards: Array = CardPoolSystem.current_pool.duplicate(true)
	if old_pool_cards.is_empty() and not GameManager.player_data.pool_cards.is_empty():
		old_pool_cards = GameManager.player_data.pool_cards.duplicate(true)
	var old_hand_cards: Array = hand_cards.duplicate(true)
	var animation_source := _hand_area_ui.get_synthesis_animation_sources([idx])[0]

	_hand_area_ui.hide_card_action_slots_for_animation([idx])
	_hand_action_animation_running = true
	await _play_hand_card_discard_animation(animation_source)
	_hand_action_animation_running = false

	if not ApiClient.is_logged_in():
		hand_cards[idx] = null
		GameManager.player_data.changed.emit()
		if is_instance_valid(_hand_area_ui):
			_hand_area_ui.clear_card_action_animation_hidden_slots()
			_hand_area_ui.clear_selection()
			_hand_area_ui.refresh_display()
		return

	hand_cards[idx] = null
	GameManager.player_data.changed.emit()
	if is_instance_valid(_hand_area_ui):
		_hand_area_ui.clear_card_action_animation_hidden_slots()
		_hand_area_ui.clear_selection()
		_hand_area_ui.refresh_display()

	_confirm_hand_discard_background(idx, old_pool_cards, old_hand_cards)

func _confirm_hand_discard_background(idx: int, old_pool_cards: Array, old_hand_cards: Array) -> void:
	var sync_resp := await ApiClient.sync_pool_hand_layout(old_pool_cards, old_hand_cards)
	if not sync_resp.get("success", false):
		push_error("丢弃前同步失败: ", sync_resp.get("error", ""))
		await _recover_after_hand_action_failure("discard_sync")
		return

	var resp = await ApiClient.discard_card("hand", idx)
	if resp["success"]:
		GameManager.mark_pool_hand_layout_clean("hand_discard")
	else:
		push_error("丢弃失败: ", resp["error"])
		await _recover_after_hand_action_failure("discard")

func _on_hand_save_to_vault() -> void:
	if _synthesis_animation_running or _hand_action_animation_running or not is_instance_valid(_hand_area_ui):
		return
	var source_idx := _hand_area_ui.get_selected_hand_index()
	if source_idx < 0:
		return
	var hand_cards = GameManager.player_data.hand_cards
	if source_idx >= hand_cards.size() or hand_cards[source_idx] == null:
		_hand_area_ui.clear_selection()
		return

	var card = hand_cards[source_idx]
	var animation_source := _hand_area_ui.get_synthesis_animation_sources([source_idx])[0]

	var vault_cards = GameManager.player_data.vault_cards
	var vault_idx := _find_first_local_vault_space()
	var old_pool_cards: Array = CardPoolSystem.current_pool.duplicate(true)
	if old_pool_cards.is_empty() and not GameManager.player_data.pool_cards.is_empty():
		old_pool_cards = GameManager.player_data.pool_cards.duplicate(true)
	var old_hand_cards: Array = hand_cards.duplicate(true)
	var old_vault_cards: Array = vault_cards.duplicate(true)

	if not ApiClient.is_logged_in():
		# 找第一个空保险箱槽
		if vault_idx < 0:
			print("保险箱已满")
			return

		_hand_area_ui.hide_card_action_slots_for_animation([source_idx])
		_hand_action_animation_running = true
		await _play_hand_card_store_animation(animation_source)
		_hand_action_animation_running = false

		# 离线模式：直接本地移动
		hand_cards[source_idx] = null
		while vault_cards.size() <= vault_idx:
			vault_cards.append(null)
		vault_cards[vault_idx] = card
		GameManager.player_data.changed.emit()
		if is_instance_valid(_hand_area_ui):
			_hand_area_ui.clear_card_action_animation_hidden_slots()
			_hand_area_ui.clear_selection()
			_hand_area_ui.refresh_display()
		return

	if vault_idx < 0:
		print("保险箱已满，请先购买保险箱槽位")
		return

	_hand_area_ui.hide_card_action_slots_for_animation([source_idx])
	_hand_action_animation_running = true
	await _play_hand_card_store_animation(animation_source)
	_hand_action_animation_running = false

	hand_cards[source_idx] = null
	while vault_cards.size() <= vault_idx:
		vault_cards.append(null)
	vault_cards[vault_idx] = card
	GameManager.player_data.changed.emit()
	if is_instance_valid(_hand_area_ui):
		_hand_area_ui.clear_card_action_animation_hidden_slots()
		_hand_area_ui.clear_selection()
		_hand_area_ui.refresh_display()

	_confirm_hand_save_to_vault_background(source_idx, vault_idx, old_pool_cards, old_hand_cards, old_vault_cards)

func _confirm_hand_save_to_vault_background(source_idx: int, vault_idx: int, old_pool_cards: Array, old_hand_cards: Array, old_vault_cards: Array) -> void:
	var sync_resp := await ApiClient.sync_pool_hand_layout(old_pool_cards, old_hand_cards)
	if not sync_resp.get("success", false):
		print("保存前同步失败: ", sync_resp.get("error", ""))
		await _recover_after_hand_action_failure("vault_sync")
		return

	var resp = await ApiClient.move_to_vault("hand", source_idx, vault_idx)
	if resp["success"]:
		var result_data: Dictionary = resp["data"]
		var cd = ApiClient.card_slot_to_cardinfo(result_data)
		if cd != null:
			while GameManager.player_data.vault_cards.size() <= vault_idx:
				GameManager.player_data.vault_cards.append(null)
			GameManager.player_data.vault_cards[vault_idx] = cd
			GameManager.player_data.changed.emit()
		GameManager.mark_pool_hand_layout_clean("hand_to_vault")
	else:
		print("保存失败: ", resp["error"])
		GameManager.player_data.vault_cards = old_vault_cards
		await _recover_after_hand_action_failure("vault")

func _find_first_local_vault_space() -> int:
	var vault_cards = GameManager.player_data.vault_cards
	for i in range(GameManager.player_data.vault_slots):
		if i >= vault_cards.size() or vault_cards[i] == null:
			return i
	return -1

func _recover_after_hand_action_failure(reason: String = "") -> void:
	FileLogger.warn("手牌资产动作失败，正在回源同步: " + reason)
	await GameManager.sync_initial_card_pool_from_server()
	await GameManager.sync_vault_from_server()
	if is_instance_valid(_hand_area_ui):
		_hand_area_ui.clear_card_action_animation_hidden_slots()
		_hand_area_ui.clear_selection()
		_hand_area_ui.refresh_display()

func _apply_hand_synthesis_result(result: Dictionary, fallback_indices: Array[int]) -> void:
	var consumed = result.get("consumed_slots", [])
	var indices_to_remove: Array[int] = []
	for slot in consumed:
		if slot is Dictionary:
			var idx := int(slot.get("slot_index", -1))
			if idx >= 0:
				indices_to_remove.append(idx)
	if indices_to_remove.is_empty():
		indices_to_remove = fallback_indices.duplicate()

	indices_to_remove.sort()
	for i in range(indices_to_remove.size() - 1, -1, -1):
		GameManager.player_data.remove_from_hand_at(indices_to_remove[i])

	var gold := int(result.get("gold_reward", 0))
	if gold > 0:
		GameManager.player_data.add_gold(gold)

	var deck_data: Dictionary = result.get("deck", {})
	if not deck_data.is_empty():
		DeckSystem.add_synthesized_deck(deck_data)

	GameManager.player_data.changed.emit()

# ══════════════════════════════════════════════════
#  卡池双击 → 移入手牌
# ══════════════════════════════════════════════════

func _on_card_pool_double_click(card: CardInfo, slot_index: int) -> void:
	if card == null:
		return
	var target_index := _first_empty_hand_slot()
	if target_index < 0:
		CardPoolSystem.refresh_failed.emit(Localization.t("error.card.hand_full"))
		return
	AudioManager.play_sfx("card_move")
	DragSystem.play_quick_move_animation(card, "pool", slot_index, "hand", target_index)
	CardPoolSystem.quick_move_to_hand(card, target_index)

# ══════════════════════════════════════════════════
#  手牌双击 → 移回卡池
# ══════════════════════════════════════════════════

func _on_hand_double_click(card: CardInfo, slot_index: int) -> void:
	if card == null:
		return
	var target_index := _first_empty_pool_slot()
	if target_index < 0:
		CardPoolSystem.refresh_failed.emit(Localization.t("error.card.pool_full"))
		return
	AudioManager.play_sfx("card_move")
	DragSystem.play_quick_move_animation(card, "hand", slot_index, "pool", target_index)
	CardPoolSystem.quick_move_from_hand_to_pool(card, slot_index)

func _first_empty_hand_slot() -> int:
	if _hand_area_ui == null:
		return -1
	var hand_cards := GameManager.player_data.hand_cards
	var target_index := -1
	for index in range(GameManager.player_data.hand_slots):
		if index >= hand_cards.size() or hand_cards[index] == null:
			target_index = index
			break
	if target_index < 0:
		return -1
	var target_page := floori(float(target_index) / float(_hand_area_ui.slot_count))
	if target_page != _hand_area_ui.current_page:
		_hand_area_ui.current_page = target_page
		_hand_area_ui.refresh_display()
	return target_index

func _first_empty_pool_slot() -> int:
	for index in range(GameManager.player_data.pool_slots):
		if index >= CardPoolSystem.current_pool.size() or CardPoolSystem.current_pool[index] == null:
			return index
	return -1

func _on_scene_changed(scene_name: String) -> void:
	match scene_name:
		"CardPool": _show_card_pool()
		"Vault": _show_vault()
		"Main": _show_card_pool()

func _clear_center() -> void:
	for child in _center_area.get_children():
		_center_area.remove_child(child)
		child.queue_free()
	_today_decks_ui = null
	_card_pool_ui = null
	_hand_area_ui = null
	_vault_ui = null
	_synthesis_panel = null
	_deck_collection_ui = null

func refresh_current_view() -> void:
	_clear_center()
	_show_card_pool()

# ══════════════════════════════════════════════════
#  调试面板
# ══════════════════════════════════════════════════

func _setup_debug_panel() -> void:
	var debug = Control.new()
	debug.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	debug.position = Vector2(130, -120)
	debug.size = Vector2(300, 100)

	var panel = Panel.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	debug.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(vbox)

	var add_gold = Button.new()
	add_gold.text = "+100 金币"
	add_gold.pressed.connect(func(): GameManager.player_data.add_gold(100))
	vbox.add_child(add_gold)

	var add_gems = Button.new()
	add_gems.text = "+10 宝石"
	add_gems.pressed.connect(func(): GameManager.player_data.add_gems(10))
	vbox.add_child(add_gems)

	var add_exp = Button.new()
	add_exp.text = "+500 经验"
	add_exp.pressed.connect(func(): GameManager.on_exp_gained(500))
	vbox.add_child(add_exp)

	var sync_btn = Button.new()
	sync_btn.text = "🔄 从服务器同步"
	sync_btn.pressed.connect(func():
		await GameManager.sync_all_from_server()
		print("[DEBUG] 数据已同步")
	)
	vbox.add_child(sync_btn)

	add_child(debug)

	# 菜单按钮（因为导航中去掉了菜单项，在调试面板加一个）
	var menu_btn = Button.new()
	menu_btn.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	menu_btn.position = Vector2(130, -80)
	menu_btn.size = Vector2(80, 36)
	menu_btn.text = "菜单"
	menu_btn.pressed.connect(_show_menu)
	debug.add_child(menu_btn)
