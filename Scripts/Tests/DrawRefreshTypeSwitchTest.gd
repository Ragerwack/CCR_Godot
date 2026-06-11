extends Node

const FAIL_TIMEOUT_MS: int = 4000

var _done: bool = false
var _last_pool: Array = []

func _ready() -> void:
	var api_base := OS.get_environment("CCR_DRAW_TYPE_SWITCH_API_BASE")
	if api_base.strip_edges() == "":
		push_error("DRAW_TYPE_SWITCH missing CCR_DRAW_TYPE_SWITCH_API_BASE")
		get_tree().quit(1)
		return

	_setup_state()
	ApiClient.set_api_base_url(api_base, false)

	CardPoolSystem.warm_refresh_roll("free")
	await get_tree().process_frame
	CardPoolSystem.warm_refresh_roll("gem")
	var gem_warmed := await _wait_for_warm_roll("gem")
	if not gem_warmed:
		push_error("DRAW_TYPE_SWITCH gem_warm_timeout")
		get_tree().quit(1)
		return

	if not CardPoolSystem._get_warm_roll("free").is_empty():
		push_error("DRAW_TYPE_SWITCH stale_free_roll_not_cleared")
		get_tree().quit(1)
		return

	CardPoolSystem.pool_updated.connect(_on_pool_updated)
	CardPoolSystem.loading_completed.connect(_on_loading_completed, CONNECT_ONE_SHOT)
	if not CardPoolSystem.do_refresh("gem"):
		push_error("DRAW_TYPE_SWITCH local_gem_cost_check_failed")
		get_tree().quit(1)
		return
	CardPoolSystem.refresh_pool("gem")

	var timeout_started := Time.get_ticks_msec()
	while not _done and Time.get_ticks_msec() - timeout_started < FAIL_TIMEOUT_MS:
		await get_tree().process_frame

	if not _done:
		push_error("DRAW_TYPE_SWITCH refresh_timeout")
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
	GameManager.draw_key_version = 1
	GameManager.player_data.hand_cards = []
	GameManager.player_data.pool_cards = []
	CardPoolSystem.current_pool = []
	CardPoolSystem._warm_rolls.clear()
	CardPoolSystem._warming_types.clear()
	for _i in range(8):
		GameManager.player_data.hand_cards.append(null)
		GameManager.player_data.pool_cards.append(null)
		CardPoolSystem.current_pool.append(null)

func _wait_for_warm_roll(refresh_type: String) -> bool:
	var started := Time.get_ticks_msec()
	while CardPoolSystem._get_warm_roll(refresh_type).is_empty() and Time.get_ticks_msec() - started < FAIL_TIMEOUT_MS:
		await get_tree().process_frame
	return not CardPoolSystem._get_warm_roll(refresh_type).is_empty()

func _on_pool_updated(cards: Array) -> void:
	_last_pool = cards.duplicate()

func _on_loading_completed() -> void:
	_done = true
	var occupied := 0
	for card in _last_pool:
		if card != null:
			occupied += 1

	print("DRAW_TYPE_SWITCH occupied=%d gems=%d" % [occupied, GameManager.player_data.gems])
	if occupied == 8 and GameManager.player_data.gems == 45:
		get_tree().quit(0)
	else:
		get_tree().quit(1)
