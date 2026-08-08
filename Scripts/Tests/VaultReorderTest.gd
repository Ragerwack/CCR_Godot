extends Node

const CCRLinkedVerticalScrollBarScript = preload("res://Scripts/UI/CCRLinkedVerticalScrollBar.gd")
const SynthesisAnimationOverlayScript = preload("res://Scripts/UI/SynthesisAnimationOverlay.gd")

func _ready() -> void:
	Localization.set_locale("zh-CN")
	ApiClient._auth_token = ""
	GameManager.player_data.gold = 10
	GameManager.player_data.gems = 5
	GameManager.vault_slot_quote = {
		"next_slot_index": 3,
		"costs": {"gold": 20, "gem": 10},
	}
	GameManager.player_data.vault_slots = 4
	GameManager.vault_raw_slot_data = [
		{"slot_index": 0, "unlocked": true},
		{"slot_index": 1, "unlocked": true},
		{"slot_index": 2, "unlocked": true},
		{"slot_index": 3, "unlocked": false},
	]

	var card_a := _make_card(101, "测试卡A", 1)
	var card_b := _make_card(102, "测试卡B", 2)
	GameManager.player_data.vault_cards = [card_a, card_b, null, null]

	var vault_ui := VaultUI.new()
	add_child(vault_ui)
	await get_tree().process_frame
	if not _assert_latest_vertical_scrollbar(vault_ui):
		return
	if not _assert_action_buttons_align_with_scrollbar(vault_ui):
		return
	if not await _assert_vault_action_icon_hover_scale(vault_ui):
		return
	if not _assert_vault_icon_brightness_harmony():
		return
	if not _assert_unlock_cost_labels_match_draw_gap(vault_ui):
		return
	if not await _assert_vault_hover_preview_vertically_centered(vault_ui):
		return
	if not _assert_action_layout_stays_fixed_after_row_expansion(vault_ui):
		return
	if not _assert_unlock_buttons_disabled_when_insufficient(vault_ui):
		return

	await vault_ui._prepare_unlock_animation_target(3)
	var locked_rect_before := vault_ui.slots[3].get_lock_icon_global_rect()
	var expected_lock_size := clampf(CardSlotUI.SLOT_SIZE.x * 0.45, 39.0, 63.0)
	if locked_rect_before.size != Vector2(expected_lock_size, expected_lock_size):
		return _fail("unlock_animation_target_lock_size_wrong")
	var original_sfx := AudioManager.sfx_volume
	var original_muted := AudioManager.is_muted
	AudioManager.reload_sfx_library()
	AudioManager.set_muted(false)
	AudioManager.set_sfx_volume(1.0)
	var unlock_sfx_events: Array[Dictionary] = []
	var unlock_sfx_recorder := func(event_name: String) -> void:
		if event_name == "forge_art_flight" or event_name == "slot_unlock":
			unlock_sfx_events.append({
				"name": event_name,
				"msec": Time.get_ticks_msec(),
			})
	AudioManager.sfx_played.connect(unlock_sfx_recorder)
	await vault_ui._play_unlock_key_animation("gold", 3)
	if AudioManager.sfx_played.is_connected(unlock_sfx_recorder):
		AudioManager.sfx_played.disconnect(unlock_sfx_recorder)
	AudioManager.set_sfx_volume(original_sfx)
	AudioManager.set_muted(original_muted)
	await get_tree().process_frame
	if not _assert_key_target_acceleration(VaultUI._accelerate_key_target_progress(0.25), VaultUI._accelerate_key_target_progress(0.50), VaultUI._accelerate_key_target_progress(0.75)):
		return _fail("unlock_key_target_not_accelerating")
	if not _assert_key_flight_sfx_timing(unlock_sfx_events):
		return _fail("unlock_key_flight_sfx_timing_wrong")
	if get_tree().root.find_child("VaultUnlockKeyIcon", true, false) != null:
		return _fail("unlock_key_icon_not_cleaned")
	if vault_ui.slots[3].get_lock_icon_global_rect().size.x > 1.0:
		return _fail("unlock_animation_lock_still_visible")
	if vault_ui.slots[3].is_unlocked():
		return _fail("unlock_animation_changed_authority_state")
	if not await _assert_synthesis_slot_reward_key_animation():
		return

	if not await vault_ui._handle_vault_to_vault(card_a, 0, 1):
		return _fail("swap_returned_false")
	if GameManager.player_data.vault_cards[0] != card_b or GameManager.player_data.vault_cards[1] != card_a:
		return _fail("swap_data_wrong")

	if not await vault_ui._handle_vault_to_vault(card_a, 1, 2):
		return _fail("move_returned_false")
	if GameManager.player_data.vault_cards[1] != null or GameManager.player_data.vault_cards[2] != card_a:
		return _fail("move_to_empty_wrong")

	if await vault_ui._handle_vault_to_vault(card_a, 2, 3):
		return _fail("locked_target_allowed")
	if GameManager.player_data.vault_cards[2] != card_a or GameManager.player_data.vault_cards[3] != null:
		return _fail("locked_target_changed_data")

	GameManager.player_data.vault_slots = 5
	GameManager.vault_raw_slot_data = [
		{"slot_index": 0, "unlocked": true},
		{"slot_index": 1, "unlocked": true},
		{"slot_index": 2, "unlocked": true},
		{"slot_index": 3, "unlocked": true},
		{"slot_index": 4, "unlocked": true},
	]
	GameManager.player_data.vault_cards = [
		_make_card(201, "合成卡1", 1),
		_make_card(202, "合成卡2", 2),
		_make_card(203, "合成卡3", 3),
		_make_card(204, "合成卡4", 4),
		_make_card(205, "合成卡5", 5),
	]
	for card in GameManager.player_data.vault_cards:
		card.color = CardColor.ColorType.PURPLE
	vault_ui.refresh_display()
	await get_tree().process_frame
	vault_ui._on_slot_clicked(0)
	if vault_ui._selected_slots.size() != 1 or int(vault_ui._selected_slots[0]) != 0:
		return _fail("single_select_first_wrong")
	if vault_ui.slots[0].find_child("VaultSelectHighlight", false, false) != null:
		return _fail("vault_selection_overlay_covers_card")
	var slot_highlight: Panel = vault_ui.slots[0].get("_selected_highlight")
	if slot_highlight == null or not slot_highlight.visible:
		return _fail("vault_selection_glow_missing")
	_force_slot_title_color(vault_ui.slots[0], CardDisplay.CARD_TEXT_COLOR)
	vault_ui._update_slot_selection_visual(0)
	if not _slot_title_color_matches(vault_ui.slots[0], CardDisplay.CARD_TEXT_COLOR_PURPLE):
		return _fail("vault_title_color_not_restored_after_visual_refresh")
	vault_ui._on_slot_clicked(1)
	if vault_ui._selected_slots.size() != 1 or int(vault_ui._selected_slots[0]) != 1:
		return _fail("single_select_replace_wrong")
	var indices := vault_ui._find_synthesizable_indices_for_card(GameManager.player_data.vault_cards[1], 1)
	if indices.size() != 5:
		return _fail("vault_auto_synthesis_indices_missing")
	if vault_ui._synthesize_btn == null or vault_ui._synthesize_btn.disabled:
		return _fail("vault_synthesis_button_disabled")
	if CCRVisualStyle.get_relic_button_caption_text(vault_ui._synthesize_btn) != "锻造":
		return _fail("vault_synthesis_button_text_not_forge")
	if vault_ui._relic_preview != null and vault_ui._relic_preview.visible:
		return _fail("relic_preview_visible_before_synthesis")
	var animation_sources := vault_ui.get_synthesis_animation_sources(indices)
	if animation_sources.size() != 5:
		return _fail("vault_synthesis_animation_sources_missing")
	for source in animation_sources:
		if not (source.get("card") is CardInfo):
			return _fail("vault_synthesis_animation_source_card_missing")
		if not bool(source.get("visible", false)):
			return _fail("vault_synthesis_animation_source_not_visible")
	vault_ui.hide_synthesis_slots_for_animation(indices)
	await get_tree().process_frame
	for idx in indices:
		var slot := vault_ui.slots[int(idx)] as CardSlotUI
		if slot != null and slot.is_occupied:
			return _fail("vault_synthesis_source_slot_still_visible")
		if GameManager.player_data.vault_cards[int(idx)] == null:
			return _fail("vault_synthesis_hidden_slot_changed_data")
	vault_ui.set_synthesis_nav_target_rect(Rect2(Vector2(12, 140), Vector2(96, 42)))
	await vault_ui._play_vault_synthesis_animation(animation_sources)
	await get_tree().process_frame
	if get_tree().root.find_child("VaultSynthesisAnimationOverlay", true, false) != null:
		return _fail("vault_synthesis_animation_overlay_not_cleaned")
	for color_name in ["green", "blue", "purple", "orange", "black", "red"]:
		for card in GameManager.player_data.vault_cards:
			card.color = CardColor.from_string(color_name)
		vault_ui._update_synthesize_button()
		if vault_ui._relic_preview != null and vault_ui._relic_preview.visible:
			return _fail(color_name + "_relic_preview_visible_before_synthesis")

	print("VAULT_REORDER ok")
	get_tree().quit(0)


