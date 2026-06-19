extends Node

signal pool_updated(cards: Array)
signal pool_filled(cards: Array)
signal refresh_failed(reason: String)
signal loading_started()
signal loading_completed()

var current_pool: Array = []
var visible_series: Array[String] = []
const WARM_ROLL_CLICK_WAIT_MS: int = 450
const WARM_ROLL_CACHE_KEY: String = "next"

var _warm_rolls: Dictionary = {}
var _warming_types: Dictionary = {}
var _confirm_in_flight: bool = false
var skip_confirm_after_preview_for_test: bool = false
var gold_draw_debug_click_started_msec: int = 0
var animate_next_pool_update: bool = false

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
	var debug_total_started := draw_started
	if refresh_type == "gold" and gold_draw_debug_click_started_msec > 0:
		debug_total_started = gold_draw_debug_click_started_msec
		gold_draw_debug_click_started_msec = 0
	loading_started.emit()
	FileLogger.perf("draw_refresh_start", {"type": refresh_type})
	var old_pool_cards: Array = current_pool.duplicate(true)
	var old_hand_cards: Array = GameManager.player_data.hand_cards.duplicate(true)
	var should_sync_layout := GameManager.is_pool_hand_layout_dirty()

	var step_started := Time.get_ticks_msec()
	var roll_data := _take_warm_roll(refresh_type)
	var used_warm_roll := not roll_data.is_empty()
	var warming_still_active := false
	if not used_warm_roll:
		var wait_started := Time.get_ticks_msec()
		while _has_any_warming_type() and Time.get_ticks_msec() - wait_started < WARM_ROLL_CLICK_WAIT_MS:
			await get_tree().process_frame
		roll_data = _take_warm_roll(refresh_type)
		used_warm_roll = not roll_data.is_empty()
		warming_still_active = _has_any_warming_type()

	_print_gold_draw_step(
		refresh_type,
		2,
		"done",
		"检查/等待预热 roll",
		step_started,
		debug_total_started,
		{
			"used_warm_roll": used_warm_roll,
			"warming_still_active": warming_still_active,
		}
	)

	if used_warm_roll:
		step_started = Time.get_ticks_msec()
		_print_gold_draw_step(
			refresh_type,
			3,
			"done",
			"复用已预热金币随机数组",
			step_started,
			debug_total_started,
			{"used_warm_roll": true}
		)
	else:
		step_started = Time.get_ticks_msec()
		var prepare_resp := await _prepare_refresh_roll(refresh_type)
		if not prepare_resp.get("success", false):
			_print_gold_draw_step(
				refresh_type,
				3,
				"failed",
				"获取金币抽卡随机数组",
				step_started,
				debug_total_started,
				{
					"error": prepare_resp.get("error", "unknown"),
					"status": prepare_resp.get("status_code", 0),
				}
			)
			if _should_fallback_to_legacy_refresh(prepare_resp):
				await _refresh_pool_legacy(refresh_type, old_pool_cards, old_hand_cards, draw_started, debug_total_started)
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
		_print_gold_draw_step(
			refresh_type,
			3,
			"done",
			"获取金币抽卡随机数组",
			step_started,
			debug_total_started,
			{"used_warm_roll": false}
		)

	step_started = Time.get_ticks_msec()
	var preview_slots := ApiClient.translate_refresh_roll_to_slots(
		roll_data,
		GameManager.player_data.level,
		GameManager.player_data.pool_slots
	)
	if preview_slots.is_empty():
		_print_gold_draw_step(
			refresh_type,
			4,
			"failed",
			"翻译随机数组为预览卡牌",
			step_started,
			debug_total_started
		)
		_rollback_refresh_attempt(refresh_type)
		refresh_failed.emit(Localization.t("error.draw.translating"))
		loading_completed.emit()
		FileLogger.perf("draw_refresh_failed", {
			"type": refresh_type,
			"stage": "translate",
			"total_ms": Time.get_ticks_msec() - draw_started,
			"used_warm_roll": used_warm_roll,
		})
		return
	_print_gold_draw_step(
		refresh_type,
		4,
		"done",
		"翻译随机数组为预览卡牌",
		step_started,
		debug_total_started,
		{"preview_slots": preview_slots.size()}
	)

	var render_started := Time.get_ticks_msec()
	current_pool = ApiClient.card_slots_to_array_sorted(preview_slots)
	GameManager.player_data.pool_cards = current_pool.duplicate()
	animate_next_pool_update = true
	pool_updated.emit(current_pool)
	pool_filled.emit(current_pool)
	_print_gold_draw_step(
		refresh_type,
		5,
		"done",
		"渲染金币抽卡预览",
		render_started,
		debug_total_started,
		{"cards": current_pool.size()}
	)
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

	# 预览已经完成，按钮和页面不再等待服务端最终确认；confirm 继续在后台收口资产状态。
	_confirm_in_flight = true
	loading_completed.emit()

	if skip_confirm_after_preview_for_test:
		step_started = Time.get_ticks_msec()
		_print_gold_draw_step(
			refresh_type,
			6,
			"done",
			"测试跳过服务端确认",
			step_started,
			debug_total_started
		)
		loading_completed.emit()
		FileLogger.perf("draw_refresh_confirm_skipped", {
			"type": refresh_type,
			"reason": "perf_test",
			"total_ms": Time.get_ticks_msec() - draw_started,
		})
		_confirm_in_flight = false
		return

	var confirm_started := Time.get_ticks_msec()
	var confirm_operation_id := ApiClient.new_operation_id("refresh_pool_confirm")
	var confirm_resp := await ApiClient.confirm_refresh_pool_roll(
		refresh_type,
		roll_data,
		preview_slots,
		old_pool_cards,
		old_hand_cards,
		should_sync_layout,
		confirm_operation_id
	)
	if confirm_resp.get("success", false):
		_print_gold_draw_step(
			refresh_type,
			6,
			"done",
			"服务端确认金币抽卡",
			confirm_started,
			debug_total_started
		)
		step_started = Time.get_ticks_msec()
		var data: Dictionary = confirm_resp["data"]
		var cards_data: Array = data.get("cards", [])
		current_pool = ApiClient.card_slots_to_array_sorted(cards_data)
		GameManager.player_data.pool_cards = current_pool.duplicate()
		var hand_data = data.get("hand", null)
		if hand_data is Array:
			GameManager.player_data.hand_cards = ApiClient.card_slots_to_array_sorted(hand_data)

		if data.get("profile", {}) is Dictionary:
			GameManager.apply_profile(data["profile"])
		else:
			await _sync_profile()
		GameManager.mark_pool_hand_layout_clean("draw_confirm")

		pool_updated.emit(current_pool)
		pool_filled.emit(current_pool)
		loading_completed.emit()
		_print_gold_draw_step(
			refresh_type,
			7,
			"done",
			"应用服务端最终状态",
			step_started,
			debug_total_started,
			{"cards": current_pool.size(), "gold": GameManager.player_data.gold}
		)
		FileLogger.perf("draw_refresh_confirm_done", {
			"type": refresh_type,
			"success": true,
			"confirm_ms": Time.get_ticks_msec() - confirm_started,
			"layout_sync_submitted": should_sync_layout,
			"total_ms": Time.get_ticks_msec() - draw_started,
		})
	else:
		_print_gold_draw_step(
			refresh_type,
			6,
			"failed",
			"服务端确认金币抽卡",
			confirm_started,
			debug_total_started,
			{
				"error": confirm_resp.get("error", "unknown"),
				"status": confirm_resp.get("status_code", 0),
			}
		)
		if ApiClient.is_network_uncertain_response(confirm_resp):
			await _handle_unknown_confirm_result(
				refresh_type,
				confirm_operation_id,
				confirm_resp,
				confirm_started,
				draw_started,
				debug_total_started,
				should_sync_layout
			)
			_confirm_in_flight = false
			loading_completed.emit()
			return

		step_started = Time.get_ticks_msec()
		_rollback_refresh_attempt(refresh_type)
		current_pool = old_pool_cards
		GameManager.player_data.pool_cards = old_pool_cards.duplicate()
		GameManager.player_data.hand_cards = old_hand_cards.duplicate()
		GameManager.player_data.changed.emit()
		pool_updated.emit(current_pool)
		await GameManager.sync_initial_card_pool_from_server()

		refresh_failed.emit(confirm_resp.get("error", "确认抽卡失败"))
		loading_completed.emit()
		_print_gold_draw_step(
			refresh_type,
			7,
			"done",
			"确认失败后回滚本地状态",
			step_started,
			debug_total_started,
			{"gold": GameManager.player_data.gold}
		)
		FileLogger.perf("draw_refresh_confirm_done", {
			"type": refresh_type,
			"success": false,
			"confirm_ms": Time.get_ticks_msec() - confirm_started,
			"layout_sync_submitted": should_sync_layout,
			"total_ms": Time.get_ticks_msec() - draw_started,
		})
	_confirm_in_flight = false
	loading_completed.emit()

