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
	if not _assert_slot_title_color(pool_ui.slots[0], CardDisplay.CARD_TEXT_COLOR_PURPLE, "draw_page"):
		return
	if not _assert_draw_section_labels(center_area, pool_ui, hand_ui):
		return

	var pool_margins := _assert_slot_area_centered("pool", pool_ui.slots, viewport_size.x)
	if pool_margins.is_empty():
		return
	var hand_margins := _assert_slot_area_centered("hand", hand_ui.slots, viewport_size.x)
	if hand_margins.is_empty():
		return
	if not _assert_hand_clip_expands_shadow_bounds(hand_ui):
		return
	var side_width := float(pool_margins["left"])
	if not _assert_player_info_layout(main, side_width):
		return
	if not _assert_nav_buttons_layout(main, side_width):
		return
	var expected_right_button_height := float(main.call("_target_player_avatar_height")) / 3.0
	if not _assert_right_action_column(pool_ui, side_width, expected_right_button_height, "pool_refresh"):
		return
	if not _assert_pool_draw_button_positions(pool_ui):
		return
	if not _assert_right_action_column(hand_ui, side_width, expected_right_button_height, "hand_action"):
		return

	main.call("_show_vault")
	await get_tree().process_frame
	await get_tree().process_frame
	var vault_ui := _find_child_by_script(center_area, VaultUIScript) as VaultUI
	if vault_ui == null:
		return _fail("vault_ui_missing")
	if not _assert_slot_title_color(vault_ui.slots[0], CardDisplay.CARD_TEXT_COLOR_BLUE, "vault_page"):
		return
	if _has_direct_label_text(vault_ui, "保险箱"):
		return _fail("vault_title_still_visible")
	var vault_margins := _assert_slot_area_centered("vault", vault_ui.slots, viewport_size.x)
	if vault_margins.is_empty():
		return
	if not _assert_vault_viewport_expands_shadow_bounds(vault_ui):
		return
	if not _assert_vault_right_region(vault_ui, side_width):
		return
	if not _assert_vault_slot_area_vertical_layout(main, vault_ui):
		return

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
		var pool_card: CardInfo = null
		var vault_card: CardInfo = null
		if i == 0:
			pool_card = _make_card("purple", "抽卡页标题色测试")
			vault_card = _make_card("blue", "保险箱标题色测试")
		GameManager.player_data.pool_cards.append(pool_card)
		GameManager.player_data.hand_cards.append(null)
		GameManager.player_data.vault_cards.append(vault_card)
		CardPoolSystem.current_pool.append(pool_card)
	GameManager.vault_raw_slot_data = []


func _make_card(color_name: String, deck_name: String) -> CardInfo:
	return CardInfo.new({
		"id": "1",
		"series_name": "测试系列",
		"deck_name": deck_name,
		"card_number": 1,
		"color": color_name,
		"card_name": "测试子卡",
		"description": "测试描述",
	})


func _assert_slot_title_color(slot: CardSlotUI, expected: Color, context: String) -> bool:
	if slot == null or slot.card_display == null:
		_fail(context + "_card_display_missing")
		return false
	for label_name in ["_deck_name_label", "_card_name_label", "_series_tag_label"]:
		var label := slot.card_display.get(label_name) as Label
		if label == null or not label.get_theme_color("font_color").is_equal_approx(expected):
			_fail(context + "_title_color_overwritten_by_page_style")
			return false
		if label.has_theme_color_override("font_shadow_color"):
			_fail(context + "_title_shadow_leaked_from_page_style")
			return false
	return true


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

func _assert_player_info_layout(main: MainUI, side_width: float) -> bool:
	var player_info := main.get("_player_info") as PlayerInfoUI
	if player_info == null:
		_fail("player_info_missing")
		return false
	var avatar_host := player_info.find_child("AvatarHost", true, false) as Control
	var labels := player_info.find_children("*", "Label", true, false)
	var id_label := labels[0] as Label if not labels.is_empty() else null
	if avatar_host == null:
		_fail("avatar_host_missing")
		return false
	var avatar_rect := avatar_host.get_global_rect()
	var center := avatar_rect.get_center()
	if absf(center.x - side_width * 0.5) > CENTER_TOLERANCE or absf(center.y - side_width * 0.5) > CENTER_TOLERANCE:
		_fail("avatar_center_not_axis_symmetric_%s" % str(center))
		return false
	if id_label == null or id_label.get_theme_font_size("font_size") < 18:
		_fail("player_info_font_not_enlarged")
		return false
	return true

