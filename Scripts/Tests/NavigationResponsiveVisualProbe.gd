extends Node

func _ready() -> void:
	var target_size := _target_size_from_environment()
	var output_path := OS.get_environment("CCR_NAV_PROBE_PATH")

	Localization.set_locale("zh-CN")
	_prepare_player_data()
	var probe_viewport := SubViewport.new()
	probe_viewport.size = Vector2i(target_size)
	probe_viewport.disable_3d = true
	probe_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(probe_viewport)
	var main := MainUI.new()
	main.size = target_size
	probe_viewport.add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	main.call("_set_game_ui_visible", true)
	var splash := main.find_child("SplashScreenUI", true, false) as Control
	if splash != null:
		splash.hide()
	main.call("_apply_shell_layout")
	await get_tree().process_frame
	await RenderingServer.frame_post_draw

	var nav := main.get("_nav_buttons") as NavButtons
	var first_button := nav.buttons[0]
	print("NAVIGATION_RESPONSIVE_VISUAL_PROBE target=%s viewport=%s first_button=%s" % [
		target_size,
		probe_viewport.get_visible_rect().size,
		first_button.get_global_rect(),
	])
	if output_path != "":
		probe_viewport.get_texture().get_image().save_png(output_path)
	get_tree().quit(0)

func _target_size_from_environment() -> Vector2:
	var raw := OS.get_environment("CCR_NAV_PROBE_SIZE")
	var parts := raw.split("x")
	if parts.size() != 2:
		return Vector2(1920.0, 1200.0)
	return Vector2(maxf(320.0, float(parts[0])), maxf(240.0, float(parts[1])))

func _prepare_player_data() -> void:
	GameManager.player_data.pool_slots = 16
	GameManager.player_data.hand_slots = 16
	GameManager.player_data.vault_slots = 16
	GameManager.player_data.pool_cards = []
	GameManager.player_data.hand_cards = []
	GameManager.player_data.vault_cards = []
	CardPoolSystem.current_pool = []
	for _index in range(16):
		GameManager.player_data.pool_cards.append(null)
		GameManager.player_data.hand_cards.append(null)
		GameManager.player_data.vault_cards.append(null)
		CardPoolSystem.current_pool.append(null)
