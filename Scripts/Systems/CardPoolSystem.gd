extends Node

signal pool_updated(cards: Array)
signal pool_filled(cards: Array)
signal refresh_failed(reason: String)
signal loading_started()
signal loading_completed()

var current_pool: Array = []
var visible_series: Array[String] = []
const WARM_ROLL_MAX_AGE_MS: int = 240000
const WARM_ROLL_CLICK_WAIT_MS: int = 450

var _warm_rolls: Dictionary = {}
var _warming_types: Dictionary = {}
var _warm_target_type: String = ""
var skip_confirm_after_preview_for_test: bool = false

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
	var draw_started := Time.get_ticks_msec()
	loading_started.emit()
	FileLogger.perf("draw_refresh_start", {"type": refresh_type})
	_warm_target_type = refresh_type
	_clear_warm_rolls_except(refresh_type)

	var old_pool_cards: Array = current_pool.duplicate(true)
	var old_hand_cards: Array = GameManager.player_data.hand_cards.duplicate(true)

	var roll_data := _take_warm_roll(refresh_type)
	var used_warm_roll := not roll_data.is_empty()
	if not used_warm_roll:
		var wait_started := Time.get_ticks_msec()
		while _has_any_warming_type() and Time.get_ticks_msec() - wait_started < WARM_ROLL_CLICK_WAIT_MS:
			await get_tree().process_frame
		roll_data = _take_warm_roll(refresh_type)
		used_warm_roll = not roll_data.is_empty()

	if not used_warm_roll:
		if _has_any_warming_type():
			_rollback_refresh_attempt(refresh_type)
			refresh_failed.emit("抽卡预热仍在进行，请稍后重试")
			loading_completed.emit()
			FileLogger.perf("draw_refresh_failed", {
				"type": refresh_type,
				"stage": "warm_pending",
				"total_ms": Time.get_ticks_msec() - draw_started,
			})
			return
		var prepare_resp := await _prepare_refresh_roll(refresh_type)
		if not prepare_resp.get("success", false):
			if _should_fallback_to_legacy_refresh(prepare_resp):
				await _refresh_pool_legacy(refresh_type, old_pool_cards, old_hand_cards, draw_started)
				return
			_rollback_refresh_attempt(refresh_type)
			refresh_failed.emit(prepare_resp.get("error", "生成抽卡随机数组失败"))
			loading_completed.emit()
			FileLogger.perf("draw_refresh_failed", {
				"type": refresh_type,
				"stage": "prepare",
				"total_ms": Time.get_ticks_msec() - draw_started,
			})
			return
		roll_data = prepare_resp["data"]

	var preview_slots := ApiClient.translate_refresh_roll_to_slots(
		roll_data,
		GameManager.player_data.level,
		GameManager.player_data.pool_slots
	)
	if preview_slots.is_empty():
		_rollback_refresh_attempt(refresh_type)
		refresh_failed.emit("抽卡随机数组翻译失败")
		loading_completed.emit()
		FileLogger.perf("draw_refresh_failed", {
			"type": refresh_type,
			"stage": "translate",
			"total_ms": Time.get_ticks_msec() - draw_started,
			"used_warm_roll": used_warm_roll,
		})
		return

	var render_started := Time.get_ticks_msec()
	current_pool = ApiClient.card_slots_to_array_sorted(preview_slots)
	GameManager.player_data.pool_cards = current_pool.duplicate()
	pool_updated.emit(current_pool)
	pool_filled.emit(current_pool)
	var preview_total_ms := Time.get_ticks_msec() - draw_started
	FileLogger.perf("draw_refresh_preview_done", {
		"type": refresh_type,
		"total_ms": preview_total_ms,
		"render_ms": Time.get_ticks_msec() - render_started,
		"used_warm_roll": used_warm_roll,
		"target_ms": 500,
	})
	if preview_total_ms > 500:
		FileLogger.warn("抽卡预览耗时超过 0.5 秒: " + str(preview_total_ms) + "ms type=" + refresh_type, "[PERF]")

	if skip_confirm_after_preview_for_test:
		loading_completed.emit()
		FileLogger.perf("draw_refresh_confirm_skipped", {
			"type": refresh_type,
			"reason": "perf_test",
			"total_ms": Time.get_ticks_msec() - draw_started,
		})
		return

	var confirm_started := Time.get_ticks_msec()
	var confirm_resp := await ApiClient.confirm_refresh_pool_roll(
		roll_data,
		preview_slots,
		old_pool_cards,
		old_hand_cards
	)
	if confirm_resp.get("success", false):
		var data: Dictionary = confirm_resp["data"]
		var cards_data: Array = data.get("cards", [])
		current_pool = ApiClient.card_slots_to_array_sorted(cards_data)
		GameManager.player_data.pool_cards = current_pool.duplicate()

		if data.get("profile", {}) is Dictionary:
			GameManager.apply_profile(data["profile"])
		else:
			await _sync_profile()

		pool_updated.emit(current_pool)
		pool_filled.emit(current_pool)
		loading_completed.emit()
		FileLogger.perf("draw_refresh_confirm_done", {
			"type": refresh_type,
			"success": true,
			"confirm_ms": Time.get_ticks_msec() - confirm_started,
			"total_ms": Time.get_ticks_msec() - draw_started,
		})
	else:
		_rollback_refresh_attempt(refresh_type)
		current_pool = old_pool_cards
		GameManager.player_data.pool_cards = old_pool_cards.duplicate()
		GameManager.player_data.hand_cards = old_hand_cards.duplicate()
		GameManager.player_data.changed.emit()
		pool_updated.emit(current_pool)
		await GameManager.sync_initial_card_pool_from_server()

		refresh_failed.emit(confirm_resp.get("error", "确认抽卡失败"))
		loading_completed.emit()
		FileLogger.perf("draw_refresh_confirm_done", {
			"type": refresh_type,
			"success": false,
			"confirm_ms": Time.get_ticks_msec() - confirm_started,
			"total_ms": Time.get_ticks_msec() - draw_started,
		})

