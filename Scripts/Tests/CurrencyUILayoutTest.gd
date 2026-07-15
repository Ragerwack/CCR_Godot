extends Node

func _ready() -> void:
	get_window().size = Vector2i(1280, 800)
	GameManager.player_data.level = 10
	GameManager.free_refresh_count = 5
	GameManager.newbie_free_refresh_count = 5
	GameManager.player_data.gold = 10086
	GameManager.player_data.gems = 50

	var host := Control.new()
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(host)
	var currency := CurrencyUI.new()
	currency.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	currency.offset_right = -55.0
	currency.offset_top = 10.0
	currency.offset_bottom = 46.0
	currency.configure_layout(230.0)
	host.add_child(currency)
	await get_tree().process_frame
	currency.offset_bottom = currency.offset_top + maxf(36.0, currency.get_required_row_height())
	await get_tree().process_frame

	var gold_icon := currency.find_child("GoldIcon", true, false) as TextureRect
	var gem_icon := currency.find_child("GemIcon", true, false) as TextureRect
	var gold_roll := currency.find_child("GoldNumberRoll", true, false) as AssetNumberRoll
	var gem_roll := currency.find_child("GemsNumberRoll", true, false) as AssetNumberRoll
	var stamina_roll := currency.find_child("StaminaNumberRoll", true, false) as AssetNumberRoll
	if (
		gold_icon == null
		or gem_icon == null
		or gold_roll == null
		or gem_roll == null
		or stamina_roll == null
	):
		return _fail("status_nodes_missing")
	var base_width := currency.size.x
	var right_edge := currency.global_position.x + currency.size.x
	var gold_icon_x := gold_icon.global_position.x
	var gem_icon_x := gem_icon.global_position.x

	if not GameManager.player_data.spend_gold(5):
		return _fail("single_digit_gold_spend_failed")
	if gold_roll.get_moving_current_digit_count() != 1 or gold_roll.get_visible_outgoing_digit_count() != 1:
		return _fail("gold_spend_should_roll_only_one_digit")
	if _first_moving_digit_y(gold_roll) >= 0.0:
		return _fail("gold_single_digit_spend_wrong_direction")
	if not _all_static_digits_settled(gold_roll):
		return _fail("gold_unchanged_digits_moved")
	await get_tree().create_timer(AssetNumberRoll.ROLL_DURATION + 0.08).timeout

	if not GameManager.try_free_refresh():
		return _fail("stamina_single_digit_spend_failed")
	if stamina_roll.get_moving_current_digit_count() != 1 or stamina_roll.get_visible_outgoing_digit_count() != 1:
		return _fail("stamina_spend_should_roll_only_current_digit moving=%d outgoing=%d text=%s" % [
			stamina_roll.get_moving_current_digit_count(),
			stamina_roll.get_visible_outgoing_digit_count(),
			_join_current_digits(stamina_roll) + " display=" + stamina_roll.get_display_text() + " current=%d max=%d newbie=%d free=%d" % [
				GameManager.get_stamina_display_current(),
				GameManager.get_stamina_display_max(),
				GameManager.newbie_free_refresh_count,
				GameManager.free_refresh_count,
			],
		])
	if _first_moving_digit_y(stamina_roll) >= 0.0:
		return _fail("stamina_single_digit_spend_wrong_direction")
	if not _all_static_digits_settled(stamina_roll):
		return _fail("stamina_unchanged_digits_moved")
	await get_tree().create_timer(AssetNumberRoll.ROLL_DURATION + 0.08).timeout

	GameManager.player_data.add_gold(9_223_372_036_854_760_000)
	GameManager.player_data.add_gems(2_147_483_597)
	if gold_roll.get_moving_current_digit_count() <= 0 or gem_roll.get_moving_current_digit_count() <= 0:
		return _fail("asset_gain_did_not_roll_up")
	if _first_moving_digit_y(gold_roll) <= 0.0 or _first_moving_digit_y(gem_roll) <= 0.0:
		return _fail("asset_gain_wrong_direction")
	if gold_roll.get_visible_outgoing_digit_count() <= 0 or gem_roll.get_visible_outgoing_digit_count() <= 0:
		return _fail("asset_gain_old_value_not_visible")
	await get_tree().process_frame
	await get_tree().process_frame

	if _first_current_label(gold_roll).get_theme_font_size("font_size") != 18 or _first_current_label(gem_roll).get_theme_font_size("font_size") != 18:
		return _fail("font_size_changed")
	if currency.size.x <= base_width:
		return _fail("currency_row_did_not_expand")
	if not is_equal_approx(currency.global_position.x + currency.size.x, right_edge):
		return _fail("currency_right_edge_moved")
	if gold_icon.global_position.x >= gold_icon_x or gem_icon.global_position.x >= gem_icon_x:
		return _fail("resource_icons_did_not_move_left")
	var currency_rect := currency.get_global_rect()
	var gem_label_rect := _current_digits_global_rect(gem_roll)
	var gold_clip := gold_roll.get_node_or_null("NumberRollClipHost") as Control
	var gem_clip := gem_roll.get_node_or_null("NumberRollClipHost") as Control
	if gold_clip == null or gem_clip == null or gold_roll == null or gem_roll == null:
		return _fail("number_roll_parent_missing")
	if not gold_clip.clip_contents or not gem_clip.clip_contents:
		return _fail("number_roll_vertical_clip_missing")
	if gold_roll.clip_contents or gem_roll.clip_contents:
		return _fail("number_roll_outer_horizontal_clip_enabled")
	if gold_clip.size.x < gold_roll.size.x + AssetNumberRoll.CLIP_HORIZONTAL_BLEED * 2.0 - 0.1:
		return _fail("gold_horizontal_clip_boundary_not_expanded")
	if gem_clip.size.x < gem_roll.size.x + AssetNumberRoll.CLIP_HORIZONTAL_BLEED * 2.0 - 0.1:
		return _fail("gem_horizontal_clip_boundary_not_expanded")
	if gem_label_rect.end.x > currency_rect.end.x - CurrencyUI.ROW_HORIZONTAL_SAFE_MARGIN + 0.1:
		return _fail("rightmost_gem_digits_not_inside_safe_edge")
	if gold_roll.size.x + 0.1 < _current_digits_minimum_width(gold_roll) + AssetNumberRoll.TEXT_HORIZONTAL_PADDING * 2.0:
		return _fail("gold_number_roll_has_no_text_padding size=%.1f min=%.1f custom=%.1f" % [
			gold_roll.size.x,
			_current_digits_minimum_width(gold_roll) + AssetNumberRoll.TEXT_HORIZONTAL_PADDING * 2.0,
			gold_roll.custom_minimum_size.x,
		])
	if gem_roll.size.x + 0.1 < _current_digits_minimum_width(gem_roll) + AssetNumberRoll.TEXT_HORIZONTAL_PADDING * 2.0:
		return _fail("gem_number_roll_has_no_text_padding")
	await get_tree().create_timer(AssetNumberRoll.ROLL_DURATION + 0.08).timeout
	if gold_roll.get_moving_current_digit_count() != 0 or gem_roll.get_moving_current_digit_count() != 0:
		return _fail("asset_gain_roll_did_not_finish")
	if gold_roll.get_visible_outgoing_digit_count() != 0 or gem_roll.get_visible_outgoing_digit_count() != 0:
		return _fail("asset_gain_old_value_remained_visible")
	if _current_digits_global_rect(gold_roll).end.y > currency.get_global_rect().end.y + 0.1 or _current_digits_global_rect(gem_roll).end.y > currency.get_global_rect().end.y + 0.1:
		return _fail("resource_digits_clipped_vertically")
	var probe_path := OS.get_environment("CCR_CURRENCY_PROBE_PATH")
	if probe_path != "" and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(probe_path)

	if not GameManager.player_data.spend_gold(9_223_372_036_854_760_100):
		return _fail("gold_spend_failed")
	if not GameManager.player_data.spend_gems(2_147_483_607):
		return _fail("gem_spend_failed")
	if _first_moving_digit_y(gold_roll) >= 0.0 or _first_moving_digit_y(gem_roll) >= 0.0:
		return _fail("asset_spend_did_not_roll_down")
	if gold_roll.get_visible_outgoing_digit_count() <= 0 or gem_roll.get_visible_outgoing_digit_count() <= 0:
		return _fail("asset_spend_old_value_not_visible")

	if not GameManager.try_free_refresh():
		return _fail("stamina_spend_failed")
	if _first_moving_digit_y(stamina_roll) >= 0.0 or stamina_roll.get_visible_outgoing_digit_count() <= 0:
		return _fail("stamina_spend_did_not_roll_down")

	await get_tree().create_timer(AssetNumberRoll.ROLL_DURATION + 0.08).timeout
	GameManager.player_data.changed.emit()
	if gold_roll.get_visible_outgoing_digit_count() != 0 or gem_roll.get_visible_outgoing_digit_count() != 0 or stamina_roll.get_visible_outgoing_digit_count() != 0:
		return _fail("unchanged_assets_replayed_animation")

	print("CURRENCY_UI_LAYOUT ok width=%d right=%.1f roll=gain_spend_stamina" % [currency.size.x, right_edge])
	get_tree().quit(0)

