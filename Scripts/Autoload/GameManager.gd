extends Node

signal scene_changed(scene_name: String)
signal pool_refreshed()
signal free_refresh_ready()
signal free_refresh_cooldown_updated(remaining: float)
signal data_synced()

enum Scene { MAIN, CARD_POOL, HAND_AREA, VAULT, DECK_PANEL, MENU }

var current_scene: Scene = Scene.MAIN
var player_data: PlayerData
# 等级经验阈值（后端 /user/level API 提供）
var exp_in_level: int = 0
var exp_for_next: int = 400
var current_view: String = "Main"

# 免费刷新：服务端管理计数，这里仅做本地临时倒计时
var free_refresh_count: int = 1
var free_refresh_cooldown: float = 0.0
var free_refresh_max_count: int = 1
var newbie_free_refresh_count: int = 0
var last_free_refresh_time_unix: float = 0.0
var _last_free_refresh_attempt_was_newbie: bool = false
var draw_key: Dictionary = {}
var draw_key_version: int = 0
var _last_gold_refresh_attempt_cost: int = 0
var _last_gem_refresh_attempt_cost: int = 0

var _cache_loaded: Dictionary = {
	"profile": false,
	"level": false,
	"pool": false,
	"hand": false,
	"vault": false,
	"decks": false,
}
var vault_raw_slot_data: Array = []
var _layout_sync_in_flight: bool = false
var _optional_login_sync_in_flight: bool = false

const NAV_BUTTONS: Array[Dictionary] = [
	{"id": "card_pool", "label": "抽牌"},
	{"id": "vault", "label": "保险箱"},
	{"id": "deck_panel", "label": "卡组"},
	{"id": "auction", "label": "拍卖行"},
	{"id": "mail", "label": "邮箱"},
	{"id": "ladder", "label": "天梯"},
	{"id": "achievement", "label": "成就"},
	{"id": "menu", "label": "菜单"},
]

# ══════════════════════════════════════════════════
#  初始化
# ══════════════════════════════════════════════════

func _ready() -> void:
	player_data = PlayerData.new()
	var cached_draw_key = Config.get_value("cache", "draw_key", {})
	if cached_draw_key is Dictionary and not cached_draw_key.is_empty():
		apply_draw_key(cached_draw_key)

	var timer = Timer.new()
	timer.name = "FreeRefreshTimer"
	timer.wait_time = 1.0
	timer.timeout.connect(_on_free_refresh_timer)
	add_child(timer)
	timer.start()

	_update_free_refresh_max()

func _process(delta: float) -> void:
	if free_refresh_cooldown > 0:
		free_refresh_cooldown -= delta
		free_refresh_cooldown = max(0.0, free_refresh_cooldown)
		free_refresh_cooldown_updated.emit(free_refresh_cooldown)
		if free_refresh_cooldown <= 0.0:
			_recover_one_free_refresh_local()

# ══════════════════════════════════════════════════
#  服务端数据同步
# ══════════════════════════════════════════════════

## 从登录响应设置玩家数据
func apply_login_user(user_data: Dictionary) -> void:
	# 映射 login 响应字段到 PlayerData
	player_data.user_id = int(user_data.get("id", player_data.user_id))
	player_data.nickname = user_data.get("username", "玩家")
	player_data.level = user_data.get("level", 1)
	player_data.exp = user_data.get("exp", 0)
	player_data.gold = user_data.get("gold", 100)
	player_data.gems = user_data.get("gems", 50)
	free_refresh_count = int(user_data.get("freeRefreshCount", free_refresh_count))
	newbie_free_refresh_count = int(user_data.get("newbieFreeRefreshCount", newbie_free_refresh_count))
	_update_free_refresh_max()
	_update_free_refresh_cooldown_from_state()
	player_data.changed.emit()

func apply_draw_key(key_data: Dictionary) -> void:
	draw_key = key_data.duplicate(true)
	draw_key_version = int(draw_key.get("version", 0))
	Config.set_value("cache", "draw_key", draw_key)

	## 从 profile 响应同步完整数据
