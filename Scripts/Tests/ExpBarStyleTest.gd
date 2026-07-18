extends Node

func _ready() -> void:
	get_window().size = Vector2i(1280, 800)
	GameManager.player_data.level = 12
	GameManager.player_data.exp = 3840
	GameManager.player_data.exp_in_level = 3840
	GameManager.player_data.exp_for_next = 6000

	var exp_bar := ExpBarUI.new()
	exp_bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(exp_bar)
	await get_tree().process_frame
	await get_tree().create_timer(0.36).timeout

	if exp_bar.get_style_id() != "archive_ruler_c":
		return _fail("style_id_not_scheme_c")
	if not is_equal_approx(exp_bar.get_current_ratio(), 0.64):
		return _fail("ratio_wrong_%.3f" % exp_bar.get_current_ratio())

	var icon := exp_bar.find_child("ExperienceIcon", true, false) as TextureRect
	var label := exp_bar.find_child("ExpValueLabel", true, false) as Label
	if icon == null or icon.texture == null:
		return _fail("experience_icon_missing")
	if label == null or label.text != "3840 / 6000":
		return _fail("label_wrong_%s" % (label.text if label != null else "<null>"))
	if not _color_close(label.get_theme_color("font_color"), Color(0.10, 0.12, 0.14, 1.0)):
		return _fail("label_not_archive_dark")

	print("EXP_BAR_STYLE ok style=archive_ruler_c ratio=0.64")
	get_tree().quit(0)

func _color_close(a: Color, b: Color) -> bool:
	return (
		absf(a.r - b.r) < 0.01
		and absf(a.g - b.g) < 0.01
		and absf(a.b - b.b) < 0.01
		and absf(a.a - b.a) < 0.01
	)

func _fail(message: String) -> void:
	push_error("EXP_BAR_STYLE " + message)
	get_tree().quit(1)
