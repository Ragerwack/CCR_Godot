extends Node

const CCRVisualStyle = preload("res://Scripts/UI/CCRVisualStyle.gd")
const TARGET_EMOJI := ["🔄", "💛", "💎", "◀", "▶", "⚗", "🗑", "📦", "✨", "✅", "❌"]
const ICON_EXPECTED_SIZES := {
	"nav_today_decks": 50, "nav_card_pool": 50, "nav_vault": 50,
	"nav_museum": 50, "nav_auction": 50, "nav_leaderboard": 50,
	"nav_mail": 50, "nav_settings": 50, "nav_exit": 50,
	"draw_stamina": 50, "draw_gold": 50, "draw_gem": 50,
	"action_page": 67, "action_synthesize": 67, "action_discard": 67, "action_store_vault": 67,
	"vault_expand_gold": 50, "vault_expand_gem": 50,
	"status_stamina": 50, "status_gold": 50, "status_gem": 50,
	"status_level": 18, "status_combat_power": 18, "status_experience": 14,
	"status_lock": 42,
}

var _failed := false

func _ready() -> void:
	get_window().size = Vector2i(1920, 1200)
	Localization.set_locale("zh-CN")
	_prepare_player_data()
	if not _assert_source_assets():
		return

	var main := MainUI.new()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	main.call("_set_game_ui_visible", true)

	if not _assert_navigation(main):
		return
	if not _assert_draw_and_hand(main):
		return
	if not _assert_status_icons(main):
		return
	if not await _assert_button_icon_hover_motion(main):
		return

	var nav_buttons := main.get("_nav_buttons") as NavButtons
	var card_pool_button := nav_buttons.find_child("NavButton_card_pool", false, false) as Button
	var original_icon_path := CCRVisualStyle.get_button_icon(card_pool_button).texture.resource_path
	Localization.set_locale("en")
	await get_tree().process_frame
	await get_tree().process_frame
	card_pool_button = nav_buttons.find_child("NavButton_card_pool", false, false) as Button
	var card_pool_icon := CCRVisualStyle.get_button_icon(card_pool_button)
	if card_pool_button == null or card_pool_icon == null or card_pool_icon.texture == null or card_pool_icon.texture.resource_path != original_icon_path:
		return _fail("locale_switch_changed_navigation_icon")
	if card_pool_button.text != "Draw":
		return _fail("locale_switch_did_not_refresh_navigation_text")

	main.call("_show_vault")
	await get_tree().process_frame
	await get_tree().process_frame
	if not _assert_vault(main):
		return
	if not _assert_max_resolution_metrics(main):
		return

	get_window().size = Vector2i(1280, 800)
	await get_tree().process_frame
	await get_tree().process_frame
	main.call("_refresh_layout_after_resize")
	await get_tree().process_frame
	if not _assert_steam_deck_metrics(main):
		return

	print("BUTTON_THEME_ICON ok assets=33 nav=9 draw=3 card_actions=4 vault=3 status=7")
	get_tree().quit(0)

func _prepare_player_data() -> void:
	GameManager.player_data.level = 8
	GameManager.player_data.combat_power = 125
	GameManager.player_data.gold = 1000
	GameManager.player_data.gems = 50
	GameManager.player_data.pool_slots = 16
	GameManager.player_data.hand_slots = 16
	GameManager.player_data.vault_slots = 16
	GameManager.player_data.pool_cards = []
	GameManager.player_data.hand_cards = []
	GameManager.player_data.vault_cards = []
	CardPoolSystem.current_pool = []
	for _index in range(16):
		GameManager.player_data.pool_cards.append(null)
		GameManager.player_data.hand_cards.append(null)
		GameManager.player_data.vault_cards.append(null)
		CardPoolSystem.current_pool.append(null)
	GameManager.vault_raw_slot_data = []