func _make_card(id_value: int, name: String, number: int) -> CardInfo:
	return CardInfo.new({
		"id": str(id_value),
		"series_name": "测试系列",
		"deck_name": "保险箱拖拽测试",
		"card_number": number,
		"color": "white",
		"card_name": name,
		"description": "保险箱换位测试卡。",
	})

func _force_slot_title_color(slot: CardSlotUI, color: Color) -> void:
	var display := slot.card_display
	if display == null:
		return
	for label_name in ["_deck_name_label", "_card_name_label", "_series_tag_label"]:
		var label := display.get(label_name) as Label
		if label != null:
			label.add_theme_color_override("font_color", color)

func _slot_title_color_matches(slot: CardSlotUI, expected: Color) -> bool:
	var display := slot.card_display
	if display == null:
		return false
	for label_name in ["_deck_name_label", "_card_name_label", "_series_tag_label"]:
		var label := display.get(label_name) as Label
		if label == null or not _color_close(label.get_theme_color("font_color"), expected):
			return false
	return true

func _assert_action_buttons_align_with_scrollbar(vault_ui: VaultUI) -> bool:
	var buttons := [
		vault_ui.get("_organize_btn") as Button,
		vault_ui.get("_synthesize_btn") as Button,
		vault_ui.get("_gold_unlock_btn") as Button,
		vault_ui.get("_gem_unlock_btn") as Button,
	]
	for button in buttons:
		if button == null:
			_fail("vault_action_button_missing")
			return false
	var scrollbar := vault_ui.get("_vertical_scrollbar") as VScrollBar
	if scrollbar == null:
		_fail("vault_action_scrollbar_missing")
		return false
	var expected_center_x := float(vault_ui.call("_right_region_center_x")) + VaultUI.VAULT_ACTION_CENTER_OFFSET_X
	var scrollbar_rect := scrollbar.get_global_rect()
	var expected_gap: float = (scrollbar_rect.size.y - buttons[0].size.y * float(buttons.size())) / float(buttons.size() - 1)
	if expected_gap < -0.1:
		_fail("vault_action_buttons_do_not_fit_scrollbar")
		return false
	for index in range(buttons.size()):
		if buttons[index].size != Vector2(VaultUI.VAULT_ACTION_BUTTON_WIDTH, VaultUI.VAULT_ACTION_BUTTON_HEIGHT):
			_fail("vault_action_button_size_wrong_%d" % index)
			return false
		if absf(buttons[index].position.x + buttons[index].size.x * 0.5 + (vault_ui.get("_action_panel") as Control).position.x - expected_center_x) > 0.1:
			_fail("vault_action_button_center_x_wrong_%d" % index)
			return false
		if not _assert_vault_action_button_vertical_content(buttons[index]):
			return false
		if index > 0:
			var previous_rect: Rect2 = buttons[index - 1].get_global_rect()
			var current_rect: Rect2 = buttons[index].get_global_rect()
			if absf(current_rect.position.y - previous_rect.end.y - expected_gap) > 0.1:
				_fail("vault_action_button_vertical_gap_not_uniform_%d" % index)
				return false
	if absf(buttons[0].get_global_rect().position.y - scrollbar_rect.position.y) > 0.1:
		_fail("vault_organize_top_not_aligned_with_scrollbar")
		return false
	if absf(buttons[buttons.size() - 1].get_global_rect().end.y - scrollbar_rect.end.y) > 0.1:
		_fail("vault_gem_expand_bottom_not_aligned_with_scrollbar")
		return false
	if CCRVisualStyle.get_relic_button_caption_text(buttons[0]) != Localization.t("ui.vault.organize"):
		_fail("vault_organize_button_text_wrong")
		return false
	return true