func apply_profile(profile: Dictionary) -> void:
	player_data.user_id = int(profile.get("id", player_data.user_id))
	player_data.nickname = profile.get("username", player_data.nickname)
	player_data.level = profile.get("level", player_data.level)
	player_data.exp = profile.get("exp", player_data.exp)
	player_data.gold = profile.get("gold", player_data.gold)
	player_data.gems = profile.get("gems", player_data.gems)
	player_data.combat_power = profile.get("combatPower", player_data.combat_power)

	# 免费刷新
	var fc = profile.get("freeRefreshCount", null)
	if fc != null:
		free_refresh_count = int(fc)
	var newbie_fc = profile.get("newbieFreeRefreshCount", null)
	if newbie_fc != null:
		newbie_free_refresh_count = int(newbie_fc)
	var last_free_time = profile.get("lastFreeRefreshTime", null)
	if last_free_time is String:
		last_free_refresh_time_unix = _parse_server_time_unix(last_free_time)
	free_refresh_max_count = mini(player_data.level, 40)
	_update_free_refresh_cooldown_from_state()

	player_data.changed.emit()
	data_synced.emit()
	_cache_loaded["profile"] = true

## 从 /user/level API 响应应用等级阈值信息
func _apply_level_info(level_info: Dictionary) -> void:
	var lvl = level_info.get("level", player_data.level)
	var exp = level_info.get("exp", player_data.exp)
	exp_in_level = level_info.get("expInLevel", 0)
	exp_for_next = level_info.get("expForNext", 400)
	player_data.level = lvl
	player_data.exp = exp
	player_data.exp_in_level = exp_in_level
	player_data.exp_for_next = exp_for_next
	player_data.changed.emit()
	_cache_loaded["level"] = true

func is_cache_loaded(key: String) -> bool:
	return bool(_cache_loaded.get(key, false))

func _apply_card_slots(slot_type: String, slots: Array) -> void:
	match slot_type:
		"pool":
			player_data.pool_cards = ApiClient.card_slots_to_array_sorted(slots)
			player_data.pool_slots = _count_unlocked_slots(slots, player_data.pool_slots)
			CardPoolSystem.current_pool = player_data.pool_cards.duplicate()
			CardPoolSystem.pool_updated.emit(CardPoolSystem.current_pool)
		"hand":
			player_data.hand_cards = ApiClient.card_slots_to_array_sorted(slots)
			player_data.hand_slots = _count_unlocked_slots(slots, player_data.hand_slots)
		"vault":
			vault_raw_slot_data = slots.duplicate()
			player_data.vault_cards = ApiClient.card_slots_to_array_sorted(slots)
			player_data.vault_slots = _count_unlocked_slots(slots, player_data.vault_slots)
	_cache_loaded[slot_type] = true
	player_data.changed.emit()

func _count_unlocked_slots(slots: Array, fallback: int) -> int:
	var max_unlocked_index := -1
	for raw in slots:
		if not (raw is Dictionary):
			continue
		if not bool(raw.get("unlocked", false)):
			continue
		max_unlocked_index = maxi(max_unlocked_index, int(raw.get("slot_index", -1)))
	if max_unlocked_index < 0:
		return fallback
	return max_unlocked_index + 1

func _apply_decks(decks_data: Array) -> void:
	DeckSystem.player_decks.clear()
	for d in decks_data:
		DeckSystem.add_synthesized_deck(d)
	_cache_loaded["decks"] = true