func _handle_unknown_confirm_result(
	refresh_type: String,
	operation_id: String,
	confirm_resp: Dictionary,
	confirm_started: int,
	draw_started: int,
	debug_total_started: int,
	should_sync_layout: bool
) -> void:
	FileLogger.warn("抽卡确认网络状态未知，开始回源同步: operation_id=" + operation_id + " error=" + str(confirm_resp.get("error", "")), "[NET]")
	refresh_failed.emit(Localization.t("error.draw.reconciling"))

	var step_started := Time.get_ticks_msec()
	var sync_resp = await GameManager.sync_initial_card_pool_from_server()
	var sync_success := sync_resp is Dictionary and bool(sync_resp.get("success", false))
	if sync_success:
		current_pool = GameManager.player_data.pool_cards.duplicate()
		pool_updated.emit(current_pool)
		pool_filled.emit(current_pool)
		GameManager.mark_pool_hand_layout_clean("draw_confirm_reconciled")
		_print_gold_draw_step(
			refresh_type,
			7,
			"done",
			"确认状态未知后回源同步成功",
			step_started,
			debug_total_started,
			{"operation_id": operation_id}
		)
		FileLogger.perf("draw_refresh_confirm_done", {
			"type": refresh_type,
			"success": true,
			"reconciled": true,
			"operation_id": operation_id,
			"confirm_ms": Time.get_ticks_msec() - confirm_started,
			"layout_sync_submitted": should_sync_layout,
			"total_ms": Time.get_ticks_msec() - draw_started,
		})
		return

	GameManager.mark_pool_hand_layout_dirty("draw_confirm_unknown")
	_print_gold_draw_step(
		refresh_type,
		7,
		"failed",
		"确认状态未知后回源同步失败",
		step_started,
		debug_total_started,
		{"operation_id": operation_id}
	)
	FileLogger.warn("抽卡确认仍未能验证，保留本地预览等待后续同步修正: operation_id=" + operation_id, "[NET]")
	FileLogger.perf("draw_refresh_confirm_done", {
		"type": refresh_type,
		"success": false,
		"unknown": true,
		"operation_id": operation_id,
		"confirm_ms": Time.get_ticks_msec() - confirm_started,
		"layout_sync_submitted": should_sync_layout,
		"total_ms": Time.get_ticks_msec() - draw_started,
	})

