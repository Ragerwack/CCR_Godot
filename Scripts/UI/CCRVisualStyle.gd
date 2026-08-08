extends RefCounted
class_name CCRVisualStyle

const TEXT_DARK := Color(0.075, 0.095, 0.125, 1.0)
const TEXT_DARK_MUTED := Color(0.20, 0.235, 0.28, 1.0)
const TEXT_DARK_GOLD := Color(0.42, 0.315, 0.08, 1.0)
const TEXT_ERROR := Color(0.70, 0.08, 0.08, 1.0)
const CARD_SHADOW := Color(0.0, 0.0, 0.0, 0.36)
const RELIC_SHADOW := Color(0.0, 0.0, 0.0, 0.42)
const SETTINGS_PANEL_DARK := Color(0.055, 0.052, 0.047, 0.94)
const SETTINGS_PANEL_INSET := Color(0.075, 0.073, 0.067, 0.96)
const SETTINGS_CONTROL_DARK := Color(0.038, 0.039, 0.038, 0.98)
const SETTINGS_CONTROL_PRESSED := Color(0.025, 0.024, 0.022, 1.0)
const SETTINGS_DISABLED := Color(0.19, 0.19, 0.18, 0.78)
const SETTINGS_BRASS := Color(0.72, 0.52, 0.27, 1.0)
const SETTINGS_BRASS_DARK := Color(0.34, 0.235, 0.11, 1.0)
const SETTINGS_ROSE_GOLD := Color(0.86, 0.70, 0.48, 1.0)
const SETTINGS_BLUE_FOCUS := Color(0.48, 0.82, 1.0, 1.0)
const SETTINGS_TEXT := Color(0.94, 0.84, 0.64, 1.0)
const SETTINGS_TEXT_HOVER := Color(0.90, 0.97, 1.0, 1.0)
const SETTINGS_TEXT_DISABLED := Color(0.58, 0.57, 0.54, 0.86)
const RELIC_BUTTON_NAV_TEXT := Color(0.96, 0.88, 0.69, 1.0)
const RELIC_BUTTON_HOVER_TEXT := Color.WHITE
const RELIC_BUTTON_VAULT_TEXT := RELIC_BUTTON_NAV_TEXT
const RELIC_BUTTON_DISABLED_TEXT := Color(0.56, 0.57, 0.59, 0.92)
const BUTTON_ICON_NODE_NAME := "CCRButtonIcon"
const BUTTON_TEXT_LABEL_NODE_NAME := "CCRButtonTextLabel"
const BUTTON_CAPTION_META := "ccr_vertical_caption_text"
const BUTTON_CAPTION_HOVER_META := "ccr_vertical_caption_hovered"
const BUTTON_CAPTION_HOVER_COLOR_META := "ccr_vertical_caption_hover_color"
const BUTTON_ICON_HOVER_SCALE_META := "ccr_icon_hover_scale"
const SETTINGS_TOGGLE_KNOB_NODE_NAME := "CCRSettingsToggleKnob"
const SETTINGS_HORIZONTAL_SCROLLBAR_TRACK_NODE_NAME := "CCRHorizontalScrollbarTrack"
const SETTINGS_HORIZONTAL_SCROLLBAR_THUMB_NODE_NAME := "CCRHorizontalScrollbarThumb"
const SETTINGS_VERTICAL_SCROLLBAR_TRACK_NODE_NAME := "CCRVerticalScrollbarTrack"
const SETTINGS_VERTICAL_SCROLLBAR_THUMB_NODE_NAME := "CCRVerticalScrollbarThumb"
const SETTINGS_DROPDOWN_SCROLLBAR_THUMB_NODE_NAME := "CCRDropdownScrollThumb"
const SETTINGS_DROPDOWN_SIZE := Vector2i(340, 60)
const SETTINGS_DROPDOWN_TEXT_RATIO := 0.80
const SETTINGS_DROPDOWN_RIGHT_WIDTH := 68
const SETTINGS_DROPDOWN_PANEL_CONTENT_MARGIN := 14.0
const SETTINGS_POPUP_HOVER_HEIGHT := 44
const SETTINGS_POPUP_DIVIDER_START_X := 268
const SETTINGS_POPUP_DIVIDER_END_X := 272
const SETTINGS_POPUP_PANEL_EDGE := 8
const SETTINGS_POPUP_HEIGHT_2_ITEMS := 96
const SETTINGS_POPUP_HEIGHT_5_ITEMS := 194
const SETTINGS_POPUP_HEIGHT_15_ITEMS := 500
const SETTINGS_POPUP_SELECTED_ICON_SIZE := 16
const SETTINGS_VERTICAL_SCROLLBAR_TRACK_END_MARGIN := 78
const BUTTON_ICON_HOVER_SCALE := 1.5
const VAULT_ACTION_BUTTON_ICON_HOVER_SCALE := 1.25
const BUTTON_ICON_HOVER_SECONDS := 0.4
const DIALOG_PANEL_PATH := "res://Resources/UI/Dialogs/ExitGame/exit_dialog_panel.png"
const DIALOG_CONFIRM_BUTTON_PATH := "res://Resources/UI/Dialogs/ExitGame/exit_dialog_confirm_button.png"
const DIALOG_CANCEL_BUTTON_PATH := "res://Resources/UI/Dialogs/ExitGame/exit_dialog_cancel_button.png"
const DIALOG_PANEL_SIZE := Vector2(960, 394)
const SETTINGS_PANEL_PATH := "res://Resources/UI/Settings/RelicPanel/settings_panel_scheme_c.png"
const SETTINGS_CONTROL_ROOT := "res://Resources/UI/Settings/Controls/"

static var _settings_popup_panel_texture_cache: Dictionary = {}
static var _settings_popup_selected_icon_cache: Dictionary = {}
static var _settings_scaled_texture_cache: Dictionary = {}
static var _settings_checkbox_checked_hover_cache: Dictionary = {}

const BUTTON_TEXTURE_PATHS := {
	"navigation": {
		"normal": "res://Resources/UI/Buttons/BlackTitanium/Navigation/button_normal.png",
		"hover": "res://Resources/UI/Buttons/BlackTitanium/Navigation/button_hover.png",
		"pressed": "res://Resources/UI/Buttons/BlackTitanium/Navigation/button_pressed.png",
		"disabled": "res://Resources/UI/Buttons/BlackTitanium/Navigation/button_disabled.png",
	},
	"action": {
		"normal": "res://Resources/UI/Buttons/BlackTitanium/Action/button_normal.png",
		"hover": "res://Resources/UI/Buttons/BlackTitanium/Action/button_hover.png",
		"pressed": "res://Resources/UI/Buttons/BlackTitanium/Action/button_pressed.png",
		"disabled": "res://Resources/UI/Buttons/BlackTitanium/Action/button_disabled.png",
	},
	"vault_action": {
		"normal": "res://Resources/UI/Buttons/BlackTitanium/VaultAction/button_normal.png",
		"hover": "res://Resources/UI/Buttons/BlackTitanium/VaultAction/button_hover.png",
		"pressed": "res://Resources/UI/Buttons/BlackTitanium/VaultAction/button_pressed.png",
		"disabled": "res://Resources/UI/Buttons/BlackTitanium/VaultAction/button_disabled.png",
	},
}

const ICON_PATHS := {
	"nav_today_decks": "res://Resources/UI/Icons/Navigation/nav_today_decks.png",
	"nav_card_pool": "res://Resources/UI/Icons/Navigation/nav_card_pool.png",
	"nav_vault": "res://Resources/UI/Icons/Navigation/nav_vault.png",
	"nav_museum": "res://Resources/UI/Icons/Navigation/nav_museum.png",
	"nav_auction": "res://Resources/UI/Icons/Navigation/nav_auction.png",
	"nav_leaderboard": "res://Resources/UI/Icons/Navigation/nav_leaderboard.png",
	"nav_mail": "res://Resources/UI/Icons/Navigation/nav_mail.png",
	"nav_settings": "res://Resources/UI/Icons/Navigation/nav_settings.png",
	"nav_exit": "res://Resources/UI/Icons/Navigation/nav_exit.png",
	"draw_stamina": "res://Resources/UI/Icons/Draw/draw_stamina.png",
	"draw_gold": "res://Resources/UI/Icons/Draw/draw_gold.png",
	"draw_gem": "res://Resources/UI/Icons/Draw/draw_gem.png",
	"action_page": "res://Resources/UI/Icons/CardActions/action_page.png",
	"action_synthesize": "res://Resources/UI/Icons/CardActions/action_synthesize.png",
	"action_discard": "res://Resources/UI/Icons/CardActions/action_discard.png",
	"action_store_vault": "res://Resources/UI/Icons/CardActions/action_store_vault.png",
	"vault_organize": "res://Resources/UI/Icons/Vault/vault_organize.png",
	"vault_synthesize": "res://Resources/UI/Icons/Vault/vault_synthesize.png",
	"vault_expand_gold": "res://Resources/UI/Icons/Vault/vault_expand_gold.png",
	"vault_expand_gem": "res://Resources/UI/Icons/Vault/vault_expand_gem.png",
	"status_stamina": "res://Resources/UI/Icons/Status/status_stamina.png",
	"status_gold": "res://Resources/UI/Icons/Status/status_gold.png",
	"status_gem": "res://Resources/UI/Icons/Status/status_gem.png",
	"status_roll_green": "res://Resources/UI/Icons/Status/status_roll_green.png",
	"status_roll_yellow": "res://Resources/UI/Icons/Status/status_roll_yellow.png",
	"status_roll_red": "res://Resources/UI/Icons/Status/status_roll_red.png",
	"status_level": "res://Resources/UI/Icons/Status/status_level.png",
	"status_combat_power": "res://Resources/UI/Icons/Status/status_combat_power.png",
	"status_experience": "res://Resources/UI/Icons/Status/status_experience.png",
	"status_lock": "res://Resources/UI/Icons/Status/status_lock.png",
	"career_archive": "res://Resources/UI/Icons/Career/career_archive.png",
	"career_acquired_date": "res://Resources/UI/Icons/Career/career_acquired_date.png",
	"career_companion_time": "res://Resources/UI/Icons/Career/career_companion_time.png",
	"career_level": "res://Resources/UI/Icons/Career/career_level.png",
	"career_gold": "res://Resources/UI/Icons/Career/career_gold.png",
	"career_combat_power": "res://Resources/UI/Icons/Career/career_combat_power.png",
	"career_relic_total": "res://Resources/UI/Icons/Career/career_relic_total.png",
}

static func apply_dark_label(label: Label, color: Color = TEXT_DARK) -> void:
	if label == null:
		return
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(1.0, 1.0, 1.0, 0.35))
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", 1)

static func make_dialog_panel_style(modulate_color: Color = Color.WHITE) -> StyleBoxTexture:
	return make_dialog_texture_style(DIALOG_PANEL_PATH, Vector2(96, 42), modulate_color)

static func make_dialog_texture_style(texture_path: String, margin: Vector2, modulate_color: Color = Color.WHITE) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = load(texture_path) as Texture2D
	style.texture_margin_left = margin.x
	style.texture_margin_right = margin.x
	style.texture_margin_top = margin.y
	style.texture_margin_bottom = margin.y
	style.content_margin_left = 6.0
	style.content_margin_right = 6.0
	style.content_margin_top = 2.0
	style.content_margin_bottom = 2.0
	style.modulate_color = modulate_color
	return style

