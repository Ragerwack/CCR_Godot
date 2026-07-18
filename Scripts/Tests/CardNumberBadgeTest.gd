extends Node

const OrangeCardDrawOverlayScript = preload("res://Scripts/UI/OrangeCardDrawOverlay.gd")
const PurpleCardDrawOverlayScript = preload("res://Scripts/UI/PurpleCardDrawOverlay.gd")

func _ready() -> void:
	var card_display := CardDisplay.new()
	card_display.size = Vector2(200, 280)
	add_child(card_display)
	card_display.set_card(CardInfo.new({
		"id": "1",
		"series_name": "测试系列",
		"deck_name": "测试卡组超长名称用于检查缩小字体",
		"card_number": 5,
		"color": "白",
		"card_name": "测试子卡超长名称用于检查缩小字体",
		"description": "测试描述",
	}), 0)
	await get_tree().process_frame

	var art: TextureRect = card_display.get("_art_image")
	var art_shadow: Panel = card_display.get("_art_shadow")
	var color_border: TextureRect = card_display.get("_color_border")
	var deck_region: Control = card_display.get("_deck_name_region")
	var deck_label: Label = card_display.get("_deck_name_label")
	var card_name_region: Control = card_display.get("_card_name_region")
	var card_name_label: Label = card_display.get("_card_name_label")
	var desc_panel: Panel = card_display.get("_description_panel")
	var series_region: Control = card_display.get("_series_tag_region")
	var series_label: Label = card_display.get("_series_tag_label")
	var badge: Control = card_display.get("_number_badge")
	var number_label: Label = card_display.get("_number_label")
	if art == null or art_shadow == null or color_border == null or deck_region == null or deck_label == null or card_name_region == null or card_name_label == null or desc_panel == null or series_region == null or series_label == null or badge == null or number_label == null:
		_fail("card layout nodes are missing")
		return
	if art.texture == null:
		_fail("card art texture was not loaded from card id fallback")
		return
	if color_border.get_index() > art.get_index():
		_fail("color frame must stay below art while frame resources are opaque RGB")
		return
	if art_shadow.get_index() > art.get_index():
		_fail("art shadow must stay below art")
		return
	if not _rect_close(Rect2(art.position, art.size), Rect2(12.0, 25.2, 176.0, 156.8), 0.1):
		_fail("art rect does not match 6x/9y/88x/56y")
		return
	if not _rect_close(Rect2(art_shadow.position, art_shadow.size), Rect2(art.position, art.size), 0.1):
		_fail("art shadow does not follow art rect")
		return
	if art.material != null:
		_fail("art should use pre-cropped rounded texture instead of a surface mask")
		return
	if art.stretch_mode != TextureRect.STRETCH_SCALE:
		_fail("art should scale a pre-cropped texture")
		return
	if not _art_has_rounded_alpha(art.texture):
		_fail("art texture does not have baked rounded alpha")
		return
	if not _rect_close(Rect2(deck_region.position, deck_region.size), Rect2(20.0, 2.8, 160.0, 19.6)):
		_fail("deck label region does not match 10x/1y/80x/7y")
		return
	if not _rect_close(Rect2(card_name_region.position, card_name_region.size), Rect2(20.0, 187.6, 160.0, 16.8)):
		_fail("card name rect does not keep 2y gap from art")
		return
	if not _rect_close(Rect2(desc_panel.position, desc_panel.size), Rect2(16.0, 210.0, 168.0, 47.6)):
		_fail("description rect does not match 8x/75y/84x/17y")
		return
	if not _rect_close(Rect2(series_region.position, series_region.size), Rect2(20.0, 263.2, 160.0, 14.0)):
		_fail("series label rect does not match 10x/94y/80x/5y")
		return
	if not _font_fits(deck_label, deck_region.size):
		_fail("deck label font was not shrunk to fit")
		return
	if _font_fits_at_size(deck_label, deck_region.size, deck_label.get_theme_font_size("font_size") + 1):
		_fail("deck label font is not the maximum size that fits")
		return
	if not _font_fits(card_name_label, card_name_region.size):
		_fail("card name label font was not shrunk to fit")
		return
	if series_label.get_theme_font_size("font_size") > deck_label.get_theme_font_size("font_size"):
		_fail("series label font should be smaller than deck label font")
		return
	if number_label.text != "5":
		_fail("number label does not show the card number")
		return
	if number_label.get_theme_font_size("font_size") != 16:
		_fail("number label font size was not increased by two points")
		return
	if not _rect_close(Rect2(badge.position, badge.size), Rect2(162.2, 2.24, 35.8, 35.84), 0.2):
		_fail("number badge is not restored to the card top-right corner")
		return
	var epsilon := 0.01
	if badge.position.x < -epsilon or badge.position.y < -epsilon:
		_fail("number badge starts outside the card")
		return
	if badge.position.x + badge.size.x > card_display.size.x + epsilon:
		_fail("number badge extends past the card's right edge")
		return
	if badge.position.y + badge.size.y > card_display.size.y + epsilon:
		_fail("number badge extends past the card's bottom edge")
		return
	if not _advanced_title_colors_are_consistent():
		return
	if not _card_text_styles_survive_global_page_styling():
		return
	if not await _slot_title_colors_survive_reuse_and_draw_animation():
		return
	if not await _green_draw_shine_runs_only_after_landing():
		return
	if not await _blue_draw_flip_then_shine_runs_in_order():
		return
	if not await _draw_refresh_reveals_each_card_only_when_its_animation_starts():
		return
	if not _green_draw_shine_delays_the_next_card():
		return
	if not _blue_draw_presentation_delays_the_next_card():
		return
	if not await _purple_draw_lightning_teleport_runs_in_order():
		return
	if not _purple_draw_presentation_delays_the_next_card():
		return
	if not await _orange_draw_sun_magic_circle_and_flight_run_in_order():
		return
	if not _orange_draw_presentation_delays_the_next_card():
		return
	if not await _black_draw_fullscreen_sequence_runs_in_order():
		return
	if not _black_draw_presentation_delays_the_next_card():
		return

	print("CARD_NUMBER_BADGE ok")
	get_tree().quit(0)

