extends Control
class_name TodayDecksUI

const CCRLinkedVerticalScrollBarScript = preload("res://Scripts/UI/CCRLinkedVerticalScrollBar.gd")

const ROW_COUNT: int = 8
const CARDS_PER_DECK: int = 5
const ROW_GAP: int = 14
const TOP_PAD: int = 18
const CARD_SPACING: int = 8
const INFO_ROW_HEIGHT: int = 26
const KEY_ROW_HEIGHT: int = 26
const CARD_ROW_SEPARATOR: float = 4.0
const BASE_COLORS: Array[CardColor.ColorType] = [
	CardColor.ColorType.GREEN,
	CardColor.ColorType.BLUE,
	CardColor.ColorType.PURPLE,
	CardColor.ColorType.ORANGE,
	CardColor.ColorType.BLACK,
]
const COLOR_API_NAMES: Array[String] = ["green", "blue", "purple", "orange", "black"]

var _content: VBoxContainer = null
var _scroll_container: ScrollContainer = null
var _vertical_scrollbar: VScrollBar = null
var _status_label: Label = null
var _reset_countdown_label: Label = null
var _hover_preview: CardDisplay = null
var _hover_preview_source: CardDisplay = null
var _top_pad: float = TOP_PAD
var _left_pad: float = 0.0
var _session_scroll_vertical: int = 0
var _restore_scroll_pending: bool = false

func configure_layout(top_padding: float) -> void:
	_top_pad = maxf(0.0, top_padding)
	# 使用经验条高度作为水平安全边距，避免最左侧卡牌被页面边缘遮挡。
	_left_pad = _top_pad
	if is_node_ready():
		_build_shell()
		_render()

func _process(_delta: float) -> void:
	_update_reset_countdown()

func _ready() -> void:
	_build_shell()
	_render()
	set_process(true)
	if not Localization.locale_changed.is_connected(_on_locale_changed):
		Localization.locale_changed.connect(_on_locale_changed)
	_ensure_draw_key.call_deferred()

func _on_locale_changed(_locale: String) -> void:
	if not is_inside_tree():
		return
	# 抽卡密匙的稳定 ID 不变，页面可以先用本地资源立即重建；
	# MainUI 随后会请求当前语言的密匙以更新服务端回传文案。
	_render()

func _build_shell() -> void:
	_capture_scroll_vertical()
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_content = null
	_scroll_container = null
	_vertical_scrollbar = null
	_status_label = null
	_reset_countdown_label = null

	var root := Control.new()
	root.name = "TodayDecksRoot"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var cards_width := _cards_width()
	var key_row := Control.new()
	key_row.name = "TodayDeckKeyRow"
	key_row.set_anchors_preset(Control.PRESET_TOP_LEFT)
	key_row.position = Vector2(_left_pad, _top_pad)
	key_row.size = Vector2(cards_width, KEY_ROW_HEIGHT)
	root.add_child(key_row)

	_reset_countdown_label = Label.new()
	_reset_countdown_label.name = "TodayDeckResetCountdown"
	# 仅保留倒计时，并放到原“今日密匙日期”的左侧位置。
	_reset_countdown_label.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	_reset_countdown_label.offset_left = 0
	_reset_countdown_label.offset_right = 0
	_reset_countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_reset_countdown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_reset_countdown_label.add_theme_font_size_override("font_size", 16)
	_reset_countdown_label.add_theme_color_override("font_color", Color.BLACK)
	key_row.add_child(_reset_countdown_label)

	_status_label = Label.new()
	_status_label.name = "TodayDeckStatusLabel"
	_status_label.text = ""
	_status_label.add_theme_font_size_override("font_size", 13)
	_status_label.add_theme_color_override("font_color", Color(0.72, 0.80, 0.92, 1.0))
	_status_label.visible = false
	root.add_child(_status_label)

	var scroll := ScrollContainer.new()
	scroll.name = "TodayDeckScroll"
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	# 安全边距必须放在 ScrollContainer 内部；把滚动容器本身右移会让首列卡牌
	# 仍然紧贴裁切边界，从而裁掉 CardDisplay 向左外扩的柔影。
	scroll.offset_left = 0
	scroll.offset_top = _top_pad + KEY_ROW_HEIGHT + 10.0
	scroll.offset_right = 0
	scroll.offset_bottom = -18
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	_scroll_container = scroll

	var content_margin := MarginContainer.new()
	content_margin.name = "TodayDeckContentMargin"
	content_margin.add_theme_constant_override("margin_left", int(ceil(_left_pad)))
	# 最后一排卡牌本体之后保留完整的向下柔影空间，避免被滚动视口裁掉。
	content_margin.add_theme_constant_override("margin_bottom", int(ceil(_card_shadow_bottom_bleed())))
	content_margin.custom_minimum_size = Vector2(_left_pad + cards_width, 0)
	scroll.add_child(content_margin)

	_content = VBoxContainer.new()
	_content.custom_minimum_size = Vector2(cards_width, 0)
	_content.add_theme_constant_override("separation", ROW_GAP)
	content_margin.add_child(_content)

	_vertical_scrollbar = CCRLinkedVerticalScrollBarScript.new() as VScrollBar
	_vertical_scrollbar.name = "TodayDeckVerticalScrollbar"
	_vertical_scrollbar.z_index = 8
	root.add_child(_vertical_scrollbar)
	_vertical_scrollbar.call("bind_scroll_container", scroll)
	_layout_vertical_scrollbar()
	_schedule_scroll_restore()

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
	_capture_scroll_vertical()
	_hide_hover_preview()
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()

	var decks: Array = GameManager.draw_key.get("decks", [])
	if decks.is_empty():
		_set_status(Localization.t("ui.today_decks.no_key"))
	else:
		_set_status("")
	_update_reset_countdown()

	for row_index in range(ROW_COUNT):
		var deck_data: Dictionary = {}
		if row_index < decks.size() and decks[row_index] is Dictionary:
			deck_data = decks[row_index]
		_content.add_child(_build_deck_row(row_index, deck_data))
	_schedule_scroll_restore()

