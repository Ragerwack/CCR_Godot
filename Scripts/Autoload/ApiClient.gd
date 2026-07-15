extends Node
## ApiClient — 后端 HTTP 通信层 (await 模式)
## 所有 API 请求集中管理，自动携带 auth token
##
## 设计：
## - 每个 API 方法返回 Dictionary { success: bool, data/error }
## - 同时发射信号供 UI 全局响应
## - 使用 await HTTPRequest.request_completed 避免请求混淆
## - 401 自动发射 auth_expired 信号

# ══════════════════════════════════════════════════
#  信号
# ══════════════════════════════════════════════════
signal login_succeeded(user_data: Dictionary)
signal login_failed(reason: String)
signal register_succeeded(user_data: Dictionary)
signal register_failed(reason: String)

signal profile_loaded(profile: Dictionary)
signal profile_failed(reason: String)

signal pool_refreshed(cards: Array)
signal pool_refresh_failed(reason: String)
signal draw_key_loaded(draw_key: Dictionary)

signal card_moved_to_hand(result: Dictionary)
signal move_to_hand_failed(reason: String)

signal card_moved_to_vault(result: Dictionary)
signal move_to_vault_failed(reason: String)

signal layout_synced(result: Dictionary)
signal layout_sync_failed(reason: String)

signal card_discarded(result: Dictionary)
signal discard_failed(reason: String)

signal cards_loaded(slot_type: String, cards: Array)
signal cards_load_failed(slot_type: String, reason: String)

signal synthesis_completed(result: Dictionary)
signal synthesis_failed(reason: String)

signal decks_loaded(decks: Array)
signal decks_load_failed(reason: String)

signal config_loaded(config: Array)
signal config_load_failed(reason: String)

signal level_info_loaded(info: Dictionary)
signal level_info_failed(reason: String)

signal heartbeat_succeeded(status: Dictionary)
signal heartbeat_failed(reason: String)
signal auth_expired()
signal session_reconnect_required(reason: String)
signal network_status_changed(status: String)

# ══════════════════════════════════════════════════
#  常量 & 状态
# ══════════════════════════════════════════════════
const DEFAULT_API_BASE_URL: String = "https://ccrgame.com/api"
const API_BASE_URL_ENV: String = "CCR_API_BASE_URL"
const AUTH_TOKEN_KEY: String = "ccr_auth_token"
const REFRESH_TOKEN_KEY: String = "ccr_refresh_token"
const HTTP_TIMEOUT_SECONDS: float = 30.0
const AUTH_TIMEOUT_SECONDS: float = 45.0
const READ_RETRY_ATTEMPTS: int = 2
const PREPARE_RETRY_ATTEMPTS: int = 3
const ASSET_WRITE_RETRY_ATTEMPTS: int = 3
const NETWORK_RETRY_BASE_SECONDS: float = 0.8
const NETWORK_RETRY_MAX_SECONDS: float = 4.0
const NETWORK_SLOW_MS: int = 8000
const PersistentHttpTransportScript = preload("res://Scripts/Network/PersistentHttpTransport.gd")

## HTTP method → human-readable name (Godot 4 移除了 HTTPClient.METHOD_NAMES)
const _METHOD_NAMES: Dictionary = {
	HTTPClient.METHOD_GET: "GET",
	HTTPClient.METHOD_HEAD: "HEAD",
	HTTPClient.METHOD_POST: "POST",
	HTTPClient.METHOD_PUT: "PUT",
	HTTPClient.METHOD_DELETE: "DELETE",
	HTTPClient.METHOD_OPTIONS: "OPTIONS",
	HTTPClient.METHOD_PATCH: "PATCH",
}

var _auth_token: String = ""
var _refresh_token: String = ""
var _api_base_url: String = DEFAULT_API_BASE_URL
var _operation_counter: int = 0
var _network_status: String = "good"
var _consecutive_network_failures: int = 0
var _asset_request_busy: bool = false
var _asset_request_queue_counter: int = 0
var _asset_request_pending_count: int = 0
var _persistent_transport: Node = null

# ══════════════════════════════════════════════════
#  初始化
# ══════════════════════════════════════════════════
func _ready() -> void:
	_persistent_transport = PersistentHttpTransportScript.new()
	_persistent_transport.name = "PersistentHttpTransport"
	add_child(_persistent_transport)
	_api_base_url = _resolve_api_base_url()
	FileLogger.log("ApiClient API Base URL=" + _api_base_url)

	var saved = Config.get_value("auth", "token", "")
	if saved != null and saved is String and saved != "":
		_auth_token = saved
		FileLogger.log("ApiClient 初始化, token=" + (_auth_token.left(10) + "..." if _auth_token.length() > 10 else _auth_token))
	var saved_refresh = Config.get_value("auth", "refresh_token", "")
	if saved_refresh != null and saved_refresh is String and saved_refresh != "":
		_refresh_token = saved_refresh
		FileLogger.log("ApiClient 初始化, 已加载 refresh token")

func is_logged_in() -> bool:
	return _auth_token != ""

func get_auth_token() -> String:
	return _auth_token

func has_refresh_token() -> bool:
	return _refresh_token != ""

func get_refresh_token() -> String:
	return _refresh_token

func get_api_base_url() -> String:
	return _api_base_url

func set_api_base_url(base_url: String, persist: bool = true) -> void:
	if _persistent_transport != null:
		_persistent_transport.close_all()
	_api_base_url = _normalize_api_base_url(base_url)
	if persist:
		Config.set_value("api", "base_url", _api_base_url)