func _rect_close(actual: Rect2, expected: Rect2, epsilon: float = 0.05) -> bool:
	return actual.position.distance_to(expected.position) <= epsilon and actual.size.distance_to(expected.size) <= epsilon

func _font_fits(label: Label, target_size: Vector2) -> bool:
	return _font_fits_at_size(label, target_size, label.get_theme_font_size("font_size"))

func _font_fits_at_size(label: Label, target_size: Vector2, font_size: int) -> bool:
	var font := label.get_theme_font("font")
	if font == null:
		return true
	var text_size := font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	return text_size.x <= target_size.x * 0.99 and font.get_height(font_size) <= target_size.y * 0.99

func _art_has_rounded_alpha(texture: Texture2D) -> bool:
	var image := texture.get_image()
	if image == null or image.is_empty():
		return false
	image.convert(Image.FORMAT_RGBA8)
	var width := image.get_width()
	var height := image.get_height()
	if width <= 2 or height <= 2:
		return false
	return image.get_pixel(0, 0).a <= 0.01 and image.get_pixel(width / 2, height / 2).a > 0.99

func _advanced_title_colors_are_consistent() -> bool:
	for color_name in ["green", "blue", "purple", "orange", "black", "red"]:
		var display := CardDisplay.new()
		display.size = Vector2(200, 280)
		add_child(display)
		display.set_card(CardInfo.new({
			"id": "1",
			"series_name": "测试系列",
			"deck_name": "测试卡组",
			"card_number": 1,
			"color": color_name,
			"card_name": "测试子卡",
			"description": "测试描述",
		}), 0)
		var deck_label: Label = display.get("_deck_name_label")
		var card_name_label: Label = display.get("_card_name_label")
		var series_label: Label = display.get("_series_tag_label")
		var deck_color := deck_label.get_theme_color("font_color")
		var card_name_color := card_name_label.get_theme_color("font_color")
		var series_color := series_label.get_theme_color("font_color")
		if not _color_close(deck_color, card_name_color) or not _color_close(deck_color, series_color):
			_fail("advanced title colors are not consistent for " + color_name)
			return false
		if _color_close(deck_color, CardDisplay.CARD_TEXT_COLOR):
			_fail("advanced title color still uses white-card text color for " + color_name)
			return false
		display.queue_free()
	return true

