extends Node

const TARGET_SCROLL: int = 180

func _ready() -> void:
	Localization.set_locale("zh-CN")
	ApiClient.logout()
	DeckCollectionUI.reset_session_filter_state()
	_setup_today_decks()
	_setup_vault()
	_setup_museum()

	var main := MainUI.new()
	add_child(main)
	await get_tree().process_frame
	main.call("_set_game_ui_visible", true)

	var nav_buttons: NavButtons = main.get("_nav_buttons")
	if nav_buttons == null:
		return _fail("nav_buttons_missing")

	if not await _assert_page_scroll_memory(nav_buttons, main, "today_decks", "TodayDeckScroll"):
		return
	if not await _assert_page_scroll_memory(nav_buttons, main, "vault", "VaultSlotViewport"):
		return
	if not await _prepare_museum_all_series(main, nav_buttons):
		return
	if not await _assert_page_scroll_memory(nav_buttons, main, "deck_panel", "DeckCollectionScroll"):
		return

	print("NAVIGATION_SCROLL_MEMORY ok")
	get_tree().quit(0)

func _assert_page_scroll_memory(nav_buttons: NavButtons, main: MainUI, view_id: String, scroll_name: String) -> bool:
	nav_buttons.nav_button_clicked.emit(view_id)
	await _wait_frames(3)
	var center_area: Control = main.get("_center_area")
	var scroll := center_area.find_child(scroll_name, true, false) as ScrollContainer
	if scroll == null:
		return _fail(scroll_name + "_missing")
	var linked_scrollbar_name := "TodayDeckVerticalScrollbar" if view_id == "today_decks" else ("VaultVerticalScrollbar" if view_id == "vault" else ("MuseumVerticalScrollbar" if view_id == "deck_panel" else ""))
	if linked_scrollbar_name != "":
		var linked_scrollbar := center_area.find_child(linked_scrollbar_name, true, false) as VScrollBar
		if linked_scrollbar == null:
			return _fail(linked_scrollbar_name + "_missing")
		linked_scrollbar.value = minf(float(TARGET_SCROLL), maxf(linked_scrollbar.min_value, linked_scrollbar.max_value - linked_scrollbar.page))
		await _wait_frames(2)
		if scroll.scroll_vertical <= 0:
			return _fail(view_id + "_linked_scrollbar_did_not_scroll_content")
	scroll.scroll_vertical = TARGET_SCROLL
	await _wait_frames(2)
	var saved_value := scroll.scroll_vertical
	if saved_value <= 0:
		return _fail(view_id + "_not_scrollable")
	nav_buttons.nav_button_clicked.emit("card_pool")
	await _wait_frames(2)
	nav_buttons.nav_button_clicked.emit(view_id)
	await _wait_frames(4)
	scroll = center_area.find_child(scroll_name, true, false) as ScrollContainer
	if scroll == null:
		return _fail(scroll_name + "_missing_after_restore")
	if abs(scroll.scroll_vertical - saved_value) > 1:
		return _fail("%s_scroll_not_restored_%d_%d" % [view_id, saved_value, scroll.scroll_vertical])
	return true

func _prepare_museum_all_series(main: MainUI, nav_buttons: NavButtons) -> bool:
	nav_buttons.nav_button_clicked.emit("deck_panel")
	await _wait_frames(3)
	var museum := main.get("_deck_collection_ui") as DeckCollectionUI
	if museum == null:
		return _fail("museum_missing")
	var series_option := museum.find_child("MuseumSeriesOption", true, false) as OptionButton
	if series_option == null:
		return _fail("museum_series_option_missing")
	series_option.select(0)
	museum._on_series_selected(0)
	await _wait_frames(2)
	return true

func _setup_today_decks() -> void:
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
			"relic_caps": {},
			"cards": cards,
		})
	GameManager.apply_draw_key({
		"date_key": "2026-07-24",
		"version": 1,
		"decks": decks,
	})

func _setup_vault() -> void:
	GameManager.player_data.gold = 1000
	GameManager.player_data.gems = 1000
	GameManager.player_data.vault_slots = 80
	GameManager.vault_slot_quote = {
		"next_slot_index": 80,
		"costs": {"gold": 20, "gem": 10},
	}
	GameManager.vault_raw_slot_data = []
	GameManager.player_data.vault_cards = []
	for index in range(80):
		GameManager.vault_raw_slot_data.append({"slot_index": index, "unlocked": true})
		GameManager.player_data.vault_cards.append(_make_card(index + 1))

func _setup_museum() -> void:
	DeckSystem.player_decks.clear()
	var deck_defs := _deck_defs()
	for i in range(deck_defs.size()):
		var deck_def: Dictionary = deck_defs[i]
		DeckSystem.add_synthesized_deck({
			"id": "navigation-scroll-memory-%d" % i,
			"color": "white",
			"deck_def": {
				"id": int(deck_def.get("id", 0)),
				"name": str(deck_def.get("key", "")),
				"description": str(deck_def.get("deck_name", "")),
			},
			"series": {
				"id": 1,
				"name": str(deck_def.get("series_name", "")),
			},
		})

func _deck_defs() -> Array[Dictionary]:
	var defs: Array[Dictionary] = []
	for series in CardDataManager.get_all_series():
		if not series is CardSeries:
			continue
		var typed_series := series as CardSeries
		var deck_names := typed_series.get_deck_names()
		for i in range(deck_names.size()):
			defs.append({
				"id": defs.size() + 1,
				"key": "%s__%d" % [typed_series.series_name, i],
				"series_name": typed_series.series_name,
				"deck_name": str(deck_names[i]),
			})
			if defs.size() >= 40:
				return defs
	return defs

func _make_card(index: int) -> CardInfo:
	return CardInfo.new({
		"id": "nav-scroll-card-%d" % index,
		"series_name": "测试系列",
		"deck_name": "保险箱滚动记忆",
		"card_number": index % 5 + 1,
		"color": "white",
		"card_name": "测试卡%d" % index,
		"description": "滚动记忆测试卡。",
	})

func _wait_frames(count: int) -> void:
	for _i in range(count):
		await get_tree().process_frame

func _fail(reason: String) -> bool:
	push_error("NAVIGATION_SCROLL_MEMORY " + reason)
	get_tree().quit(1)
	return false
