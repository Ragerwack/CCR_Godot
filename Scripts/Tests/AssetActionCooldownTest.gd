extends Node

const AssetActionCooldownScript = preload("res://Scripts/UI/AssetActionCooldown.gd")


func _ready() -> void:
	var button := Button.new()
	button.size = Vector2(120, 40)
	button.text = "CD"
	add_child(button)
	await get_tree().process_frame

	var cooldown := AssetActionCooldownScript.new() as Control
	cooldown.name = "AssetActionCooldown"
	cooldown.duration_seconds = 0.5
	cooldown.set_anchors_preset(Control.PRESET_FULL_RECT)
	cooldown.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(cooldown)
	if cooldown == null:
		return _fail("attach_missing")
	if cooldown.duration_seconds != 0.5:
		return _fail("duration_wrong")
	if cooldown.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		return _fail("mouse_filter_wrong")
	if not cooldown.try_start():
		return _fail("first_start_rejected")
	if not cooldown.is_cooling_down():
		return _fail("cooldown_not_running")
	if cooldown.try_start():
		return _fail("second_start_allowed")
	await get_tree().create_timer(0.75).timeout
	if cooldown.is_cooling_down():
		return _fail("cooldown_not_finished")
	if cooldown.remaining_ratio() != 0.0:
		return _fail("remaining_not_zero")
	if not cooldown.try_start():
		return _fail("restart_rejected")

	print("ASSET_ACTION_COOLDOWN ok")
	get_tree().quit(0)


func _fail(reason: String) -> void:
	push_error("ASSET_ACTION_COOLDOWN " + reason)
	get_tree().quit(1)