func _card_text_styles_survive_global_page_styling() -> bool:
	var page_root := Control.new()
	add_child(page_root)
	var display := CardDisplay.new()
	display.size = Vector2(200, 280)
	page_root.add_child(display)
	display.set_card(CardInfo.new({
		"id": "1",
		"series_name": "测试系列",
		"deck_name": "测试卡组",
		"card_number": 3,
		"color": "purple",
		"card_name": "测试子卡",
		"description": "测试描述",
	}), 0)

	var main_style_applier := MainUI.new()
	# 直接复现抽卡页/保险箱页创建、后台同步和 resize 都会调用的页面级染色。
	# 重复调用用于防止修复只依赖某一次通知或动画结束后的补刷。
	main_style_applier.call("_apply_game_text_color", page_root)
	main_style_applier.call("_apply_game_text_color", page_root)

	var deck_label: Label = display.get("_deck_name_label")
	var card_name_label: Label = display.get("_card_name_label")
	var series_label: Label = display.get("_series_tag_label")
	var number_label: Label = display.get("_number_label")
	var description_label: Label = display.get("_description_label")
	var passed := true
	for title_label in [deck_label, card_name_label, series_label]:
		if title_label == null or not _color_close(title_label.get_theme_color("font_color"), CardDisplay.CARD_TEXT_COLOR_PURPLE):
			_fail("global page styling overwrote rarity title color")
			passed = false
			break
		if title_label.has_theme_color_override("font_shadow_color"):
			_fail("global page styling leaked label shadow into card title")
			passed = false
			break
	if passed:
		for fixed_label in [number_label, description_label]:
			if fixed_label == null or not _color_close(fixed_label.get_theme_color("font_color"), CardDisplay.CARD_TEXT_COLOR):
				_fail("global page styling overwrote fixed card text color")
				passed = false
				break
			if fixed_label.has_theme_color_override("font_shadow_color"):
				_fail("global page styling leaked label shadow into fixed card text")
				passed = false
				break
	main_style_applier.queue_free()
	page_root.queue_free()
	return passed

func _slot_title_colors_survive_reuse_and_draw_animation() -> bool:
	var slot := CardSlotUI.new()
	slot.area_type = "pool"
	add_child(slot)
	await get_tree().process_frame
	var purple_card := CardInfo.new({
		"id": "1",
		"series_name": "测试系列",
		"deck_name": "测试卡组",
		"card_number": 1,
		"color": "purple",
		"card_name": "测试子卡",
		"description": "测试描述",
	})
	slot.set_card(purple_card, 0)
	if not _slot_title_color_matches(slot, CardDisplay.CARD_TEXT_COLOR_PURPLE):
		_fail("slot purple title color wrong before draw animation")
		return false
	slot.play_draw_drop_in(0.0)
	await get_tree().create_timer(0.45).timeout
	if not _slot_title_color_matches(slot, CardDisplay.CARD_TEXT_COLOR_PURPLE):
		_fail("slot purple title color changed after draw animation")
		return false
	var blue_card := CardInfo.new({
		"id": "1",
		"series_name": "测试系列",
		"deck_name": "测试卡组",
		"card_number": 2,
		"color": "blue",
		"card_name": "测试子卡",
		"description": "测试描述",
	})
	slot.set_card(blue_card, 0)
	if not _slot_title_color_matches(slot, CardDisplay.CARD_TEXT_COLOR_BLUE):
		_fail("slot blue title color wrong after slot reuse")
		return false
	slot.queue_free()
	return true

func _slot_title_color_matches(slot: CardSlotUI, expected: Color) -> bool:
	if slot == null or slot.card_display == null:
		return false
	var deck_label: Label = slot.card_display.get("_deck_name_label")
	var card_name_label: Label = slot.card_display.get("_card_name_label")
	var series_label: Label = slot.card_display.get("_series_tag_label")
	if deck_label == null or card_name_label == null or series_label == null:
		return false
	return (
		_color_close(deck_label.get_theme_color("font_color"), expected)
		and _color_close(card_name_label.get_theme_color("font_color"), expected)
		and _color_close(series_label.get_theme_color("font_color"), expected)
	)

