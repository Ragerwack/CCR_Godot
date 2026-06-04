class_name CardSeries
extends RefCounted

var type: String  # "基本卡组" or "限时卡组"
var series_name: String
var series_style: String
var decks: Dictionary  # deck_name -> {cards: []}

func _init(data: Dictionary = {}):
	type = data.get("type", "")
	series_name = data.get("series_name", "")
	series_style = data.get("series_style", "")
	decks = {}

func get_deck_names() -> Array:
	return decks.keys()

func get_deck(deck_name: String) -> Dictionary:
	return decks.get(deck_name, {})

func add_card(card: CardInfo) -> void:
	if not decks.has(card.deck_name):
		decks[card.deck_name] = {"cards": []}
	decks[card.deck_name]["cards"].append(card)

func get_deck_cards(deck_name: String) -> Array[CardInfo]:
	var deck = decks.get(deck_name, {})
	var cards: Array[CardInfo] = []
	if deck.has("cards"):
		for c in deck["cards"]:
			if c is CardInfo:
				cards.append(c)
	return cards

func get_total_cards() -> int:
	var total = 0
	for deck_name in decks.keys():
		var deck = decks[deck_name]
		if deck.has("cards"):
			total += deck["cards"].size()
	return total
