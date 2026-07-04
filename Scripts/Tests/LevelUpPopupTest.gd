extends Node

const LEVEL_UP_POPUP_SCRIPT = preload("res://Scripts/UI/LevelUpPopupUI.gd")

func _ready() -> void:
	var captured: Dictionary = {}
	if not GameManager.player_leveled_up.is_connected(_capture_level_up):
		GameManager.player_leveled_up.connect(_capture_level_up.bind(captured))
	GameManager.player_data.level = 1
	GameManager._apply_level_info({
		"level": 2,
		"exp": 0,
		"expInLevel": 0,
		"expForNext": 500,
	})
	await get_tree().process_frame
	if int(captured.get("level", 0)) != 2:
		return _fail("level_signal_missing")
	var rewards: Array = captured.get("rewards", [])
	if rewards.is_empty() or not _has_reward_text(rewards, "金币"):
		return _fail("level_rewards_missing")

	captured.clear()
	GameManager._last_announced_level = 2
	GameManager.player_data.level = 2
	GameManager._cache_loaded["profile"] = true
	GameManager.apply_profile({
		"id": GameManager.player_data.user_id,
		"username": GameManager.player_data.nickname,
		"level": 3,
		"exp": 0,
	})
	await get_tree().process_frame
	if int(captured.get("level", 0)) != 3:
		return _fail("profile_level_signal_missing")

	captured.clear()
	GameManager._last_announced_level = 3
	GameManager.player_data.level = 3
	GameManager.player_data.gold = 200
	GameManager.player_data.gems = 60
	GameManager.player_data.hand_slots = 9
	GameManager.apply_exp_result({
		"old_level": 3,
		"new_level": 4,
		"old_exp": 900,
		"new_exp": 1400,
		"exp_in_level": 0,
		"exp_for_next": 700,
		"leveled_up": true,
		"rewards": [
			{"type": "slot", "slot_type": "hand", "slot_index": 9},
			{"type": "gold", "amount": 50},
			{"type": "gem", "amount": 5},
		],
	})
	await get_tree().process_frame
	if int(captured.get("level", 0)) != 4:
		return _fail("exp_result_level_signal_missing")
	rewards = captured.get("rewards", [])
	if not _has_reward_text(rewards, "金币 +50"):
		return _fail("exp_result_gold_missing")
	if not _has_reward_text(rewards, "宝石 +5"):
		return _fail("exp_result_gems_missing")
	if not _has_reward_text(rewards, "手牌卡槽 +1"):
		return _fail("exp_result_slot_missing")
	if GameManager.player_data.gold != 250 or GameManager.player_data.gems != 65 or GameManager.player_data.hand_slots != 10:
		return _fail("exp_result_local_state_wrong")

	var popup := LEVEL_UP_POPUP_SCRIPT.new()
	add_child(popup)
	popup.setup(4, rewards)
	await get_tree().process_frame
	var title := popup.find_child("LevelUpTitle", true, false) as Label
	var reward_label := popup.find_child("LevelUpRewards", true, false) as Label
	var panel := popup.find_child("LevelUpPanel", true, false) as Panel
	if title == null or title.text.find("4") < 0:
		return _fail("popup_title_wrong")
	if reward_label == null or reward_label.text.find("金币 +50") < 0 or reward_label.text.find("手牌卡槽 +1") < 0:
		return _fail("popup_rewards_wrong")
	if panel == null:
		return _fail("popup_panel_missing")
	var viewport_center := get_viewport().get_visible_rect().size * 0.5
	var panel_center := panel.get_global_rect().get_center()
	if panel_center.distance_to(viewport_center) > 2.0:
		return _fail("popup_not_centered")
	popup.dismissed.emit()
	popup.queue_free()
	await get_tree().process_frame
	print("LEVEL_UP_POPUP ok")
	get_tree().quit(0)

func _capture_level_up(level: int, rewards: Array[String], target: Dictionary) -> void:
	target["level"] = level
	target["rewards"] = rewards

func _has_reward_text(rewards: Array, text: String) -> bool:
	for reward in rewards:
		if str(reward).find(text) >= 0:
			return true
	return false

func _fail(reason: String) -> void:
	push_error("LEVEL_UP_POPUP " + reason)
	get_tree().quit(1)
