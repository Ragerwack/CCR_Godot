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

signal card_moved_to_hand(result: Dictionary)
signal move_to_hand_failed(reason: String)

signal card_moved_to_vault(result: Dictionary)
signal move_to_vault_failed(reason: String)

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

signal auth_expired()

# ══════════════════════════════════════════════════
#  常量 & 状态
# ══════════════════════════════════════════════════
const API_BASE_URL: String = "http://ccrgame.com/api"
const AUTH_TOKEN_KEY: String = "ccr_auth_token"

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

# ══════════════════════════════════════════════════
#  初始化
# ══════════════════════════════════════════════════
func _ready() -> void:
	var saved = Config.get_value("auth", "token", "")
	if saved != null and saved is String and saved != "":
		_auth_token = saved
		FileLogger.log("ApiClient 初始化, token=" + (_auth_token.left(10) + "..." if _auth_token.length() > 10 else _auth_token))

func is_logged_in() -> bool:
	return _auth_token != ""

func get_auth_token() -> String:
	return _auth_token

# ══════════════════════════════════════════════════
#  核心请求方法
# ══════════════════════════════════════════════════

func _make_headers() -> PackedStringArray:
	var h: PackedStringArray = PackedStringArray(["Content-Type: application/json"])
	if _auth_token != "":
		h.append("Authorization: Bearer " + _auth_token)
	return h

var _batch_requests: Array[HTTPRequest] = []
var _batch_urls: Array[String] = []

## 批量并行请求 — 同时发出多个请求，全部完成后返回结果
func batch_request(requests: Array[Dictionary]) -> Dictionary:
	# requests: [{key, url, method, body}]
	var http_nodes: Array[HTTPRequest] = []
	var keys: Array[String] = []
	var urls: Array[String] = []

	for req in requests:
		var http := HTTPRequest.new()
		http.timeout = 15  # 15秒超时
		add_child(http)
		var headers = _make_headers()
		var url: String = req["url"]
		var method: int = req.get("method", HTTPClient.METHOD_GET)
		var body: String = req.get("body", "")
		http.request(url, headers, method, body)
		http_nodes.append(http)
		keys.append(req["key"])
		urls.append(url)

	# 请求已全部同时发出，逐个收集结果，但超时或失败不影响其他请求
	var results: Dictionary = {}
	for i in range(http_nodes.size()):
		var http = http_nodes[i]
		# 用超时保护：如果这个请求卡住，最多等 25 秒
		var result_arr: Array = await http.request_completed
		
		# 主动超时检查：如果等待超过 25 秒还没返回，标记失败
		# 注意：await 会一直等，但 http.timeout 会在连接层超时
		# 这里额外检查 result_arr 的有效性
		if result_arr.is_empty() or result_arr.size() < 4 or result_arr[0] != HTTPRequest.RESULT_SUCCESS:
			var status = "unknown"
			var code = 0
			if result_arr.size() >= 2:
				code = result_arr[1]
			results[keys[i]] = {"success": false, "error": "请求超时或无响应", "error_type": "network", "status_code": code}
		else:
			results[keys[i]] = _parse_response(result_arr, urls[i])
		http.queue_free()

	return results

## 发送 HTTP 请求并等待响应，返回标准化的 Dictionary
func _request(url: String, method: int = HTTPClient.METHOD_GET, body: String = "") -> Dictionary:
	var http := HTTPRequest.new()
	http.timeout = 15  # 15秒超时，防止无限等待
	add_child(http)
	var headers = _make_headers()
	FileLogger.http(_METHOD_NAMES.get(method, "?"), url)
	var req_err = http.request(url, headers, method, body)
	if req_err != OK:
		http.queue_free()
		FileLogger.error("请求启动失败: " + url + " err=" + str(req_err), "[HTTP]")
		return {"success": false, "error": "请求启动失败", "error_type": "network"}

	var result_arr: Array = await http.request_completed
	http.queue_free()
	var resp = _parse_response(result_arr, url)
	FileLogger.http(_METHOD_NAMES.get(method, "?"), url, resp.get("status_code", 0), "成功" if resp.get("success", false) else "失败: " + resp.get("error", ""))
	return resp

