extends Node

const AssetActionCooldownScript = preload("res://Scripts/UI/AssetActionCooldown.gd")
const CCRVisualStyle = preload("res://Scripts/UI/CCRVisualStyle.gd")


func _ready() -> void:
	var test_viewport := SubViewport.new()
	test_viewport.size = Vector2i(400, 220)
	test_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(test_viewport)

	var background := ColorRect.new()
	background.color = Color(0.92, 0.94, 0.97, 1.0)
	background.size = Vector2(400, 220)
	test_viewport.add_child(background)

	var button := Button.new()
	button.position = Vector2(104, 78)
	button.size = Vector2(192, 64)
	button.text = "CD"
	CCRVisualStyle.apply_relic_button(button, "action_synthesize")
	background.add_child(button)
	await get_tree().process_frame

	var cooldown := AssetActionCooldownScript.new() as Control
	cooldown.name = "AssetActionCooldown"
	cooldown.duration_seconds = 0.5
	cooldown.set_anchors_preset(Control.PRESET_FULL_RECT)
	cooldown.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cooldown.z_index = 128
	button.add_child(cooldown)
	if cooldown == null:
		return _fail("attach_missing")
	if cooldown.duration_seconds != 0.5:
		return _fail("duration_wrong")
	if cooldown.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		return _fail("mouse_filter_wrong")
	if not (cooldown.material is ShaderMaterial):
		return _fail("shape_mask_material_missing")
	if cooldown.visible:
		return _fail("cooldown_visible_before_start")
	var finish_state := {"count": 0}
	cooldown.cooldown_finished.connect(func(): finish_state["count"] = int(finish_state["count"]) + 1)
	button.disabled = true
	await get_tree().process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
	var can_capture_pixels := DisplayServer.get_name() != "headless"
	var before_image: Image = test_viewport.get_texture().get_image().duplicate() as Image if can_capture_pixels else null
	if not cooldown.try_start():
		return _fail("first_start_rejected")
	if can_capture_pixels:
		await get_tree().create_timer(0.18).timeout
	for _frame in range(3):
		await get_tree().process_frame
		if can_capture_pixels:
			await RenderingServer.frame_post_draw
	if can_capture_pixels:
		RenderingServer.force_draw(true)
	if not cooldown.visible:
		return _fail("cooldown_not_visible_after_start")
	if not cooldown.is_cooling_down():
		return _fail("cooldown_not_running")
	var after_image: Image = test_viewport.get_texture().get_image().duplicate() as Image if can_capture_pixels else null
	if can_capture_pixels:
		var probe_path := OS.get_environment("CCR_COOLDOWN_PROBE_PATH")
		if probe_path != "":
			after_image.save_png(probe_path)
		var button_changed := _changed_pixels(before_image, after_image, Rect2i(104, 78, 192, 64))
		if button_changed < 200:
			var full_changed := _changed_pixels(before_image, after_image, Rect2i(Vector2i.ZERO, before_image.get_size()))
			return _fail("cooldown_not_rendered_on_button image=%s button_changed=%d full_changed=%d button=%s cooldown=%s color=%s tree_visible=%s center_before=%s center_after=%s" % [str(before_image.get_size()), button_changed, full_changed, str(button.get_global_rect()), str(cooldown.get_global_rect()), str(cooldown.color), str(cooldown.is_visible_in_tree()), str(before_image.get_pixel(200, 110)), str(after_image.get_pixel(200, 110))])
		if _color_distance(before_image.get_pixel(104, 78), after_image.get_pixel(104, 78)) > 0.03:
			return _fail("cooldown_escaped_button_alpha_mask")
	var material := cooldown.material as ShaderMaterial
	if material == null or float(material.get_shader_parameter("remaining")) <= 0.0:
		return _fail("cooldown_shader_progress_missing")
	if cooldown.try_start():
		return _fail("second_start_allowed")
	await get_tree().create_timer(0.75).timeout
	if cooldown.is_cooling_down():
		return _fail("cooldown_not_finished")
	if cooldown.remaining_ratio() != 0.0:
		return _fail("remaining_not_zero")
	if int(finish_state["count"]) != 1:
		return _fail("finish_signal_count_%d" % int(finish_state["count"]))
	if cooldown.visible:
		return _fail("cooldown_visible_after_finish_signal")
	if not cooldown.try_start():
		return _fail("restart_rejected")

	test_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	test_viewport.free()
	await get_tree().process_frame
	print("ASSET_ACTION_COOLDOWN ok")
	get_tree().quit(0)


func _changed_pixels(before_image: Image, after_image: Image, rect: Rect2i) -> int:
	if before_image == null or after_image == null or before_image.get_size() != after_image.get_size():
		return 0
	var changed := 0
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var before := before_image.get_pixel(x, y)
			var after := after_image.get_pixel(x, y)
			if _color_distance(before, after) > 0.08:
				changed += 1
	return changed


func _color_distance(first: Color, second: Color) -> float:
	return absf(first.r - second.r) + absf(first.g - second.g) + absf(first.b - second.b)


func _fail(reason: String) -> void:
	push_error("ASSET_ACTION_COOLDOWN " + reason)
	get_tree().quit(1)
