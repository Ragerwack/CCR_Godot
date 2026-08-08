extends Node

func _ready() -> void:
	Localization.set_locale("zh-CN")
	var original_level := GameManager.player_data.level
	var original_combat_power := GameManager.player_data.combat_power
	GameManager.player_data.level = 7
	GameManager.player_data.combat_power = 128

	var player_info := PlayerInfoUI.new()
	player_info.size = Vector2(320, 240)
	add_child(player_info)
	await get_tree().process_frame

	var level_host := player_info.find_child("LevelLabelHost", true, false) as Control
	var combat_host := player_info.find_child("CombatPowerLabelHost", true, false) as Control
	var level_roll := player_info.find_child("LevelNumberRoll", true, false) as AssetNumberRoll
	var combat_roll := player_info.find_child("CombatPowerNumberRoll", true, false) as AssetNumberRoll
	var player_id_label := player_info.find_child("PlayerIdLabel", true, false) as Label
	if level_host == null or combat_host == null or level_roll == null or combat_roll == null or player_id_label == null:
		_fail("player identity or stat roll nodes are missing")
		return
	if not level_host.clip_contents or not combat_host.clip_contents:
		_fail("player stat flip hosts do not clip the moving digits")
		return
	if not _color_close(player_id_label.get_theme_color("font_color"), Color.BLACK) or not _all_roll_digits_black([level_roll, combat_roll]):
		_fail("player identity or stat text is not black")
		return
	if level_roll.get_display_text() != Localization.t("ui.player.level_short", [7]) or combat_roll.get_display_text() != Localization.t("ui.player.combat_power_short", [128]):
		_fail("player stat rolls initial text wrong")
		return
	if not _assert_roll_digit_centers(level_roll, "level_initial") or not _assert_roll_digit_centers(combat_roll, "combat_initial"):
		return

	GameManager.player_data.level = 8
	GameManager.apply_confirmed_synthesis_combat_power({
		"combat_power": 128,
		"combat_power_added": 128,
	})
	GameManager.player_data.changed.emit()
	await get_tree().process_frame

	if level_roll.get_moving_current_digit_count() != 1:
		_fail("level change should roll exactly one digit")
		return
	if combat_roll.get_moving_current_digit_count() != 3:
		_fail("combat power change should roll all three digits")
		return
	if level_roll.get_visible_outgoing_digit_count() != 1 or combat_roll.get_visible_outgoing_digit_count() != 3:
		_fail("stat outgoing digits should remain visible during roll")
		return
	if not _level_prefix_static(level_roll):
		_fail("level Lv prefix should stay static while digit rolls")
		return
	if _first_moving_digit_y(level_roll) <= 0.0 or _first_moving_digit_y(combat_roll) <= 0.0:
		_fail("player stat gain should roll upward from below")
		return
	# 合成奖励或后台 profile 同步可能在动画期间再次发出同值刷新，不能取消翻转。
	GameManager.player_data.changed.emit()
	await get_tree().process_frame
	if combat_roll.get_visible_outgoing_digit_count() != 3 or combat_roll.get_moving_current_digit_count() != 3:
		_fail("same-value refresh cancelled the combat power roll animation")
		return
	await get_tree().create_timer(0.12).timeout
	if OS.get_environment("CCR_PLAYER_STAT_FLIP_SCREENSHOT_PATH") != "":
		await RenderingServer.frame_post_draw
	if not _save_screenshot():
		return

	await get_tree().create_timer(PlayerInfoUI.STAT_FLIP_DURATION + 0.08).timeout
	await get_tree().process_frame
	if level_roll.get_visible_outgoing_digit_count() != 0 or combat_roll.get_visible_outgoing_digit_count() != 0:
		_fail("temporary stat outgoing digits were not cleaned up")
		return
	if level_roll.get_moving_current_digit_count() != 0 or combat_roll.get_moving_current_digit_count() != 0:
		_fail("player stat roll animation state did not finish")
		return
	if level_roll.get_display_text() != Localization.t("ui.player.level_short", [8]) or combat_roll.get_display_text() != Localization.t("ui.player.combat_power_short", [256]):
		_fail("level or combat power did not settle on the new value")
		return
	if not _assert_roll_digit_centers(level_roll, "level_settled") or not _assert_roll_digit_centers(combat_roll, "combat_settled"):
		return

	GameManager.player_data.level = original_level
	GameManager.player_data.combat_power = original_combat_power
	GameManager.player_data.changed.emit()
	print("PLAYER_STAT_FLIP_ANIMATION ok")
	get_tree().quit(0)

func _save_screenshot() -> bool:
	var screenshot_path := OS.get_environment("CCR_PLAYER_STAT_FLIP_SCREENSHOT_PATH")
	if screenshot_path == "":
		return true
	var screenshot := get_viewport().get_texture().get_image()
	if screenshot == null or screenshot.is_empty() or screenshot.save_png(screenshot_path) != OK:
		_fail("player stat flip screenshot could not be saved")
		return false
	return true

func _fail(message: String) -> void:
	push_error("PLAYER_STAT_FLIP_ANIMATION " + message)
	get_tree().quit(1)

func _color_close(actual: Color, expected: Color) -> bool:
	return is_equal_approx(actual.r, expected.r) and is_equal_approx(actual.g, expected.g) and is_equal_approx(actual.b, expected.b) and is_equal_approx(actual.a, expected.a)

func _all_roll_digits_black(rolls: Array) -> bool:
	for roll in rolls:
		if not (roll is AssetNumberRoll):
			return false
		for label in (roll as AssetNumberRoll).get_current_digit_labels():
			if not _color_close(label.get_theme_color("font_color"), Color.BLACK):
				return false
	return true

func _level_prefix_static(roll: AssetNumberRoll) -> bool:
	var labels := roll.get_current_digit_labels()
	if labels.size() < 4:
		return false
	for index in range(3):
		if absf(labels[index].position.y) > 0.01:
			return false
	return true

func _first_moving_digit_y(roll: AssetNumberRoll) -> float:
	for label in roll.get_current_digit_labels():
		if absf(label.position.y) > 0.01:
			return label.position.y
	return 0.0

func _assert_roll_digit_centers(roll: AssetNumberRoll, label: String) -> bool:
	var expected_center_y := INF
	for digit_label in roll.get_current_digit_labels():
		if digit_label.text == "":
			continue
		var center_y := digit_label.get_global_rect().get_center().y
		if expected_center_y == INF:
			expected_center_y = center_y
			continue
		if absf(center_y - expected_center_y) > 0.1:
			_fail("%s_digit_center_mismatch expected=%.2f actual=%.2f text=%s" % [
				label,
				expected_center_y,
				center_y,
				roll.get_display_text(),
			])
			return false
	if expected_center_y == INF:
		_fail("%s_digit_center_empty" % label)
		return false
	return true
