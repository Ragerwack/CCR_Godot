extends Control
class_name MainUI

@export var enable_debug: bool = false

const TodayDecksUIScript = preload("res://Scripts/UI/TodayDecksUI.gd")
const LevelUpPopupUIScript = preload("res://Scripts/UI/LevelUpPopupUI.gd")
const SynthesisAnimationOverlayScript = preload("res://Scripts/UI/SynthesisAnimationOverlay.gd")
const CCRVisualStyle = preload("res://Scripts/UI/CCRVisualStyle.gd")
const MAIN_BACKGROUND_PATH := "res://Resources/Backgrounds/main_background.png"

const LEFT_PANEL_WIDTH: int = 120
const TOP_BAR_HEIGHT: int = 90
const EXP_BAR_RATIO: float = 0.024   # 接近 MMORPG 底部细经验条的屏占比
const EXP_BAR_MIN_HEIGHT: int = 16
const EXP_BAR_MAX_HEIGHT: int = 24
const CARD_SLOT_HEIGHT_RATIO: float = 0.21

var _player_info: PlayerInfoUI
var _currency: CurrencyUI
var _nav_buttons: NavButtons
var _center_area: Control
var _exp_bar_ui: ExpBarUI
var _menu_button: Button = null
var _level_up_popup: Control = null
var _main_background: TextureRect = null
var _reconnect_overlay: Control = null

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
		return
	if is_instance_valid(_level_up_popup):
		_level_up_popup.queue_free()
	_level_up_popup = LevelUpPopupUIScript.new()
	_level_up_popup.setup(level, rewards)
	_level_up_popup.dismissed.connect(func(): _level_up_popup = null)
	add_child(_level_up_popup)

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

# ══════════════════════════════════════════════════
#  UI 搭建
# ══════════════════════════════════════════════════

func setup_ui() -> void:
	var vp_size = get_viewport_rect().size
	var exp_bar_h = clampi(int(vp_size.y * EXP_BAR_RATIO), EXP_BAR_MIN_HEIGHT, EXP_BAR_MAX_HEIGHT)
	_configure_card_slot_size(vp_size)

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
	_player_info.position = Vector2(10, 10)
	_player_info.size = Vector2(LEFT_PANEL_WIDTH, 130)
	add_child(_player_info)

	_currency = CurrencyUI.new()
	_currency.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	# 体力、金币、宝石并排显示，位于菜单按钮左侧。
	_currency.offset_left = -285
	_currency.offset_right = -55   # -(50 菜单宽 + 5 间距)
	_currency.offset_top = 10
	_currency.offset_bottom = 46   # 10 + 36 高（单行）
	add_child(_currency)

	# ── 左侧导航 ──
	_nav_buttons = NavButtons.new()
	_nav_buttons.set_anchors_preset(Control.PRESET_TOP_LEFT)
	# 导航栏占满左侧栏从 TOP_BAR_HEIGHT 到底部经验条上方，内部按钮垂直居中
	_nav_buttons.offset_left = 0
	_nav_buttons.offset_right = LEFT_PANEL_WIDTH
	_nav_buttons.offset_top = TOP_BAR_HEIGHT
	_nav_buttons.offset_bottom = vp_size.y - exp_bar_h
	add_child(_nav_buttons)

	# ── 中央内容区（无右侧面板，全宽） ──
	_center_area = Control.new()
	_center_area.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_center_area.position = Vector2(LEFT_PANEL_WIDTH, 0)
	_center_area.size = Vector2(vp_size.x - LEFT_PANEL_WIDTH, vp_size.y - exp_bar_h)
	_center_area.name = "CenterArea"
	add_child(_center_area)

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
	var exp_bar_h := clampi(int(vp_size.y * EXP_BAR_RATIO), EXP_BAR_MIN_HEIGHT, EXP_BAR_MAX_HEIGHT)
	_configure_card_slot_size(vp_size)
	if is_instance_valid(_nav_buttons):
		_nav_buttons.offset_left = 0
		_nav_buttons.offset_right = LEFT_PANEL_WIDTH
		_nav_buttons.offset_top = TOP_BAR_HEIGHT
		_nav_buttons.offset_bottom = vp_size.y - exp_bar_h
	if is_instance_valid(_center_area):
		_center_area.position = Vector2(LEFT_PANEL_WIDTH, 0)
		_center_area.size = Vector2(vp_size.x - LEFT_PANEL_WIDTH, vp_size.y - exp_bar_h)
	if is_instance_valid(_exp_bar_ui):
		_exp_bar_ui.offset_top = -exp_bar_h

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
	var available_width := maxf(320.0, vp_size.x - LEFT_PANEL_WIDTH - 64.0)
	var max_slot_width := maxf(1.0, (available_width - 7.0 * 8.0) / 8.0)
	var slot_h := minf(slot_h_by_height, max_slot_width / aspect)
	var slot_size := Vector2(roundf(slot_h * aspect), roundf(slot_h))
	CardSlotUI.configure_slot_size(slot_size)

