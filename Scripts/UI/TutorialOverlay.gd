extends Control
class_name TutorialOverlay

const DIM_COLOR := Color(0.005, 0.012, 0.028, 0.72)
const BORDER_COLOR := Color(0.30, 0.84, 1.0, 0.95)
const BORDER_PADDING := 8.0
const MESSAGE_MAX_WIDTH := 520.0
const MESSAGE_MIN_WIDTH := 260.0
const MESSAGE_VIEWPORT_MARGIN := 16.0
const MESSAGE_TARGET_GAP := 24.0
const MESSAGE_PLACEMENT_AUTO := "auto"
const MESSAGE_PLACEMENT_LEFT := "left"

var _targets: Array[Control] = []
var _holes: Array[Rect2] = []
var _blockers: Array[Control] = []
var _message_key := ""
var _message_args: Array = []
var _message_placement := MESSAGE_PLACEMENT_AUTO
var _show_arrow := false
var _show_drag_path := false
var _elapsed := 0.0
var _notice_only := false
var _message_panel: Panel = null
var _message_label: Label = null

func _ready() -> void:
	_sync_to_viewport()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 4000
	_build_message_panel()
	if not Localization.locale_changed.is_connected(_on_locale_changed):
		Localization.locale_changed.connect(_on_locale_changed)
	set_process(true)
	_refresh_geometry()

func _on_locale_changed(_locale: String) -> void:
	_refresh_text()
	_refresh_geometry()

func configure(targets: Array[Control], message_key: String, message_args: Array = [], show_drag_path: bool = false, message_placement: String = MESSAGE_PLACEMENT_AUTO) -> void:
	_targets = targets.filter(func(node): return is_instance_valid(node) and node.is_visible_in_tree())
	_message_key = message_key
	_message_args = message_args.duplicate()
	_message_placement = message_placement if message_placement in [MESSAGE_PLACEMENT_AUTO, MESSAGE_PLACEMENT_LEFT] else MESSAGE_PLACEMENT_AUTO
	_show_drag_path = show_drag_path
	_notice_only = false
	_show_arrow = false
	_elapsed = 0.0
	visible = not _targets.is_empty()
	_refresh_text()
	_refresh_geometry()
	_focus_first_target.call_deferred()

func clear() -> void:
	_targets.clear()
	_holes.clear()
	_clear_blockers()
	visible = false
	_notice_only = false
	_message_placement = MESSAGE_PLACEMENT_AUTO
	queue_redraw()

func _process(delta: float) -> void:
	if not visible:
		return
	_elapsed += delta
	if _elapsed >= 6.0 and not _show_arrow:
		_show_arrow = true
	_refresh_geometry()
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_node_ready():
		_sync_to_viewport()
		_refresh_geometry()

func _sync_to_viewport() -> void:
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	position = Vector2.ZERO
	size = get_viewport_rect().size

func _draw() -> void:
	if not visible:
		return
	if _notice_only:
		return
	_draw_dim_cells()
	var pulse := 0.62 + sin(_elapsed * 3.2) * 0.24
	var pulse_color := BORDER_COLOR
	pulse_color.a = pulse
	for hole in _holes:
		draw_style_box(_border_style(pulse_color), hole)
	if _show_drag_path and _holes.size() >= 2:
		_draw_dashed_line(_holes[0].get_center(), _holes[1].get_center(), Color(0.48, 0.90, 1.0, 0.72), 3.0)
	if _show_arrow and not _holes.is_empty():
		_draw_arrow_to(_holes[0])

func _draw_dim_cells() -> void:
	var bounds := Rect2(Vector2.ZERO, size)
	if _holes.is_empty():
		draw_rect(bounds, DIM_COLOR)
		return
	var xs: Array[float] = [0.0, size.x]
	var ys: Array[float] = [0.0, size.y]
	for hole in _holes:
		xs.append(clampf(hole.position.x, 0.0, size.x))
		xs.append(clampf(hole.end.x, 0.0, size.x))
		ys.append(clampf(hole.position.y, 0.0, size.y))
		ys.append(clampf(hole.end.y, 0.0, size.y))
	xs.sort()
	ys.sort()
	for xi in range(xs.size() - 1):
		for yi in range(ys.size() - 1):
			var cell := Rect2(Vector2(xs[xi], ys[yi]), Vector2(xs[xi + 1] - xs[xi], ys[yi + 1] - ys[yi]))
			if cell.size.x <= 0.0 or cell.size.y <= 0.0 or _point_in_any_hole(cell.get_center()):
				continue
			draw_rect(cell, DIM_COLOR)

