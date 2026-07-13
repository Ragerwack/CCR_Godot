extends Control
class_name PurpleCardDrawOverlay

signal presentation_finished

const CHARGE_DURATION: float = 0.45
const TELEPORT_DURATION: float = 0.30
const REMATERIALIZE_DURATION: float = 0.40
const SETTLE_DURATION: float = 0.35
const TOTAL_DURATION: float = CHARGE_DURATION + TELEPORT_DURATION + REMATERIALIZE_DURATION + SETTLE_DURATION

const PURPLE_LIGHTNING_COLOR := Color(0.72, 0.22, 1.0, 1.0)
const PURPLE_LIGHTNING_CORE_COLOR := Color(0.94, 0.78, 1.0, 1.0)

const ELECTRIC_RING_SHADER: String = """
shader_type canvas_item;

void fragment() {
	vec2 p = (UV - vec2(0.5)) * 2.0;
	float radius = length(p);
	float angle = atan(p.y, p.x);
	float ring = exp(-pow((radius - 0.56) / 0.045, 2.0));
	float outer_glow = exp(-pow((radius - 0.56) / 0.15, 2.0)) * 0.34;
	float arcs = pow(max(0.0, sin(angle * 11.0 + radius * 22.0)), 24.0);
	arcs *= smoothstep(0.34, 0.50, radius) * (1.0 - smoothstep(0.62, 0.82, radius));
	float alpha = clamp(ring + outer_glow + arcs * 0.75, 0.0, 1.0);
	vec3 purple = mix(vec3(0.38, 0.04, 0.78), vec3(0.93, 0.68, 1.0), ring + arcs);
	COLOR = vec4(purple, alpha) * COLOR;
}
"""

var _card: CardInfo
var _target_rect: Rect2
var _card_display: CardDisplay
var _electric_ring: ColorRect
var _bolt_glow: Line2D
var _bolt_core: Line2D
var _branch_bolts: Array[Line2D] = []
var _sequence: Tween

func setup(card: CardInfo, target_rect: Rect2) -> void:
	_card = card
	_target_rect = target_rect
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 2800

	_electric_ring = ColorRect.new()
	_electric_ring.name = "PurpleElectricRing"
	_electric_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_electric_ring.color = Color.WHITE
	var ring_shader := Shader.new()
	ring_shader.code = ELECTRIC_RING_SHADER
	var ring_material := ShaderMaterial.new()
	ring_material.shader = ring_shader
	_electric_ring.material = ring_material
	_electric_ring.modulate.a = 0.0
	add_child(_electric_ring)

	_bolt_glow = _make_bolt("PurpleBoltGlow", 13.0, Color(0.48, 0.04, 1.0, 0.42))
	add_child(_bolt_glow)
	_bolt_core = _make_bolt("PurpleBoltCore", 3.5, PURPLE_LIGHTNING_CORE_COLOR)
	add_child(_bolt_core)
	for i in range(2):
		var branch := _make_bolt("PurpleBoltBranch%d" % (i + 1), 2.2, PURPLE_LIGHTNING_COLOR)
		_branch_bolts.append(branch)
		add_child(branch)

	_card_display = CardDisplay.new()
	_card_display.name = "PurpleCardTeleport"
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
	var start_position := _hover_position()
	var target_position := _target_rect.position
	_card_display.position = start_position
	_card_display.pivot_offset = _card_display.size * 0.5
	_card_display.scale = Vector2(0.92, 0.92)

	var charge_start := maxf(0.0, delay)
	var teleport_start := charge_start + CHARGE_DURATION
	var rematerialize_start := teleport_start + TELEPORT_DURATION
	var settle_start := rematerialize_start + REMATERIALIZE_DURATION
	_sequence = create_tween().set_parallel(true)

	# 蓄能：卡牌在槽位上方浮现，目标槽周围只产生局部紫色电流。
	_sequence.tween_property(_card_display, "modulate:a", 1.0, CHARGE_DURATION * 0.34).set_delay(charge_start).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_sequence.tween_property(_card_display, "scale", Vector2.ONE, CHARGE_DURATION).set_delay(charge_start).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_sequence.tween_property(_electric_ring, "modulate:a", 0.82, CHARGE_DURATION * 0.58).set_delay(charge_start).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_sequence.tween_property(_electric_ring, "scale", Vector2.ONE, CHARGE_DURATION).set_delay(charge_start).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# 瞬移：紫色主雷击穿卡牌与卡槽，卡牌压缩为残光后消失。
	_sequence.tween_property(_bolt_glow, "modulate:a", 1.0, TELEPORT_DURATION * 0.16).set_delay(teleport_start).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_sequence.tween_property(_bolt_core, "modulate:a", 1.0, TELEPORT_DURATION * 0.10).set_delay(teleport_start).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	for branch in _branch_bolts:
		_sequence.tween_property(branch, "modulate:a", 0.90, TELEPORT_DURATION * 0.18).set_delay(teleport_start).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_sequence.tween_property(_card_display, "modulate", Color(0.86, 0.48, 1.0, 0.0), TELEPORT_DURATION * 0.72).set_delay(teleport_start + TELEPORT_DURATION * 0.12).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	_sequence.tween_property(_card_display, "scale", Vector2(0.10, 1.10), TELEPORT_DURATION * 0.72).set_delay(teleport_start + TELEPORT_DURATION * 0.12).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)

	# 重构：在雷光最亮时直接切换到槽位，不使用平滑飞行，以保持“瞬移”辨识度。
	_sequence.tween_callback(func():
		_card_display.position = target_position
		_card_display.scale = Vector2(1.16, 0.90)
		_card_display.modulate = Color(0.90, 0.62, 1.0, 0.0)
	).set_delay(rematerialize_start)
	_sequence.tween_property(_card_display, "modulate", Color.WHITE, REMATERIALIZE_DURATION * 0.52).set_delay(rematerialize_start).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_sequence.tween_property(_card_display, "scale", Vector2.ONE, REMATERIALIZE_DURATION).set_delay(rematerialize_start).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_sequence.tween_property(_electric_ring, "modulate:a", 1.0, REMATERIALIZE_DURATION * 0.22).set_delay(rematerialize_start).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_sequence.tween_property(_electric_ring, "scale", Vector2(1.24, 1.24), REMATERIALIZE_DURATION).set_delay(rematerialize_start).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)

	# 收束：雷电和槽位电环在最后 0.35 秒熄灭，真实卡槽随后接管显示。
	_sequence.tween_property(_bolt_glow, "modulate:a", 0.0, REMATERIALIZE_DURATION + SETTLE_DURATION).set_delay(rematerialize_start).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_sequence.tween_property(_bolt_core, "modulate:a", 0.0, REMATERIALIZE_DURATION * 0.72).set_delay(rematerialize_start).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	for branch in _branch_bolts:
		_sequence.tween_property(branch, "modulate:a", 0.0, REMATERIALIZE_DURATION * 0.60).set_delay(rematerialize_start).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_sequence.tween_property(_electric_ring, "modulate:a", 0.0, SETTLE_DURATION).set_delay(settle_start).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_sequence.finished.connect(_finish_presentation)

