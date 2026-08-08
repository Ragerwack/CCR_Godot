extends Node

func _ready() -> void:
	ApiClient.logout()
	Localization.set_locale("zh-CN")
	_setup_today_decks()
	_setup_vault()

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

	nav_buttons.nav_button_clicked.emit("today_decks")
	await _wait_frames(4)
	if not await _capture("CCR_TODAY_DECK_SCROLLBAR_SCREENSHOT_PATH"):
		return
	var today_scroll := main.find_child("TodayDeckScroll", true, false) as ScrollContainer
	if today_scroll == null:
		return _fail("today deck scroll container is missing")
	today_scroll.scroll_vertical = int(ceil(today_scroll.get_v_scroll_bar().max_value))
	await _wait_frames(3)
	if not await _capture("CCR_TODAY_DECK_BOTTOM_SCROLLBAR_SCREENSHOT_PATH"):
		return

	nav_buttons.nav_button_clicked.emit("vault")
	await _wait_frames(5)
	if not await _capture("CCR_VAULT_SCROLLBAR_SCREENSHOT_PATH"):
		return

	print("PAGE_VERTICAL_SCROLLBAR_VISUAL_PROBE ok")
	get_tree().quit(0)

func _setup_today_decks() -> void:
	var decks: Array = []
	for deck_index in range(8):
		var cards: Array = []
		for number in range(1, 6):
			var card_id := deck_index * 5 + number
			cards.append({
				"card_def_id": card_id,
				"number": number,
				"name": "子卡%d" % number,
				"description": "垂直滚动条视觉探针",
				"image_url": "/images/cards/card_%03d.jpg" % card_id,
			})
		decks.append({
			"deck_def_id": deck_index + 1,
			"deck_def_key": "scrollbar_probe_%d" % deck_index,
			"series_name": "万象测试系列",
			"deck_name": "今日卡组%d" % (deck_index + 1),
			"relic_caps": {},
			"cards": cards,
		})
	GameManager.apply_draw_key({"date_key": "2026-07-26", "version": 1, "decks": decks})

func _setup_vault() -> void:
	GameManager.player_data.gold = 1000
	GameManager.player_data.gems = 1000
	GameManager.player_data.vault_slots = 80
	GameManager.vault_slot_quote = {
		"next_slot_index": 80,
		"costs": {"gold": 20, "gem": 10},
	}
	GameManager.vault_raw_slot_data = []
	GameManager.player_data.vault_cards = []
	for index in range(80):
		GameManager.vault_raw_slot_data.append({"slot_index": index, "unlocked": true})
		GameManager.player_data.vault_cards.append(CardInfo.new({
			"id": "scrollbar-probe-card-%d" % index,
			"series_name": "万象测试系列",
			"deck_name": "保险箱卡组",
			"card_number": index % 5 + 1,
			"color": "white",
			"card_name": "测试卡%d" % (index + 1),
			"description": "保险箱滚动条视觉探针",
		}))

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
	push_error("PAGE_VERTICAL_SCROLLBAR_VISUAL_PROBE " + message)
	get_tree().quit(1)
