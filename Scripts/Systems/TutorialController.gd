extends Node
class_name TutorialController

signal tutorial_completed

const TUTORIAL_VERSION := 1
const VALID_STATES := [
	"NOT_STARTED", "WAITING_DRAW_PAGE_READY", "HIGHLIGHT_STAMINA_DRAW",
	"WAITING_FIRST_DRAW_RESULT", "IDENTIFYING_COMPLETE_SET",
	"DRAGGING_CARD_1", "DRAGGING_CARD_2", "DRAGGING_CARD_3", "DRAGGING_CARD_4", "DRAGGING_CARD_5",
	"WAITING_COMPLETE_SET_READY", "HIGHLIGHT_SELECT_CARD", "HIGHLIGHT_FORGE_BUTTON",
	"WAITING_FORGE_RESULT", "WAITING_RELIC_ANIMATION_END", "HIGHLIGHT_MUSEUM_BUTTON",
	"WAITING_MUSEUM_PAGE_READY", "COMPLETED", "ERROR_RECOVERABLE",
]
const TARGET_REIDENTIFICATION_STATES := [
	"NOT_STARTED", "WAITING_DRAW_PAGE_READY", "HIGHLIGHT_STAMINA_DRAW",
	"WAITING_FIRST_DRAW_RESULT", "IDENTIFYING_COMPLETE_SET",
	"DRAGGING_CARD_1", "DRAGGING_CARD_2", "DRAGGING_CARD_3", "DRAGGING_CARD_4", "DRAGGING_CARD_5",
	"WAITING_COMPLETE_SET_READY", "HIGHLIGHT_SELECT_CARD", "HIGHLIGHT_FORGE_BUTTON",
]

var state := "NOT_STARTED"
var _main: MainUI = null
var _overlay: TutorialOverlay = null
var _card_pool: CardPoolUI = null
var _hand: HandAreaUI = null
var _nav: NavButtons = null
var _museum: DeckCollectionUI = null
var _target_cards_by_number: Dictionary = {}
var _draw_confirmed := false
var _draw_presentation_completed := false
var _drag_started_msec := 0
var _drag_retry_count := 0
var _queued_server_payload: Dictionary = {}
var _server_save_in_flight := false
var _controller_move_armed_number := 0

func setup(main_ui: MainUI, overlay: TutorialOverlay) -> void:
	_main = main_ui
	_overlay = overlay
	_connect_global_signals()
	_load_progress()
	if GameManager.player_data.tutorial_completed:
		state = "COMPLETED"
		_overlay.clear()
		return
	if state == "NOT_STARTED":
		_transition("WAITING_DRAW_PAGE_READY", "tutorial_started")
	_reconcile_real_state.call_deferred()

func bind_page(card_pool: CardPoolUI, hand: HandAreaUI, nav: NavButtons, museum: DeckCollectionUI = null) -> void:
	_card_pool = card_pool
	_hand = hand
	_nav = nav
	_museum = museum
	if is_instance_valid(_card_pool) and not _card_pool.draw_presentation_completed.is_connected(_on_draw_presentation_completed):
		_card_pool.draw_presentation_completed.connect(_on_draw_presentation_completed)
	if is_instance_valid(_hand):
		if not _hand.card_dragged.is_connected(_on_hand_card_dragged):
			_hand.card_dragged.connect(_on_hand_card_dragged)
		if not _hand.card_clicked.is_connected(_on_hand_card_clicked):
			_hand.card_clicked.connect(_on_hand_card_clicked)
	if is_instance_valid(_nav) and not _nav.nav_button_clicked.is_connected(_on_nav_clicked):
		_nav.nav_button_clicked.connect(_on_nav_clicked)
	_reconcile_real_state.call_deferred()

func on_view_changed(view_id: String, museum: DeckCollectionUI = null) -> void:
	_museum = museum
	if state == "HIGHLIGHT_MUSEUM_BUTTON" and view_id == "deck_panel":
		_transition("WAITING_MUSEUM_PAGE_READY", "tutorial_museum_clicked")
	_reconcile_real_state.call_deferred()

