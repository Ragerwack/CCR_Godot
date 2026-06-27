extends Node

const ALL_RELIC_COLORS := [
	CardColor.ColorType.WHITE,
	CardColor.ColorType.GREEN,
	CardColor.ColorType.BLUE,
	CardColor.ColorType.PURPLE,
	CardColor.ColorType.ORANGE,
	CardColor.ColorType.BLACK,
	CardColor.ColorType.RED,
]
const ALL_RELIC_NAMES := ["white", "green", "blue", "purple", "orange", "black", "red"]
const THUMBNAIL_CACHE = preload("res://Scripts/UI/MuseumRelicThumbnailCache.gd")


func _ready() -> void:
	var cards_by_id: Array[CardInfo] = CardDataManager.get_cards_by_deck_id(1)
	if cards_by_id.size() != 5 or int(cards_by_id[0].id) != 1:
		return _fail("deck_id_lookup_wrong")
	for deck_def_id in range(1, 69):
		var deck_cards: Array[CardInfo] = CardDataManager.get_cards_by_deck_id(deck_def_id)
		var expected_first_card_id := (deck_def_id - 1) * 5 + 1
		if deck_cards.size() != 5 or int(deck_cards[0].id) != expected_first_card_id:
			return _fail("all_deck_id_lookup_wrong_%d" % deck_def_id)
	var solar_cards: Array[CardInfo] = CardDataManager.get_cards_by_deck_id(21)
	if solar_cards.size() != 5 or int(solar_cards[0].id) != 101:
		return _fail("global_deck_id_lookup_wrong")
	var cards_by_key: Array[CardInfo] = CardDataManager.get_cards_by_deck_key("solar_system__sun")
	if cards_by_key.size() != 5 or int(cards_by_key[0].id) != 101:
		return _fail("deck_key_lookup_wrong")
	var cards_by_name: Array[CardInfo] = CardDataManager.get_cards_by_deck("万象卡域", "AI意识")
	if cards_by_name.size() != 5:
		return _fail("deck_name_lookup_wrong")

	DeckSystem.player_decks.clear()
	for color_type in ALL_RELIC_COLORS:
		DeckSystem.add_synthesized_deck({
			"id": "museum-relic-test-%d" % color_type,
			"color": ALL_RELIC_NAMES[color_type],
			"deck_def": {
				"id": 21,
				"name": "solar_system__sun",
				"description": "Sun",
			},
			"series": {
				"id": 2,
				"name": "Solar System",
			},
		})
		var added_deck := DeckSystem.player_decks.back() as Deck
		if added_deck.deck_def_key != "solar_system__sun":
			return _fail("server_deck_key_missing_%d" % color_type)

	var museum := DeckCollectionUI.new()
	add_child(museum)
	await get_tree().process_frame
	await get_tree().process_frame

	var expected_height := get_viewport().get_visible_rect().size.y * 3.0 / 5.0
	for color_type in ALL_RELIC_COLORS:
		var relic_card := museum.find_child("RelicCard%d" % color_type, true, false) as Control
		if relic_card == null:
			return _fail("relic_card_missing_%d" % color_type)
		var label_box := relic_card.find_child("RelicCardLabels", true, false) as VBoxContainer
		if label_box == null:
			return _fail("relic_labels_missing_%d" % color_type)
		var series_label := relic_card.find_child("RelicCardSeries", true, false) as Label
		var name_label := relic_card.find_child("RelicCardName", true, false) as Label
		var count_label := relic_card.find_child("RelicCardCount", true, false) as Label
		if series_label == null or series_label.text != "Solar System":
			return _fail("relic_series_label_wrong_%d" % color_type)
		if name_label == null or name_label.text != "Sun":
			return _fail("relic_name_label_wrong_%d" % color_type)
		if count_label == null or count_label.text == "":
			return _fail("relic_count_label_missing_%d" % color_type)
		var relic_host := relic_card.find_child("RelicHost", true, false) as Control
		if relic_host == null:
			return _fail("relic_host_missing_%d" % color_type)
		if absf(relic_host.custom_minimum_size.y - expected_height) > 1.0:
			return _fail("relic_height_wrong_%d" % color_type)
		var thumbnail := relic_card.find_child("RelicThumbnail", true, false) as TextureRect
		if thumbnail == null or thumbnail.texture == null:
			return _fail("relic_thumbnail_missing_%d" % color_type)
		var cache_path: String = THUMBNAIL_CACHE.get_cache_path(color_type, "solar_system__sun", 21)
		if not FileAccess.file_exists(cache_path):
			return _fail("relic_thumbnail_cache_missing_%d" % color_type)
		var fallback_relic_view := relic_card.find_child("RelicView", true, false) as RelicView
		if fallback_relic_view != null:
			return _fail("relic_thumbnail_fallback_used_%d" % color_type)

	print("MUSEUM_RELIC ok colors=7 height=", roundi(expected_height), " thumbnails=true")
	get_tree().quit(0)


func _fail(reason: String) -> void:
	push_error("MUSEUM_RELIC " + reason)
	get_tree().quit(1)
