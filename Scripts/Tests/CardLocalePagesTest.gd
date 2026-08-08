extends Node

const TodayDecksUIScript = preload("res://Scripts/UI/TodayDecksUI.gd")
const RESEEDED_SERIES_ID := 2
const RESEEDED_DECK_ID := 3
const RESEEDED_CARD_ID_OFFSET := 10

func _ready() -> void:
	ApiClient.logout()
	DeckCollectionUI.reset_session_filter_state()
	GameManager.player_data.reset_to_defaults(false)
	GameManager.player_data.level = 1
	GameManager.player_data.pool_slots = 16
	GameManager.player_data.vault_slots = 1
	GameManager.player_data.vault_cards = []
	GameManager.vault_raw_slot_data = []

	var raw_deck := _asset_id_draw_deck()
	GameManager.apply_draw_key({
		"date_key": CardPoolSystem._beijing_date_key(),
		"version": 1,
		"decks": [raw_deck],
		"number_probabilities": {"1": 1.0},
		"color_probabilities": {"white": 1.0},
	})

	# 预热 Roll 只包含语言无关资产 ID；切换语言后必须继续复用。
	Localization.set_locale("en")
	CardPoolSystem._store_warm_roll("free", _mock_roll(raw_deck), "en")
	if CardPoolSystem._get_warm_roll("free").is_empty():
		_fail("English warm roll was not stored")
		return
	Localization.set_locale("ja")
	if CardPoolSystem._get_warm_roll("free").is_empty():
		_fail("asset-id warm roll was discarded on locale switch")
		return
	if not ApiClient.get_localized_api_url("/game/cards?type=pool").ends_with("type=pool&lang=ja"):
		_fail("localized batch URL did not append Japanese locale")
		return

	# 生产数据库重复 seed 后自增 ID 不会回到客户端静态资源的 1..N。
	# 即使 ID 已变成 11/3/2 并碰撞到另一套本地静态卡，仍必须根据
	# 系列、卡组和编号定位正式日语卡面。
	var production_slot_card := ApiClient.card_slot_to_cardinfo({
		"card_def_id": RESEEDED_CARD_ID_OFFSET + 1,
		"color": "white",
		"card_def": {
			"id": RESEEDED_CARD_ID_OFFSET + 1,
			"deck_def_id": RESEEDED_DECK_ID,
			"series_id": RESEEDED_SERIES_ID,
			"series_asset_id": 1,
			"deck_asset_id": 1,
			"card_asset_id": 1,
			"number": 1,
		},
	})
	if production_slot_card == null or production_slot_card.card_name != "目覚めの瞬間":
		_fail("reseeded production card IDs did not resolve Japanese text")
		return

	var today := TodayDecksUIScript.new()
	today.size = Vector2(1920, 1200)
	today.configure_layout(40.0)
	add_child(today)
	await get_tree().process_frame
	await get_tree().process_frame
	var first_row := today.find_child("TodayDeckRow1", true, false) as Control
	var title := first_row.find_child("DeckNameLabel", true, false) as Label if first_row != null else null
	if title == null or title.text != "万象カード界-AI意識":
		_fail("today deck title did not use Japanese card metadata")
		return
	var today_card := first_row.find_child("Card1", true, false) as CardDisplay if first_row != null else null
	if today_card == null or today_card.card == null or today_card.card.card_name != "目覚めの瞬間":
		_fail("today deck card did not use Japanese card text")
		return

	DeckSystem.player_decks.clear()
	DeckSystem.add_synthesized_deck({
		"id": "locale-pages-relic",
		"color": "white",
		"deck_def": {
			"id": RESEEDED_DECK_ID,
			"asset_id": 1,
		},
		"series": {"id": RESEEDED_SERIES_ID, "asset_id": 1},
	})
	var museum := DeckCollectionUI.new()
	museum.size = Vector2(2168, 1416)
	add_child(museum)
	# 本测试的生产形态 draw key 故意不带 deck_def_key，博物馆部分改为全部系列，
	# 避免“今日可见”筛选干扰这里对日语圣物标题的独立断言。
	museum._selected_series = ""
	museum.render_decks()
	await get_tree().process_frame
	await get_tree().process_frame
	var series_option := museum.find_child("MuseumSeriesOption", true, false) as OptionButton
	if series_option == null or not _option_contains(series_option, "万象カード界"):
		_fail("museum series dropdown did not use Japanese text")
		return
	var relic_card := museum.find_child("RelicCard0", true, false) as Control
	var relic_name := relic_card.find_child("RelicCardName", true, false) as Label if relic_card != null else null
	if relic_name == null or relic_name.text != "AI意識":
		_fail("museum relic title did not use Japanese text")
		return

	# 旧回归只覆盖日语、一个系列，而且在测试中手动执行本地化，掩盖了正式
	# DeckSystem 载入链路没有规范化服务端英文快照的问题。这里使用生产形状的
	# 偏移 ID，一次核对韩语博物馆下拉框中的全部七个系列。
	museum.queue_free()
	await get_tree().process_frame
	Localization.set_locale("ko")
	DeckSystem.player_decks.clear()
	_add_production_shaped_museum_relics()
	var korean_museum := DeckCollectionUI.new()
	korean_museum.size = Vector2(2168, 1416)
	add_child(korean_museum)
	korean_museum._selected_series = ""
	korean_museum.render_decks()
	await get_tree().process_frame
	await get_tree().process_frame
	var korean_series_option := korean_museum.find_child("MuseumSeriesOption", true, false) as OptionButton
	var expected_korean_series: Array[String] = ["만상 카드계", "태양계", "지구", "음양", "오행", "국가", "도시"]
	var unexpected_english_series: Array[String] = ["Cosmic Card Realm", "Solar System", "Earth", "Yin Yang", "Five Elements", "Nations", "Cities"]
	if korean_series_option == null or korean_series_option.get_item_count() != expected_korean_series.size() + 2:
		_fail("Korean museum series dropdown did not contain all seven series")
		return
	for expected_series in expected_korean_series:
		if not _option_contains(korean_series_option, expected_series):
			_fail("Korean museum series dropdown is missing: " + expected_series)
			return
	for english_series in unexpected_english_series:
		if _option_contains(korean_series_option, english_series):
			_fail("Korean museum series dropdown kept English text: " + english_series)
			return
	korean_museum.queue_free()
	await get_tree().process_frame
	Localization.set_locale("ja")

	var vault_card := CardInfo.new({
		"id": str(RESEEDED_CARD_ID_OFFSET + 1),
		"card_asset_id": 1,
		"deck_asset_id": 1,
		"series_asset_id": 1,
		"deck_definition_id": RESEEDED_DECK_ID,
		"series_definition_id": RESEEDED_SERIES_ID,
		"card_number": 1,
		"color": CardColor.ColorType.WHITE,
	})
	GameManager.player_data.vault_cards = [vault_card]
	var vault := VaultUI.new()
	vault.size = Vector2(1920, 1200)
	add_child(vault)
	await get_tree().process_frame
	await get_tree().process_frame
	var vault_display: CardDisplay = null
	for candidate in vault.find_children("*", "CardDisplay", true, false):
		var display := candidate as CardDisplay
		if display != null and display.card != null:
			vault_display = display
			break
	if vault_display == null or vault_display.card.card_name != "目覚めの瞬間":
		_fail("vault card did not use Japanese text")
		return

	Localization.set_locale("en")
	print("CARD_LOCALE_PAGES ok asset_ids_only=true today=vault=ja museum=ja+ko_all_series warm_roll_reused=true")
	get_tree().quit(0)