func _resolve_api_base_url() -> String:
	var env_url := OS.get_environment(API_BASE_URL_ENV)
	if env_url.strip_edges() != "":
		return _normalize_api_base_url(env_url)

	var configured = Config.get_value("api", "base_url", DEFAULT_API_BASE_URL)
	if configured is String and configured.strip_edges() != "":
		return _normalize_api_base_url(configured)

	return DEFAULT_API_BASE_URL

func _new_operation_id(kind: String) -> String:
	_operation_counter += 1
	var safe_kind := kind.replace("/", "_").replace(" ", "_")
	return "%s:%d:%d:%08x" % [
		safe_kind,
		int(Time.get_unix_time_from_system() * 1000.0),
		_operation_counter,
		randi(),
	]

func new_operation_id(kind: String) -> String:
	return _new_operation_id(kind)

func get_network_status() -> String:
	return _network_status

func _normalize_api_base_url(base_url: String) -> String:
	var normalized := base_url.strip_edges()
	while normalized.ends_with("/"):
		normalized = normalized.substr(0, normalized.length() - 1)
	return normalized if normalized != "" else DEFAULT_API_BASE_URL

func _api_url(path: String) -> String:
	if path.begins_with("/"):
		return _api_base_url + path
	return _api_base_url + "/" + path

# ══════════════════════════════════════════════════
#  核心请求方法
# ══════════════════════════════════════════════════

func _make_headers() -> PackedStringArray:
	var h: PackedStringArray = PackedStringArray(["Content-Type: application/json"])
	h.append("Accept-Language: " + Localization.get_http_locale())
	if _auth_token != "":
		h.append("Authorization: Bearer " + _auth_token)
	return h

var _batch_requests: Array[HTTPRequest] = []
var _batch_urls: Array[String] = []

## 批量并行请求 — 同时发出多个请求，全部完成后返回结果
func batch_request(requests: Array[Dictionary]) -> Dictionary:
	var batch_started := Time.get_ticks_msec()
	FileLogger.perf("new_data_request_start", {"mode": "batch", "count": requests.size()})
	var state: Dictionary = {
		"pending": requests.size(),
		"results": {},
		"http_nodes": [],
		"keys": [],
		"cancelled": false,
	}

	for req in requests:
		_start_batch_request(req, state)

	var max_timeout := HTTP_TIMEOUT_SECONDS
	for req in requests:
		max_timeout = maxf(max_timeout, float(req.get("timeout", HTTP_TIMEOUT_SECONDS)))
	var timeout_ms := int(max_timeout * 1000.0) + 1000
	while int(state["pending"]) > 0 and Time.get_ticks_msec() - batch_started < timeout_ms:
		await get_tree().process_frame

	if int(state["pending"]) > 0:
		state["cancelled"] = true
		FileLogger.warn("批量请求等待超时 pending=" + str(state["pending"]), "[HTTP]")
		for key in state["keys"]:
			if not state["results"].has(key):
				state["results"][key] = {"success": false, "error": "请求超时", "error_type": "network", "status_code": 0}
		for http in state["http_nodes"]:
			if is_instance_valid(http):
				http.cancel_request()
				http.queue_free()

	FileLogger.log("批量请求完成 count=" + str(requests.size()) + " total_ms=" + str(Time.get_ticks_msec() - batch_started))
	FileLogger.perf("new_data_request_done", {"mode": "batch", "count": requests.size(), "total_ms": Time.get_ticks_msec() - batch_started})
	return state["results"] as Dictionary

func _start_batch_request(req: Dictionary, state: Dictionary) -> void:
	var http := HTTPRequest.new()
	add_child(http)
	state["http_nodes"].append(http)

	var headers = _make_headers()
	var key := str(req["key"])
	var url := str(req["url"])
	var method: int = req.get("method", HTTPClient.METHOD_GET)
	var body: String = req.get("body", "")
	var timeout_seconds: float = float(req.get("timeout", HTTP_TIMEOUT_SECONDS))
	http.timeout = timeout_seconds
	state["keys"].append(key)
	var started := Time.get_ticks_msec()
	FileLogger.http(_METHOD_NAMES.get(method, "?"), url + " [batch:start]")
	http.request_completed.connect(_on_batch_request_completed.bind(key, url, method, started, http, state), CONNECT_ONE_SHOT)
	var req_err = http.request(url, headers, method, body)
	if req_err != OK:
		state["results"][key] = {"success": false, "error": "请求启动失败", "error_type": "network", "status_code": 0}
		state["pending"] = maxi(0, int(state["pending"]) - 1)
		FileLogger.error("批量请求启动失败: " + url + " err=" + str(req_err), "[HTTP]")
		http.queue_free()

func _on_batch_request_completed(result: int, code: int, headers: PackedStringArray, body: PackedByteArray, key: String, url: String, method: int, started: int, http: HTTPRequest, state: Dictionary) -> void:
	if bool(state.get("cancelled", false)):
		return
	var result_arr: Array = [result, code, headers, body]
	var resp: Dictionary = _parse_response(result_arr, url)
	state["results"][key] = resp
	state["pending"] = maxi(0, int(state["pending"]) - 1)
	FileLogger.http(
		_METHOD_NAMES.get(method, "?"),
		url,
		resp.get("status_code", 0),
		("成功" if resp.get("success", false) else "失败: " + resp.get("error", "")) + " | wait_ms=" + str(Time.get_ticks_msec() - started)
	)
	if is_instance_valid(http):
		http.queue_free()

