extends Node

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
	if not await _slot_title_colors_survive_reuse_and_draw_animation():
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

func _color_close(a: Color, b: Color, epsilon: float = 0.005) -> bool:
	return absf(a.r - b.r) <= epsilon and absf(a.g - b.g) <= epsilon and absf(a.b - b.b) <= epsilon and absf(a.a - b.a) <= epsilon

func _fail(message: String) -> void:
	push_error("CARD_NUMBER_BADGE " + message)
	get_tree().quit(1)