func on_forge_started() -> void:
	if state != "HIGHLIGHT_FORGE_BUTTON":
		return
	_log_event("tutorial_forge_clicked")
	_transition("WAITING_FORGE_RESULT")
	_overlay.clear()

func on_forge_confirmed(result: Dictionary) -> void:
	if state != "WAITING_FORGE_RESULT":
		return
	_store_relic_id(result)
	_transition("WAITING_RELIC_ANIMATION_END", "tutorial_forge_succeeded")

func on_forge_finished(success: bool, result: Dictionary) -> void:
	if not ["WAITING_FORGE_RESULT", "WAITING_RELIC_ANIMATION_END"].has(state):
		return
	if not success:
		_transition("HIGHLIGHT_FORGE_BUTTON", "tutorial_error", {"stage": "forge"})
		_show_forge_step()
		return
	_store_relic_id(result)
	if state == "WAITING_FORGE_RESULT":
		_log_event("tutorial_forge_succeeded")
	_transition("HIGHLIGHT_MUSEUM_BUTTON", "tutorial_relic_animation_completed")
	_show_museum_step()

func _store_relic_id(result: Dictionary) -> void:
	var deck: Dictionary = result.get("deck", {}) if result.get("deck", {}) is Dictionary else {}
	var relic_id := str(deck.get("relic_instance_id", ""))
	if not relic_id.is_empty():
		GameManager.player_data.tutorial_relic_instance_id = relic_id

func on_museum_page_ready() -> void:
	if state != "WAITING_MUSEUM_PAGE_READY":
		return
	if _museum_has_target_relic():
		_complete()

func handle_controller_action(action_id: String) -> bool:
	if state.begins_with("DRAGGING_CARD_") and action_id == ControllerInput.ACTION_DRAW_FREE:
		var number := int(state.trim_prefix("DRAGGING_CARD_"))
		var card: CardInfo = _target_cards_by_number.get(number)
		if card == null or not is_instance_valid(_card_pool) or not is_instance_valid(_hand):
			return true
		var source := _card_pool.get_card_slot_for_card(card)
		var target := _hand.get_first_empty_drop_slot()
		if source == null or target == null:
			return true
		if _controller_move_armed_number != number:
			_controller_move_armed_number = number
			_drag_started_msec = Time.get_ticks_msec()
			_log_event("tutorial_card_drag_started", {"card_number": number, "card_instance_id": card.get_instance_ref(), "retry_count": _drag_retry_count, "input": "controller"})
			target.grab_focus()
			_overlay.configure([target], "ui.tutorial.controller_move")
			return true
		_controller_move_armed_number = 0
		_hand.controller_move_from_pool(card, source.slot_data_index, target)
		return true
	if state == "HIGHLIGHT_SELECT_CARD" and action_id == ControllerInput.ACTION_DRAW_FREE:
		var focus_owner := get_viewport().gui_get_focus_owner()
		if focus_owner is CardSlotUI:
			(focus_owner as CardSlotUI).controller_activate()
		return true
	if state == "HIGHLIGHT_FORGE_BUTTON" and action_id == ControllerInput.ACTION_SYNTHESIZE:
		_main.call("_on_hand_synthesize")
		return true
	if state == "HIGHLIGHT_MUSEUM_BUTTON" and action_id == ControllerInput.ACTION_DRAW_FREE:
		var button := _nav.get_button("deck_panel") if is_instance_valid(_nav) else null
		if button != null:
			button.emit_signal("pressed")
		return true
	return false