func _assert_vault_action_icon_hover_scale(vault_ui: VaultUI) -> bool:
	var buttons := [
		vault_ui.get("_organize_btn") as Button,
		vault_ui.get("_synthesize_btn") as Button,
		vault_ui.get("_gold_unlock_btn") as Button,
		vault_ui.get("_gem_unlock_btn") as Button,
	]
	for button in buttons:
		if button == null:
			_fail("vault_action_hover_button_missing")
			return false
		var icon := CCRVisualStyle.get_button_icon(button)
		if icon == null:
			_fail("vault_action_hover_icon_missing_%s" % button.name)
			return false
		icon.scale = Vector2.ONE
		button.mouse_entered.emit()
	await get_tree().create_timer(CCRVisualStyle.BUTTON_ICON_HOVER_SECONDS + 0.06).timeout
	for button in buttons:
		var icon := CCRVisualStyle.get_button_icon(button)
		if icon == null:
			_fail("vault_action_hover_icon_lost_%s" % button.name)
			return false
		if not _vector2_close(icon.scale, Vector2.ONE * CCRVisualStyle.VAULT_ACTION_BUTTON_ICON_HOVER_SCALE):
			_fail("vault_action_icon_hover_scale_wrong_%s expected=%.2f actual=%.3f" % [button.name, CCRVisualStyle.VAULT_ACTION_BUTTON_ICON_HOVER_SCALE, icon.scale.x])
			return false
		button.mouse_exited.emit()
	await get_tree().create_timer(CCRVisualStyle.BUTTON_ICON_HOVER_SECONDS + 0.06).timeout
	for button in buttons:
		var icon := CCRVisualStyle.get_button_icon(button)
		if icon == null:
			_fail("vault_action_exit_icon_lost_%s" % button.name)
			return false
		if not _vector2_close(icon.scale, Vector2.ONE):
			_fail("vault_action_icon_exit_scale_wrong_%s actual=%.3f" % [button.name, icon.scale.x])
			return false
	return true

