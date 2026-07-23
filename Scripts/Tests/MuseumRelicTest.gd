extends Node

const ALL_RELIC_COLORS := [
	CardColor.ColorType.WHITE,
	CardColor.ColorType.GREEN,
	CardColor.ColorType.BLUE,
	CardColor.ColorType.PURPLE,
	CardColor.ColorType.ORANGE,
	CardColor.ColorType.BLACK,
	CardColor.ColorType.RED,
]
const ALL_RELIC_NAMES := ["white", "green", "blue", "purple", "orange", "black", "red"]
const THUMBNAIL_CACHE = preload("res://Scripts/UI/MuseumRelicThumbnailCache.gd")


func _ready() -> void:
	Localization.set_locale("zh-CN")
	DeckCollectionUI.reset_session_filter_state()
	GameManager.apply_draw_key({
		"date_key": "2026-07-13",
		"version": 1,
		"decks": [{
			"deck_def_id": 21,
			"deck_def_key": "solar_system__sun",
			"series_name": "Solar System",
			"deck_name": "Sun",
		}],
	})
	var cards_by_id: Array[CardInfo] = CardDataManager.get_cards_by_deck_id(1)
	if cards_by_id.size() != 5 or int(cards_by_id[0].id) != 1:
		return _fail("deck_id_lookup_wrong")
	for deck_def_id in range(1, 69):
		var deck_cards: Array[CardInfo] = CardDataManager.get_cards_by_deck_id(deck_def_id)
		var expected_first_card_id := (deck_def_id - 1) * 5 + 1
		if deck_cards.size() != 5 or int(deck_cards[0].id) != expected_first_card_id:
			return _fail("all_deck_id_lookup_wrong_%d" % deck_def_id)
	var solar_cards: Array[CardInfo] = CardDataManager.get_cards_by_deck_id(21)
	if solar_cards.size() != 5 or int(solar_cards[0].id) != 101:
		return _fail("global_deck_id_lookup_wrong")
	var cards_by_key: Array[CardInfo] = CardDataManager.get_cards_by_deck_key("solar_system__sun")
	if cards_by_key.size() != 5 or int(cards_by_key[0].id) != 101:
		return _fail("deck_key_lookup_wrong")
	var cards_by_name: Array[CardInfo] = CardDataManager.get_cards_by_deck("万象卡域", "AI意识")
	if cards_by_name.size() != 5:
		return _fail("deck_name_lookup_wrong")

	DeckSystem.player_decks.clear()
	for color_type in ALL_RELIC_COLORS:
		DeckSystem.add_synthesized_deck({
			"id": "museum-relic-test-%d" % color_type,
			"color": ALL_RELIC_NAMES[color_type],
			"deck_def": {
				"id": 21,
				"name": "solar_system__sun",
				"description": "Sun",
			},
			"series": {
				"id": 2,
				"name": "Solar System",
			},
		})
		var added_deck := DeckSystem.player_decks.back() as Deck
		if added_deck.deck_def_key != "solar_system__sun":
			return _fail("server_deck_key_missing_%d" % color_type)

	for color_type in [CardColor.ColorType.WHITE, CardColor.ColorType.GREEN]:
		DeckSystem.add_synthesized_deck({
			"id": "museum-earth-test-%d" % color_type,
			"color": ALL_RELIC_NAMES[color_type],
			"deck_def": {
				"id": 36,
				"name": "earth__asia",
				"description": "亚洲",
			},
			"series": {
				"id": 3,
				"name": "地球",
			},
		})

	var museum := DeckCollectionUI.new()
	# 最大正式分辨率下，中间区域 + 右侧区域的最小可用宽度。
	museum.size = Vector2(2168, 1416)
	add_child(museum)
	await get_tree().process_frame
	await get_tree().process_frame
	var color_filter := museum.find_child("MuseumColorFilter", true, false) as MenuButton
	if color_filter == null:
		return _fail("filter_color_missing")
	if color_filter.get_popup().get_item_count() != ALL_RELIC_COLORS.size():
		return _fail("filter_color_count_wrong")
	if color_filter.text != "稀有度：全部":
		return _fail("filter_rarity_label_wrong")
	if color_filter.get_popup().get_item_text(color_filter.get_popup().get_item_index(CardColor.ColorType.WHITE)) != "普通":
		return _fail("filter_white_name_not_tier")
	if color_filter.get_popup().get_item_text(color_filter.get_popup().get_item_index(CardColor.ColorType.RED)) != "宇宙":
		return _fail("filter_red_name_not_cosmic")
	var sort_option := museum.find_child("MuseumSortOption", true, false) as OptionButton
	if sort_option == null or sort_option.get_item_count() != 3:
		return _fail("filter_sort_missing")
	var series_option := museum.find_child("MuseumSeriesOption", true, false) as OptionButton
	if series_option == null or series_option.get_item_count() < 3:
		return _fail("filter_series_missing")
	if series_option.get_item_text(1) != "今日可见系列" or str(series_option.get_item_metadata(1)) != DeckCollectionUI.TODAY_VISIBLE_SERIES_FILTER:
		return _fail("today_visible_series_filter_missing")
	if str(series_option.get_item_metadata(series_option.selected)) != DeckCollectionUI.TODAY_VISIBLE_SERIES_FILTER:
		return _fail("today_visible_series_filter_not_default")
	var filter_bar := museum.find_child("MuseumFilterBar", true, false) as HBoxContainer
	if filter_bar == null or filter_bar.get_child_count() != DeckCollectionUI.RELICS_PER_ROW:
		return _fail("filter_bar_not_aligned_to_relic_columns")
	if sort_option.get_parent() != filter_bar.get_child(3):
		return _fail("sort_filter_not_in_fourth_column")
	if filter_bar.get_child(4).name != "MuseumFilterBarSpacer":
		return _fail("filter_bar_spacer_missing")
	var progress_label := museum.find_child("MuseumCollectionProgress", true, false) as Label
	var total_decks := _total_deck_defs()
	if progress_label == null or progress_label.text != "已收藏 7/7":
		return _fail("collection_progress_wrong")
	var relic_grid := museum.find_child("MuseumRelicGrid", true, false) as HFlowContainer
	var visible_relics := museum._apply_relic_filters(museum._aggregate_relics(DeckSystem.get_player_decks()))
	museum._sort_relic_list(visible_relics)
	var expected_first_row_count := museum._get_relics_that_fit_first_row(visible_relics)
	if relic_grid == null:
		return _fail("relic_flow_grid_missing")
	if expected_first_row_count <= DeckCollectionUI.RELICS_PER_ROW:
		return _fail("relic_grid_did_not_add_columns")
	if relic_grid.get_child_count() != ALL_RELIC_COLORS.size():
		return _fail("relic_grid_count_wrong")
	if relic_grid.get_child(0).name != "RelicCard%d" % CardColor.ColorType.RED:
		return _fail("standard_sort_does_not_put_rarest_first")

	var expected_scales := {
		CardColor.ColorType.WHITE: 1.0,
		CardColor.ColorType.GREEN: 1.12,
		CardColor.ColorType.BLUE: 1.26,
		CardColor.ColorType.PURPLE: 1.05,
		CardColor.ColorType.ORANGE: 0.92,
		CardColor.ColorType.BLACK: 0.92,
		CardColor.ColorType.RED: 1.08,
	}
	var relic_visible_bottom_by_row: Dictionary = {}
	for color_type in ALL_RELIC_COLORS:
		var relic_card := museum.find_child("RelicCard%d" % color_type, true, false) as Control
		if relic_card == null:
			return _fail("relic_card_missing_%d" % color_type)
		if absf(RelicView.get_display_scale(color_type) - float(expected_scales[color_type])) > 0.001:
			return _fail("relic_display_scale_wrong_%d" % color_type)
		var hover_frame := relic_card.find_child("RelicHoverFrame", true, false) as Panel
		if hover_frame == null:
			return _fail("relic_hover_frame_missing_%d" % color_type)
		var hit_area := relic_card.find_child("RelicHitArea", true, false) as ColorRect
		if hit_area == null:
			return _fail("relic_hit_area_missing_%d" % color_type)
		var label_box := relic_card.find_child("RelicCardLabels", true, false) as VBoxContainer
		if label_box == null:
			return _fail("relic_labels_missing_%d" % color_type)
		var series_label := relic_card.find_child("RelicCardSeries", true, false) as Label
		var name_label := relic_card.find_child("RelicCardName", true, false) as Label
		var count_label := relic_card.find_child("RelicCardCount", true, false) as Label
		if series_label == null or series_label.text != "Solar System":
			return _fail("relic_series_label_wrong_%d" % color_type)
		if name_label == null or name_label.text != "Sun":
			return _fail("relic_name_label_wrong_%d" % color_type)
		if count_label == null or count_label.text == "":
			return _fail("relic_count_label_missing_%d" % color_type)
		var relic_host := relic_card.find_child("RelicHost", true, false) as Control
		if relic_host == null:
			return _fail("relic_host_missing_%d" % color_type)
		var box := relic_card.find_child("RelicCardBox", true, false) as VBoxContainer
		if box == null or label_box.get_parent() != box or relic_host.get_parent() != box:
			return _fail("relic_box_order_parent_wrong_%d" % color_type)
		if label_box.get_index() <= relic_host.get_index():
			return _fail("relic_labels_not_below_relic_%d" % color_type)
		var relic_shadow := relic_card.find_child("RelicThumbnailShadow", true, false) as TextureRect
		if relic_shadow == null:
			return _fail("relic_shadow_missing_%d" % color_type)
		var expected_relic_size := museum._get_visual_relic_size(color_type)
		if absf(relic_host.custom_minimum_size.y - museum._get_visual_relic_slot_height()) > 1.0:
			return _fail("relic_host_height_wrong_%d" % color_type)
		if absf(relic_host.custom_minimum_size.x - expected_relic_size.x) > 1.0:
			return _fail("relic_width_wrong_%d" % color_type)
		var thumbnail := relic_card.find_child("RelicThumbnail", true, false) as TextureRect
		if thumbnail == null or thumbnail.texture == null:
			return _fail("relic_thumbnail_missing_%d" % color_type)
		if thumbnail.size.distance_to(expected_relic_size) > 1.0:
			return _fail("relic_thumbnail_size_wrong_%d" % color_type)
		var visible_bottom_y := thumbnail.global_position.y + RelicView.get_visible_bottom_ratio(color_type) * thumbnail.size.y
		var row_key := roundi(relic_card.global_position.y)
		if not relic_visible_bottom_by_row.has(row_key):
			relic_visible_bottom_by_row[row_key] = visible_bottom_y
		elif absf(visible_bottom_y - float(relic_visible_bottom_by_row[row_key])) > 1.0:
			return _fail("relic_visible_bottom_not_aligned_%d" % color_type)
		if relic_shadow.texture == null or relic_shadow.texture != thumbnail.texture:
			return _fail("relic_shadow_texture_wrong_%d" % color_type)
		var cache_path: String = THUMBNAIL_CACHE.get_cache_path(color_type, "solar_system__sun", 21)
		if not FileAccess.file_exists(cache_path):
			return _fail("relic_thumbnail_cache_missing_%d" % color_type)
		var fallback_relic_view := relic_card.find_child("RelicView", true, false) as RelicView
		if fallback_relic_view != null:
			return _fail("relic_thumbnail_fallback_used_%d" % color_type)

	for index in range(expected_first_row_count):
		var relic := relic_grid.get_child(index) as Control
		if relic == null:
			return _fail("relic_grid_first_row_missing_%d" % index)
		if absf(relic.global_position.y - relic_grid.get_child(0).global_position.y) > 1.0:
			return _fail("relic_grid_not_max_items_on_first_row")
	if expected_first_row_count < relic_grid.get_child_count():
		var next_relic := relic_grid.get_child(expected_first_row_count) as Control
		if next_relic != null and absf(next_relic.global_position.y - relic_grid.get_child(0).global_position.y) <= 1.0:
			return _fail("relic_grid_first_row_left_unused_space")

	var first_relic := museum.find_child("RelicCard0", true, false) as Control
	var first_thumb := first_relic.find_child("RelicThumbnail", true, false) as TextureRect
	var test_relic := {
		"deck_def_key": "solar_system__sun",
		"deck_def_id": 21,
		"series_name": "Solar System",
		"deck_name": "Sun",
		"color": CardColor.ColorType.WHITE,
		"count": 1,
	}
	Localization.set_locale("en")
	museum._start_relic_view(test_relic, first_thumb, first_relic)
	await get_tree().create_timer(0.55).timeout
	if museum._view_state != museum.ViewState.RELIC_CENTERED:
		return _fail("view_relic_not_centered")
	if museum._view_blur == null or not museum._view_blur.visible:
		return _fail("view_blur_missing")
	if museum._view_relic_shadow == null:
		return _fail("view_relic_shadow_missing")
	if not first_relic.visible:
		return _fail("source_relic_layout_not_reserved")
	if first_relic.modulate.a > 0.01:
		return _fail("source_relic_not_transparent")
	museum.render_decks()
	await get_tree().process_frame
	await get_tree().process_frame
	first_relic = museum.find_child("RelicCard0", true, false) as Control
	if first_relic == null or first_relic.modulate.a > 0.01:
		return _fail("source_relic_restored_during_view_rerender")
	museum._advance_relic_view()
	await get_tree().create_timer(1.35).timeout
	if museum._view_state != museum.ViewState.CARDS_VISIBLE or museum._view_card_displays.size() != 5:
		return _fail("view_cards_not_visible")
	for i in range(5):
		var display := museum._view_card_displays[i] as CardDisplay
		if display == null or display.card == null or int(display.card.card_number) != i + 1:
			return _fail("view_card_order_wrong")
		if not display.hover_scale_enabled:
			return _fail("view_card_hover_scale_disabled")
		if absf(display.normal_visual_scale - 0.5) > 0.001 or absf(display.hover_visual_scale - 1.0) > 0.001:
			return _fail("view_card_not_supersampled_for_clear_text")
		if display.scale.distance_to(Vector2(display.normal_visual_scale, display.normal_visual_scale)) > 0.02:
			return _fail("view_card_resting_scale_wrong")
		if display.card.series_name != "Solar System" or display.card.deck_name != "Sun":
			return _fail("view_card_locale_not_english_%d" % i)
		if i == 0 and (display.card.card_name != "Dawn's First Light" or not display.card.description.begins_with("The first ray of sunlight")):
			return _fail("view_card_text_not_english")
	var hovered_display := museum._view_card_displays[2] as CardDisplay
	hovered_display._on_mouse_entered()
	await get_tree().create_timer(CardDisplay.HOVER_TRANSITION_DURATION * 0.5).timeout
	var previous_hover_z := hovered_display.z_index
	var next_hovered_display := museum._view_card_displays[3] as CardDisplay
	next_hovered_display._on_mouse_entered()
	hovered_display._on_mouse_exited()
	await get_tree().process_frame
	if next_hovered_display.z_index <= previous_hover_z or next_hovered_display.z_index <= hovered_display.z_index:
		return _fail("view_card_new_hover_not_on_top")
	await get_tree().create_timer(CardDisplay.HOVER_TRANSITION_DURATION + 0.05).timeout
	if next_hovered_display.scale.distance_to(Vector2.ONE) > 0.02:
		return _fail("view_card_hover_not_doubled")
	next_hovered_display._on_mouse_exited()
	await get_tree().create_timer(CardDisplay.HOVER_TRANSITION_DURATION + 0.05).timeout
	if next_hovered_display.scale.distance_to(Vector2(next_hovered_display.normal_visual_scale, next_hovered_display.normal_visual_scale)) > 0.02:
		return _fail("view_card_hover_not_restored")
	Localization.set_locale("zh-CN")
	museum._advance_relic_view()
	await get_tree().create_timer(1.35).timeout
	if museum._view_state != museum.ViewState.CARDS_HIDDEN or not museum._view_card_displays.is_empty():
		return _fail("view_cards_not_hidden")
	museum._advance_relic_view()
	await get_tree().create_timer(0.55).timeout
	if museum._view_state != museum.ViewState.NONE or museum._view_overlay != null:
		return _fail("view_not_closed")
	first_relic = museum.find_child("RelicCard0", true, false) as Control
	if first_relic == null:
		return _fail("source_relic_missing_after_view_closed")
	if first_relic.modulate.a < 0.99:
		return _fail("source_relic_not_restored")

	museum._selected_colors[CardColor.ColorType.WHITE] = false
	museum.render_decks()
	await get_tree().process_frame
	var filtered_white := museum.find_child("RelicCard0", true, false) as Control
	if filtered_white != null:
		return _fail("filter_color_white_visible")
	progress_label = museum.find_child("MuseumCollectionProgress", true, false) as Label
	if progress_label == null or progress_label.text != "已收藏 6/6":
		return _fail("filtered_collection_progress_wrong")
	museum._selected_colors[CardColor.ColorType.WHITE] = true
	museum._sort_mode = "standard"
	var sorted_relics := museum._aggregate_relics(DeckSystem.get_player_decks())
	museum._sort_relic_list(sorted_relics)
	if sorted_relics.is_empty() or int(sorted_relics[0].get("color", -1)) != CardColor.ColorType.RED or int(sorted_relics[0].get("deck_def_id", 0)) != 21:
		return _fail("filter_standard_sort_wrong")
	var standard_synthetic_relics: Array[Dictionary] = [
		{"deck_def_id": 36, "series_name": "地球", "deck_name": "亚洲", "color": CardColor.ColorType.WHITE, "first_index": 0, "last_index": 0},
		{"deck_def_id": 22, "series_name": "太阳系", "deck_name": "水星", "color": CardColor.ColorType.PURPLE, "first_index": 1, "last_index": 1},
		{"deck_def_id": 21, "series_name": "太阳系", "deck_name": "太阳", "color": CardColor.ColorType.PURPLE, "first_index": 2, "last_index": 2},
		{"deck_def_id": 1, "series_name": "万象卡域", "deck_name": "AI意识", "color": CardColor.ColorType.BLUE, "first_index": 3, "last_index": 3},
	]
	museum._sort_relic_list(standard_synthetic_relics)
	if int(standard_synthetic_relics[0].get("deck_def_id", 0)) != 21 or int(standard_synthetic_relics[1].get("deck_def_id", 0)) != 22 or int(standard_synthetic_relics[2].get("color", -1)) != CardColor.ColorType.BLUE:
		return _fail("standard_sort_rarity_series_deck_order_wrong")
	var synthetic_relics: Array[Dictionary] = [
		{"deck_def_id": 1, "series_name": "S", "deck_name": "new", "first_index": 0, "last_index": 0},
		{"deck_def_id": 2, "series_name": "S", "deck_name": "old", "first_index": 3, "last_index": 5},
	]
	museum._sort_mode = "recent"
	museum._sort_relic_list(synthetic_relics)
	if int(synthetic_relics[0].get("deck_def_id", 0)) != 1:
		return _fail("recent_sort_reversed")
	museum._sort_mode = "oldest"
	museum._sort_relic_list(synthetic_relics)
	if int(synthetic_relics[0].get("deck_def_id", 0)) != 2:
		return _fail("oldest_sort_reversed")

	museum._selected_series = DeckCollectionUI.TODAY_VISIBLE_SERIES_FILTER
	museum.render_decks()
	await get_tree().process_frame
	var today_grid := museum.find_child("MuseumRelicGrid", true, false) as HFlowContainer
	progress_label = museum.find_child("MuseumCollectionProgress", true, false) as Label
	if today_grid == null or today_grid.get_child_count() != ALL_RELIC_COLORS.size():
		return _fail("today_visible_filter_did_not_keep_draw_key_relics")
	if progress_label == null or progress_label.text != "已收藏 7/7":
		return _fail("today_visible_filter_progress_wrong")

	museum._selected_series = "地球"
	museum.render_decks()
	await get_tree().process_frame
	color_filter = museum.find_child("MuseumColorFilter", true, false) as MenuButton
	if color_filter == null:
		return _fail("series_rarity_filter_missing")
	if color_filter.get_popup().get_item_count() != 2:
		return _fail("series_rarity_filter_count_wrong")
	if color_filter.get_popup().get_item_index(CardColor.ColorType.WHITE) < 0 or color_filter.get_popup().get_item_index(CardColor.ColorType.GREEN) < 0:
		return _fail("series_rarity_filter_missing_owned_rarity")
	if color_filter.get_popup().get_item_index(CardColor.ColorType.BLUE) >= 0:
		return _fail("series_rarity_filter_kept_unowned_rarity")
	museum._selected_series = DeckCollectionUI.TODAY_VISIBLE_SERIES_FILTER
	museum.render_decks()
	await get_tree().process_frame

	museum._on_color_filter_pressed(CardColor.ColorType.WHITE)
	sort_option = museum.find_child("MuseumSortOption", true, false) as OptionButton
	if sort_option == null:
		return _fail("session_sort_option_missing")
	sort_option.select(0)
	museum._on_sort_selected(0)
	series_option = museum.find_child("MuseumSeriesOption", true, false) as OptionButton
	if series_option == null:
		return _fail("session_series_option_missing")
	series_option.select(1)
	museum._on_series_selected(1)
	await get_tree().process_frame
	museum.queue_free()
	await get_tree().process_frame

	var restored_museum := DeckCollectionUI.new()
	restored_museum.size = Vector2(2168, 1416)
	add_child(restored_museum)
	await get_tree().process_frame
	await get_tree().process_frame
	if bool(restored_museum._selected_colors.get(CardColor.ColorType.WHITE, true)):
		return _fail("session_color_filter_not_restored")
	if restored_museum._selected_series != DeckCollectionUI.TODAY_VISIBLE_SERIES_FILTER:
		return _fail("session_series_filter_not_restored")
	if restored_museum._sort_mode != "recent":
		return _fail("session_sort_filter_not_restored")
	var restored_sort := restored_museum.find_child("MuseumSortOption", true, false) as OptionButton
	if restored_sort == null or str(restored_sort.get_item_metadata(restored_sort.selected)) != "recent":
		return _fail("session_sort_ui_not_restored")
	var restored_series := restored_museum.find_child("MuseumSeriesOption", true, false) as OptionButton
	if restored_series == null or str(restored_series.get_item_metadata(restored_series.selected)) != DeckCollectionUI.TODAY_VISIBLE_SERIES_FILTER:
		return _fail("session_series_ui_not_restored")
	var restored_grid := restored_museum.find_child("MuseumRelicGrid", true, false) as HFlowContainer
	if restored_grid == null or restored_grid.get_child_count() != ALL_RELIC_COLORS.size() - 1:
		return _fail("session_filtered_grid_not_restored")
	progress_label = restored_museum.find_child("MuseumCollectionProgress", true, false) as Label
	if progress_label == null or progress_label.text != "已收藏 6/6":
		return _fail("session_progress_not_restored")
	DeckCollectionUI.reset_session_filter_state()

	print("MUSEUM_RELIC ok colors=7 first_row=%d thumbnails=true view=true today_filter=true session_filter=true hover_2x=true" % expected_first_row_count)
	get_tree().quit(0)


func _fail(reason: String) -> void:
	push_error("MUSEUM_RELIC " + reason)
	get_tree().quit(1)

func _total_deck_defs() -> int:
	var total := 0
	for series in CardDataManager.get_all_series():
		if series is CardSeries:
			total += (series as CardSeries).get_deck_names().size()
	return total
