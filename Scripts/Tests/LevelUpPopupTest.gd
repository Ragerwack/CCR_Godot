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
	if rewards.is_empty() or str(rewards[0]).find("体力上限") < 0:
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

	var popup := LEVEL_UP_POPUP_SCRIPT.new()
	add_child(popup)
	popup.setup(2, rewards)
	await get_tree().process_frame
	var title := popup.find_child("LevelUpTitle", true, false) as Label
	var reward_label := popup.find_child("LevelUpRewards", true, false) as Label
	if title == null or title.text.find("2") < 0:
		return _fail("popup_title_wrong")
	if reward_label == null or reward_label.text.find("体力上限") < 0:
		return _fail("popup_rewards_wrong")
	popup.dismissed.emit()
	popup.queue_free()
	await get_tree().process_frame
	print("LEVEL_UP_POPUP ok")
	get_tree().quit(0)

func _capture_level_up(level: int, rewards: Array[String], target: Dictionary) -> void:
	target["level"] = level
	target["rewards"] = rewards

func _fail(reason: String) -> void:
	push_error("LEVEL_UP_POPUP " + reason)
	get_tree().quit(1)