func _assert_vault_action_button_vertical_content(button: Button) -> bool:
	var icon := CCRVisualStyle.get_button_icon(button)
	var caption := CCRVisualStyle.get_button_text_label(button)
	if icon == null or caption == null or not caption.visible:
		_fail("vault_action_button_vertical_content_missing_%s" % button.name)
		return false
	if icon.texture == null or icon.texture.get_size().x < VaultUI.VAULT_ACTION_ICON_SIZE * 2.0:
		_fail("vault_action_icon_source_not_high_resolution_%s" % button.name)
		return false
	if icon.size != Vector2(VaultUI.VAULT_ACTION_ICON_SIZE, VaultUI.VAULT_ACTION_ICON_SIZE):
		_fail("vault_action_icon_size_wrong_%s" % button.name)
		return false
	if absf(icon.position.x - (button.size.x - VaultUI.VAULT_ACTION_ICON_SIZE) * 0.5) > 0.1:
		_fail("vault_action_icon_not_centered_%s" % button.name)
		return false
	if absf(icon.position.y - VaultUI.VAULT_ACTION_ICON_TOP) > 0.1:
		_fail("vault_action_icon_top_wrong_%s" % button.name)
		return false
	if caption.text != CCRVisualStyle.get_relic_button_caption_text(button):
		_fail("vault_action_caption_not_synced_%s" % button.name)
		return false
	if button.text != "":
		_fail("vault_action_native_text_not_empty_%s" % button.name)
		return false
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color", "font_disabled_color"]:
		if button.get_theme_color(state).a > 0.001:
			_fail("vault_action_native_text_visible_%s_%s" % [button.name, state])
			return false
	if absf(caption.position.y - (VaultUI.VAULT_ACTION_ICON_TOP + VaultUI.VAULT_ACTION_ICON_SIZE + VaultUI.VAULT_ACTION_TEXT_GAP)) > 0.1:
		_fail("vault_action_caption_top_wrong_%s" % button.name)
		return false
	if absf(caption.size.x - button.size.x) > 0.1:
		_fail("vault_action_caption_width_wrong_%s" % button.name)
		return false
	if button.disabled:
		if not _color_close(caption.get_theme_color("font_color"), CCRVisualStyle.RELIC_BUTTON_DISABLED_TEXT):
			_fail("vault_action_caption_not_gray_when_disabled_%s" % button.name)
			return false
	else:
		if not _color_close(caption.get_theme_color("font_color"), CCRVisualStyle.RELIC_BUTTON_VAULT_TEXT):
			_fail("vault_action_caption_not_navigation_normal_color_%s" % button.name)
			return false
		button.mouse_entered.emit()
		if not _color_close(caption.get_theme_color("font_color"), CCRVisualStyle.RELIC_BUTTON_HOVER_TEXT):
			_fail("vault_action_caption_not_white_on_hover_%s" % button.name)
			return false
		button.mouse_exited.emit()
		if not _color_close(caption.get_theme_color("font_color"), CCRVisualStyle.RELIC_BUTTON_NAV_TEXT):
			_fail("vault_action_caption_not_navigation_color_after_hover_%s" % button.name)
			return false
	return true