func cancel() -> void:
	if _sequence != null and _sequence.is_valid():
		_sequence.kill()
	_sequence = null
	queue_free()

func _make_bolt(node_name: String, bolt_width: float, bolt_color: Color) -> Line2D:
	var bolt := Line2D.new()
	bolt.name = node_name
	bolt.width = bolt_width
	bolt.default_color = bolt_color
	bolt.antialiased = true
	bolt.joint_mode = Line2D.LINE_JOINT_ROUND
	bolt.begin_cap_mode = Line2D.LINE_CAP_ROUND
	bolt.end_cap_mode = Line2D.LINE_CAP_ROUND
	bolt.modulate.a = 0.0
	return bolt

func _layout_effects() -> void:
	var card_size := _target_rect.size
	if card_size.x <= 0.0 or card_size.y <= 0.0:
		card_size = CardDisplay.CARD_SIZE
	_card_display.size = card_size
	_card_display.custom_minimum_size = card_size

	var ring_size := Vector2(card_size.x * 1.90, card_size.y * 1.45)
	_electric_ring.size = ring_size
	_electric_ring.position = _target_rect.get_center() - ring_size * 0.5
	_electric_ring.pivot_offset = ring_size * 0.5
	_electric_ring.scale = Vector2(0.58, 0.58)

	var start_center := _hover_position() + card_size * 0.5
	var target_center := _target_rect.get_center()
	var main_points := _jagged_points(start_center, target_center, 9, 17.0, 0)
	_bolt_glow.points = main_points
	_bolt_core.points = main_points
	_branch_bolts[0].points = _branch_points(main_points, 3, Vector2(-42.0, 18.0))
	_branch_bolts[1].points = _branch_points(main_points, 5, Vector2(38.0, 28.0))

func _hover_position() -> Vector2:
	return _target_rect.position - Vector2(0.0, _target_rect.size.y * 0.68 + 34.0)

func _jagged_points(start: Vector2, finish: Vector2, segments: int, amplitude: float, phase: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	var direction := finish - start
	var perpendicular := direction.normalized().orthogonal()
	for i in range(segments + 1):
		var ratio := float(i) / float(segments)
		var point := start.lerp(finish, ratio)
		if i > 0 and i < segments:
			var zigzag := -1.0 if (i + phase) % 2 == 0 else 1.0
			var taper := sin(ratio * PI)
			point += perpendicular * amplitude * zigzag * taper * (0.62 + float((i * 7 + phase) % 5) * 0.09)
		points.append(point)
	return points

func _branch_points(main_points: PackedVector2Array, origin_index: int, offset: Vector2) -> PackedVector2Array:
	var origin := main_points[origin_index]
	return _jagged_points(origin, origin + offset, 4, 7.0, origin_index)

func _finish_presentation() -> void:
	_sequence = null
	presentation_finished.emit()
	queue_free()
