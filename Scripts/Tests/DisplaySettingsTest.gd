extends Node

func _ready() -> void:
	var original_resolution := DisplaySettings.get_current_resolution()
	var original_fullscreen := DisplaySettings.is_fullscreen_enabled()

	DisplaySettings.apply_window_mode(true, false)
	if not DisplaySettings.apply_resolution(Vector2i(1280, 800), false):
		_fail("supported_resolution_rejected")
		return
	if DisplaySettings.is_fullscreen_enabled():
		_fail("resolution_change_did_not_leave_fullscreen")
		return
	if DisplaySettings.get_current_resolution() != Vector2i(1280, 800):
		_fail("current_resolution_not_updated")
		return
	if DisplaySettings.apply_resolution(Vector2i(1234, 567), false):
		_fail("unsupported_resolution_accepted")
		return

	DisplaySettings.current_resolution = original_resolution
	DisplaySettings.apply_window_mode(original_fullscreen, false)
	print("DISPLAY_SETTINGS ok fullscreen_resolution_switches_to_windowed=true")
	get_tree().quit(0)

func _fail(reason: String) -> void:
	push_error("DISPLAY_SETTINGS " + reason)
	get_tree().quit(1)
