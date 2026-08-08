extends Node

func _ready() -> void:
	ApiClient.logout()
	Localization.set_locale("zh-CN")
	GameManager.apply_draw_key(_mock_draw_key())

	var main := MainUI.new()
	add_child(main)
	await get_tree().process_frame

	main.call("_set_game_ui_visible", true)
	if main.get("_current_view_id") != "card_pool":
		_fail("login default view is not card_pool")
		return
	if main.get("_menu_button") != null:
		_fail("top-right settings button still exists")
		return

	var nav_buttons: NavButtons = main.get("_nav_buttons")
	var buttons: Array = nav_buttons.get("buttons")
	if buttons.size() < 2 or buttons[0].text != "今日卡组" or buttons[buttons.size() - 2].text != "设置" or buttons[buttons.size() - 1].text != "退出游戏":
		_fail("navigation order is wrong")
		return

	nav_buttons.nav_button_clicked.emit("today_decks")
	await get_tree().process_frame
	await get_tree().process_frame

	var center_area: Control = main.get("_center_area")
	if _has_label_text(center_area, "今日卡组"):
		_fail("today decks title is still visible")
		return
	var date_label := center_area.find_child("TodayDeckDateLabel", true, false) as Label
	var countdown_label := center_area.find_child("TodayDeckResetCountdown", true, false) as Label
	if date_label != null:
		_fail("today decks date label should be removed")
		return
	if countdown_label == null or countdown_label.text.find("密匙重置倒计时：") != 0:
		_fail("today decks reset countdown is missing")
		return
	var key_row := center_area.find_child("TodayDeckKeyRow", true, false) as Control
	if key_row == null or absf(countdown_label.global_position.x - key_row.global_position.x) > 0.1:
		_fail("today decks countdown is not in former date position")
		return
	if countdown_label.get_theme_font_size("font_size") != 16:
		_fail("today decks countdown font not increased")
		return
	if not _color_close(countdown_label.get_theme_color("font_color"), Color.BLACK):
		_fail("today decks countdown text is not black")
		return
	var rows := center_area.find_children("TodayDeckRow*", "VBoxContainer", true, false)
	if rows.size() != 8:
		_fail("today decks row count is not 8")
		return

	var expected_size: Vector2 = CardSlotUI.SLOT_SIZE
	var content_host := center_area.find_child("TodayDecksContentRegion", true, false) as Control
	var expected_left_shift := float(main.call("_exp_bar_height", get_viewport().get_visible_rect().size))
	var latest_scrollbar := center_area.find_child("TodayDeckVerticalScrollbar", true, false) as VScrollBar
	if latest_scrollbar == null or not latest_scrollbar.visible:
		_fail("today deck latest vertical scrollbar is missing")
		return
	if latest_scrollbar.size.y <= 438.0:
		_fail("today deck vertical scrollbar middle section was not extended")
		return
	var latest_track := latest_scrollbar.find_child("CCRVerticalScrollbarTrack", false, false) as NinePatchRect
	if latest_track == null or latest_track.patch_margin_top != latest_track.patch_margin_bottom or latest_track.patch_margin_top != 78:
		_fail("today deck vertical scrollbar end caps are not protected")
		return
	var scroll := center_area.find_child("TodayDeckScroll", true, false) as ScrollContainer
	if scroll == null:
		_fail("today deck scroll container is missing")
		return
	for row_index in range(rows.size()):
		var row = rows[row_index]
		var type_label := row.find_child("DeckTypeLabel", true, false) as Label
		var name_label := row.find_child("DeckNameLabel", true, false) as Label
		var level_label := row.find_child("DeckVisibleLevelLabel", true, false) as Label
		if type_label == null or name_label == null or level_label == null:
			_fail("today deck info labels are missing")
			return
		if type_label.get_theme_font_size("font_size") != 15 or name_label.get_theme_font_size("font_size") != 15 or level_label.get_theme_font_size("font_size") != 15:
			_fail("today deck info font not increased")
			return
		if not _color_close(type_label.get_theme_color("font_color"), Color.BLACK) or not _color_close(name_label.get_theme_color("font_color"), Color.BLACK) or not _color_close(level_label.get_theme_color("font_color"), Color.BLACK):
			_fail("today deck info text is not black")
			return
		if row_index == 0 and type_label.text != "今日新卡组":
			_fail("today deck type label is wrong")
			return
		if row_index == 3 and type_label.text != "随机卡组":
			_fail("random deck type label is wrong")
			return
		if row_index == 0 and name_label.text != "测试系列-测试卡组1":
			_fail("series-deck label is wrong")
			return
		if row_index == 0 and level_label.text != "可见等级：1级":
			_fail("visible level label is wrong")
			return
		var card_boxes := row.find_children("TodayDeckCards", "HBoxContainer", true, false)
		if card_boxes.size() != 1:
			_fail("today deck row missing card box")
			return
		var cards := card_boxes[0].find_children("Card*", "CardDisplay", false, false)
		if cards.size() != 5:
			_fail("today deck row does not contain 5 cards")
			return
		var first_card: CardDisplay = cards[0]
		if content_host == null or absf(first_card.global_position.x - content_host.global_position.x - expected_left_shift) > 0.1:
			_fail("today deck cards are not shifted right by experience bar height")
			return
		if row_index == 0:
			var cards_right := (card_boxes[0] as Control).get_global_rect().end.x
			if absf(latest_scrollbar.global_position.x - cards_right - expected_left_shift) > 0.1:
				_fail("today deck vertical scrollbar gap is not experience bar height")
				return
		var card_shadow := first_card.find_child("CardShadow", false, false) as Panel
		var shadow_style := card_shadow.get_theme_stylebox("panel") as StyleBoxFlat if card_shadow != null else null
		if scroll == null or shadow_style == null:
			_fail("today deck first-card shadow setup is missing")
			return
		var left_shadow_bleed := maxf(0.0, float(shadow_style.shadow_size) - shadow_style.shadow_offset.x)
		if first_card.global_position.x - scroll.get_global_rect().position.x < left_shadow_bleed - 0.1:
			_fail("today deck first-card left shadow is clipped")
			return
		if absf(first_card.custom_minimum_size.x - expected_size.x) > 0.1 or absf(first_card.custom_minimum_size.y - expected_size.y) > 0.1:
			_fail("today deck card size is not same as draw card size")
			return
		if first_card.mouse_filter != Control.MOUSE_FILTER_STOP or first_card.hover_uses_slot_bounds or first_card.hover_scale_enabled:
			_fail("today deck card hover preview is not enabled")
			return

	var first_row_cards_for_bounds := (rows[0].find_child("TodayDeckCards", true, false) as HBoxContainer).find_children("Card*", "CardDisplay", false, false)
	var first_bound_card := first_row_cards_for_bounds[0] as CardDisplay
	if absf(latest_scrollbar.global_position.y - first_bound_card.global_position.y) > 0.1:
		_fail("today deck scrollbar top does not align with first card top")
		return
	var last_row_cards_for_bounds := (rows[rows.size() - 1].find_child("TodayDeckCards", true, false) as HBoxContainer).find_children("Card*", "CardDisplay", false, false)
	var last_bound_card := last_row_cards_for_bounds[0] as CardDisplay
	var last_shadow := last_bound_card.find_child("CardShadow", false, false) as Panel
	var last_shadow_style := last_shadow.get_theme_stylebox("panel") as StyleBoxFlat if last_shadow != null else null
	if last_shadow_style == null:
		_fail("today deck last-card shadow setup is missing")
		return
	scroll.scroll_vertical = int(ceil(scroll.get_v_scroll_bar().max_value))
	await get_tree().process_frame
	await get_tree().process_frame
	var bottom_shadow_bleed := float(last_shadow_style.shadow_size) + maxf(0.0, last_shadow_style.shadow_offset.y)
	var last_card_bottom := last_bound_card.get_global_rect().end.y
	if last_card_bottom + bottom_shadow_bleed > scroll.get_global_rect().end.y + 0.1:
		_fail("today deck last-row bottom shadow is clipped")
		return
	if absf(latest_scrollbar.get_global_rect().end.y - last_card_bottom) > 0.1:
		_fail("today deck scrollbar bottom does not align with fully shown last card bottom")
		return
	scroll.scroll_vertical = 0
	await get_tree().process_frame

	var first_row_cards := (rows[0].find_child("TodayDeckCards", true, false) as HBoxContainer).find_children("Card*", "CardDisplay", false, false)
	var today_ui := _find_today_decks_ui(center_area)
	if today_ui == null:
		_fail("today decks ui missing")
		return
	var hover_card := first_row_cards[0] as CardDisplay
	today_ui._on_card_hover_changed(hover_card, true)
	await get_tree().process_frame
	if today_ui._hover_preview == null:
		_fail("today deck hover preview missing")
		return
	var cards_box := hover_card.get_parent() as Control
	var blank_left := cards_box.global_position.x + cards_box.size.x + 18.0
	if today_ui._hover_preview.global_position.x + today_ui._hover_preview.size.x * 0.5 <= blank_left:
		_fail("today deck hover preview is not centered in right blank area")
		return
	today_ui._on_card_hover_changed(hover_card, false)
	if today_ui._hover_preview != null:
		_fail("today deck hover preview not hidden")
		return

	var expected_colors := [
		CardColor.ColorType.WHITE,
		CardColor.ColorType.GREEN,
		CardColor.ColorType.BLUE,
		CardColor.ColorType.ORANGE,
		CardColor.ColorType.BLACK,
	]
	for i in range(expected_colors.size()):
		var card_display := first_row_cards[i] as CardDisplay
		if card_display.card == null or int(card_display.card.color) != int(expected_colors[i]):
			_fail("sold out color shift is wrong at card " + str(i + 1))
			return
		if not _card_title_color_matches(card_display, _expected_card_title_color(expected_colors[i])):
			_fail("today deck card title color does not match rarity at card " + str(i + 1))
			return

	var second_row_cards := (rows[1].find_child("TodayDeckCards", true, false) as HBoxContainer).find_children("Card*", "CardDisplay", false, false)
	var expected_two_sold_out := [
		CardColor.ColorType.WHITE,
		CardColor.ColorType.WHITE,
		CardColor.ColorType.GREEN,
		CardColor.ColorType.BLUE,
		CardColor.ColorType.BLACK,
	]
	for i in range(expected_two_sold_out.size()):
		var card_display := second_row_cards[i] as CardDisplay
		if card_display.card == null or int(card_display.card.color) != int(expected_two_sold_out[i]):
			_fail("two sold out colors shift is wrong at card " + str(i + 1))
			return

	var third_row_cards := (rows[2].find_child("TodayDeckCards", true, false) as HBoxContainer).find_children("Card*", "CardDisplay", false, false)
	for i in range(third_row_cards.size()):
		var card_display := third_row_cards[i] as CardDisplay
		if card_display.card == null or int(card_display.card.color) != int(CardColor.ColorType.WHITE):
			_fail("all advanced colors sold out should display white at card " + str(i + 1))
			return

	print("TODAY_DECKS_UI ok")
	get_tree().quit(0)

