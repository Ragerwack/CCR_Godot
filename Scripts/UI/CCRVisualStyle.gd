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
const BUTTON_ICON_NODE_NAME := "CCRButtonIcon"
const BUTTON_ICON_HOVER_SCALE := 1.5
const BUTTON_ICON_HOVER_SECONDS := 0.4
const DIALOG_PANEL_PATH := "res://Resources/UI/Dialogs/ExitGame/exit_dialog_panel.png"
const DIALOG_CONFIRM_BUTTON_PATH := "res://Resources/UI/Dialogs/ExitGame/exit_dialog_confirm_button.png"
const DIALOG_CANCEL_BUTTON_PATH := "res://Resources/UI/Dialogs/ExitGame/exit_dialog_cancel_button.png"
const DIALOG_PANEL_SIZE := Vector2(960, 394)
const SETTINGS_PANEL_PATH := "res://Resources/UI/Settings/RelicPanel/settings_panel_scheme_c.png"

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
	var border := Color(0.78, 0.62, 0.39, 1.0) if not destructive else Color(0.72, 0.34, 0.22, 1.0)
	button.add_theme_stylebox_override("normal", _make_settings_control_style(SETTINGS_CONTROL_DARK, border, 2, 6))
	button.add_theme_stylebox_override("hover", _make_settings_control_style(Color(0.060, 0.066, 0.066, 1.0), SETTINGS_BLUE_FOCUS, 2, 6, true))
	button.add_theme_stylebox_override("pressed", _make_settings_control_style(SETTINGS_CONTROL_PRESSED, SETTINGS_ROSE_GOLD, 2, 6, false, true))
	button.add_theme_stylebox_override("hover_pressed", _make_settings_control_style(SETTINGS_CONTROL_PRESSED, SETTINGS_ROSE_GOLD, 2, 6, false, true))
	button.add_theme_stylebox_override("disabled", _make_settings_control_style(SETTINGS_DISABLED, Color(0.43, 0.42, 0.39, 0.88), 1, 6))
	button.add_theme_stylebox_override("focus", _make_settings_focus_style(6))
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

static func apply_settings_tab_button(button: Button, active: bool) -> void:
	if button == null:
		return
	var normal_color := Color(0.078, 0.074, 0.066, 0.98) if active else Color(0.115, 0.105, 0.092, 0.82)
	var border := SETTINGS_BLUE_FOCUS if active else SETTINGS_BRASS_DARK
	button.add_theme_stylebox_override("normal", _make_settings_control_style(normal_color, border, 2 if active else 1, 6, active))
	button.add_theme_stylebox_override("hover", _make_settings_control_style(Color(0.075, 0.082, 0.084, 1.0), SETTINGS_BLUE_FOCUS, 2, 6, true))
	button.add_theme_stylebox_override("pressed", _make_settings_control_style(SETTINGS_CONTROL_PRESSED, SETTINGS_ROSE_GOLD, 2, 6, false, true))
	button.add_theme_stylebox_override("hover_pressed", _make_settings_control_style(SETTINGS_CONTROL_PRESSED, SETTINGS_ROSE_GOLD, 2, 6, false, true))
	button.add_theme_stylebox_override("disabled", _make_settings_control_style(SETTINGS_DISABLED, Color(0.43, 0.42, 0.39, 0.88), 1, 6))
	button.add_theme_stylebox_override("focus", _make_settings_focus_style(6))
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
	apply_settings_button(option as Button)
	option.custom_minimum_size.y = maxf(option.custom_minimum_size.y, 40.0)
	option.add_theme_icon_override("arrow", _make_chevron_icon(18, 12, SETTINGS_ROSE_GOLD))
	apply_settings_popup_menu(option.get_popup())