func _connect_global_signals() -> void:
	# 教程步骤以真实资产位置为准。双击快速移动不会发出 card_dragged，但一定会更新
	# PlayerData；延迟到本帧输入链结束后再核对，可同时兼容拖拽、双击和未来移动入口。
	if not GameManager.player_data.changed.is_connected(_on_player_data_changed):
		GameManager.player_data.changed.connect(_on_player_data_changed)
	if not CardPoolSystem.refresh_request_started.is_connected(_on_refresh_request_started):
		CardPoolSystem.refresh_request_started.connect(_on_refresh_request_started)
	if not CardPoolSystem.refresh_confirmed.is_connected(_on_refresh_confirmed):
		CardPoolSystem.refresh_confirmed.connect(_on_refresh_confirmed)
	if not CardPoolSystem.refresh_failed.is_connected(_on_refresh_failed):
		CardPoolSystem.refresh_failed.connect(_on_refresh_failed)
	if not DragSystem.drag_started.is_connected(_on_drag_started):
		DragSystem.drag_started.connect(_on_drag_started)
	if not GameManager.data_synced.is_connected(_on_game_data_synced):
		GameManager.data_synced.connect(_on_game_data_synced)
	if is_instance_valid(_nav) and not _nav.nav_button_clicked.is_connected(_on_nav_clicked):
		_nav.nav_button_clicked.connect(_on_nav_clicked)

func _on_player_data_changed() -> void:
	if state.begins_with("DRAGGING_CARD_"):
		var expected := int(state.trim_prefix("DRAGGING_CARD_"))
		_advance_after_asset_change.call_deferred(expected)

func _advance_after_asset_change(expected: int) -> void:
	# 原生拖拽会在同一帧由 card_dragged 先完成并切到下一步，此处用原步骤编号去重。
	# 双击快速移动没有该信号，因此仍停在原步骤，由真实手牌状态在这里完成推进。
	if state != "DRAGGING_CARD_%d" % expected:
		return
	if _target_cards_by_number.is_empty():
		_reconcile_real_state()
		return
	var collected := _actual_collected_numbers()
	if not expected in collected:
		return
	_log_event("tutorial_card_drag_completed", {
		"card_number": expected,
		"card_instance_id": (_target_cards_by_number[expected] as CardInfo).get_instance_ref(),
		"retry_count": _drag_retry_count,
		"duration": 0.0,
		"input": "quick_move",
	})
	_drag_retry_count = 0
	GameManager.player_data.tutorial_collected_numbers = collected
	_save_local()
	_queue_server_save("tutorial_card_drag_completed", {"card_number": expected, "duration": 0.0, "input": "quick_move"})
	_show_current_drag_step()

func _load_progress() -> void:
	var server_state := GameManager.player_data.tutorial_state
	state = server_state if VALID_STATES.has(server_state) else "NOT_STARTED"
	var local = Config.get_value("tutorial", "player_%d" % GameManager.player_data.user_id, {})
	if local is Dictionary and int(local.get("tutorial_version", 0)) == TUTORIAL_VERSION:
		var local_state := str(local.get("tutorial_state", ""))
		if state == "NOT_STARTED" and VALID_STATES.has(local_state) and local_state != "COMPLETED":
			state = local_state
		_apply_local_target(local)
	_apply_player_target()

func _apply_local_target(local: Dictionary) -> void:
	# 本地快照只补全服务端缺失值。JSON null 不能传给 int()，旧或中断写入的空快照也不能
	# 覆盖服务端已经恢复出的目标。
	var local_definition = local.get("target_set_definition_id", null)
	if GameManager.player_data.tutorial_target_definition_id <= 0 and local_definition != null:
		var definition_id := int(local_definition)
		if definition_id > 0:
			GameManager.player_data.tutorial_target_definition_id = definition_id
	var local_color = local.get("target_color", null)
	if GameManager.player_data.tutorial_target_color.is_empty() and local_color != null:
		var target_color := str(local_color)
		if not target_color.is_empty():
			GameManager.player_data.tutorial_target_color = target_color
	var refs = local.get("target_card_instance_ids", [])
	if GameManager.player_data.tutorial_target_card_instance_ids.is_empty() and refs is Array and not refs.is_empty():
		GameManager.player_data.tutorial_target_card_instance_ids = refs.duplicate()
	var numbers = local.get("collected_numbers", [])
	if GameManager.player_data.tutorial_collected_numbers.is_empty() and numbers is Array:
		GameManager.player_data.tutorial_collected_numbers = numbers.duplicate()
	var local_relic = local.get("relic_instance_id", null)
	if GameManager.player_data.tutorial_relic_instance_id.is_empty() and local_relic != null:
		GameManager.player_data.tutorial_relic_instance_id = str(local_relic)