func warm_refresh_roll(refresh_type: String = "free") -> void:
	if _get_warm_roll(refresh_type).size() > 0:
		return
	if _has_any_warming_type():
		return

	_warming_types[refresh_type] = true
	var warm_started := Time.get_ticks_msec()
	FileLogger.perf("draw_roll_warm_start", {"type": refresh_type})
	var resp := await _prepare_refresh_roll(refresh_type)
	_warming_types.erase(refresh_type)
	if resp.get("success", false):
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
	_warm_rolls[WARM_ROLL_CACHE_KEY] = {
		"roll": roll_data,
	}

func _take_warm_roll(refresh_type: String) -> Dictionary:
	var roll := _get_warm_roll(refresh_type)
	if not roll.is_empty():
		_warm_rolls.erase(WARM_ROLL_CACHE_KEY)
	return roll

func _get_warm_roll(refresh_type: String) -> Dictionary:
	if not _warm_rolls.has(WARM_ROLL_CACHE_KEY):
		return {}
	var entry = _warm_rolls[WARM_ROLL_CACHE_KEY]
	if not entry is Dictionary:
		_warm_rolls.erase(WARM_ROLL_CACHE_KEY)
		return {}
	var roll = entry.get("roll", {})
	if roll is Dictionary:
		var roll_draw_key = roll.get("draw_key", {})
		if not roll_draw_key is Dictionary or str(roll_draw_key.get("date_key", "")) != _beijing_date_key():
			_warm_rolls.erase(WARM_ROLL_CACHE_KEY)
			return {}
		var matrix: Array = roll.get("random_matrix", [])
		if matrix.size() < 16:
			_warm_rolls.erase(WARM_ROLL_CACHE_KEY)
			return {}
		return roll
	_warm_rolls.erase(WARM_ROLL_CACHE_KEY)
	return {}

func _beijing_date_key() -> String:
	var beijing_unix := int(Time.get_unix_time_from_system()) + 8 * 60 * 60
	var parts := Time.get_datetime_dict_from_unix_time(beijing_unix)
	return "%04d-%02d-%02d" % [int(parts.year), int(parts.month), int(parts.day)]