## 发送 HTTP 请求并等待响应，返回标准化的 Dictionary。max_attempts > 1 时会对网络/入口层失败做退避重试。
func _request(
	url: String,
	method: int = HTTPClient.METHOD_GET,
	body: String = "",
	timeout_seconds: float = HTTP_TIMEOUT_SECONDS,
	max_attempts: int = 1,
	retry_processing_conflict: bool = false
) -> Dictionary:
	var attempts := maxi(1, max_attempts)
	var last_resp: Dictionary = {}
	for attempt_index in range(attempts):
		var attempt_no := attempt_index + 1
		var resp := await _request_once(url, method, body, timeout_seconds, attempt_no, attempts)
		resp["attempt"] = attempt_no
		resp["max_attempts"] = attempts
		_record_network_result(resp)
		last_resp = resp
		if attempt_no >= attempts or not _should_retry_response(resp, retry_processing_conflict):
			return resp

		var delay_seconds := _retry_delay_seconds(attempt_no)
		FileLogger.perf("network_retry_scheduled", {
			"method": _METHOD_NAMES.get(method, "?"),
			"url": url,
			"attempt": attempt_no,
			"max_attempts": attempts,
			"delay_ms": int(delay_seconds * 1000.0),
			"status": resp.get("status_code", 0),
			"error": resp.get("error", ""),
		})
		await _sleep_seconds(delay_seconds)
	return last_resp

func _request_once(
	url: String,
	method: int = HTTPClient.METHOD_GET,
	body: String = "",
	timeout_seconds: float = HTTP_TIMEOUT_SECONDS,
	attempt_no: int = 1,
	max_attempts: int = 1
) -> Dictionary:
	var started := Time.get_ticks_msec()
	var headers = _make_headers()
	FileLogger.http(_METHOD_NAMES.get(method, "?"), url)
	FileLogger.perf("new_data_request_start", {"method": _METHOD_NAMES.get(method, "?"), "url": url, "attempt": attempt_no, "max_attempts": max_attempts})
	var network_started := Time.get_ticks_msec()
	var raw: Dictionary = await _persistent_transport.request(url, method, headers, body, timeout_seconds)
	var network_ms := Time.get_ticks_msec() - network_started
	var result_arr: Array = [
		int(raw.get("result", HTTPRequest.RESULT_CONNECTION_ERROR)),
		int(raw.get("response_code", 0)),
		raw.get("headers", PackedStringArray()),
		raw.get("body", PackedByteArray()),
	]
	var resp = _parse_response(result_arr, url)
	var total_ms := Time.get_ticks_msec() - started
	resp["network_ms"] = network_ms
	resp["total_ms"] = total_ms
	resp["connection_reused"] = bool(raw.get("connection_reused", false))
	resp["connection_slot"] = int(raw.get("connection_slot", -1))
	resp["pool_wait_ms"] = int(raw.get("pool_wait_ms", 0))
	resp["connect_ms"] = int(raw.get("connect_ms", 0))
	resp["ttfb_ms"] = int(raw.get("ttfb_ms", 0))
	FileLogger.http(_METHOD_NAMES.get(method, "?"), url, resp.get("status_code", 0), ("成功" if resp.get("success", false) else "失败: " + resp.get("error", "")) + " | network_ms=" + str(network_ms) + " | total_ms=" + str(total_ms))
	FileLogger.perf("new_data_request_done", {
		"method": _METHOD_NAMES.get(method, "?"),
		"url": url,
		"status": resp.get("status_code", 0),
		"success": resp.get("success", false),
		"network_ms": network_ms,
		"total_ms": total_ms,
		"attempt": attempt_no,
		"max_attempts": max_attempts,
		"connection_reused": resp["connection_reused"],
		"connection_slot": resp["connection_slot"],
		"pool_wait_ms": resp["pool_wait_ms"],
		"connect_ms": resp["connect_ms"],
		"ttfb_ms": resp["ttfb_ms"],
	})
	return resp

func _should_retry_response(resp: Dictionary, retry_processing_conflict: bool) -> bool:
	var status := int(resp.get("status_code", 0))
	var error_type := str(resp.get("error_type", ""))
	if error_type == "network":
		return true
	if _is_retryable_status(status):
		return true
	if retry_processing_conflict and status == 409:
		var err := str(resp.get("error", ""))
		return err.contains("正在处理中")
	return false

func is_network_uncertain_response(resp: Dictionary) -> bool:
	var status := int(resp.get("status_code", 0))
	if str(resp.get("error_type", "")) == "network" or status == 0:
		return true
	if _is_retryable_status(status):
		return true
	return status == 409 and str(resp.get("error", "")).contains("正在处理中")

func _is_retryable_status(status: int) -> bool:
	return status in [408, 425, 429, 500, 502, 503, 504]

func _retry_delay_seconds(attempt_no: int) -> float:
	var exponential = NETWORK_RETRY_BASE_SECONDS * pow(2.0, float(maxi(0, attempt_no - 1)))
	var jitter := randf() * 0.35
	return minf(NETWORK_RETRY_MAX_SECONDS, exponential + jitter)

func _sleep_seconds(seconds: float) -> void:
	if seconds <= 0.0 or get_tree() == null:
		return
	var timer := get_tree().create_timer(seconds)
	await timer.timeout