func _apply_player_target() -> void:
	_rebuild_target_cards_from_real_state()

func _reconcile_real_state() -> void:
	if state == "COMPLETED" or GameManager.player_data.tutorial_completed:
		if is_instance_valid(_overlay):
			_overlay.clear()
		return
	_rebuild_target_cards_from_real_state()
	var available_cards := CardPoolSystem.current_pool + GameManager.player_data.hand_cards
	if _target_cards_by_number.is_empty() and _pool_has_collectible_cards(available_cards) and state in TARGET_REIDENTIFICATION_STATES:
		if _identify_complete_set(available_cards):
			_log_event("tutorial_complete_set_found", {"recovered": true})
			_show_current_drag_step()
		else:
			_fail_recoverable("complete_set_missing_on_recovery")
		return
	if _museum_has_target_relic():
		if is_instance_valid(_main) and _main.get_current_view_id() == "deck_panel":
			_complete()
		else:
			_transition("HIGHLIGHT_MUSEUM_BUTTON")
			_show_museum_step()
		return
	var collected := _actual_collected_numbers()
	GameManager.player_data.tutorial_collected_numbers = collected
	if collected.size() == 5:
		if state in ["WAITING_COMPLETE_SET_READY", "HIGHLIGHT_SELECT_CARD", "HIGHLIGHT_FORGE_BUTTON", "WAITING_FORGE_RESULT", "WAITING_RELIC_ANIMATION_END"]:
			if state == "HIGHLIGHT_FORGE_BUTTON":
				_show_forge_step()
			elif state in ["WAITING_FORGE_RESULT", "WAITING_RELIC_ANIMATION_END"]:
				_overlay.clear()
			else:
				_transition("HIGHLIGHT_SELECT_CARD")
				_show_select_step()
			return
		_wait_for_complete_set_sync()
		return
	if not _target_cards_by_number.is_empty():
		_show_current_drag_step()
		return
	match state:
		"WAITING_DRAW_PAGE_READY", "NOT_STARTED": _show_draw_step()
		"HIGHLIGHT_STAMINA_DRAW": _show_draw_step()
		"WAITING_FIRST_DRAW_RESULT", "IDENTIFYING_COMPLETE_SET": _overlay.clear()
		"HIGHLIGHT_MUSEUM_BUTTON": _show_museum_step()
		"WAITING_MUSEUM_PAGE_READY": on_museum_page_ready()

func _pool_has_collectible_cards(cards: Array) -> bool:
	# 卡池数组会为已解锁空槽保留 null；数组非空不代表玩家已经完成首次抽卡。
	for card in cards:
		if card is CardInfo and card.deck_definition_id > 0 and card.card_number >= 1 and card.card_number <= 5:
			return true
	return false

func _on_game_data_synced() -> void:
	_reconcile_real_state.call_deferred()

func _show_draw_step() -> void:
	if not is_instance_valid(_card_pool):
		return
	var button := _card_pool.get_stamina_draw_button()
	if button == null or button.disabled or not button.is_visible_in_tree():
		return
	_transition("HIGHLIGHT_STAMINA_DRAW", "tutorial_draw_button_highlighted")
	_overlay.configure([button], "ui.tutorial.draw_first", [], false, TutorialOverlay.MESSAGE_PLACEMENT_LEFT)

func _on_refresh_request_started(refresh_type: String) -> void:
	if state != "HIGHLIGHT_STAMINA_DRAW" or refresh_type != "free":
		return
	_draw_confirmed = false
	_draw_presentation_completed = false
	_transition("WAITING_FIRST_DRAW_RESULT", "tutorial_first_draw_started")
	_overlay.clear()

func _on_refresh_confirmed(_cards: Array, refresh_type: String) -> void:
	if state != "WAITING_FIRST_DRAW_RESULT" or refresh_type != "free":
		return
	_draw_confirmed = true
	_try_identify_after_draw()