func _assert_source_assets() -> bool:
	for variant in ["navigation", "action"]:
		var paths: Dictionary = CCRVisualStyle.BUTTON_TEXTURE_PATHS[variant]
		var expected_size := Vector2i(256, 64) if variant == "navigation" else Vector2i(192, 64)
		for state in ["normal", "hover", "pressed", "disabled"]:
			var texture := load(str(paths[state])) as Texture2D
			if texture == null or texture.get_size() != Vector2(expected_size):
				return _fail("button_asset_wrong_%s_%s" % [variant, state])
			var image := texture.get_image()
			if image == null or image.get_pixel(0, 0).a > 0.1:
				return _fail("button_asset_alpha_missing_%s_%s" % [variant, state])
	for icon_id in CCRVisualStyle.ICON_PATHS.keys():
		var icon := CCRVisualStyle.icon(str(icon_id))
		var expected_icon_size := int(ICON_EXPECTED_SIZES.get(str(icon_id), 0))
		if icon == null or expected_icon_size <= 0 or icon.get_size() != Vector2(expected_icon_size, expected_icon_size):
			return _fail("icon_asset_wrong_%s" % str(icon_id))
		var image := icon.get_image()
		if image == null or image.get_pixel(0, 0).a > 0.1:
			return _fail("icon_asset_alpha_missing_%s" % str(icon_id))
	return true

func _assert_navigation(main: MainUI) -> bool:
	var nav_buttons := main.get("_nav_buttons") as NavButtons
	if nav_buttons == null or nav_buttons.buttons.size() != 9:
		return _fail("navigation_button_count_wrong")
	for index in range(nav_buttons.buttons.size()):
		var button := nav_buttons.buttons[index]
		var expected_icon := str(NavButtons.NAV_ITEMS[index]["icon_id"])
		if not _assert_button(button, expected_icon, "navigation"):
			return false
		if index in [4, 5, 6] and not button.disabled:
			return _fail("coming_soon_navigation_not_disabled_%d" % index)
	if not _assert_icon_column_aligned(nav_buttons.buttons, "navigation"):
		return false
	if nav_buttons.buttons[0].get_theme_font_size("font_size") < 13:
		return _fail("navigation_button_font_not_increased")
	nav_buttons.select_by_id("vault")
	var selected := nav_buttons.find_child("NavButton_vault", false, false) as Button
	if selected == null or not (selected.get_theme_stylebox("normal") is StyleBoxTexture):
		return _fail("selected_navigation_lost_texture_style")
	nav_buttons.select_by_id("card_pool")
	return true

func _assert_draw_and_hand(main: MainUI) -> bool:
	var center := main.get("_center_area") as Control
	var targets := {
		"DrawStaminaButton": "draw_stamina",
		"DrawGoldButton": "draw_gold",
		"DrawGemButton": "draw_gem",
		"HandPageButton": "action_page",
		"HandSynthesizeButton": "action_synthesize",
		"HandDiscardButton": "action_discard",
		"HandStoreVaultButton": "action_store_vault",
	}
	for node_name in targets:
		var button := center.find_child(str(node_name), true, false) as Button
		if button == null or not _assert_button(button, str(targets[node_name]), "action"):
			return _fail("draw_or_hand_button_missing_%s" % str(node_name))
	var action_buttons: Array[Button] = []
	for node_name in targets:
		action_buttons.append(center.find_child(str(node_name), true, false) as Button)
	if not _assert_icon_column_aligned(action_buttons, "action"):
		return false
	for button in action_buttons:
		if button.get_theme_font_size("font_size") < 15:
			return _fail("action_button_font_not_increased_%s" % button.name)
	return true

func _assert_vault(main: MainUI) -> bool:
	var center := main.get("_center_area") as Control
	var targets := {
		"VaultSynthesizeButton": "action_synthesize",
		"VaultExpandGoldButton": "vault_expand_gold",
		"VaultExpandGemButton": "vault_expand_gem",
	}
	for node_name in targets:
		var button := center.find_child(str(node_name), true, false) as Button
		if button == null or not _assert_button(button, str(targets[node_name]), "action"):
			return _fail("vault_button_missing_%s" % str(node_name))
	var locked_slot_icon := center.find_child("LockedSlotIcon", true, false) as TextureRect
	if locked_slot_icon == null or locked_slot_icon.texture == null:
		return _fail("locked_slot_icon_missing")
	if locked_slot_icon.texture.resource_path != str(CCRVisualStyle.ICON_PATHS["status_lock"]):
		return _fail("locked_slot_does_not_use_padlock")
	var expected_lock_size := clampf(CardSlotUI.SLOT_SIZE.x * 0.45, 39.0, 63.0)
	if locked_slot_icon.size != Vector2(expected_lock_size, expected_lock_size):
		return _fail("locked_slot_icon_not_enlarged_50_percent")
	return true