func _green_draw_shine_runs_only_after_landing() -> bool:
	var slot := CardSlotUI.new()
	slot.area_type = "pool"
	add_child(slot)
	await get_tree().process_frame
	var green_card := _test_card("green", 3)
	slot.set_card(green_card, 0)
	slot.play_draw_drop_in(0.0)
	# 取基础跌落的中段，避免 headless 首帧资源加载造成临界计时抖动。
	await get_tree().create_timer(CardSlotUI.DROP_IN_DURATION * 0.75).timeout
	if slot.card_display.is_green_draw_shine_playing():
		_fail("green shine started before the white-card drop finished")
		return false
	await get_tree().create_timer(CardSlotUI.DRAW_DROP_TOTAL_DURATION).timeout
	if not slot.card_display.is_green_draw_shine_playing():
		_fail("green shine did not start after landing")
		return false
	var shine_overlay: ColorRect = slot.card_display.get("_rarity_shine_overlay")
	var shine_material: ShaderMaterial = slot.card_display.get("_rarity_shine_material")
	if shine_overlay == null or shine_material == null or not shine_overlay.visible:
		_fail("green shine overlay or material is missing")
		return false
	var progress := float(shine_material.get_shader_parameter("progress"))
	if progress <= -0.20 or progress >= 1.20:
		_fail("green shine progress is outside the active sweep")
		return false
	await get_tree().create_timer(CardDisplay.GREEN_DRAW_SHINE_DURATION + 0.06).timeout
	if slot.card_display.is_green_draw_shine_playing():
		_fail("green shine exceeded its 0.5 second duration")
		return false

	slot.set_card(_test_card("white", 4), 0)
	slot.play_draw_drop_in(0.0)
	await get_tree().create_timer(CardSlotUI.DRAW_DROP_TOTAL_DURATION + 0.08).timeout
	if slot.card_display.is_green_draw_shine_playing():
		_fail("white card incorrectly played the green shine")
		return false
	slot.queue_free()
	return true

func _green_draw_shine_delays_the_next_card() -> bool:
	var pool_ui := CardPoolUI.new()
	pool_ui.columns = 8
	var cards: Array = [
		_test_card("white", 1),
		_test_card("green", 2),
		_test_card("white", 3),
		_test_card("green", 4),
		_test_card("white", 5),
	]
	var delays := pool_ui._draw_drop_delays(cards, false)
	if delays.size() != cards.size():
		pool_ui.free()
		_fail("rarity delay count does not match cards")
		return false
	var full_white_duration := CardSlotUI.DRAW_DROP_COMPLETE_DURATION
	var full_green_duration := maxf(full_white_duration, CardSlotUI.DRAW_DROP_TOTAL_DURATION + CardSlotUI.GREEN_RARITY_SHINE_DURATION)
	if not is_equal_approx(delays[1] - delays[0], CardPoolUI.WHITE_DRAW_REVEAL_INTERVAL):
		pool_ui.free()
		_fail("white card did not use the fast reveal interval")
		return false
	if not is_equal_approx(delays[2] - delays[1], full_green_duration):
		pool_ui.free()
		_fail("next normal card starts before the green effect finishes")
		return false
	if not is_equal_approx(delays[4] - delays[3], full_green_duration):
		pool_ui.free()
		_fail("second green card did not delay its next card")
		return false
	var rapid_delays := pool_ui._draw_drop_delays(cards, true)
	if not is_equal_approx(rapid_delays[1] - rapid_delays[0], CardPoolUI.WHITE_DRAW_REVEAL_INTERVAL):
		pool_ui.free()
		_fail("rapid draw did not keep the white fast reveal interval")
		return false
	if not is_equal_approx(rapid_delays[2] - rapid_delays[1], full_green_duration):
		pool_ui.free()
		_fail("rapid draw skipped the full green effect duration")
		return false
	pool_ui.free()
	return true

