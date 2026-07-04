extends Control
class_name SynthesisAnimationOverlay

const CardDisplayScript = preload("res://Scripts/UI/CardDisplay.gd")
const RelicViewScene = preload("res://Scenes/UI/RelicView.tscn")
const CCRVisualStyle = preload("res://Scripts/UI/CCRVisualStyle.gd")

const CARD_FLOAT_DURATION: float = 0.31
const SURFACE_DISSOLVE_DURATION: float = 0.30
const ART_MIN_FLIGHT: float = 0.90
const ART_MAX_FLIGHT: float = 1.30
const ART_FLIGHT_INTERVAL: float = 0.10
const RELIC_FORM_DURATION: float = 0.30
const RELIC_HOLD_DURATION: float = 0.50
const RELIC_TO_NAV_DURATION: float = 0.50
const RELIC_SCALE_MULTIPLIER: float = 1.30
const RELIC_SCREEN_HEIGHT_RATIO: float = (3.0 / 5.0) * RELIC_SCALE_MULTIPLIER
const SINGLE_CARD_FADE_DURATION: float = 0.50

var _sources: Array[Dictionary] = []
var _cards: Array = []
var _color_type: int = CardColor.ColorType.WHITE
var _nav_target_rect: Rect2 = Rect2()
var _relic_rect: Rect2 = Rect2()
var _rng := RandomNumberGenerator.new()


func setup(sources: Array[Dictionary], nav_target_rect: Rect2) -> void:
	_sources = sources.duplicate(true)
	_nav_target_rect = nav_target_rect
	_cards.clear()
	for source in _sources:
		var card = source.get("card")
		if card is CardInfo:
			_cards.append(card)
			_color_type = int(card.color)


func play() -> void:
	_rng.randomize()
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)
	z_index = 3000
	await get_tree().process_frame
	if _sources.is_empty():
		queue_free()
		return

	var card_nodes := _create_card_nodes()
	await get_tree().process_frame
	_bind_card_nodes(card_nodes)
	await _float_cards(card_nodes)
	var art_nodes := await _dissolve_to_art(card_nodes)
	_relic_rect = _get_centered_relic_rect()
	await _fly_art_to_relic_slots(art_nodes, _relic_rect)
	var relic := await _form_relic(art_nodes)
	await _hold_relic_before_nav(relic)
	await _send_relic_to_nav(relic)
	queue_free()


func play_store_to_nav() -> void:
	_rng.randomize()
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)
	z_index = 3000
	await get_tree().process_frame
	var card_nodes := _create_card_nodes()
	await get_tree().process_frame
	_bind_card_nodes(card_nodes)
	await _float_cards(card_nodes)
	for node in card_nodes:
		await _send_card_to_nav(node)
	queue_free()


func play_discard() -> void:
	_rng.randomize()
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)
	z_index = 3000
	await get_tree().process_frame
	var card_nodes := _create_card_nodes()
	await get_tree().process_frame
	_bind_card_nodes(card_nodes)
	await _float_cards(card_nodes)
	await _fade_cards_out(card_nodes)
	queue_free()


func _create_card_nodes() -> Array[Control]:
	var viewport_size := get_viewport_rect().size
	var result: Array[Control] = []
	for i in range(_sources.size()):
		var source: Dictionary = _sources[i]
		var card: CardInfo = source.get("card")
		if card == null:
			continue
		var rect: Rect2 = source.get("global_rect", Rect2())
		if rect.size.x <= 1.0 or rect.size.y <= 1.0:
			var fallback_size := CardDisplay.CARD_SIZE
			rect = Rect2(
				Vector2(
					_rng.randf_range(viewport_size.x * 0.15, viewport_size.x * 0.85),
					_rng.randf_range(viewport_size.y + 20.0, viewport_size.y * 1.5)
				),
				fallback_size
			)
		var display := CardDisplayScript.new() as CardDisplay
		display.name = "SynthesisCard%d" % (i + 1)
		display.hover_uses_slot_bounds = false
		display.hover_scale_enabled = false
		display.is_draggable = false
		display.position = rect.position
		display.size = rect.size
		display.custom_minimum_size = rect.size
		display.pivot_offset = rect.size * 0.5
		display.set_meta("synthesis_card", card)
		display.set_meta("synthesis_index", i)
		add_child(display)
		result.append(display)
	return result


