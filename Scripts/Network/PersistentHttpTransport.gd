extends Node

## ApiClient 的低层持久 HTTP 传输。
##
## HTTPRequest 适合独立请求，但 CCR 的生产 API 全部指向同一 origin。
## 这里保留少量 HTTPClient 连接，让后续指令复用已完成的 TCP/TLS 握手。

const DEFAULT_POOL_SIZE: int = 2

var _slots: Array[Dictionary] = []


func _ready() -> void:
	_ensure_slots()


func _exit_tree() -> void:
	close_all()


func close_all() -> void:
	for slot in _slots:
		var client = slot.get("client")
		if client is HTTPClient:
			client.close()
		slot["origin"] = ""


func request(
	url: String,
	method: int,
	headers: PackedStringArray,
	body: String,
	timeout_seconds: float
) -> Dictionary:
	_ensure_slots()
	var queued_at := Time.get_ticks_msec()
	var slot_index := await _acquire_slot()
	var slot: Dictionary = _slots[slot_index]
	var pool_wait_ms := Time.get_ticks_msec() - queued_at
	var remaining_timeout := timeout_seconds - float(pool_wait_ms) / 1000.0
	if remaining_timeout <= 0.0:
		slot["busy"] = false
		return _failure(HTTPRequest.RESULT_TIMEOUT, pool_wait_ms, slot_index)
	var result := await _request_on_slot(
		slot,
		url,
		method,
		headers,
		body,
		remaining_timeout,
		pool_wait_ms,
		slot_index
	)
	slot["busy"] = false
	return result


func _ensure_slots() -> void:
	if not _slots.is_empty():
		return
	for index in range(DEFAULT_POOL_SIZE):
		_slots.append({
			"id": index,
			"client": HTTPClient.new(),
			"origin": "",
			"busy": false,
		})


func _acquire_slot() -> int:
	while true:
		# 始终优先复用第一条空闲连接，避免低并发时无意扩大握手数。
		for index in range(_slots.size()):
			if not bool(_slots[index].get("busy", false)):
				_slots[index]["busy"] = true
				return index
		await get_tree().process_frame
	return 0


func _request_on_slot(
	slot: Dictionary,
	url: String,
	method: int,
	headers: PackedStringArray,
	body: String,
	timeout_seconds: float,
	pool_wait_ms: int,
	slot_index: int
) -> Dictionary:
	var parsed := _parse_url(url)
	if parsed.is_empty():
		return _failure(HTTPRequest.RESULT_CANT_CONNECT, pool_wait_ms, slot_index)

	var client: HTTPClient = slot["client"]
	var origin := str(parsed["origin"])
	if str(slot.get("origin", "")) == origin and client.get_status() == HTTPClient.STATUS_CONNECTED:
		# 先消费闲置期间到达的 FIN/错误，避免把已被服务端关闭的 socket 误判为可复用。
		client.poll()
	var reused_connection := (
		str(slot.get("origin", "")) == origin
		and client.get_status() == HTTPClient.STATUS_CONNECTED
	)
	var started := Time.get_ticks_msec()
	var connect_ms := 0

	if not reused_connection:
		client.close()
		slot["origin"] = ""
		var tls_options = TLSOptions.client() if bool(parsed["tls"]) else null
		var connect_started := Time.get_ticks_msec()
		var connect_error := client.connect_to_host(str(parsed["host"]), int(parsed["port"]), tls_options)
		if connect_error != OK:
			client.close()
			return _failure(HTTPRequest.RESULT_CANT_CONNECT, pool_wait_ms, slot_index)

		while client.get_status() in [
			HTTPClient.STATUS_RESOLVING,
			HTTPClient.STATUS_CONNECTING,
		]:
			client.poll()
			if _timed_out(started, timeout_seconds):
				client.close()
				return _failure(HTTPRequest.RESULT_TIMEOUT, pool_wait_ms, slot_index)
			await get_tree().process_frame

		connect_ms = Time.get_ticks_msec() - connect_started
		if client.get_status() != HTTPClient.STATUS_CONNECTED:
			var connect_result := _result_for_status(client.get_status())
			client.close()
			return _failure(connect_result, pool_wait_ms, slot_index, connect_ms)
		slot["origin"] = origin

	var request_started := Time.get_ticks_msec()
	var request_error := client.request(method, str(parsed["path"]), headers, body)
	if request_error != OK:
		client.close()
		slot["origin"] = ""
		return _failure(HTTPRequest.RESULT_CONNECTION_ERROR, pool_wait_ms, slot_index, connect_ms, reused_connection)

	while client.get_status() == HTTPClient.STATUS_REQUESTING:
		client.poll()
		if _timed_out(started, timeout_seconds):
			client.close()
			slot["origin"] = ""
			return _failure(HTTPRequest.RESULT_TIMEOUT, pool_wait_ms, slot_index, connect_ms, reused_connection)
		await get_tree().process_frame

	if not client.has_response():
		var response_result := _result_for_status(client.get_status())
		client.close()
		slot["origin"] = ""
		return _failure(response_result, pool_wait_ms, slot_index, connect_ms, reused_connection)

	var ttfb_ms := Time.get_ticks_msec() - request_started
	var response_code := client.get_response_code()
	var response_headers := client.get_response_headers()
	var response_body := PackedByteArray()

	while client.get_status() == HTTPClient.STATUS_BODY:
		client.poll()
		var chunk := client.read_response_body_chunk()
		if not chunk.is_empty():
			response_body.append_array(chunk)
		if _timed_out(started, timeout_seconds):
			client.close()
			slot["origin"] = ""
			return _failure(HTTPRequest.RESULT_TIMEOUT, pool_wait_ms, slot_index, connect_ms, reused_connection)
		if client.get_status() == HTTPClient.STATUS_BODY and chunk.is_empty():
			await get_tree().process_frame

	if client.get_status() != HTTPClient.STATUS_CONNECTED:
		# 服务端可以用 Connection: close 主动结束连接；本次响应仍是成功的。
		client.close()
		slot["origin"] = ""

	return {
		"result": HTTPRequest.RESULT_SUCCESS,
		"response_code": response_code,
		"headers": response_headers,
		"body": response_body,
		"connection_reused": reused_connection,
		"connection_slot": slot_index,
		"pool_wait_ms": pool_wait_ms,
		"connect_ms": connect_ms,
		"ttfb_ms": ttfb_ms,
	}