## 解析 HTTP 响应为统一格式
func _parse_response(result_arr: Array, _url: String = "") -> Dictionary:
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
	var parse_result := json_parser.parse(body_str)
	if parse_result != OK:
		return {"success": false, "error": "响应解析失败", "error_type": "parse", "status_code": code}

	var data: Dictionary = json_parser.get_data() as Dictionary

	if data.has("success") and data["success"] == true:
		var payload = data.get("data")
		return {"success": true, "data": payload, "status_code": code}

	# 失败响应
	var err: String = data.get("error", "未知错误")
	if code == 401:
		# 认证过期 — 清除 token 并通知
		_auth_token = ""
		Config.set_value("auth", "token", "")
		auth_expired.emit()
		return {"success": false, "error": err, "error_type": "auth", "status_code": code}

	return {"success": false, "error": err, "error_type": "business", "status_code": code}

# ══════════════════════════════════════════════════
#  认证
# ══════════════════════════════════════════════════

## 登录 — 成功时自动保存 token
func login(username: String, password: String) -> Dictionary:
	var body := JSON.stringify({"email": username, "password": password})
	var resp := await _request(API_BASE_URL + "/auth/login", HTTPClient.METHOD_POST, body)

	if resp["success"]:
		var data: Dictionary = resp["data"]
		if data.has("token"):
			_auth_token = data["token"]
			Config.set_value("auth", "token", _auth_token)
			login_succeeded.emit(data)
		else:
			login_failed.emit("登录响应缺少 token")
			return {"success": false, "error": "登录响应缺少 token"}
	else:
		login_failed.emit(resp["error"])
	return resp

## 注册
func register(username: String, password: String, email: String) -> Dictionary:
	var body := JSON.stringify({"username": username, "password": password, "email": email})
	var resp := await _request(API_BASE_URL + "/auth/register", HTTPClient.METHOD_POST, body)

	if resp["success"]:
		var data: Dictionary = resp["data"]
		if data.has("token"):
			_auth_token = data["token"]
			Config.set_value("auth", "token", _auth_token)
		register_succeeded.emit(data)
	else:
		register_failed.emit(resp["error"])
	return resp

## 登出
func logout() -> void:
	_auth_token = ""
	Config.set_value("auth", "token", "")

# ══════════════════════════════════════════════════
#  用户
# ══════════════════════════════════════════════════

## 获取用户资料
func get_profile() -> Dictionary:
	var resp := await _request(API_BASE_URL + "/user/profile", HTTPClient.METHOD_GET)
	if resp["success"]:
		profile_loaded.emit(resp["data"])
	else:
		profile_failed.emit(resp["error"])
	return resp

# ══════════════════════════════════════════════════
#  游戏
# ══════════════════════════════════════════════════

## 刷新卡池
func refresh_pool(refresh_type: String) -> Dictionary:
	var body := JSON.stringify({"type": refresh_type})
	var resp := await _request(API_BASE_URL + "/game/refresh-pool", HTTPClient.METHOD_POST, body)
	if resp["success"]:
		pool_refreshed.emit(resp["data"])
	else:
		pool_refresh_failed.emit(resp["error"])
	return resp

## 移动到指定手牌槽位
func move_to_hand(pool_slot_index: int, hand_slot_index: int) -> Dictionary:
	var body := JSON.stringify({
		"pool_slot_index": pool_slot_index,
		"hand_slot_index": hand_slot_index,
	})
	var resp := await _request(API_BASE_URL + "/game/move-to-hand", HTTPClient.METHOD_POST, body)
	if resp["success"]:
		card_moved_to_hand.emit(resp["data"])
	else:
		move_to_hand_failed.emit(resp["error"])
	return resp

