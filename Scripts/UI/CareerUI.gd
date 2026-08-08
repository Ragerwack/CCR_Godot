extends Control
class_name CareerUI

const CCRVisualStyle = preload("res://Scripts/UI/CCRVisualStyle.gd")
const CountryCatalog = preload("res://Scripts/Data/CountryCatalog.gd")

const INFO_ICON_SIZE := 56.0
const HEADER_ICON_SIZE := 76.0
const CONTENT_SIDE_MARGIN := 34
const RELIC_ICON_PATHS := {
	CardColor.ColorType.WHITE: "res://Resources/Relics/final/relic_white_frame.png",
	CardColor.ColorType.GREEN: "res://Resources/Relics/final/relic_green_frame.png",
	CardColor.ColorType.BLUE: "res://Resources/Relics/final/relic_blue_frame.png",
	CardColor.ColorType.PURPLE: "res://Resources/Relics/final/relic_purple_frame.png",
	CardColor.ColorType.ORANGE: "res://Resources/Relics/final/relic_orange_frame.png",
	CardColor.ColorType.BLACK: "res://Resources/Relics/final/relic_black_frame.png",
	CardColor.ColorType.RED: "res://Resources/Relics/final/relic_red_frame.png",
}

var _refresh_queued := false
var _info_icon_size := INFO_ICON_SIZE

func configure_icon_size(target_size: float) -> void:
	_info_icon_size = maxf(INFO_ICON_SIZE, target_size)
	if is_node_ready():
		_queue_refresh()

func get_info_icon_size() -> float:
	return _info_icon_size

func _ready() -> void:
	GameManager.player_data.changed.connect(_queue_refresh)
	GameManager.data_synced.connect(_queue_refresh)
	Localization.locale_changed.connect(_on_locale_changed)
	_build_page()

func _exit_tree() -> void:
	if GameManager.player_data.changed.is_connected(_queue_refresh):
		GameManager.player_data.changed.disconnect(_queue_refresh)
	if GameManager.data_synced.is_connected(_queue_refresh):
		GameManager.data_synced.disconnect(_queue_refresh)
	if Localization.locale_changed.is_connected(_on_locale_changed):
		Localization.locale_changed.disconnect(_on_locale_changed)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_node_ready():
		_queue_refresh()

func _on_locale_changed(_locale: String) -> void:
	_queue_refresh()

func _queue_refresh() -> void:
	if _refresh_queued or not is_inside_tree():
		return
	_refresh_queued = true
	call_deferred("_refresh_deferred")

func _refresh_deferred() -> void:
	_refresh_queued = false
	if is_inside_tree():
		_build_page()

func _build_page() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()

	var scroll := ScrollContainer.new()
	scroll.name = "CareerScroll"
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	CCRVisualStyle.apply_settings_scroll_container(scroll)
	add_child(scroll)

	var margin := MarginContainer.new()
	margin.name = "CareerPageMargin"
	margin.custom_minimum_size.x = maxf(640.0, size.x)
	margin.add_theme_constant_override("margin_left", CONTENT_SIDE_MARGIN)
	margin.add_theme_constant_override("margin_right", CONTENT_SIDE_MARGIN)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 34)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(margin)

	var content := VBoxContainer.new()
	content.name = "CareerContent"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 14)
	margin.add_child(content)

	content.add_child(_make_header())
	content.add_child(_make_identity_panel())
	content.add_child(_make_collection_panel())
	content.add_child(_make_oldest_collection_panel())
	refresh_visual_style()

func _make_header() -> Control:
	var row := HBoxContainer.new()
	row.name = "CareerHeader"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	row.add_child(_make_texture_icon(
		"res://Resources/UI/Icons/Career/career_archive.png",
		"CareerHeaderIcon",
		maxf(HEADER_ICON_SIZE, _info_icon_size * 1.10)
	))
	var labels := VBoxContainer.new()
	var title := Label.new()
	title.name = "CareerTitle"
	title.text = Localization.t("ui.career.title")
	title.add_theme_font_size_override("font_size", 30)
	labels.add_child(title)
	var subtitle := Label.new()
	subtitle.name = "CareerSubtitle"
	subtitle.text = Localization.t("ui.career.subtitle")
	subtitle.add_theme_font_size_override("font_size", 15)
	labels.add_child(subtitle)
	row.add_child(labels)
	return row

func _make_identity_panel() -> Panel:
	var panel := _make_section_panel("CareerIdentityPanel")
	var box := _make_panel_vbox(panel)
	var player := GameManager.player_data
	box.add_child(_make_plain_row("CareerPlayerId", Localization.t("ui.career.id", [_format_integer(player.user_id)])))
	box.add_child(_make_plain_row("CareerCountry", Localization.t("ui.career.country", [_localized_country_name(player.country)])))
	var titles: Array = player.equipped_titles
	for index in range(3):
		var title_name := Localization.t("ui.career.title_empty")
		if index < titles.size() and titles[index] is Dictionary:
			title_name = str(titles[index].get("name", title_name))
		box.add_child(_make_plain_row(
			"CareerEquippedTitle%d" % (index + 1),
			Localization.t("ui.career.title_slot", [index + 1, title_name])
		))
	_finalize_panel_height(panel, box)
	return panel

