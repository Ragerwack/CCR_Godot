extends Node

func _ready() -> void:
	Localization.set_locale("zh-CN")
	GameManager.player_data.pool_slots = 8
	GameManager.player_data.hand_slots = 8
	GameManager.player_data.pool_cards = []
	GameManager.player_data.hand_cards = []
	CardPoolSystem.current_pool = []
	for _index in range(16):
		GameManager.player_data.pool_cards.append(null)
		GameManager.player_data.hand_cards.append(null)
		CardPoolSystem.current_pool.append(null)

	var viewport := SubViewport.new()
	viewport.size = Vector2i(1920, 1200)
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var main := MainUI.new()
	main.size = Vector2(1920, 1200)
	viewport.add_child(main)
	await get_tree().process_frame
	main.call("_set_game_ui_visible", true)
	var splash := main.find_child("SplashScreenUI", true, false) as Control
	if splash != null:
		splash.hide()
	var pool := main.get("_card_pool_ui") as CardPoolUI
	var overlay := main.get("_tutorial_overlay") as TutorialOverlay
	overlay.configure([pool.get_stamina_draw_button()], "ui.tutorial.draw_first", [], false, TutorialOverlay.MESSAGE_PLACEMENT_LEFT)
	await get_tree().process_frame
	await get_tree().process_frame
	var panel := overlay.find_child("TutorialMessagePanel", true, false) as Panel
	var target_rect := pool.get_stamina_draw_button().get_global_rect()
	var panel_rect := panel.get_global_rect() if panel != null else Rect2()
	if panel == null or panel_rect.end.x > viewport.size.x - TutorialOverlay.MESSAGE_VIEWPORT_MARGIN + 0.5 or panel_rect.end.x > target_rect.position.x + 0.5:
		push_error("TUTORIAL_OVERLAY_VISUAL_PROBE draw message is not inside the viewport on the target's left")
		get_tree().quit(1)
		return

	var output_path := OS.get_environment("CCR_TUTORIAL_OVERLAY_PROBE_PATH")
	if output_path != "":
		viewport.get_texture().get_image().save_png(output_path)

	var hand := main.get("_hand_area_ui") as HandAreaUI
	var forge_button := hand.get_synthesize_button() if hand != null else null
	if forge_button == null:
		push_error("TUTORIAL_OVERLAY_VISUAL_PROBE forge button is missing")
		get_tree().quit(1)
		return
	overlay.configure([forge_button], "ui.tutorial.forge", [], false, TutorialOverlay.MESSAGE_PLACEMENT_LEFT)
	await get_tree().process_frame
	await get_tree().process_frame
	var forge_target_rect := forge_button.get_global_rect()
	var forge_panel_rect := panel.get_global_rect()
	if forge_panel_rect.end.x > viewport.size.x - TutorialOverlay.MESSAGE_VIEWPORT_MARGIN + 0.5 or forge_panel_rect.end.x > forge_target_rect.position.x + 0.5:
		push_error("TUTORIAL_OVERLAY_VISUAL_PROBE forge message is not inside the viewport on the target's left")
		get_tree().quit(1)
		return
	var forge_output_path := OS.get_environment("CCR_TUTORIAL_FORGE_OVERLAY_PROBE_PATH")
	if forge_output_path != "":
		viewport.get_texture().get_image().save_png(forge_output_path)

	viewport.size = Vector2i(1280, 800)
	main.size = Vector2(1280, 800)
	await get_tree().process_frame
	await get_tree().process_frame
	pool = main.get("_card_pool_ui") as CardPoolUI
	overlay = main.get("_tutorial_overlay") as TutorialOverlay
	panel = overlay.find_child("TutorialMessagePanel", true, false) as Panel
	if pool == null or overlay == null or panel == null:
		push_error("TUTORIAL_OVERLAY_VISUAL_PROBE compact layout nodes are missing")
		get_tree().quit(1)
		return
	overlay.configure([pool.get_stamina_draw_button()], "ui.tutorial.draw_first", [], false, TutorialOverlay.MESSAGE_PLACEMENT_LEFT)
	await get_tree().process_frame
	var compact_target_rect := pool.get_stamina_draw_button().get_global_rect()
	var compact_panel_rect := panel.get_global_rect()
	if compact_panel_rect.position.x < TutorialOverlay.MESSAGE_VIEWPORT_MARGIN - 0.5 or compact_panel_rect.end.x > viewport.size.x - TutorialOverlay.MESSAGE_VIEWPORT_MARGIN + 0.5 or compact_panel_rect.position.y < TutorialOverlay.MESSAGE_VIEWPORT_MARGIN - 0.5 or compact_panel_rect.end.y > viewport.size.y - TutorialOverlay.MESSAGE_VIEWPORT_MARGIN + 0.5 or compact_panel_rect.end.x > compact_target_rect.position.x + 0.5:
		push_error("TUTORIAL_OVERLAY_VISUAL_PROBE compact draw message escaped the viewport or target-left placement")
		get_tree().quit(1)
		return
	print("TUTORIAL_OVERLAY_VISUAL_PROBE ok draw_target=%s draw_panel=%s forge_target=%s forge_panel=%s compact_target=%s compact_panel=%s" % [target_rect, panel_rect, forge_target_rect, forge_panel_rect, compact_target_rect, compact_panel_rect])
	get_tree().quit(0)