static func apply_settings_popup_menu(popup: PopupMenu) -> void:
	if popup == null:
		return
	var panel := _make_flat_style(
		Color(0.045, 0.044, 0.041, 0.98),
		SETTINGS_ROSE_GOLD,
		2,
		6,
		Vector2(0, 8),
		Color(0.0, 0.0, 0.0, 0.32),
		12
	)
	panel.content_margin_left = 8.0
	panel.content_margin_right = 8.0
	panel.content_margin_top = 8.0
	panel.content_margin_bottom = 8.0
	popup.add_theme_stylebox_override("panel", panel)
	popup.add_theme_stylebox_override("hover", _make_settings_control_style(Color(0.10, 0.16, 0.18, 0.95), SETTINGS_BLUE_FOCUS, 1, 4, true))
	popup.add_theme_stylebox_override("separator", _make_flat_style(Color(0.62, 0.47, 0.25, 0.55), Color.TRANSPARENT, 0, 0))
	popup.add_theme_color_override("font_color", SETTINGS_TEXT)
	popup.add_theme_color_override("font_hover_color", SETTINGS_TEXT_HOVER)
	popup.add_theme_color_override("font_disabled_color", SETTINGS_TEXT_DISABLED)
	popup.add_theme_constant_override("v_separation", 6)
	popup.add_theme_constant_override("h_separation", 8)

static func apply_settings_slider(slider: HSlider) -> void:
	if slider == null:
		return
	var rail := _make_flat_style(Color(0.030, 0.030, 0.029, 1.0), SETTINGS_BRASS_DARK, 1, 3)
	rail.content_margin_top = 3.0
	rail.content_margin_bottom = 3.0
	var fill := _make_flat_style(Color(0.22, 0.48, 0.62, 0.92), SETTINGS_BLUE_FOCUS, 1, 3, Vector2.ZERO, Color.TRANSPARENT, 0, true)
	var fill_hover := _make_flat_style(Color(0.28, 0.60, 0.78, 0.95), SETTINGS_BLUE_FOCUS, 1, 3, Vector2.ZERO, Color.TRANSPARENT, 0, true)
	slider.add_theme_stylebox_override("slider", rail)
	slider.add_theme_stylebox_override("grabber_area", fill)
	slider.add_theme_stylebox_override("grabber_area_highlight", fill_hover)
	slider.add_theme_icon_override("grabber", _make_slider_grabber_icon(false))
	slider.add_theme_icon_override("grabber_highlight", _make_slider_grabber_icon(true))
	slider.add_theme_icon_override("grabber_disabled", _make_slider_grabber_icon(false, true))

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

static func apply_settings_avatar_button(button: Button) -> void:
	if button == null:
		return
	button.add_theme_stylebox_override("normal", _make_settings_control_style(Color(0.050, 0.048, 0.043, 0.94), SETTINGS_BRASS_DARK, 1, 6))
	button.add_theme_stylebox_override("hover", _make_settings_control_style(Color(0.068, 0.074, 0.073, 0.98), SETTINGS_BLUE_FOCUS, 2, 6, true))
	button.add_theme_stylebox_override("pressed", _make_settings_control_style(SETTINGS_CONTROL_PRESSED, SETTINGS_ROSE_GOLD, 2, 6, false, true))
	button.add_theme_stylebox_override("focus", _make_settings_focus_style(6))

static func _apply_settings_scrollbar(scrollbar: ScrollBar) -> void:
	scrollbar.custom_minimum_size = Vector2(20, 20)
	scrollbar.add_theme_stylebox_override("scroll", _make_flat_style(Color(0.095, 0.078, 0.047, 0.62), SETTINGS_BRASS_DARK, 1, 6))
	scrollbar.add_theme_stylebox_override("scroll_focus", _make_settings_focus_style(6))
	scrollbar.add_theme_stylebox_override("grabber", _make_settings_control_style(Color(0.060, 0.058, 0.052, 1.0), SETTINGS_ROSE_GOLD, 2, 6))
	scrollbar.add_theme_stylebox_override("grabber_highlight", _make_settings_control_style(Color(0.070, 0.082, 0.084, 1.0), SETTINGS_BLUE_FOCUS, 2, 6, true))
	scrollbar.add_theme_stylebox_override("grabber_pressed", _make_settings_control_style(SETTINGS_CONTROL_PRESSED, SETTINGS_ROSE_GOLD, 2, 6, false, true))
	scrollbar.add_theme_icon_override("increment", _make_chevron_icon(14, 14, SETTINGS_ROSE_GOLD, true))
	scrollbar.add_theme_icon_override("increment_highlight", _make_chevron_icon(14, 14, SETTINGS_BLUE_FOCUS, true))
	scrollbar.add_theme_icon_override("decrement", _make_chevron_icon(14, 14, SETTINGS_ROSE_GOLD, false))
	scrollbar.add_theme_icon_override("decrement_highlight", _make_chevron_icon(14, 14, SETTINGS_BLUE_FOCUS, false))