func _on_draw_presentation_completed(_cards: Array) -> void:
	if state != "WAITING_FIRST_DRAW_RESULT":
		return
	_draw_presentation_completed = true
	_try_identify_after_draw()

func _try_identify_after_draw() -> void:
	if not _draw_confirmed or not _draw_presentation_completed:
		return
	_transition("IDENTIFYING_COMPLETE_SET", "tutorial_first_draw_completed")
	if not _identify_complete_set(CardPoolSystem.current_pool):
		_fail_recoverable("complete_set_missing")
		return
	_log_event("tutorial_complete_set_found", {"definition_id": GameManager.player_data.tutorial_target_definition_id})
	_show_current_drag_step()

func _identify_complete_set(cards: Array) -> bool:
	var groups: Dictionary = {}
	for card in cards:
		if not card is CardInfo:
			continue
		var typed := card as CardInfo
		if typed.deck_definition_id <= 0 or typed.card_number < 1 or typed.card_number > 5:
			continue
		var key := "%d|%s" % [typed.deck_definition_id, CardColor.to_api_string(typed.color)]
		if not groups.has(key):
			groups[key] = {}
		if not groups[key].has(typed.card_number):
			groups[key][typed.card_number] = typed
	for key in groups:
		var by_number: Dictionary = groups[key]
		if by_number.size() < 5:
			continue
		_target_cards_by_number = by_number
		var first: CardInfo = by_number[1]
		GameManager.player_data.tutorial_target_definition_id = first.deck_definition_id
		GameManager.player_data.tutorial_target_color = CardColor.to_api_string(first.color)
		var refs: Array = []
		for number in range(1, 6):
			refs.append((by_number[number] as CardInfo).get_instance_ref())
		GameManager.player_data.tutorial_target_card_instance_ids = refs
		GameManager.player_data.tutorial_collected_numbers = []
		_save_local()
		_queue_server_save("tutorial_complete_set_found", {"definition_id": first.deck_definition_id})
		return true
	return false

func _rebuild_target_cards_from_real_state() -> void:
	var definition_id := GameManager.player_data.tutorial_target_definition_id
	var target_color := GameManager.player_data.tutorial_target_color
	if definition_id <= 0 or target_color.is_empty():
		return
	var rebuilt: Dictionary = {}
	for card in CardPoolSystem.current_pool + GameManager.player_data.hand_cards:
		if card is CardInfo and card.deck_definition_id == definition_id and CardColor.to_api_string(card.color) == target_color:
			if card.card_number >= 1 and card.card_number <= 5 and not rebuilt.has(card.card_number):
				rebuilt[card.card_number] = card
	if not rebuilt.is_empty():
		_target_cards_by_number = rebuilt

func _show_current_drag_step() -> void:
	var collected := _actual_collected_numbers()
	GameManager.player_data.tutorial_collected_numbers = collected
	var next_number := 1
	while next_number in collected and next_number <= 5:
		next_number += 1
	if next_number > 5:
		_wait_for_complete_set_sync()
		return
	var card: CardInfo = _target_cards_by_number.get(next_number)
	if card == null or not is_instance_valid(_card_pool) or not is_instance_valid(_hand):
		return
	var source := _card_pool.get_card_slot_for_card(card)
	var target := _hand.get_first_empty_drop_slot()
	if source == null or target == null:
		return
	_transition("DRAGGING_CARD_%d" % next_number)
	var message_key := "ui.tutorial.drag_first" if next_number == 1 else "ui.tutorial.drag_progress"
	var args: Array = [] if next_number == 1 else [collected.size(), 5]
	if ControllerInput.is_controller_active():
		message_key = "ui.tutorial.controller_drag"
		args = []
	_overlay.configure([source, target], message_key, args, next_number == 1)