func _assert_status_icons(main: MainUI) -> bool:
	for node_name in ["StaminaIcon", "GoldIcon", "GemIcon", "LevelIcon", "CombatPowerIcon", "ExperienceIcon"]:
		var icon := main.find_child(node_name, true, false) as TextureRect
		if icon == null or icon.texture == null:
			return _fail("status_icon_missing_%s" % node_name)
	var stamina_label := main.find_child("StaminaLabel", true, false) as Label
	var gold_label := main.find_child("GoldLabel", true, false) as Label
	var gem_label := main.find_child("GemsLabel", true, false) as Label
	if stamina_label == null or stamina_label.text.find("⚡") >= 0:
		return _fail("stamina_label_still_uses_emoji")
	if gold_label == null or gold_label.text.find("💰") >= 0:
		return _fail("gold_label_still_uses_emoji")
	if gem_label == null or gem_label.text.find("💎") >= 0:
		return _fail("gem_label_still_uses_emoji")
	var level_icon := main.find_child("LevelIcon", true, false) as TextureRect
	var combat_icon := main.find_child("CombatPowerIcon", true, false) as TextureRect
	if level_icon.custom_minimum_size != Vector2(36, 36) or combat_icon.custom_minimum_size != Vector2(36, 36):
		return _fail("player_status_icons_not_double_size")
	return true

func _assert_steam_deck_metrics(main: MainUI) -> bool:
	var nav_buttons := main.get("_nav_buttons") as NavButtons
	var expected_width := 102.0
	var expected_nav_height := 25.0
	nav_buttons.configure_button_metrics(expected_width, expected_nav_height)
	nav_buttons.call("_layout_buttons")
	for button in nav_buttons.buttons:
		if absf(button.size.x - expected_width) > 1.0 or absf(button.size.y - expected_nav_height) > 1.0:
			return _fail("steam_deck_navigation_size_changed_by_icon_%s" % str(button.size))
		if button.get_theme_constant("icon_max_width") != 17:
			return _fail("steam_deck_navigation_icon_not_two_thirds")
	var center := main.get("_center_area") as Control
	var vault_ui := center.find_child("VaultActionPanel", true, false).get_parent() as VaultUI
	if vault_ui == null:
		return _fail("steam_deck_vault_ui_missing")
	vault_ui.configure_side_button_metrics(expected_width, 33.0)
	vault_ui.call("_layout_right_actions")
	for node_name in ["VaultSynthesizeButton", "VaultExpandGoldButton", "VaultExpandGemButton"]:
		var button := center.find_child(node_name, true, false) as Button
		if button == null or button.size.x > expected_width + 1.0:
			return _fail("steam_deck_action_button_overflow_%s" % node_name)
		var expected_icon_width := 22 if node_name == "VaultSynthesizeButton" else 17
		if button.get_theme_constant("icon_max_width") != expected_icon_width:
			return _fail("steam_deck_action_icon_ratio_wrong_%s" % node_name)
	return true