func _refresh_geometry() -> void:
	if not is_inside_tree():
		return
	var next_holes: Array[Rect2] = []
	var overlay_origin := global_position
	for target in _targets:
		if not is_instance_valid(target) or not target.is_visible_in_tree():
			continue
		var rect := target.get_global_rect()
		rect.position -= overlay_origin
		rect = rect.grow(BORDER_PADDING)
		next_holes.append(rect.intersection(Rect2(Vector2.ZERO, size)))
	var geometry_changed := _rect_list_changed(_holes, next_holes)
	_holes = next_holes
	if _notice_only:
		_clear_blockers()
	elif geometry_changed:
		_rebuild_blockers()
	_layout_message()
	queue_redraw()

func _rect_list_changed(previous: Array[Rect2], current: Array[Rect2]) -> bool:
	if previous.size() != current.size():
		return true
	for index in range(previous.size()):
		if not previous[index].is_equal_approx(current[index]):
			return true
	return false

func show_notice(message_key: String) -> void:
	_targets.clear()
	_holes.clear()
	_message_key = message_key
	_message_args = []
	_message_placement = MESSAGE_PLACEMENT_AUTO
	_notice_only = true
	visible = true
	_refresh_text()
	_clear_blockers()
	_message_panel.size = Vector2(minf(520.0, maxf(1.0, size.x - MESSAGE_VIEWPORT_MARGIN * 2.0)), minf(88.0, maxf(1.0, size.y - MESSAGE_VIEWPORT_MARGIN * 2.0)))
	_message_panel.position = Vector2(clampf((size.x - _message_panel.size.x) * 0.5, MESSAGE_VIEWPORT_MARGIN, maxf(MESSAGE_VIEWPORT_MARGIN, size.x - _message_panel.size.x - MESSAGE_VIEWPORT_MARGIN)), clampf(size.y * 0.18, MESSAGE_VIEWPORT_MARGIN, maxf(MESSAGE_VIEWPORT_MARGIN, size.y - _message_panel.size.y - MESSAGE_VIEWPORT_MARGIN)))
	queue_redraw()
	var timer := get_tree().create_timer(5.0)
	timer.timeout.connect(func():
		if _notice_only:
			clear()
	)

func _rebuild_blockers() -> void:
	_clear_blockers()
	var xs: Array[float] = [0.0, size.x]
	var ys: Array[float] = [0.0, size.y]
	for hole in _holes:
		xs.append(clampf(hole.position.x, 0.0, size.x))
		xs.append(clampf(hole.end.x, 0.0, size.x))
		ys.append(clampf(hole.position.y, 0.0, size.y))
		ys.append(clampf(hole.end.y, 0.0, size.y))
	xs.sort()
	ys.sort()
	for xi in range(xs.size() - 1):
		for yi in range(ys.size() - 1):
			var rect := Rect2(Vector2(xs[xi], ys[yi]), Vector2(xs[xi + 1] - xs[xi], ys[yi + 1] - ys[yi]))
			if rect.size.x <= 0.0 or rect.size.y <= 0.0 or _point_in_any_hole(rect.get_center()):
				continue
			var blocker := Control.new()
			blocker.position = rect.position
			blocker.size = rect.size
			blocker.mouse_filter = Control.MOUSE_FILTER_STOP
			blocker.focus_mode = Control.FOCUS_NONE
			add_child(blocker)
			move_child(blocker, 0)
			_blockers.append(blocker)

func _clear_blockers() -> void:
	for blocker in _blockers:
		if is_instance_valid(blocker):
			blocker.queue_free()
	_blockers.clear()

func _point_in_any_hole(point: Vector2) -> bool:
	for hole in _holes:
		if hole.has_point(point):
			return true
	return false