func _assert_vault_icon_brightness_harmony() -> bool:
	var organize_luma := _visible_icon_mean_luma(CCRVisualStyle.icon("vault_organize"))
	var gold_luma := _visible_icon_mean_luma(CCRVisualStyle.icon("vault_expand_gold"))
	var gem_luma := _visible_icon_mean_luma(CCRVisualStyle.icon("vault_expand_gem"))
	if organize_luma <= 0.0 or gold_luma <= 0.0 or gem_luma <= 0.0:
		_fail("vault_icon_brightness_probe_failed")
		return false
	var expansion_mean := (gold_luma + gem_luma) * 0.5
	if absf(organize_luma - expansion_mean) > 12.0:
		_fail("vault_organize_icon_titanium_brightness_mismatch expected_near=%.2f actual=%.2f" % [expansion_mean, organize_luma])
		return false
	return true

func _visible_icon_mean_luma(texture: Texture2D) -> float:
	if texture == null:
		return 0.0
	var image := texture.get_image()
	if image == null or image.is_empty():
		return 0.0
	var total := 0.0
	var count := 0
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var pixel := image.get_pixel(x, y)
			if pixel.a <= 32.0 / 255.0:
				continue
			total += (0.2126 * pixel.r + 0.7152 * pixel.g + 0.0722 * pixel.b) * 255.0
			count += 1
	return total / float(count) if count > 0 else 0.0

func _assert_unlock_cost_labels_match_draw_gap(vault_ui: VaultUI) -> bool:
	var gold_button := vault_ui.get("_gold_unlock_btn") as Button
	var gem_button := vault_ui.get("_gem_unlock_btn") as Button
	var gold_label := vault_ui.get("_gold_unlock_cost_label") as Label
	var gem_label := vault_ui.get("_gem_unlock_cost_label") as Label
	if gold_button == null or gem_button == null or gold_label == null or gem_label == null:
		_fail("vault_unlock_gap_nodes_missing")
		return false
	var first_row_center_y := CardSlotUI.SLOT_SIZE.y * 0.5
	var second_row_center_y := CardSlotUI.SLOT_SIZE.y + VaultUI.SLOT_SPACING + CardSlotUI.SLOT_SIZE.y * 0.5
	var draw_gold_center_y := (first_row_center_y + second_row_center_y) * 0.5
	var draw_free_top := first_row_center_y - gold_button.size.y * 0.5
	var draw_gold_top := draw_gold_center_y - gold_button.size.y * 0.5
	var draw_gem_top := second_row_center_y - gem_button.size.y * 0.5
	var adjacent_button_gap := minf(
		draw_gold_top - (draw_free_top + gold_button.size.y),
		draw_gem_top - (draw_gold_top + gem_button.size.y)
	)
	var expected_gap := maxf(VaultUI.ACTION_LABEL_GAP, (adjacent_button_gap - gold_label.size.y) * 0.5)
	var gold_gap := gold_label.position.y - (gold_button.position.y + gold_button.size.y)
	var gem_gap := gem_label.position.y - (gem_button.position.y + gem_button.size.y)
	if absf(gold_gap - expected_gap) > 1.0:
		_fail("vault_gold_unlock_label_gap_wrong expected=%.2f actual=%.2f" % [expected_gap, gold_gap])
		return false
	if absf(gem_gap - expected_gap) > 1.0:
		_fail("vault_gem_unlock_label_gap_wrong")
		return false
	if gold_label.get_theme_font_size("font_size") != 18 or gem_label.get_theme_font_size("font_size") != 18:
		_fail("vault_unlock_label_font_size_wrong")
		return false
	var slot_label := vault_ui.get_node_or_null("SlotLabel") as Label
	if slot_label == null or not _color_close(slot_label.get_theme_color("font_color"), Color.BLACK):
		_fail("vault_slot_count_text_is_not_black")
		return false
	var top_padding := float(vault_ui.get("_scrollbar_top_padding"))
	if slot_label.position.distance_to(Vector2(top_padding, top_padding)) > 0.1 or slot_label.horizontal_alignment != HORIZONTAL_ALIGNMENT_LEFT:
		_fail("vault_slot_count_not_aligned_with_today_deck_countdown")
		return false
	if not _color_close(gold_label.get_theme_color("font_color"), Color.BLACK) or not _color_close(gem_label.get_theme_color("font_color"), Color.BLACK):
		_fail("vault_unlock_cost_text_is_not_black")
		return false
	return true

