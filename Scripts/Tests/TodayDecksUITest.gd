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
	if buttons.is_empty() or buttons[0].text != "今日卡组" or buttons[buttons.size() - 1].text != "设置":
		_fail("navigation order is wrong")
		return

	nav_buttons.nav_button_clicked.emit("today_decks")
	await get_tree().process_frame
	await get_tree().process_frame

	var center_area: Control = main.get("_center_area")
	var rows := center_area.find_children("TodayDeckRow*", "HBoxContainer", true, false)
	if rows.size() != 8:
		_fail("today decks row count is not 8")
		return

	var expected_size: Vector2 = CardSlotUI.SLOT_SIZE
	for row_index in range(rows.size()):
		var row = rows[row_index]
		var type_label := row.find_child("DeckTypeLabel", true, false) as Label
		var name_label := row.find_child("DeckNameLabel", true, false) as Label
		var level_label := row.find_child("DeckVisibleLevelLabel", true, false) as Label
		if type_label == null or name_label == null or level_label == null:
			_fail("today deck info labels are missing")
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
		if absf(first_card.custom_minimum_size.x - expected_size.x) > 0.1 or absf(first_card.custom_minimum_size.y - expected_size.y) > 0.1:
			_fail("today deck card size is not same as draw card size")
			return
		if first_card.mouse_filter != Control.MOUSE_FILTER_STOP or first_card.hover_uses_slot_bounds:
			_fail("today deck card hover preview is not enabled")
			return

	var first_row_cards := (rows[0].find_child("TodayDeckCards", true, false) as HBoxContainer).find_children("Card*", "CardDisplay", false, false)
	var expected_colors := [
		CardColor.ColorType.WHITE,
		CardColor.ColorType.WHITE,
		CardColor.ColorType.GREEN,
		CardColor.ColorType.BLUE,
		CardColor.ColorType.ORANGE,
	]
	for i in range(expected_colors.size()):
		var card_display := first_row_cards[i] as CardDisplay
		if card_display.card == null or int(card_display.card.color) != int(expected_colors[i]):
			_fail("sold out color shift is wrong at card " + str(i + 1))
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
			"relic_caps": {
				"purple": {"exhausted": deck_index == 0, "current": 900 if deck_index == 0 else 0, "max": 900},
			},
			"cards": cards,
		})
	return {
		"date_key": "2026-06-27",
		"version": 1,
		"decks": decks,
	}

func _fail(message: String) -> void:
	push_error("TODAY_DECKS_UI " + message)
	get_tree().quit(1)
