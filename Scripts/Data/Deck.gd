class_name Deck
extends RefCounted

var id: String
var series_name: String
var deck_name: String
var color: CardColor.ColorType
var card_count: int = 0
var combat_power: int = 0

# 已收集的编号 (1-5)
var collected_numbers: Array[int] = []

func _init(id_: String = "", series_: String = "", deck_: String = "", color_: CardColor.ColorType = CardColor.ColorType.WHITE):
	id = id_
	series_name = series_
	deck_name = deck_
	color = color_

func is_complete() -> bool:
	return collected_numbers.size() >= 5

func add_card_number(n: int) -> bool:
	if n in collected_numbers:
		return false
	collected_numbers.append(n)
	collected_numbers.sort()
	card_count = collected_numbers.size()
	return true

func has_card_number(n: int) -> bool:
	return n in collected_numbers

func get_missing_numbers() -> Array[int]:
	var missing: Array[int] = []
	for i in range(1, 6):
		if not (i in collected_numbers):
			missing.append(i)
	return missing

func to_dict() -> Dictionary:
	return {
		"id": id,
		"series_name": series_name,
		"deck_name": deck_name,
		"color": color,
		"card_count": card_count,
		"combat_power": combat_power,
		"collected_numbers": collected_numbers,
	}
