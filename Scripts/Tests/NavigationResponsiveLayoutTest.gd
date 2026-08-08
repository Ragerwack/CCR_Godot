extends Node

const STANDARD_VIEWPORT_SIZE := Vector2(1920.0, 1080.0)
const TALL_VIEWPORT_SIZE := Vector2(1920.0, 1200.0)
const COMPACT_VIEWPORT_SIZE := Vector2(1280.0, 800.0)
const NARROW_VIEWPORT_SIZE := Vector2(800.0, 450.0)
const TOLERANCE := 0.01

func _ready() -> void:
	Localization.set_locale("zh-CN")
	var main := MainUI.new()
	main.call("_configure_card_slot_size", STANDARD_VIEWPORT_SIZE)
	var standard_width := float(main.call("_side_button_width", STANDARD_VIEWPORT_SIZE))
	var standard_height := float(main.call("_nav_button_height", STANDARD_VIEWPORT_SIZE))
	var standard_left := float(main.call("_left_region_width", STANDARD_VIEWPORT_SIZE))
	var standard_center := float(main.call("_card_grid_width"))
	main.call("_configure_card_slot_size", TALL_VIEWPORT_SIZE)
	var tall_width := float(main.call("_side_button_width", TALL_VIEWPORT_SIZE))
	var tall_height := float(main.call("_nav_button_height", TALL_VIEWPORT_SIZE))
	var tall_left := float(main.call("_left_region_width", TALL_VIEWPORT_SIZE))
	var tall_center := float(main.call("_card_grid_width"))
	main.call("_configure_card_slot_size", Vector2(2560.0, 1440.0))
	var large_height := float(main.call("_nav_button_height", Vector2(2560.0, 1440.0)))
	if absf(large_height / 1440.0 - MainUI.NAV_BUTTON_HEIGHT_RATIO) > 0.00001:
		return _fail("large_navigation_height_ratio_wrong_%s" % large_height)
	main.call("_configure_card_slot_size", COMPACT_VIEWPORT_SIZE)
	var compact_width := float(main.call("_side_button_width", COMPACT_VIEWPORT_SIZE))
	var compact_height := float(main.call("_nav_button_height", COMPACT_VIEWPORT_SIZE))
	var compact_left := float(main.call("_left_region_width", COMPACT_VIEWPORT_SIZE))
	var compact_center := float(main.call("_card_grid_width"))

	if absf(standard_height - 1080.0 * MainUI.NAV_BUTTON_HEIGHT_RATIO) > TOLERANCE:
		return _fail("standard_navigation_height_wrong_%s" % standard_height)
	if absf(tall_width - standard_width) > TOLERANCE or absf(tall_left - standard_left) > TOLERANCE or absf(tall_center - standard_center) > TOLERANCE:
		return _fail("same_width_aspect_changed_regions")
	if absf(tall_height - 1200.0 * MainUI.NAV_BUTTON_HEIGHT_RATIO) > TOLERANCE:
		return _fail("tall_navigation_height_wrong_%s" % tall_height)
	if absf(standard_height / STANDARD_VIEWPORT_SIZE.y - compact_height / COMPACT_VIEWPORT_SIZE.y) > 0.00001:
		return _fail("navigation_height_ratio_changed_%s_%s" % [standard_height, compact_height])
	if absf(compact_height - 800.0 * MainUI.NAV_BUTTON_HEIGHT_RATIO) > TOLERANCE:
		return _fail("compact_navigation_height_wrong_%s" % compact_height)
	for region_case in [
		[STANDARD_VIEWPORT_SIZE.x, standard_left, standard_center],
		[COMPACT_VIEWPORT_SIZE.x, compact_left, compact_center],
	]:
		var viewport_width := float(region_case[0])
		var left_width := float(region_case[1])
		var center_width := float(region_case[2])
		if absf(left_width / viewport_width - MainUI.LEFT_REGION_WIDTH_RATIO) > 0.00001:
			return _fail("left_region_ratio_changed_%s" % str(region_case))
		if absf(center_width / viewport_width - MainUI.CENTER_REGION_WIDTH_RATIO) > 0.00001:
			return _fail("center_region_ratio_changed_%s" % str(region_case))
		var right_width := viewport_width - left_width - center_width
		if absf(right_width / viewport_width - MainUI.RIGHT_REGION_WIDTH_RATIO) > 0.00001:
			return _fail("right_region_ratio_changed_%s" % str(region_case))
	for arbitrary_size in [Vector2(2560.0, 1440.0), Vector2(2560.0, 1600.0), Vector2(3440.0, 1440.0)]:
		var target_size: Vector2 = arbitrary_size
		main.call("_configure_card_slot_size", target_size)
		var arbitrary_left := float(main.call("_left_region_width", target_size))
		var arbitrary_center := float(main.call("_center_region_width", target_size))
		var arbitrary_right: float = target_size.x - arbitrary_left - arbitrary_center
		if absf(arbitrary_left / target_size.x - MainUI.LEFT_REGION_WIDTH_RATIO) > 0.00001:
			return _fail("arbitrary_left_region_ratio_changed_%s" % target_size)
		if absf(arbitrary_center / target_size.x - MainUI.CENTER_REGION_WIDTH_RATIO) > 0.00001:
			return _fail("arbitrary_center_region_ratio_changed_%s" % target_size)
		if absf(arbitrary_right / target_size.x - MainUI.RIGHT_REGION_WIDTH_RATIO) > 0.00001:
			return _fail("arbitrary_right_region_ratio_changed_%s" % target_size)
		var grid_width := float(main.call("_card_grid_width"))
		if grid_width > arbitrary_center + TOLERANCE:
			return _fail("arbitrary_grid_overflows_center_region_%s" % target_size)
		var four_row_height := CardSlotUI.SLOT_SIZE.y * 4.0 + MainUI.CARD_GRID_SPACING * 2.0
		var usable_height := target_size.y - float(main.call("_exp_bar_height", target_size))
		if four_row_height > usable_height + TOLERANCE:
			return _fail("arbitrary_grid_overflows_vertical_region_%s" % target_size)

	var nav := NavButtons.new()
	nav.size = Vector2(standard_width, 900.0)
	add_child(nav)
	await get_tree().process_frame
	nav.configure_button_metrics(standard_width, standard_height)
	await get_tree().process_frame

	var first_button := nav.buttons[0]
	if first_button.text.is_empty():
		return _fail("standard_navigation_label_hidden")
	if absf(first_button.size.y / STANDARD_VIEWPORT_SIZE.y - standard_height / STANDARD_VIEWPORT_SIZE.y) > 0.00001:
		return _fail("standard_button_height_not_applied")

	main.call("_configure_card_slot_size", NARROW_VIEWPORT_SIZE)
	var narrow_width := float(main.call("_side_button_width", NARROW_VIEWPORT_SIZE))
	var narrow_height := float(main.call("_nav_button_height", NARROW_VIEWPORT_SIZE))
	nav.size.x = narrow_width
	nav.configure_button_metrics(narrow_width, narrow_height)
	await get_tree().process_frame
	first_button = nav.buttons[0]
	if not first_button.text.is_empty():
		return _fail("narrow_overlapping_label_not_hidden")
	for button in nav.buttons:
		if not button.text.is_empty():
			return _fail("narrow_navigation_labels_not_hidden_as_group_%s" % button.name)
		var narrow_icon := CCRVisualStyle.get_button_icon(button)
		if narrow_icon == null:
			return _fail("narrow_navigation_icon_missing_%s" % button.name)
		var icon_centered := absf(narrow_icon.get_rect().get_center().x - button.size.x * 0.5) <= TOLERANCE
		if not icon_centered:
			return _fail("narrow_navigation_group_icon_not_centered_%s" % button.name)
	if absf(first_button.size.y / NARROW_VIEWPORT_SIZE.y - standard_height / STANDARD_VIEWPORT_SIZE.y) > 0.00001:
		return _fail("narrow_button_height_ratio_not_preserved")
	nav.select_by_id("vault")
	first_button = nav.buttons[0]
	var selected_state_icon := CCRVisualStyle.get_button_icon(first_button)
	if not first_button.text.is_empty() or absf(selected_state_icon.get_rect().get_center().x - first_button.size.x * 0.5) > TOLERANCE:
		return _fail("compact_content_mode_lost_after_selection")

	nav.size.x = standard_width
	nav.configure_button_metrics(standard_width, standard_height)
	await get_tree().process_frame
	first_button = nav.buttons[0]
	if first_button.text.is_empty():
		return _fail("wide_navigation_label_not_restored")
	for button in nav.buttons:
		var restored_icon := CCRVisualStyle.get_button_icon(button)
		if button.text.is_empty():
			return _fail("wide_navigation_label_not_restored_%s" % button.name)
		if absf(restored_icon.get_rect().get_center().x - button.size.x * 0.5) <= TOLERANCE:
			return _fail("wide_navigation_icon_still_centered_%s" % button.name)

	print("NAVIGATION_RESPONSIVE_LAYOUT ok regions=7:34:7 standard=%.2fx%.2f tall=%.2fx%.2f compact=%.2fx%.2f" % [
		standard_width,
		standard_height,
		tall_width,
		tall_height,
		compact_width,
		compact_height,
	])
	get_tree().quit(0)

func _fail(message: String) -> void:
	push_error("NAVIGATION_RESPONSIVE_LAYOUT %s" % message)
	get_tree().quit(1)