## 同步全量数据（profile + level + 卡牌 + 套牌）
func sync_all_from_server() -> void:
	var started := Time.get_ticks_msec()
	FileLogger.log("开始同步服务端数据 (6路并行请求)")
	FileLogger.perf("full_sync_start")

	var base := ApiClient.get_api_base_url()
	var results := await ApiClient.batch_request([
		{"key": "profile", "url": base + "/user/profile"},
		{"key": "level", "url": base + "/player/level"},
		{"key": "pool", "url": base + "/game/cards?type=pool"},
		{"key": "hand", "url": base + "/game/cards?type=hand"},
		{"key": "vault", "url": base + "/game/cards?type=vault"},
		{"key": "decks", "url": base + "/game/decks"},
	])

	if results.get("profile", {}).get("success", false):
		apply_profile(results["profile"]["data"])
	else:
		FileLogger.warn("profile 同步失败: " + results.get("profile", {}).get("error", ""))

	if results.get("level", {}).get("success", false):
		_apply_level_info(results["level"]["data"])
	else:
		FileLogger.warn("等级同步失败: " + results.get("level", {}).get("error", ""))

	for slot_type in ["pool", "hand", "vault"]:
		var resp: Dictionary = results.get(slot_type, {})
		if resp.get("success", false):
			_apply_card_slots(slot_type, resp["data"])
		else:
			FileLogger.warn(slot_type + " 同步失败: " + resp.get("error", ""))

	if results.get("decks", {}).get("success", false):
		_apply_decks(results["decks"]["data"])
	else:
		FileLogger.warn("套牌同步失败: " + results.get("decks", {}).get("error", ""))

	FileLogger.perf("full_sync_done", {"total_ms": Time.get_ticks_msec() - started})
	data_synced.emit()

## 登录后首屏同步：只加载进入抽卡页必需的数据。
## 保险箱和博物馆在玩家进入对应页面时再加载，避免阻塞首屏。
func sync_initial_card_pool_from_server() -> void:
	var started := Time.get_ticks_msec()
	FileLogger.log("开始首屏同步 (profile + level + pool + hand 并行)")
	FileLogger.perf("login_initial_sync_start")

	var base := ApiClient.get_api_base_url()
	var results := await ApiClient.batch_request([
		{"key": "profile", "url": base + "/user/profile"},
		{"key": "level", "url": base + "/player/level"},
		{"key": "pool", "url": base + "/game/cards?type=pool"},
		{"key": "hand", "url": base + "/game/cards?type=hand"},
	])

	if results.get("profile", {}).get("success", false):
		apply_profile(results["profile"]["data"])
	else:
		FileLogger.warn("首屏 profile 同步失败: " + results.get("profile", {}).get("error", ""))

	if results.get("level", {}).get("success", false):
		_apply_level_info(results["level"]["data"])
	else:
		FileLogger.warn("首屏等级同步失败: " + results.get("level", {}).get("error", ""))

	for slot_type in ["pool", "hand"]:
		var resp: Dictionary = results.get(slot_type, {})
		if resp.get("success", false):
			_apply_card_slots(slot_type, resp["data"])
		else:
			FileLogger.warn("首屏 " + slot_type + " 同步失败: " + resp.get("error", ""))

	FileLogger.perf("login_initial_sync_done", {"total_ms": Time.get_ticks_msec() - started})
	data_synced.emit()

