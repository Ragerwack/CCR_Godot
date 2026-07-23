extends Control
class_name OrangeCardDrawOverlay

signal presentation_finished

const SUN_GROW_DURATION: float = 1.0
const MAGIC_REVEAL_DURATION: float = 1.0
const CARD_FLY_DURATION: float = 0.5
const TOTAL_DURATION: float = SUN_GROW_DURATION + MAGIC_REVEAL_DURATION + CARD_FLY_DURATION
const MAGIC_CIRCLE_TEXTURE: Texture2D = preload("res://Resources/UI/VFX/orange_magic_circle.png")
const FIRE_RING_SFX_EVENT := "draw_orange_fire_ring"

const SUN_SHADER: String = """
shader_type canvas_item;

uniform float energy = 1.0;

void fragment() {
	vec2 p = (UV - vec2(0.5)) * 2.0;
	float radius = length(p);
	float angle = atan(p.y, p.x);
	float core = 1.0 - smoothstep(0.055, 0.24, radius);
	float corona = exp(-radius * 4.8) * 0.72;
	float long_rays = pow(max(0.0, cos(angle * 8.0)), 42.0) * exp(-radius * 2.15);
	float fine_rays = pow(max(0.0, cos(angle * 24.0 + 0.35)), 72.0) * exp(-radius * 2.8);
	float ray_mask = smoothstep(0.07, 0.25, radius) * (1.0 - smoothstep(0.25, 0.98, radius));
	float alpha = max(core, corona * 0.75) + (long_rays * 0.72 + fine_rays * 0.24) * ray_mask;
	vec3 warm_gold = mix(vec3(1.0, 0.42, 0.025), vec3(1.0, 0.96, 0.62), clamp(core + corona, 0.0, 1.0));
	COLOR = vec4(warm_gold * (0.78 + energy * 0.52), clamp(alpha * energy, 0.0, 1.0)) * COLOR;
}
"""

const HALO_SHADER: String = """
shader_type canvas_item;

uniform float ring_alpha = 1.0;

void fragment() {
	vec2 p = (UV - vec2(0.5)) * 2.0;
	float radius = length(p);
	float main_ring = exp(-pow((radius - 0.455) / 0.024, 2.0));
	float outer_glow = exp(-pow((radius - 0.455) / 0.075, 2.0)) * 0.42;
	float inner_ring = exp(-pow((radius - 0.385) / 0.012, 2.0)) * 0.38;
	float alpha = clamp(main_ring + outer_glow + inner_ring, 0.0, 1.0) * ring_alpha;
	vec3 gold = mix(vec3(1.0, 0.48, 0.035), vec3(1.0, 0.94, 0.58), main_ring);
	COLOR = vec4(gold, alpha) * COLOR;
}
"""

var _card: CardInfo
var _target_rect: Rect2
var _sun: ColorRect
var _halo: ColorRect
var _magic_circle: TextureRect
var _card_display: CardDisplay
var _sequence: Tween

func setup(card: CardInfo, target_rect: Rect2) -> void:
	_card = card
	_target_rect = target_rect
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 2900

	_sun = _make_shader_rect("OrangeDrawSun", SUN_SHADER)
	add_child(_sun)

	_halo = _make_shader_rect("OrangeDrawHalo", HALO_SHADER)
	_halo.modulate.a = 0.0
	add_child(_halo)

	_magic_circle = TextureRect.new()
	_magic_circle.name = "OrangeMagicCircle"
	_magic_circle.texture = MAGIC_CIRCLE_TEXTURE
	_magic_circle.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_magic_circle.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_magic_circle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_magic_circle.modulate = Color(1.0, 0.88, 0.48, 0.0)
	add_child(_magic_circle)

	_card_display = CardDisplay.new()
	_card_display.name = "OrangeCardReveal"
	_card_display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_display.hover_scale_enabled = false
	_card_display.modulate.a = 0.0
	add_child(_card_display)