static func apply_settings_panel(panel: Panel) -> void:
	if panel == null:
		return
	var style := StyleBoxTexture.new()
	style.texture = load(SETTINGS_PANEL_PATH) as Texture2D
	style.texture_margin_left = 96.0
	style.texture_margin_right = 96.0
	style.texture_margin_top = 76.0
	style.texture_margin_bottom = 76.0
	style.content_margin_left = 64.0
	style.content_margin_right = 64.0
	style.content_margin_top = 52.0
	style.content_margin_bottom = 52.0
	panel.add_theme_stylebox_override("panel", style)

static func apply_settings_content_panel(panel: Panel) -> void:
	if panel == null:
		return
	var style := _make_flat_style(
		SETTINGS_PANEL_INSET,
		SETTINGS_BRASS_DARK,
		1,
		6,
		Vector2(0, 5),
		Color(0.0, 0.0, 0.0, 0.22),
		8
	)
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 12.0
	style.content_margin_bottom = 12.0
	panel.add_theme_stylebox_override("panel", style)

static func apply_settings_label(label: Label, muted: bool = false) -> void:
	if label == null:
		return
	label.add_theme_color_override("font_color", Color(0.84, 0.72, 0.51, 0.96) if muted else SETTINGS_TEXT)
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.72))
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", 1)

static func apply_settings_button(button: Button, active: bool = false, destructive: bool = false) -> void:
	if button == null:
		return
	var normal_texture := "line_edit_focus.png" if active else "line_edit_normal.png"
	button.add_theme_stylebox_override("normal", _make_settings_texture_style(normal_texture, 36, 28, 36, 28, 14, 14, 7, 7))
	button.add_theme_stylebox_override("hover", _make_settings_texture_style("line_edit_focus.png", 38, 30, 38, 30, 14, 14, 7, 7))
	button.add_theme_stylebox_override("pressed", _make_settings_texture_style("line_edit_pressed.png", 38, 28, 38, 28, 14, 14, 8, 5))
	button.add_theme_stylebox_override("hover_pressed", _make_settings_texture_style("line_edit_pressed.png", 38, 28, 38, 28, 14, 14, 8, 5))
	button.add_theme_stylebox_override("disabled", _make_settings_texture_style("line_edit_disabled.png", 36, 28, 36, 28, 14, 14, 7, 7))
	button.add_theme_stylebox_override("focus", _make_settings_texture_style("line_edit_focus.png", 38, 30, 38, 30, 14, 14, 7, 7))
	button.add_theme_color_override("font_color", SETTINGS_TEXT if not active else SETTINGS_TEXT_HOVER)
	button.add_theme_color_override("font_hover_color", SETTINGS_TEXT_HOVER)
	button.add_theme_color_override("font_pressed_color", Color(1.0, 0.78, 0.48, 1.0))
	button.add_theme_color_override("font_hover_pressed_color", Color(1.0, 0.78, 0.48, 1.0))
	button.add_theme_color_override("font_focus_color", SETTINGS_TEXT_HOVER)
	button.add_theme_color_override("font_disabled_color", SETTINGS_TEXT_DISABLED)
	button.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.82))
	button.add_theme_constant_override("outline_size", 1)
	button.add_theme_constant_override("h_separation", 0)
	button.clip_text = true

static func apply_settings_dialog_button(button: Button, destructive: bool = false) -> void:
	if button == null:
		return
	var texture_path := DIALOG_CONFIRM_BUTTON_PATH if destructive else DIALOG_CANCEL_BUTTON_PATH
	button.add_theme_stylebox_override("normal", make_dialog_texture_style(texture_path, Vector2(52, 24), Color.WHITE))
	button.add_theme_stylebox_override("hover", make_dialog_texture_style(texture_path, Vector2(52, 24), Color(1.12, 1.12, 1.12, 1.0)))
	button.add_theme_stylebox_override("pressed", make_dialog_texture_style(texture_path, Vector2(52, 24), Color(0.84, 0.90, 0.95, 1.0)))
	button.add_theme_stylebox_override("hover_pressed", make_dialog_texture_style(texture_path, Vector2(52, 24), Color(0.84, 0.90, 0.95, 1.0)))
	button.add_theme_stylebox_override("disabled", make_dialog_texture_style(texture_path, Vector2(52, 24), Color(0.55, 0.58, 0.62, 0.78)))
	button.add_theme_stylebox_override("focus", make_dialog_texture_style(texture_path, Vector2(52, 24), Color(1.12, 1.12, 1.12, 1.0)))
	button.add_theme_color_override("font_color", SETTINGS_TEXT)
	button.add_theme_color_override("font_hover_color", SETTINGS_TEXT)
	button.add_theme_color_override("font_pressed_color", Color(1.0, 0.78, 0.48, 1.0))
	button.add_theme_color_override("font_hover_pressed_color", Color(1.0, 0.78, 0.48, 1.0))
	button.add_theme_color_override("font_focus_color", SETTINGS_TEXT)
	button.add_theme_color_override("font_disabled_color", SETTINGS_TEXT_DISABLED)
	button.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.90))
	button.add_theme_constant_override("outline_size", 2)
	button.add_theme_constant_override("h_separation", 0)
	button.clip_text = true

static func apply_settings_toggle_button(button: Button, active: bool) -> void:
	if button == null:
		return
	button.toggle_mode = true
	button.button_pressed = active
	# 布尔按钮底座的目标尺寸与最新切图等比；不得用九宫格压缩圆角和金属边框。
	button.add_theme_stylebox_override("normal", _make_settings_texture_style("toggle_base_focus.png" if active else "toggle_base_normal.png", 0, 0, 0, 0))
	button.add_theme_stylebox_override("hover", _make_settings_texture_style("toggle_base_focus.png", 0, 0, 0, 0))
	button.add_theme_stylebox_override("pressed", _make_settings_texture_style("toggle_base_pressed.png", 0, 0, 0, 0))
	button.add_theme_stylebox_override("hover_pressed", _make_settings_texture_style("toggle_base_pressed.png", 0, 0, 0, 0))
	button.add_theme_stylebox_override("disabled", _make_settings_texture_style("toggle_base_disabled.png", 0, 0, 0, 0))
	button.add_theme_stylebox_override("focus", _make_settings_texture_style("toggle_base_focus.png", 0, 0, 0, 0))
	button.icon = null
	button.add_theme_icon_override("icon", _make_empty_icon())
	button.add_theme_icon_override("icon_pressed", _make_empty_icon())
	button.add_theme_icon_override("icon_hover", _make_empty_icon())
	button.add_theme_icon_override("icon_disabled", _make_empty_icon())
	button.add_theme_color_override("font_color", SETTINGS_TEXT if not active else SETTINGS_TEXT_HOVER)
	button.add_theme_color_override("font_hover_color", SETTINGS_TEXT_HOVER)
	button.add_theme_color_override("font_pressed_color", Color(1.0, 0.78, 0.48, 1.0))
	button.add_theme_color_override("font_disabled_color", SETTINGS_TEXT_DISABLED)
	button.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.82))
	button.add_theme_constant_override("outline_size", 1)
	button.add_theme_constant_override("h_separation", 0)
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.expand_icon = false
	button.clip_text = true
	_ensure_settings_toggle_knob(button, active)

static func apply_settings_tab_button(button: Button, active: bool) -> void:
	if button == null:
		return
	button.add_theme_stylebox_override("normal", _make_settings_texture_style("line_edit_focus.png" if active else "line_edit_normal.png", 0, 0, 0, 0, 14, 14, 7, 7))
	button.add_theme_stylebox_override("hover", _make_settings_texture_style("line_edit_focus.png", 0, 0, 0, 0, 14, 14, 7, 7))
	button.add_theme_stylebox_override("pressed", _make_settings_texture_style("line_edit_pressed.png", 0, 0, 0, 0, 14, 14, 8, 5))
	button.add_theme_stylebox_override("hover_pressed", _make_settings_texture_style("line_edit_pressed.png", 0, 0, 0, 0, 14, 14, 8, 5))
	button.add_theme_stylebox_override("disabled", _make_settings_texture_style("line_edit_disabled.png", 0, 0, 0, 0, 14, 14, 7, 7))
	button.add_theme_stylebox_override("focus", _make_settings_texture_style("line_edit_focus.png", 0, 0, 0, 0, 14, 14, 7, 7))
	button.add_theme_color_override("font_color", SETTINGS_TEXT_HOVER if active else SETTINGS_TEXT)
	button.add_theme_color_override("font_hover_color", SETTINGS_TEXT_HOVER)
	button.add_theme_color_override("font_pressed_color", Color(1.0, 0.78, 0.48, 1.0))
	button.add_theme_color_override("font_disabled_color", SETTINGS_TEXT_DISABLED)
	button.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.82))
	button.add_theme_constant_override("outline_size", 1)
	button.clip_text = true

static func apply_settings_option_button(option: OptionButton) -> void:
	if option == null:
		return
	# ImageGen 素材就是最终 340x60；零切片且控件同尺寸，四角和箭头不会横向拉伸。
	option.custom_minimum_size = Vector2(SETTINGS_DROPDOWN_SIZE)
	option.add_theme_stylebox_override("normal", _make_settings_texture_style("dropdown_box_normal.png", 0, 0, 0, 0, 14, SETTINGS_DROPDOWN_RIGHT_WIDTH, 7, 7))
	option.add_theme_stylebox_override("hover", _make_settings_texture_style("dropdown_box_focus.png", 0, 0, 0, 0, 14, SETTINGS_DROPDOWN_RIGHT_WIDTH, 7, 7))
	option.add_theme_stylebox_override("pressed", _make_settings_texture_style("dropdown_box_pressed.png", 0, 0, 0, 0, 14, SETTINGS_DROPDOWN_RIGHT_WIDTH, 8, 5))
	option.add_theme_stylebox_override("hover_pressed", _make_settings_texture_style("dropdown_box_pressed.png", 0, 0, 0, 0, 14, SETTINGS_DROPDOWN_RIGHT_WIDTH, 8, 5))
	option.add_theme_stylebox_override("disabled", _make_settings_texture_style("dropdown_box_disabled.png", 0, 0, 0, 0, 14, SETTINGS_DROPDOWN_RIGHT_WIDTH, 7, 7))
	option.add_theme_stylebox_override("focus", _make_settings_texture_style("dropdown_box_focus.png", 0, 0, 0, 0, 14, SETTINGS_DROPDOWN_RIGHT_WIDTH, 7, 7))
	option.add_theme_color_override("font_color", SETTINGS_TEXT)
	option.add_theme_color_override("font_hover_color", SETTINGS_TEXT_HOVER)
	option.add_theme_color_override("font_pressed_color", Color(1.0, 0.78, 0.48, 1.0))
	option.add_theme_color_override("font_disabled_color", SETTINGS_TEXT_DISABLED)
	option.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.82))
	option.add_theme_constant_override("outline_size", 1)
	option.alignment = HORIZONTAL_ALIGNMENT_CENTER
	option.add_theme_icon_override("arrow", _make_empty_icon())
	var popup := option.get_popup()
	popup.set_meta("ccr_settings_dropdown_width", SETTINGS_DROPDOWN_SIZE.x)
	apply_settings_popup_menu(popup)
	# PopupMenu 是独立子窗口，不会继承设置页对 OptionButton 做的字号增量。
	popup.add_theme_font_size_override("font_size", option.get_theme_font_size("font_size"))
	_center_settings_popup_items(popup)

