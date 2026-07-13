extends Node

var _clicked_index := -1

func _ready() -> void:
	await get_tree().process_frame

	for action_id in ControllerInput.get_action_ids():
		if not InputMap.has_action(action_id):
			return _fail("missing_action_" + action_id)

	if ControllerInput.get_binding(ControllerInput.ACTION_POINTER_PRIMARY) == "":
		return _fail("primary_binding_missing")
	if ControllerInput.get_binding(ControllerInput.ACTION_DRAW_FREE) == "":
		return _fail("draw_free_binding_missing")
	var expected_hand_page_binding := "axis_any:%d" % JOY_AXIS_RIGHT_Y
	if ControllerInput.get_binding(ControllerInput.ACTION_HAND_PAGE) != expected_hand_page_binding:
		return _fail("hand_page_default_binding_wrong")
	if InputMap.action_get_events(ControllerInput.ACTION_HAND_PAGE).size() != 2:
		return _fail("hand_page_axis_events_missing")
	var cursor_texture := ControllerInput.call("_load_cursor_texture") as Texture2D
	if cursor_texture == null:
		return _fail("cursor_texture_missing")
	var cursor_image := cursor_texture.get_image()
	if cursor_image == null or cursor_image.is_empty():
		return _fail("cursor_image_missing")
	if cursor_image.get_pixel(47, 63).a > 0.01:
		return _fail("cursor_background_not_transparent")
	if cursor_image.get_used_rect().size.x >= cursor_image.get_width() and cursor_image.get_used_rect().size.y >= cursor_image.get_height():
		return _fail("cursor_uses_full_square")

	var original_binding := ControllerInput.get_binding(ControllerInput.ACTION_DRAW_FREE)
	var options := ControllerInput.get_binding_options()
	if options.is_empty():
		return _fail("binding_options_missing")
	if not options.any(func(option): return str(option.get("id", "")) == expected_hand_page_binding):
		return _fail("hand_page_binding_option_missing")
	var replacement := str(options[0].get("id", ""))
	ControllerInput.set_binding(ControllerInput.ACTION_DRAW_FREE, replacement)
	if ControllerInput.get_binding(ControllerInput.ACTION_DRAW_FREE) != replacement:
		return _fail("set_binding_failed")
	ControllerInput.set_binding(ControllerInput.ACTION_DRAW_FREE, original_binding)

	var slot := CardSlotUI.new()
	slot.slot_index = 3
	slot.area_type = "hand"
	add_child(slot)
	await get_tree().process_frame
	if not (await _assert_slot_is_translucent(slot, "hand")):
		return

	for area in ["pool", "vault"]:
		var visual_slot := CardSlotUI.new()
		visual_slot.area_type = area
		add_child(visual_slot)
		await get_tree().process_frame
		if not (await _assert_slot_is_translucent(visual_slot, area)):
			return

	slot.slot_clicked.connect(func(index: int): _clicked_index = index)
	if not slot.is_controller_focusable():
		return _fail("slot_not_focusable")
	slot.controller_activate()
	if _clicked_index != 3:
		return _fail("slot_activate_failed")

	print("CONTROLLER_INPUT ok")
	get_tree().quit(0)

func _fail(reason: String) -> void:
	push_error("CONTROLLER_INPUT " + reason)
	get_tree().quit(1)

func _assert_slot_is_translucent(slot: CardSlotUI, area: String) -> bool:
	var background := slot.find_child("Background", false, false) as ColorRect
	if background == null:
		_fail(area + "_slot_background_missing")
		return false
	if background.color.a >= 0.95:
		_fail(area + "_slot_background_opaque")
		return false

	var border := slot.find_child("Border", false, false) as ColorRect
	if border == null:
		_fail(area + "_slot_border_missing")
		return false
	if border.color.a >= 0.95:
		_fail(area + "_slot_border_opaque")
		return false
	var inset := slot.find_child("SlotInsetShadow", false, false) as Control
	if inset == null or inset.find_child("TopInsetShadow", false, false) == null or inset.find_child("BottomInsetHighlight", false, false) == null:
		_fail(area + "_slot_inset_shadow_missing")
		return false

	slot.set_unlocked(false)
	await get_tree().process_frame
	var lock_overlay := slot.find_child("LockOverlay", false, false) as ColorRect
	if lock_overlay == null:
		_fail(area + "_slot_lock_overlay_missing")
		return false
	if lock_overlay.color.a >= 0.95:
		_fail(area + "_slot_lock_overlay_opaque")
		return false
	var drag_overlay := slot.find_child("DragOutOverlay", false, false) as ColorRect
	if drag_overlay == null:
		_fail(area + "_slot_drag_overlay_missing")
		return false
	if drag_overlay.color.a >= 0.95:
		_fail(area + "_slot_drag_overlay_opaque")
		return false
	slot.set_unlocked(true)
	return true
