extends RefCounted
class_name CCRVisualStyle

const TEXT_DARK := Color(0.075, 0.095, 0.125, 1.0)
const TEXT_DARK_MUTED := Color(0.20, 0.235, 0.28, 1.0)
const TEXT_DARK_GOLD := Color(0.42, 0.315, 0.08, 1.0)
const TEXT_ERROR := Color(0.70, 0.08, 0.08, 1.0)
const CARD_SHADOW := Color(0.0, 0.0, 0.0, 0.36)
const RELIC_SHADOW := Color(0.0, 0.0, 0.0, 0.42)

static func apply_dark_label(label: Label, color: Color = TEXT_DARK) -> void:
	if label == null:
		return
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(1.0, 1.0, 1.0, 0.35))
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", 1)

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
