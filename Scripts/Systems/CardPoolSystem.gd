extends Node

signal pool_updated(cards: Array[CardInfo])
signal pool_filled(cards: Array[CardInfo])
signal refresh_failed(reason: String)
signal loading_started()
signal loading_completed()

var current_pool: Array[CardInfo] = []
var visible_series: Array[String] = []

func _ready() -> void:
	GameManager.pool_refreshed.connect(_on_pool_refresh)
	_update_visible_series()

func _update_visible_series() -> void:
	var lvl = GameManager.player_data.level
	var count = 2
	if lvl >= 2 and lvl <= 4: count = 3
	elif lvl >= 5 and lvl <= 9: count = 4
	elif lvl >= 10 and lvl <= 19: count = 5
	elif lvl >= 20 and lvl <= 29: count = 6
	elif lvl >= 30 and lvl <= 39: count = 7
	elif lvl >= 40: count = 8

	visible_series.clear()
	var all_series = CardDataManager.get_all_series()
	for i in range(mini(count, all_series.size())):
		visible_series.append(all_series[i].series_name)

# ══════════════════════════════════════════════════
#  从服务端刷新卡池
# ══════════════════════════════════════════════════

func refresh_pool(refresh_type: String = "free") -> void:
	loading_started.emit()

	var resp = await ApiClient.refresh_pool(refresh_type)
	if resp["success"]:
		var cards_data: Array = resp["data"]
		current_pool = ApiClient.card_slots_to_array_sorted(cards_data)
		GameManager.player_data.pool_cards = current_pool.duplicate()

		# 如果是付费刷新，同步 profile 获取最新余额
		if refresh_type == "gem" or refresh_type == "gold":
			await _sync_wallet()

		pool_updated.emit(current_pool)
		pool_filled.emit(current_pool)
		loading_completed.emit()
	else:
		# 刷新失败，回滚本地乐观扣款
		if refresh_type == "gem":
			GameManager.player_data.add_gems(5)
		elif refresh_type == "gold":
			var cost = maxi(1, int(GameManager.player_data.gold * 0.01))
			GameManager.player_data.add_gold(cost)
		elif refresh_type == "free":
			GameManager.free_refresh_count += 1

		refresh_failed.emit(resp["error"])
		loading_completed.emit()

## 同步钱包数据（刷新后）
func _sync_wallet() -> void:
	var profile_resp = await ApiClient.get_profile()
	if profile_resp["success"]:
		GameManager.apply_profile(profile_resp["data"])

## 消耗检查 + API 刷新
func do_refresh(type: String) -> bool:
	match type:
		"free":
			var ok = GameManager.try_free_refresh()
			if not ok:
				refresh_failed.emit("免费刷新次数已用完")
			return ok
		"gem":
			return GameManager.try_gem_refresh()
		"gold":
			return GameManager.try_gold_refresh()
	return false

# ══════════════════════════════════════════════════
#  卡池本地操作
# ══════════════════════════════════════════════════

func remove_card(card: CardInfo) -> void:
	var idx = current_pool.find(card)
	if idx >= 0:
		current_pool.remove_at(idx)

func add_card(card: CardInfo) -> bool:
	if current_pool.size() >= GameManager.player_data.pool_slots:
		return false
	current_pool.append(card)
	pool_updated.emit(current_pool)
	return true

# ══════════════════════════════════════════════════
#  移动到指定手牌槽位（纯本地，不调服务器）
# ══════════════════════════════════════════════════

func quick_move_to_hand(card: CardInfo, hand_slot_index: int = -1) -> void:
	var pool_idx = current_pool.find(card)
	if pool_idx < 0:
		refresh_failed.emit("卡牌不在当前卡池中")
		return

	# 自动找第一个空手牌槽
	if hand_slot_index < 0:
		var hand_cards = GameManager.player_data.hand_cards
		for i in range(GameManager.player_data.hand_slots):
			if i >= hand_cards.size() or hand_cards[i] == null:
				hand_slot_index = i
				break
		if hand_slot_index < 0:
			refresh_failed.emit("手牌槽已满")
			return

	# 纯本地操作：从卡池移除 → 插入手牌槽位
	current_pool.remove_at(pool_idx)

	var hand_cards = GameManager.player_data.hand_cards
	while hand_cards.size() < hand_slot_index:
		hand_cards.append(null)  # 填充空槽
	if hand_slot_index < hand_cards.size():
		hand_cards[hand_slot_index] = card
	else:
		hand_cards.append(card)

	GameManager.player_data.changed.emit()
	pool_updated.emit(current_pool)

# ══════════════════════════════════════════════════
#  从手牌移回卡池（纯本地，不调服务器）
# ══════════════════════════════════════════════════

func quick_move_from_hand_to_pool(card: CardInfo, hand_slot_index: int) -> void:
	var hand_cards = GameManager.player_data.hand_cards
	if hand_slot_index < 0 or hand_slot_index >= hand_cards.size():
		refresh_failed.emit("手牌槽位无效")
		return

	if hand_cards[hand_slot_index] == null or hand_cards[hand_slot_index] != card:
		refresh_failed.emit("卡牌不在此手牌槽位")
		return

	# 找第一个空卡池槽
	var target_idx = -1
	for i in range(GameManager.player_data.pool_slots):
		if i >= current_pool.size() or current_pool[i] == null:
			target_idx = i
			break
	if target_idx < 0:
		refresh_failed.emit("卡池已满")
		return

	# 纯本地操作：从手牌移除 → 插入卡池槽位
	hand_cards[hand_slot_index] = null

	while current_pool.size() < target_idx:
		current_pool.append(null)
	if target_idx < current_pool.size():
		current_pool[target_idx] = card
	else:
		current_pool.append(card)

	GameManager.player_data.changed.emit()
	pool_updated.emit(current_pool)

# ══════════════════════════════════════════════════
#  从服务端加载卡池数据
# ══════════════════════════════════════════════════

func load_pool_from_server() -> void:
	loading_started.emit()
	var resp = await ApiClient.get_cards("pool")
	if resp["success"]:
		current_pool = ApiClient.card_slots_to_array_sorted(resp["data"])
		GameManager.player_data.pool_cards = current_pool.duplicate()
		pool_updated.emit(current_pool)
	loading_completed.emit()

func _on_pool_refresh() -> void:
	pass
