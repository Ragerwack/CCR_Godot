extends Node

const SynthesisAnimationOverlayScript = preload("res://Scripts/UI/SynthesisAnimationOverlay.gd")


func _ready() -> void:
	var cards: Array[CardInfo] = CardDataManager.get_cards_by_deck_id(1)
	if cards.size() != 5:
		return _fail("cards_missing")
	var sources := _make_sources(cards)

	var overlay = SynthesisAnimationOverlayScript.new()
	overlay.setup(sources, Rect2(Vector2(8, 210), Vector2(104, 36)))
	await get_tree().process_frame
	get_tree().root.add_child(overlay)
	await overlay.play()
	await get_tree().process_frame
	if is_instance_valid(overlay):
		return _fail("overlay_not_freed")

	var store_overlay = SynthesisAnimationOverlayScript.new()
	store_overlay.setup([sources[0]], Rect2(Vector2(8, 210), Vector2(104, 36)))
	get_tree().root.add_child(store_overlay)
	await store_overlay.play_store_to_nav()
	await get_tree().process_frame
	if is_instance_valid(store_overlay):
		return _fail("store_overlay_not_freed")

	var discard_overlay = SynthesisAnimationOverlayScript.new()
	discard_overlay.setup([sources[1]], Rect2(Vector2(8, 210), Vector2(104, 36)))
	get_tree().root.add_child(discard_overlay)
	await discard_overlay.play_discard()
	await get_tree().process_frame
	if is_instance_valid(discard_overlay):
		return _fail("discard_overlay_not_freed")

	print("SYNTHESIS_ANIMATION_OVERLAY ok cards=5 color=purple store=true discard=true")
	get_tree().quit(0)


func _make_sources(cards: Array[CardInfo]) -> Array[Dictionary]:
	var sources: Array[Dictionary] = []
	for i in range(5):
		var card := CardInfo.new(cards[i].to_dict())
		card.color = CardColor.ColorType.PURPLE
		sources.append({
			"index": i,
			"card": card,
			"global_rect": Rect2(Vector2(170 + i * 72, 470 - absf(float(i) - 2.0) * 18.0), Vector2(64, 90)),
			"visible": true,
		})
	return sources


func _fail(reason: String) -> void:
	push_error("SYNTHESIS_ANIMATION_OVERLAY " + reason)
	get_tree().quit(1)
