extends Control
class_name TodayDecksUI

const ROW_COUNT: int = 8
const CARDS_PER_DECK: int = 5
const ROW_GAP: int = 14
const LEFT_PAD: int = 28
const TOP_PAD: int = 18
const CARD_SPACING: int = 8
const INFO_WIDTH: int = 190
const BASE_COLORS: Array[CardColor.ColorType] = [
	CardColor.ColorType.WHITE,
	CardColor.ColorType.GREEN,
	CardColor.ColorType.BLUE,
	CardColor.ColorType.PURPLE,
	CardColor.ColorType.ORANGE,
]
const COLOR_API_NAMES: Array[String] = ["white", "green", "blue", "purple", "orange"]

var _content: VBoxContainer = null
var _status_label: Label = null

func _ready() -> void:
	_build_shell()
	_render()
	_ensure_draw_key.call_deferred()

func _build_shell() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = LEFT_PAD
	root.offset_top = TOP_PAD
	root.offset_right = -24
	root.offset_bottom = -18
	root.add_theme_constant_override("separation", 12)
	add_child(root)

	var title := Label.new()
	title.text = Localization.t("ui.today_decks.title")
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.92, 0.96, 1.0, 1.0))
	root.add_child(title)

	_status_label = Label.new()
	_status_label.text = ""
	_status_label.add_theme_font_size_override("font_size", 13)
	_status_label.add_theme_color_override("font_color", Color(0.72, 0.80, 0.92, 1.0))
	root.add_child(_status_label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)

	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", ROW_GAP)
	scroll.add_child(_content)

func _ensure_draw_key() -> void:
	if not GameManager.draw_key.is_empty():
		return
	if not ApiClient.is_logged_in():
		_set_status(Localization.t("ui.today_decks.no_key"))
		return
	_set_status(Localization.t("ui.today_decks.loading"))
	var resp := await ApiClient.get_draw_key()
	if resp.get("success", false):
		GameManager.apply_draw_key(resp["data"])
		_render()
	else:
		_set_status(Localization.t("ui.today_decks.load_failed", [resp.get("error", "")]))

func _render() -> void:
	if _content == null:
		return
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()

	var decks: Array = GameManager.draw_key.get("decks", [])
	if decks.is_empty():
		_set_status(Localization.t("ui.today_decks.no_key"))
	else:
		_set_status(Localization.t("ui.today_decks.date", [str(GameManager.draw_key.get("date_key", ""))]))

	for row_index in range(ROW_COUNT):
		var deck_data: Dictionary = {}
		if row_index < decks.size() and decks[row_index] is Dictionary:
			deck_data = decks[row_index]
		_content.add_child(_build_deck_row(row_index, deck_data))

func _build_deck_row(row_index: int, deck_data: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.name = "TodayDeckRow%d" % (row_index + 1)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 14)

	var info := _build_deck_info(row_index, deck_data)
	row.add_child(info)

	var cards := HBoxContainer.new()
	cards.name = "TodayDeckCards"
	cards.add_theme_constant_override("separation", CARD_SPACING)
	row.add_child(cards)

	var card_size := CardSlotUI.SLOT_SIZE
	var colors := _display_colors(deck_data)
	for card_number in range(1, CARDS_PER_DECK + 1):
		var card := _card_for_number(deck_data, card_number, colors[card_number - 1])
		var card_view := CardDisplay.new()
		card_view.name = "Card%d" % card_number
		card_view.custom_minimum_size = card_size
		card_view.size = card_size
		cards.add_child(card_view)
		_configure_card_view.call_deferred(card_view, card_size, card, card_number - 1)
	return row

func _configure_card_view(card_view: CardDisplay, card_size: Vector2, card: CardInfo, card_index: int) -> void:
	if not is_instance_valid(card_view):
		return
	card_view.custom_minimum_size = card_size
	card_view.size = card_size
	card_view.is_draggable = false
	card_view.hover_uses_slot_bounds = false
	card_view.mouse_filter = Control.MOUSE_FILTER_STOP
	if card != null:
		card_view.set_card(card, card_index)
	else:
		card_view.clear()

func _build_deck_info(row_index: int, deck_data: Dictionary) -> VBoxContainer:
	var info := VBoxContainer.new()
	info.name = "TodayDeckInfo"
	info.custom_minimum_size = Vector2(INFO_WIDTH, CardSlotUI.SLOT_SIZE.y)
	info.add_theme_constant_override("separation", 3)

	var type_label := _info_label(_deck_type_text(row_index))
	type_label.name = "DeckTypeLabel"
	type_label.add_theme_color_override("font_color", Color(0.90, 0.78, 0.46, 1.0))
	info.add_child(type_label)

	var name_label := _info_label(_series_deck_title(row_index, deck_data))
	name_label.name = "DeckNameLabel"
	name_label.add_theme_color_override("font_color", Color(0.88, 0.92, 1.0, 1.0))
	info.add_child(name_label)

	var level_label := _info_label(Localization.t("ui.today_decks.visible_level", [_visible_level_for_row(row_index)]))
	level_label.name = "DeckVisibleLevelLabel"
	level_label.add_theme_color_override("font_color", Color(0.68, 0.78, 0.92, 1.0))
	info.add_child(level_label)
	return info

