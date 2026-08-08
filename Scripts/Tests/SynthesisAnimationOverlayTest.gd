extends Node

const SynthesisAnimationOverlayScript = preload("res://Scripts/UI/SynthesisAnimationOverlay.gd")


func _ready() -> void:
	var cards: Array[CardInfo] = CardDataManager.get_cards_by_deck_id(1)
	if cards.size() != 5:
		return _fail("cards_missing")
	var sources := _make_sources(cards)
	if ApiClient._apply_optional_draw_key({"deck": {"id": 1}}):
		return _fail("missing_draw_key_applied")
	var reward_entries := SynthesisAnimationOverlayScript.extract_reward_entries({
		"gold_reward": 200,
		"rewards": {"gold": 200, "gems": 10, "unlocked_vault_slots": [8, 9]},
		"exp_result": {"rewards": [
			{"type": "gold", "amount": 25},
			{"type": "gem", "amount": 3},
			{"type": "slot", "slot_type": "hand", "slot_index": 16},
		]},
	})
	if reward_entries.size() != 5:
		return _fail("reward_entry_count_wrong")
	if int(reward_entries[0].get("amount", 0)) != 225 or int(reward_entries[1].get("amount", 0)) != 13:
		return _fail("currency_rewards_not_aggregated")
	var direct_stamina_entries := SynthesisAnimationOverlayScript.extract_reward_entries({
		"rewards": {"stamina": {"amount": 4}},
	})
	if direct_stamina_entries.size() != 1 or str(direct_stamina_entries[0].get("type", "")) != "stamina":
		return _fail("stamina_reward_entry_missing")
	if absf(SynthesisAnimationOverlayScript.REWARD_STAMINA_FLIGHT_DURATION - 1.0) > 0.001:
		return _fail("stamina_reward_duration_wrong")
	if absf(SynthesisAnimationOverlayScript.REWARD_GOLD_FLIGHT_DURATION - 1.3) > 0.001:
		return _fail("gold_reward_duration_wrong")
	if absf(SynthesisAnimationOverlayScript.REWARD_GEMS_FLIGHT_DURATION - 1.6) > 0.001:
		return _fail("gems_reward_duration_wrong")
	if absf(SynthesisAnimationOverlayScript.REWARD_REVERSE_RATIO - 0.20) > 0.001:
		return _fail("reward_reverse_ratio_wrong")
	var key_texture := load(SynthesisAnimationOverlayScript.REWARD_KEY_TEXTURE_PATH) as Texture2D
	if key_texture == null or key_texture.get_size().y != 256.0:
		return _fail("reward_key_asset_missing")
	var key_image := key_texture.get_image()
	if key_image == null or key_image.get_pixel(0, 0).a > 0.05:
		return _fail("reward_key_alpha_missing")

	var locked_slot := CardSlotUI.new()
	locked_slot.position = Vector2(760, 520)
	add_child(locked_slot)
	await get_tree().process_frame
	locked_slot.set_unlocked(false)
	var lock_rect := locked_slot.get_lock_icon_global_rect()
	if lock_rect.size.x <= 1.0:
		return _fail("reward_lock_target_missing")
	for index in range(reward_entries.size()):
		reward_entries[index]["target_rect"] = lock_rect
		if str(reward_entries[index].get("slot_type", "")) == "hand":
			reward_entries[index]["target_slot"] = locked_slot

	var overlay = SynthesisAnimationOverlayScript.new()
	overlay.setup(sources, Rect2(Vector2(8, 210), Vector2(104, 36)), true)
	await get_tree().process_frame
	get_tree().root.add_child(overlay)
	var relic_landing_events: Array[Dictionary] = []
	var relic_landing_listener := func(event_name: String) -> void:
		if event_name == "relic_landing":
			relic_landing_events.append({
				"msec": Time.get_ticks_msec(),
			})
	AudioManager.sfx_played.connect(relic_landing_listener)
	await get_tree().process_frame
	var wait_probe := {"relic_formed_before_payload": false}
	var expected_relic_height := get_viewport().get_visible_rect().size.y * (3.0 / 5.0) * 1.30
	var relic_rect := overlay._get_centered_relic_rect()
	if absf(relic_rect.size.y - expected_relic_height) > 1.0:
		return _fail("relic_height_wrong")
	if absf(overlay.RELIC_HOLD_DURATION - 0.50) > 0.001:
		return _fail("relic_hold_duration_wrong")
	if absf(overlay.ART_FLIGHT_SFX_LEAD_TIME - 0.10) > 0.001:
		return _fail("art_flight_sfx_lead_time_wrong")
	var reward_probe_item := {"type": "gold", "target_rect": Rect2(Vector2(860, 120), Vector2(30, 30))}
	var reward_probe_start := Vector2(240, 260)
	var reward_probe_icon := overlay._create_reward_icon(reward_probe_item, reward_probe_start)
	if reward_probe_icon == null:
		return _fail("reward_probe_icon_missing")
	overlay._start_reward_flight(reward_probe_icon, reward_probe_item, reward_probe_start, 0.0)
	await get_tree().create_timer(SynthesisAnimationOverlayScript.REWARD_GOLD_FLIGHT_DURATION * 0.90).timeout
	if not is_instance_valid(reward_probe_icon):
		return _fail("reward_probe_icon_disappeared_before_target")
	if reward_probe_icon.modulate.a < 0.99:
		return _fail("reward_probe_icon_faded_before_target")
	await get_tree().create_timer(SynthesisAnimationOverlayScript.REWARD_GOLD_FLIGHT_DURATION * 0.20).timeout
	if is_instance_valid(reward_probe_icon):
		return _fail("reward_probe_icon_not_removed_after_target")
	var relic_probe := Control.new()
	relic_probe.name = "RelicFlightAlphaProbe"
	relic_probe.position = Vector2(260, 260)
	relic_probe.size = Vector2(80, 120)
	relic_probe.modulate.a = 1.0
	overlay.add_child(relic_probe)
	var original_nav_target: Rect2 = overlay.get("_nav_target_rect")
	overlay.set("_nav_target_rect", Rect2(Vector2(20, 220), Vector2(104, 36)))
	var relic_probe_start_msec := Time.get_ticks_msec()
	var relic_probe_events_before := relic_landing_events.size()
	overlay._send_relic_to_nav(relic_probe)
	await get_tree().create_timer(SynthesisAnimationOverlayScript.RELIC_TO_NAV_DURATION * 0.80).timeout
	if not is_instance_valid(relic_probe):
		return _fail("relic_probe_removed_before_target")
	if relic_probe.modulate.a < 0.99:
		return _fail("relic_probe_faded_before_target")
	if relic_landing_events.size() != relic_probe_events_before:
		return _fail("relic_landing_played_before_target")
	await get_tree().create_timer(SynthesisAnimationOverlayScript.RELIC_TO_NAV_DURATION * 0.35).timeout
	if is_instance_valid(relic_probe):
		return _fail("relic_probe_not_removed_after_target")
	if relic_landing_events.size() != relic_probe_events_before + 1:
		return _fail("relic_landing_missing_after_target")
	var relic_probe_event: Dictionary = relic_landing_events[relic_landing_events.size() - 1]
	var relic_probe_elapsed := float(int(relic_probe_event.get("msec", 0)) - relic_probe_start_msec) / 1000.0
	if relic_probe_elapsed < SynthesisAnimationOverlayScript.RELIC_TO_NAV_DURATION * 0.95:
		return _fail("relic_landing_too_early")
	overlay.set("_nav_target_rect", original_nav_target)
	var preview_nodes := overlay._create_card_nodes()
	overlay._bind_card_nodes(preview_nodes)
	if preview_nodes.size() > 0:
		preview_nodes[0].rotation_degrees = -4.0
	var art_nodes := await overlay._dissolve_to_art(preview_nodes)
	if art_nodes.is_empty():
		return _fail("art_nodes_missing")
	if absf(art_nodes[0].rotation_degrees + 4.0) > 0.001:
		return _fail("art_rotation_not_inherited")
	var art_shadow = art_nodes[0].get_meta("shadow", null)
	if not (art_shadow is TextureRect) or not is_instance_valid(art_shadow):
		return _fail("art_shadow_missing")
	if absf(art_shadow.rotation_degrees + 4.0) > 0.001:
		return _fail("art_shadow_rotation_not_inherited")
	await overlay._fly_art_to_relic_slots(art_nodes, relic_rect)
	if absf(art_nodes[0].rotation_degrees) > 0.001:
		return _fail("art_rotation_not_normalized")
	if art_shadow is TextureRect and is_instance_valid(art_shadow) and absf(art_shadow.rotation_degrees) > 0.001:
		return _fail("art_shadow_rotation_not_normalized")
	for art in art_nodes:
		var shadow = art.get_meta("shadow", null)
		if shadow is TextureRect and is_instance_valid(shadow):
			shadow.queue_free()
		if is_instance_valid(art):
			art.queue_free()
	get_tree().create_timer(3.0).timeout.connect(func():
		if is_instance_valid(overlay):
			wait_probe["relic_formed_before_payload"] = overlay.find_child("SynthesisRelic", true, false) != null
			overlay.set_reward_items(reward_entries, true)
	)
	await overlay.play()
	if AudioManager.sfx_played.is_connected(relic_landing_listener):
		AudioManager.sfx_played.disconnect(relic_landing_listener)
	await get_tree().process_frame
	if not bool(wait_probe.get("relic_formed_before_payload", false)):
		return _fail("relic_did_not_form_before_delayed_server_payload")
	if is_instance_valid(overlay):
		return _fail("overlay_not_freed")
	if locked_slot.get_lock_icon_global_rect().size.x > 1.0:
		return _fail("reward_key_did_not_consume_lock")

	var store_overlay = SynthesisAnimationOverlayScript.new()
	store_overlay.setup([sources[0]], Rect2(Vector2(8, 210), Vector2(104, 36)))
	get_tree().root.add_child(store_overlay)
	await store_overlay.play_store_to_nav()
	await get_tree().process_frame
	if is_instance_valid(store_overlay):
		return _fail("store_overlay_not_freed")

	var discard_overlay = SynthesisAnimationOverlayScript.new()
	discard_overlay.setup([sources[1]], Rect2(Vector2(8, 210), Vector2(104, 36)))
	get_tree().root.add_child(discard_overlay)
	await discard_overlay.play_discard()
	await get_tree().process_frame
	if is_instance_valid(discard_overlay):
		return _fail("discard_overlay_not_freed")

	print("SYNTHESIS_ANIMATION_OVERLAY ok cards=5 color=purple rewards=5 art_rotation=true relic_landing=true key_unlock=true store=true discard=true")
	get_tree().quit(0)


func _make_sources(cards: Array[CardInfo]) -> Array[Dictionary]:
	var sources: Array[Dictionary] = []
	for i in range(5):
		var card := CardInfo.new(cards[i].to_dict())
		card.color = CardColor.ColorType.PURPLE
		sources.append({
			"index": i,
			"card": card,
			"global_rect": Rect2(Vector2(170 + i * 72, 470 - absf(float(i) - 2.0) * 18.0), Vector2(64, 90)),
			"visible": true,
		})
	return sources


func _fail(reason: String) -> void:
	push_error("SYNTHESIS_ANIMATION_OVERLAY " + reason)
	get_tree().quit(1)
