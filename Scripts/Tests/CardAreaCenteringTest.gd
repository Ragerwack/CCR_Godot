extends Node

const EXPECTED_VIEWPORT_SIZE: Vector2 = Vector2(1920, 1200)
const CENTER_TOLERANCE: float = 1.0
const CardPoolUIScript = preload("res://Scripts/UI/CardPoolUI.gd")
const HandAreaUIScript = preload("res://Scripts/UI/HandAreaUI.gd")
const VaultUIScript = preload("res://Scripts/UI/VaultUI.gd")

func _ready() -> void:
	get_window().size = Vector2i(1920, 1200)
	await get_tree().process_frame

	ApiClient.logout()
	Localization.set_locale("zh-CN")
	_prepare_player_data()

	var main := MainUI.new()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame

	main.call("_set_game_ui_visible", true)
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size != EXPECTED_VIEWPORT_SIZE:
		return _fail("unexpected_viewport_size_%s" % str(viewport_size))

	var center_area: Control = main.get("_center_area")
	var pool_ui := _find_child_by_script(center_area, CardPoolUIScript) as CardPoolUI
	var hand_ui := _find_child_by_script(center_area, HandAreaUIScript) as HandAreaUI
	if pool_ui == null or hand_ui == null:
		return _fail("draw_page_areas_missing")

	var pool_margins := _assert_slot_area_centered("pool", pool_ui.slots, viewport_size.x)
	if pool_margins.is_empty():
		return
	var hand_margins := _assert_slot_area_centered("hand", hand_ui.slots, viewport_size.x)
	if hand_margins.is_empty():
		return
	if not _assert_hand_clip_expands_shadow_bounds(hand_ui):
		return

	main.call("_show_vault")
	await get_tree().process_frame
	await get_tree().process_frame
	var vault_ui := _find_child_by_script(center_area, VaultUIScript) as VaultUI
	if vault_ui == null:
		return _fail("vault_ui_missing")
	if _has_direct_label_text(vault_ui, "保险箱"):
		return _fail("vault_title_still_visible")
	var vault_margins := _assert_slot_area_centered("vault", vault_ui.slots, viewport_size.x)
	if vault_margins.is_empty():
		return

	var side_width := float(pool_margins["left"])
	var long_short_ratio := viewport_size.y / side_width
	var width_height_ratio := side_width / viewport_size.y
	print("CARD_AREA_CENTERING ok left=%.1f right=%.1f side_long_short=%.4f side_width_height=%.4f" % [
		side_width,
		float(pool_margins["right"]),
		long_short_ratio,
		width_height_ratio,
	])
	get_tree().quit(0)


func _prepare_player_data() -> void:
	GameManager.player_data.pool_slots = 16
	GameManager.player_data.hand_slots = 16
	GameManager.player_data.vault_slots = 16
	GameManager.player_data.pool_cards = []
	GameManager.player_data.hand_cards = []
	GameManager.player_data.vault_cards = []
	CardPoolSystem.current_pool = []
	for i in range(16):
		GameManager.player_data.pool_cards.append(null)
		GameManager.player_data.hand_cards.append(null)
		GameManager.player_data.vault_cards.append(null)
		CardPoolSystem.current_pool.append(null)
	GameManager.vault_raw_slot_data = []


func _assert_slot_area_centered(area_name: String, slots: Array, viewport_width: float) -> Dictionary:
	if slots.size() < 8:
		_fail(area_name + "_slots_missing")
		return {}
	var first_slot := slots[0] as Control
	var last_slot := slots[7] as Control
	if first_slot == null or last_slot == null:
		_fail(area_name + "_slot_nodes_invalid")
		return {}
	var left := first_slot.get_global_rect().position.x
	var right := last_slot.get_global_rect().position.x + last_slot.get_global_rect().size.x
	var left_margin := left
	var right_margin := viewport_width - right
	if absf(left_margin - right_margin) > CENTER_TOLERANCE:
		_fail("%s_not_centered_left_%.1f_right_%.1f" % [area_name, left_margin, right_margin])
		return {}
	return {"left": left_margin, "right": right_margin}


func _find_child_by_script(root: Node, script_resource: Script) -> Node:
	if root == null:
		return null
	for child in root.get_children():
		if child.get_script() == script_resource:
			return child
		var found := _find_child_by_script(child, script_resource)
		if found != null:
			return found
	return null


func _assert_hand_clip_expands_shadow_bounds(hand_ui: HandAreaUI) -> bool:
	var clip := hand_ui.get("_slots_clip") as Control
	if clip == null:
		_fail("hand_clip_missing")
		return false
	if hand_ui.slots.size() < 16:
		_fail("hand_slots_missing_for_clip_test")
		return false
	var first_slot := hand_ui.slots[0] as Control
	var last_slot := hand_ui.slots[15] as Control
	if first_slot == null or last_slot == null:
		_fail("hand_clip_slot_nodes_invalid")
		return false
	var clip_rect := clip.get_global_rect()
	var first_rect := first_slot.get_global_rect()
	var last_rect := last_slot.get_global_rect()
	if clip_rect.position.x >= first_rect.position.x or clip_rect.position.y >= first_rect.position.y:
		_fail("hand_clip_not_expanded_before_slots")
		return false
	if clip_rect.end.x <= last_rect.end.x or clip_rect.end.y <= last_rect.end.y:
		_fail("hand_clip_not_expanded_after_slots")
		return false
	return true


func _has_direct_label_text(root: Node, text: String) -> bool:
	for child in root.get_children():
		var label := child as Label
		if label != null and label.text == text:
			return true
	return false


func _fail(reason: String) -> void:
	push_error("CARD_AREA_CENTERING " + reason)
	get_tree().quit(1)
