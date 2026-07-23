extends Node

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
	if not _assert_action_buttons_evenly_spaced(vault_ui):
		return
	if not _assert_unlock_buttons_disabled_when_insufficient(vault_ui):
		return

	await vault_ui._prepare_unlock_animation_target(3)
	var locked_rect_before := vault_ui.slots[3].get_lock_icon_global_rect()
	var expected_lock_size := clampf(CardSlotUI.SLOT_SIZE.x * 0.45, 39.0, 63.0)
	if locked_rect_before.size != Vector2(expected_lock_size, expected_lock_size):
		return _fail("unlock_animation_target_lock_size_wrong")
	await vault_ui._play_unlock_key_animation("gold", 3)
	await get_tree().process_frame
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
	if vault_ui._synthesize_btn.text != "锻造":
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

func _assert_action_buttons_evenly_spaced(vault_ui: VaultUI) -> bool:
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
	var gap_a: float = buttons[1].position.y - buttons[0].position.y
	var gap_b: float = buttons[2].position.y - buttons[1].position.y
	var gap_c: float = buttons[3].position.y - buttons[2].position.y
	if absf(gap_a - gap_b) > 0.1 or absf(gap_b - gap_c) > 0.1:
		_fail("vault_action_buttons_not_even")
		return false
	if buttons[0].text != Localization.t("ui.vault.organize"):
		_fail("vault_organize_button_text_wrong")
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
	overlay._start_reward_flight(icon, wide_target_item, Vector2(420, 360), 0.0)
	await get_tree().create_timer(2.20).timeout
	await get_tree().process_frame
	if is_instance_valid(icon):
		overlay.queue_free()
		_fail("reward_key_icon_not_cleaned")
		return false
	overlay.queue_free()
	return true

func _color_close(a: Color, b: Color, epsilon: float = 0.005) -> bool:
	return absf(a.r - b.r) <= epsilon and absf(a.g - b.g) <= epsilon and absf(a.b - b.b) <= epsilon and absf(a.a - b.a) <= epsilon


func _fail(reason: String) -> void:
	push_error("VAULT_REORDER " + reason)
	get_tree().quit(1)
