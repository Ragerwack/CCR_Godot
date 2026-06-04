class_name Vault
extends RefCounted

var cards: Array[CardInfo] = []
var max_slots: int = 2

signal vault_changed()

func _init(slots: int = 2):
	max_slots = slots

func set_max_slots(n: int) -> void:
	max_slots = n

func is_full() -> bool:
	return cards.size() >= max_slots

func get_empty_slots() -> int:
	return max_slots - cards.size()

func add_card(card: CardInfo) -> bool:
	if is_full():
		return false
	cards.append(card)
	vault_changed.emit()
	return true

func remove_card(card: CardInfo) -> bool:
	var idx = cards.find(card)
	if idx >= 0:
		cards.remove_at(idx)
		vault_changed.emit()
		return true
	return false

func get_card_at(idx: int) -> CardInfo:
	if idx >= 0 and idx < cards.size():
		return cards[idx]
	return null

func get_cards_by_deck(deck_name: String) -> Array[CardInfo]:
	var result: Array[CardInfo] = []
	for c in cards:
		if c.deck_name == deck_name:
			result.append(c)
	return result

func get_cards_by_series(series: String) -> Array[CardInfo]:
	var result: Array[CardInfo] = []
	for c in cards:
		if c.series_name == series:
			result.append(c)
	return result

func to_dict() -> Dictionary:
	var arr: Array = []
	for c in cards:
		arr.append(c.to_dict())
	return {"cards": arr, "max_slots": max_slots}