func _record_network_result(resp: Dictionary) -> void:
	var status := int(resp.get("status_code", 0))
	var network_ms := int(resp.get("network_ms", 0))
	if status == 0 or str(resp.get("error_type", "")) == "network":
		_consecutive_network_failures += 1
	elif status >= 500:
		_consecutive_network_failures += 1
	else:
		_consecutive_network_failures = 0

	var next_status := "good"
	if _consecutive_network_failures >= 3:
		next_status = "offline"
	elif _consecutive_network_failures >= 2:
		next_status = "bad"
	elif _consecutive_network_failures >= 1 or network_ms >= NETWORK_SLOW_MS:
		next_status = "unstable"

	if next_status != _network_status:
		_network_status = next_status
		network_status_changed.emit(_network_status)
		FileLogger.perf("network_status_changed", {"status": _network_status, "failures": _consecutive_network_failures, "network_ms": network_ms})

func _asset_request(url: String, method: int, body: String, operation_kind: String) -> Dictionary:
	_asset_request_queue_counter += 1
	_asset_request_pending_count += 1
	var queue_id := _asset_request_queue_counter
	var queued_at := Time.get_ticks_msec()
	if _asset_request_busy:
		FileLogger.perf("asset_request_queued", {"kind": operation_kind, "queue_id": queue_id})
	while _asset_request_busy:
		await get_tree().process_frame

	_asset_request_busy = true
	FileLogger.perf("asset_request_started", {
		"kind": operation_kind,
		"queue_id": queue_id,
		"queue_wait_ms": Time.get_ticks_msec() - queued_at,
	})
	var resp := await _request(url, method, body, HTTP_TIMEOUT_SECONDS, ASSET_WRITE_RETRY_ATTEMPTS, true)
	_asset_request_busy = false
	_asset_request_pending_count = maxi(0, _asset_request_pending_count - 1)
	FileLogger.perf("asset_request_done", {
		"kind": operation_kind,
		"queue_id": queue_id,
		"success": resp.get("success", false),
		"status": resp.get("status_code", 0),
	})
	return resp

func has_pending_asset_requests() -> bool:
	return _asset_request_pending_count > 0

## 解析 HTTP 响应为统一格式
func _parse_response(result_arr: Array, _url: String = "") -> Dictionary:
	var parse_started := Time.get_ticks_msec()
	var result: int = result_arr[0]
	var code: int = result_arr[1]
	var body_bytes: PackedByteArray = result_arr[3]

	if result != HTTPRequest.RESULT_SUCCESS:
		var err_detail = "网络连接失败"
		match result:
			HTTPRequest.RESULT_TIMEOUT:
				err_detail = "请求超时"
			HTTPRequest.RESULT_CANT_CONNECT:
				err_detail = "无法连接服务器"
			HTTPRequest.RESULT_CANT_RESOLVE:
				err_detail = "无法解析域名"
			HTTPRequest.RESULT_NO_RESPONSE:
				err_detail = "服务器无响应"
			HTTPRequest.RESULT_CONNECTION_ERROR:
				err_detail = "连接错误"
			_:
				err_detail = "网络错误(" + str(result) + ")"
		return {"success": false, "error": err_detail, "error_type": "network", "status_code": code}

	var json_parser := JSON.new()
	var body_str = body_bytes.get_string_from_utf8()
	FileLogger.perf("json_parse_start", {"url": _url, "status": code, "bytes": body_bytes.size()})
	var parse_result := json_parser.parse(body_str)
	if parse_result != OK:
		FileLogger.perf("json_parse_done", {"url": _url, "success": false, "parse_ms": Time.get_ticks_msec() - parse_started})
		var error_message := "响应解析失败"
		var error_type := "parse"
		if code == 404:
			error_message = "接口不存在或尚未部署"
			error_type = "http"
		elif code >= 400:
			error_message = "HTTP " + str(code)
			error_type = "http"
		return {"success": false, "error": error_message, "error_type": error_type, "status_code": code}
	FileLogger.perf("json_parse_done", {"url": _url, "success": true, "parse_ms": Time.get_ticks_msec() - parse_started})

	var data: Dictionary = json_parser.get_data() as Dictionary

	if data.has("success") and data["success"] == true:
		var payload = data.get("data")
		return {"success": true, "data": payload, "status_code": code}

	# 失败响应
	var err: String = data.get("error", "未知错误")
	var error_code := str(data.get("error_code", ""))
	var error_data = data.get("data", {})
	if code == 401:
		# 认证过期 — 清除 token 并通知
		_auth_token = ""
		Config.set_value("auth", "token", "")
		if error_code == "SESSION_IDLE_TIMEOUT":
			session_reconnect_required.emit(err)
			return {"success": false, "error": err, "error_type": "auth", "error_code": error_code, "data": error_data, "status_code": code}
		if not _url.ends_with("/auth/refresh") and not _url.ends_with("/auth/heartbeat"):
			auth_expired.emit()
		return {"success": false, "error": err, "error_type": "auth", "error_code": error_code, "data": error_data, "status_code": code}

	return {"success": false, "error": err, "error_type": "business", "error_code": error_code, "data": error_data, "status_code": code}

# ══════════════════════════════════════════════════
#  认证
# ══════════════════════════════════════════════════