func _blue_draw_flip_then_shine_runs_in_order() -> bool:
	var slot := CardSlotUI.new()
	slot.area_type = "pool"
	add_child(slot)
	await get_tree().process_frame
	slot.set_card(_test_card("blue", 6), 0)
	slot.play_draw_drop_in(0.0)
	if not is_equal_approx(CardSlotUI.BLUE_DRAW_FLIP_DURATION, 0.60):
		_fail("blue card floating flip duration should be 0.6 seconds")
		return false
	await get_tree().create_timer(CardSlotUI.BLUE_DRAW_FLIP_DURATION * 0.5).timeout
	if not slot.card_display.is_blue_draw_back_visible():
		_fail("blue card back was not shown during the floating flip")
		return false
	var art: TextureRect = slot.card_display.get("_art_image")
	var deck_region: Control = slot.card_display.get("_deck_name_region")
	if art == null or deck_region == null or art.visible or deck_region.visible:
		_fail("blue card back exposes front art or text during the flip")
		return false
	await get_tree().create_timer(CardSlotUI.BLUE_DRAW_FLIP_DURATION * 0.65).timeout
	if slot.card_display.is_blue_draw_back_visible():
		_fail("blue card back remained visible after the floating flip")
		return false
	await get_tree().create_timer(CardSlotUI.DROP_IN_DURATION * 0.75).timeout
	if slot.card_display.is_green_draw_shine_playing():
		_fail("blue shine started before the white-card drop finished")
		return false
	await get_tree().create_timer(CardSlotUI.DRAW_DROP_TOTAL_DURATION).timeout
	if not slot.card_display.is_green_draw_shine_playing():
		_fail("blue shine did not start after landing")
		return false
	var shine_material: ShaderMaterial = slot.card_display.get("_rarity_shine_material")
	if shine_material == null:
		_fail("blue shine material is missing")
		return false
	var shine_color: Color = shine_material.get_shader_parameter("shine_color")
	if shine_color.b <= shine_color.r:
		_fail("blue shine does not use a blue light color")
		return false
	await get_tree().create_timer(CardDisplay.BLUE_DRAW_SHINE_DURATION + 0.06).timeout
	if slot.card_display.is_green_draw_shine_playing():
		_fail("blue shine exceeded its 0.5 second duration")
		return false
	slot.queue_free()
	return true

func _blue_draw_presentation_delays_the_next_card() -> bool:
	var pool_ui := CardPoolUI.new()
	pool_ui.columns = 8
	var cards: Array = [
		_test_card("white", 1),
		_test_card("blue", 2),
		_test_card("white", 3),
		_test_card("blue", 4),
		_test_card("white", 5),
	]
	var full_blue_duration := CardSlotUI.BLUE_DRAW_FLIP_DURATION + maxf(CardSlotUI.DRAW_DROP_COMPLETE_DURATION, CardSlotUI.DRAW_DROP_TOTAL_DURATION + CardSlotUI.BLUE_RARITY_SHINE_DURATION)
	var delays := pool_ui._draw_drop_delays(cards, false)
	if not is_equal_approx(delays[2] - delays[1], full_blue_duration) or not is_equal_approx(delays[4] - delays[3], full_blue_duration):
		pool_ui.free()
		_fail("next card starts before the complete blue presentation finishes")
		return false
	var rapid_delays := pool_ui._draw_drop_delays(cards, true)
	if not is_equal_approx(rapid_delays[2] - rapid_delays[1], full_blue_duration):
		pool_ui.free()
		_fail("rapid draw skipped the complete blue presentation")
		return false
	pool_ui.free()
	return true

func _draw_refresh_reveals_each_card_only_when_its_animation_starts() -> bool:
	var previous_pool_slots := GameManager.player_data.pool_slots
	GameManager.player_data.pool_slots = 3
	var pool_ui := CardPoolUI.new()
	pool_ui.auto_warm_enabled = false
	add_child(pool_ui)
	await get_tree().process_frame

	var cards: Array = [
		_test_card("white", 1),
		_test_card("white", 2),
		_test_card("white", 3),
	]
	pool_ui._refresh_display(cards, true, false)
	if not pool_ui.slots[0].is_occupied:
		GameManager.player_data.pool_slots = previous_pool_slots
		pool_ui.queue_free()
		_fail("first draw card was not revealed immediately")
		return false
	if pool_ui.slots[1].is_occupied or pool_ui.slots[2].is_occupied:
		GameManager.player_data.pool_slots = previous_pool_slots
		pool_ui.queue_free()
		_fail("draw refresh revealed cards before their own animation started")
		return false

	await get_tree().create_timer(CardPoolUI.WHITE_DRAW_REVEAL_INTERVAL * 0.5).timeout
	if pool_ui.slots[1].is_occupied:
		GameManager.player_data.pool_slots = previous_pool_slots
		pool_ui.queue_free()
		_fail("second white card appeared before the 0.15 second reveal interval")
		return false

	await get_tree().create_timer(CardPoolUI.WHITE_DRAW_REVEAL_INTERVAL * 0.75).timeout
	if not pool_ui.slots[1].is_occupied:
		GameManager.player_data.pool_slots = previous_pool_slots
		pool_ui.queue_free()
		_fail("second white card did not reveal after the 0.15 second interval")
		return false
	if pool_ui.slots[2].is_occupied:
		GameManager.player_data.pool_slots = previous_pool_slots
		pool_ui.queue_free()
		_fail("third white card appeared before the second white interval elapsed")
		return false

	await get_tree().create_timer(CardPoolUI.WHITE_DRAW_REVEAL_INTERVAL * 1.05).timeout
	if not pool_ui.slots[2].is_occupied:
		GameManager.player_data.pool_slots = previous_pool_slots
		pool_ui.queue_free()
		_fail("third white card did not reveal on the fast white cadence")
		return false

	pool_ui._refresh_display(cards, false, false)
	if not pool_ui.slots[0].is_occupied or not pool_ui.slots[1].is_occupied or not pool_ui.slots[2].is_occupied:
		GameManager.player_data.pool_slots = previous_pool_slots
		pool_ui.queue_free()
		_fail("non-animated pool refresh should still render all cards immediately")
		return false

	GameManager.player_data.pool_slots = previous_pool_slots
	pool_ui.queue_free()
	return true