func _build_message_panel() -> void:
	_message_panel = Panel.new()
	_message_panel.name = "TutorialMessagePanel"
	_message_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_message_panel.z_index = 2
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.045, 0.085, 0.96)
	style.border_color = Color(0.36, 0.78, 1.0, 0.88)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	_message_panel.add_theme_stylebox_override("panel", style)
	add_child(_message_panel)

	_message_label = Label.new()
	_message_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message_label.add_theme_font_size_override("font_size", 22)
	_message_label.add_theme_color_override("font_color", Color(0.88, 0.96, 1.0))
	_message_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_message_panel.add_child(_message_label)

func _refresh_text() -> void:
	if _message_label != null:
		_message_label.text = Localization.t(_message_key, _message_args)

func _layout_message() -> void:
	if _notice_only or _message_panel == null or _holes.is_empty():
		return
	var available_width := maxf(1.0, size.x - MESSAGE_VIEWPORT_MARGIN * 2.0)
	var available_height := maxf(1.0, size.y - MESSAGE_VIEWPORT_MARGIN * 2.0)
	var text_wrap_width := maxf(1.0, minf(MESSAGE_MAX_WIDTH, available_width) - 44.0)
	var text_size := _message_label.get_theme_font("font").get_multiline_string_size(
		_message_label.text,
		HORIZONTAL_ALIGNMENT_CENTER,
		text_wrap_width,
		_message_label.get_theme_font_size("font_size")
	)
	var requested_width := clampf(text_size.x + 44.0, minf(MESSAGE_MIN_WIDTH, available_width), minf(MESSAGE_MAX_WIDTH, available_width))
	_message_panel.size = Vector2(minf(requested_width, available_width), minf(maxf(72.0, text_size.y + 32.0), available_height))
	var target := _holes[0]
	var x := 0.0
	var y := 0.0
	if _message_placement == MESSAGE_PLACEMENT_LEFT:
		x = target.position.x - _message_panel.size.x - MESSAGE_TARGET_GAP
		y = target.get_center().y - _message_panel.size.y * 0.5
	else:
		var above_y := target.position.y - _message_panel.size.y - MESSAGE_TARGET_GAP
		y = above_y if above_y >= MESSAGE_VIEWPORT_MARGIN else target.end.y + MESSAGE_TARGET_GAP
		x = target.get_center().x - _message_panel.size.x * 0.5
	x = clampf(x, MESSAGE_VIEWPORT_MARGIN, maxf(MESSAGE_VIEWPORT_MARGIN, size.x - _message_panel.size.x - MESSAGE_VIEWPORT_MARGIN))
	y = clampf(y, MESSAGE_VIEWPORT_MARGIN, maxf(MESSAGE_VIEWPORT_MARGIN, size.y - _message_panel.size.y - MESSAGE_VIEWPORT_MARGIN))
	_message_panel.position = Vector2(x, y)

func _border_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.border_color = color
	style.set_border_width_all(4)
	style.set_corner_radius_all(12)
	return style

func _draw_dashed_line(from: Vector2, to: Vector2, color: Color, width: float) -> void:
	var distance := from.distance_to(to)
	if distance <= 1.0:
		return
	var direction := (to - from) / distance
	var cursor := 0.0
	while cursor < distance:
		var segment_end := minf(distance, cursor + 14.0)
		draw_line(from + direction * cursor, from + direction * segment_end, color, width, true)
		cursor += 24.0

func _draw_arrow_to(hole: Rect2) -> void:
	var target := hole.get_center()
	var start := target + Vector2(0, -maxf(54.0, hole.size.y * 0.65))
	draw_line(start, target - Vector2(0, 12), BORDER_COLOR, 5.0, true)
	draw_colored_polygon(PackedVector2Array([target, target + Vector2(-11, -18), target + Vector2(11, -18)]), BORDER_COLOR)

func _focus_first_target() -> void:
	if _targets.is_empty():
		return
	var first := _targets[0]
	if is_instance_valid(first) and first.focus_mode != Control.FOCUS_NONE:
		first.grab_focus()
