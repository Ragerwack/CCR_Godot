extends Control
class_name BlackCardDrawOverlay

signal presentation_finished

const FADE_TO_BLACK_DURATION: float = 0.50
const BLACK_HOLE_REVEAL_DURATION: float = 0.50
const CARD_REVEAL_DURATION: float = 0.50
const CARD_FLY_DURATION: float = 0.50
const TOTAL_DURATION: float = FADE_TO_BLACK_DURATION + BLACK_HOLE_REVEAL_DURATION + CARD_REVEAL_DURATION + CARD_FLY_DURATION

const BLACK_HOLE_SHADER: String = """
shader_type canvas_item;

uniform float intensity = 1.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 p = (UV - vec2(0.5)) * 2.0;
	float radius = length(p);
	float angle = atan(p.y, p.x);
	float warped = radius + sin(angle * 4.0 - radius * 15.0) * 0.018;
	float outer_glow = exp(-pow((warped - 0.44) / 0.16, 2.0));
	float accretion = exp(-pow((warped - 0.31) / 0.055, 2.0));
	float hot_edge = exp(-pow((warped - 0.235) / 0.022, 2.0));
	float texture_noise = mix(0.72, 1.18, hash(floor((p + vec2(1.0)) * 52.0 + angle)));
	vec3 cold_glow = vec3(0.12, 0.20, 0.42) * outer_glow;
	vec3 ring = mix(vec3(0.18, 0.23, 0.55), vec3(0.95, 0.58, 0.20), smoothstep(-0.7, 0.8, p.y));
	vec3 color = cold_glow + ring * accretion * texture_noise + vec3(1.0, 0.82, 0.48) * hot_edge;
	float disc = 1.0 - smoothstep(0.205, 0.235, radius);
	color = mix(color, vec3(0.0), disc);
	float alpha = max(max(outer_glow * 0.62, accretion), max(hot_edge, disc * 0.98));
	alpha *= 1.0 - smoothstep(0.72, 0.98, radius);
	COLOR = vec4(color * intensity, alpha * intensity) * COLOR;
}
"""

var _background: ColorRect
var _black_hole: ColorRect
var _card_display: CardDisplay
var _card: CardInfo
var _target_rect: Rect2
var _sequence: Tween
var _audio_restore_requested: bool = false

func setup(card: CardInfo, target_rect: Rect2) -> void:
	_card = card
	_target_rect = target_rect
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 3000

	_background = ColorRect.new()
	_background.name = "BlackoutBackground"
	_background.set_anchors_preset(Control.PRESET_FULL_RECT)
	_background.color = Color(0, 0, 0, 0)
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_background)

	_black_hole = ColorRect.new()
	_black_hole.name = "BlackHole"
	_black_hole.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_black_hole.color = Color.WHITE
	var shader := Shader.new()
	shader.code = BLACK_HOLE_SHADER
	var black_hole_material := ShaderMaterial.new()
	black_hole_material.shader = shader
	_black_hole.material = black_hole_material
	_black_hole.modulate.a = 0.0
	add_child(_black_hole)

	_card_display = CardDisplay.new()
	_card_display.name = "BlackCardReveal"
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
	_card_display.scale = Vector2(0.025, 0.025)
	_card_display.pivot_offset = _card_display.size * 0.5
	_black_hole.scale = Vector2(0.35, 0.35)
	_black_hole.pivot_offset = _black_hole.size * 0.5

	# 使用绝对阶段延迟固定四段时间轴，避免 Tween 并行组的游标规则让后续阶段提前。
	var blackout_start := maxf(0.0, delay)
	var black_hole_start := blackout_start + FADE_TO_BLACK_DURATION
	var card_reveal_start := black_hole_start + BLACK_HOLE_REVEAL_DURATION
	var card_fly_start := card_reveal_start + CARD_REVEAL_DURATION
	_sequence = create_tween().set_parallel(true)
	_sequence.tween_callback(_begin_audio_silence).set_delay(blackout_start)
	_sequence.tween_property(_background, "color:a", 1.0, FADE_TO_BLACK_DURATION).set_delay(blackout_start).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_sequence.tween_callback(_play_black_hole_sfx).set_delay(black_hole_start)
	_sequence.tween_property(_black_hole, "modulate:a", 1.0, BLACK_HOLE_REVEAL_DURATION).set_delay(black_hole_start).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_sequence.tween_property(_black_hole, "scale", Vector2.ONE, BLACK_HOLE_REVEAL_DURATION).set_delay(black_hole_start).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_sequence.tween_property(_card_display, "modulate:a", 1.0, CARD_REVEAL_DURATION * 0.25).set_delay(card_reveal_start).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_sequence.tween_property(_card_display, "scale", Vector2.ONE, CARD_REVEAL_DURATION).set_delay(card_reveal_start).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_sequence.tween_callback(_begin_audio_restore).set_delay(card_fly_start)
	_sequence.tween_property(_background, "color:a", 0.0, CARD_FLY_DURATION).set_delay(card_fly_start).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_sequence.tween_property(_black_hole, "modulate:a", 0.0, CARD_FLY_DURATION * 0.65).set_delay(card_fly_start).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_sequence.tween_property(_card_display, "position", _target_rect.position, CARD_FLY_DURATION).set_delay(card_fly_start).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_sequence.finished.connect(_finish_presentation)

func cancel() -> void:
	if _sequence != null and _sequence.is_valid():
		_sequence.kill()
	_sequence = null
	_restore_audio_immediately()
	queue_free()

func _layout_effects() -> void:
	var viewport_size := get_viewport_rect().size
	var hole_size := maxf(280.0, minf(viewport_size.x, viewport_size.y) * 0.48)
	_black_hole.position = (viewport_size - Vector2.ONE * hole_size) * 0.5
	_black_hole.size = Vector2.ONE * hole_size
	var card_size := _target_rect.size
	if card_size.x <= 0.0 or card_size.y <= 0.0:
		card_size = CardDisplay.CARD_SIZE
	_card_display.size = card_size
	_card_display.custom_minimum_size = card_size

func _centered_card_position() -> Vector2:
	return (get_viewport_rect().size - _card_display.size) * 0.5

func _begin_audio_silence() -> void:
	if AudioManager != null:
		AudioManager.fade_all_audio_to_silence(FADE_TO_BLACK_DURATION)

func _play_black_hole_sfx() -> void:
	if AudioManager != null:
		AudioManager.play_cinematic_sfx("draw_black_hole", 1.0, 0.0)

func _begin_audio_restore() -> void:
	_audio_restore_requested = true
	if AudioManager != null:
		AudioManager.restore_all_audio(CARD_FLY_DURATION)

func _restore_audio_immediately() -> void:
	if AudioManager != null:
		AudioManager.restore_all_audio(0.0)

func _finish_presentation() -> void:
	_sequence = null
	if not _audio_restore_requested:
		_restore_audio_immediately()
	presentation_finished.emit()
	queue_free()