func _purple_draw_lightning_teleport_runs_in_order() -> bool:
	var slot := CardSlotUI.new()
	slot.area_type = "pool"
	slot.position = Vector2(260, 280)
	add_child(slot)
	await get_tree().process_frame
	slot.set_card(_test_card("purple", 9), 0)
	slot.play_draw_drop_in(0.0)
	var overlay: Control = slot.get("_purple_draw_overlay")
	if overlay == null or slot.card_display.visible:
		_fail("purple draw did not hide the slot card and create its local effect overlay")
		return false
	if overlay.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		_fail("purple local effect incorrectly blocks the whole screen")
		return false
	var reveal_card: CardDisplay = overlay.get("_card_display")
	var electric_ring: ColorRect = overlay.get("_electric_ring")
	var bolt_core: Line2D = overlay.get("_bolt_core")
	if reveal_card == null or electric_ring == null or bolt_core == null:
		_fail("purple draw overlay is missing the card, electric ring, or lightning bolt")
		return false
	await get_tree().create_timer(PurpleCardDrawOverlayScript.CHARGE_DURATION * 0.72).timeout
	if reveal_card.modulate.a <= 0.70 or reveal_card.position.y >= slot.global_position.y:
		_fail("purple card did not charge above its target slot")
		return false
	if electric_ring.modulate.a <= 0.25:
		_fail("purple target slot did not accumulate local electricity")
		return false
	await get_tree().create_timer(PurpleCardDrawOverlayScript.CHARGE_DURATION * 0.40).timeout
	if bolt_core.modulate.a <= 0.10 or bolt_core.default_color.b <= bolt_core.default_color.r:
		_fail("purple lightning did not strike with a purple color")
		return false
	await get_tree().create_timer(PurpleCardDrawOverlayScript.TELEPORT_DURATION + PurpleCardDrawOverlayScript.REMATERIALIZE_DURATION * 0.55).timeout
	if reveal_card.position.distance_to(slot.global_position) > 1.0 or reveal_card.modulate.a <= 0.45:
		_fail("purple card did not rematerialize directly inside its target slot")
		return false
	await get_tree().create_timer(PurpleCardDrawOverlayScript.REMATERIALIZE_DURATION * 0.55 + PurpleCardDrawOverlayScript.SETTLE_DURATION + 0.10).timeout
	if is_instance_valid(overlay):
		_fail("purple draw overlay was not cleaned after the 1.5 second sequence")
		return false
	if not slot.card_display.visible:
		_fail("purple draw did not reveal the target slot card after teleporting")
		return false
	slot.queue_free()
	return true

func _purple_draw_presentation_delays_the_next_card() -> bool:
	var pool_ui := CardPoolUI.new()
	var cards: Array = [
		_test_card("white", 1),
		_test_card("purple", 2),
		_test_card("white", 3),
	]
	var delays := pool_ui._draw_drop_delays(cards, false)
	if not is_equal_approx(delays[2] - delays[1], PurpleCardDrawOverlayScript.TOTAL_DURATION):
		pool_ui.free()
		_fail("next card starts before the complete purple lightning teleport finishes")
		return false
	var rapid_delays := pool_ui._draw_drop_delays(cards, true)
	if not is_equal_approx(rapid_delays[2] - rapid_delays[1], PurpleCardDrawOverlayScript.TOTAL_DURATION):
		pool_ui.free()
		_fail("rapid draw skipped the complete purple lightning teleport")
		return false
	pool_ui.free()
	return true