func _assert_nav_buttons_layout(main: MainUI, side_width: float) -> bool:
	var nav_buttons := main.get("_nav_buttons") as NavButtons
	if nav_buttons == null:
		_fail("nav_buttons_missing")
		return false
	var buttons: Array = nav_buttons.get("buttons")
	if buttons.is_empty():
		_fail("nav_button_list_empty")
		return false
	var center_area := main.get("_center_area") as Control
	if center_area == null:
		_fail("center_area_missing")
		return false
	if center_area.get_index() > nav_buttons.get_index():
		_fail("center_area_blocks_nav_buttons")
		return false
	var expected_width := side_width * 0.8
	var expected_height := float(main.call("_nav_button_height", EXPECTED_VIEWPORT_SIZE))
	for button in buttons:
		var btn := button as Button
		if btn == null:
			continue
		var rect := btn.get_global_rect()
		if absf(rect.size.x - expected_width) > 1.0 or absf(rect.size.y - expected_height) > 1.0:
			_fail("nav_button_size_wrong")
			return false
		if absf(rect.get_center().x - side_width * 0.5) > CENTER_TOLERANCE:
			_fail("nav_button_not_centered_left_region")
			return false
	var first_gap := maxf(4.0, (nav_buttons.size.y - expected_height * buttons.size()) / float(buttons.size() + 1))
	var compressed_gap := maxf(0.0, first_gap - expected_height / float(buttons.size() - 1))
	for index in range(buttons.size()):
		var button := buttons[index] as Button
		var expected_y := first_gap + index * (expected_height + compressed_gap)
		if absf(button.position.y - expected_y) > CENTER_TOLERANCE:
			_fail("nav_button_vertical_compression_wrong")
			return false
	var prior_last_y := first_gap + (buttons.size() - 1) * (expected_height + first_gap)
	if absf(prior_last_y - buttons[buttons.size() - 1].position.y - expected_height) > CENTER_TOLERANCE:
		_fail("nav_last_button_not_raised_one_height")
		return false
	return true

func _assert_pool_draw_button_positions(pool_ui: CardPoolUI) -> bool:
	var stamina := pool_ui.find_child("DrawStaminaButton", true, false) as Button
	var gold := pool_ui.find_child("DrawGoldButton", true, false) as Button
	var gem := pool_ui.find_child("DrawGemButton", true, false) as Button
	if stamina == null or gold == null or gem == null:
		_fail("pool_draw_buttons_missing")
		return false
	var expected_stamina_center_y := CardSlotUI.SLOT_SIZE.y * 0.5
	var expected_gem_center_y := CardSlotUI.SLOT_SIZE.y + 8.0 + CardSlotUI.SLOT_SIZE.y * 0.5
	var expected_gold_center_y := (expected_stamina_center_y + expected_gem_center_y) * 0.5
	var gold_center_y := gold.global_position.y + gold.size.y * 0.5 - pool_ui.global_position.y
	if absf(gold_center_y - expected_gold_center_y) > CENTER_TOLERANCE:
		_fail("gold_draw_not_on_pool_midline")
		return false
	var stamina_center_y := stamina.global_position.y + stamina.size.y * 0.5 - pool_ui.global_position.y
	var gem_center_y := gem.global_position.y + gem.size.y * 0.5 - pool_ui.global_position.y
	if absf(stamina_center_y - expected_stamina_center_y) > CENTER_TOLERANCE:
		_fail("stamina_draw_not_on_first_row_center")
		return false
	if absf(gem_center_y - expected_gem_center_y) > CENTER_TOLERANCE:
		_fail("gem_draw_not_on_second_row_center")
		return false
	return true

