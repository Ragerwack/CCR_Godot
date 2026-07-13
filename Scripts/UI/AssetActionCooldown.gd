extends Control
class_name AssetActionCooldown

const DEFAULT_DURATION_SECONDS: float = 0.5
const BASE_TINT: Color = Color(0.015, 0.055, 0.15, 0.50)
const SHADOW_COLOR: Color = Color(0.015, 0.095, 0.26, 0.78)
const SWEEP_EDGE_COLOR: Color = Color(0.48, 0.86, 1.0, 0.92)
const MASK_SHADER_CODE: String = """
shader_type canvas_item;

uniform sampler2D button_mask : source_color;
uniform bool use_texture_mask = false;
uniform float corner_radius_ratio = 0.22;
uniform vec2 cooldown_size = vec2(1.0);

float rounded_rect_mask(vec2 uv, vec2 target_size, float radius_ratio) {
	float shortest_side = max(min(target_size.x, target_size.y), 1.0);
	vec2 half_extent = target_size / shortest_side * 0.5;
	vec2 point = (uv - vec2(0.5)) * target_size / shortest_side;
	float radius = min(min(half_extent.x, half_extent.y) * radius_ratio, min(half_extent.x, half_extent.y));
	vec2 corner_distance = abs(point) - (half_extent - vec2(radius));
	float signed_distance = length(max(corner_distance, vec2(0.0))) + min(max(corner_distance.x, corner_distance.y), 0.0) - radius;
	return 1.0 - smoothstep(-0.75 / shortest_side, 0.75 / shortest_side, signed_distance);
}

void fragment() {
	float shape_alpha = rounded_rect_mask(UV, cooldown_size, corner_radius_ratio);
	if (use_texture_mask) {
		shape_alpha *= texture(button_mask, UV).a;
	}
	COLOR.a *= shape_alpha;
	if (COLOR.a <= 0.001) {
		discard;
	}
}
"""

var duration_seconds: float = DEFAULT_DURATION_SECONDS
var _started_msec: int = -1
var _mask_material: ShaderMaterial = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ensure_mask_material()
	_configure_parent_button_mask()
	_update_mask_geometry()
	visible = false
	set_process(false)
	resized.connect(_on_resized)


func _on_resized() -> void:
	_update_mask_geometry()
	queue_redraw()


func _ensure_mask_material() -> void:
	if _mask_material != null:
		return
	var shader := Shader.new()
	shader.code = MASK_SHADER_CODE
	_mask_material = ShaderMaterial.new()
	_mask_material.shader = shader
	material = _mask_material


func _configure_parent_button_mask() -> void:
	var button := get_parent() as Button
	if button == null:
		return
	var style := button.get_theme_stylebox("normal") as StyleBoxTexture
	if style != null and style.texture != null:
		set_button_mask(style.texture)


func set_button_mask(mask_texture: Texture2D) -> void:
	_ensure_mask_material()
	_mask_material.set_shader_parameter("button_mask", mask_texture)
	_mask_material.set_shader_parameter("use_texture_mask", mask_texture != null)


func _update_mask_geometry() -> void:
	_ensure_mask_material()
	_mask_material.set_shader_parameter("cooldown_size", size.max(Vector2.ONE))


func try_start() -> bool:
	if is_cooling_down():
		return false
	start()
	return true


func start() -> void:
	_configure_parent_button_mask()
	_update_mask_geometry()
	_started_msec = Time.get_ticks_msec()
	visible = true
	set_process(true)
	queue_redraw()


func is_cooling_down() -> bool:
	if _started_msec < 0:
		return false
	var elapsed := float(Time.get_ticks_msec() - _started_msec) / 1000.0
	return elapsed < duration_seconds


func remaining_ratio() -> float:
	if not is_cooling_down():
		return 0.0
	var elapsed := float(Time.get_ticks_msec() - _started_msec) / 1000.0
	return clampf(1.0 - elapsed / duration_seconds, 0.0, 1.0)


func _process(_delta: float) -> void:
	if not is_cooling_down():
		_started_msec = -1
		set_process(false)
		visible = false
	queue_redraw()


func _draw() -> void:
	var ratio := remaining_ratio()
	if ratio <= 0.0 or size.x <= 1.0 or size.y <= 1.0:
		return
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, BASE_TINT, true)
	_draw_remaining_sector(ratio)
	_draw_sweep_edge(ratio)


func _draw_remaining_sector(ratio: float) -> void:
	if ratio >= 0.995:
		draw_rect(Rect2(Vector2.ZERO, size), SHADOW_COLOR, true)
		return

	var center := size * 0.5
	var radius := size.length() * 0.72
	var start_angle := -PI * 0.5 + TAU * (1.0 - ratio)
	var end_angle := -PI * 0.5 + TAU
	var steps := maxi(8, int(72.0 * ratio))
	var points := PackedVector2Array()
	points.append(center)
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		var angle := lerpf(start_angle, end_angle, t)
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	draw_colored_polygon(points, SHADOW_COLOR)


func _draw_sweep_edge(ratio: float) -> void:
	var center := size * 0.5
	var angle := -PI * 0.5 + TAU * (1.0 - ratio)
	var endpoint := center + Vector2(cos(angle), sin(angle)) * size.length()
	draw_line(center, endpoint, SWEEP_EDGE_COLOR, 2.0, true)