func _bind_card_nodes(card_nodes: Array[Control]) -> void:
	for node in card_nodes:
		if not is_instance_valid(node):
			continue
		var display := node as CardDisplay
		if display == null:
			continue
		var card = display.get_meta("synthesis_card")
		var index := int(display.get_meta("synthesis_index", -1))
		if card is CardInfo:
			display.set_card(card, index)


func _float_cards(card_nodes: Array[Control]) -> void:
	for i in range(card_nodes.size()):
		var node := card_nodes[i]
		if not is_instance_valid(node):
			continue
		var lift := maxf(72.0, node.size.y * 0.55)
		var drift := (float(i) - 2.0) * 14.0
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(node, "position", node.position + Vector2(drift, -lift), CARD_FLOAT_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(node, "rotation_degrees", (float(i) - 2.0) * 2.0, CARD_FLOAT_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(CARD_FLOAT_DURATION).timeout


func _dissolve_to_art(card_nodes: Array[Control]) -> Array[TextureRect]:
	var art_nodes: Array[TextureRect] = []
	for node in card_nodes:
		if not is_instance_valid(node):
			continue
		var display := node as CardDisplay
		var art_rect := display.get_art_rect()
		var art := TextureRect.new()
		art.name = "SynthesisArt"
		art.position = display.position + art_rect.position
		art.size = art_rect.size
		art.texture = display.get_art_texture()
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art.clip_contents = true
		art.pivot_offset = art.size * 0.5
		var shadow := CCRVisualStyle.make_texture_shadow(art, "SynthesisArtShadow", Vector2(8, 10), Color(0, 0, 0, 0.34))
		add_child(shadow)
		add_child(art)
		art.set_meta("shadow", shadow)
		art_nodes.append(art)

		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(display, "modulate:a", 0.0, SURFACE_DISSOLVE_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tween.tween_property(display, "scale", Vector2(1.04, 1.04), SURFACE_DISSOLVE_DURATION)
	await get_tree().create_timer(SURFACE_DISSOLVE_DURATION).timeout
	for node in card_nodes:
		if is_instance_valid(node):
			node.queue_free()
	return art_nodes


func _fly_art_to_relic_slots(art_nodes: Array[TextureRect], relic_rect: Rect2) -> void:
	var target_rects := _get_relic_slot_rects(relic_rect)
	for i in range(art_nodes.size()):
		var art := art_nodes[i]
		if not is_instance_valid(art):
			continue
		var duration := lerpf(ART_MIN_FLIGHT, ART_MAX_FLIGHT, float(i) / maxf(float(art_nodes.size() - 1), 1.0))
		var target_rect := Rect2(relic_rect.get_center() - art.size * 0.5, art.size)
		if i < target_rects.size():
			target_rect = target_rects[i]
		var start_pos := art.position
		var start_size := art.size
		var away := (start_pos + start_size * 0.5 - target_rect.get_center()).normalized()
		if away.length() <= 0.01:
			away = Vector2(0.0, -1.0).rotated(_rng.randf_range(-0.8, 0.8))
		var side := away.rotated((PI * 0.5) * (-1.0 if i % 2 == 0 else 1.0))
		var away_distance := maxf(120.0, get_viewport_rect().size.y * 0.18)
		var loop_distance := maxf(180.0, get_viewport_rect().size.y * 0.24)
		var control_a := start_pos + away * away_distance + side * 42.0
		var control_b := target_rect.position + away * loop_distance + side * 130.0
		var delay := float(i) * ART_FLIGHT_INTERVAL
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_method(func(t: float):
			if is_instance_valid(art):
				var next_pos := _cubic_bezier(start_pos, control_a, control_b, target_rect.position, t)
				art.position = next_pos
				art.pivot_offset = art.size * 0.5
				var shadow = art.get_meta("shadow", null)
				if shadow is TextureRect and is_instance_valid(shadow):
					shadow.position = next_pos + Vector2(8, 10)
		, 0.0, 1.0, duration).set_delay(delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_property(art, "size", target_rect.size, duration).set_delay(delay)
		var shadow = art.get_meta("shadow", null)
		if shadow is TextureRect and is_instance_valid(shadow):
			tween.tween_property(shadow, "size", target_rect.size, duration).set_delay(delay)
	await get_tree().create_timer(ART_FLIGHT_INTERVAL * maxf(float(art_nodes.size() - 1), 0.0) + ART_MAX_FLIGHT).timeout


func _form_relic(art_nodes: Array[TextureRect]) -> Control:
	var relic := RelicViewScene.instantiate() as RelicView
	relic.set_relic_color(_color_type)
	if _relic_rect.size.x <= 1.0 or _relic_rect.size.y <= 1.0:
		_relic_rect = _get_centered_relic_rect()
	relic.name = "SynthesisRelic"
	relic.position = _relic_rect.position
	relic.size = _relic_rect.size
	relic.custom_minimum_size = relic.size
	relic.modulate.a = 0.0
	relic.scale = Vector2(0.82, 0.82)
	relic.pivot_offset = relic.size * 0.5
	add_child(relic)
	relic.set_cards(_cards)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(relic, "modulate:a", 1.0, RELIC_FORM_DURATION)
	tween.tween_property(relic, "scale", Vector2.ONE, RELIC_FORM_DURATION).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for art in art_nodes:
		if is_instance_valid(art):
			tween.tween_property(art, "modulate:a", 0.0, RELIC_FORM_DURATION * 0.7)
			var shadow = art.get_meta("shadow", null)
			if shadow is TextureRect and is_instance_valid(shadow):
				tween.tween_property(shadow, "modulate:a", 0.0, RELIC_FORM_DURATION * 0.7)
	await get_tree().create_timer(RELIC_FORM_DURATION).timeout
	for art in art_nodes:
		if is_instance_valid(art):
			var shadow = art.get_meta("shadow", null)
			if shadow is TextureRect and is_instance_valid(shadow):
				shadow.queue_free()
			art.queue_free()
	return relic


func _hold_relic_before_nav(relic: Control) -> void:
	if not is_instance_valid(relic):
		return
	await get_tree().create_timer(RELIC_HOLD_DURATION).timeout


func _get_centered_relic_rect() -> Rect2:
	var relic := RelicViewScene.instantiate() as RelicView
	var color_ok := relic.set_relic_color(_color_type)
	var viewport_size := get_viewport_rect().size
	var relic_height := viewport_size.y * RELIC_SCREEN_HEIGHT_RATIO
	var relic_width := relic_height * (relic.get_aspect_ratio() if color_ok else 0.40)
	relic.free()
	return Rect2(viewport_size * 0.5 - Vector2(relic_width, relic_height) * 0.5, Vector2(relic_width, relic_height))


func _get_relic_slot_rects(relic_rect: Rect2) -> Array[Rect2]:
	var layout_path := RelicView.get_layout_path(_color_type)
	if layout_path == "":
		return []
	var file := FileAccess.open(layout_path, FileAccess.READ)
	if file == null:
		return []
	var parsed = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		return []
	var slots: Array = parsed.get("slots", [])
	slots.sort_custom(func(a: Dictionary, b: Dictionary): return int(a.get("id", 0)) < int(b.get("id", 0)))
	var rects: Array[Rect2] = []
	for slot in slots:
		var pos := relic_rect.position + Vector2(
			relic_rect.size.x * float(slot.get("x_ratio", 0.0)),
			relic_rect.size.y * float(slot.get("y_ratio", 0.0))
		)
		var size := Vector2(
			relic_rect.size.x * float(slot.get("width_ratio", 0.0)),
			relic_rect.size.y * float(slot.get("height_ratio", 0.0))
		)
		rects.append(Rect2(pos, size))
	return rects


func _send_card_to_nav(card_node: Control) -> void:
	if not is_instance_valid(card_node):
		return
	var target_center := _nav_target_rect.get_center()
	if _nav_target_rect.size.x <= 1.0 or _nav_target_rect.size.y <= 1.0:
		target_center = Vector2(60.0, get_viewport_rect().size.y * 0.5)
	var target_height := maxf(_nav_target_rect.size.y, 36.0)
	var target_scale := target_height / maxf(card_node.size.y, 1.0)
	var target_pos := target_center - card_node.size * target_scale * 0.5
	var start_pos := card_node.position
	var control := (start_pos + target_pos) * 0.5 + Vector2(_rng.randf_range(-100.0, 100.0), -maxf(100.0, get_viewport_rect().size.y * 0.16))
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_method(func(t: float):
		if is_instance_valid(card_node):
			card_node.position = _quadratic_bezier(start_pos, control, target_pos, t)
	, 0.0, 1.0, RELIC_TO_NAV_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(card_node, "scale", Vector2(target_scale, target_scale), RELIC_TO_NAV_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(card_node, "modulate:a", 0.0, RELIC_TO_NAV_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tween.finished
	if is_instance_valid(card_node):
		card_node.queue_free()


func _fade_cards_out(card_nodes: Array[Control]) -> void:
	for node in card_nodes:
		if not is_instance_valid(node):
			continue
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(node, "modulate:a", 0.0, SINGLE_CARD_FADE_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tween.tween_property(node, "scale", Vector2(1.08, 1.08), SINGLE_CARD_FADE_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(SINGLE_CARD_FADE_DURATION).timeout
	for node in card_nodes:
		if is_instance_valid(node):
			node.queue_free()


func _send_relic_to_nav(relic: Control) -> void:
	if not is_instance_valid(relic):
		return
	var target_center := _nav_target_rect.get_center()
	if _nav_target_rect.size.x <= 1.0 or _nav_target_rect.size.y <= 1.0:
		target_center = Vector2(60.0, get_viewport_rect().size.y * 0.5)
	var target_height := maxf(_nav_target_rect.size.y, 36.0)
	var target_scale := target_height / maxf(relic.size.y, 1.0)
	var target_pos := target_center - relic.size * target_scale * 0.5
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(relic, "position", target_pos, RELIC_TO_NAV_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(relic, "scale", Vector2(target_scale, target_scale), RELIC_TO_NAV_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(relic, "modulate:a", 0.0, RELIC_TO_NAV_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tween.finished


func _create_light(color: Color) -> Control:
	var host := Control.new()
	host.name = "SynthesisLight"
	host.size = Vector2(54, 54)
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in range(3):
		var ray := ColorRect.new()
		ray.position = Vector2(25, 3)
		ray.size = Vector2(4, 48)
		ray.color = Color(color.r, color.g, color.b, 0.34 - float(i) * 0.07)
		ray.pivot_offset = Vector2(2, 24)
		ray.rotation_degrees = 60.0 * float(i)
		host.add_child(ray)
	var core := ColorRect.new()
	core.position = Vector2(17, 17)
	core.size = Vector2(20, 20)
	core.color = Color(color.r, color.g, color.b, 0.95)
	host.add_child(core)
	var spark := ColorRect.new()
	spark.position = Vector2(24, 6)
	spark.size = Vector2(6, 42)
	spark.color = Color(1, 1, 1, 0.68)
	spark.pivot_offset = Vector2(3, 21)
	spark.rotation_degrees = 35
	host.add_child(spark)
	return host


func _pulse_light(light: Control, delay: float) -> void:
	if not is_instance_valid(light):
		return
	var tween := create_tween()
	tween.set_loops(4)
	tween.tween_interval(delay)
	tween.tween_property(light, "scale", Vector2(1.18, 1.18), 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(light, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


func _quadratic_bezier(a: Vector2, b: Vector2, c: Vector2, t: float) -> Vector2:
	var p := clampf(t, 0.0, 1.0)
	return a * (1.0 - p) * (1.0 - p) + b * 2.0 * (1.0 - p) * p + c * p * p


func _cubic_bezier(a: Vector2, b: Vector2, c: Vector2, d: Vector2, t: float) -> Vector2:
	var p := clampf(t, 0.0, 1.0)
	var q := 1.0 - p
	return a * q * q * q + b * 3.0 * q * q * p + c * 3.0 * q * p * p + d * p * p * p


func _color_for_card_color(color_type: int) -> Color:
	match color_type:
		CardColor.ColorType.WHITE: return Color(0.92, 0.95, 1.0, 1.0)
		CardColor.ColorType.GREEN: return Color(0.32, 1.0, 0.54, 1.0)
		CardColor.ColorType.BLUE: return Color(0.34, 0.68, 1.0, 1.0)
		CardColor.ColorType.PURPLE: return Color(0.78, 0.35, 1.0, 1.0)
		CardColor.ColorType.ORANGE: return Color(1.0, 0.62, 0.16, 1.0)
		CardColor.ColorType.BLACK: return Color(0.58, 0.58, 0.70, 1.0)
		CardColor.ColorType.RED: return Color(1.0, 0.20, 0.18, 1.0)
	return Color.WHITE