func _assert_draw_section_labels(center_area: Control, pool_ui: CardPoolUI, hand_ui: HandAreaUI) -> bool:
	var pool_label := center_area.find_child("CardPoolSectionLabel", false, false) as Label
	var hand_label := center_area.find_child("HandSectionLabel", false, false) as Label
	if pool_label == null or hand_label == null:
		_fail("draw_section_labels_missing")
		return false
	if pool_label.text != "卡池" or hand_label.text != "手牌":
		_fail("draw_section_label_text_wrong")
		return false
	for label in [pool_label, hand_label]:
		var typed_label := label as Label
		if typed_label.get_theme_font_size("font_size") != MainUI.PLAYER_INFO_FONT_SIZE:
			_fail("draw_section_label_font_size_wrong")
			return false
		if not typed_label.get_theme_color("font_color").is_equal_approx(Color.BLACK):
			_fail("draw_section_label_color_wrong")
			return false
		if typed_label.mouse_filter != Control.MOUSE_FILTER_IGNORE:
			_fail("draw_section_label_blocks_mouse")
			return false
		if absf(typed_label.get_global_rect().get_center().x - EXPECTED_VIEWPORT_SIZE.x * 0.5) > CENTER_TOLERANCE:
			_fail("draw_section_label_not_centered")
			return false
	var pool_container := pool_ui.get_parent() as Control
	var hand_container := hand_ui.get_parent() as Control
	if pool_container == null or hand_container == null:
		_fail("draw_section_containers_missing")
		return false
	var pool_label_rect := pool_label.get_global_rect()
	var hand_label_rect := hand_label.get_global_rect()
	var pool_rect := pool_container.get_global_rect()
	var hand_rect := hand_container.get_global_rect()
	var center_rect := center_area.get_global_rect()
	if pool_label_rect.position.y < center_rect.position.y or pool_label_rect.end.y > pool_rect.position.y + CENTER_TOLERANCE:
		_fail("pool_section_label_not_above_pool")
		return false
	if hand_label_rect.position.y < pool_rect.end.y - CENTER_TOLERANCE or hand_label_rect.end.y > hand_rect.position.y + CENTER_TOLERANCE:
		_fail("hand_section_label_not_between_pool_and_hand")
		return false
	if hand_label.get_index() >= hand_container.get_index():
		_fail("hand_section_label_above_hand_cards")
		return false
	if pool_label.get_index() >= pool_container.get_index():
		_fail("pool_section_label_above_pool_cards")
		return false
	var pool_gap := pool_rect.position.y - center_rect.position.y
	var hand_gap := hand_rect.position.y - pool_rect.end.y
	var expected_pool_label_center_y := center_rect.position.y + maxf(0.0, pool_gap - pool_label_rect.size.y) * 0.75 + pool_label_rect.size.y * 0.5
	var expected_hand_label_center_y := pool_rect.end.y + maxf(0.0, hand_gap - hand_label_rect.size.y) * 0.75 + hand_label_rect.size.y * 0.5
	if absf(pool_label_rect.get_center().y - expected_pool_label_center_y) > CENTER_TOLERANCE:
		_fail("pool_section_label_vertical_distance_wrong")
		return false
	if absf(hand_label_rect.get_center().y - expected_hand_label_center_y) > CENTER_TOLERANCE:
		_fail("hand_section_label_vertical_distance_wrong")
		return false
	return true