func warm_refresh_roll(refresh_type: String = "free") -> void:
	if _get_warm_roll(refresh_type).size() > 0:
		return
	if bool(_warming_types.get(refresh_type, false)):
		return

	_warm_target_type = refresh_type
	_clear_warm_rolls_except(refresh_type)
	if _has_warming_type_except(refresh_type):
		FileLogger.perf("draw_roll_warm_skip", {"type": refresh_type, "reason": "other_warming"})
		return

	_warming_types[refresh_type] = true
	var warm_started := Time.get_ticks_msec()
	FileLogger.perf("draw_roll_warm_start", {"type": refresh_type})
	var resp := await _prepare_refresh_roll(refresh_type)
	_warming_types.erase(refresh_type)
	if _warm_target_type != refresh_type:
		FileLogger.perf("draw_roll_warm_done", {
			"type": refresh_type,
			"success": false,
			"reason": "stale_target",
			"total_ms": Time.get_ticks_msec() - warm_started,
		})
		if _warm_target_type != "":
			warm_refresh_roll.call_deferred(_warm_target_type)
		return
	if resp.get("success", false):
		_clear_warm_rolls_except(refresh_type)
		_store_warm_roll(refresh_type, resp["data"])
		FileLogger.perf("draw_roll_warm_done", {
			"type": refresh_type,
			"success": true,
			"total_ms": Time.get_ticks_msec() - warm_started,
		})
	else:
		FileLogger.perf("draw_roll_warm_done", {
			"type": refresh_type,
			"success": false,
			"error": resp.get("error", "unknown"),
			"status": resp.get("status_code", 0),
			"total_ms": Time.get_ticks_msec() - warm_started,
		})

func _prepare_refresh_roll(refresh_type: String) -> Dictionary:
	if GameManager.draw_key_version <= 0:
		var key_resp := await ApiClient.get_draw_key()
		if key_resp.get("success", false):
			GameManager.apply_draw_key(key_resp["data"])

	var prepare_resp := await ApiClient.prepare_refresh_pool_roll(refresh_type, GameManager.draw_key_version)
	if not prepare_resp.get("success", false):
		return prepare_resp

	var roll_data: Dictionary = prepare_resp["data"]
	if roll_data.get("key_stale", false):
		if roll_data.get("draw_key", {}) is Dictionary:
			GameManager.apply_draw_key(roll_data["draw_key"])
		prepare_resp = await ApiClient.prepare_refresh_pool_roll(refresh_type, GameManager.draw_key_version)
		if not prepare_resp.get("success", false):
			return prepare_resp
		roll_data = prepare_resp["data"]

	if roll_data.get("draw_key", {}) is Dictionary:
		GameManager.apply_draw_key(roll_data["draw_key"])
	return prepare_resp

func _store_warm_roll(refresh_type: String, roll_data: Dictionary) -> void:
	if roll_data.is_empty() or roll_data.get("key_stale", false):
		return
	_warm_rolls[refresh_type] = {
		"created_msec": Time.get_ticks_msec(),
		"roll": roll_data,
	}

func _take_warm_roll(refresh_type: String) -> Dictionary:
	var roll := _get_warm_roll(refresh_type)
	if not roll.is_empty():
		_warm_rolls.erase(refresh_type)
	return roll

