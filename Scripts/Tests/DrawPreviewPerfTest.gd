extends Node

const TARGET_MS: int = 500
const FAIL_TIMEOUT_MS: int = 2000

var _started_ms: int = 0
var _preview_elapsed_ms: int = -1
var _done: bool = false
var _use_http_warm: bool = false

func _ready() -> void:
	_setup_state()
	_use_http_warm = OS.get_environment("CCR_DRAW_PERF_USE_HTTP") == "1"
	var api_base := OS.get_environment("CCR_DRAW_PERF_API_BASE")
	if api_base.strip_edges() != "":
		ApiClient.set_api_base_url(api_base, false)

	var ui := CardPoolUI.new()
	ui.name = "DrawPreviewPerfCardPoolUI"
	ui.auto_warm_enabled = false
	add_child(ui)
	await get_tree().process_frame
	await get_tree().process_frame

	CardPoolSystem.pool_updated.connect(_on_pool_updated, CONNECT_ONE_SHOT)
	if _use_http_warm:
		CardPoolSystem.skip_confirm_after_preview_for_test = false
		CardPoolSystem.loading_completed.connect(_on_loading_completed, CONNECT_ONE_SHOT)
		CardPoolSystem.warm_refresh_roll("free")
		var warm_started := Time.get_ticks_msec()
		while CardPoolSystem._get_warm_roll("free").is_empty() and Time.get_ticks_msec() - warm_started < FAIL_TIMEOUT_MS:
			await get_tree().process_frame
		if CardPoolSystem._get_warm_roll("free").is_empty():
			push_error("DRAW_PREVIEW_PERF warm_timeout_ms=%d" % FAIL_TIMEOUT_MS)
			get_tree().quit(1)
			return
	else:
		CardPoolSystem.skip_confirm_after_preview_for_test = true
		CardPoolSystem._store_warm_roll("free", _mock_roll())

	_started_ms = Time.get_ticks_msec()
	CardPoolSystem.refresh_pool("free")

	var timeout_started := Time.get_ticks_msec()
	while not _done and Time.get_ticks_msec() - timeout_started < FAIL_TIMEOUT_MS:
		await get_tree().process_frame

	if not _done:
		push_error("DRAW_PREVIEW_PERF timeout_ms=%d" % FAIL_TIMEOUT_MS)
		get_tree().quit(1)

func _setup_state() -> void:
	GameManager.player_data.level = 3
	GameManager.player_data.pool_slots = 9
	GameManager.player_data.hand_slots = 9
	GameManager.player_data.gold = 1000
	GameManager.player_data.gems = 50
	GameManager.free_refresh_count = 1
	GameManager.newbie_free_refresh_count = 0
	GameManager.draw_key_version = 1
	GameManager.player_data.hand_cards = []
	GameManager.player_data.pool_cards = []
	CardPoolSystem.current_pool = []
	for _i in range(9):
		GameManager.player_data.hand_cards.append(null)
		GameManager.player_data.pool_cards.append(null)
		CardPoolSystem.current_pool.append(null)

func _on_pool_updated(cards: Array) -> void:
	var elapsed_ms := Time.get_ticks_msec() - _started_ms
	_preview_elapsed_ms = elapsed_ms
	var occupied := 0
	for card in cards:
		if card != null:
			occupied += 1
	print("DRAW_PREVIEW_PERF total_ms=%d target_ms=%d occupied=%d" % [elapsed_ms, TARGET_MS, occupied])
	if _use_http_warm:
		if elapsed_ms > TARGET_MS or occupied != 9:
			_done = true
			get_tree().quit(1)
		return

	_done = true
	if elapsed_ms <= TARGET_MS and occupied == 9:
		get_tree().quit(0)
	else:
		get_tree().quit(1)

func _on_loading_completed() -> void:
	if _done:
		return
	_done = true
	if _preview_elapsed_ms >= 0 and _preview_elapsed_ms <= TARGET_MS:
		get_tree().quit(0)
	else:
		get_tree().quit(1)

func _mock_roll() -> Dictionary:
	var matrix: Array = []
	for i in range(16):
		var deck_roll := 0.20 if i % 2 == 0 else 0.70
		var number_roll := float(i % 5) / 5.0 + 0.01
		var color_roll := 0.01
		matrix.append([deck_roll, number_roll, color_roll])

	return {
		"key_stale": false,
		"roll_id": "00000000-0000-4000-8000-000000000001",
		"signature": "0123456789abcdef0123456789abcdef",
		"random_matrix": matrix,
		"draw_key": {
			"date_key": "2026-06-10",
			"version": 1,
			"decks": [
				_mock_deck(1, "性能测试一"),
				_mock_deck(2, "性能测试二"),
			],
			"number_probabilities": {
				"1": 0.3,
				"2": 0.25,
				"3": 0.2,
				"4": 0.15,
				"5": 0.1,
			},
			"color_probabilities": {
				"white": 1.0,
				"green": 0.0,
				"blue": 0.0,
				"purple": 0.0,
				"orange": 0.0,
				"black": 0.0,
			},
		},
		"expires_at": "2026-06-10T00:00:00.000Z",
	}

func _mock_deck(deck_id: int, deck_name: String) -> Dictionary:
	var cards: Array = []
	for number in range(1, 6):
		var card_id := deck_id * 100 + number
		cards.append({
			"card_def_id": card_id,
			"number": number,
			"name": "测试子卡%d" % number,
			"description": "用于客户端抽卡预览性能验证。",
			"image_url": "",
		})
	return {
		"deck_def_id": deck_id,
		"deck_name": deck_name,
		"series_name": "性能测试系列",
		"cards": cards,
	}