## 移动到保险箱
func move_to_vault(source_type: String, source_slot_index: int, vault_slot_index: int) -> Dictionary:
	var body := JSON.stringify({
		"source_type": source_type,
		"source_slot_index": source_slot_index,
		"vault_slot_index": vault_slot_index,
	})
	var resp := await _request(API_BASE_URL + "/game/move-to-vault", HTTPClient.METHOD_POST, body)
	if resp["success"]:
		card_moved_to_vault.emit(resp["data"])
	else:
		move_to_vault_failed.emit(resp["error"])
	return resp

## 丢弃卡牌
func discard_card(slot_type: String, slot_index: int) -> Dictionary:
	var body := JSON.stringify({
		"slot_type": slot_type,
		"slot_index": slot_index,
	})
	var resp := await _request(API_BASE_URL + "/game/discard", HTTPClient.METHOD_POST, body)
	if resp["success"]:
		card_discarded.emit(resp["data"])
	else:
		discard_failed.emit(resp["error"])
	return resp

## 解锁槽位
func unlock_slot(slot_type: String, slot_index: int) -> Dictionary:
	var body := JSON.stringify({
		"type": slot_type,
		"index": slot_index,
	})
	var resp := await _request(API_BASE_URL + "/game/unlock-slot", HTTPClient.METHOD_POST, body)
	if resp["success"]:
		print("[ApiClient] 槽位解锁成功: " + slot_type + "[" + str(slot_index) + "]")
	else:
		print("[ApiClient] 槽位解锁失败: " + str(resp.get("error", "未知错误")))
	return resp

## 获取槽位卡牌
func get_cards(slot_type: String) -> Dictionary:
	var resp := await _request(API_BASE_URL + "/game/cards?type=" + slot_type, HTTPClient.METHOD_GET)
	if resp["success"]:
		cards_loaded.emit(slot_type, resp["data"])
	else:
		cards_load_failed.emit(slot_type, resp["error"])
	return resp

## 合成套牌（手牌或保险箱）
## source_type: "hand" (默认) 或 "vault"
func synthesize(slot_indices: Array, source_type: String = "hand") -> Dictionary:
	var body := JSON.stringify({
		"source_type": source_type,
		"slot_indices": slot_indices,
	})
	var resp := await _request(API_BASE_URL + "/game/synthesize", HTTPClient.METHOD_POST, body)
	if resp["success"]:
		synthesis_completed.emit(resp["data"])
	else:
		synthesis_failed.emit(resp["error"])
	return resp

## 获取已合成套牌列表
func get_decks() -> Dictionary:
	var resp := await _request(API_BASE_URL + "/game/decks", HTTPClient.METHOD_GET)
	if resp["success"]:
		decks_loaded.emit(resp["data"])
	else:
		decks_load_failed.emit(resp["error"])
	return resp

## 获取游戏配置
func get_config() -> Dictionary:
	var resp := await _request(API_BASE_URL + "/game/config", HTTPClient.METHOD_GET)
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
	var resp := await _request(API_BASE_URL + "/player/level", HTTPClient.METHOD_GET)
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
	})

## 批量转换 — 跳过空槽位
static func card_slots_to_array(slots: Array) -> Array[CardInfo]:
	var result: Array[CardInfo] = []
	for s in slots:
		var ci = card_slot_to_cardinfo(s)
		if ci != null:
			result.append(ci)
	return result

## 批量转换并排序（按 slot_index），跳过空槽位
static func card_slots_to_array_sorted(slots: Array) -> Array[CardInfo]:
	var result: Array[CardInfo] = []
	# 先按键排序
	var sorted = slots.duplicate()
	sorted.sort_custom(func(a, b): return a.get("slot_index", 0) < b.get("slot_index", 0))
	for s in sorted:
		var ci = card_slot_to_cardinfo(s)
		if ci != null:
			result.append(ci)
	return result
