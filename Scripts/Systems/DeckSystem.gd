extends Node

# CCR 数据层
const _CCRData = preload("res://Scripts/Data/CCRData.gd")

signal deck_updated(deck: Deck)
signal synthesis_ready(deck: Deck, cards: Array[CardInfo])
signal synthesis_completed(exp_reward: int)

var player_decks: Array[Deck] = []

func check_synthesis_cards(cards: Array[CardInfo]) -> bool:
	if cards.size() != 5:
		return false
	var series = cards[0].series_name
	var deck = cards[0].deck_name
	var color = cards[0].color
	var numbers: Array[int] = []
	for c in cards:
		if c.series_name != series or c.deck_name != deck or c.color != color:
			return false
		numbers.append(c.card_number)
	numbers.sort()
	return numbers == [1, 2, 3, 4, 5]

func find_synthesizable_decks(cards: Array[CardInfo], location: String) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var groups: Dictionary = {}
	for c in cards:
		var key = "%s|%s|%d" % [c.series_name, c.deck_name, c.color]
		if not groups.has(key):
			groups[key] = []
		groups[key].append(c)
	for key in groups:
		var group = groups[key]
		if group.size() >= 5:
			var numbers: Array[int] = []
			for g in group:
				numbers.append(g.card_number)
			numbers.sort()
			if numbers == [1, 2, 3, 4, 5]:
				results.append({
					"cards": group,
					"series_name": group[0].series_name,
					"deck_name": group[0].deck_name,
					"color": group[0].color,
				})
	return results

func synthesize(cards: Array[CardInfo]) -> bool:
	if not check_synthesis_cards(cards):
		return false
	var card = cards[0]
	var exp_reward = CardColor.get_exp(card.color) * 5
	var deck = _CCRData.Deck.new(
		"%s_%s_%d" % [card.series_name, card.deck_name, card.color],
		card.series_name, card.deck_name, card.color
	)
	for i in range(1, 6):
		deck.add_card_number(i)
	player_decks.append(deck)
	GameManager.on_exp_gained(exp_reward)
	synthesis_completed.emit(exp_reward)
	return true

# 由服务端合成结果添加套牌
func add_synthesized_deck(deck_data: Dictionary) -> void:
	var deck_id = deck_data.get("id", "")
	var series_name = ""
	var deck_name = ""

	var dd = deck_data.get("deck_def", {})
	if dd is Dictionary:
		deck_name = dd.get("name", "")

	var s = deck_data.get("series", {})
	if s is Dictionary:
		series_name = s.get("name", "")

	var color = CardColor.from_string(str(deck_data.get("color", "white")))
	var combat_power = deck_data.get("combat_power", 0)

	var deck = _CCRData.Deck.new(str(deck_id), series_name, deck_name, color)
	deck.combat_power = combat_power
	for i in range(1, 6):
		deck.add_card_number(i)
	player_decks.append(deck)
	deck_updated.emit(deck)

func get_player_decks() -> Array[Deck]:
	return player_decks

func get_deck_count() -> int:
	return player_decks.size()

func get_deck_count_by_color(color: CardColor.ColorType) -> int:
	var count = 0
	for d in player_decks:
		if d.color == color:
			count += 1
	return count