static func apply_settings_option_button_geometry(option: OptionButton, control_size: Vector2i, visual_height: int) -> void:
	if option == null:
		return
	var safe_size := Vector2i(maxi(1, control_size.x), maxi(1, control_size.y))
	var safe_visual_height := clampi(visual_height, 1, safe_size.y)
	option.custom_minimum_size = Vector2(safe_size)
	option.size = Vector2(safe_size)
	option.add_theme_stylebox_override("normal", _make_padded_settings_texture_style("dropdown_box_normal.png", safe_size, safe_visual_height, 14, SETTINGS_DROPDOWN_RIGHT_WIDTH, 7, 7))
	option.add_theme_stylebox_override("hover", _make_padded_settings_texture_style("dropdown_box_focus.png", safe_size, safe_visual_height, 14, SETTINGS_DROPDOWN_RIGHT_WIDTH, 7, 7))
	option.add_theme_stylebox_override("pressed", _make_padded_settings_texture_style("dropdown_box_pressed.png", safe_size, safe_visual_height, 14, SETTINGS_DROPDOWN_RIGHT_WIDTH, 8, 5))
	option.add_theme_stylebox_override("hover_pressed", _make_padded_settings_texture_style("dropdown_box_pressed.png", safe_size, safe_visual_height, 14, SETTINGS_DROPDOWN_RIGHT_WIDTH, 8, 5))
	option.add_theme_stylebox_override("disabled", _make_padded_settings_texture_style("dropdown_box_disabled.png", safe_size, safe_visual_height, 14, SETTINGS_DROPDOWN_RIGHT_WIDTH, 7, 7))
	option.add_theme_stylebox_override("focus", _make_padded_settings_texture_style("dropdown_box_focus.png", safe_size, safe_visual_height, 14, SETTINGS_DROPDOWN_RIGHT_WIDTH, 7, 7))
	var popup := option.get_popup()
	popup.set_meta("ccr_settings_dropdown_width", safe_size.x)
	apply_settings_popup_menu(popup)
	popup.add_theme_font_size_override("font_size", option.get_theme_font_size("font_size"))
	_configure_settings_popup_asset_and_size(popup)
	_center_settings_popup_items(popup)

static func apply_settings_popup_menu(popup: PopupMenu) -> void:
	if popup == null:
		return
	_configure_settings_popup_asset_and_size(popup)
	var target_width := int(popup.get_meta("ccr_settings_dropdown_width", SETTINGS_DROPDOWN_SIZE.x))
	popup.add_theme_stylebox_override("hover", _make_settings_popup_hover_style(target_width))
	popup.add_theme_stylebox_override("separator", _make_flat_style(Color(0.62, 0.47, 0.25, 0.55), Color.TRANSPARENT, 0, 0))
	popup.add_theme_color_override("font_color", SETTINGS_TEXT)
	popup.add_theme_color_override("font_hover_color", SETTINGS_TEXT_HOVER)
	popup.add_theme_color_override("font_disabled_color", SETTINGS_TEXT_DISABLED)
	popup.add_theme_color_override("font_outline_color", Color(0.025, 0.025, 0.023, 0.96))
	var selected_icon := _make_settings_popup_selected_icon(SETTINGS_TEXT)
	var selected_disabled_icon := _make_settings_popup_selected_icon(SETTINGS_TEXT_DISABLED)
	for icon_name in ["checked", "radio_checked"]:
		popup.add_theme_icon_override(icon_name, selected_icon)
	for icon_name in ["checked_disabled", "radio_checked_disabled"]:
		popup.add_theme_icon_override(icon_name, selected_disabled_icon)
	popup.add_theme_constant_override("outline_size", 2)
	popup.add_theme_constant_override("v_separation", 6)
	popup.add_theme_constant_override("h_separation", 8)
	popup.add_theme_constant_override("indent", 1)
	popup.add_theme_constant_override("item_start_padding", 14)
	popup.add_theme_constant_override("item_end_padding", SETTINGS_DROPDOWN_RIGHT_WIDTH)
	if not popup.has_meta("ccr_settings_popup_center_connected"):
		popup.set_meta("ccr_settings_popup_center_connected", true)
		popup.about_to_popup.connect(func():
			_configure_settings_popup_asset_and_size(popup)
			_center_settings_popup_items(popup)
			_configure_settings_popup_scrollbar.call_deferred(popup)
		)
	_center_settings_popup_items(popup)

static func _configure_settings_popup_asset_and_size(popup: PopupMenu) -> void:
	var item_count := popup.item_count
	var target_width := maxi(1, int(popup.get_meta("ccr_settings_dropdown_width", SETTINGS_DROPDOWN_SIZE.x)))
	var asset_name := "dropdown_menu_panel_5_items.png"
	var target_height := SETTINGS_POPUP_HEIGHT_5_ITEMS
	var has_embedded_scrollbar := false
	if item_count <= 2:
		asset_name = "dropdown_menu_panel_2_items.png"
		target_height = SETTINGS_POPUP_HEIGHT_2_ITEMS
	elif item_count <= 5:
		asset_name = "dropdown_menu_panel_5_items.png"
		target_height = SETTINGS_POPUP_HEIGHT_5_ITEMS
	elif item_count <= 15:
		asset_name = "dropdown_menu_panel_15_items.png"
		target_height = SETTINGS_POPUP_HEIGHT_15_ITEMS
	else:
		asset_name = "dropdown_menu_panel_region.png"
		target_height = int(popup.get_meta("ccr_settings_popup_height", 533))
		has_embedded_scrollbar = true
	popup.add_theme_stylebox_override("panel", _make_settings_popup_panel_style(asset_name, target_width, target_height, has_embedded_scrollbar))
	popup.min_size = Vector2i(target_width, target_height)
	popup.max_size = Vector2i(target_width, target_height)
	popup.shrink_width = false
	popup.shrink_height = false
	popup.set_meta("ccr_settings_popup_asset", asset_name)
	popup.set_meta("ccr_settings_popup_embedded_scrollbar", has_embedded_scrollbar)
	var divider_x := int(roundf(float(SETTINGS_POPUP_DIVIDER_END_X) * float(target_width) / float(SETTINGS_DROPDOWN_SIZE.x)))
	popup.set_meta("ccr_settings_popup_divider_x", divider_x)

static func _make_settings_popup_panel_style(asset_name: String, target_width: int, target_height: int, has_embedded_scrollbar: bool) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	var cache_key := "%s:%d:%d:%s" % [asset_name, target_width, target_height, str(has_embedded_scrollbar)]
	var texture := _settings_popup_panel_texture_cache.get(cache_key) as Texture2D
	if texture == null:
		var source_texture := _settings_texture(asset_name)
		var source_image := source_texture.get_image() if source_texture != null else null
		if source_image != null and not source_image.is_empty():
			var target_image := _resize_settings_popup_panel_image(source_image, target_height)
			if not has_embedded_scrollbar:
				_remove_settings_popup_embedded_scrollbar(target_image)
			else:
				_align_settings_popup_divider(target_image)
			if target_image.get_width() != target_width:
				target_image.resize(target_width, target_image.get_height(), Image.INTERPOLATE_LANCZOS)
			texture = ImageTexture.create_from_image(target_image)
			_settings_popup_panel_texture_cache[cache_key] = texture
	if texture == null:
		texture = _settings_texture(asset_name)
	style.texture = texture
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	return style

static func _resize_settings_popup_panel_image(source: Image, target_height: int) -> Image:
	var source_size := source.get_size()
	var safe_target_height := maxi(target_height, SETTINGS_POPUP_PANEL_EDGE * 2 + 1)
	var target := Image.create(source_size.x, safe_target_height, false, Image.FORMAT_RGBA8)
	var source_inner_height := maxi(1, source_size.y - SETTINGS_POPUP_PANEL_EDGE * 2)
	var target_inner_height := maxi(1, safe_target_height - SETTINGS_POPUP_PANEL_EDGE * 2)
	for y in range(safe_target_height):
		var source_y := y
		if y >= safe_target_height - SETTINGS_POPUP_PANEL_EDGE:
			source_y = source_size.y - (safe_target_height - y)
		elif y >= SETTINGS_POPUP_PANEL_EDGE:
			var ratio := float(y - SETTINGS_POPUP_PANEL_EDGE) / float(maxi(1, target_inner_height - 1))
			source_y = SETTINGS_POPUP_PANEL_EDGE + int(roundf(ratio * float(source_inner_height - 1)))
		target.blit_rect(source, Rect2i(0, clampi(source_y, 0, source_size.y - 1), source_size.x, 1), Vector2i(0, y))
	return target

static func _remove_settings_popup_embedded_scrollbar(image: Image) -> void:
	if image == null or image.is_empty():
		return
	var closed_texture := _settings_texture("dropdown_box_normal.png")
	var closed_image := closed_texture.get_image() if closed_texture != null else null
	var image_size := image.get_size()
	var right_inner_end := image_size.x - SETTINGS_POPUP_PANEL_EDGE - 1
	var clone_start_x := 205
	var clone_width := 48
	for y in range(SETTINGS_POPUP_PANEL_EDGE, image_size.y - SETTINGS_POPUP_PANEL_EDGE):
		for x in range(SETTINGS_POPUP_DIVIDER_END_X + 1, right_inner_end + 1):
			var source_x := clone_start_x + ((x - SETTINGS_POPUP_DIVIDER_END_X - 1) % clone_width)
			image.set_pixel(x, y, image.get_pixel(source_x, y))
		if closed_image != null and not closed_image.is_empty():
			var closed_inner_height := maxi(1, closed_image.get_height() - SETTINGS_POPUP_PANEL_EDGE * 2)
			var closed_y := SETTINGS_POPUP_PANEL_EDGE + ((y - SETTINGS_POPUP_PANEL_EDGE) % closed_inner_height)
			for x in range(SETTINGS_POPUP_DIVIDER_START_X, SETTINGS_POPUP_DIVIDER_END_X + 1):
				image.set_pixel(x, y, closed_image.get_pixel(x, closed_y))

static func _align_settings_popup_divider(image: Image) -> void:
	if image == null or image.is_empty():
		return
	var closed_texture := _settings_texture("dropdown_box_normal.png")
	var closed_image := closed_texture.get_image() if closed_texture != null else null
	if closed_image == null or closed_image.is_empty():
		return
	var clear_end_x := mini(image.get_width() - SETTINGS_POPUP_PANEL_EDGE - 1, SETTINGS_POPUP_DIVIDER_END_X + 10)
	var clone_start_x := SETTINGS_POPUP_DIVIDER_START_X - 28
	var closed_inner_height := maxi(1, closed_image.get_height() - SETTINGS_POPUP_PANEL_EDGE * 2)
	for y in range(SETTINGS_POPUP_PANEL_EDGE, image.get_height() - SETTINGS_POPUP_PANEL_EDGE):
		for x in range(SETTINGS_POPUP_DIVIDER_START_X, clear_end_x + 1):
			image.set_pixel(x, y, image.get_pixel(clone_start_x + x - SETTINGS_POPUP_DIVIDER_START_X, y))
		var closed_y := SETTINGS_POPUP_PANEL_EDGE + ((y - SETTINGS_POPUP_PANEL_EDGE) % closed_inner_height)
		for x in range(SETTINGS_POPUP_DIVIDER_START_X, SETTINGS_POPUP_DIVIDER_END_X + 1):
			image.set_pixel(x, y, closed_image.get_pixel(x, closed_y))

