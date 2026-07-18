extends Control
class_name ExpBarUI

const CCRVisualStyle = preload("res://Scripts/UI/CCRVisualStyle.gd")

const STYLE_ID := "archive_ruler_c"
const BAR_HEIGHT_RATIO: float = 0.024
const MIN_BAR_HEIGHT: int = 16
const MAX_BAR_HEIGHT: int = 24
const BAR_PADDING: int = 2
const RULER_HEIGHT: float = 4.0
const GLOW_DURATION: float = 3.0

const ARCHIVE_BASE := Color(0.86, 0.81, 0.69, 0.94)
const ARCHIVE_BASE_HIGHLIGHT := Color(0.97, 0.94, 0.84, 0.86)
const ARCHIVE_BORDER := Color(0.37, 0.29, 0.17, 0.64)
const ARCHIVE_TICK := Color(0.30, 0.25, 0.17, 0.34)
const TRACK_DARK := Color(0.54, 0.50, 0.42, 0.78)
const TRACK_LIGHT := Color(0.90, 0.86, 0.75, 0.62)
const FILL_START := Color(0.25, 0.41, 0.49, 0.94)
const FILL_END := Color(0.58, 0.78, 0.78, 0.94)
const FILL_EDGE := Color(0.98, 0.91, 0.63, 0.92)
const TEXT_COLOR := Color(0.10, 0.12, 0.14, 1.0)
const TEXT_SHADOW := Color(1.0, 0.97, 0.86, 0.55)

var _label: Label
var _glow_tween: Tween
var _current_ratio: float = 0.0
var _glow_alpha: float = 0.0

func _ready() -> void:
	var vp := get_viewport_rect().size
	var bar_h := clampi(int(vp.y * BAR_HEIGHT_RATIO), MIN_BAR_HEIGHT, MAX_BAR_HEIGHT)
	anchor_left = 0.0
	anchor_top = 1.0
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_left = 0
	offset_top = -bar_h
	offset_right = 0
	offset_bottom = 0
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	setup_ui()
	_start_glow_animation()

	GameManager.player_data.changed.connect(_on_player_data_changed)
	GameManager.data_synced.connect(_on_data_synced)
	refresh()

func setup_ui() -> void:
	var value_center := CenterContainer.new()
	value_center.name = "ExpValueCenter"
	value_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	value_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(value_center)

	var value_row := HBoxContainer.new()
	value_row.name = "ExpValueRow"
	value_row.alignment = BoxContainer.ALIGNMENT_CENTER
	value_row.add_theme_constant_override("separation", 2)
	value_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	value_row.add_child(CCRVisualStyle.make_status_icon("status_experience", "ExperienceIcon", 14.0))

	_label = Label.new()
	_label.name = "ExpValueLabel"
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 11)
	_label.add_theme_color_override("font_color", TEXT_COLOR)
	_label.add_theme_color_override("font_shadow_color", TEXT_SHADOW)
	_label.add_theme_constant_override("shadow_offset_x", 0)
	_label.add_theme_constant_override("shadow_offset_y", 1)
	value_row.add_child(_label)
	value_center.add_child(value_row)

func get_style_id() -> String:
	return STYLE_ID

func get_current_ratio() -> float:
	return _current_ratio

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()

func _draw() -> void:
	var full_rect := Rect2(Vector2.ZERO, size)
	if full_rect.size.x <= 0.0 or full_rect.size.y <= 0.0:
		return
	_draw_archive_base(full_rect)
	_draw_ruler(full_rect)
	_draw_track_and_fill(_track_rect(full_rect))

func _draw_archive_base(full_rect: Rect2) -> void:
	var base_style := StyleBoxFlat.new()
	base_style.bg_color = ARCHIVE_BASE
	base_style.border_color = ARCHIVE_BORDER
	base_style.set_border_width_all(1)
	base_style.set_corner_radius_all(0)
	base_style.shadow_color = Color(0.0, 0.0, 0.0, 0.22)
	base_style.shadow_size = 5
	base_style.shadow_offset = Vector2(0, -1)
	draw_style_box(base_style, full_rect)
	draw_rect(Rect2(Vector2(0, 1), Vector2(full_rect.size.x, 1)), ARCHIVE_BASE_HIGHLIGHT, true)

func _draw_ruler(full_rect: Rect2) -> void:
	var left := BAR_PADDING + 10.0
	var right := maxf(left, full_rect.size.x - BAR_PADDING - 10.0)
	var top := 1.0
	for index in range(11):
		var x := lerpf(left, right, float(index) / 10.0)
		var tick_h := RULER_HEIGHT if index % 5 == 0 else RULER_HEIGHT - 1.5
		draw_line(Vector2(x, top), Vector2(x, top + tick_h), ARCHIVE_TICK, 1.0)
	draw_line(Vector2(left, top), Vector2(right, top), Color(0.30, 0.25, 0.17, 0.22), 1.0)