# ══════════════════════════════════════════════════
#  导航
# ══════════════════════════════════════════════════

func _on_nav_button(id: String) -> void:
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
	_card_pool_ui.card_double_clicked.connect(_on_card_pool_double_click)

	_hand_area_ui = HandAreaUI.new()
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
	_today_decks_ui = TodayDecksUIScript.new()
	_today_decks_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_center_area.add_child(_today_decks_ui)
	_apply_game_text_color(_center_area)

func _sync_before_leaving_card_pool() -> Dictionary:
	if _card_pool_ui == null and _hand_area_ui == null:
		return {"success": true}
	return await GameManager.sync_pool_hand_layout()

func _show_vault() -> void:
	_current_view_id = "vault"
	_nav_buttons.select_by_id("vault")
	_clear_center()
	_vault_ui = VaultUI.new()
	_vault_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	if is_instance_valid(_nav_buttons):
		_vault_ui.set_synthesis_nav_target_rect(_nav_buttons.get_button_global_rect("deck_panel"))
	_center_area.add_child(_vault_ui)
	_apply_game_text_color(_center_area)

func _show_deck_collection() -> void:
	_current_view_id = "deck_panel"
	_nav_buttons.select_by_id("deck_panel")
	_clear_center()
	_deck_collection_ui = DeckCollectionUI.new()
	_deck_collection_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_center_area.add_child(_deck_collection_ui)
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

func _build_menu_panel() -> Control:
	var panel = Control.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.size = Vector2(520, 620)
	vbox.position = -vbox.size / 2.0
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	var title = Label.new()
	title.text = Localization.t("ui.menu.title")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	vbox.add_child(title)

	var music_row = _make_slider_row(Localization.t("ui.menu.music_volume"), AudioManager.bgm_volume, func(v): AudioManager.set_bgm_volume(v))
	vbox.add_child(music_row)

	var sfx_row = _make_slider_row(Localization.t("ui.menu.sfx_volume"), AudioManager.sfx_volume, func(v): AudioManager.set_sfx_volume(v))
	vbox.add_child(sfx_row)

	var resolution_row := HBoxContainer.new()
	var resolution_label := Label.new()
	resolution_label.text = Localization.t("ui.menu.resolution")
	resolution_label.custom_minimum_size = Vector2(120, 30)
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
	resolution_select.item_selected.connect(func(index: int):
		var selected_resolution: Vector2i = resolution_select.get_item_metadata(index)
		DisplaySettings.apply_resolution(selected_resolution, true)
	)
	resolution_row.add_child(resolution_select)
	vbox.add_child(resolution_row)

	var language_row := HBoxContainer.new()
	var language_label := Label.new()
	language_label.text = Localization.t("ui.menu.language")
	language_label.custom_minimum_size = Vector2(120, 30)
	language_row.add_child(language_label)
	var language_select := OptionButton.new()
	language_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	language_select.add_item(Localization.t("ui.language.en"))
	language_select.set_item_metadata(0, "en")
	language_select.add_item(Localization.t("ui.language.zh_cn"))
	language_select.set_item_metadata(1, "zh-CN")
	language_select.select(1 if Localization.locale == "zh-CN" else 0)
	language_select.item_selected.connect(func(index: int):
		var selected_locale := str(language_select.get_item_metadata(index))
		_apply_language_selection.call_deferred(selected_locale)
	)
	language_row.add_child(language_select)
	vbox.add_child(language_row)

	var controller_sep = HSeparator.new()
	vbox.add_child(controller_sep)

	var controller_title := Label.new()
	controller_title.text = Localization.t("ui.controller.title")
	controller_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controller_title.add_theme_font_size_override("font_size", 18)
	vbox.add_child(controller_title)

	for action_id in ControllerInput.get_action_ids():
		vbox.add_child(_make_controller_binding_row(action_id))

	var reset_controller_btn := Button.new()
	reset_controller_btn.text = Localization.t("ui.controller.reset")
	reset_controller_btn.pressed.connect(func():
		ControllerInput.reset_bindings()
		_show_settings()
	)
	vbox.add_child(reset_controller_btn)

	var mute_btn = Button.new()
	mute_btn.text = Localization.t("ui.menu.mute") if not AudioManager.is_muted else Localization.t("ui.menu.muted")
	mute_btn.pressed.connect(func():
		AudioManager.toggle_mute()
		mute_btn.text = Localization.t("ui.menu.mute") if not AudioManager.is_muted else Localization.t("ui.menu.muted")
	)
	vbox.add_child(mute_btn)

	var sep = HSeparator.new()
	vbox.add_child(sep)

	var logout_btn = Button.new()
	logout_btn.text = Localization.t("ui.menu.logout")
	logout_btn.pressed.connect(_on_logout_pressed)
	vbox.add_child(logout_btn)

	return panel

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
	slider.value = default_val
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
	for child in target.get_children():
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
	var animation_sources := _hand_area_ui.get_synthesis_animation_sources(selected_indices)

	var old_pool_cards: Array = CardPoolSystem.current_pool.duplicate()
	if old_pool_cards.is_empty() and not GameManager.player_data.pool_cards.is_empty():
		old_pool_cards = GameManager.player_data.pool_cards.duplicate()
	var old_hand_cards: Array = GameManager.player_data.hand_cards.duplicate()

	_synthesis_animation_running = true
	_hand_area_ui.hide_synthesis_slots_for_animation(selected_indices)
	await _play_hand_synthesis_animation(animation_sources)
	_synthesis_animation_running = false

	_apply_hand_synthesis_pending_removal(selected_indices)
	if is_instance_valid(_hand_area_ui):
		_hand_area_ui.clear_selection()
		_hand_area_ui.refresh_display()

	_confirm_hand_synthesis_background(
		selected_indices.duplicate(),
		old_pool_cards,
		old_hand_cards
	)

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