static func _make_settings_popup_selected_icon(color: Color) -> Texture2D:
	var cache_key := color.to_html(true)
	var cached := _settings_popup_selected_icon_cache.get(cache_key) as Texture2D
	if cached != null:
		return cached
	var size := SETTINGS_POPUP_SELECTED_ICON_SIZE
	var center := Vector2(float(size - 1) * 0.5, float(size - 1) * 0.5)
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	for y in range(size):
		for x in range(size):
			var distance := Vector2(float(x), float(y)).distance_to(center)
			var alpha := 0.0
			if distance <= 3.0:
				alpha = 1.0
			elif distance >= 5.1 and distance <= 6.9:
				alpha = clampf(minf(distance - 5.1, 6.9 - distance) / 0.7, 0.0, 1.0)
			if alpha > 0.0:
				image.set_pixel(x, y, Color(color.r, color.g, color.b, color.a * alpha))
	var texture := ImageTexture.create_from_image(image)
	_settings_popup_selected_icon_cache[cache_key] = texture
	return texture

static func _make_settings_popup_hover_style(target_width: int = SETTINGS_DROPDOWN_SIZE.x) -> StyleBoxTexture:
	var safe_width := maxi(1, target_width)
	var texture_size := Vector2i(safe_width, SETTINGS_POPUP_HOVER_HEIGHT)
	var text_width := int(roundf(float(safe_width) * SETTINGS_DROPDOWN_TEXT_RATIO))
	var image := Image.create(texture_size.x, texture_size.y, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var fill_color := Color(0.10, 0.16, 0.18, 0.68)
	var border_color := Color(SETTINGS_BLUE_FOCUS.r, SETTINGS_BLUE_FOCUS.g, SETTINGS_BLUE_FOCUS.b, 0.96)
	var border_width := 2
	for y in range(border_width, texture_size.y - border_width):
		for x in range(border_width, text_width - border_width):
			image.set_pixel(x, y, fill_color)
	for i in range(border_width):
		for x in range(0, text_width):
			image.set_pixel(x, i, border_color)
			image.set_pixel(x, texture_size.y - 1 - i, border_color)
		for y in range(0, texture_size.y):
			image.set_pixel(i, y, border_color)
			image.set_pixel(text_width - 1 - i, y, border_color)
	var style := StyleBoxTexture.new()
	style.texture = ImageTexture.create_from_image(image)
	return style

static func _configure_settings_popup_scrollbar(popup: PopupMenu) -> void:
	var scrollbar := _find_internal_v_scrollbar(popup)
	if scrollbar == null or popup.item_count <= 15:
		return
	scrollbar.custom_minimum_size = Vector2(SETTINGS_DROPDOWN_RIGHT_WIDTH, 20)
	var empty_style := StyleBoxEmpty.new()
	scrollbar.add_theme_stylebox_override("scroll", empty_style)
	scrollbar.add_theme_stylebox_override("scroll_focus", empty_style)
	# 透明命中框与可见拨块同高；上下透明图标为面板里的固定箭头预留点击区。
	var grabber_hit_style := StyleBoxEmpty.new()
	grabber_hit_style.content_margin_top = 53.5
	grabber_hit_style.content_margin_bottom = 53.5
	for style_name in ["grabber", "grabber_highlight", "grabber_pressed"]:
		scrollbar.add_theme_stylebox_override(style_name, grabber_hit_style)
	for icon_name in ["increment", "increment_highlight", "decrement", "decrement_highlight"]:
		scrollbar.add_theme_icon_override(icon_name, _make_empty_icon(Vector2i(SETTINGS_DROPDOWN_RIGHT_WIDTH, 46)))
	var thumb := scrollbar.get_node_or_null(NodePath(SETTINGS_DROPDOWN_SCROLLBAR_THUMB_NODE_NAME)) as TextureRect
	if thumb == null:
		thumb = TextureRect.new()
		thumb.name = SETTINGS_DROPDOWN_SCROLLBAR_THUMB_NODE_NAME
		thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		thumb.z_index = 2
		scrollbar.add_child(thumb)
	thumb.texture = _settings_texture("dropdown_scroll_thumb_normal.png")
	if not scrollbar.has_meta("ccr_dropdown_scrollbar_layout_connected"):
		scrollbar.set_meta("ccr_dropdown_scrollbar_layout_connected", true)
		scrollbar.resized.connect(func(): _layout_settings_popup_scrollbar_thumb(scrollbar))
		scrollbar.value_changed.connect(func(_value: float): _layout_settings_popup_scrollbar_thumb(scrollbar))
		scrollbar.changed.connect(func(): _layout_settings_popup_scrollbar_thumb(scrollbar))
		scrollbar.mouse_entered.connect(func(): _set_settings_popup_scrollbar_state(scrollbar, "focus"))
		scrollbar.mouse_exited.connect(func(): _set_settings_popup_scrollbar_state(scrollbar, "normal"))
		scrollbar.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
				_set_settings_popup_scrollbar_state(scrollbar, "pressed" if event.pressed else "focus")
		)
	_layout_settings_popup_scrollbar_thumb.call_deferred(scrollbar)

static func _find_internal_v_scrollbar(root: Node) -> VScrollBar:
	for child in root.get_children(true):
		if child is VScrollBar:
			return child as VScrollBar
		var nested := _find_internal_v_scrollbar(child)
		if nested != null:
			return nested
	return null

static func _set_settings_popup_scrollbar_state(scrollbar: VScrollBar, state: String) -> void:
	var thumb := scrollbar.get_node_or_null(NodePath(SETTINGS_DROPDOWN_SCROLLBAR_THUMB_NODE_NAME)) as TextureRect
	if thumb == null:
		return
	var texture_state := state if state in ["normal", "focus", "disabled"] else "normal"
	# 当前资产没有 pressed 版本；拖动期间继续使用可见的 focus 纹理。
	if state == "pressed":
		texture_state = "focus"
	thumb.texture = _settings_texture("dropdown_scroll_thumb_%s.png" % texture_state)

static func _layout_settings_popup_scrollbar_thumb(scrollbar: VScrollBar) -> void:
	var thumb := scrollbar.get_node_or_null(NodePath(SETTINGS_DROPDOWN_SCROLLBAR_THUMB_NODE_NAME)) as TextureRect
	if thumb == null or thumb.texture == null:
		return
	var thumb_size := thumb.texture.get_size() * 0.44
	var scrollbar_size := scrollbar.size
	thumb.size = Vector2(minf(thumb_size.x, scrollbar_size.x), minf(thumb_size.y, scrollbar_size.y))
	thumb.custom_minimum_size = thumb.size
	var effective_max := maxf(scrollbar.min_value, scrollbar.max_value - scrollbar.page)
	var value_ratio := 0.0
	if effective_max > scrollbar.min_value:
		value_ratio = clampf((scrollbar.value - scrollbar.min_value) / (effective_max - scrollbar.min_value), 0.0, 1.0)
	var endpoint_margin := minf(46.0, maxf(0.0, (scrollbar_size.y - thumb.size.y) * 0.5))
	var travel_height := maxf(0.0, scrollbar_size.y - thumb.size.y - endpoint_margin * 2.0)
	thumb.position = Vector2(
		(scrollbar_size.x - thumb.size.x) * 0.5 + SETTINGS_DROPDOWN_PANEL_CONTENT_MARGIN,
		endpoint_margin + travel_height * value_ratio
	)

static func _center_settings_popup_items(popup: PopupMenu) -> void:
	if popup == null or popup.item_count == 0:
		return
	var popup_width := maxf(float(popup.size.x), float(popup.min_size.x))
	if popup_width <= 0.0:
		return
	var font := popup.get_theme_font("font")
	var font_size := popup.get_theme_font_size("font_size")
	var content_width := popup_width * SETTINGS_DROPDOWN_TEXT_RATIO
	var item_baseline_x := 32.0
	for index in range(popup.item_count):
		var text_width := font.get_string_size(popup.get_item_text(index), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var centered_start_x := maxf(item_baseline_x, (content_width - text_width) * 0.5)
		popup.set_item_indent(index, int(roundf(centered_start_x - item_baseline_x)))

static func apply_settings_line_edit(line_edit: LineEdit) -> void:
	if line_edit == null:
		return
	line_edit.custom_minimum_size.y = maxf(line_edit.custom_minimum_size.y, 60.0)
	line_edit.add_theme_stylebox_override("normal", _make_settings_texture_style("line_edit_normal.png", 0, 0, 0, 0, 18, 18, 10, 10))
	line_edit.add_theme_stylebox_override("focus", _make_settings_texture_style("line_edit_focus.png", 0, 0, 0, 0, 18, 18, 10, 10))
	line_edit.add_theme_stylebox_override("read_only", _make_settings_texture_style("line_edit_disabled.png", 0, 0, 0, 0, 18, 18, 10, 10))
	line_edit.add_theme_color_override("font_color", SETTINGS_TEXT)
	line_edit.add_theme_color_override("font_readonly_color", Color(0.84, 0.74, 0.55, 0.92))
	line_edit.add_theme_color_override("font_placeholder_color", Color(0.62, 0.55, 0.42, 0.78))
	line_edit.add_theme_color_override("caret_color", SETTINGS_BLUE_FOCUS)
	line_edit.add_theme_color_override("selection_color", Color(0.32, 0.61, 0.78, 0.38))

static func apply_settings_line_edit_height(line_edit: LineEdit, target_height: int) -> void:
	if line_edit == null:
		return
	var height := maxi(1, target_height)
	line_edit.custom_minimum_size.y = float(height)
	line_edit.add_theme_stylebox_override("normal", _make_scaled_settings_texture_style("line_edit_normal.png", height, 0, 0, 0, 0, 18, 18, 10, 10))
	line_edit.add_theme_stylebox_override("focus", _make_scaled_settings_texture_style("line_edit_focus.png", height, 0, 0, 0, 0, 18, 18, 10, 10))
	line_edit.add_theme_stylebox_override("read_only", _make_scaled_settings_texture_style("line_edit_disabled.png", height, 0, 0, 0, 0, 18, 18, 10, 10))

static func apply_settings_check_box(check_box: CheckBox) -> void:
	if check_box == null:
		return
	check_box.custom_minimum_size.y = maxf(check_box.custom_minimum_size.y, 36.0)
	check_box.add_theme_icon_override("unchecked", _settings_texture("checkbox_empty_icon.png"))
	check_box.add_theme_icon_override("unchecked_hover", _settings_texture("checkbox_focus_empty_icon.png"))
	check_box.add_theme_icon_override("unchecked_pressed", _settings_texture("checkbox_focus_empty_icon.png"))
	check_box.add_theme_icon_override("unchecked_disabled", _settings_texture("checkbox_disabled_checked_icon.png"))
	check_box.add_theme_icon_override("checked", _settings_texture("checkbox_checked_icon.png"))
	check_box.add_theme_icon_override("checked_hover", _settings_checkbox_checked_hover_icon())
	check_box.add_theme_icon_override("checked_pressed", _settings_checkbox_checked_hover_icon())
	check_box.add_theme_icon_override("checked_disabled", _settings_texture("checkbox_disabled_checked_icon.png"))
	check_box.add_theme_stylebox_override("focus", _make_settings_focus_style(6))
	check_box.add_theme_color_override("font_color", SETTINGS_TEXT)
	check_box.add_theme_color_override("font_hover_color", SETTINGS_TEXT_HOVER)
	check_box.add_theme_color_override("font_pressed_color", Color(1.0, 0.78, 0.48, 1.0))
	check_box.add_theme_color_override("font_disabled_color", SETTINGS_TEXT_DISABLED)
	check_box.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.82))
	check_box.add_theme_constant_override("outline_size", 1)
	check_box.add_theme_constant_override("h_separation", 10)