func _orange_draw_sun_magic_circle_and_flight_run_in_order() -> bool:
	var slot := CardSlotUI.new()
	slot.area_type = "pool"
	slot.position = Vector2(250, 190)
	add_child(slot)
	await get_tree().process_frame
	slot.set_card(_test_card("orange", 8), 0)
	slot.play_draw_drop_in(0.0)
	var overlay: Control = slot.get("_orange_draw_overlay")
	if overlay == null or slot.card_display.visible:
		_fail("orange draw did not hide the slot card and create a fullscreen overlay")
		return false
	var sun: ColorRect = overlay.get("_sun")
	var halo: ColorRect = overlay.get("_halo")
	var magic_circle: TextureRect = overlay.get("_magic_circle")
	var reveal_card: CardDisplay = overlay.get("_card_display")
	if sun == null or halo == null or magic_circle == null or reveal_card == null or magic_circle.texture == null:
		_fail("orange draw overlay is missing the sun, halo, magic circle, or card")
		return false
	var expected_sun_diameter: float = overlay.get_viewport_rect().size.y * 0.75
	if not is_equal_approx(sun.size.y, expected_sun_diameter):
		_fail("orange sun diameter is not three quarters of the screen height")
		return false
	await get_tree().create_timer(OrangeCardDrawOverlayScript.SUN_GROW_DURATION * 0.52).timeout
	if sun.scale.x <= 0.05 or sun.scale.x >= 0.98 or sun.modulate.a <= 0.8:
		_fail("orange sun did not grow from the center point during the first second")
		return false
	if halo.modulate.a > 0.05 or magic_circle.modulate.a > 0.05 or reveal_card.modulate.a > 0.05:
		_fail("orange halo or magic circle appeared before the sun finished growing")
		return false
	await get_tree().create_timer(OrangeCardDrawOverlayScript.SUN_GROW_DURATION * 0.58).timeout
	if halo.modulate.a <= 0.05 or halo.scale.x <= 0.25:
		_fail("orange sun did not release the expanding golden halo")
		return false
	await get_tree().create_timer(OrangeCardDrawOverlayScript.MAGIC_REVEAL_DURATION * 0.55).timeout
	if magic_circle.modulate.a <= 0.35 or reveal_card.modulate.a <= 0.35:
		_fail("orange magic circle and card did not replace the sun during the second phase")
		return false
	var center_position: Vector2 = (overlay.get_viewport_rect().size - reveal_card.size) * 0.5
	if reveal_card.position.distance_to(center_position) > 1.0:
		_fail("orange card is not centered inside the magic circle")
		return false
	await get_tree().create_timer(OrangeCardDrawOverlayScript.MAGIC_REVEAL_DURATION * 0.43 + OrangeCardDrawOverlayScript.CARD_FLY_DURATION * 0.52).timeout
	if magic_circle.modulate.a >= 0.75:
		_fail("orange magic circle did not begin disappearing during the card flight")
		return false
	if reveal_card.position.distance_to(center_position) <= 2.0:
		_fail("orange card did not begin flying toward its target slot")
		return false
	await get_tree().create_timer(OrangeCardDrawOverlayScript.CARD_FLY_DURATION * 0.58 + 0.08).timeout
	if is_instance_valid(overlay):
		_fail("orange draw overlay was not cleaned after the 2.5 second sequence")
		return false
	if not slot.card_display.visible:
		_fail("orange draw did not reveal the target slot card after the flight")
		return false
	slot.queue_free()
	return true

func _orange_draw_presentation_delays_the_next_card() -> bool:
	var pool_ui := CardPoolUI.new()
	var cards: Array = [
		_test_card("white", 1),
		_test_card("orange", 2),
		_test_card("white", 3),
	]
	var delays := pool_ui._draw_drop_delays(cards, false)
	if not is_equal_approx(delays[2] - delays[1], OrangeCardDrawOverlayScript.TOTAL_DURATION):
		pool_ui.free()
		_fail("next card starts before the complete orange presentation finishes")
		return false
	var rapid_delays := pool_ui._draw_drop_delays(cards, true)
	if not is_equal_approx(rapid_delays[2] - rapid_delays[1], OrangeCardDrawOverlayScript.TOTAL_DURATION):
		pool_ui.free()
		_fail("rapid draw skipped the complete orange presentation")
		return false
	pool_ui.free()
	return true

