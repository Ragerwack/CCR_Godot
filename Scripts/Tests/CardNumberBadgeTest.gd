extends Node

func _ready() -> void:
	var card_display := CardDisplay.new()
	card_display.size = Vector2(107, 149)
	add_child(card_display)
	card_display.set_card(CardInfo.new({
		"id": "1",
		"series_name": "测试系列",
		"deck_name": "测试卡组",
		"card_number": 5,
		"color": "白",
		"card_name": "测试子卡",
		"description": "测试描述",
	}), 0)
	await get_tree().process_frame

	var badge: Control = card_display.get("_number_badge")
	var number_label: Label = card_display.get("_number_label")
	if badge == null or number_label == null:
		_fail("number badge nodes are missing")
		return
	if number_label.text != "5":
		_fail("number label does not show the card number")
		return
	var epsilon := 0.01
	if badge.position.x < -epsilon or badge.position.y < -epsilon:
		_fail("number badge starts outside the card")
		return
	if badge.position.x + badge.size.x > card_display.size.x + epsilon:
		_fail("number badge extends past the card's right edge")
		return
	if badge.position.y + badge.size.y > card_display.size.y + epsilon:
		_fail("number badge extends past the card's bottom edge")
		return

	print("CARD_NUMBER_BADGE ok")
	get_tree().quit(0)

func _fail(message: String) -> void:
	push_error("CARD_NUMBER_BADGE " + message)
	get_tree().quit(1)
