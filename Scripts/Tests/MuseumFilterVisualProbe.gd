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


func _ready() -> void:
	get_viewport().gui_embed_subwindows = true
	ApiClient.logout()
	Localization.set_locale("zh-CN")
	DeckCollectionUI.reset_session_filter_state()
	_setup_museum_data()

	var main := MainUI.new()
	main.size = get_viewport().get_visible_rect().size
	add_child(main)
	await _wait_frames(2)
	for child in main.get_children():
		if child.has_method("_selected_country_code"):
			child.hide()
			break

	main.call("_set_game_ui_visible", true)
	var nav_buttons: NavButtons = main.get("_nav_buttons")
	if nav_buttons == null:
		return _fail("navigation is missing")
	nav_buttons.nav_button_clicked.emit("deck_panel")
	await _wait_frames(5)

	var museum := main.get("_deck_collection_ui") as DeckCollectionUI
	var currency := main.get("_currency") as CurrencyUI
	var series_option := museum.find_child("MuseumSeriesOption", true, false) as OptionButton if museum != null else null
	var progress := museum.find_child("MuseumCollectionProgress", true, false) as LineEdit if museum != null else null
	var sort_option := museum.find_child("MuseumSortOption", true, false) as OptionButton if museum != null else null
	if museum == null or currency == null or series_option == null or progress == null or sort_option == null:
		return _fail("museum controls are missing")

	_print_metrics("wide_closed", museum, currency, progress, series_option, sort_option)
	if currency.visible:
		return _fail("currency is still visible while wide filters overlap it")
	if not await _capture("CCR_MUSEUM_FILTER_WIDE_SCREENSHOT_PATH"):
		return

	series_option.show_popup()
	await _wait_frames(3)
	_print_popup_metrics(series_option)
	if not await _capture("CCR_MUSEUM_FILTER_POPUP_SCREENSHOT_PATH"):
		return
	series_option.get_popup().hide()

	_select_series(series_option, "地球")
	await _wait_frames(5)
	_print_metrics("narrow_closed", museum, currency, progress, series_option, sort_option)
	if not currency.visible:
		return _fail("currency did not return after filters became narrow")
	if not await _capture("CCR_MUSEUM_FILTER_NARROW_SCREENSHOT_PATH"):
		return

	print("MUSEUM_FILTER_VISUAL_PROBE ok")
	get_tree().quit(0)


func _setup_museum_data() -> void:
	GameManager.player_data.gold = 123456
	GameManager.player_data.gems = 789
	GameManager.newbie_free_refresh_count = 0
	GameManager.free_refresh_count = 42
	GameManager.player_data.level = 50
	GameManager.apply_draw_key({
		"date_key": "2026-07-27",
		"version": 1,
		"decks": [{
			"deck_def_id": 21,
			"deck_def_key": "solar_system__sun",
			"series_name": "Solar System",
			"deck_name": "Sun",
		}],
	})
	DeckSystem.player_decks.clear()
	for color_type in ALL_RELIC_COLORS:
		DeckSystem.add_synthesized_deck({
			"id": "museum-filter-probe-solar-%d" % color_type,
			"color": ALL_RELIC_NAMES[color_type],
			"deck_def": {"id": 21, "name": "solar_system__sun", "description": "Sun"},
			"series": {"id": 2, "name": "Solar System"},
		})
	for color_type in [CardColor.ColorType.WHITE, CardColor.ColorType.GREEN]:
		DeckSystem.add_synthesized_deck({
			"id": "museum-filter-probe-earth-%d" % color_type,
			"color": ALL_RELIC_NAMES[color_type],
			"deck_def": {"id": 36, "name": "earth__asia", "description": "亚洲"},
			"series": {"id": 3, "name": "地球"},
		})


func _select_series(series_option: OptionButton, metadata: String) -> void:
	for index in range(series_option.item_count):
		if str(series_option.get_item_metadata(index)) == metadata:
			series_option.select(index)
			series_option.item_selected.emit(index)
			return
	_fail("series option is missing: " + metadata)


func _print_metrics(tag: String, museum: DeckCollectionUI, currency: CurrencyUI, progress: LineEdit, series_option: OptionButton, sort_option: OptionButton) -> void:
	var rarity_filter := museum.find_child("MuseumColorFilter", true, false) as HBoxContainer
	var controls_rect: Rect2 = museum.get_filter_controls_global_rect() if museum.has_method("get_filter_controls_global_rect") else Rect2(progress.get_global_rect().position, sort_option.get_global_rect().end - progress.get_global_rect().position)
	print("MUSEUM_FILTER_METRICS tag=%s progress=%s series=%s rarity=%s sort=%s controls=%s currency=%s currency_visible=%s" % [
		tag,
		progress.get_global_rect(),
		series_option.get_global_rect(),
		rarity_filter.get_global_rect() if rarity_filter != null else Rect2(),
		sort_option.get_global_rect(),
		controls_rect,
		currency.get_global_rect(),
		str(currency.visible),
	])


func _print_popup_metrics(option: OptionButton) -> void:
	var popup := option.get_popup()
	print("MUSEUM_FILTER_POPUP_METRICS body=%s popup_position=%s popup_size=%s body_divider_ratio=%.6f popup_divider_x=%s" % [
		option.get_global_rect(),
		popup.position,
		popup.size,
		float(CCRVisualStyle.SETTINGS_POPUP_DIVIDER_END_X) / float(CCRVisualStyle.SETTINGS_DROPDOWN_SIZE.x),
		str(popup.get_meta("ccr_settings_popup_divider_x", -1)),
	])


func _capture(environment_key: String) -> bool:
	await RenderingServer.frame_post_draw
	var screenshot_path := OS.get_environment(environment_key)
	if screenshot_path == "":
		return true
	var screenshot := get_viewport().get_texture().get_image()
	if screenshot == null or screenshot.is_empty() or screenshot.save_png(screenshot_path) != OK:
		_fail("screenshot could not be saved: " + environment_key)
		return false
	return true


func _wait_frames(count: int) -> void:
	for _index in range(count):
		await get_tree().process_frame


func _fail(message: String) -> void:
	push_error("MUSEUM_FILTER_VISUAL_PROBE " + message)
	get_tree().quit(1)
