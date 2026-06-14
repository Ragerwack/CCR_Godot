extends Node

const FAIL_TIMEOUT_MS: int = 4000

var _done: bool = false
var _last_pool: Array = []

func _ready() -> void:
	var api_base := OS.get_environment("CCR_DRAW_LEGACY_API_BASE")
	if api_base.strip_edges() == "":
		push_error("DRAW_LEGACY_FALLBACK missing CCR_DRAW_LEGACY_API_BASE")
		get_tree().quit(1)
		return

	_setup_state()
	ApiClient.set_api_base_url(api_base, false)

	CardPoolSystem.pool_updated.connect(_on_pool_updated)
	CardPoolSystem.loading_completed.connect(_on_loading_completed, CONNECT_ONE_SHOT)

	if not CardPoolSystem.do_refresh("gold"):
		push_error("DRAW_LEGACY_FALLBACK local_cost_check_failed")
		get_tree().quit(1)
		return

	CardPoolSystem.refresh_pool("gold")

	var timeout_started := Time.get_ticks_msec()
	while not _done and Time.get_ticks_msec() - timeout_started < FAIL_TIMEOUT_MS:
		await get_tree().process_frame

	if not _done:
		push_error("DRAW_LEGACY_FALLBACK timeout_ms=%d" % FAIL_TIMEOUT_MS)
		get_tree().quit(1)

func _setup_state() -> void:
	GameManager.player_data.user_id = 1
	GameManager.player_data.level = 1
	GameManager.player_data.pool_slots = 8
	GameManager.player_data.hand_slots = 8
	GameManager.player_data.gold = 1000
	GameManager.player_data.gems = 50
	GameManager.free_refresh_count = 1
	GameManager.newbie_free_refresh_count = 0
	GameManager.draw_key = {}
	GameManager.draw_key_version = 0
	GameManager.player_data.hand_cards = []
	GameManager.player_data.pool_cards = []
	CardPoolSystem.current_pool = []
	CardPoolSystem._warm_rolls.clear()
	CardPoolSystem._warming_types.clear()
	CardPoolSystem._warming_types["free"] = true
	for _i in range(8):
		GameManager.player_data.hand_cards.append(null)
		GameManager.player_data.pool_cards.append(null)
		CardPoolSystem.current_pool.append(null)

func _on_pool_updated(cards: Array) -> void:
	_last_pool = cards.duplicate()

func _on_loading_completed() -> void:
	_done = true
	var occupied := 0
	for card in _last_pool:
		if card != null:
			occupied += 1

	print("DRAW_LEGACY_FALLBACK occupied=%d gold=%d" % [occupied, GameManager.player_data.gold])
	if occupied == 8 and GameManager.player_data.gold == 990:
		get_tree().quit(0)
	else:
		get_tree().quit(1)