static func apply_settings_check_box_icon_size(check_box: CheckBox, icon_size: int) -> void:
	if check_box == null:
		return
	var target_size := maxi(1, icon_size)
	check_box.custom_minimum_size.y = maxf(check_box.custom_minimum_size.y, float(target_size))
	check_box.add_theme_icon_override("unchecked", _scaled_settings_texture("checkbox_empty_icon.png", target_size))
	check_box.add_theme_icon_override("unchecked_hover", _scaled_settings_texture("checkbox_focus_empty_icon.png", target_size))
	check_box.add_theme_icon_override("unchecked_pressed", _scaled_settings_texture("checkbox_focus_empty_icon.png", target_size))
	check_box.add_theme_icon_override("unchecked_disabled", _scaled_settings_texture("checkbox_disabled_checked_icon.png", target_size))
	check_box.add_theme_icon_override("checked", _scaled_settings_texture("checkbox_checked_icon.png", target_size))
	check_box.add_theme_icon_override("checked_hover", _settings_checkbox_checked_hover_icon(target_size))
	check_box.add_theme_icon_override("checked_pressed", _settings_checkbox_checked_hover_icon(target_size))
	check_box.add_theme_icon_override("checked_disabled", _scaled_settings_texture("checkbox_disabled_checked_icon.png", target_size))

static func apply_settings_slider(slider: HSlider) -> void:
	if slider == null:
		return
	slider.custom_minimum_size.y = maxf(slider.custom_minimum_size.y, 34.0)
	var empty_style := StyleBoxEmpty.new()
	var empty_icon := _make_empty_icon(Vector2i(28, 28))
	slider.add_theme_stylebox_override("slider", empty_style)
	slider.add_theme_stylebox_override("grabber_area", empty_style)
	slider.add_theme_stylebox_override("grabber_area_highlight", empty_style)
	slider.add_theme_icon_override("grabber", empty_icon)
	slider.add_theme_icon_override("grabber_highlight", empty_icon)
	slider.add_theme_icon_override("grabber_disabled", empty_icon)
	_ensure_horizontal_scrollbar_parts(slider)

static func apply_settings_scroll_container(scroll: ScrollContainer) -> void:
	if scroll == null:
		return
	scroll.add_theme_stylebox_override("panel", _make_flat_style(Color(0.030, 0.030, 0.028, 0.55), SETTINGS_BRASS_DARK, 1, 4))
	scroll.add_theme_constant_override("scrollbar_margin_left", 8)
	scroll.add_theme_constant_override("scrollbar_margin_right", 4)
	scroll.add_theme_constant_override("scrollbar_margin_top", 6)
	scroll.add_theme_constant_override("scrollbar_margin_bottom", 6)
	var vbar := scroll.get_v_scroll_bar()
	if vbar != null:
		_apply_settings_scrollbar(vbar)
	var hbar := scroll.get_h_scroll_bar()
	if hbar != null:
		_apply_settings_scrollbar(hbar)

static func apply_latest_vertical_scrollbar(scrollbar: VScrollBar) -> void:
	if scrollbar == null:
		return
	_apply_settings_scrollbar(scrollbar)

static func apply_settings_avatar_button(button: Button) -> void:
	if button == null:
		return
	button.add_theme_stylebox_override("normal", _make_settings_control_style(Color(0.050, 0.048, 0.043, 0.94), SETTINGS_BRASS_DARK, 1, 6))
	button.add_theme_stylebox_override("hover", _make_settings_control_style(Color(0.068, 0.074, 0.073, 0.98), SETTINGS_BLUE_FOCUS, 2, 6, true))
	button.add_theme_stylebox_override("pressed", _make_settings_control_style(SETTINGS_CONTROL_PRESSED, SETTINGS_ROSE_GOLD, 2, 6, false, true))
	button.add_theme_stylebox_override("focus", _make_settings_focus_style(6))

static func _apply_settings_scrollbar(scrollbar: ScrollBar) -> void:
	if scrollbar is HScrollBar:
		scrollbar.custom_minimum_size = Vector2(20, 20)
		scrollbar.add_theme_stylebox_override("scroll", _make_settings_texture_style("hslider_rail_normal.png", 28, 10, 28, 10, 0, 0, 0, 0))
		scrollbar.add_theme_stylebox_override("scroll_focus", _make_settings_texture_style("hslider_rail_focus.png", 28, 10, 28, 10, 0, 0, 0, 0))
		scrollbar.add_theme_stylebox_override("grabber", _make_settings_texture_style("hslider_knob_normal_icon.png", 8, 8, 8, 8, 0, 0, 0, 0))
		scrollbar.add_theme_stylebox_override("grabber_highlight", _make_settings_texture_style("hslider_knob_focus_icon.png", 8, 8, 8, 8, 0, 0, 0, 0))
		scrollbar.add_theme_stylebox_override("grabber_pressed", _make_settings_texture_style("hslider_knob_pressed_icon.png", 8, 8, 8, 8, 0, 0, 0, 0))
	else:
		scrollbar.custom_minimum_size = Vector2(68, 20)
		var empty_style := StyleBoxEmpty.new()
		scrollbar.add_theme_stylebox_override("scroll", empty_style)
		scrollbar.add_theme_stylebox_override("scroll_focus", empty_style)
		scrollbar.add_theme_stylebox_override("grabber", empty_style)
		scrollbar.add_theme_stylebox_override("grabber_highlight", empty_style)
		scrollbar.add_theme_stylebox_override("grabber_pressed", empty_style)
		_ensure_vertical_scrollbar_parts(scrollbar as VScrollBar)
	scrollbar.add_theme_icon_override("increment", _make_empty_icon())
	scrollbar.add_theme_icon_override("increment_highlight", _make_empty_icon())
	scrollbar.add_theme_icon_override("decrement", _make_empty_icon())
	scrollbar.add_theme_icon_override("decrement_highlight", _make_empty_icon())

static func _ensure_vertical_scrollbar_parts(scrollbar: VScrollBar) -> void:
	var existing_track := scrollbar.get_node_or_null(NodePath(SETTINGS_VERTICAL_SCROLLBAR_TRACK_NODE_NAME))
	var track := existing_track as NinePatchRect
	if track == null:
		if existing_track != null:
			scrollbar.remove_child(existing_track)
			existing_track.queue_free()
		track = NinePatchRect.new()
		track.name = SETTINGS_VERTICAL_SCROLLBAR_TRACK_NODE_NAME
		track.mouse_filter = Control.MOUSE_FILTER_IGNORE
		track.z_index = 1
		scrollbar.add_child(track)
	track.patch_margin_top = SETTINGS_VERTICAL_SCROLLBAR_TRACK_END_MARGIN
	track.patch_margin_bottom = SETTINGS_VERTICAL_SCROLLBAR_TRACK_END_MARGIN
	track.patch_margin_left = 0
	track.patch_margin_right = 0
	track.draw_center = true

	var thumb := scrollbar.get_node_or_null(NodePath(SETTINGS_VERTICAL_SCROLLBAR_THUMB_NODE_NAME)) as TextureRect
	if thumb == null:
		thumb = TextureRect.new()
		thumb.name = SETTINGS_VERTICAL_SCROLLBAR_THUMB_NODE_NAME
		thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		thumb.z_index = 2
		scrollbar.add_child(thumb)

	_set_vertical_scrollbar_state(scrollbar, "normal")
	if not scrollbar.has_meta("ccr_vertical_scrollbar_layout_connected"):
		scrollbar.set_meta("ccr_vertical_scrollbar_layout_connected", true)
		scrollbar.resized.connect(func(): _layout_vertical_scrollbar_parts(scrollbar))
		scrollbar.value_changed.connect(func(_value: float): _layout_vertical_scrollbar_parts(scrollbar))
		scrollbar.changed.connect(func(): _layout_vertical_scrollbar_parts(scrollbar))
		scrollbar.mouse_entered.connect(func(): _set_vertical_scrollbar_state(scrollbar, "focus"))
		scrollbar.mouse_exited.connect(func(): _set_vertical_scrollbar_state(scrollbar, "normal"))
		scrollbar.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
				_set_vertical_scrollbar_state(scrollbar, "pressed" if event.pressed else "focus")
		)
	_layout_vertical_scrollbar_parts(scrollbar)

static func _set_vertical_scrollbar_state(scrollbar: VScrollBar, state: String) -> void:
	var track := scrollbar.get_node_or_null(NodePath(SETTINGS_VERTICAL_SCROLLBAR_TRACK_NODE_NAME)) as NinePatchRect
	var thumb := scrollbar.get_node_or_null(NodePath(SETTINGS_VERTICAL_SCROLLBAR_THUMB_NODE_NAME)) as TextureRect
	if track == null or thumb == null:
		return
	var texture_state := state if state in ["normal", "focus", "pressed", "disabled"] else "normal"
	track.texture = _settings_texture("vertical_scrollbar_track_%s.png" % texture_state)
	thumb.texture = _settings_texture("vertical_scrollbar_thumb_%s.png" % texture_state)

static func _layout_vertical_scrollbar_parts(scrollbar: VScrollBar) -> void:
	var track := scrollbar.get_node_or_null(NodePath(SETTINGS_VERTICAL_SCROLLBAR_TRACK_NODE_NAME)) as NinePatchRect
	var thumb := scrollbar.get_node_or_null(NodePath(SETTINGS_VERTICAL_SCROLLBAR_THUMB_NODE_NAME)) as TextureRect
	if track == null or thumb == null:
		return
	var scrollbar_width := maxf(scrollbar.size.x, scrollbar.custom_minimum_size.x)
	var scrollbar_height := maxf(scrollbar.size.y, scrollbar.custom_minimum_size.y)
	var track_texture_size := track.texture.get_size() if track.texture != null else Vector2(68, 438)
	var thumb_texture_size := thumb.texture.get_size() if thumb.texture != null else Vector2(93, 247)
	var asset_scale := 0.65
	var track_width := minf(scrollbar_width, track_texture_size.x)
	track.size = Vector2(track_width, scrollbar_height)
	track.custom_minimum_size = track.size
	track.position = Vector2((scrollbar_width - track_width) * 0.5, 0.0)

	var thumb_width := minf(scrollbar_width, thumb_texture_size.x * asset_scale)
	var thumb_height := minf(scrollbar_height, thumb_texture_size.y * asset_scale)
	thumb.size = Vector2(thumb_width, thumb_height)
	thumb.custom_minimum_size = thumb.size
	var effective_max := maxf(scrollbar.min_value, scrollbar.max_value - scrollbar.page)
	var value_ratio := 0.0
	if effective_max > scrollbar.min_value:
		value_ratio = clampf((scrollbar.value - scrollbar.min_value) / (effective_max - scrollbar.min_value), 0.0, 1.0)
	var endpoint_margin := minf(48.0, maxf(0.0, (scrollbar_height - thumb_height) * 0.5))
	var travel_height := maxf(0.0, scrollbar_height - thumb_height - endpoint_margin * 2.0)
	thumb.position = Vector2(
		(scrollbar_width - thumb_width) * 0.5,
		endpoint_margin + travel_height * value_ratio
	)