func _has_any_warming_type() -> bool:
	for key in _warming_types.keys():
		if bool(_warming_types[key]):
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

func _refresh_pool_legacy(refresh_type: String, old_pool_cards: Array, old_hand_cards: Array, draw_started: int, debug_total_started: int = -1) -> void:
	if debug_total_started < 0:
		debug_total_started = draw_started
	FileLogger.perf("draw_refresh_legacy_fallback_start", {"type": refresh_type})
	var step_started := Time.get_ticks_msec()
	var sync_resp := await ApiClient.sync_pool_hand_layout(old_pool_cards, old_hand_cards)
	if not sync_resp.get("success", false):
		_print_gold_draw_step(
			refresh_type,
			4,
			"failed",
			"旧接口回退前同步布局",
			step_started,
			debug_total_started,
			{"error": sync_resp.get("error", "unknown"), "status": sync_resp.get("status_code", 0)}
		)
		_rollback_refresh_attempt(refresh_type)
		current_pool = old_pool_cards
		GameManager.player_data.pool_cards = old_pool_cards.duplicate()
		GameManager.player_data.hand_cards = old_hand_cards.duplicate()
		GameManager.player_data.changed.emit()
		pool_updated.emit(current_pool)
		refresh_failed.emit(sync_resp.get("error", "刷新前同步卡池和手牌失败"))
		loading_completed.emit()
		_print_gold_draw_step(
			refresh_type,
			7,
			"done",
			"旧接口同步失败后回滚本地状态",
			step_started,
			debug_total_started,
			{"gold": GameManager.player_data.gold}
		)
		FileLogger.perf("draw_refresh_failed", {
			"type": refresh_type,
			"stage": "legacy_sync",
			"total_ms": Time.get_ticks_msec() - draw_started,
		})
		return
	_print_gold_draw_step(
		refresh_type,
		4,
		"done",
		"旧接口回退前同步布局",
		step_started,
		debug_total_started
	)

	step_started = Time.get_ticks_msec()
	var resp := await ApiClient.refresh_pool(refresh_type)
	if resp.get("success", false):
		_print_gold_draw_step(
			refresh_type,
			5,
			"done",
			"调用旧金币抽卡接口",
			step_started,
			debug_total_started
		)
		step_started = Time.get_ticks_msec()
		var cards_data: Array = resp.get("data", [])
		current_pool = ApiClient.card_slots_to_array_sorted(cards_data)
		GameManager.player_data.pool_cards = current_pool.duplicate()
		await _sync_profile()
		animate_next_pool_update = true
		pool_updated.emit(current_pool)
		pool_filled.emit(current_pool)
		loading_completed.emit()
		_print_gold_draw_step(
			refresh_type,
			6,
			"done",
			"应用旧接口返回状态",
			step_started,
			debug_total_started,
			{"cards": current_pool.size(), "gold": GameManager.player_data.gold}
		)
		_print_gold_draw_step(
			refresh_type,
			7,
			"done",
			"旧接口金币抽卡完成",
			Time.get_ticks_msec(),
			debug_total_started
		)
		FileLogger.perf("draw_refresh_legacy_fallback_done", {
			"type": refresh_type,
			"success": true,
			"total_ms": Time.get_ticks_msec() - draw_started,
		})
		return

	_print_gold_draw_step(
		refresh_type,
		5,
		"failed",
		"调用旧金币抽卡接口",
		step_started,
		debug_total_started,
		{"error": resp.get("error", "unknown"), "status": resp.get("status_code", 0)}
	)
	step_started = Time.get_ticks_msec()
	_rollback_refresh_attempt(refresh_type)
	current_pool = old_pool_cards
	GameManager.player_data.pool_cards = old_pool_cards.duplicate()
	GameManager.player_data.hand_cards = old_hand_cards.duplicate()
	GameManager.player_data.changed.emit()
	pool_updated.emit(current_pool)
	refresh_failed.emit(resp.get("error", "刷新卡池失败"))
	loading_completed.emit()
	_print_gold_draw_step(
		refresh_type,
		7,
		"done",
		"旧接口失败后回滚本地状态",
		step_started,
		debug_total_started,
		{"gold": GameManager.player_data.gold}
	)
	FileLogger.perf("draw_refresh_legacy_fallback_done", {
		"type": refresh_type,
		"success": false,
		"status": resp.get("status_code", 0),
		"total_ms": Time.get_ticks_msec() - draw_started,
	})