func sync_optional_login_data_background(include_config: bool = true) -> void:
	if _optional_login_sync_in_flight or not ApiClient.is_logged_in():
		return
	_optional_login_sync_in_flight = true
	var started := Time.get_ticks_msec()
	FileLogger.perf("login_optional_tasks_start", {"include_config": include_config})

	var base := ApiClient.get_api_base_url()
	var requests: Array[Dictionary] = [
		{"key": "profile", "url": base + "/user/profile", "timeout": 20.0},
		{"key": "level", "url": base + "/player/level", "timeout": 20.0},
		{"key": "vault", "url": base + "/game/cards?type=vault", "timeout": 20.0},
		{"key": "decks", "url": base + "/game/decks", "timeout": 20.0},
		{"key": "daily", "url": base + "/signin", "method": HTTPClient.METHOD_POST, "body": "{}", "timeout": 20.0},
	]
	if include_config:
		requests.append({"key": "config", "url": base + "/game/config", "timeout": 20.0})

	var results := await ApiClient.batch_request(requests)

	var profile_resp: Dictionary = results.get("profile", {})
	if profile_resp.get("success", false):
		apply_profile(profile_resp["data"])
	else:
		FileLogger.warn("登录后台 profile 同步失败: " + profile_resp.get("error", ""))

	var level_resp: Dictionary = results.get("level", {})
	if level_resp.get("success", false):
		_apply_level_info(level_resp["data"])
	else:
		FileLogger.warn("登录后台等级同步失败: " + level_resp.get("error", ""))

	var vault_resp: Dictionary = results.get("vault", {})
	if vault_resp.get("success", false):
		_apply_card_slots("vault", vault_resp["data"])
	else:
		FileLogger.warn("登录后台保险箱同步失败: " + vault_resp.get("error", ""))

	var decks_resp: Dictionary = results.get("decks", {})
	if decks_resp.get("success", false):
		_apply_decks(decks_resp["data"])
	else:
		FileLogger.warn("登录后台博物馆同步失败: " + decks_resp.get("error", ""))

	var daily_resp: Dictionary = results.get("daily", {})
	var daily_error := str(daily_resp.get("error", ""))
	if daily_resp.get("success", false):
		_apply_daily_reward(daily_resp["data"])
	elif daily_error.find("今日已签到") >= 0:
		FileLogger.log("登录后台每日奖励已检查: " + daily_error)
	else:
		FileLogger.warn("登录后台每日奖励检查失败: " + daily_error)

	if include_config:
		var config_resp: Dictionary = results.get("config", {})
		if config_resp.get("success", false):
			FileLogger.log("登录后台卡牌配置加载成功")
		else:
			FileLogger.warn("登录后台卡牌配置加载失败: " + config_resp.get("error", ""))

	_optional_login_sync_in_flight = false
	FileLogger.perf("login_optional_tasks_done", {
		"success": true,
		"total_ms": Time.get_ticks_msec() - started,
		"vault": vault_resp.get("success", false),
		"decks": decks_resp.get("success", false),
		"daily": daily_resp.get("success", false) or daily_error.find("今日已签到") >= 0,
		"profile": profile_resp.get("success", false),
		"level": level_resp.get("success", false),
		"config": results.get("config", {}).get("success", false) if include_config else null,
	})
	data_synced.emit()

func _apply_daily_reward(daily_data: Dictionary) -> void:
	if daily_data.has("newGold"):
		player_data.gold = int(str(daily_data.get("newGold", player_data.gold)))
	if daily_data.has("newGems"):
		player_data.gems = int(str(daily_data.get("newGems", player_data.gems)))
	player_data.changed.emit()

func sync_decks_from_server() -> void:
	var started := Time.get_ticks_msec()
	FileLogger.perf("new_data_request_start", {"page": "deck_panel"})
	var decks_resp := await ApiClient.get_decks()
	if decks_resp.get("success", false):
		_apply_decks(decks_resp["data"])
		FileLogger.log("博物馆套牌同步成功, 套牌数=" + str(decks_resp["data"].size()))
	else:
		FileLogger.warn("博物馆套牌同步失败: " + decks_resp.get("error", ""))
	FileLogger.perf("new_data_request_done", {"page": "deck_panel", "success": decks_resp.get("success", false), "total_ms": Time.get_ticks_msec() - started})
	data_synced.emit()

func sync_vault_from_server() -> void:
	var started := Time.get_ticks_msec()
	FileLogger.perf("new_data_request_start", {"page": "vault"})
	var vault_resp := await ApiClient.get_cards("vault")
	if vault_resp.get("success", false):
		_apply_card_slots("vault", vault_resp["data"])
		FileLogger.log("保险箱同步成功, 槽位数=" + str(player_data.vault_cards.size()))
	else:
		FileLogger.warn("保险箱同步失败: " + vault_resp.get("error", ""))
	FileLogger.perf("new_data_request_done", {"page": "vault", "success": vault_resp.get("success", false), "total_ms": Time.get_ticks_msec() - started})
	data_synced.emit()