func _confirm_hand_synthesis_background(selected_indices: Array, old_pool_cards: Array, old_hand_cards: Array) -> void:
	var sync_resp := await ApiClient.sync_pool_hand_layout(old_pool_cards, old_hand_cards)
	if not sync_resp.get("success", false):
		push_error("合成前同步失败: ", sync_resp.get("error", ""))
		await _recover_after_synthesis_failure()
		return

	var resp := await ApiClient.synthesize(selected_indices, "hand")
	if resp.get("success", false):
		_apply_synthesis_confirmed_result(resp.get("data", {}))
		_sync_after_synthesis_success_background()
	else:
		push_error("合成失败: ", resp.get("error", ""))
		await _recover_after_synthesis_failure()

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
		GameManager.apply_exp_result(exp_result)

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

	_hand_action_animation_running = true
	await _play_hand_card_discard_animation(animation_source)
	_hand_action_animation_running = false

	if not ApiClient.is_logged_in():
		hand_cards[idx] = null
		GameManager.player_data.changed.emit()
		if is_instance_valid(_hand_area_ui):
			_hand_area_ui.clear_selection()
			_hand_area_ui.refresh_display()
		return

	hand_cards[idx] = null
	GameManager.player_data.changed.emit()
	if is_instance_valid(_hand_area_ui):
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

	if not ApiClient.is_logged_in():
		# 找第一个空保险箱槽
		if vault_idx < 0:
			print("保险箱已满")
			return

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
			_hand_area_ui.clear_selection()
			_hand_area_ui.refresh_display()
		return

	if vault_idx < 0:
		print("保险箱已满，请先购买保险箱槽位")
		return

	_hand_action_animation_running = true
	await _play_hand_card_store_animation(animation_source)
	_hand_action_animation_running = false

	var old_pool_cards: Array = CardPoolSystem.current_pool.duplicate(true)
	if old_pool_cards.is_empty() and not GameManager.player_data.pool_cards.is_empty():
		old_pool_cards = GameManager.player_data.pool_cards.duplicate(true)
	var old_hand_cards: Array = hand_cards.duplicate(true)
	var old_vault_cards: Array = vault_cards.duplicate(true)

	hand_cards[source_idx] = null
	while vault_cards.size() <= vault_idx:
		vault_cards.append(null)
	vault_cards[vault_idx] = card
	GameManager.player_data.changed.emit()
	if is_instance_valid(_hand_area_ui):
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
	if not ApiClient.is_logged_in():
		CardPoolSystem.quick_move_to_hand(card)
		return
	CardPoolSystem.quick_move_to_hand(card)

# ══════════════════════════════════════════════════
#  手牌双击 → 移回卡池
# ══════════════════════════════════════════════════

func _on_hand_double_click(card: CardInfo, slot_index: int) -> void:
	if card == null:
		return
	CardPoolSystem.quick_move_from_hand_to_pool(card, slot_index)

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
