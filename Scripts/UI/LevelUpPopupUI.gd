extends Control
class_name LevelUpPopupUI

signal dismissed()

const CCRVisualStyle = preload("res://Scripts/UI/CCRVisualStyle.gd")

var _level: int = 1
var _rewards: Array[String] = []

func setup(level: int, rewards: Array[String]) -> void:
	_level = level
	_rewards = rewards.duplicate()
	if is_node_ready():
		_refresh_text()

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 0
	offset_top = 0
	offset_right = 0
	offset_bottom = 0
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 900

	var shade := ColorRect.new()
	shade.name = "LevelUpShade"
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.0, 0.0, 0.0, 0.42)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	var center := CenterContainer.new()
	center.name = "LevelUpCenter"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.offset_left = 0
	center.offset_top = 0
	center.offset_right = 0
	center.offset_bottom = 0
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var panel := Panel.new()
	panel.name = "LevelUpPanel"
	panel.size = CCRVisualStyle.DIALOG_PANEL_SIZE
	panel.custom_minimum_size = CCRVisualStyle.DIALOG_PANEL_SIZE
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", CCRVisualStyle.make_dialog_panel_style())
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.name = "LevelUpContent"
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 180
	box.offset_right = -180
	box.offset_top = 82
	box.offset_bottom = -54
	box.add_theme_constant_override("separation", 12)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(box)

	var title := Label.new()
	title.name = "LevelUpTitle"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.50, 1.0))
	title.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.88))
	title.add_theme_constant_override("shadow_offset_x", 0)
	title.add_theme_constant_override("shadow_offset_y", 2)
	box.add_child(title)

	var body := Label.new()
	body.name = "LevelUpBody"
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 17)
	body.add_theme_color_override("font_color", Color(0.92, 0.96, 1.0, 0.96))
	body.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.82))
	body.add_theme_constant_override("shadow_offset_x", 0)
	body.add_theme_constant_override("shadow_offset_y", 1)
	box.add_child(body)

	var rewards_label := Label.new()
	rewards_label.name = "LevelUpRewards"
	rewards_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rewards_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rewards_label.add_theme_font_size_override("font_size", 17)
	rewards_label.add_theme_color_override("font_color", Color(0.78, 0.91, 1.0, 1.0))
	rewards_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.82))
	rewards_label.add_theme_constant_override("shadow_offset_x", 0)
	rewards_label.add_theme_constant_override("shadow_offset_y", 1)
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