func get_session_scroll_vertical() -> int:
	if _scroll_container != null:
		return _scroll_container.scroll_vertical
	return _session_scroll_vertical

func set_session_scroll_vertical(value: int) -> void:
	_session_scroll_vertical = maxi(0, value)
	_schedule_scroll_restore()

func _capture_scroll_vertical() -> void:
	if _scroll_container == null or _restore_scroll_pending:
		return
	_session_scroll_vertical = _scroll_container.scroll_vertical

func _schedule_scroll_restore() -> void:
	if _scroll_container == null or _restore_scroll_pending:
		return
	_restore_scroll_pending = true
	_restore_session_scroll_vertical.call_deferred()

func _restore_session_scroll_vertical() -> void:
	if not is_inside_tree():
		_restore_scroll_pending = false
		return
	await get_tree().process_frame
	if is_instance_valid(_scroll_container):
		_scroll_container.scroll_vertical = _session_scroll_vertical
	_restore_scroll_pending = false

func _build_deck_row(row_index: int, deck_data: Dictionary) -> Control:
	var row := VBoxContainer.new()
	row.name = "TodayDeckRow%d" % (row_index + 1)
	row.custom_minimum_size = Vector2(_cards_width(), INFO_ROW_HEIGHT + CardSlotUI.SLOT_SIZE.y + CARD_ROW_SEPARATOR)
	row.add_theme_constant_override("separation", int(CARD_ROW_SEPARATOR))

	var info := _build_deck_info(row_index, deck_data)
	row.add_child(info)

	var cards := HBoxContainer.new()
	cards.name = "TodayDeckCards"
	cards.add_theme_constant_override("separation", CARD_SPACING)
	cards.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	row.add_child(cards)

	var card_size := CardSlotUI.SLOT_SIZE
	cards.custom_minimum_size = Vector2(card_size.x * CARDS_PER_DECK + CARD_SPACING * (CARDS_PER_DECK - 1), card_size.y)
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
	card_view.hover_scale_enabled = false
	card_view.mouse_filter = Control.MOUSE_FILTER_STOP
	if not card_view.card_hover_changed.is_connected(_on_card_hover_changed):
		card_view.card_hover_changed.connect(_on_card_hover_changed)
	if card != null:
		card_view.set_card(card, card_index)
	else:
		card_view.clear()

func _exit_tree() -> void:
	_hide_hover_preview()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout_vertical_scrollbar()
		if _hover_preview != null:
			_layout_hover_preview()

func _layout_vertical_scrollbar() -> void:
	if _vertical_scrollbar == null:
		return
	var scroll_top := _top_pad + KEY_ROW_HEIGHT + 10.0
	var first_card_top := scroll_top + INFO_ROW_HEIGHT + CARD_ROW_SEPARATOR
	var scroll_bottom := maxf(scroll_top, size.y - 18.0)
	# 滚到底时，底部安全留白会让末排卡牌本体下缘停在这个位置；
	# 因而轨道首尾可分别严格对应首排上缘与末排下缘。
	var last_card_bottom := scroll_bottom - _card_shadow_bottom_bleed()
	var protected_caps_height := float(CCRVisualStyle.SETTINGS_VERTICAL_SCROLLBAR_TRACK_END_MARGIN * 2)
	var scrollbar_height := maxf(protected_caps_height, last_card_bottom - first_card_top)
	var scrollbar_size := Vector2(CCRLinkedVerticalScrollBarScript.CONTROL_SIZE.x, scrollbar_height)
	_vertical_scrollbar.size = scrollbar_size
	_vertical_scrollbar.custom_minimum_size = scrollbar_size
	var cards_right := _left_pad + _cards_width()
	_vertical_scrollbar.position = Vector2(
		cards_right + _top_pad,
		first_card_top
	)

