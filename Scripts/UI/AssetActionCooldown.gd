extends Control
class_name AssetActionCooldown

const DEFAULT_DURATION_SECONDS: float = 0.5
const SHADOW_COLOR: Color = Color(0.0, 0.0, 0.0, 0.46)
const RIM_COLOR: Color = Color(1.0, 1.0, 1.0, 0.18)

var duration_seconds: float = DEFAULT_DURATION_SECONDS
var _started_msec: int = -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)
	resized.connect(queue_redraw)


func try_start() -> bool:
	if is_cooling_down():
		return false
	start()
	return true


func start() -> void:
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
	draw_rect(rect, Color(0.0, 0.0, 0.0, 0.12), true)
	_draw_remaining_sector(ratio)
	draw_arc(rect.get_center(), minf(size.x, size.y) * 0.42, -PI * 0.5, -PI * 0.5 + TAU, 64, RIM_COLOR, 1.4, true)


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