func _assert_vault_hover_preview_vertically_centered(vault_ui: VaultUI) -> bool:
	if vault_ui.slots.is_empty():
		_fail("vault_hover_preview_slot_missing")
		return false
	var slot := vault_ui.slots[0] as CardSlotUI
	if slot == null or not slot.is_occupied:
		_fail("vault_hover_preview_occupied_slot_missing")
		return false
	slot.call("_show_hover_preview")
	await get_tree().process_frame
	var preview := slot.get("_hover_preview") as CardDisplay
	if preview == null or not preview.is_inside_tree():
		_fail("vault_hover_preview_not_created")
		return false
	var expected_center_y := get_viewport().get_visible_rect().size.y * 0.5
	var actual_center_y := preview.get_global_rect().get_center().y
	slot.call("_hide_hover_preview")
	await get_tree().process_frame
	if absf(actual_center_y - expected_center_y) > 0.5:
		_fail("vault_hover_preview_not_on_screen_midline expected=%.2f actual=%.2f" % [expected_center_y, actual_center_y])
		return false
	return true

func _assert_action_layout_stays_fixed_after_row_expansion(vault_ui: VaultUI) -> bool:
	var original_vault_slots := GameManager.player_data.vault_slots
	var original_raw_slots: Array = GameManager.vault_raw_slot_data.duplicate(true)
	var original_cards: Array = GameManager.player_data.vault_cards.duplicate()
	var initial_viewport := vault_ui.get("_slot_viewport") as ScrollContainer
	var initial_scrollbar := vault_ui.get("_vertical_scrollbar") as VScrollBar
	var initial_buttons := [
		vault_ui.get("_organize_btn") as Button,
		vault_ui.get("_synthesize_btn") as Button,
		vault_ui.get("_gold_unlock_btn") as Button,
		vault_ui.get("_gem_unlock_btn") as Button,
	]
	var initial_viewport_rect := initial_viewport.get_global_rect() if initial_viewport != null else Rect2()
	var initial_scrollbar_rect := initial_scrollbar.get_global_rect() if initial_scrollbar != null else Rect2()
	var initial_button_rects: Array[Rect2] = []
	for button in initial_buttons:
		initial_button_rects.append(button.get_global_rect() if button != null else Rect2())
	var expanded_raw_slots: Array = []
	for index in range(32):
		expanded_raw_slots.append({"slot_index": index, "unlocked": true})
	var expanded_cards := original_cards.duplicate()
	expanded_cards.resize(32)
	GameManager.player_data.vault_slots = 32
	GameManager.vault_raw_slot_data = expanded_raw_slots
	GameManager.player_data.vault_cards = expanded_cards
	vault_ui.refresh_display()

	var aligned := _assert_action_buttons_align_with_scrollbar(vault_ui)
	var viewport := vault_ui.get("_slot_viewport") as ScrollContainer
	var scrollbar := vault_ui.get("_vertical_scrollbar") as VScrollBar
	var buttons := [
		vault_ui.get("_organize_btn") as Button,
		vault_ui.get("_synthesize_btn") as Button,
		vault_ui.get("_gold_unlock_btn") as Button,
		vault_ui.get("_gem_unlock_btn") as Button,
	]
	if aligned and viewport != null and scrollbar != null:
		var viewport_rect := viewport.get_global_rect()
		if viewport_rect != initial_viewport_rect:
			_fail("vault_viewport_moved_after_server_rows_loaded")
			aligned = false
		if initial_scrollbar == null or initial_scrollbar.get_global_rect() != initial_scrollbar_rect:
			_fail("vault_scrollbar_moved_after_server_rows_loaded")
			aligned = false
		if absf(buttons[0].get_global_rect().position.y - initial_scrollbar_rect.position.y) > 0.1:
			_fail("vault_organize_button_not_aligned_with_scrollbar_after_refresh")
			aligned = false
		for index in range(buttons.size()):
			var button := buttons[index] as Button
			if button != null and button.get_global_rect() != initial_button_rects[index]:
				_fail("vault_action_button_moved_after_server_rows_loaded_%d" % index)
				aligned = false
				break
			if button == null or not button.visible or button.get_global_rect().position.y < scrollbar.get_global_rect().position.y or button.get_global_rect().end.y > scrollbar.get_global_rect().end.y:
				_fail("vault_action_button_not_within_scrollbar_after_refresh_%d" % index)
				aligned = false
				break
	else:
		_fail("vault_action_refresh_nodes_missing")
		aligned = false

	GameManager.player_data.vault_slots = original_vault_slots
	GameManager.vault_raw_slot_data = original_raw_slots
	GameManager.player_data.vault_cards = original_cards
	vault_ui.refresh_display()
	return aligned