func _assert_max_resolution_metrics(main: MainUI) -> bool:
	# CI 主机可能把窗口尺寸限制在物理屏幕内，因此直接用正式最大分辨率驱动布局公式。
	main.call("_configure_card_slot_size", Vector2(2560, 1440))
	var nav_height := float(main.call("_nav_button_height", Vector2(2560, 1440)))
	if nav_height != 75.0:
		return _fail("max_resolution_navigation_height_not_75px_%s" % nav_height)
	var nav_buttons := main.get("_nav_buttons") as NavButtons
	nav_buttons.configure_button_metrics(260.0, nav_height)
	nav_buttons.call("_layout_buttons")
	for button in nav_buttons.buttons:
		if button.get_theme_constant("icon_max_width") != 50:
			return _fail("max_resolution_navigation_icon_not_50px")
	main.call("_apply_currency_layout", Vector2(2560, 1440))
	var stamina_icon := main.find_child("StaminaIcon", true, false) as TextureRect
	if stamina_icon == null or stamina_icon.custom_minimum_size != Vector2(50, 50):
		return _fail("max_resolution_currency_icon_not_50px")
	var center := main.get("_center_area") as Control
	var vault_ui := center.find_child("VaultActionPanel", true, false).get_parent() as VaultUI
	vault_ui.configure_side_button_metrics(260.0, 100.0)
	vault_ui.call("_layout_right_actions")
	var synthesize := center.find_child("VaultSynthesizeButton", true, false) as Button
	var gold_expand := center.find_child("VaultExpandGoldButton", true, false) as Button
	if synthesize.get_theme_constant("icon_max_width") != 67:
		return _fail("max_resolution_action_icon_not_67px")
	if gold_expand.get_theme_constant("icon_max_width") != 50:
		return _fail("max_resolution_currency_button_icon_not_50px")
	return true

func _assert_button(button: Button, icon_id: String, variant: String) -> bool:
	var overlay_icon := CCRVisualStyle.get_button_icon(button)
	if button.icon != null or overlay_icon == null or overlay_icon.texture == null or str(button.get_meta("ccr_icon_id", "")) != icon_id:
		return _fail("button_icon_wrong_%s" % button.name)
	if str(button.get_meta("ccr_button_variant", "")) != variant:
		return _fail("button_variant_wrong_%s" % button.name)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var style := button.get_theme_stylebox(state) as StyleBoxTexture
		if style == null or style.texture == null:
			return _fail("button_state_style_missing_%s_%s" % [button.name, state])
		if style.texture_margin_left <= 0.0 or style.texture_margin_top <= 0.0:
			return _fail("button_nine_slice_missing_%s_%s" % [button.name, state])
	for emoji in TARGET_EMOJI:
		if button.text.find(emoji) >= 0:
			return _fail("button_text_still_contains_emoji_%s" % button.name)
	return true

func _assert_icon_column_aligned(buttons: Array[Button], group_name: String) -> bool:
	var reference_x := -1.0
	for button in buttons:
		if button == null:
			return _fail("%s_icon_button_missing" % group_name)
		var button_icon := CCRVisualStyle.get_button_icon(button)
		if button_icon == null:
			return _fail("%s_icon_overlay_missing" % group_name)
		var center_x := button.global_position.x + button_icon.position.x + button_icon.size.x * 0.5
		if reference_x < 0.0:
			reference_x = center_x
		elif absf(center_x - reference_x) > 0.5:
			return _fail("%s_icon_column_misaligned" % group_name)
	return true

func _assert_button_icon_hover_motion(main: MainUI) -> bool:
	var nav_buttons := main.get("_nav_buttons") as NavButtons
	var nav_button := nav_buttons.find_child("NavButton_card_pool", false, false) as Button
	var nav_icon := CCRVisualStyle.get_button_icon(nav_button)
	var center_before := nav_icon.position + nav_icon.pivot_offset
	nav_button.mouse_entered.emit()
	await get_tree().create_timer(0.45).timeout
	if nav_icon.scale.distance_to(Vector2(1.5, 1.5)) > 0.01:
		return _fail("button_icon_hover_scale_not_150_percent")
	if (nav_icon.position + nav_icon.pivot_offset) != center_before:
		return _fail("button_icon_hover_center_changed")
	nav_button.mouse_exited.emit()
	await get_tree().create_timer(0.45).timeout
	if nav_icon.scale.distance_to(Vector2.ONE) > 0.01:
		return _fail("button_icon_hover_restore_failed")

	return true

func _fail(reason: String) -> bool:
	if _failed:
		return false
	_failed = true
	push_error("BUTTON_THEME_ICON " + reason)
	get_tree().quit(1)
	return false