## 登录 — 成功时自动保存 token
func login(username: String, password: String) -> Dictionary:
	var payload := {"email": username, "password": password}
	var queue_ticket := str(Config.get_value("queue", "ticket_id", ""))
	if queue_ticket != "":
		payload["queue_ticket_id"] = queue_ticket
	var body := JSON.stringify(payload)
	var resp := await _request(_api_url("/auth/login"), HTTPClient.METHOD_POST, body, AUTH_TIMEOUT_SECONDS)

	if resp["success"]:
		Config.set_value("queue", "ticket_id", "")
		var data: Dictionary = resp["data"]
		if data.has("token") or data.has("access_token"):
			_store_login_tokens(data)
			login_succeeded.emit(data)
		else:
			login_failed.emit("登录响应缺少 token")
			return {"success": false, "error": "登录响应缺少 token"}
	else:
		login_failed.emit(resp["error"])
	return resp

## 注册
func register(username: String, password: String, email: String, country: String = "EARTH") -> Dictionary:
	var payload := {"username": username, "password": password, "email": email, "country": country}
	var queue_ticket := str(Config.get_value("queue", "ticket_id", ""))
	if queue_ticket != "":
		payload["queue_ticket_id"] = queue_ticket
	var body := JSON.stringify(payload)
	var resp := await _request(_api_url("/auth/register"), HTTPClient.METHOD_POST, body, AUTH_TIMEOUT_SECONDS)

	if resp["success"]:
		Config.set_value("queue", "ticket_id", "")
		var data: Dictionary = resp["data"]
		if data.has("token") or data.has("access_token"):
			_store_login_tokens(data)
		register_succeeded.emit(data)
	else:
		register_failed.emit(resp["error"])
	return resp

## 登出
func logout() -> void:
	_auth_token = ""
	_refresh_token = ""
	Config.set_value("auth", "token", "")
	Config.set_value("auth", "refresh_token", "")

func refresh_session() -> Dictionary:
	if _refresh_token == "":
		return {"success": false, "error": "本地没有可恢复会话", "error_type": "auth", "status_code": 0}
	var body := JSON.stringify({"refresh_token": _refresh_token})
	var resp := await _request(_api_url("/auth/refresh"), HTTPClient.METHOD_POST, body, AUTH_TIMEOUT_SECONDS, READ_RETRY_ATTEMPTS)
	if resp.get("success", false):
		_store_login_tokens(resp["data"])
	else:
		if resp.get("error_type", "") == "auth":
			_refresh_token = ""
			Config.set_value("auth", "refresh_token", "")
	return resp

func _store_login_tokens(data: Dictionary) -> void:
	var access_token := str(data.get("access_token", data.get("token", "")))
	if access_token != "":
		_auth_token = access_token
		Config.set_value("auth", "token", _auth_token)
	var refresh := str(data.get("refresh_token", ""))
	if refresh != "":
		_refresh_token = refresh
		Config.set_value("auth", "refresh_token", _refresh_token)

func heartbeat(user_id: int = 0) -> Dictionary:
	var body := JSON.stringify({
		"user_id": user_id,
		"client_time": Time.get_datetime_string_from_system(),
	})
	var resp := await _request(_api_url("/auth/heartbeat"), HTTPClient.METHOD_POST, body, HTTP_TIMEOUT_SECONDS, READ_RETRY_ATTEMPTS)
	if resp.get("success", false):
		heartbeat_succeeded.emit(resp["data"])
	else:
		heartbeat_failed.emit(resp.get("error", "心跳失败"))
	return resp

func queue_status(ticket_id: String = "") -> Dictionary:
	var path := "/queue/status"
	if ticket_id.strip_edges() != "":
		path += "?ticket_id=" + ticket_id.uri_encode()
	return await _request(_api_url(path), HTTPClient.METHOD_GET, "", HTTP_TIMEOUT_SECONDS, READ_RETRY_ATTEMPTS)

func health_check() -> Dictionary:
	return await _request(_api_url("/health"), HTTPClient.METHOD_GET, "", HTTP_TIMEOUT_SECONDS)

# ══════════════════════════════════════════════════
#  用户
# ══════════════════════════════════════════════════

## 获取用户资料
func get_profile() -> Dictionary:
	var resp := await _request(_api_url("/user/profile"), HTTPClient.METHOD_GET, "", HTTP_TIMEOUT_SECONDS, READ_RETRY_ATTEMPTS)
	if resp["success"]:
		profile_loaded.emit(resp["data"])
	else:
		profile_failed.emit(resp["error"])
	return resp

## 更新玩家资料；头像、国籍等资料以服务端确认结果为准。
func update_profile(changes: Dictionary) -> Dictionary:
	var resp := await _request(
		_api_url("/user/profile"),
		HTTPClient.METHOD_PUT,
		JSON.stringify(changes),
		HTTP_TIMEOUT_SECONDS,
	)
	if resp.get("success", false):
		profile_loaded.emit(resp["data"])
	else:
		profile_failed.emit(str(resp.get("error", "更新用户资料失败")))
	return resp

## 条件同步玩家稳定资料与博物馆 relic 快照。
func sync_player_cache(cache_state: Dictionary) -> Dictionary:
	return await _request(
		_api_url("/user/cache-sync"),
		HTTPClient.METHOD_POST,
		JSON.stringify(cache_state),
		HTTP_TIMEOUT_SECONDS,
		READ_RETRY_ATTEMPTS
	)

# ══════════════════════════════════════════════════
#  游戏
# ══════════════════════════════════════════════════