func _make_collection_panel() -> Panel:
	var panel := _make_section_panel("CareerCollectionPanel")
	var box := _make_panel_vbox(panel)
	var player := GameManager.player_data
	box.add_child(_make_path_icon_row("CareerLevel", "res://Resources/UI/Icons/Career/career_level.png", Localization.t("ui.career.level", [_format_integer(player.level)])))
	box.add_child(_make_path_icon_row("CareerGold", "res://Resources/UI/Icons/Career/career_gold.png", Localization.t("ui.career.gold", [_format_integer(player.gold)])))
	box.add_child(_make_path_icon_row("CareerCombatPower", "res://Resources/UI/Icons/Career/career_combat_power.png", Localization.t("ui.career.combat_power", [_format_integer(player.combat_power)])))

	var active_decks := _active_decks()
	box.add_child(_make_path_icon_row("CareerRelicTotal", "res://Resources/UI/Icons/Career/career_relic_total.png", Localization.t("ui.career.relic_total", [_format_integer(active_decks.size())])))
	var total_kinds := _total_deck_definition_count()
	for color_type in range(CardColor.ColorType.size()):
		var stats := _color_collection_stats(active_decks, color_type)
		var relic_count := int(stats.get("count", 0))
		if relic_count <= 0:
			continue
		var kind_count := int(stats.get("kinds", 0))
		var percent := 0.0 if total_kinds <= 0 else float(kind_count) * 100.0 / float(total_kinds)
		var text := Localization.t("ui.career.color_progress", [
			CardColor.display_name(color_type),
			_format_integer(relic_count),
			_format_integer(kind_count),
			_format_integer(total_kinds),
			"%.1f" % percent,
		])
		box.add_child(_make_relic_progress_row(color_type, text))
	_finalize_panel_height(panel, box)
	return panel

func _make_oldest_collection_panel() -> Panel:
	var panel := _make_section_panel("CareerOldestPanel")
	var box := _make_panel_vbox(panel)
	var oldest := _oldest_active_deck()
	if oldest == null:
		box.add_child(_make_path_icon_row(
			"CareerOldestEmpty",
			"res://Resources/UI/Icons/Career/career_archive.png",
			Localization.t("ui.career.oldest_empty")
		))
		_finalize_panel_height(panel, box)
		return panel

	box.add_child(_make_path_icon_row(
		"CareerOldestName",
		"res://Resources/UI/Icons/Career/career_archive.png",
		Localization.t("ui.career.oldest_name", [oldest.deck_name])
	))
	box.add_child(_make_path_icon_row(
		"CareerOldestDate",
		"res://Resources/UI/Icons/Career/career_acquired_date.png",
		Localization.t("ui.career.acquired_on", [_format_acquired_date(oldest)])
	))
	box.add_child(_make_path_icon_row(
		"CareerOldestDays",
		"res://Resources/UI/Icons/Career/career_companion_time.png",
		Localization.t("ui.career.companion_days", [_format_integer(_companion_days(oldest))])
	))
	_finalize_panel_height(panel, box)
	return panel

func _make_section_panel(node_name: String) -> Panel:
	var panel := Panel.new()
	panel.name = node_name
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	CCRVisualStyle.apply_settings_content_panel(panel)
	return panel

func _make_panel_vbox(panel: Panel) -> VBoxContainer:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_top", 15)
	margin.add_theme_constant_override("margin_bottom", 15)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 7)
	margin.add_child(box)
	return box

func _finalize_panel_height(panel: Panel, box: VBoxContainer) -> void:
	var content_height := 30.0
	for child in box.get_children():
		content_height += (child as Control).custom_minimum_size.y
	content_height += maxf(0.0, float(box.get_child_count() - 1) * 7.0)
	panel.custom_minimum_size.y = content_height

func _make_plain_row(node_name: String, text: String) -> Label:
	var label := Label.new()
	label.name = node_name
	label.text = text
	label.custom_minimum_size.y = 34
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 19)
	return label

func _make_icon_row(node_name: String, icon_id: String, text: String) -> HBoxContainer:
	var row := _make_row(node_name)
	row.add_child(CCRVisualStyle.make_status_icon(icon_id, node_name + "Icon", _info_icon_size))
	row.add_child(_make_value_label(node_name + "Label", text))
	return row

func _make_path_icon_row(node_name: String, icon_path: String, text: String) -> HBoxContainer:
	var row := _make_row(node_name)
	row.add_child(_make_texture_icon(icon_path, node_name + "Icon", _info_icon_size))
	row.add_child(_make_value_label(node_name + "Label", text))
	return row