func _on_drag_started(card: CardInfo, from: String) -> void:
	if not state.begins_with("DRAGGING_CARD_") or from != "pool":
		return
	var expected := int(state.trim_prefix("DRAGGING_CARD_"))
	if not _card_matches_target_number(card, expected):
		return
	_drag_started_msec = Time.get_ticks_msec()
	_log_event("tutorial_card_drag_started", {"card_number": expected, "card_instance_id": card.get_instance_ref(), "retry_count": _drag_retry_count})

func _on_hand_card_dragged(card: CardInfo, _to_slot: int) -> void:
	if not state.begins_with("DRAGGING_CARD_"):
		return
	var expected := int(state.trim_prefix("DRAGGING_CARD_"))
	if not _card_matches_target_number(card, expected):
		return
	var collected := _actual_collected_numbers()
	if not expected in collected:
		_drag_retry_count += 1
		_show_current_drag_step()
		return
	var duration := maxf(0.0, float(Time.get_ticks_msec() - _drag_started_msec) / 1000.0) if _drag_started_msec > 0 else 0.0
	_log_event("tutorial_card_drag_completed", {"card_number": expected, "card_instance_id": card.get_instance_ref(), "retry_count": _drag_retry_count, "duration": duration})
	_drag_retry_count = 0
	GameManager.player_data.tutorial_collected_numbers = collected
	_save_local()
	_queue_server_save("tutorial_card_drag_completed", {"card_number": expected, "duration": duration})
	_show_current_drag_step()

func _actual_collected_numbers() -> Array:
	var result: Array = []
	for card in GameManager.player_data.hand_cards:
		if card is CardInfo and _card_matches_target_number(card, card.card_number) and not card.card_number in result:
			result.append(card.card_number)
	result.sort()
	return result

func _card_matches_target_number(card: CardInfo, number: int) -> bool:
	return card != null and card.deck_definition_id == GameManager.player_data.tutorial_target_definition_id and CardColor.to_api_string(card.color) == GameManager.player_data.tutorial_target_color and card.card_number == number

func _wait_for_complete_set_sync() -> void:
	if state == "WAITING_COMPLETE_SET_READY":
		return
	_transition("WAITING_COMPLETE_SET_READY", "tutorial_five_cards_collected")
	_overlay.show_notice("ui.tutorial.complete_set")
	_sync_complete_set.call_deferred()

func _sync_complete_set() -> void:
	var response := await GameManager.sync_pool_hand_layout()
	if not response.get("success", false):
		_log_event("tutorial_error", {"stage": "complete_set_sync"})
		var timer := get_tree().create_timer(2.0)
		timer.timeout.connect(_sync_complete_set)
		return
	_transition("HIGHLIGHT_SELECT_CARD")
	_show_select_step()

func _show_select_step() -> void:
	var card: CardInfo = _target_cards_by_number.get(1)
	var slot := _hand.get_card_slot_for_card(card) if is_instance_valid(_hand) else null
	if slot != null:
		_overlay.configure([slot], "ui.tutorial.select_card")

func _on_hand_card_clicked(card: CardInfo) -> void:
	if state != "HIGHLIGHT_SELECT_CARD" or not _card_matches_target_number(card, card.card_number):
		return
	_log_event("tutorial_card_selected", {"card_number": card.card_number})
	_transition("HIGHLIGHT_FORGE_BUTTON", "tutorial_card_selected")
	_show_forge_step()

func _show_forge_step() -> void:
	if not is_instance_valid(_hand):
		return
	var button := _hand.get_synthesize_button()
	if button != null and not button.disabled:
		_overlay.configure([button], "ui.tutorial.forge", [], false, TutorialOverlay.MESSAGE_PLACEMENT_LEFT)

func _show_museum_step() -> void:
	if not is_instance_valid(_nav):
		return
	var button := _nav.get_button("deck_panel")
	if button != null and button.is_visible_in_tree():
		_overlay.configure([button], "ui.tutorial.museum")

func _on_nav_clicked(id: String) -> void:
	if state == "HIGHLIGHT_MUSEUM_BUTTON" and id == "deck_panel":
		_log_event("tutorial_museum_clicked")

