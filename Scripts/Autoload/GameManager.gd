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

# 解锁槽位 credit 计数（模拟：将来由服务端管理）
var unlock_credits_pool: int = 0
var unlock_credits_hand: int = 0
var unlock_credits_vault: int = 0

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

# ══════════════════════════════════════════════════
#  服务端数据同步
# ══════════════════════════════════════════════════

## 从登录响应设置玩家数据
func apply_login_user(user_data: Dictionary) -> void:
	# 映射 login 响应字段到 PlayerData
	player_data.nickname = user_data.get("username", "玩家")
	player_data.level = user_data.get("level", 1)
	player_data.exp = user_data.get("exp", 0)
	player_data.gold = user_data.get("gold", 100)
	player_data.gems = user_data.get("gems", 10)
	_update_free_refresh_max()
	player_data.changed.emit()
	# 登录后异步获取等级阈值信息
	sync_level_info_async()

## 从 profile 响应同步完整数据
func apply_profile(profile: Dictionary) -> void:
	player_data.nickname = profile.get("username", player_data.nickname)
	player_data.level = profile.get("level", player_data.level)
	player_data.exp = profile.get("exp", player_data.exp)
	player_data.gold = profile.get("gold", player_data.gold)
	player_data.gems = profile.get("gems", player_data.gems)
	player_data.combat_power = profile.get("combatPower", player_data.combat_power)

	# 免费刷新
	var fc = profile.get("freeRefreshCount", null)
	if fc is int:
		free_refresh_count = fc
	free_refresh_max_count = mini(player_data.level, 40)

	player_data.changed.emit()
	data_synced.emit()

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

## 同步全量数据（profile + level + 卡牌 + 套牌）
func sync_all_from_server() -> void:
	FileLogger.log("开始同步服务端数据 (6步顺序请求)")
	
	# 1. 获取 profile
	FileLogger.log("同步第1步: 获取 profile")
	var profile_resp := await ApiClient.get_profile()
	if profile_resp.get("success", false):
		apply_profile(profile_resp["data"])
		FileLogger.log("profile 同步成功")
	else:
		FileLogger.warn("profile 同步失败: " + profile_resp.get("error", ""))
	
	# 2. 获取等级信息
	FileLogger.log("同步第2步: 获取等级信息")
	var level_resp := await ApiClient.get_level_info()
	if level_resp.get("success", false):
		_apply_level_info(level_resp["data"])
		FileLogger.log("等级信息同步成功")
	else:
		FileLogger.warn("等级同步失败: " + level_resp.get("error", ""))
	
	# 3. 获取卡池
	FileLogger.log("同步第3步: 获取卡池")
	var pool_resp := await ApiClient.get_cards("pool")
	if pool_resp.get("success", false):
		player_data.pool_cards = ApiClient.card_slots_to_array_sorted(pool_resp["data"])
		player_data.changed.emit()
		FileLogger.log("卡池同步成功, 卡牌数=" + str(player_data.pool_cards.size()))
	else:
		FileLogger.warn("卡池同步失败: " + pool_resp.get("error", ""))
	
	# 4. 获取手牌
	FileLogger.log("同步第4步: 获取手牌")
	var hand_resp := await ApiClient.get_cards("hand")
	if hand_resp.get("success", false):
		player_data.hand_cards = ApiClient.card_slots_to_array_sorted(hand_resp["data"])
		player_data.changed.emit()
		FileLogger.log("手牌同步成功, 卡牌数=" + str(player_data.hand_cards.size()))
	else:
		FileLogger.warn("手牌同步失败: " + hand_resp.get("error", ""))
	
	# 5. 获取保险箱
	FileLogger.log("同步第5步: 获取保险箱")
	var vault_resp := await ApiClient.get_cards("vault")
	if vault_resp.get("success", false):
		player_data.vault_cards = ApiClient.card_slots_to_array_sorted(vault_resp["data"])
		player_data.changed.emit()
		FileLogger.log("保险箱同步成功, 卡牌数=" + str(player_data.vault_cards.size()))
	else:
		FileLogger.warn("保险箱同步失败: " + vault_resp.get("error", ""))
	
	# 6. 获取套牌
	FileLogger.log("同步第6步: 获取套牌")
	var decks_resp := await ApiClient.get_decks()
	if decks_resp.get("success", false):
		DeckSystem.player_decks.clear()
		for d in decks_resp["data"]:
			DeckSystem.add_synthesized_deck(d)
		FileLogger.log("套牌同步成功, 套牌数=" + str(decks_resp["data"].size()))
	else:
		FileLogger.warn("套牌同步失败: " + decks_resp.get("error", ""))
	
	FileLogger.log("全部同步完成")
	data_synced.emit()

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
	if free_refresh_count > 0:
		free_refresh_count -= 1
		return true
	return false

## 尝试宝石刷新
func try_gem_refresh() -> bool:
	if player_data.spend_gems(5):
		return true
	return false

## 尝试金币刷新  
func try_gold_refresh() -> bool:
	var cost = maxi(1, int(player_data.gold * 0.01))
	if player_data.spend_gold(cost):
		return true
	return false

func get_free_refresh_remaining() -> int:
	return free_refresh_count

func get_free_refresh_cooldown() -> float:
	return free_refresh_cooldown

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
	# 检查是否有对应区域的解锁 credit
	match type:
		"pool":
			if unlock_credits_pool <= 0:
				print("[GameManager] 无可用卡池解锁次数")
				return
			unlock_credits_pool -= 1
			# 更新卡池解锁槽位数
			if index + 1 > player_data.pool_slots:
				player_data.pool_slots = index + 1
		"hand":
			if unlock_credits_hand <= 0:
				print("[GameManager] 无可用手牌解锁次数")
				return
			unlock_credits_hand -= 1
			if index + 1 > player_data.hand_slots:
				player_data.hand_slots = index + 1
		"vault":
			if unlock_credits_vault <= 0:
				print("[GameManager] 无可用保险箱解锁次数")
				return
			unlock_credits_vault -= 1
			if index + 1 > player_data.vault_slots:
				player_data.vault_slots = index + 1
		_:
			print("[GameManager] 未知槽位类型: " + type)
			return

	# 通知服务端解锁槽位
	_send_unlock_slot_to_server(type, index)

	# 刷新全局 UI
	player_data.changed.emit()

func _send_unlock_slot_to_server(type: String, index: int) -> void:
	# 异步通知服务端；不阻塞 UI
	ApiClient.unlock_slot(type, index)