## 刷新卡池
func refresh_pool(refresh_type: String) -> Dictionary:
	var body := JSON.stringify({
		"operation_id": _new_operation_id("refresh_pool"),
		"type": refresh_type,
	})
	var resp := await _asset_request(_api_url("/game/refresh-pool"), HTTPClient.METHOD_POST, body, "refresh_pool")
	if resp["success"]:
		pool_refreshed.emit(resp["data"])
	else:
		pool_refresh_failed.emit(resp["error"])
	return resp

func get_draw_key() -> Dictionary:
	var resp := await _request(_api_url("/game/draw-key"), HTTPClient.METHOD_GET, "", HTTP_TIMEOUT_SECONDS, READ_RETRY_ATTEMPTS)
	if resp.get("success", false):
		draw_key_loaded.emit(resp["data"])
	return resp

func prepare_refresh_pool_roll(refresh_type: String, draw_key_version: int) -> Dictionary:
	var payload := {
		"type": refresh_type,
	}
	if draw_key_version > 0:
		payload["draw_key_version"] = draw_key_version
	var body := JSON.stringify(payload)
	return await _request(_api_url("/game/refresh-pool/prepare"), HTTPClient.METHOD_POST, body, HTTP_TIMEOUT_SECONDS, PREPARE_RETRY_ATTEMPTS)

func confirm_refresh_pool_roll(refresh_type: String, roll_data: Dictionary, cards: Array, pool_cards: Array, hand_cards: Array, sync_layout: bool = true, operation_id: String = "") -> Dictionary:
	var op_id := operation_id
	if op_id == "":
		op_id = _new_operation_id("refresh_pool_confirm")
	var payload := {
		"operation_id": op_id,
		"type": refresh_type,
		"roll_id": roll_data.get("roll_id", ""),
		"signature": roll_data.get("signature", ""),
		"cards": _slot_cards_to_refresh_results(cards),
	}
	if sync_layout:
		payload["pool"] = _cards_to_layout(pool_cards)
		payload["hand"] = _cards_to_layout(hand_cards)
	var body := JSON.stringify(payload)
	var resp := await _asset_request(_api_url("/game/refresh-pool/confirm"), HTTPClient.METHOD_POST, body, "refresh_pool_confirm")
	resp["operation_id"] = op_id
	if resp.get("success", false):
		pool_refreshed.emit(resp["data"].get("cards", []))
	else:
		pool_refresh_failed.emit(resp.get("error", "确认抽卡失败"))
	return resp

## 移动到指定手牌槽位
func move_to_hand(pool_slot_index: int, hand_slot_index: int) -> Dictionary:
	var body := JSON.stringify({
		"operation_id": _new_operation_id("move_to_hand"),
		"pool_slot_index": pool_slot_index,
		"hand_slot_index": hand_slot_index,
	})
	var resp := await _asset_request(_api_url("/game/move-to-hand"), HTTPClient.METHOD_POST, body, "move_to_hand")
	if resp["success"]:
		card_moved_to_hand.emit(resp["data"])
	else:
		move_to_hand_failed.emit(resp["error"])
	return resp

## 移动到保险箱
func move_to_vault(source_type: String, source_slot_index: int, vault_slot_index: int) -> Dictionary:
	var body := JSON.stringify({
		"operation_id": _new_operation_id("move_to_vault"),
		"source_type": source_type,
		"source_slot_index": source_slot_index,
		"vault_slot_index": vault_slot_index,
	})
	var resp := await _asset_request(_api_url("/game/move-to-vault"), HTTPClient.METHOD_POST, body, "move_to_vault")
	if resp["success"]:
		card_moved_to_vault.emit(resp["data"])
	else:
		move_to_vault_failed.emit(resp["error"])
	return resp

func sync_pool_hand_layout(pool_cards: Array, hand_cards: Array) -> Dictionary:
	var body := JSON.stringify({
		"pool": _cards_to_layout(pool_cards),
		"hand": _cards_to_layout(hand_cards),
	})
	var resp := await _request(_api_url("/game/sync-layout"), HTTPClient.METHOD_POST, body, HTTP_TIMEOUT_SECONDS, READ_RETRY_ATTEMPTS)
	if resp["success"]:
		layout_synced.emit(resp["data"])
	else:
		layout_sync_failed.emit(resp["error"])
	return resp

func sync_vault_layout(vault_cards: Array) -> Dictionary:
	var body := JSON.stringify({
		"vault": _cards_to_layout(vault_cards),
	})
	var resp := await _request(_api_url("/game/sync-layout"), HTTPClient.METHOD_POST, body, HTTP_TIMEOUT_SECONDS, READ_RETRY_ATTEMPTS)
	if resp["success"]:
		layout_synced.emit(resp["data"])
	else:
		layout_sync_failed.emit(resp["error"])
	return resp

## 丢弃卡牌
func discard_card(slot_type: String, slot_index: int) -> Dictionary:
	var body := JSON.stringify({
		"operation_id": _new_operation_id("discard"),
		"slot_type": slot_type,
		"slot_index": slot_index,
	})
	var resp := await _asset_request(_api_url("/game/discard"), HTTPClient.METHOD_POST, body, "discard")
	if resp["success"]:
		card_discarded.emit(resp["data"])
	else:
		discard_failed.emit(resp["error"])
	return resp

