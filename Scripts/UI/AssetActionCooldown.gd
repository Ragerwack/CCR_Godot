extends ColorRect
class_name AssetActionCooldown

signal cooldown_finished

const DEFAULT_DURATION_SECONDS: float = 0.5
const MASK_SHADER_CODE: String = """
shader_type canvas_item;

uniform sampler2D button_mask : source_color;
uniform bool use_texture_mask = false;
uniform float corner_radius_ratio = 0.22;
uniform vec2 cooldown_size = vec2(1.0);
uniform float remaining = 0.0;
uniform vec4 base_tint : source_color = vec4(0.015, 0.055, 0.15, 0.50);
uniform vec4 shadow_color : source_color = vec4(0.015, 0.095, 0.26, 0.78);
uniform vec4 sweep_edge_color : source_color = vec4(0.48, 0.86, 1.0, 0.92);

const float PI_VALUE = 3.14159265359;
const float TAU_VALUE = 6.28318530718;

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
	if (shape_alpha <= 0.001 || remaining <= 0.001) {
		discard;
	}

	vec2 pixel_point = (UV - vec2(0.5)) * cooldown_size;
	float clockwise_from_top = fract((atan(pixel_point.y, pixel_point.x) + PI_VALUE * 0.5) / TAU_VALUE);
	float elapsed = 1.0 - remaining;
	float sector = step(elapsed, clockwise_from_top);
	if (remaining >= 0.995) {
		sector = 1.0;
	}

	vec3 overlay_rgb = mix(base_tint.rgb, shadow_color.rgb, sector);
	float overlay_alpha = mix(base_tint.a, shadow_color.a, sector);
	float edge_angle = -PI_VALUE * 0.5 + TAU_VALUE * elapsed;
	vec2 edge_direction = vec2(cos(edge_angle), sin(edge_angle));
	float edge_projection = dot(pixel_point, edge_direction);
	float edge_distance = abs(pixel_point.x * edge_direction.y - pixel_point.y * edge_direction.x);
	float edge = (1.0 - smoothstep(1.0, 2.5, edge_distance)) * step(0.0, edge_projection);
	overlay_rgb = mix(overlay_rgb, sweep_edge_color.rgb, edge * sweep_edge_color.a);
	overlay_alpha = max(overlay_alpha, edge * sweep_edge_color.a);
	COLOR = vec4(overlay_rgb, overlay_alpha * shape_alpha);
}
"""

var duration_seconds: float = DEFAULT_DURATION_SECONDS
var _started_msec: int = -1
var _mask_material: ShaderMaterial = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	color = Color.WHITE
	_ensure_mask_material()
	_configure_parent_button_mask()
	_update_mask_geometry()
	_update_shader_progress(0.0)
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


func _update_shader_progress(ratio: float) -> void:
	_ensure_mask_material()
	_mask_material.set_shader_parameter("remaining", clampf(ratio, 0.0, 1.0))


func try_start() -> bool:
	if is_cooling_down():
		return false
	start()
	return true


func start() -> void:
	_configure_parent_button_mask()
	_update_mask_geometry()
	_started_msec = Time.get_ticks_msec()
	_update_shader_progress(1.0)
	visible = true
	set_process(true)


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
	var ratio := remaining_ratio()
	_update_shader_progress(ratio)
	if ratio <= 0.0:
		_finish_cooldown()


func _finish_cooldown() -> void:
	if _started_msec < 0:
		return
	_started_msec = -1
	set_process(false)
	visible = false
	_update_shader_progress(0.0)
	cooldown_finished.emit()