static func icon(icon_id: String) -> Texture2D:
	var path := str(ICON_PATHS.get(icon_id, ""))
	if path == "":
		push_error("CCRVisualStyle: unknown icon id %s" % icon_id)
		return null
	return load(path) as Texture2D

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
	button.add_theme_color_override("font_color", Color(0.96, 0.88, 0.69, 1.0) if not active else Color(0.78, 0.91, 1.0, 1.0))
	button.add_theme_color_override("font_hover_color", Color(0.92, 0.97, 1.0, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(1.0, 0.83, 0.52, 1.0))
	button.add_theme_color_override("font_hover_pressed_color", Color(1.0, 0.83, 0.52, 1.0))
	button.add_theme_color_override("font_focus_color", Color(0.92, 0.97, 1.0, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(0.56, 0.57, 0.59, 0.92))
	button.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.82))
	button.add_theme_constant_override("outline_size", 1)
	button.add_theme_constant_override("h_separation", 0)
	# 图标独立于 Button 的文本排版，才能在悬浮时只缩放图标并固定其中心点。
	button.icon = null
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.clip_text = true
	button.set_meta("ccr_button_variant", resolved_variant)
	button.set_meta("ccr_icon_id", icon_id)
	_ensure_button_icon(button, icon_id)
	_ensure_button_icon_hover_animation(button)
	configure_relic_button_metrics(button, button.size.y if button.size.y > 0.0 else 36.0)

static func configure_relic_button_metrics(
	button: Button,
	button_height: float,
	icon_height_ratio: float = 2.0 / 3.0
) -> void:
	if button == null:
		return
	var icon_width := maxi(1, int(roundf(button_height * icon_height_ratio)))
	button.add_theme_constant_override("icon_max_width", icon_width)
	_configure_button_text_shift(button, float(icon_width))
	_layout_button_icon(button, icon_width, button_height)

static func get_button_icon(button: Button) -> TextureRect:
	if button == null:
		return null
	return button.get_node_or_null(NodePath(BUTTON_ICON_NODE_NAME)) as TextureRect

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

static func _layout_button_icon(button: Button, icon_size: float, button_height: float) -> void:
	var button_icon := get_button_icon(button)
	if button_icon == null:
		return
	# 同一列统一采用该列最大（2/3 按钮高度）的参考宽度，资源类小图标也会与操作图标共线。
	var column_reference := maxf(1.0, button_height * 2.0 / 3.0)
	var center_x := 4.0 + column_reference
	button_icon.size = Vector2(icon_size, icon_size)
	button_icon.custom_minimum_size = button_icon.size
	button_icon.position = Vector2(center_x - icon_size * 0.5, (button.size.y - icon_size) * 0.5)
	button_icon.pivot_offset = button_icon.size * 0.5

static func _configure_button_text_shift(button: Button, icon_size: float) -> void:
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		var style := button.get_theme_stylebox(state) as StyleBoxTexture
		if style == null:
			continue
		style.content_margin_left = 4.0 + maxf(1.0, icon_size)
		style.content_margin_right = 4.0

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
	var target_scale := Vector2.ONE * (BUTTON_ICON_HOVER_SCALE if hovered else 1.0)
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
	style.texture = load(texture_path) as Texture2D
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
