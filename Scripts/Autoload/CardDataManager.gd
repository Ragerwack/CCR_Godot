extends Node

signal data_loaded
signal card_generated(card: CardInfo)

const CARD_DATA_PATH = "res://Resources/Cards/card-data.json"

var all_series: Array[CardSeries] = []
var all_cards: Array[CardInfo] = []

var _series_by_name: Dictionary = {}
var _cards_by_series: Dictionary = {}
var _cards_by_deck: Dictionary = {}

# 编号概率: 1号30%, 2号25%, 3号20%, 4号15%, 5号10%
const NUMBER_WEIGHTS: Array[float] = [30.0, 25.0, 20.0, 15.0, 10.0]

func _ready() -> void:
	load_card_data()

func load_card_data() -> bool:
	if not FileAccess.file_exists(CARD_DATA_PATH):
		push_error("Card data file not found: " + CARD_DATA_PATH)
		return false

	var file = FileAccess.open(CARD_DATA_PATH, FileAccess.READ)
	if file == null:
		push_error("Failed to open card data: " + str(FileAccess.get_open_error()))
		return false

	var json_str = file.get_as_text()
	file.close()

	var json = JSON.new()
	if json.parse(json_str) != OK:
		push_error("Failed to parse JSON")
		return false

	var data = json.get_data()
	# Support both: old flat { "cards": [...] } and new nested { "series": [...] }
	if data is Dictionary and data.has("series"):
		_parse_series_format(data["series"])
		data_loaded.emit()
		return true
	elif data is Dictionary and data.has("cards"):
		_parse_old_cards_format(data["cards"])
		data_loaded.emit()
		return true
	return false

# New 3-level format: series → decks → cards
func _parse_series_format(series_array: Array) -> void:
	all_cards.clear()
	all_series.clear()
	_series_by_name.clear()
	_cards_by_series.clear()
	_cards_by_deck.clear()

	for series_data in series_array:
		var sname = series_data.get("name_zh", "")
		var sen = series_data.get("name_en", "")
		var cat = series_data.get("category", "限时卡组")

		# Create CardSeries
		var cs = CardSeries.new({
			"type": cat,
			"series_name": sname,
			"series_style": sen,
		})

		# Process decks
		for deck_data in series_data.get("decks", []):
			var dname = deck_data.get("name_zh", "")

			for card_data in deck_data.get("cards", []):
				var card = CardInfo.new({
					"id": str(card_data.get("card_id", 0)),
					"series_name": sname,
					"deck_name": dname,
					"card_number": int(card_data.get("number", 1)),
					"color": "白",  # 默认白色，抽卡时随机分配
					"card_name": card_data.get("name_zh", ""),
					"description": card_data.get("desc_zh", ""),
					"image_path": card_data.get("image", ""),
					"type": cat,
					"series_style": sen,
				})
				all_cards.append(card)
				cs.add_card(card)

		all_series.append(cs)
		_series_by_name[sname] = cs
		_cards_by_series[sname] = _filter_cards_by_series(sname)

		# Build deck-level lookup
		for deck_data in series_data.get("decks", []):
			var dn = deck_data.get("name_zh", "")
			_cards_by_deck[sname + "/" + dn] = cs.get_deck_cards(dn)

func _filter_cards_by_series(series_name: String) -> Array[CardInfo]:
	var out: Array[CardInfo] = []
	for c in all_cards:
		if c.series_name == series_name:
			out.append(c)
	return out

# Old flat format: { "cards": [ { "series_name":..., "deck_name":..., ... } ] }
func _parse_old_cards_format(cards_array: Array) -> void:
	all_cards.clear()
	all_series.clear()
	_series_by_name.clear()
	_cards_by_series.clear()
	_cards_by_deck.clear()

	var series_map: Dictionary = {}

	for card_data in cards_array:
		var card = CardInfo.new(card_data)
		all_cards.append(card)

		if not series_map.has(card.series_name):
			series_map[card.series_name] = {
				"type": card.type,
				"series_name": card.series_name,
				"series_style": card.series_style,
				"decks": {}
			}

		var s = series_map[card.series_name]
		if not s["decks"].has(card.deck_name):
			s["decks"][card.deck_name] = []
		s["decks"][card.deck_name].append(card)

	for series_name in series_map:
		var sdata = series_map[series_name]
		var cs = CardSeries.new(sdata)
		all_series.append(cs)
		_series_by_name[series_name] = cs
		_cards_by_series[series_name] = all_cards.filter(func(c): return c.series_name == series_name)

		for deck_name in cs.get_deck_names():
			var key = series_name + "/" + deck_name
			_cards_by_deck[key] = cs.get_deck_cards(deck_name)

func get_all_series() -> Array[CardSeries]:
	return all_series

func get_series_by_name(name: String) -> CardSeries:
	return _series_by_name.get(name)

func get_cards_by_series(series_name: String) -> Array[CardInfo]:
	return _cards_by_series.get(series_name, [])

func get_cards_by_deck(series_name: String, deck_name: String) -> Array[CardInfo]:
	var key = series_name + "/" + deck_name
	return _cards_by_deck.get(key, [])

# 生成随机颜色
func roll_color() -> CardColor.ColorType:
	var total_weight = 0.0
	for w in CardColor.COLOR_WEIGHTS:
		total_weight += w
	var roll = randf() * total_weight
	var cumulative = 0.0
	for i in range(CardColor.COLOR_WEIGHTS.size()):
		cumulative += CardColor.COLOR_WEIGHTS[i]
		if roll <= cumulative:
			return i as CardColor.ColorType
	return CardColor.ColorType.WHITE

# 生成随机编号
func roll_card_number() -> int:
	var total = 0.0
	for w in NUMBER_WEIGHTS:
		total += w
	var roll = randf() * total
	var cumulative = 0.0
	for i in range(NUMBER_WEIGHTS.size()):
		cumulative += NUMBER_WEIGHTS[i]
		if roll <= cumulative:
			return i + 1
	return 1

# 从指定系列/卡组生成随机卡
func generate_card_from_deck(series_name: String, deck_name: String) -> CardInfo:
	var cards = get_cards_by_deck(series_name, deck_name)
	if cards.is_empty():
		return null
	var color = roll_color()
	var number = roll_card_number()
	for c in cards:
		if c.card_number == number:
			var new_card = CardInfo.new(c.to_dict())
			new_card.color = color
			return new_card
	var base_card = cards[randi() % cards.size()]
	var new_card2 = CardInfo.new(base_card.to_dict())
	new_card2.color = color
	return new_card2

# 填充卡池
func fill_pool(pool_size: int, visible_series: Array[String] = []) -> Array[CardInfo]:
	var result: Array[CardInfo] = []
	var series_to_use = visible_series if not visible_series.is_empty() else Array(_series_by_name.keys())
	for i in range(pool_size):
		if series_to_use.is_empty():
			break
		var sname = series_to_use[randi() % series_to_use.size()]
		var cs = _series_by_name.get(sname)
		if cs == null:
			continue
		var deck_names = cs.get_deck_names()
		if deck_names.is_empty():
			continue
		var dname = deck_names[randi() % deck_names.size()]
		var card = generate_card_from_deck(sname, dname)
		if card != null:
			result.append(card)
	return result
