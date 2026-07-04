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

	var original_binding := ControllerInput.get_binding(ControllerInput.ACTION_DRAW_FREE)
	var options := ControllerInput.get_binding_options()
	if options.is_empty():
		return _fail("binding_options_missing")
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