func _add_production_shaped_museum_relics() -> void:
	var definitions: Array[Dictionary] = [
		{"local_deck_id": 1, "series_asset_id": 1},
		{"local_deck_id": 21, "series_asset_id": 2},
		{"local_deck_id": 36, "series_asset_id": 3},
		{"local_deck_id": 47, "series_asset_id": 4},
		{"local_deck_id": 49, "series_asset_id": 5},
		{"local_deck_id": 54, "series_asset_id": 6},
		{"local_deck_id": 59, "series_asset_id": 7},
	]
	for index in range(definitions.size()):
		var definition := definitions[index]
		DeckSystem.add_synthesized_deck({
			"id": "locale-pages-korean-relic-%d" % index,
			"color": "white",
			"deck_def": {
				"id": int(definition["local_deck_id"]) + 2,
				"asset_id": 1,
			},
			"series": {
				"id": int(definition["series_asset_id"]) + 1,
				"asset_id": int(definition["series_asset_id"]),
			},
		})

func _asset_id_draw_deck() -> Dictionary:
	var source_cards: Array[CardInfo] = CardDataManager.get_cards_by_deck_id(1)
	var cards: Array = []
	for source in source_cards:
		cards.append({
			"card_def_id": RESEEDED_CARD_ID_OFFSET + int(source.id),
			"card_asset_id": source.card_number,
			"number": source.card_number,
		})
	return {
		"deck_def_id": RESEEDED_DECK_ID,
		"deck_asset_id": 1,
		"series_id": RESEEDED_SERIES_ID,
		"series_asset_id": 1,
		"cards": cards,
	}

func _mock_roll(deck: Dictionary) -> Dictionary:
	var matrix: Array = []
	for _i in range(16):
		matrix.append([0.1, 0.1, 0.1])
	var key := {
		"date_key": CardPoolSystem._beijing_date_key(),
		"version": 1,
		"decks": [deck],
		"number_probabilities": {"1": 1.0},
		"color_probabilities": {"white": 1.0},
	}
	return {
		"roll_id": "locale-pages-roll",
		"signature": "locale-pages-signature",
		"random_matrix": matrix,
		"draw_key": key,
	}

func _option_contains(option: OptionButton, expected: String) -> bool:
	for index in range(option.get_item_count()):
		if option.get_item_text(index) == expected:
			return true
	return false

func _fail(message: String) -> void:
	push_error("CARD_LOCALE_PAGES failed: " + message)
	get_tree().quit(1)