func _assert_latest_vertical_scrollbar(vault_ui: VaultUI) -> bool:
	var scrollbar := vault_ui.find_child("VaultVerticalScrollbar", true, false) as VScrollBar
	if scrollbar == null or not scrollbar.visible:
		_fail("vault_latest_vertical_scrollbar_missing")
		return false
	var expected_top := float(vault_ui.call("_vault_first_card_top"))
	var expected_bottom := float(vault_ui.call("_today_deck_last_card_bottom"))
	var expected_height := maxf(
		float(CCRVisualStyle.SETTINGS_VERTICAL_SCROLLBAR_TRACK_END_MARGIN * 2),
		expected_bottom - expected_top - scrollbar.size.x
	)
	if absf(scrollbar.size.y - expected_height) > 0.1:
		_fail("vault_vertical_scrollbar_length_not_shortened_by_one_width")
		return false
	var available_height := vault_ui.size.y if vault_ui.size.y > 0.0 else vault_ui.get_viewport_rect().size.y
	var expected_centered_y := maxf(0.0, (available_height - expected_height) * 0.5)
	if absf(scrollbar.position.y - expected_centered_y) > 0.1:
		_fail("vault_vertical_scrollbar_not_screen_vertical_centered")
		return false
	if absf(scrollbar.position.y + scrollbar.size.y * 0.5 - available_height * 0.5) > 0.1:
		_fail("vault_vertical_scrollbar_center_y_wrong")
		return false
	var track := scrollbar.find_child("CCRVerticalScrollbarTrack", false, false) as NinePatchRect
	if track == null or track.patch_margin_top != 78 or track.patch_margin_bottom != 78:
		_fail("vault_vertical_scrollbar_end_caps_unprotected")
		return false
	if vault_ui.slots.size() < VaultUI.VAULT_COLUMNS:
		_fail("vault_rightmost_slot_missing")
		return false
	var rightmost_slot := vault_ui.slots[VaultUI.VAULT_COLUMNS - 1] as CardSlotUI
	var visible_track_left := track.get_global_rect().position.x + CCRLinkedVerticalScrollBarScript.TRACK_VISUAL_LEFT_INSET
	var rightmost_slot_right := rightmost_slot.get_global_rect().end.x
	if absf(visible_track_left - rightmost_slot_right - scrollbar.size.x * 0.5) > 0.1:
		_fail("vault_vertical_scrollbar_left_gap_not_equal_half_width")
		return false
	return true

func _assert_unlock_buttons_disabled_when_insufficient(vault_ui: VaultUI) -> bool:
	var gold_button := vault_ui.get("_gold_unlock_btn") as Button
	var gem_button := vault_ui.get("_gem_unlock_btn") as Button
	if gold_button == null or gem_button == null:
		_fail("vault_unlock_button_missing")
		return false
	if not gold_button.disabled:
		_fail("vault_gold_unlock_not_disabled_when_insufficient")
		return false
	if not gem_button.disabled:
		_fail("vault_gem_unlock_not_disabled_when_insufficient")
		return false
	GameManager.player_data.gold = 100
	GameManager.player_data.gems = 50
	vault_ui.call("_update_unlock_buttons")
	if gold_button.disabled:
		_fail("vault_gold_unlock_still_disabled_when_sufficient")
		return false
	if gem_button.disabled:
		_fail("vault_gem_unlock_still_disabled_when_sufficient")
		return false
	return true

