extends Node

const FAIL_TIMEOUT_MS: int = 4000
const BUFFERED_PREVIEW_TARGET_MS: int = 1000

var _preview_count: int = 0
var _buffered_click_msec: int = -1
var _first_card_id: String = ""
var _done: bool = false
var _exit_code: int = 1

func _ready() -> void:
	_setup_state()
	var api_base := OS.get_environment("CCR_DRAW_CONTINUOUS_API_BASE")
	if api_base.strip_edges() == "":
		push_error("DRAW_CONTINUOUS missing API base")
		get_tree().quit(1)
		return
	ApiClient.set_api_base_url(api_base, false)

	var ui := CardPoolUI.new()
	ui.name = "DrawContinuousCardPoolUI"
	ui.auto_warm_enabled = false
	add_child(ui)
	await get_tree().process_frame
	await get_tree().process_frame

	CardPoolSystem.pool_updated.connect(_on_pool_updated)
	CardPoolSystem.warm_refresh_roll("gem")
	var warm_started := Time.get_ticks_msec()
	while CardPoolSystem._get_warm_roll("gem").is_empty() and Time.get_ticks_msec() - warm_started < FAIL_TIMEOUT_MS:
		await get_tree().process_frame
	if CardPoolSystem._get_warm_roll("gem").is_empty():
		_fail("warm timeout")
		return

	if not CardPoolSystem.request_refresh("gem"):
		_fail("first draw rejected")
		return

	var timeout_started := Time.get_ticks_msec()
	while not _done and Time.get_ticks_msec() - timeout_started < FAIL_TIMEOUT_MS:
		await get_tree().process_frame
	if not _done:
		_fail("second preview timeout")
		return

	# 等第二轮后台 confirm 收口，避免测试退出时留下未完成 HTTPRequest。
	var settle_started := Time.get_ticks_msec()
	while (CardPoolSystem.has_pending_confirm() or ApiClient.has_pending_asset_requests()) and Time.get_ticks_msec() - settle_started < FAIL_TIMEOUT_MS:
		await get_tree().process_frame
	if CardPoolSystem.get_roll_prefetch_status() != CardPoolSystem.ROLL_PREFETCH_STATUS_READY:
		_exit_code = 1
		push_error("DRAW_CONTINUOUS next roll did not return to ready after confirm")
	get_tree().quit(_exit_code)

func _setup_state() -> void:
	GameManager.player_data.user_id = 1
	GameManager.player_data.level = 1
	GameManager.player_data.pool_slots = 8
	GameManager.player_data.hand_slots = 8
	GameManager.player_data.gold = 1000
	GameManager.player_data.gems = 50
	GameManager.free_refresh_count = 1
	GameManager.newbie_free_refresh_count = 0
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

func _on_pool_updated(cards: Array) -> void:
	if cards.is_empty() or cards[0] == null:
		return
	_preview_count += 1
	if _preview_count == 1:
		_first_card_id = str(cards[0].id)
		# 模拟玩家查看预览时继续移动卡牌；上一轮 confirm 不得把这次新移动误标为 clean。
		GameManager.mark_pool_hand_layout_dirty("continuous_test_after_snapshot")
		_queue_second_draw.call_deferred()
		return
	if _preview_count != 2:
		_fail("confirm triggered duplicate pool render count=%d" % _preview_count)
		return

	var elapsed := Time.get_ticks_msec() - _buffered_click_msec
	var second_card_id := str(cards[0].id)
	print("DRAW_CONTINUOUS buffered_preview_ms=%d first=%s second=%s gems=%d" % [
		elapsed,
		_first_card_id,
		second_card_id,
		GameManager.player_data.gems,
	])
	_done = true
	if (
		elapsed <= BUFFERED_PREVIEW_TARGET_MS
		and second_card_id != _first_card_id
		and GameManager.player_data.gems == 40
		and GameManager.is_pool_hand_layout_dirty()
	):
		_exit_code = 0
	else:
		_exit_code = 1

func _queue_second_draw() -> void:
	_buffered_click_msec = Time.get_ticks_msec()
	CardPoolSystem.warm_refresh_roll("gem")
	if CardPoolSystem.get_roll_prefetch_status() != CardPoolSystem.ROLL_PREFETCH_STATUS_WAITING:
		_fail("roll status showed ready while confirm was pending")
		return
	if not CardPoolSystem.request_refresh("gem"):
		_fail("buffered draw rejected")

func _fail(reason: String) -> void:
	if _done:
		return
	_done = true
	push_error("DRAW_CONTINUOUS " + reason)
	get_tree().quit(1)