func _fail(message: String) -> void:
	push_error("CURRENCY_UI_LAYOUT " + message)
	get_tree().quit(1)

func _first_current_label(roll: AssetNumberRoll) -> Label:
	for label in roll.get_current_digit_labels():
		if label.text != "":
			return label
	return roll.get_current_digit_labels()[0]

func _first_moving_digit_y(roll: AssetNumberRoll) -> float:
	for label in roll.get_current_digit_labels():
		if absf(label.position.y) > 0.01:
			return label.position.y
	return 0.0

func _all_static_digits_settled(roll: AssetNumberRoll) -> bool:
	for label in roll.get_current_digit_labels():
		if absf(label.position.y) <= 0.01:
			continue
		var has_visible_outgoing := false
		for outgoing in roll.get_outgoing_digit_labels():
			if outgoing.get_parent() == label.get_parent() and outgoing.visible:
				has_visible_outgoing = true
				break
		if not has_visible_outgoing:
			return false
	return true

func _current_digits_minimum_width(roll: AssetNumberRoll) -> float:
	var width := 0.0
	for label in roll.get_current_digit_labels():
		width += label.get_combined_minimum_size().x if label.text != "" else 0.0
	return width

func _current_digits_global_rect(roll: AssetNumberRoll) -> Rect2:
	var rect := Rect2()
	var has_rect := false
	for label in roll.get_current_digit_labels():
		if label.text == "":
			continue
		var label_rect := label.get_global_rect()
		if not has_rect:
			rect = label_rect
			has_rect = true
		else:
			rect = rect.merge(label_rect)
	return rect

func _join_current_digits(roll: AssetNumberRoll) -> String:
	var text := ""
	for label in roll.get_current_digit_labels():
		text += label.text
	return text