func _get_warm_roll(refresh_type: String) -> Dictionary:
	if not _warm_rolls.has(refresh_type):
		return {}
	var entry = _warm_rolls[refresh_type]
	if not entry is Dictionary:
		_warm_rolls.erase(refresh_type)
		return {}
	var created_msec := int(entry.get("created_msec", 0))
	if created_msec <= 0 or Time.get_ticks_msec() - created_msec > WARM_ROLL_MAX_AGE_MS:
		_warm_rolls.erase(refresh_type)
		return {}
	var roll = entry.get("roll", {})
	if roll is Dictionary:
		return roll
	_warm_rolls.erase(refresh_type)
	return {}

func _clear_warm_rolls_except(refresh_type: String) -> void:
	for key in _warm_rolls.keys():
		if str(key) != refresh_type:
			_warm_rolls.erase(key)

func _has_any_warming_type() -> bool:
	for key in _warming_types.keys():
		if bool(_warming_types[key]):
			return true
	return false

func _has_warming_type_except(refresh_type: String) -> bool:
	for key in _warming_types.keys():
		if str(key) != refresh_type and bool(_warming_types[key]):
			return true
	return false

func _rollback_refresh_attempt(refresh_type: String) -> void:
	if refresh_type == "gem":
		GameManager.rollback_gem_refresh_attempt()
	elif refresh_type == "gold":
		GameManager.rollback_gold_refresh_attempt()
	elif refresh_type == "free":
		GameManager.rollback_free_refresh_attempt()

func _should_fallback_to_legacy_refresh(resp: Dictionary) -> bool:
	if int(resp.get("status_code", 0)) == 404:
		return true
	return str(resp.get("error_type", "")) == "http" and str(resp.get("error", "")).contains("接口不存在")

func _refresh_pool_legacy(refresh_type: String, old_pool_cards: Array, old_hand_cards: Array, draw_started: int) -> void:
	FileLogger.perf("draw_refresh_legacy_fallback_start", {"type": refresh_type})
	var sync_resp := await ApiClient.sync_pool_hand_layout(old_pool_cards, old_hand_cards)
	if not sync_resp.get("success", false):
		_rollback_refresh_attempt(refresh_type)
		current_pool = old_pool_cards
		GameManager.player_data.pool_cards = old_pool_cards.duplicate()
		GameManager.player_data.hand_cards = old_hand_cards.duplicate()
		GameManager.player_data.changed.emit()
		pool_updated.emit(current_pool)
		refresh_failed.emit(sync_resp.get("error", "刷新前同步卡池和手牌失败"))
		loading_completed.emit()
		FileLogger.perf("draw_refresh_failed", {
			"type": refresh_type,
			"stage": "legacy_sync",
			"total_ms": Time.get_ticks_msec() - draw_started,
		})
		return

	var resp := await ApiClient.refresh_pool(refresh_type)
	if resp.get("success", false):
		var cards_data: Array = resp.get("data", [])
		current_pool = ApiClient.card_slots_to_array_sorted(cards_data)
		GameManager.player_data.pool_cards = current_pool.duplicate()
		await _sync_profile()
		pool_updated.emit(current_pool)
		pool_filled.emit(current_pool)
		loading_completed.emit()
		FileLogger.perf("draw_refresh_legacy_fallback_done", {
			"type": refresh_type,
			"success": true,
			"total_ms": Time.get_ticks_msec() - draw_started,
		})
		return

	_rollback_refresh_attempt(refresh_type)
	current_pool = old_pool_cards
	GameManager.player_data.pool_cards = old_pool_cards.duplicate()
	GameManager.player_data.hand_cards = old_hand_cards.duplicate()
	GameManager.player_data.changed.emit()
	pool_updated.emit(current_pool)
	refresh_failed.emit(resp.get("error", "刷新卡池失败"))
	loading_completed.emit()
	FileLogger.perf("draw_refresh_legacy_fallback_done", {
		"type": refresh_type,
		"success": false,
		"status": resp.get("status_code", 0),
		"total_ms": Time.get_ticks_msec() - draw_started,
	})

## 同步玩家资料（刷新后）
func _sync_profile() -> void:
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
		current_pool[idx] = null

func add_card(card: CardInfo) -> bool:
	for i in range(GameManager.player_data.pool_slots):
		while current_pool.size() <= i:
			current_pool.append(null)
		if current_pool[i] == null:
			current_pool[i] = card
			pool_updated.emit(current_pool)
			return true
	return false

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
	current_pool[pool_idx] = null

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
