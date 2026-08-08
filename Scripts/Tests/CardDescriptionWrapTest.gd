extends Node

const TEST_RESOLUTION := Vector2(2560, 1600)

func _ready() -> void:
	var original_card_size := CardDisplay.CARD_SIZE
	var slot_size := _slot_size_for_resolution(TEST_RESOLUTION)
	CardDisplay.configure_card_size(slot_size)

	if not await _assert_multiline_description(
		"代码深处闪烁第一缕自我意识的微光，冰冷的逻辑回路中诞生了对存在的疑问。",
		"zh_cn"
	):
		CardDisplay.configure_card_size(original_card_size)
		return
	if not await _assert_multiline_description(
		"An unusually long localized description should remain readable across multiple lines on every supported desktop platform.",
		"en"
	):
		CardDisplay.configure_card_size(original_card_size)
		return
	if not await _assert_short_description_stays_single_line("短描述"):
		CardDisplay.configure_card_size(original_card_size)
		return

	CardDisplay.configure_card_size(original_card_size)
	print("CARD_DESCRIPTION_WRAP ok resolution=2560x1600 forced_multiline=true")
	get_tree().quit(0)

func _slot_size_for_resolution(viewport_size: Vector2) -> Vector2:
	var aspect := 107.0 / 149.0
	var slot_h_by_height := viewport_size.y * 0.21
	var available_width := viewport_size.x - 64.0
	var max_slot_width := (available_width - 7.0 * 8.0) / 8.0
	var slot_h := minf(slot_h_by_height, max_slot_width / aspect)
	return Vector2(roundf(slot_h * aspect), roundf(slot_h))

func _assert_multiline_description(description: String, context: String) -> bool:
	var display := _make_card(description)
	await get_tree().process_frame
	var label := display.get("_description_label") as Label
	if label == null:
		return _fail(context + "_description_label_missing")
	if label.text.count("\n") < 1:
		return _fail(context + "_deterministic_line_break_missing")
	if label.get_line_count() < 2 or label.get_visible_line_count() < 2:
		return _fail(context + "_description_collapsed_to_single_line")
	var base_font_size := maxi(6, int(roundf(display.size.y * CardDisplay.DESCRIPTION_FONT_CANVAS / CardDisplay.CARD_CANVAS_SIZE.y)))
	if label.get_theme_font_size("font_size") < base_font_size:
		return _fail(context + "_description_font_unexpectedly_shrunk")
	display.queue_free()
	return true

func _assert_short_description_stays_single_line(description: String) -> bool:
	var display := _make_card(description)
	await get_tree().process_frame
	var label := display.get("_description_label") as Label
	if label == null or label.text.contains("\n") or label.get_line_count() != 1:
		return _fail("short_description_was_forced_multiline")
	display.queue_free()
	return true

func _make_card(description: String) -> CardDisplay:
	var display := CardDisplay.new()
	display.size = CardDisplay.CARD_SIZE
	add_child(display)
	display.set_card(CardInfo.new({
		"id": "1",
		"series_name": "测试系列",
		"deck_name": "测试卡组",
		"card_number": 1,
		"color": "white",
		"card_name": "测试子卡",
		"description": description,
	}), 0)
	return display

func _fail(reason: String) -> bool:
	push_error("CARD_DESCRIPTION_WRAP " + reason)
	get_tree().quit(1)
	return false
