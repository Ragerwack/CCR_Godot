extends Node

func _ready() -> void:
	Localization.set_locale("en")
	var splash := SplashScreenUI.new()
	add_child(splash)
	await get_tree().process_frame
	splash.call("_on_switch_mode")
	await get_tree().process_frame

	var username := splash.get("_username_input") as LineEdit
	var password := splash.get("_password_input") as LineEdit
	var email := splash.get("_email_input") as LineEdit
	var submit := splash.get("_submit_button") as Button
	var username_status := splash.find_child("RegisterUsernameStatus", true, false) as Label
	var password_status := splash.find_child("RegisterPasswordStatus", true, false) as Label
	var email_status := splash.find_child("RegisterEmailStatus", true, false) as Label
	if username == null or password == null or email == null or submit == null:
		_fail("registration controls are missing")
		return

	_set_text(username, "takenuser")
	_set_text(password, "secret1")
	_set_text(email, "new@example.com")
	await get_tree().create_timer(0.9).timeout
	if username_status.text != "This ID is unavailable" or password_status.text != "✓" or email_status.text != "✓" or not submit.disabled:
		_fail("taken username did not keep registration locked")
		return

	_set_text(username, "CosmicNan")
	await get_tree().create_timer(0.9).timeout
	if username_status.text != "✓" or email_status.text != "✓" or submit.disabled:
		_fail("all verified registration fields did not unlock submit")
		return

	_set_text(email, "used@example.com")
	await get_tree().create_timer(0.9).timeout
	if email_status.text != "This email is unavailable" or not submit.disabled:
		_fail("taken email did not lock registration")
		return

	splash.queue_free()
	await get_tree().process_frame
	GameManager.player_data.nickname = "CurrentName"
	GameManager.player_data.user_id = 1
	var main := MainUI.new()
	main.size = get_viewport().get_visible_rect().size
	add_child(main)
	await get_tree().process_frame
	main.call("_set_game_ui_visible", true)
	main.call("_show_settings")
	await get_tree().process_frame
	var profile_tab := main.find_child("ProfileSettingsTab", true, false) as Button
	if profile_tab == null:
		_fail("profile settings tab is missing")
		return
	profile_tab.pressed.emit()
	await get_tree().process_frame
	var profile_name := main.find_child("PlayerNameField", true, false) as LineEdit
	var profile_status := main.find_child("PlayerNameAvailabilityStatus", true, false) as Label
	var profile_save := main.find_child("PlayerNameSaveButton", true, false) as Button
	if profile_name == null or profile_status == null or profile_save == null:
		_fail("profile rename controls are missing")
		return
	_set_text(profile_name, "CosmicRenamed")
	await get_tree().create_timer(0.9).timeout
	if profile_status.text != "✓" or profile_save.disabled:
		_fail("available profile Game ID did not unlock save")
		return
	_set_text(profile_name, "takenuser")
	await get_tree().create_timer(0.9).timeout
	if profile_status.text != "This ID is unavailable" or not profile_save.disabled:
		_fail("taken profile Game ID did not lock save")
		return

	print("ACCOUNT_AVAILABILITY_UI ok")
	get_tree().quit(0)

func _set_text(field: LineEdit, value: String) -> void:
	field.text = value
	field.text_changed.emit(value)

func _fail(message: String) -> void:
	push_error("ACCOUNT_AVAILABILITY_UI failed: " + message)
	get_tree().quit(1)