func _assert_synthesis_slot_reward_key_animation() -> bool:
	var overlay := SynthesisAnimationOverlay.new()
	overlay.name = "RewardKeyAnimationProbe"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	await get_tree().process_frame

	if absf(overlay._key_rotation_for_direction(Vector2.DOWN)) > 0.1:
		overlay.queue_free()
		_fail("reward_key_down_rotation_wrong")
		return false
	if absf(overlay._key_rotation_for_direction(Vector2.RIGHT) + 90.0) > 0.1:
		overlay.queue_free()
		_fail("reward_key_right_rotation_wrong")
		return false
	if absf(overlay._reward_flight_duration({"type": "slot"}) - 2.08) > 0.01:
		overlay.queue_free()
		_fail("reward_key_duration_wrong")
		return false
	if absf(SynthesisAnimationOverlayScript.REWARD_KEY_FLIGHT_SFX_LEAD_TIME - 0.40) > 0.001:
		overlay.queue_free()
		_fail("reward_key_flight_sfx_lead_time_wrong")
		return false
	if not _assert_key_target_acceleration(
		SynthesisAnimationOverlayScript._accelerate_key_target_progress(0.25),
		SynthesisAnimationOverlayScript._accelerate_key_target_progress(0.50),
		SynthesisAnimationOverlayScript._accelerate_key_target_progress(0.75)
	):
		overlay.queue_free()
		_fail("reward_key_target_not_accelerating")
		return false

	var item := {"type": "slot", "target_rect": Rect2(Vector2(220, 120), Vector2(48, 48))}
	var icon := overlay._create_reward_icon(item, Vector2(420, 360))
	if icon == null:
		overlay.queue_free()
		_fail("reward_key_icon_missing")
		return false
	if icon.size != Vector2(96, 96):
		overlay.queue_free()
		_fail("reward_key_icon_size_wrong")
		return false
	icon.queue_free()

	var expected_vault_key_size := clampf(CardSlotUI.SLOT_SIZE.x * 0.45, 39.0, 63.0) * VaultUI.UNLOCK_KEY_SCALE
	var wide_target_item := {"type": "slot", "target_rect": Rect2(Vector2(20, 120), Vector2(130, 36))}
	icon = overlay._create_reward_icon(wide_target_item, Vector2(420, 360))
	if icon == null:
		overlay.queue_free()
		_fail("reward_key_wide_target_icon_missing")
		return false
	if absf(icon.size.x - expected_vault_key_size) > 0.01 or absf(icon.size.y - expected_vault_key_size) > 0.01:
		overlay.queue_free()
		_fail("reward_key_wide_target_icon_size_wrong")
		return false
	var original_sfx := AudioManager.sfx_volume
	var original_muted := AudioManager.is_muted
	AudioManager.reload_sfx_library()
	AudioManager.set_muted(false)
	AudioManager.set_sfx_volume(1.0)
	var reward_key_sfx_events: Array[Dictionary] = []
	var reward_key_sfx_recorder := func(event_name: String) -> void:
		if event_name == "forge_art_flight" or event_name == "slot_unlock":
			reward_key_sfx_events.append({
				"name": event_name,
				"msec": Time.get_ticks_msec(),
			})
	AudioManager.sfx_played.connect(reward_key_sfx_recorder)
	overlay._start_reward_flight(icon, wide_target_item, Vector2(420, 360), 0.0)
	await get_tree().create_timer(2.20).timeout
	if AudioManager.sfx_played.is_connected(reward_key_sfx_recorder):
		AudioManager.sfx_played.disconnect(reward_key_sfx_recorder)
	AudioManager.set_sfx_volume(original_sfx)
	AudioManager.set_muted(original_muted)
	await get_tree().process_frame
	if not _assert_key_flight_sfx_timing(reward_key_sfx_events):
		overlay.queue_free()
		_fail("reward_key_flight_sfx_timing_wrong")
		return false
	if is_instance_valid(icon):
		overlay.queue_free()
		_fail("reward_key_icon_not_cleaned")
		return false
	overlay.queue_free()
	return true

func _assert_key_target_acceleration(progress_25: float, progress_50: float, progress_75: float) -> bool:
	var first_step := progress_25
	var second_step := progress_50 - progress_25
	var third_step := progress_75 - progress_50
	var final_step := 1.0 - progress_75
	return first_step < second_step and second_step < third_step and third_step < final_step

func _assert_key_flight_sfx_timing(events: Array[Dictionary]) -> bool:
	var flight_msec := -1
	var unlock_msec := -1
	for event in events:
		var name := str(event.get("name", ""))
		if name == "forge_art_flight" and flight_msec < 0:
			flight_msec = int(event.get("msec", -1))
		elif name == "slot_unlock" and unlock_msec < 0:
			unlock_msec = int(event.get("msec", -1))
	if flight_msec < 0 or unlock_msec < 0 or flight_msec >= unlock_msec:
		return false
	var lead_msec := unlock_msec - flight_msec
	return lead_msec >= 300 and lead_msec <= 560

func _color_close(a: Color, b: Color, epsilon: float = 0.005) -> bool:
	return absf(a.r - b.r) <= epsilon and absf(a.g - b.g) <= epsilon and absf(a.b - b.b) <= epsilon and absf(a.a - b.a) <= epsilon

func _vector2_close(a: Vector2, b: Vector2, epsilon: float = 0.01) -> bool:
	return absf(a.x - b.x) <= epsilon and absf(a.y - b.y) <= epsilon


func _fail(reason: String) -> void:
	push_error("VAULT_REORDER " + reason)
	get_tree().quit(1)