func get_vault_slot_quote() -> Dictionary:
	return await _request(_api_url("/game/vault-slot-quote"), HTTPClient.METHOD_GET, "", HTTP_TIMEOUT_SECONDS, READ_RETRY_ATTEMPTS)

## 解锁槽位
func unlock_slot(slot_type: String, slot_index: int, currency: String = "gem") -> Dictionary:
	var body := JSON.stringify({
		"operation_id": _new_operation_id("unlock_slot"),
		"type": slot_type,
		"index": slot_index,
		"currency": currency,
	})
	var resp := await _asset_request(_api_url("/game/unlock-slot"), HTTPClient.METHOD_POST, body, "unlock_slot")
	if resp["success"]:
		print("[ApiClient] 槽位解锁成功: " + slot_type + "[" + str(slot_index) + "]")
	else:
		print("[ApiClient] 槽位解锁失败: " + str(resp.get("error", "未知错误")))
	return resp

## 获取槽位卡牌
func get_cards(slot_type: String) -> Dictionary:
	var resp := await _request(_api_url("/game/cards?type=" + slot_type), HTTPClient.METHOD_GET, "", HTTP_TIMEOUT_SECONDS, READ_RETRY_ATTEMPTS)
	if resp["success"]:
		cards_loaded.emit(slot_type, resp["data"])
	else:
		cards_load_failed.emit(slot_type, resp["error"])
	return resp

## 合成套牌（手牌或保险箱）
## source_type: "hand" (默认) 或 "vault"
func synthesize(slot_indices: Array, source_type: String = "hand") -> Dictionary:
	var body := JSON.stringify({
		"operation_id": _new_operation_id("synthesize"),
		"source_type": source_type,
		"draw_key_version": GameManager.draw_key_version,
		"slot_indices": slot_indices,
	})
	var resp := await _asset_request(_api_url("/game/synthesize"), HTTPClient.METHOD_POST, body, "synthesize")
	if resp["success"]:
		var data: Dictionary = resp.get("data", {})
		if data.get("key_stale", false):
			_apply_optional_draw_key(data)
			var stale_resp := {
				"success": false,
				"error": "抽卡密匙已更新，请重试合成",
				"error_type": "key_stale",
				"status_code": 409,
				"data": data,
			}
			synthesis_failed.emit(stale_resp["error"])
			return stale_resp
		_apply_optional_draw_key(data)
		synthesis_completed.emit(resp["data"])
	else:
		synthesis_failed.emit(resp["error"])
	return resp

func _apply_optional_draw_key(data: Dictionary) -> bool:
	var returned_draw_key = data.get("draw_key", null)
	if returned_draw_key is Dictionary and not returned_draw_key.is_empty():
		GameManager.apply_draw_key(returned_draw_key)
		return true
	return false

## 获取已合成套牌列表
func get_decks() -> Dictionary:
	var resp := await _request(_api_url("/game/decks"), HTTPClient.METHOD_GET, "", HTTP_TIMEOUT_SECONDS, READ_RETRY_ATTEMPTS)
	if resp["success"]:
		decks_loaded.emit(resp["data"])
	else:
		decks_load_failed.emit(resp["error"])
	return resp

## 获取游戏配置
func get_config() -> Dictionary:
	var resp := await _request(_api_url("/game/config"), HTTPClient.METHOD_GET, "", HTTP_TIMEOUT_SECONDS, READ_RETRY_ATTEMPTS)
	if resp["success"]:
		config_loaded.emit(resp["data"])
	else:
		config_load_failed.emit(resp["error"])
	return resp

# ══════════════════════════════════════════════════
#  等级 API
# ══════════════════════════════════════════════════

## 获取等级信息 (expForNext, expInLevel 等)
func get_level_info() -> Dictionary:
	var resp := await _request(_api_url("/player/level"), HTTPClient.METHOD_GET, "", HTTP_TIMEOUT_SECONDS, READ_RETRY_ATTEMPTS)
	if resp["success"]:
		level_info_loaded.emit(resp["data"])
	else:
		level_info_failed.emit(resp["error"])
	return resp

# ══════════════════════════════════════════════════
#  工具方法 — 服务端数据 → 本地 CardInfo
# ══════════════════════════════════════════════════

## 将服务端卡牌数据转换为 CardInfo 对象
static func card_slot_to_cardinfo(slot_data: Dictionary) -> CardInfo:
	# 空槽位（服务端 card_def_id 为 null）
	var card_def_id = slot_data.get("card_def_id")
	if card_def_id == null:
		return null
	
	var card_def = slot_data.get("card_def")
	if card_def == null:
		card_def = {}
	var color_val = slot_data.get("color", "white")
	return CardInfo.new({
		"id": str(card_def_id),
		"series_name": card_def.get("series_name", ""),
		"deck_name": card_def.get("deck_name", ""),
		"card_number": card_def.get("number", 1),
		"color": color_val if color_val is String else CardColor.from_string(str(color_val)),
		"card_name": card_def.get("name", ""),
		"description": card_def.get("description", ""),
		"image_path": card_def.get("image_url", card_def.get("image", "")),
	})

static func _cards_to_layout(cards: Array) -> Array:
	var result: Array = []
	for card in cards:
		if card == null:
			result.append(null)
			continue
		result.append({
			"card_def_id": int(card.id),
			"color": _color_to_api(card.color),
		})
	return result