static func _ensure_horizontal_scrollbar_parts(slider: HSlider) -> void:
	var track := slider.get_node_or_null(NodePath(SETTINGS_HORIZONTAL_SCROLLBAR_TRACK_NODE_NAME)) as TextureRect
	if track == null:
		track = TextureRect.new()
		track.name = SETTINGS_HORIZONTAL_SCROLLBAR_TRACK_NODE_NAME
		track.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		track.stretch_mode = TextureRect.STRETCH_SCALE
		track.mouse_filter = Control.MOUSE_FILTER_IGNORE
		track.z_index = 1
		slider.add_child(track)
	track.texture = _settings_texture("horizontal_scrollbar_track_normal.png")

	var thumb := slider.get_node_or_null(NodePath(SETTINGS_HORIZONTAL_SCROLLBAR_THUMB_NODE_NAME)) as TextureRect
	if thumb == null:
		thumb = TextureRect.new()
		thumb.name = SETTINGS_HORIZONTAL_SCROLLBAR_THUMB_NODE_NAME
		thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		thumb.z_index = 2
		slider.add_child(thumb)
	thumb.texture = _settings_texture("horizontal_scrollbar_thumb_normal.png")

	if not slider.has_meta("ccr_horizontal_scrollbar_layout_connected"):
		slider.set_meta("ccr_horizontal_scrollbar_layout_connected", true)
		slider.resized.connect(func(): _layout_horizontal_scrollbar_parts(slider))
		slider.value_changed.connect(func(_value: float): _layout_horizontal_scrollbar_parts(slider))
	_layout_horizontal_scrollbar_parts(slider)

static func _layout_horizontal_scrollbar_parts(slider: HSlider) -> void:
	var track := slider.get_node_or_null(NodePath(SETTINGS_HORIZONTAL_SCROLLBAR_TRACK_NODE_NAME)) as TextureRect
	var thumb := slider.get_node_or_null(NodePath(SETTINGS_HORIZONTAL_SCROLLBAR_THUMB_NODE_NAME)) as TextureRect
	if track == null or thumb == null:
		return
	var track_size := track.texture.get_size() if track.texture != null else Vector2(339, 39)
	var thumb_size := thumb.texture.get_size() if thumb.texture != null else Vector2(28, 28)
	var slider_width := maxf(slider.size.x, slider.custom_minimum_size.x)
	var slider_height := maxf(slider.size.y, slider.custom_minimum_size.y)
	track.size = Vector2(slider_width, minf(track_size.y, slider_height))
	track.custom_minimum_size = track.size
	track.position = Vector2(0.0, (slider_height - track.size.y) * 0.5)

	thumb.size = thumb_size
	thumb.custom_minimum_size = thumb_size
	var value_ratio := 0.0
	if slider.max_value > slider.min_value:
		value_ratio = clampf((slider.value - slider.min_value) / (slider.max_value - slider.min_value), 0.0, 1.0)
	var track_endpoint_margin := thumb_size.x * 0.5
	var travel_width := maxf(0.0, slider_width - track_endpoint_margin * 2.0)
	var thumb_center_x := track_endpoint_margin + travel_width * value_ratio
	thumb.position = Vector2(
		thumb_center_x - thumb_size.x * 0.5,
		(slider_height - thumb_size.y) * 0.5
	)

static func _ensure_settings_toggle_knob(button: Button, active: bool) -> void:
	var knob := button.get_node_or_null(NodePath(SETTINGS_TOGGLE_KNOB_NODE_NAME)) as TextureRect
	if knob == null:
		knob = TextureRect.new()
		knob.name = SETTINGS_TOGGLE_KNOB_NODE_NAME
		knob.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		knob.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
		knob.z_index = 2
		button.add_child(knob)
		button.resized.connect(func(): _layout_settings_toggle_knob(button, button.button_pressed, false))
	# 使用最新 UI 的完整布尔拨块，不再使用丢失外圈装饰的 28px 缩略图。
	knob.texture = _settings_texture("toggle_knob_focus.png" if active else "toggle_knob_normal.png")
	_layout_settings_toggle_knob(button, active, true)

static func _layout_settings_toggle_knob(button: Button, active: bool, animate: bool) -> void:
	var knob := button.get_node_or_null(NodePath(SETTINGS_TOGGLE_KNOB_NODE_NAME)) as TextureRect
	if knob == null or knob.texture == null:
		return
	var button_width := maxf(maxf(button.size.x, button.custom_minimum_size.x), 92.0)
	var button_height := maxf(maxf(button.size.y, button.custom_minimum_size.y), 42.0)
	var source_size := knob.texture.get_size()
	var knob_scale := button_height / maxf(1.0, source_size.y)
	var knob_size := source_size * knob_scale
	var target_x := button_width - knob_size.x if active else 0.0
	var target_position := Vector2(target_x, (button_height - knob_size.y) * 0.5)
	knob.size = knob_size
	knob.custom_minimum_size = knob_size
	var previous_active := bool(button.get_meta("ccr_settings_toggle_active", active)) if button.has_meta("ccr_settings_toggle_active") else active
	button.set_meta("ccr_settings_toggle_active", active)
	if animate and previous_active != active and button.is_inside_tree():
		var active_tween := button.get_meta("ccr_settings_toggle_tween") as Tween if button.has_meta("ccr_settings_toggle_tween") else null
		if active_tween != null and is_instance_valid(active_tween):
			active_tween.kill()
		var tween := button.create_tween()
		button.set_meta("ccr_settings_toggle_tween", tween)
		tween.tween_property(knob, "position", target_position, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	else:
		knob.position = target_position

static func icon(icon_id: String) -> Texture2D:
	var path := str(ICON_PATHS.get(icon_id, ""))
	if path == "":
		push_error("CCRVisualStyle: unknown icon id %s" % icon_id)
		return null
	if icon_id.begins_with("vault_"):
		return _load_texture_png_source(path)
	return _load_texture_source(path)

static func apply_relic_button(
	button: Button,
	icon_id: String,
	active: bool = false,
	variant: String = "action"
) -> void:
	if button == null:
		return
	var resolved_variant := variant if BUTTON_TEXTURE_PATHS.has(variant) else "action"
	var paths: Dictionary = BUTTON_TEXTURE_PATHS[resolved_variant]
	button.add_theme_stylebox_override("normal", _make_button_style(str(paths["hover"] if active else paths["normal"]), resolved_variant))
	button.add_theme_stylebox_override("hover", _make_button_style(str(paths["hover"]), resolved_variant))
	button.add_theme_stylebox_override("pressed", _make_button_style(str(paths["pressed"]), resolved_variant))
	button.add_theme_stylebox_override("hover_pressed", _make_button_style(str(paths["pressed"]), resolved_variant))
	button.add_theme_stylebox_override("disabled", _make_button_style(str(paths["disabled"]), resolved_variant))
	button.add_theme_stylebox_override("focus", _make_button_style(str(paths["hover"]), resolved_variant))
	button.add_theme_color_override("font_color", RELIC_BUTTON_NAV_TEXT if not active else Color(0.78, 0.91, 1.0, 1.0))
	button.add_theme_color_override("font_hover_color", RELIC_BUTTON_HOVER_TEXT)
	button.add_theme_color_override("font_pressed_color", Color(1.0, 0.83, 0.52, 1.0))
	button.add_theme_color_override("font_hover_pressed_color", Color(1.0, 0.83, 0.52, 1.0))
	button.add_theme_color_override("font_focus_color", Color(0.92, 0.97, 1.0, 1.0))
	button.add_theme_color_override("font_disabled_color", RELIC_BUTTON_DISABLED_TEXT)
	button.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.82))
	button.add_theme_constant_override("outline_size", 1)
	button.add_theme_constant_override("h_separation", 0)
	# 图标独立于 Button 的文本排版，才能在悬浮时只缩放图标并固定其中心点。
	button.icon = null
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.clip_text = true
	button.set_meta("ccr_button_variant", resolved_variant)
	button.set_meta("ccr_icon_id", icon_id)
	button.set_meta(BUTTON_ICON_HOVER_SCALE_META, VAULT_ACTION_BUTTON_ICON_HOVER_SCALE if resolved_variant == "vault_action" else BUTTON_ICON_HOVER_SCALE)
	if resolved_variant == "vault_action":
		_capture_relic_button_caption_text(button)
		_hide_relic_button_native_text(button)
	_ensure_button_icon(button, icon_id)
	_ensure_button_icon_hover_animation(button)
	configure_relic_button_metrics(button, button.size.y if button.size.y > 0.0 else 36.0)

static func configure_relic_button_metrics(
	button: Button,
	button_height: float,
	icon_height_ratio: float = 2.0 / 3.0,
	center_icon: bool = false
) -> void:
	if button == null:
		return
	var icon_width := maxi(1, int(roundf(button_height * icon_height_ratio)))
	button.add_theme_constant_override("icon_max_width", icon_width)
	var text_label := get_button_text_label(button)
	if text_label != null:
		text_label.visible = false
	if center_icon:
		_configure_button_text_hidden(button)
	else:
		_configure_button_text_shift(button, float(icon_width))
	_layout_button_icon(button, icon_width, button_height, center_icon)

static func configure_relic_button_vertical_metrics(
	button: Button,
	icon_size: float,
	icon_top: float,
	text_gap: float,
	font_size: int,
	caption_color: Color = RELIC_BUTTON_VAULT_TEXT
) -> void:
	if button == null:
		return
	var resolved_icon_size := maxi(1, int(roundf(icon_size)))
	var resolved_font_size := maxi(1, font_size)
	button.add_theme_constant_override("icon_max_width", resolved_icon_size)
	button.add_theme_font_size_override("font_size", resolved_font_size)
	_capture_relic_button_caption_text(button)
	_hide_relic_button_native_text(button)
	button.set_meta("ccr_vertical_caption_color", caption_color)
	button.set_meta(BUTTON_CAPTION_HOVER_COLOR_META, RELIC_BUTTON_HOVER_TEXT)
	_configure_button_text_hidden(button)
	_layout_button_icon_vertical(button, float(resolved_icon_size), icon_top)
	_ensure_button_text_label(button)
	_ensure_relic_button_caption_hover(button)
	refresh_relic_button_caption(button, icon_top + float(resolved_icon_size) + text_gap, resolved_font_size)

static func get_button_icon(button: Button) -> TextureRect:
	if button == null:
		return null
	return button.get_node_or_null(NodePath(BUTTON_ICON_NODE_NAME)) as TextureRect

static func get_button_text_label(button: Button) -> Label:
	if button == null:
		return null
	return button.get_node_or_null(NodePath(BUTTON_TEXT_LABEL_NODE_NAME)) as Label

static func get_relic_button_caption_text(button: Button) -> String:
	if button == null:
		return ""
	return str(button.get_meta(BUTTON_CAPTION_META, button.text))

static func _ensure_button_icon(button: Button, icon_id: String) -> void:
	var button_icon := get_button_icon(button)
	if button_icon == null:
		button_icon = TextureRect.new()
		button_icon.name = BUTTON_ICON_NODE_NAME
		button_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		button_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		button_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button_icon.z_index = 1
		button.add_child(button_icon)
	button_icon.texture = icon(icon_id)

static func _layout_button_icon(button: Button, icon_size: float, button_height: float, centered: bool = false) -> void:
	var button_icon := get_button_icon(button)
	if button_icon == null:
		return
	# 同一列统一采用该列最大（2/3 按钮高度）的参考宽度，资源类小图标也会与操作图标共线。
	var column_reference := maxf(1.0, button_height * 2.0 / 3.0)
	var center_x := button.size.x * 0.5 if centered else 4.0 + column_reference
	button_icon.custom_minimum_size = Vector2(icon_size, icon_size)
	button_icon.size = button_icon.custom_minimum_size
	button_icon.position = Vector2(center_x - icon_size * 0.5, (button.size.y - icon_size) * 0.5)
	button_icon.pivot_offset = button_icon.size * 0.5