func _card_shadow_bottom_bleed() -> float:
	return float(CardDisplay.CARD_SHADOW_SIZE) + maxf(0.0, CardDisplay.CARD_SHADOW_OFFSET.y)

func _on_card_hover_changed(card_view: CardDisplay, active: bool) -> void:
	if active:
		_show_hover_preview(card_view)
	elif card_view == _hover_preview_source:
		_hide_hover_preview()

func _show_hover_preview(card_view: CardDisplay) -> void:
	if card_view == null or card_view.card == null or get_tree() == null:
		return
	if DragSystem != null and DragSystem.is_dragging():
		return
	_hide_hover_preview()
	_hover_preview_source = card_view
	_hover_preview = CardDisplay.new()
	_hover_preview.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_hover_preview.z_index = 4090
	_hover_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_tree().root.add_child(_hover_preview)
	_layout_hover_preview()
	_hover_preview.set_card(card_view.card, card_view.card_index)
	_hover_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _layout_hover_preview() -> void:
	if _hover_preview == null or _hover_preview_source == null:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var preview_height := viewport_size.y * 0.5
	var preview_width := preview_height * (CardSlotUI.SLOT_SIZE.x / CardSlotUI.SLOT_SIZE.y)
	var blank_rect := _right_blank_preview_rect()
	var center := blank_rect.get_center() if blank_rect.size.x > 0.0 and blank_rect.size.y > 0.0 else Vector2(viewport_size.x * 0.75, viewport_size.y * 0.5)
	var preview_pos := Vector2(
		clampf(center.x - preview_width * 0.5, 0.0, maxf(0.0, viewport_size.x - preview_width)),
		clampf(center.y - preview_height * 0.5, 0.0, maxf(0.0, viewport_size.y - preview_height))
	)
	_hover_preview.position = preview_pos
	_hover_preview.size = Vector2(preview_width, preview_height)
	_hover_preview.custom_minimum_size = _hover_preview.size

func _right_blank_preview_rect() -> Rect2:
	var viewport_size := get_viewport().get_visible_rect().size
	var cards_box := _hover_preview_source.get_parent() as Control if _hover_preview_source != null else null
	if cards_box == null:
		return Rect2()
	var cards_rect := Rect2(cards_box.global_position, cards_box.size)
	var left := cards_rect.end.x + 18.0
	if _vertical_scrollbar != null:
		left = maxf(left, _vertical_scrollbar.get_global_rect().end.x + 18.0)
	var right := viewport_size.x - 24.0
	if right <= left:
		return Rect2()
	return Rect2(Vector2(left, 0.0), Vector2(right - left, viewport_size.y))

func _hide_hover_preview() -> void:
	if _hover_preview != null:
		_hover_preview.queue_free()
	_hover_preview = null
	_hover_preview_source = null

func _build_deck_info(row_index: int, deck_data: Dictionary) -> HBoxContainer:
	var info := HBoxContainer.new()
	info.name = "TodayDeckInfo"
	info.custom_minimum_size = Vector2(_cards_width(), INFO_ROW_HEIGHT)
	info.add_theme_constant_override("separation", 0)

	var type_label := _info_label(_deck_type_text(row_index))
	type_label.name = "DeckTypeLabel"
	type_label.add_theme_color_override("font_color", Color.BLACK)
	type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	info.add_child(type_label)

	var name_label := _info_label(_series_deck_title(row_index, deck_data))
	name_label.name = "DeckNameLabel"
	name_label.add_theme_color_override("font_color", Color.BLACK)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.add_child(name_label)

	var level_label := _info_label(Localization.t("ui.today_decks.visible_level", [_visible_level_for_row(row_index)]))
	level_label.name = "DeckVisibleLevelLabel"
	level_label.add_theme_color_override("font_color", Color.BLACK)
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	info.add_child(level_label)
	return info

func _info_label(text: String) -> Label:
	var label := Label.new()
	label.custom_minimum_size = Vector2(_cards_width() / 3.0, INFO_ROW_HEIGHT)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.clip_contents = true
	label.add_theme_font_size_override("font_size", 15)
	label.text = text
	return label