func _draw_track_and_fill(track_rect: Rect2) -> void:
	if track_rect.size.x <= 0.0 or track_rect.size.y <= 0.0:
		return
	var track_style := StyleBoxFlat.new()
	track_style.bg_color = TRACK_LIGHT
	track_style.border_color = ARCHIVE_BORDER
	track_style.set_border_width_all(1)
	track_style.set_corner_radius_all(5)
	draw_style_box(track_style, track_rect)
	draw_rect(Rect2(track_rect.position + Vector2(1, track_rect.size.y - 2), Vector2(maxf(0.0, track_rect.size.x - 2), 1)), TRACK_DARK, true)

	var fill_width := floorf(maxf(0.0, track_rect.size.x - 2.0) * _current_ratio)
	if fill_width <= 0.0:
		return
	var fill_rect := Rect2(track_rect.position + Vector2(1, 1), Vector2(fill_width, maxf(1.0, track_rect.size.y - 2)))
	_draw_gradient_fill(fill_rect)
	var edge_x := fill_rect.position.x + fill_rect.size.x
	draw_rect(Rect2(Vector2(edge_x - 1.0, fill_rect.position.y), Vector2(2.0, fill_rect.size.y)), FILL_EDGE, true)
	if _glow_alpha > 0.0:
		draw_rect(
			Rect2(fill_rect.position + Vector2(0, 1), Vector2(fill_rect.size.x, minf(3.0, fill_rect.size.y * 0.42))),
			Color(1.0, 0.98, 0.86, _glow_alpha),
			true
		)

func _draw_gradient_fill(fill_rect: Rect2) -> void:
	var segment_count := clampi(int(fill_rect.size.x / 18.0), 8, 96)
	var segment_w := fill_rect.size.x / float(segment_count)
	for index in range(segment_count):
		var t := 0.0 if segment_count <= 1 else float(index) / float(segment_count - 1)
		var color := FILL_START.lerp(FILL_END, t)
		var x := fill_rect.position.x + segment_w * float(index)
		var w := ceilf(segment_w) + 1.0
		draw_rect(Rect2(Vector2(x, fill_rect.position.y), Vector2(w, fill_rect.size.y)), color, true)
	for index in range(1, 10):
		var x := fill_rect.position.x + fill_rect.size.x * float(index) / 10.0
		draw_line(
			Vector2(x, fill_rect.position.y + 1),
			Vector2(x, fill_rect.position.y + fill_rect.size.y - 1),
			Color(1.0, 1.0, 1.0, 0.18),
			1.0
		)

func _track_rect(full_rect: Rect2) -> Rect2:
	var top := maxf(BAR_PADDING + RULER_HEIGHT, floorf(full_rect.size.y * 0.28))
	var height := maxf(8.0, full_rect.size.y - top - BAR_PADDING)
	return Rect2(Vector2(BAR_PADDING, top), Vector2(maxf(0.0, full_rect.size.x - BAR_PADDING * 2.0), height))

func _start_glow_animation() -> void:
	if _glow_tween != null and _glow_tween.is_valid():
		_glow_tween.kill()
	_glow_tween = create_tween()
	_glow_tween.set_loops(0)
	_glow_tween.tween_method(_set_glow_alpha, 0.0, 0.18, GLOW_DURATION * 0.5)
	_glow_tween.tween_method(_set_glow_alpha, 0.18, 0.0, GLOW_DURATION * 0.5)

func _set_glow_alpha(value: float) -> void:
	_glow_alpha = value
	queue_redraw()

func _on_player_data_changed() -> void:
	var pd := GameManager.player_data
	var exp_in_level: int = pd.exp_in_level if "exp_in_level" in pd else GameManager.exp_in_level
	var exp_for_next: int = pd.exp_for_next if "exp_for_next" in pd else GameManager.exp_for_next
	if exp_for_next <= 0:
		exp_for_next = 400

	var ratio := float(exp_in_level) / float(exp_for_next) if exp_for_next > 0 else 0.0
	ratio = clampf(ratio, 0.0, 1.0)
	var ratio_tween := create_tween()
	ratio_tween.tween_method(_set_current_ratio, _current_ratio, ratio, 0.3).set_trans(Tween.TRANS_CUBIC)

	_label.text = "%d / %d" % [exp_in_level, exp_for_next]
	_start_glow_animation()

func _set_current_ratio(value: float) -> void:
	_current_ratio = clampf(value, 0.0, 1.0)
	queue_redraw()

func _on_data_synced() -> void:
	call_deferred("refresh")

func refresh() -> void:
	_on_player_data_changed()