func _print_gold_draw_step(refresh_type: String, step: int, status: String, name: String, step_started: int, total_started: int, details: Dictionary = {}) -> void:
	if refresh_type != "gold":
		return
	var now := Time.get_ticks_msec()
	var parts: Array[String] = [
		"gold-draw step %d: %s" % [step, status],
		name,
		"step_ms=%d" % (now - step_started),
		"total_ms=%d" % (now - total_started),
	]
	var keys := details.keys()
	keys.sort()
	for key in keys:
		parts.append("%s=%s" % [str(key), str(details[key])])
	print(" | ".join(parts))

## 同步玩家资料（刷新后）
func _sync_profile() -> void:
	var profile_resp = await ApiClient.get_profile()
	if profile_resp["success"]:
		GameManager.apply_profile(profile_resp["data"])

## 消耗检查 + API 刷新
func do_refresh(type: String) -> bool:
	if _confirm_in_flight:
		refresh_failed.emit(Localization.t("error.draw.pending"))
		return false
	match type:
		"free":
			var ok = GameManager.try_free_refresh()
			if not ok:
				refresh_failed.emit(Localization.t("error.draw.no_stamina"))
			return ok
		"gem":
			return GameManager.try_gem_refresh()
		"gold":
			return GameManager.try_gold_refresh()
	return false

func has_pending_confirm() -> bool:
	return _confirm_in_flight

# ══════════════════════════════════════════════════
#  卡池本地操作
# ══════════════════════════════════════════════════

func remove_card(card: CardInfo) -> void:
	var idx = current_pool.find(card)
	if idx >= 0:
		current_pool[idx] = null
		GameManager.mark_pool_hand_layout_dirty("pool_remove")

func add_card(card: CardInfo) -> bool:
	for i in range(GameManager.player_data.pool_slots):
		while current_pool.size() <= i:
			current_pool.append(null)
		if current_pool[i] == null:
			current_pool[i] = card
			GameManager.mark_pool_hand_layout_dirty("pool_add")
			pool_updated.emit(current_pool)
			return true
	return false

# ══════════════════════════════════════════════════
#  移动到指定手牌槽位（纯本地，不调服务器）
# ══════════════════════════════════════════════════

func quick_move_to_hand(card: CardInfo, hand_slot_index: int = -1) -> void:
	var pool_idx = current_pool.find(card)
	if pool_idx < 0:
		refresh_failed.emit(Localization.t("error.card.not_in_pool"))
		return

	# 自动找第一个空手牌槽
	if hand_slot_index < 0:
		var hand_cards = GameManager.player_data.hand_cards
		for i in range(GameManager.player_data.hand_slots):
			if i >= hand_cards.size() or hand_cards[i] == null:
				hand_slot_index = i
				break
		if hand_slot_index < 0:
			refresh_failed.emit(Localization.t("error.card.hand_full"))
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

	GameManager.mark_pool_hand_layout_dirty("quick_pool_to_hand")
	GameManager.player_data.changed.emit()
	pool_updated.emit(current_pool)

# ══════════════════════════════════════════════════
#  从手牌移回卡池（纯本地，不调服务器）
# ══════════════════════════════════════════════════

func quick_move_from_hand_to_pool(card: CardInfo, hand_slot_index: int) -> void:
	var hand_cards = GameManager.player_data.hand_cards
	if hand_slot_index < 0 or hand_slot_index >= hand_cards.size():
		refresh_failed.emit(Localization.t("error.card.invalid_hand_slot"))
		return

	if hand_cards[hand_slot_index] == null or hand_cards[hand_slot_index] != card:
		refresh_failed.emit(Localization.t("error.card.not_in_hand_slot"))
		return

	# 找第一个空卡池槽
	var target_idx = -1
	for i in range(GameManager.player_data.pool_slots):
		if i >= current_pool.size() or current_pool[i] == null:
			target_idx = i
			break
	if target_idx < 0:
		refresh_failed.emit(Localization.t("error.card.pool_full"))
		return

	# 纯本地操作：从手牌移除 → 插入卡池槽位
	hand_cards[hand_slot_index] = null

	while current_pool.size() < target_idx:
		current_pool.append(null)
	if target_idx < current_pool.size():
		current_pool[target_idx] = card
	else:
		current_pool.append(card)

	GameManager.mark_pool_hand_layout_dirty("quick_hand_to_pool")
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