func _info_label(text: String) -> Label:
	var label := Label.new()
	label.custom_minimum_size = Vector2(INFO_WIDTH, 21)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.clip_contents = true
	label.add_theme_font_size_override("font_size", 13)
	label.text = text
	return label

func _deck_type_text(row_index: int) -> String:
	match row_index:
		0: return Localization.t("ui.today_decks.type.today")
		1: return Localization.t("ui.today_decks.type.yesterday")
		2: return Localization.t("ui.today_decks.type.day_before")
		_: return Localization.t("ui.today_decks.type.random")

func _series_deck_title(row_index: int, deck_data: Dictionary) -> String:
	if deck_data.is_empty():
		return Localization.t("ui.today_decks.empty_row", [row_index + 1])
	var series_name := str(deck_data.get("series_name", ""))
	var deck_name := str(deck_data.get("deck_name", ""))
	if series_name != "" and deck_name != "":
		return "%s-%s" % [series_name, deck_name]
	if deck_name != "":
		return deck_name
	if series_name != "":
		return series_name
	return Localization.t("ui.today_decks.empty_row", [row_index + 1])

func _visible_level_for_row(row_index: int) -> int:
	match row_index:
		0, 1: return 1
		2: return 2
		3: return 5
		4: return 10
		5: return 20
		6: return 30
		_: return 40

func _card_for_number(deck_data: Dictionary, number: int, color: CardColor.ColorType) -> CardInfo:
	if deck_data.is_empty():
		return null
	var card_from_key := _card_from_draw_key(deck_data, number, color)
	if card_from_key != null:
		return card_from_key

	var deck_key := str(deck_data.get("deck_def_key", deck_data.get("deck_key", deck_data.get("name", ""))))
	var deck_def_id := int(deck_data.get("deck_def_id", deck_data.get("id", 0)))
	var local_cards: Array[CardInfo] = []
	if deck_key != "":
		local_cards = CardDataManager.get_cards_by_deck_key(deck_key)
	if local_cards.is_empty() and deck_def_id > 0:
		local_cards = CardDataManager.get_cards_by_deck_id(deck_def_id)
	if local_cards.is_empty():
		local_cards = CardDataManager.get_cards_by_deck(str(deck_data.get("series_name", "")), str(deck_data.get("deck_name", "")))
	for card in local_cards:
		if card != null and card.card_number == number:
			var copy := CardInfo.new(card.to_dict())
			copy.color = color
			return copy
	return null

func _card_from_draw_key(deck_data: Dictionary, number: int, color: CardColor.ColorType) -> CardInfo:
	var cards: Array = deck_data.get("cards", [])
	for raw in cards:
		if not raw is Dictionary:
			continue
		if int(raw.get("number", 1)) != number:
			continue
		return CardInfo.new({
			"id": str(raw.get("card_def_id", raw.get("id", 0))),
			"series_name": str(deck_data.get("series_name", "")),
			"deck_name": str(deck_data.get("deck_name", "")),
			"card_number": number,
			"color": color,
			"card_name": str(raw.get("name", "")),
			"description": str(raw.get("description", "")),
			"image_path": str(raw.get("image_url", raw.get("image", ""))),
		})
	return null

func _display_colors(deck_data: Dictionary) -> Array[CardColor.ColorType]:
	var colors: Array[CardColor.ColorType] = BASE_COLORS.duplicate()
	for api_name in COLOR_API_NAMES:
		if not _is_color_exhausted(deck_data, api_name):
			continue
		var color_type := CardColor.from_string(api_name)
		var idx := colors.find(color_type)
		if idx >= 0:
			colors.remove_at(idx)
			colors.push_front(CardColor.ColorType.WHITE)
	while colors.size() < CARDS_PER_DECK:
		colors.push_front(CardColor.ColorType.WHITE)
	return colors.slice(0, CARDS_PER_DECK)

func _is_color_exhausted(deck_data: Dictionary, api_name: String) -> bool:
	for key in ["sold_out_colors", "exhausted_colors", "relic_sold_out_colors"]:
		var color_list: Variant = deck_data.get(key, [])
		if color_list is Array:
			for value in color_list:
				if str(value).to_lower() == api_name:
					return true

	for key in ["relic_caps", "relic_limits", "relic_supply"]:
		var caps: Variant = deck_data.get(key, {})
		if not caps is Dictionary:
			continue
		var cap_value: Variant = caps.get(api_name, null)
		if cap_value is Dictionary:
			if bool(cap_value.get("exhausted", cap_value.get("sold_out", cap_value.get("is_exhausted", false)))):
				return true
			var max_value: Variant = cap_value.get("max", cap_value.get("max_supply", cap_value.get("limit", null)))
			if max_value != null:
				var current := int(cap_value.get("current", cap_value.get("issued", cap_value.get("count", 0))))
				return current >= int(max_value)
		elif cap_value is bool:
			return bool(cap_value)
	return false

func _set_status(text: String) -> void:
	if _status_label != null:
		_status_label.text = text