func _black_draw_fullscreen_sequence_runs_in_order() -> bool:
	var slot := CardSlotUI.new()
	slot.area_type = "pool"
	slot.position = Vector2(240, 180)
	add_child(slot)
	await get_tree().process_frame
	slot.set_card(_test_card("black", 7), 0)
	slot.play_draw_drop_in(0.0)
	var overlay: BlackCardDrawOverlay = slot.get("_black_draw_overlay")
	if overlay == null or slot.card_display.visible:
		_fail("black draw did not hide the slot card and create a fullscreen overlay")
		return false
	var background: ColorRect = overlay.get("_background")
	var black_hole: ColorRect = overlay.get("_black_hole")
	var reveal_card: CardDisplay = overlay.get("_card_display")
	if background == null or black_hole == null or reveal_card == null:
		_fail("black draw overlay is missing a required visual layer")
		return false
	await get_tree().create_timer(BlackCardDrawOverlay.FADE_TO_BLACK_DURATION * 0.6).timeout
	if background.color.a <= 0.05 or background.color.a >= 0.98:
		_fail("black draw background did not gradually fade to black")
		return false
	if not AudioManager.is_cinematic_silence_active():
		_fail("black draw did not start the global audio fade")
		return false
	await get_tree().create_timer(BlackCardDrawOverlay.FADE_TO_BLACK_DURATION * 0.55).timeout
	if black_hole.modulate.a <= 0.05 or black_hole.scale.x <= 0.35:
		_fail("black hole did not appear after the blackout")
		return false
	if reveal_card.modulate.a > 0.05:
		_fail("black card appeared before the black-hole reveal finished")
		return false
	await get_tree().create_timer(BlackCardDrawOverlay.BLACK_HOLE_REVEAL_DURATION).timeout
	if reveal_card.modulate.a <= 0.05 or reveal_card.scale.x <= 0.025 or reveal_card.scale.x >= 1.0:
		_fail("black card did not grow from the black-hole center")
		return false
	await get_tree().create_timer(BlackCardDrawOverlay.CARD_REVEAL_DURATION).timeout
	if background.color.a >= 0.98:
		_fail("black background did not begin disappearing during the slot flight")
		return false
	await get_tree().create_timer(BlackCardDrawOverlay.CARD_FLY_DURATION + 0.12).timeout
	if is_instance_valid(overlay):
		_fail("black draw overlay was not cleaned after the two-second sequence")
		return false
	if not slot.card_display.visible or AudioManager.is_cinematic_silence_active():
		_fail("black draw did not reveal the target slot card and restore audio")
		return false
	slot.queue_free()
	return true

func _black_draw_presentation_delays_the_next_card() -> bool:
	var pool_ui := CardPoolUI.new()
	var cards: Array = [
		_test_card("white", 1),
		_test_card("black", 2),
		_test_card("white", 3),
	]
	var delays := pool_ui._draw_drop_delays(cards, false)
	if not is_equal_approx(delays[2] - delays[1], BlackCardDrawOverlay.TOTAL_DURATION):
		pool_ui.free()
		_fail("next card starts before the complete black presentation finishes")
		return false
	var rapid_delays := pool_ui._draw_drop_delays(cards, true)
	if not is_equal_approx(rapid_delays[2] - rapid_delays[1], BlackCardDrawOverlay.TOTAL_DURATION):
		pool_ui.free()
		_fail("rapid draw skipped the complete black presentation")
		return false
	pool_ui.free()
	return true

func _test_card(color_name: String, number: int) -> CardInfo:
	return CardInfo.new({
		"id": str(number),
		"series_name": "测试系列",
		"deck_name": "测试卡组",
		"card_number": number,
		"color": color_name,
		"card_name": "测试子卡",
		"description": "测试描述",
	})

func _color_close(a: Color, b: Color, epsilon: float = 0.005) -> bool:
	return absf(a.r - b.r) <= epsilon and absf(a.g - b.g) <= epsilon and absf(a.b - b.b) <= epsilon and absf(a.a - b.a) <= epsilon

func _fail(message: String) -> void:
	push_error("CARD_NUMBER_BADGE " + message)
	get_tree().quit(1)