func _cards_width() -> float:
	return CardSlotUI.SLOT_SIZE.x * CARDS_PER_DECK + CARD_SPACING * (CARDS_PER_DECK - 1)

func _update_reset_countdown() -> void:
	if _reset_countdown_label == null:
		return
	_reset_countdown_label.text = Localization.t("ui.today_decks.reset_countdown", [_format_reset_countdown()])

func _format_reset_countdown() -> String:
	var now_unix := Time.get_unix_time_from_system()
	var beijing_unix := now_unix + 8.0 * 3600.0
	var seconds_in_day := int(beijing_unix) % 86400
	var remaining := 86400 - seconds_in_day
	if remaining >= 86400:
		remaining = 0
	var hours := int(remaining / 3600)
	var minutes := int((remaining % 3600) / 60)
	var seconds := remaining % 60
	return "%02d:%02d:%02d" % [hours, minutes, seconds]

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
	var local_cards := _local_cards_for_deck(deck_data)
	if not local_cards.is_empty():
		series_name = local_cards[0].series_name
		deck_name = local_cards[0].deck_name
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
	if local_cards.is_empty():
		local_cards = CardDataManager.get_cards_by_deck_alias(
			str(deck_data.get("series_name", "")),
			str(deck_data.get("deck_name", ""))
		)
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

func _local_cards_for_deck(deck_data: Dictionary) -> Array[CardInfo]:
	var series_asset_id := int(deck_data.get("series_asset_id", 0))
	var deck_asset_id := int(deck_data.get("deck_asset_id", 0))
	if series_asset_id > 0 and deck_asset_id > 0:
		var by_asset := CardDataManager.get_cards_by_asset_ids(series_asset_id, deck_asset_id)
		if not by_asset.is_empty():
			return by_asset
	var deck_def_id := int(deck_data.get("deck_def_id", deck_data.get("id", 0)))
	if deck_def_id > 0:
		var by_id := CardDataManager.get_cards_by_deck_id(deck_def_id)
		if _draw_key_names_match_local_deck(deck_data, by_id):
			return by_id
	var deck_key := str(deck_data.get("deck_def_key", deck_data.get("deck_key", "")))
	if deck_key != "":
		var by_key := CardDataManager.get_cards_by_deck_key(deck_key)
		if _draw_key_names_match_local_deck(deck_data, by_key):
			return by_key
	var by_alias := CardDataManager.get_cards_by_deck_alias(
		str(deck_data.get("series_name", "")),
		str(deck_data.get("deck_name", ""))
	)
	if not by_alias.is_empty():
		return by_alias
	return []

func _draw_key_names_match_local_deck(deck_data: Dictionary, cards: Array[CardInfo]) -> bool:
	if cards.is_empty():
		return false
	var source := cards[0]
	if source == null:
		return false
	return (
		_known_card_text(source, "series_name", str(deck_data.get("series_name", "")))
		and _known_card_text(source, "deck_name", str(deck_data.get("deck_name", "")))
	)

func _known_card_text(card: CardInfo, field: String, value: String) -> bool:
	if value == "":
		return true
	var candidates: Array[String] = []
	if field == "series_name":
		candidates.append(card.series_name)
		candidates.append(card.series_name_zh)
		candidates.append(card.series_name_en)
	else:
		candidates.append(card.deck_name)
		candidates.append(card.deck_name_zh)
		candidates.append(card.deck_name_en)
	for locale_texts in card.localized_texts.values():
		if locale_texts is Dictionary:
			candidates.append(str(locale_texts.get(field, "")))
	return value in candidates

func _card_from_draw_key(deck_data: Dictionary, number: int, color: CardColor.ColorType) -> CardInfo:
	var cards: Array = deck_data.get("cards", [])
	for raw in cards:
		if not raw is Dictionary:
			continue
		if int(raw.get("number", 1)) != number:
			continue
		var card := CardInfo.new({
			"id": str(raw.get("card_def_id", raw.get("id", 0))),
			"card_asset_id": int(raw.get("card_asset_id", raw.get("number", number))),
			"deck_asset_id": int(deck_data.get("deck_asset_id", 0)),
			"series_asset_id": int(deck_data.get("series_asset_id", 0)),
			"deck_definition_id": int(deck_data.get("deck_def_id", deck_data.get("id", 0))),
			"series_definition_id": int(deck_data.get("series_id", 0)),
			"card_number": number,
			"color": color,
		})
		return CardDataManager.localize_card_in_place(card)
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