func play(delay: float = 0.0) -> void:
	if _card_display == null or get_tree() == null:
		_finish_presentation()
		return
	_card_display.set_card(_card, -1)
	_layout_effects()
	var center_position := _centered_card_position()
	_card_display.position = center_position
	_card_display.pivot_offset = _card_display.size * 0.5
	_card_display.scale = Vector2(0.92, 0.92)
	_magic_circle.pivot_offset = _magic_circle.size * 0.5
	_magic_circle.scale = Vector2(0.72, 0.72)
	_halo.pivot_offset = _halo.size * 0.5

	var grow_start := maxf(0.0, delay)
	var magic_start := grow_start + SUN_GROW_DURATION
	var fly_start := magic_start + MAGIC_REVEAL_DURATION
	_sequence = create_tween().set_parallel(true)
	# 第一阶段：中心金点在一秒内成长为直径为屏幕高度 3/4 的太阳。
	_sequence.tween_property(_sun, "modulate:a", 1.0, SUN_GROW_DURATION * 0.12).set_delay(grow_start).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_sequence.tween_property(_sun, "scale", Vector2.ONE, SUN_GROW_DURATION).set_delay(grow_start).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	# 第二阶段：太阳释放一轮冲出屏幕的金色光圈，同时留下法阵与中央橙卡。
	_sequence.tween_callback(_play_fire_ring_sfx).set_delay(magic_start)
	_sequence.tween_property(_halo, "modulate:a", 1.0, MAGIC_REVEAL_DURATION * 0.12).set_delay(magic_start).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_sequence.tween_property(_halo, "scale", Vector2.ONE, MAGIC_REVEAL_DURATION * 0.78).set_delay(magic_start).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	_sequence.tween_property(_halo, "modulate:a", 0.0, MAGIC_REVEAL_DURATION * 0.38).set_delay(magic_start + MAGIC_REVEAL_DURATION * 0.62).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_sequence.tween_property(_sun, "modulate:a", 0.0, MAGIC_REVEAL_DURATION * 0.32).set_delay(magic_start).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_sequence.tween_property(_magic_circle, "modulate:a", 0.94, MAGIC_REVEAL_DURATION * 0.42).set_delay(magic_start + MAGIC_REVEAL_DURATION * 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_sequence.tween_property(_magic_circle, "scale", Vector2.ONE, MAGIC_REVEAL_DURATION * 0.56).set_delay(magic_start + MAGIC_REVEAL_DURATION * 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_sequence.tween_property(_magic_circle, "rotation", deg_to_rad(18.0), MAGIC_REVEAL_DURATION * 0.88).set_delay(magic_start + MAGIC_REVEAL_DURATION * 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_sequence.tween_property(_card_display, "modulate:a", 1.0, MAGIC_REVEAL_DURATION * 0.30).set_delay(magic_start + MAGIC_REVEAL_DURATION * 0.42).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_sequence.tween_property(_card_display, "scale", Vector2.ONE, MAGIC_REVEAL_DURATION * 0.34).set_delay(magic_start + MAGIC_REVEAL_DURATION * 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# 第三阶段：法阵消失，临时卡面精确飞向自己的真实槽位。
	_sequence.tween_property(_magic_circle, "modulate:a", 0.0, CARD_FLY_DURATION * 0.72).set_delay(fly_start).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_sequence.tween_property(_magic_circle, "scale", Vector2(1.08, 1.08), CARD_FLY_DURATION).set_delay(fly_start).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_sequence.tween_property(_card_display, "position", _target_rect.position, CARD_FLY_DURATION).set_delay(fly_start).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_sequence.tween_property(_card_display, "scale", Vector2.ONE, CARD_FLY_DURATION).set_delay(fly_start).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_sequence.finished.connect(_finish_presentation)

func cancel() -> void:
	if _sequence != null and _sequence.is_valid():
		_sequence.kill()
	_sequence = null
	queue_free()

func _play_fire_ring_sfx() -> void:
	AudioManager.play_sfx(FIRE_RING_SFX_EVENT, 1.0, 0.0)

func _make_shader_rect(node_name: String, shader_code: String) -> ColorRect:
	var rect := ColorRect.new()
	rect.name = node_name
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.color = Color.WHITE
	var shader := Shader.new()
	shader.code = shader_code
	var shader_material := ShaderMaterial.new()
	shader_material.shader = shader
	rect.material = shader_material
	return rect

func _layout_effects() -> void:
	var viewport_size := get_viewport_rect().size
	var sun_diameter := viewport_size.y * 0.75
	_sun.size = Vector2.ONE * sun_diameter
	_sun.position = (viewport_size - _sun.size) * 0.5
	_sun.pivot_offset = _sun.size * 0.5
	var point_scale := 6.0 / maxf(sun_diameter, 1.0)
	_sun.scale = Vector2.ONE * point_scale
	_sun.modulate.a = 0.0

	var halo_size := viewport_size.length() * 2.05
	_halo.size = Vector2.ONE * halo_size
	_halo.position = (viewport_size - _halo.size) * 0.5
	var halo_start_scale := sun_diameter / maxf(halo_size, 1.0)
	_halo.scale = Vector2.ONE * halo_start_scale

	var circle_size := minf(viewport_size.y * 0.72, viewport_size.x * 0.72)
	_magic_circle.size = Vector2.ONE * circle_size
	_magic_circle.position = (viewport_size - _magic_circle.size) * 0.5

	var card_size := _target_rect.size
	if card_size.x <= 0.0 or card_size.y <= 0.0:
		card_size = CardDisplay.CARD_SIZE
	_card_display.size = card_size
	_card_display.custom_minimum_size = card_size

func _centered_card_position() -> Vector2:
	return (get_viewport_rect().size - _card_display.size) * 0.5

func _finish_presentation() -> void:
	_sequence = null
	presentation_finished.emit()
	queue_free()
