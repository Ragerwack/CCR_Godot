extends Node

func _ready() -> void:
	var pool_left := _add_slot("pool", 0, Vector2(40, 60), 1)
	var pool_right := _add_slot("pool", 4, Vector2(520, 60), 2)
	var hand_left := _add_slot("hand", 0, Vector2(40, 300), 3)
	var hand_right := _add_slot("hand", 4, Vector2(520, 300), 4)

	await get_tree().process_frame

	var viewport_size := get_viewport().get_visible_rect().size
	var preview_size := Vector2(260, 360)
	var left_rect := Rect2(pool_left.global_position, pool_left.size).merge(Rect2(hand_left.global_position, hand_left.size))
	var right_rect := Rect2(pool_right.global_position, pool_right.size).merge(Rect2(hand_right.global_position, hand_right.size))

	if not _centers_close(pool_left._hover_preview_center(viewport_size, preview_size), right_rect.get_center()):
		return _fail("pool_left_preview_not_at_right_group_center")

	if not _centers_close(hand_left._hover_preview_center(viewport_size, preview_size), right_rect.get_center()):
		return _fail("hand_left_preview_not_at_right_group_center")

	if not _centers_close(pool_right._hover_preview_center(viewport_size, preview_size), left_rect.get_center()):
		return _fail("pool_right_preview_not_at_left_group_center")

	if not _centers_close(hand_right._hover_preview_center(viewport_size, preview_size), left_rect.get_center()):
		return _fail("hand_right_preview_not_at_left_group_center")

	print("HOVER_PREVIEW_POSITION ok")
	get_tree().quit(0)

func _add_slot(area: String, index: int, slot_position: Vector2, card_id: int) -> CardSlotUI:
	var slot := CardSlotUI.new()
	slot.slot_index = index
	slot.area_type = area
	slot.position = slot_position
	add_child(slot)
	slot.set_card(_make_card(card_id), index)
	return slot

func _make_card(id_value: int) -> CardInfo:
	return CardInfo.new({
		"id": str(id_value),
		"series_name": "测试系列",
		"deck_name": "预览定位测试",
		"card_number": id_value,
		"color": "white",
		"card_name": "测试卡%d" % id_value,
		"description": "预览定位测试卡。",
	})

func _control_center(control: Control) -> Vector2:
	return control.global_position + control.size * 0.5

func _centers_close(a: Vector2, b: Vector2) -> bool:
	return a.distance_to(b) <= 1.0

func _fail(reason: String) -> void:
	push_error("HOVER_PREVIEW_POSITION " + reason)
	get_tree().quit(1)
