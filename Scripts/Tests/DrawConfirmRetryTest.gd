extends Node

const FAIL_TIMEOUT_MS: int = 7000
const TEST_OPERATION_ID: String = "refresh_pool_confirm:test:weaknet"

var _done: bool = false

func _ready() -> void:
	var api_base := OS.get_environment("CCR_DRAW_CONFIRM_RETRY_API_BASE")
	if api_base.strip_edges() == "":
		push_error("DRAW_CONFIRM_RETRY missing CCR_DRAW_CONFIRM_RETRY_API_BASE")
		get_tree().quit(1)
		return

	ApiClient.set_api_base_url(api_base, false)
	call_deferred("_run")

	var timeout_started := Time.get_ticks_msec()
	while not _done and Time.get_ticks_msec() - timeout_started < FAIL_TIMEOUT_MS:
		await get_tree().process_frame

	if not _done:
		push_error("DRAW_CONFIRM_RETRY timeout_ms=%d" % FAIL_TIMEOUT_MS)
		get_tree().quit(1)

func _run() -> void:
	var resp := await ApiClient.confirm_refresh_pool_roll(
		"free",
		_mock_roll(),
		_mock_cards(),
		[],
		[],
		false,
		TEST_OPERATION_ID
	)
	_done = true

	if not resp.get("success", false):
		push_error("DRAW_CONFIRM_RETRY request_failed error=%s status=%s attempt=%s" % [
			resp.get("error", ""),
			resp.get("status_code", 0),
			resp.get("attempt", 0),
		])
		get_tree().quit(1)
		return

	if str(resp.get("operation_id", "")) != TEST_OPERATION_ID:
		push_error("DRAW_CONFIRM_RETRY operation_id_changed=%s" % resp.get("operation_id", ""))
		get_tree().quit(1)
		return

	if int(resp.get("attempt", 0)) != 2:
		push_error("DRAW_CONFIRM_RETRY expected_second_attempt got=%s" % resp.get("attempt", 0))
		get_tree().quit(1)
		return

	if ApiClient.get_network_status() != "good":
		push_error("DRAW_CONFIRM_RETRY network_status_not_recovered=%s" % ApiClient.get_network_status())
		get_tree().quit(1)
		return

	print("DRAW_CONFIRM_RETRY success attempt=%d operation_id=%s" % [int(resp.get("attempt", 0)), resp.get("operation_id", "")])
	get_tree().quit(0)

func _mock_roll() -> Dictionary:
	return {
		"roll_id": "00000000-0000-4000-8000-000000000099",
		"signature": "retry-signature",
	}

func _mock_cards() -> Array:
	var cards: Array = []
	for index in range(3):
		cards.append({
			"slot_index": index,
			"card_def_id": 9900 + index,
			"color": "white",
		})
	return cards