func _mock_draw_key() -> Dictionary:
	var decks: Array = []
	for deck_index in range(8):
		var cards: Array = []
		for number in range(1, 6):
			var card_id := deck_index * 5 + number
			cards.append({
				"card_def_id": card_id,
				"number": number,
				"name": "子卡%d" % number,
				"description": "测试描述",
				"image_url": "/images/cards/card_%03d.jpg" % card_id,
			})
		decks.append({
			"deck_def_id": deck_index + 1,
			"deck_def_key": "mock__deck_%d" % deck_index,
			"series_name": "测试系列",
			"deck_name": "测试卡组%d" % (deck_index + 1),
			"relic_caps": _mock_relic_caps(deck_index),
			"cards": cards,
		})
	return {
		"date_key": "2026-06-27",
		"version": 1,
		"decks": decks,
	}

func _mock_relic_caps(deck_index: int) -> Dictionary:
	match deck_index:
		0:
			return {
				"purple": {"exhausted": true, "current": 900, "max": 900},
			}
		1:
			return {
				"purple": {"exhausted": true, "current": 900, "max": 900},
				"orange": {"exhausted": true, "current": 30, "max": 30},
			}
		2:
			return {
				"green": {"exhausted": true, "current": 1000000, "max": 1000000},
				"blue": {"exhausted": true, "current": 30000, "max": 30000},
				"purple": {"exhausted": true, "current": 900, "max": 900},
				"orange": {"exhausted": true, "current": 30, "max": 30},
				"black": {"exhausted": true, "current": 1, "max": 1},
			}
		_:
			return {}

