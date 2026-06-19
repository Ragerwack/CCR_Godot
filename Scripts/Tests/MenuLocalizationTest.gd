extends Node

const CountryCatalogScript = preload("res://Scripts/Data/CountryCatalog.gd")

func _ready() -> void:
	ApiClient.logout()
	Localization.set_locale("en")
	var main := MainUI.new()
	add_child(main)
	await get_tree().process_frame

	var menu_button: Button = main.get("_menu_button")
	var center_area: Control = main.get("_center_area")
	if menu_button == null or center_area == null or menu_button.z_index <= center_area.z_index:
		_fail("menu button is still covered by the center content")
		return

	var splash: Node = null
	for child in main.get_children():
		if child.has_method("_selected_country_code"):
			splash = child
			break
	if splash == null or splash.call("_selected_country_code") != "EARTH":
		_fail("registration nationality does not default to EARTH")
		return

	main.call("_set_game_ui_visible", true)
	menu_button.pressed.emit()
	await get_tree().process_frame
	if not _has_text(center_area, "Menu") or not _has_option_button(center_area):
		_fail("English menu or language selector is missing")
		return

	Localization.set_locale("zh-CN", true, 1)
	await get_tree().process_frame
	if not _has_text(center_area, "菜单"):
		_fail("menu did not refresh after language change")
		return

	var entries: Array[Dictionary] = CountryCatalogScript.localized_entries("en")
	if entries.is_empty() or entries[0].get("code", "") != "EARTH":
		_fail("country catalog does not default to EARTH")
		return
	var found_china := false
	for entry in entries:
		if entry.get("code", "") == "CN" and entry.get("label", "") == "China":
			found_china = true
			break
	if not found_china:
		_fail("country catalog is missing China/CN")
		return

	# 测试结束恢复首次启动默认语言，避免污染本机后续图形验证。
	Localization.set_locale("en")
	print("MENU_LOCALIZATION ok")
	get_tree().quit(0)

func _has_text(root: Node, expected: String) -> bool:
	for child in root.find_children("*", "Label", true, false):
		if child.text == expected:
			return true
	return false

func _has_option_button(root: Node) -> bool:
	return not root.find_children("*", "OptionButton", true, false).is_empty()

func _fail(message: String) -> void:
	push_error("MENU_LOCALIZATION " + message)
	get_tree().quit(1)