func _make_relic_progress_row(color_type: int, text: String) -> HBoxContainer:
	var row_name := "CareerColorProgress%d" % color_type
	var row := _make_row(row_name)
	row.add_child(_make_texture_icon(str(RELIC_ICON_PATHS.get(color_type, "")), row_name + "Icon", _info_icon_size))
	row.add_child(_make_value_label(row_name + "Label", text))
	return row

func _make_row(node_name: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = node_name
	row.custom_minimum_size.y = _info_icon_size + 4.0
	row.add_theme_constant_override("separation", 15)
	return row

func _make_value_label(node_name: String, text: String) -> Label:
	var label := Label.new()
	label.name = node_name
	label.text = text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 20)
	return label

func _make_texture_icon(path: String, node_name: String, icon_size: float) -> TextureRect:
	var icon := TextureRect.new()
	icon.name = node_name
	icon.custom_minimum_size = Vector2(icon_size, icon_size)
	icon.texture = load(path) as Texture2D if path != "" else null
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon

func refresh_visual_style() -> void:
	for label in find_children("*", "Label", true, false):
		var typed := label as Label
		if typed.name in ["CareerPlayerId", "CareerLevelLabel", "CareerCombatPowerLabel"]:
			typed.add_theme_color_override("font_color", Color.BLACK)
		elif typed.name == "CareerTitle":
			typed.add_theme_color_override("font_color", CCRVisualStyle.SETTINGS_TEXT_HOVER)
		elif typed.name == "CareerSubtitle":
			typed.add_theme_color_override("font_color", CCRVisualStyle.SETTINGS_TEXT_DISABLED)
		else:
			typed.add_theme_color_override("font_color", CCRVisualStyle.SETTINGS_TEXT)
		typed.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
		typed.add_theme_constant_override("shadow_offset_x", 0)
		typed.add_theme_constant_override("shadow_offset_y", 1)

func _active_decks() -> Array[Deck]:
	var result: Array[Deck] = []
	for deck in DeckSystem.get_player_decks():
		if deck != null and deck.status == "active":
			result.append(deck)
	return result

func _color_collection_stats(decks: Array[Deck], color_type: int) -> Dictionary:
	var count := 0
	var kinds := {}
	for deck in decks:
		if int(deck.color) != color_type:
			continue
		count += 1
		var kind_key := str(deck.deck_def_id) if deck.deck_def_id > 0 else deck.series_name + "|" + deck.deck_name
		kinds[kind_key] = true
	return {"count": count, "kinds": kinds.size()}

func _total_deck_definition_count() -> int:
	var kinds := {}
	for card in CardDataManager.all_cards:
		if card == null:
			continue
		kinds[card.series_name_zh + "|" + card.deck_name_zh] = true
	return kinds.size()

func _oldest_active_deck() -> Deck:
	var oldest: Deck = null
	for deck in _active_decks():
		if oldest == null:
			oldest = deck
			continue
		if deck.created_at_unix > 0.0 and (oldest.created_at_unix <= 0.0 or deck.created_at_unix < oldest.created_at_unix):
			oldest = deck
	return oldest

func _format_acquired_date(deck: Deck) -> String:
	if deck.created_date_beijing != "":
		return _localized_date_from_iso(deck.created_date_beijing)
	if deck.created_at_unix <= 0.0:
		return Localization.t("ui.career.date_unknown")
	var beijing_datetime := Time.get_datetime_dict_from_unix_time(int(deck.created_at_unix) + 8 * 60 * 60)
	return _localized_date(int(beijing_datetime.year), int(beijing_datetime.month), int(beijing_datetime.day))

func _localized_date_from_iso(value: String) -> String:
	var parts := value.left(10).split("-")
	if parts.size() != 3:
		return value
	return _localized_date(int(parts[0]), int(parts[1]), int(parts[2]))

func _localized_date(year: int, month: int, day: int) -> String:
	if Localization.locale == "zh-CN" or Localization.locale == "zh-TW":
		return Localization.t("ui.career.date_zh", [year, month, day])
	return Localization.t("ui.career.date_iso", [year, month, day])

func _companion_days(deck: Deck) -> int:
	if deck.created_at_unix <= 0.0:
		return 0
	return maxi(0, int(floor((Time.get_unix_time_from_system() - deck.created_at_unix) / 86400.0)))

func _localized_country_name(code: String) -> String:
	for entry in CountryCatalog.localized_entries(Localization.locale):
		if str(entry.get("code", "")) == code:
			return str(entry.get("label", code))
	return code

func _format_integer(value: int) -> String:
	var negative := value < 0
	var digits := str(absi(value))
	var output := ""
	for index in range(digits.length()):
		if index > 0 and (digits.length() - index) % 3 == 0:
			output += ","
		output += digits[index]
	return ("-" if negative else "") + output
