extends Node

signal session_status_changed(status: String)
signal heartbeat_failed_soft(fail_count: int, reason: String)

const HEARTBEAT_INTERVAL_SECONDS: float = 45.0
const HEARTBEAT_FAILURE_THRESHOLD: int = 3

var _timer: Timer = null
var _failure_count: int = 0
var _running: bool = false
var _heartbeat_in_flight: bool = false
var _last_status: String = "offline"

func _ready() -> void:
	_timer = Timer.new()
	_timer.name = "SessionHeartbeatTimer"
	_timer.wait_time = HEARTBEAT_INTERVAL_SECONDS
	_timer.one_shot = false
	_timer.timeout.connect(_on_heartbeat_timer)
	add_child(_timer)

func start_session() -> void:
	if not ApiClient.is_logged_in():
		return
	_running = true
	_failure_count = 0
	_set_status("online")
	if _timer != null and _timer.is_stopped():
		_timer.start()
	_send_heartbeat.call_deferred()

func stop_session() -> void:
	_running = false
	_failure_count = 0
	_heartbeat_in_flight = false
	if _timer != null:
		_timer.stop()
	_set_status("offline")

func get_status() -> String:
	return _last_status

func _on_heartbeat_timer() -> void:
	_send_heartbeat()

func _send_heartbeat() -> void:
	if not _running or _heartbeat_in_flight or not ApiClient.is_logged_in():
		return
	_heartbeat_in_flight = true
	FileLogger.perf("heartbeat_start", {"fail_count": _failure_count})
	var resp: Dictionary = await ApiClient.heartbeat(GameManager.player_data.user_id)
	_heartbeat_in_flight = false

	if resp.get("success", false):
		_failure_count = 0
		_set_status(resp["data"].get("session_status", "online"))
		FileLogger.perf("heartbeat_done", {"success": true, "status": _last_status})
		return

	if resp.get("error_type", "") == "auth" and ApiClient.has_refresh_token():
		FileLogger.warn("心跳发现 access token 失效，尝试刷新会话")
		var refresh_resp: Dictionary = await ApiClient.refresh_session()
		if refresh_resp.get("success", false):
			_failure_count = 0
			_set_status("online")
			FileLogger.perf("heartbeat_refresh_session_done", {"success": true})
			return
		FileLogger.perf("heartbeat_refresh_session_done", {
			"success": false,
			"reason": refresh_resp.get("error", ""),
		})
		ApiClient.auth_expired.emit()
		return

	_failure_count += 1
	var reason := str(resp.get("error", "心跳失败"))
	FileLogger.perf("heartbeat_done", {"success": false, "fail_count": _failure_count, "reason": reason})
	heartbeat_failed_soft.emit(_failure_count, reason)

	if _failure_count >= HEARTBEAT_FAILURE_THRESHOLD:
		_set_status("reconnecting")

func _set_status(status: String) -> void:
	if _last_status == status:
		return
	_last_status = status
	session_status_changed.emit(status)
