extends RefCounted
class_name CCRVisualStyle

const TEXT_DARK := Color(0.075, 0.095, 0.125, 1.0)
const TEXT_DARK_MUTED := Color(0.20, 0.235, 0.28, 1.0)
const TEXT_DARK_GOLD := Color(0.42, 0.315, 0.08, 1.0)
const TEXT_ERROR := Color(0.70, 0.08, 0.08, 1.0)
const CARD_SHADOW := Color(0.0, 0.0, 0.0, 0.36)
const RELIC_SHADOW := Color(0.0, 0.0, 0.0, 0.42)
const BUTTON_ICON_NODE_NAME := "CCRButtonIcon"
const BUTTON_ICON_HOVER_SCALE := 1.5
const BUTTON_ICON_HOVER_SECONDS := 0.4

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
	"vault_expand_gold": "res://Resources/UI/Icons/Vault/vault_expand_gold.png",
	"vault_expand_gem": "res://Resources/UI/Icons/Vault/vault_expand_gem.png",
	"status_stamina": "res://Resources/UI/Icons/Status/status_stamina.png",
	"status_gold": "res://Resources/UI/Icons/Status/status_gold.png",
	"status_gem": "res://Resources/UI/Icons/Status/status_gem.png",
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
