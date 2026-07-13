extends Node

const REQUEST_COUNT: int = 4


func _ready() -> void:
	var api_base := OS.get_environment("CCR_PERSISTENT_HTTP_API_BASE")
	if api_base.strip_edges() == "":
		_fail("missing CCR_PERSISTENT_HTTP_API_BASE")
		return

	ApiClient.set_api_base_url(api_base, false)
	call_deferred("_run")


func _run() -> void:
	var first_socket_id := -1
	var previous_response_closed := false
	for index in range(REQUEST_COUNT):
		var resp := await ApiClient.health_check()
		if not resp.get("success", false):
			_fail("request %d failed: %s" % [index + 1, resp.get("error", "")])
			return
		var data: Dictionary = resp.get("data", {})
		var socket_id := int(data.get("socket_id", -1))
		var expected_reuse := index > 0 and not previous_response_closed
		if index == 0:
			first_socket_id = socket_id
			if bool(resp.get("connection_reused", true)):
				_fail("first request unexpectedly reused a connection")
				return
		else:
			if expected_reuse and first_socket_id > 0 and socket_id != first_socket_id:
				_fail("request %d opened socket %d instead of reusing %d" % [index + 1, socket_id, first_socket_id])
				return
			if bool(resp.get("connection_reused", false)) != expected_reuse:
				_fail("request %d reuse=%s expected=%s" % [index + 1, resp.get("connection_reused", false), expected_reuse])
				return
		if expected_reuse and int(resp.get("connect_ms", -1)) != 0:
			_fail("request %d repeated connect_ms=%s" % [index + 1, resp.get("connect_ms", -1)])
			return
		if not expected_reuse and index > 0:
			first_socket_id = socket_id
		previous_response_closed = bool(data.get("closed_after_response", false))

	print("PERSISTENT_HTTP ok requests=%d socket_id=%d" % [REQUEST_COUNT, first_socket_id])
	get_tree().quit(0)


func _fail(message: String) -> void:
	push_error("PERSISTENT_HTTP " + message)
	get_tree().quit(1)