static func _layout_button_icon_vertical(button: Button, icon_size: float, icon_top: float) -> void:
	var button_icon := get_button_icon(button)
	if button_icon == null:
		return
	button_icon.custom_minimum_size = Vector2(icon_size, icon_size)
	button_icon.size = button_icon.custom_minimum_size
	button_icon.position = Vector2((button.size.x - icon_size) * 0.5, icon_top)
	button_icon.pivot_offset = button_icon.size * 0.5

static func _configure_button_text_shift(button: Button, icon_size: float) -> void:
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		var style := button.get_theme_stylebox(state) as StyleBoxTexture
		if style == null:
			continue
		style.content_margin_left = 4.0 + maxf(1.0, icon_size)
		style.content_margin_right = 4.0
		style.content_margin_top = 2.0
		style.content_margin_bottom = 2.0

static func _configure_button_text_hidden(button: Button) -> void:
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		var style := button.get_theme_stylebox(state) as StyleBoxTexture
		if style == null:
			continue
		style.content_margin_left = 0.0
		style.content_margin_right = 0.0
		style.content_margin_top = 0.0
		style.content_margin_bottom = 0.0

static func _ensure_button_text_label(button: Button) -> Label:
	var label := get_button_text_label(button)
	if label == null:
		label = Label.new()
		label.name = BUTTON_TEXT_LABEL_NODE_NAME
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		label.clip_text = true
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.z_index = 2
		button.add_child(label)
	label.visible = true
	return label

static func refresh_relic_button_caption(button: Button, text_top: float, font_size: int) -> void:
	_capture_relic_button_caption_text(button)
	_hide_relic_button_native_text(button)
	var label := get_button_text_label(button)
	if label == null:
		return
	label.text = get_relic_button_caption_text(button)
	label.position = Vector2(0.0, text_top)
	label.size = Vector2(button.size.x, maxf(1.0, button.size.y - text_top))
	label.custom_minimum_size = label.size
	label.add_theme_font_size_override("font_size", font_size)
	_apply_relic_button_caption_color(button)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.82))
	label.add_theme_constant_override("outline_size", 1)

static func _ensure_relic_button_caption_hover(button: Button) -> void:
	if button == null or button.has_meta("ccr_vertical_caption_hover_bound"):
		return
	button.set_meta("ccr_vertical_caption_hover_bound", true)
	button.set_meta(BUTTON_CAPTION_HOVER_META, false)
	button.mouse_entered.connect(func():
		button.set_meta(BUTTON_CAPTION_HOVER_META, true)
		_apply_relic_button_caption_color(button)
	)
	button.mouse_exited.connect(func():
		button.set_meta(BUTTON_CAPTION_HOVER_META, false)
		_apply_relic_button_caption_color(button)
	)

static func _apply_relic_button_caption_color(button: Button) -> void:
	var label := get_button_text_label(button)
	if label == null:
		return
	var normal_color: Color = button.get_meta("ccr_vertical_caption_color", RELIC_BUTTON_VAULT_TEXT)
	var hover_color: Color = button.get_meta(BUTTON_CAPTION_HOVER_COLOR_META, RELIC_BUTTON_HOVER_TEXT)
	var caption_color := RELIC_BUTTON_DISABLED_TEXT if button.disabled else (hover_color if bool(button.get_meta(BUTTON_CAPTION_HOVER_META, false)) else normal_color)
	label.add_theme_color_override(
		"font_color",
		caption_color
	)

static func _capture_relic_button_caption_text(button: Button) -> void:
	if button == null or button.text == "":
		return
	button.set_meta(BUTTON_CAPTION_META, button.text)
	button.text = ""

static func _hide_relic_button_native_text(button: Button) -> void:
	if button == null:
		return
	var transparent := Color(1.0, 1.0, 1.0, 0.0)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color", "font_disabled_color", "font_outline_color"]:
		button.add_theme_color_override(state, transparent)

static func _ensure_button_icon_hover_animation(button: Button) -> void:
	if button.has_meta("ccr_icon_hover_animation_bound"):
		return
	button.set_meta("ccr_icon_hover_animation_bound", true)
	button.mouse_entered.connect(func(): _animate_button_icon(button, true))
	button.mouse_exited.connect(func(): _animate_button_icon(button, false))

static func _animate_button_icon(button: Button, hovered: bool) -> void:
	var button_icon := get_button_icon(button)
	if button_icon == null:
		return
	var active_tween := button.get_meta("ccr_icon_hover_tween") as Tween if button.has_meta("ccr_icon_hover_tween") else null
	if active_tween != null and is_instance_valid(active_tween):
		active_tween.kill()
	var tween := button.create_tween()
	button.set_meta("ccr_icon_hover_tween", tween)
	var hover_scale := float(button.get_meta(BUTTON_ICON_HOVER_SCALE_META, BUTTON_ICON_HOVER_SCALE))
	var target_scale := Vector2.ONE * (hover_scale if hovered else 1.0)
	tween.tween_property(button_icon, "scale", target_scale, BUTTON_ICON_HOVER_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

static func make_status_icon(icon_id: String, node_name: String, icon_size: float) -> TextureRect:
	var texture_rect := TextureRect.new()
	texture_rect.name = node_name
	texture_rect.texture = icon(icon_id)
	texture_rect.custom_minimum_size = Vector2(icon_size, icon_size)
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return texture_rect

static func _make_button_style(texture_path: String, variant: String) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = _load_texture_png_source(texture_path) if variant == "vault_action" else _load_texture_source(texture_path)
	if variant == "navigation":
		style.texture_margin_left = 20.0
		style.texture_margin_right = 20.0
		style.texture_margin_top = 12.0
		style.texture_margin_bottom = 12.0
	else:
		style.texture_margin_left = 20.0
		style.texture_margin_right = 20.0
		style.texture_margin_top = 14.0
		style.texture_margin_bottom = 14.0
	style.content_margin_left = 4.0
	style.content_margin_right = 4.0
	style.content_margin_top = 2.0
	style.content_margin_bottom = 2.0
	return style

static func _load_texture_source(resource_path: String) -> Texture2D:
	var texture := load(resource_path) as Texture2D
	if texture != null:
		return texture
	return _load_texture_png_source(resource_path)

static func _load_texture_png_source(resource_path: String) -> Texture2D:
	var image := Image.new()
	var error := image.load(ProjectSettings.globalize_path(resource_path))
	if error == OK:
		return ImageTexture.create_from_image(image)
	return null

static func _settings_texture(file_name: String) -> Texture2D:
	var resource_path := SETTINGS_CONTROL_ROOT + file_name
	if ResourceLoader.exists(resource_path, "Texture2D"):
		var texture := load(resource_path) as Texture2D
		if texture != null:
			return texture
	var image := Image.new()
	var error := image.load(ProjectSettings.globalize_path(resource_path))
	if error == OK:
		return ImageTexture.create_from_image(image)
	push_error("CCRVisualStyle: settings control texture not found: %s" % resource_path)
	return _make_empty_icon()

static func _scaled_settings_texture(file_name: String, target_height: int) -> Texture2D:
	var cache_key := "%s:%d" % [file_name, target_height]
	if _settings_scaled_texture_cache.has(cache_key):
		return _settings_scaled_texture_cache[cache_key] as Texture2D
	var source_texture := _settings_texture(file_name)
	var source_image := source_texture.get_image() if source_texture != null else null
	if source_image == null or source_image.is_empty():
		return source_texture
	var source_size := source_image.get_size()
	if source_size.y <= 0:
		return source_texture
	var scaled_height := maxi(1, target_height)
	var scaled_width := maxi(1, int(roundf(float(source_size.x) * float(scaled_height) / float(source_size.y))))
	var scaled_image := source_image.duplicate()
	scaled_image.resize(scaled_width, scaled_height, Image.INTERPOLATE_LANCZOS)
	var texture := ImageTexture.create_from_image(scaled_image)
	_settings_scaled_texture_cache[cache_key] = texture
	return texture

static func _settings_checkbox_icon_texture(file_name: String, target_height: int) -> Texture2D:
	if target_height > 0:
		return _scaled_settings_texture(file_name, target_height)
	return _settings_texture(file_name)

static func _settings_checkbox_checked_hover_icon(target_height: int = 0) -> Texture2D:
	var cache_key := "checked_hover:%d" % target_height
	if _settings_checkbox_checked_hover_cache.has(cache_key):
		return _settings_checkbox_checked_hover_cache[cache_key] as Texture2D
	var focus_texture := _settings_checkbox_icon_texture("checkbox_focus_empty_icon.png", target_height)
	var checked_texture := _settings_checkbox_icon_texture("checkbox_checked_icon.png", target_height)
	var empty_texture := _settings_checkbox_icon_texture("checkbox_empty_icon.png", target_height)
	var focus_image := focus_texture.get_image() if focus_texture != null else null
	var checked_image := checked_texture.get_image() if checked_texture != null else null
	var empty_image := empty_texture.get_image() if empty_texture != null else null
	if focus_image == null or checked_image == null or empty_image == null:
		return checked_texture
	if focus_image.is_empty() or checked_image.is_empty() or empty_image.is_empty():
		return checked_texture
	var image := focus_image.duplicate()
	var width := mini(image.get_width(), mini(checked_image.get_width(), empty_image.get_width()))
	var height := mini(image.get_height(), mini(checked_image.get_height(), empty_image.get_height()))
	for y in range(height):
		for x in range(width):
			var checked_pixel := checked_image.get_pixel(x, y)
			var empty_pixel := empty_image.get_pixel(x, y)
			var delta := absf(checked_pixel.r - empty_pixel.r) + absf(checked_pixel.g - empty_pixel.g) + absf(checked_pixel.b - empty_pixel.b) + absf(checked_pixel.a - empty_pixel.a)
			if checked_pixel.a > 0.01 and delta > 0.08:
				image.set_pixel(x, y, checked_pixel)
	var texture := ImageTexture.create_from_image(image)
	_settings_checkbox_checked_hover_cache[cache_key] = texture
	return texture

static func _padded_settings_texture(file_name: String, target_size: Vector2i, visual_height: int) -> Texture2D:
	var safe_size := Vector2i(maxi(1, target_size.x), maxi(1, target_size.y))
	var safe_visual_height := clampi(visual_height, 1, safe_size.y)
	var cache_key := "%s:padded:%d:%d:%d" % [file_name, safe_size.x, safe_size.y, safe_visual_height]
	if _settings_scaled_texture_cache.has(cache_key):
		return _settings_scaled_texture_cache[cache_key] as Texture2D
	var source_texture := _settings_texture(file_name)
	var source_image := source_texture.get_image() if source_texture != null else null
	if source_image == null or source_image.is_empty():
		return source_texture
	var scaled_image := source_image.duplicate()
	scaled_image.resize(safe_size.x, safe_visual_height, Image.INTERPOLATE_LANCZOS)
	var padded_image := Image.create(safe_size.x, safe_size.y, false, Image.FORMAT_RGBA8)
	padded_image.fill(Color.TRANSPARENT)
	var target_y := (safe_size.y - safe_visual_height) / 2
	padded_image.blit_rect(scaled_image, Rect2i(Vector2i.ZERO, scaled_image.get_size()), Vector2i(0, target_y))
	var texture := ImageTexture.create_from_image(padded_image)
	_settings_scaled_texture_cache[cache_key] = texture
	return texture

static func _make_padded_settings_texture_style(
	file_name: String,
	target_size: Vector2i,
	visual_height: int,
	content_left: float = 0.0,
	content_right: float = 0.0,
	content_top: float = 0.0,
	content_bottom: float = 0.0
) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = _padded_settings_texture(file_name, target_size, visual_height)
	style.content_margin_left = content_left
	style.content_margin_right = content_right
	style.content_margin_top = content_top
	style.content_margin_bottom = content_bottom
	return style

static func _make_settings_texture_style(
	file_name: String,
	margin_left: float,
	margin_top: float,
	margin_right: float,
	margin_bottom: float,
	content_left: float = 0.0,
	content_right: float = 0.0,
	content_top: float = 0.0,
	content_bottom: float = 0.0
) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = _settings_texture(file_name)
	style.texture_margin_left = margin_left
	style.texture_margin_top = margin_top
	style.texture_margin_right = margin_right
	style.texture_margin_bottom = margin_bottom
	style.content_margin_left = content_left
	style.content_margin_right = content_right
	style.content_margin_top = content_top
	style.content_margin_bottom = content_bottom
	return style

static func _make_scaled_settings_texture_style(
	file_name: String,
	target_height: int,
	margin_left: float,
	margin_top: float,
	margin_right: float,
	margin_bottom: float,
	content_left: float = 0.0,
	content_right: float = 0.0,
	content_top: float = 0.0,
	content_bottom: float = 0.0
) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = _scaled_settings_texture(file_name, target_height)
	style.texture_margin_left = margin_left
	style.texture_margin_top = margin_top
	style.texture_margin_right = margin_right
	style.texture_margin_bottom = margin_bottom
	style.content_margin_left = content_left
	style.content_margin_right = content_right
	style.content_margin_top = content_top
	style.content_margin_bottom = content_bottom
	return style

static func _make_empty_icon(size: Vector2i = Vector2i.ONE) -> Texture2D:
	var image := Image.create(maxi(1, size.x), maxi(1, size.y), false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	return ImageTexture.create_from_image(image)

static func _make_settings_control_style(
	fill: Color,
	border: Color,
	border_width: int,
	radius: int,
	focused: bool = false,
	pressed: bool = false
) -> StyleBoxFlat:
	var style := _make_flat_style(
		fill,
		border,
		border_width,
		radius,
		Vector2(0, 2 if not pressed else 0),
		Color(0.0, 0.0, 0.0, 0.24 if not pressed else 0.14),
		6 if not pressed else 2,
		focused
	)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 6.0 if not pressed else 8.0
	style.content_margin_bottom = 6.0 if not pressed else 4.0
	return style

static func _make_settings_focus_style(radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	style.border_color = SETTINGS_BLUE_FOCUS
	style.set_border_width_all(2)
	style.set_corner_radius_all(radius)
	style.shadow_color = Color(0.27, 0.70, 1.0, 0.42)
	style.shadow_size = 8
	return style

static func _make_toggle_icon(active: bool, highlighted: bool = false, disabled: bool = false) -> Texture2D:
	var width := 52
	var height := 24
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))
	var track := Color(0.15, 0.14, 0.13, 0.82) if disabled else (Color(0.055, 0.075, 0.076, 1.0) if active else Color(0.044, 0.043, 0.040, 0.98))
	var border := Color(0.45, 0.45, 0.43, 0.86) if disabled else (SETTINGS_BLUE_FOCUS if highlighted else SETTINGS_ROSE_GOLD)
	var glow := Color(0.30, 0.70, 1.0, 0.42) if active and highlighted else Color(0.90, 0.70, 0.40, 0.22)
	var radius := float(height) * 0.5 - 1.0
	var left_center := Vector2(radius + 1.0, height * 0.5)
	var right_center := Vector2(width - radius - 1.0, height * 0.5)
	for y in range(height):
		for x in range(width):
			var p := Vector2(x + 0.5, y + 0.5)
			var in_capsule := absf(p.y - height * 0.5) <= radius and p.x >= left_center.x and p.x <= right_center.x
			in_capsule = in_capsule or p.distance_to(left_center) <= radius or p.distance_to(right_center) <= radius
			if not in_capsule:
				continue
			var edge := minf(
				absf(p.y - height * 0.5),
				minf(p.distance_to(left_center), p.distance_to(right_center))
			)
			image.set_pixel(x, y, border if edge > radius - 2.0 else track)
			if active and p.x < width * 0.58 and edge <= radius - 3.0:
				image.set_pixel(x, y, glow)
	var knob_center := Vector2(width - height * 0.5 - 2.0, height * 0.5) if active else Vector2(height * 0.5 + 2.0, height * 0.5)
	var knob_fill := Color(0.56, 0.56, 0.54, 0.96) if disabled else Color(0.86, 0.68, 0.42, 1.0)
	for y in range(height):
		for x in range(width):
			var p := Vector2(x + 0.5, y + 0.5)
			var d := p.distance_to(knob_center)
			if d <= 8.0:
				image.set_pixel(x, y, knob_fill)
			if d > 6.0 and d <= 8.0:
				image.set_pixel(x, y, Color(1.0, 0.88, 0.62, 1.0) if not disabled else Color(0.72, 0.72, 0.70, 0.9))
	return ImageTexture.create_from_image(image)

static func _make_checkbox_icon(checked: bool, highlighted: bool = false, disabled: bool = false) -> Texture2D:
	var size := 28
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))
	var border := Color(0.48, 0.48, 0.46, 0.85) if disabled else (SETTINGS_BLUE_FOCUS if highlighted else SETTINGS_ROSE_GOLD)
	var fill := Color(0.19, 0.19, 0.18, 0.86) if disabled else Color(0.044, 0.043, 0.040, 0.98)
	var left := 4
	var top := 4
	var right := size - 5
	var bottom := size - 5
	for y in range(top, bottom + 1):
		for x in range(left, right + 1):
			var border_pixel := x <= left + 2 or x >= right - 2 or y <= top + 2 or y >= bottom - 2
			image.set_pixel(x, y, border if border_pixel else fill)
	if checked:
		var mark := Color(0.64, 0.64, 0.62, 0.9) if disabled else (SETTINGS_BLUE_FOCUS if highlighted else SETTINGS_ROSE_GOLD)
		_draw_image_line(image, Vector2(8, 15), Vector2(12, 20), mark, 2)
		_draw_image_line(image, Vector2(12, 20), Vector2(21, 8), mark, 2)
	return ImageTexture.create_from_image(image)