static func _slot_cards_to_refresh_results(slots: Array) -> Array:
	var result: Array = []
	for slot in slots:
		if slot == null:
			continue
		result.append({
			"slot_index": int(slot.get("slot_index", result.size())),
			"card_def_id": int(slot.get("card_def_id", 0)),
			"color": str(slot.get("color", "white")),
		})
	return result

static func _color_to_api(color_value) -> String:
	var color_int := int(color_value)
	match color_int:
		CardColor.ColorType.WHITE: return "white"
		CardColor.ColorType.GREEN: return "green"
		CardColor.ColorType.BLUE: return "blue"
		CardColor.ColorType.PURPLE: return "purple"
		CardColor.ColorType.ORANGE: return "orange"
		CardColor.ColorType.BLACK: return "black"
		CardColor.ColorType.RED: return "red"
	return "white"

static func translate_refresh_roll_to_slots(roll_data: Dictionary, player_level: int, pool_slots: int) -> Array:
	var draw_key: Dictionary = roll_data.get("draw_key", {})
	var decks: Array = draw_key.get("decks", [])
	var matrix: Array = roll_data.get("random_matrix", [])
	var number_probs: Dictionary = draw_key.get("number_probabilities", {})
	var color_probs: Dictionary = draw_key.get("color_probabilities", {})
	var deck_count := mini(_visible_deck_count(player_level), decks.size())
	var expected_slots := mini(pool_slots, 16)
	var result: Array = []
	if deck_count <= 0:
		return result
	if matrix.size() < 16:
		return result

	var slot_count := expected_slots
	for i in range(slot_count):
		var row: Array = matrix[i] if matrix[i] is Array else [0.0, 0.0, 0.0]
		var deck_roll := _unit_float(row[0] if row.size() > 0 else 0.0)
		var number_roll := _unit_float(row[1] if row.size() > 1 else 0.0)
		var color_roll := _unit_float(row[2] if row.size() > 2 else 0.0)
		var deck_index := mini(deck_count - 1, int(floor(deck_roll * float(deck_count))))
		var deck: Dictionary = decks[deck_index]
		var number := int(_pick_by_unit_random(number_roll, number_probs, ["1", "2", "3", "4", "5"]))
		var rolled_color := _pick_by_unit_random(color_roll, color_probs, ["white", "green", "blue", "purple", "orange", "black"])
		var color := _resolve_available_deck_color(deck, rolled_color)
		var cards: Array = deck.get("cards", [])
		var card_def: Dictionary = {}
		for card in cards:
			if int(card.get("number", 1)) == number:
				card_def = card
				break
		if card_def.is_empty() and not cards.is_empty():
			card_def = cards[0]
		if card_def.is_empty():
			continue
		result.append({
			"slot_index": i,
			"card_def_id": int(card_def.get("card_def_id", 0)),
			"color": color,
			"card_def": {
				"id": int(card_def.get("card_def_id", 0)),
				"number": int(card_def.get("number", number)),
				"name": str(card_def.get("name", "")),
				"deck_name": str(deck.get("deck_name", "")),
				"series_name": str(deck.get("series_name", "")),
				"description": str(card_def.get("description", "")),
				"image_url": str(card_def.get("image_url", card_def.get("image", ""))),
			},
		})
	return result

static func _resolve_available_deck_color(deck: Dictionary, requested_color: String) -> String:
	var order: Array[String] = ["black", "orange", "purple", "blue", "green", "white"]
	var idx := order.find(requested_color)
	if idx < 0:
		return "white" if requested_color == "red" else requested_color
	var caps: Dictionary = deck.get("relic_caps", {})
	while idx < order.size():
		var candidate := order[idx]
		var cap = caps.get(candidate, {})
		var exhausted := false
		if cap is Dictionary:
			exhausted = bool(cap.get("exhausted", false))
		if not exhausted:
			return candidate
		idx += 1
	return "white"

static func _visible_deck_count(level: int) -> int:
	if level >= 40:
		return 8
	if level >= 30:
		return 7
	if level >= 20:
		return 6
	if level >= 10:
		return 5
	if level >= 5:
		return 4
	if level >= 2:
		return 3
	return 2

static func _unit_float(value) -> float:
	var n := float(value)
	if n < 0.0:
		return 0.0
	if n >= 1.0:
		return 0.999999999999
	return n

static func _pick_by_unit_random(roll: float, probabilities: Dictionary, ordered_keys: Array) -> String:
	var cumulative := 0.0
	for key in ordered_keys:
		cumulative += float(probabilities.get(str(key), 0.0))
		if roll < cumulative:
			return str(key)
	return str(ordered_keys[ordered_keys.size() - 1]) if ordered_keys.size() > 0 else ""

## 批量转换 — 跳过空槽位
static func card_slots_to_array(slots: Array) -> Array[CardInfo]:
	var result: Array[CardInfo] = []
	for s in slots:
		var ci = card_slot_to_cardinfo(s)
		if ci != null:
			result.append(ci)
	return result

## 批量转换并排序（按 slot_index），保留空槽为 null，避免本地槽位索引漂移。
static func card_slots_to_array_sorted(slots: Array) -> Array:
	var result: Array = []
	var sorted = slots.duplicate()
	sorted.sort_custom(func(a, b): return a.get("slot_index", 0) < b.get("slot_index", 0))
	for s in sorted:
		var slot_index := int(s.get("slot_index", result.size()))
		while result.size() < slot_index:
			result.append(null)
		var ci = card_slot_to_cardinfo(s)
		result.append(ci)
	return result