func _museum_has_target_relic() -> bool:
	if GameManager.player_data.tutorial_target_definition_id <= 0:
		return false
	var color := CardColor.from_string(GameManager.player_data.tutorial_target_color)
	if is_instance_valid(_museum):
		return _museum.contains_relic(GameManager.player_data.tutorial_target_definition_id, color)
	for deck in DeckSystem.player_decks:
		if deck != null and int(deck.deck_def_id) == GameManager.player_data.tutorial_target_definition_id and int(deck.color) == int(color):
			return true
	return false

func _complete() -> void:
	state = "COMPLETED"
	GameManager.player_data.tutorial_state = state
	GameManager.player_data.tutorial_completed = true
	_save_local()
	_log_event("tutorial_completed")
	_queue_server_save("tutorial_completed")
	_overlay.show_notice("ui.tutorial.first_collectible")
	tutorial_completed.emit()

func _fail_recoverable(reason: String) -> void:
	state = "ERROR_RECOVERABLE"
	_save_local()
	_log_event("tutorial_error", {"reason": reason})
	_queue_server_save("tutorial_error", {"reason": reason})
	_overlay.show_notice("ui.tutorial.error_continue")

func _on_refresh_failed(reason: String) -> void:
	if state == "WAITING_FIRST_DRAW_RESULT":
		_transition("HIGHLIGHT_STAMINA_DRAW", "tutorial_error", {"stage": "draw", "reason": reason.left(128)})
		_show_draw_step()

func _transition(next_state: String, event: String = "", payload: Dictionary = {}) -> void:
	if not VALID_STATES.has(next_state):
		return
	state = next_state
	GameManager.player_data.tutorial_state = state
	_save_local()
	if not event.is_empty():
		_log_event(event, payload)
	_queue_server_save(event, payload)

func _log_event(event: String, payload: Dictionary = {}) -> void:
	var fields := payload.duplicate()
	fields["tutorial_state"] = state
	fields["tutorial_version"] = TUTORIAL_VERSION
	FileLogger.perf(event, fields)

func _save_local() -> void:
	if GameManager.player_data.user_id <= 0:
		return
	Config.set_value("tutorial", "player_%d" % GameManager.player_data.user_id, _progress_payload(false))

func _queue_server_save(event: String = "", event_payload: Dictionary = {}) -> void:
	if not ApiClient.is_logged_in():
		return
	_queued_server_payload = _progress_payload(true)
	if not event.is_empty():
		_queued_server_payload["event"] = event
		_queued_server_payload["event_payload"] = event_payload
	_flush_server_save.call_deferred()

func _flush_server_save() -> void:
	if _server_save_in_flight or _queued_server_payload.is_empty():
		return
	_server_save_in_flight = true
	while not _queued_server_payload.is_empty() and ApiClient.is_logged_in():
		var payload := _queued_server_payload.duplicate(true)
		_queued_server_payload.clear()
		var response := await ApiClient.update_tutorial_progress(payload)
		if not response.get("success", false):
			FileLogger.warn("新手引导进度服务端保存失败: " + str(response.get("error", "unknown")), "[TUTORIAL]")
			_queued_server_payload = payload
			break
	_server_save_in_flight = false

func _progress_payload(for_server: bool) -> Dictionary:
	var payload := {
		"tutorial_version": TUTORIAL_VERSION,
		"tutorial_state": state,
		"target_set_definition_id": GameManager.player_data.tutorial_target_definition_id if GameManager.player_data.tutorial_target_definition_id > 0 else null,
		"target_color": GameManager.player_data.tutorial_target_color if not GameManager.player_data.tutorial_target_color.is_empty() else null,
		"target_card_instance_ids": GameManager.player_data.tutorial_target_card_instance_ids.duplicate(),
		"collected_numbers": GameManager.player_data.tutorial_collected_numbers.duplicate(),
		"relic_instance_id": GameManager.player_data.tutorial_relic_instance_id if not GameManager.player_data.tutorial_relic_instance_id.is_empty() else null,
	}
	if not for_server:
		payload["tutorial_completed"] = state == "COMPLETED"
	return payload