static func _make_scroll_arrow_icon(scrollbar: ScrollBar, increment: bool, highlighted: bool = false) -> Texture2D:
	var color := SETTINGS_BLUE_FOCUS if highlighted else SETTINGS_ROSE_GOLD
	if scrollbar is HScrollBar:
		return _make_horizontal_chevron_icon(14, 14, color, increment)
	return _make_chevron_icon(14, 14, color, not increment)

static func _make_flat_style(
	fill: Color,
	border: Color,
	border_width: int,
	radius: int,
	shadow_offset: Vector2 = Vector2.ZERO,
	shadow_color: Color = Color.TRANSPARENT,
	shadow_size: int = 0,
	focused: bool = false
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.shadow_offset = shadow_offset
	style.shadow_color = shadow_color
	style.shadow_size = shadow_size
	if focused:
		style.shadow_color = Color(0.27, 0.70, 1.0, 0.32)
		style.shadow_size = max(shadow_size, 8)
	style.anti_aliasing = true
	return style

static func _make_chevron_icon(width: int, height: int, color: Color, up: bool = false) -> Texture2D:
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))
	var center_y := height * 0.55 if not up else height * 0.45
	var left := Vector2(width * 0.25, height * (0.35 if not up else 0.65))
	var mid := Vector2(width * 0.5, center_y)
	var right := Vector2(width * 0.75, height * (0.35 if not up else 0.65))
	_draw_image_line(image, left, mid, color, 2)
	_draw_image_line(image, mid, right, color, 2)
	return ImageTexture.create_from_image(image)

static func _make_horizontal_chevron_icon(width: int, height: int, color: Color, right: bool = true) -> Texture2D:
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))
	var center_x := width * 0.55 if right else width * 0.45
	var top := Vector2(width * (0.35 if right else 0.65), height * 0.25)
	var mid := Vector2(center_x, height * 0.5)
	var bottom := Vector2(width * (0.35 if right else 0.65), height * 0.75)
	_draw_image_line(image, top, mid, color, 2)
	_draw_image_line(image, mid, bottom, color, 2)
	return ImageTexture.create_from_image(image)

static func _make_slider_grabber_icon(highlighted: bool, disabled: bool = false) -> Texture2D:
	var size := 24
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))
	var center := Vector2(size * 0.5, size * 0.5)
	var radius := 10.0
	var border := Color(0.48, 0.48, 0.46, 0.90) if disabled else (SETTINGS_BLUE_FOCUS if highlighted else SETTINGS_ROSE_GOLD)
	var fill := Color(0.24, 0.24, 0.23, 0.92) if disabled else Color(0.075, 0.068, 0.055, 1.0)
	var gem := Color(0.58, 0.58, 0.56, 0.70) if disabled else (Color(0.60, 0.88, 1.0, 1.0) if highlighted else Color(0.90, 0.72, 0.42, 1.0))
	for y in range(size):
		for x in range(size):
			var p := Vector2(x + 0.5, y + 0.5)
			var d := p.distance_to(center)
			if d <= radius:
				image.set_pixel(x, y, fill)
			if d > radius - 2.0 and d <= radius:
				image.set_pixel(x, y, border)
			if absf(p.x - center.x) + absf(p.y - center.y) <= 4.2:
				image.set_pixel(x, y, gem)
	return ImageTexture.create_from_image(image)

static func _draw_image_line(image: Image, start: Vector2, end: Vector2, color: Color, thickness: int) -> void:
	var steps := int(maxf(absf(end.x - start.x), absf(end.y - start.y))) + 1
	for i in range(steps + 1):
		var t := float(i) / float(maxi(1, steps))
		var p := start.lerp(end, t)
		for yy in range(-thickness, thickness + 1):
			for xx in range(-thickness, thickness + 1):
				if Vector2(xx, yy).length() > float(thickness):
					continue
				var px := int(roundf(p.x)) + xx
				var py := int(roundf(p.y)) + yy
				if px >= 0 and py >= 0 and px < image.get_width() and py < image.get_height():
					image.set_pixel(px, py, color)

static func make_shadow_panel(node_name: String, corner_radius: int, shadow_size: int, shadow_offset: Vector2, color: Color = CARD_SHADOW) -> Panel:
	var panel := Panel.new()
	panel.name = node_name
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.01)
	style.border_color = Color(0.0, 0.0, 0.0, 0.0)
	style.set_corner_radius_all(corner_radius)
	style.shadow_color = color
	style.shadow_size = shadow_size
	style.shadow_offset = shadow_offset
	panel.add_theme_stylebox_override("panel", style)
	return panel

static func make_texture_shadow(source: TextureRect, node_name: String, offset: Vector2 = Vector2(10, 14), color: Color = RELIC_SHADOW) -> TextureRect:
	var shadow := TextureRect.new()
	shadow.name = node_name
	shadow.texture = source.texture
	shadow.expand_mode = source.expand_mode
	shadow.stretch_mode = source.stretch_mode
	shadow.anchor_left = source.anchor_left
	shadow.anchor_top = source.anchor_top
	shadow.anchor_right = source.anchor_right
	shadow.anchor_bottom = source.anchor_bottom
	shadow.offset_left = source.offset_left + offset.x
	shadow.offset_top = source.offset_top + offset.y
	shadow.offset_right = source.offset_right + offset.x
	shadow.offset_bottom = source.offset_bottom + offset.y
	shadow.modulate = color
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shadow.z_index = source.z_index - 1
	return shadow
