extends Node

func _ready() -> void:
	var original_locale := Localization.locale
	if CardDataManager.all_cards.size() != 340:
		_fail("expected 340 local card definitions, got %d" % CardDataManager.all_cards.size(), original_locale)
		return
	for source_card in CardDataManager.all_cards:
		for locale_key in ["ja", "ko"]:
			var locale_texts = source_card.localized_texts.get(locale_key, {})
			if not locale_texts is Dictionary or str(locale_texts.get("card_name", "")).strip_edges().is_empty() or str(locale_texts.get("description", "")).strip_edges().is_empty():
				_fail("card %s is missing complete %s face text" % [source_card.id, locale_key], original_locale)
				return

	Localization.set_locale("ja")
	var japanese_definitions := CardDataManager.get_cards_by_deck_id(1)
	if japanese_definitions.is_empty() or japanese_definitions[0].card_name != "目覚めの瞬間" or japanese_definitions[0].series_name != "万象カード界" or japanese_definitions[0].deck_name != "AI意識":
		_fail("Japanese static card localization is not displayed", original_locale)
		return
	Localization.set_locale("ko")
	var korean_definitions := CardDataManager.get_cards_by_deck_id(1)
	if korean_definitions.is_empty() or korean_definitions[0].card_name != "각성의 순간" or korean_definitions[0].series_name != "만상 카드계" or korean_definitions[0].deck_name != "AI 의식":
		_fail("Korean static card localization is not displayed", original_locale)
		return

	Localization.set_locale("en")
	var definitions := CardDataManager.get_cards_by_deck_id(1)
	if definitions.is_empty():
		_fail("local card definition for deck 1 is missing", original_locale)
		return
	var definition := definitions[0] as CardInfo
	if definition == null or definition.card_name_en == "" or definition.card_name_zh == "":
		_fail("test card does not contain both language variants", original_locale)
		return
	var corrected_card_11: CardInfo = null
	var corrected_card_25: CardInfo = null
	var corrected_moon_deck: CardInfo = null
	for source_card in CardDataManager.all_cards:
		if source_card.id == "11":
			corrected_card_11 = source_card
		if source_card.id == "25":
			corrected_card_25 = source_card
		if source_card.deck_name_en == "Moon":
			corrected_moon_deck = source_card
	if corrected_card_11 == null or corrected_card_11.card_name_en != "Edge of the Event Horizon" or corrected_card_25 == null or corrected_card_25.card_name_en != "Planck's Key" or corrected_moon_deck == null:
		_fail("English card override corrections are not applied", original_locale)
		return

	var pool_card := CardInfo.new(definition.to_dict())
	var hand_card := CardInfo.new(definition.to_dict())
	var vault_card := CardInfo.new(definition.to_dict())
	# 模拟服务端只返回请求时语言的卡牌；切换后必须能按稳定 card id 回填另一语言。
	var server_only_card := CardInfo.new({
		"id": definition.id,
		"deck_definition_id": definition.deck_definition_id,
		"series_name": definition.series_name_en,
		"deck_name": definition.deck_name_en,
		"card_name": definition.card_name_en,
		"description": definition.description_en,
		"card_number": definition.card_number,
		"color": CardColor.ColorType.WHITE,
		# 模拟语言已切到日语，但迟到的服务端响应仍携带英文当前字段。
		"localized_texts": {
			"ja": {
				"series_name": definition.series_name_en,
				"deck_name": definition.deck_name_en,
				"card_name": definition.card_name_en,
				"description": definition.description_en,
			},
		},
	})
	var relic := Deck.new("locale-test", definition.series_name_en, definition.deck_name_en, CardColor.ColorType.WHITE)
	# 模拟生产数据库重复 seed 后的碰撞 ID：3 在本地静态资源中属于另一套卡，
	# 但英文身份仍明确指向 AI Consciousness，不能被错误 ID 带偏。
	relic.deck_def_id = 3
	Localization.set_locale("ja")
	CardDataManager.localize_deck_in_place(relic)
	if relic.series_name != "万象カード界" or relic.deck_name != "AI意識":
		_fail("Japanese museum relic title was not localized", original_locale)
		return
	Localization.set_locale("ko")
	CardDataManager.localize_deck_in_place(relic)
	if relic.series_name != "만상 카드계" or relic.deck_name != "AI 의식":
		_fail("Korean museum relic title was not localized", original_locale)
		return
	Localization.set_locale("en")

	GameManager.player_data.pool_cards = [pool_card]
	GameManager.player_data.hand_cards = [hand_card]
	GameManager.player_data.vault_cards = [vault_card]
	CardPoolSystem.current_pool = [server_only_card]
	DeckSystem.player_decks = [relic]
	var dirty_before := GameManager.is_pool_hand_layout_dirty()

	var display := CardDisplay.new()
	display.custom_minimum_size = Vector2(214, 298)
	add_child(display)
	display.set_card(server_only_card)
	await get_tree().process_frame

	Localization.set_locale("zh-CN")
	await get_tree().process_frame
	if pool_card.card_name != definition.card_name_zh:
		_fail("pool card kept the old language", original_locale)
		return
	if hand_card.description != definition.description_zh:
		_fail("hand card kept the old language", original_locale)
		return
	if vault_card.deck_name != definition.deck_name_zh:
		_fail("vault card kept the old language", original_locale)
		return
	if server_only_card.series_name != definition.series_name_zh:
		_fail("server-only cached card was not hydrated and relocalized", original_locale)
		return
	if relic.deck_name != definition.deck_name_zh:
		_fail("museum relic title kept the old language", original_locale)
		return
	var card_name_label := display.get("_card_name_label") as Label
	var description_label := display.get("_description_label") as Label
	if card_name_label == null or card_name_label.text != definition.card_name_zh:
		_fail("visible card face did not refresh immediately", original_locale)
		return
	if description_label == null or description_label.text.find(definition.description_zh.left(8)) < 0:
		_fail("visible card description did not refresh immediately", original_locale)
		return
	if GameManager.is_pool_hand_layout_dirty() != dirty_before:
		_fail("language refresh incorrectly dirtied the asset layout", original_locale)
		return

	Localization.set_locale("en")
	await get_tree().process_frame
	if pool_card.card_name != definition.card_name_en or card_name_label.text != definition.card_name_en:
		_fail("cards did not switch back to English", original_locale)
		return
	if relic.deck_name != definition.deck_name_en:
		_fail("museum relic did not switch back to English", original_locale)
		return

	Localization.set_locale("ja")
	await get_tree().process_frame
	if card_name_label.text != "目覚めの瞬間" or description_label.text.is_empty():
		_fail("visible card face did not switch to Japanese", original_locale)
		return
	Localization.set_locale("ko")
	await get_tree().process_frame
	if card_name_label.text != "각성의 순간" or description_label.text.is_empty():
		_fail("visible card face did not switch to Korean", original_locale)
		return
	Localization.set_locale("en")
	await get_tree().process_frame

	var japanese_card := CardInfo.new({
		"id": definition.id,
		"card_name": "サーバー日本語カード",
		"localized_texts": {
			"ja": {
				"series_name": "日本語シリーズ",
				"deck_name": "日本語デッキ",
				"card_name": "サーバー日本語カード",
				"description": "日本語の説明",
			}
		},
	})
	Localization.set_locale("ja")
	CardDataManager.localize_card_in_place(japanese_card)
	if japanese_card.card_name != "サーバー日本語カード" or japanese_card.description != "日本語の説明":
		_fail("exact server locale text was overwritten by local fallback", original_locale)
		return

	Localization.set_locale(original_locale)
	print("CARD_LOCALE_REFRESH ok")
	get_tree().quit(0)

func _fail(message: String, original_locale: String) -> void:
	Localization.set_locale(original_locale)
	push_error("CARD_LOCALE_REFRESH failed: " + message)
	get_tree().quit(1)
