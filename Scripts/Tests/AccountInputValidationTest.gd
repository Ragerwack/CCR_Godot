extends Node

const AccountInputValidationScript = preload("res://Scripts/Data/AccountInputValidation.gd")

func _ready() -> void:
	if AccountInputValidationScript.username_error_key("星海_2026") != "":
		_fail("ordinary Chinese Game ID was rejected")
		return
	if AccountInputValidationScript.username_error_key("Collector_01") != "":
		_fail("ordinary Latin Game ID was rejected")
		return
	if AccountInputValidationScript.username_error_key("x") != "ui.account.status.id_length":
		_fail("short Game ID was not rejected")
		return
	if AccountInputValidationScript.username_error_key("bad-name") != "ui.account.status.id_format":
		_fail("invalid Game ID punctuation was not rejected")
		return
	if AccountInputValidationScript.email_error_key("player@example.com") != "":
		_fail("valid email was rejected")
		return
	if AccountInputValidationScript.email_error_key("not-an-email") != "ui.account.status.email_format":
		_fail("invalid email was accepted")
		return
	if AccountInputValidationScript.password_error_key("secret1") != "":
		_fail("valid password was rejected")
		return
	if AccountInputValidationScript.password_error_key("12345") != "ui.account.status.password_length":
		_fail("short password was accepted")
		return
	print("ACCOUNT_INPUT_VALIDATION ok")
	get_tree().quit(0)

func _fail(message: String) -> void:
	push_error("ACCOUNT_INPUT_VALIDATION failed: " + message)
	get_tree().quit(1)