func sync_reward_state_from_server() -> void:
	var started := Time.get_ticks_msec()
	FileLogger.perf("reward_state_sync_start")

	var base := ApiClient.get_api_base_url()
	var results := await ApiClient.batch_request([
		{"key": "profile", "url": base + "/user/profile"},
		{"key": "level", "url": base + "/player/level"},
		{"key": "pool", "url": base + "/game/cards?type=pool"},
		{"key": "hand", "url": base + "/game/cards?type=hand"},
		{"key": "vault", "url": base + "/game/cards?type=vault"},
	])

	if results.get("profile", {}).get("success", false):
		apply_profile(results["profile"]["data"])
	else:
		FileLogger.warn("奖励后 profile 同步失败: " + results.get("profile", {}).get("error", ""))

	if results.get("level", {}).get("success", false):
		_apply_level_info(results["level"]["data"])
	else:
		FileLogger.warn("奖励后等级同步失败: " + results.get("level", {}).get("error", ""))

	for slot_type in ["pool", "hand", "vault"]:
		var resp: Dictionary = results.get(slot_type, {})
		if resp.get("success", false):
			_apply_card_slots(slot_type, resp["data"])
		else:
			FileLogger.warn("奖励后 " + slot_type + " 同步失败: " + resp.get("error", ""))

	FileLogger.perf("reward_state_sync_done", {"total_ms": Time.get_ticks_msec() - started})
	data_synced.emit()

## 提交抽卡页内卡池/手牌临时布局。
## 仅同步 pool/hand 的位置，不处理保险箱、丢弃、合成等资产动作。
func sync_pool_hand_layout() -> Dictionary:
	if not ApiClient.is_logged_in():
		return {"success": true, "data": {"synced": false, "offline": true}}

	var pool_cards: Array = CardPoolSystem.current_pool
	if pool_cards.is_empty() and not player_data.pool_cards.is_empty():
		pool_cards = player_data.pool_cards

	var resp := await ApiClient.sync_pool_hand_layout(pool_cards, player_data.hand_cards)
	if not resp.get("success", false):
		var error := str(resp.get("error", ""))
		FileLogger.warn("卡池/手牌布局同步失败: " + error)
		if error.contains("临时布局与服务端卡牌集合不一致"):
			FileLogger.warn("检测到本地卡池/手牌缓存与服务端不一致，正在回源同步")
			await sync_initial_card_pool_from_server()
	return resp

func sync_pool_hand_layout_background(reason: String = "scene_switch") -> void:
	if _layout_sync_in_flight:
		return
	_layout_sync_in_flight = true
	var started := Time.get_ticks_msec()
	FileLogger.perf("old_data_upload_start", {"reason": reason})
	var resp := await sync_pool_hand_layout()
	FileLogger.perf("old_data_upload_done", {"reason": reason, "success": resp.get("success", false), "total_ms": Time.get_ticks_msec() - started})
	_layout_sync_in_flight = false

# ══════════════════════════════════════════════════
#  场景切换
# ══════════════════════════════════════════════════

func switch_scene(scene_name: String) -> void:
	current_view = scene_name
	scene_changed.emit(scene_name)

# ══════════════════════════════════════════════════
#  刷新管理
# ══════════════════════════════════════════════════

func _update_free_refresh_max() -> void:
	free_refresh_max_count = mini(player_data.level, 40)

func _on_free_refresh_timer() -> void:
	pass

## 尝试免费刷新（本地乐观扣除，服务端会验证）
func try_free_refresh() -> bool:
	if newbie_free_refresh_count > 0:
		_last_free_refresh_attempt_was_newbie = true
		newbie_free_refresh_count -= 1
		_update_free_refresh_cooldown_from_state()
		free_refresh_cooldown_updated.emit(free_refresh_cooldown)
		return true
	if free_refresh_count > 0:
		_last_free_refresh_attempt_was_newbie = false
		free_refresh_count -= 1
		if free_refresh_count < free_refresh_max_count:
			last_free_refresh_time_unix = Time.get_unix_time_from_system()
		_update_free_refresh_cooldown_from_state()
		free_refresh_cooldown_updated.emit(free_refresh_cooldown)
		return true
	return false

func rollback_free_refresh_attempt() -> void:
	if _last_free_refresh_attempt_was_newbie:
		newbie_free_refresh_count += 1
	else:
		free_refresh_count = mini(free_refresh_count + 1, free_refresh_max_count)
	_update_free_refresh_cooldown_from_state()
	free_refresh_cooldown_updated.emit(free_refresh_cooldown)

