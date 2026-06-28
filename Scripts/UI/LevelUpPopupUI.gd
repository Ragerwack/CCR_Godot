extends Control
class_name LevelUpPopupUI

signal dismissed()

var _level: int = 1
var _rewards: Array[String] = []

func setup(level: int, rewards: Array[String]) -> void:
	_level = level
	_rewards = rewards.duplicate()
	if is_node_ready():
		_refresh_text()

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 900

	var shade := ColorRect.new()
	shade.name = "LevelUpShade"
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.0, 0.0, 0.0, 0.42)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	var panel := Panel.new()
	panel.name = "LevelUpPanel"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.size = Vector2(420, 250)
	panel.position = -panel.size / 2.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.075, 0.10, 0.96)
	style.border_color = Color(1.0, 0.78, 0.28, 1.0)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.shadow_color = Color(0, 0, 0, 0.55)
	style.shadow_size = 12
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var box := VBoxContainer.new()
	box.name = "LevelUpContent"
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 28
	box.offset_right = -28
	box.offset_top = 22
	box.offset_bottom = -18
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)

	var title := Label.new()
	title.name = "LevelUpTitle"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.42, 1.0))
	box.add_child(title)

	var body := Label.new()
	body.name = "LevelUpBody"
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 16)
	body.add_theme_color_override("font_color", Color(0.90, 0.92, 0.96, 1.0))
	box.add_child(body)

	var rewards_label := Label.new()
	rewards_label.name = "LevelUpRewards"
	rewards_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rewards_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rewards_label.add_theme_font_size_override("font_size", 15)
	rewards_label.add_theme_color_override("font_color", Color(0.78, 0.86, 1.0, 1.0))
	box.add_child(rewards_label)

	var hint := Label.new()
	hint.name = "LevelUpDismissHint"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.55))
	box.add_child(hint)

	_refresh_text()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		accept_event()
		dismissed.emit()
		queue_free()

func _refresh_text() -> void:
	var title := find_child("LevelUpTitle", true, false) as Label
	var body := find_child("LevelUpBody", true, false) as Label
	var rewards_label := find_child("LevelUpRewards", true, false) as Label
	var hint := find_child("LevelUpDismissHint", true, false) as Label
	if title:
		title.text = Localization.t("ui.level_up.title", [_level])
	if body:
		body.text = Localization.t("ui.level_up.body")
	if rewards_label:
		rewards_label.text = "\n".join(_rewards)
	if hint:
		hint.text = Localization.t("ui.level_up.dismiss")