func _assert_right_action_column(root: Node, side_width: float, expected_button_height: float, reason_prefix: String) -> bool:
	var column := root.find_child("*Column", true, false) as Control
	if column == null:
		_fail(reason_prefix + "_column_missing")
		return false
	var expected_center_x := EXPECTED_VIEWPORT_SIZE.x - side_width * 0.5
	var rect := column.get_global_rect()
	if absf(rect.get_center().x - expected_center_x) > CENTER_TOLERANCE:
		_fail(reason_prefix + "_not_centered_right_region")
		return false
	for child in column.get_children():
		var button := child as Button
		if button == null:
			continue
		var button_rect := button.get_global_rect()
		if absf(button_rect.size.x - side_width * 0.8) > 1.0:
			_fail(reason_prefix + "_button_width_wrong")
			return false
		if absf(button_rect.size.y - expected_button_height) > 1.0:
			_fail(reason_prefix + "_button_height_wrong")
			return false
	if root is HandAreaUI:
		var hand_ui := root as HandAreaUI
		var buttons := [
			hand_ui.find_child("HandPageButton", true, false),
			hand_ui.find_child("HandSynthesizeButton", true, false),
			hand_ui.find_child("HandDiscardButton", true, false),
			hand_ui.find_child("HandStoreVaultButton", true, false),
		]
		for index in range(buttons.size()):
			var button := buttons[index] as Button
			if button == null:
				_fail("hand_action_button_missing_%d" % index)
				return false
			var first_center_y := CardSlotUI.SLOT_SIZE.y * 0.25
			var last_center_y := CardSlotUI.SLOT_SIZE.y + 8.0 + CardSlotUI.SLOT_SIZE.y * 0.75
			var expected_center_y := first_center_y + (last_center_y - first_center_y) * float(index) / 3.0
			if absf(button.get_global_rect().get_center().y - hand_ui.global_position.y - expected_center_y) > CENTER_TOLERANCE:
				_fail("hand_action_vertical_layout_wrong_%d" % index)
				return false
	return true

func _assert_vault_right_region(vault_ui: VaultUI, side_width: float) -> bool:
	var label := vault_ui.find_child("SlotLabel", true, false) as Label
	if label == null:
		_fail("vault_slot_label_missing")
		return false
	var top_padding := float(vault_ui.get("_scrollbar_top_padding"))
	var expected_label_position := vault_ui.global_position + Vector2(top_padding, top_padding)
	if label.global_position.distance_to(expected_label_position) > CENTER_TOLERANCE or label.horizontal_alignment != HORIZONTAL_ALIGNMENT_LEFT:
		_fail("vault_slot_label_not_aligned_with_today_deck_countdown")
		return false
	var action_panel := vault_ui.find_child("VaultActionPanel", true, false) as Control
	if action_panel == null:
		_fail("vault_action_panel_missing")
		return false
	var expected_action_center_x := vault_ui.global_position.x + float(vault_ui.call("_right_region_center_x")) + float(vault_ui.get("_side_button_center_offset_x"))
	if absf(action_panel.get_global_rect().get_center().x - expected_action_center_x) > CENTER_TOLERANCE:
		_fail("vault_action_panel_not_centered_on_action_column")
		return false
	return true

func _assert_vault_slot_area_vertical_layout(main: MainUI, vault_ui: VaultUI) -> bool:
	var viewport := vault_ui.get("_slot_viewport") as ScrollContainer
	var currency := main.get("_currency") as CurrencyUI
	if viewport == null or currency == null:
		_fail("vault_vertical_layout_nodes_missing")
		return false
	var viewport_rect := viewport.get_global_rect()
	var vault_rect := vault_ui.get_global_rect()
	var expected_center_y := vault_rect.get_center().y
	if absf(viewport_rect.get_center().y - expected_center_y) > CENTER_TOLERANCE:
		_fail("vault_slot_area_not_vertically_centered")
		return false
	var currency_bottom := currency.get_global_rect().end.y
	if viewport_rect.position.y <= currency_bottom:
		_fail("vault_slot_area_not_below_currency")
		return false
	return true


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

func _assert_vault_viewport_expands_shadow_bounds(vault_ui: VaultUI) -> bool:
	var viewport := vault_ui.get("_slot_viewport") as ScrollContainer
	if viewport == null:
		_fail("vault_viewport_missing")
		return false
	if vault_ui.slots.size() < 8:
		_fail("vault_slots_missing_for_shadow_test")
		return false
	var first_slot := vault_ui.slots[0] as Control
	var last_first_row_slot := vault_ui.slots[7] as Control
	if first_slot == null or last_first_row_slot == null:
		_fail("vault_shadow_slot_nodes_invalid")
		return false
	var viewport_rect := viewport.get_global_rect()
	var first_rect := first_slot.get_global_rect()
	var last_rect := last_first_row_slot.get_global_rect()
	if viewport_rect.position.x >= first_rect.position.x or viewport_rect.position.y >= first_rect.position.y:
		_fail("vault_viewport_not_expanded_before_first_row")
		return false
	if viewport_rect.end.x <= last_rect.end.x:
		_fail("vault_viewport_not_expanded_after_right_column")
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