func _parse_url(url: String) -> Dictionary:
	var scheme_separator := url.find("://")
	if scheme_separator <= 0:
		return {}
	var scheme := url.substr(0, scheme_separator).to_lower()
	if scheme not in ["http", "https"]:
		return {}
	var authority_start := scheme_separator + 3
	var path_start := url.find("/", authority_start)
	var authority := url.substr(authority_start) if path_start < 0 else url.substr(authority_start, path_start - authority_start)
	var path := "/" if path_start < 0 else url.substr(path_start)
	var host := authority
	var port := 443 if scheme == "https" else 80
	if authority.begins_with("["):
		var closing_bracket := authority.find("]")
		if closing_bracket <= 1:
			return {}
		host = authority.substr(1, closing_bracket - 1)
		if closing_bracket + 1 < authority.length():
			if authority.substr(closing_bracket + 1, 1) != ":":
				return {}
			var ipv6_port_text := authority.substr(closing_bracket + 2)
			if not ipv6_port_text.is_valid_int():
				return {}
			port = int(ipv6_port_text)
	else:
		var colon := authority.rfind(":")
		if colon > 0:
			var port_text := authority.substr(colon + 1)
			if not port_text.is_valid_int():
				return {}
			host = authority.substr(0, colon)
			port = int(port_text)
	if host.is_empty():
		return {}
	return {
		"tls": scheme == "https",
		"host": host,
		"port": port,
		"path": path,
		"origin": "%s://%s:%d" % [scheme, host, port],
	}


func _timed_out(started: int, timeout_seconds: float) -> bool:
	return Time.get_ticks_msec() - started >= int(maxf(0.1, timeout_seconds) * 1000.0)


func _result_for_status(status: int) -> int:
	match status:
		HTTPClient.STATUS_CANT_RESOLVE:
			return HTTPRequest.RESULT_CANT_RESOLVE
		HTTPClient.STATUS_CANT_CONNECT:
			return HTTPRequest.RESULT_CANT_CONNECT
		HTTPClient.STATUS_TLS_HANDSHAKE_ERROR:
			return HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR
		_:
			return HTTPRequest.RESULT_CONNECTION_ERROR


func _failure(
	result: int,
	pool_wait_ms: int,
	slot_index: int,
	connect_ms: int = 0,
	reused_connection: bool = false
) -> Dictionary:
	return {
		"result": result,
		"response_code": 0,
		"headers": PackedStringArray(),
		"body": PackedByteArray(),
		"connection_reused": reused_connection,
		"connection_slot": slot_index,
		"pool_wait_ms": pool_wait_ms,
		"connect_ms": connect_ms,
		"ttfb_ms": 0,
	}