func _find_today_decks_ui(root: Node) -> Node:
	for child in root.get_children():
		if child.get_script() == load("res://Scripts/UI/TodayDecksUI.gd"):
			return child
		var found := _find_today_decks_ui(child)
		if found != null:
			return found
	return null

func _has_label_text(root: Node, text: String) -> bool:
	for child in root.find_children("*", "Label", true, false):
		var label := child as Label
		if label != null and label.text == text:
			return true
	return false

func _fail(message: String) -> void:
	push_error("TODAY_DECKS_UI " + message)
	get_tree().quit(1)

func _color_close(actual: Color, expected: Color) -> bool:
	return is_equal_approx(actual.r, expected.r) and is_equal_approx(actual.g, expected.g) and is_equal_approx(actual.b, expected.b) and is_equal_approx(actual.a, expected.a)

func _card_title_color_matches(card_display: CardDisplay, expected: Color) -> bool:
	for label_name in ["_deck_name_label", "_card_name_label", "_series_tag_label"]:
		var title_label := card_display.get(label_name) as Label
		if title_label == null or not _color_close(title_label.get_theme_color("font_color"), expected):
			return false
	return true

func _expected_card_title_color(color_type: CardColor.ColorType) -> Color:
	match color_type:
		CardColor.ColorType.GREEN:
			return CardDisplay.CARD_TEXT_COLOR_GREEN
		CardColor.ColorType.BLUE:
			return CardDisplay.CARD_TEXT_COLOR_BLUE
		CardColor.ColorType.PURPLE:
			return CardDisplay.CARD_TEXT_COLOR_PURPLE
		CardColor.ColorType.ORANGE:
			return CardDisplay.CARD_TEXT_COLOR_ORANGE
		CardColor.ColorType.BLACK:
			return CardDisplay.CARD_TEXT_COLOR_BLACK
		CardColor.ColorType.RED:
			return CardDisplay.CARD_TEXT_COLOR_RED
		_:
			return CardDisplay.CARD_TEXT_COLOR