## 尝试宝石刷新
func try_gem_refresh() -> bool:
	_last_gem_refresh_attempt_cost = 5
	if player_data.spend_gems(5):
		return true
	_last_gem_refresh_attempt_cost = 0
	return false

## 尝试金币刷新  
func try_gold_refresh() -> bool:
	var cost = maxi(1, int(player_data.gold * 0.01))
	_last_gold_refresh_attempt_cost = cost
	if player_data.spend_gold(cost):
		return true
	_last_gold_refresh_attempt_cost = 0
	return false

func rollback_gem_refresh_attempt() -> void:
	if _last_gem_refresh_attempt_cost > 0:
		player_data.add_gems(_last_gem_refresh_attempt_cost)
	_last_gem_refresh_attempt_cost = 0

func rollback_gold_refresh_attempt() -> void:
	if _last_gold_refresh_attempt_cost > 0:
		player_data.add_gold(_last_gold_refresh_attempt_cost)
	_last_gold_refresh_attempt_cost = 0

func get_free_refresh_remaining() -> int:
	return newbie_free_refresh_count if newbie_free_refresh_count > 0 else free_refresh_count

func is_using_newbie_free_refreshes() -> bool:
	return newbie_free_refresh_count > 0

func get_free_refresh_cooldown() -> float:
	return free_refresh_cooldown

func _update_free_refresh_cooldown_from_state() -> void:
	if newbie_free_refresh_count > 0 or free_refresh_count >= free_refresh_max_count:
		free_refresh_cooldown = 0.0
		return
	if last_free_refresh_time_unix <= 0.0:
		free_refresh_cooldown = 0.0
		return
	var next_refresh_unix := last_free_refresh_time_unix + 60.0
	free_refresh_cooldown = maxf(0.0, next_refresh_unix - Time.get_unix_time_from_system())

func _recover_one_free_refresh_local() -> void:
	if newbie_free_refresh_count > 0 or free_refresh_count >= free_refresh_max_count:
		return
	free_refresh_count = mini(free_refresh_count + 1, free_refresh_max_count)
	last_free_refresh_time_unix = Time.get_unix_time_from_system()
	_update_free_refresh_cooldown_from_state()
	free_refresh_ready.emit()
	free_refresh_cooldown_updated.emit(free_refresh_cooldown)

func _parse_server_time_unix(value: String) -> float:
	var normalized := value.strip_edges()
	if normalized == "":
		return 0.0
	normalized = normalized.replace("Z", "")
	var dot_idx := normalized.find(".")
	if dot_idx >= 0:
		normalized = normalized.substr(0, dot_idx)
	var offset_idx := normalized.find("+", 10)
	if offset_idx < 0:
		offset_idx = normalized.find("-", 10)
	if offset_idx >= 0:
		normalized = normalized.substr(0, offset_idx)
	return float(Time.get_unix_time_from_datetime_string(normalized))

## 经验获取（从服务器响应同步）
func on_exp_gained(amount: int) -> void:
	player_data.exp += amount
	player_data.changed.emit()
	# 通知服务端并等待新数据
	sync_level_info_async()

## 异步刷新等级信息（获取经验/升级后的最新阈值）
func sync_level_info_async() -> void:
	var resp: Dictionary = await ApiClient.get_level_info()
	if resp.get("success", false):
		_apply_level_info(resp["data"])

# ══════════════════════════════════════════════════
#  槽位解锁管理
# ══════════════════════════════════════════════════

## 处理槽位解锁请求（由 CardSlotUI 的 slot_unlock_requested 信号触发）
func handle_unlock_slot(type: String, index: int) -> void:
	if type != "vault":
		print("[GameManager] 卡池和手牌槽位由等级或系统奖励解锁")
		return

	var resp := await ApiClient.unlock_slot(type, index)
	if not resp.get("success", false):
		print("[GameManager] 保险箱槽位购买失败: " + str(resp.get("error", "未知错误")))
		await sync_vault_from_server()
		return

	var profile_resp := await ApiClient.get_profile()
	if profile_resp.get("success", false):
		apply_profile(profile_resp["data"])
	await sync_vault_from_server()
