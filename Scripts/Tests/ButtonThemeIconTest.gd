extends Node

const CCRVisualStyle = preload("res://Scripts/UI/CCRVisualStyle.gd")
const TARGET_EMOJI := ["🔄", "💛", "💎", "◀", "▶", "⚗", "🗑", "📦", "✨", "✅", "❌"]
const ICON_EXPECTED_SIZES := {
	"nav_today_decks": 50, "nav_card_pool": 50, "nav_vault": 50,
	"nav_museum": 50, "nav_auction": 50, "nav_leaderboard": 50,
	"nav_mail": 50, "nav_settings": 50, "nav_exit": 50,
	"draw_stamina": 50, "draw_gold": 50, "draw_gem": 50,
	"action_page": 67, "action_synthesize": 67, "action_discard": 67, "action_store_vault": 67,
	"vault_organize": 216, "vault_synthesize": 216, "vault_expand_gold": 216, "vault_expand_gem": 216,
	"status_stamina": 50, "status_gold": 50, "status_gem": 50,
	"status_roll_green": 50, "status_roll_yellow": 50, "status_roll_red": 50,
	"status_level": 18, "status_combat_power": 18, "status_experience": 14,
	"status_lock": 42,
}

var _failed := false

func _ready() -> void:
	get_window().size = Vector2i(1920, 1200)
	Localization.set_locale("zh-CN")
	# 测试只隔离当前进程的登录态，不改写开发者本机保存的 token。
	ApiClient._auth_token = ""
	ApiClient._refresh_token = ""
	_prepare_player_data()
	if not _assert_source_assets():
		return

	var main := MainUI.new()
	main.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	if not _assert_login_overlay_isolated(main):
		return
	main.call("_set_game_ui_visible", true)

	if not _assert_navigation(main):
		return
	if not _assert_draw_and_hand(main):
		return
	if not _assert_status_icons(main):
		return
	var currency_probe_path := OS.get_environment("CCR_MAIN_CURRENCY_PROBE_PATH")
	if currency_probe_path != "" and DisplayServer.get_name() != "headless":
		var splash := main.find_child("SplashScreenUI", true, false) as Control
		if splash != null:
			splash.hide()
		GameManager.player_data.add_gold(9_223_372_036_854_774_807)
		GameManager.player_data.add_gems(2_147_483_597)
		await get_tree().process_frame
		await get_tree().process_frame
		var currency := main.get("_currency") as CurrencyUI
		await get_tree().create_timer(AssetNumberRoll.ROLL_DURATION + 0.06).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(currency_probe_path)
		print("MAIN_CURRENCY_PROBE ok")
		get_tree().quit(0)
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

	print("BUTTON_THEME_ICON ok assets=37 nav=9 draw=3 card_actions=4 vault=4 status=10")
	get_tree().quit(0)

func _assert_login_overlay_isolated(main: MainUI) -> bool:
	var splash_count := 0
	var splash: Control = null
	for child in main.get_children():
		if child.name == "SplashScreenUI":
			splash_count += 1
			splash = child as Control
	if splash_count != 1 or splash == null:
		return _fail("login_splash_initial_count_wrong=%d" % splash_count)
	main.call("_show_splash_screen")
	splash_count = 0
	for child in main.get_children():
		if child.name == "SplashScreenUI":
			splash_count += 1
	if splash_count != 1:
		return _fail("login_splash_not_idempotent=%d" % splash_count)
	if splash.z_index != 4096:
		return _fail("login_splash_not_above_game_icons")
	var nav_buttons := main.get("_nav_buttons") as NavButtons
	var center := main.get("_center_area") as Control
	if nav_buttons == null or center == null or nav_buttons.is_visible_in_tree() or center.is_visible_in_tree():
		return _fail("game_ui_visible_behind_login")
	for icon_node in main.find_children(CCRVisualStyle.BUTTON_ICON_NODE_NAME, "TextureRect", true, false):
		var icon := icon_node as TextureRect
		if icon != null and icon.is_visible_in_tree():
			return _fail("game_button_icon_visible_on_login=" + str(icon.get_parent().name))
	if bool(ApiClient.call("_should_invalidate_access_token", "https://ccrgame.com/api/auth/login")):
		return _fail("login_401_invalidates_existing_access_token")
	if bool(ApiClient.call("_should_emit_auth_expired", "https://ccrgame.com/api/auth/login")):
		return _fail("login_401_emits_global_auth_expired")
	if not bool(ApiClient.call("_should_emit_auth_expired", "https://ccrgame.com/api/user/profile")):
		return _fail("protected_401_does_not_emit_auth_expired")
	return true

func _prepare_player_data() -> void:
	GameManager.player_data.user_id = 0
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
	for variant in ["navigation", "action", "vault_action"]:
		var paths: Dictionary = CCRVisualStyle.BUTTON_TEXTURE_PATHS[variant]
		var expected_size := Vector2i(256, 64) if variant == "navigation" else (Vector2i(194, 208) if variant == "vault_action" else Vector2i(192, 64))
		for state in ["normal", "hover", "pressed", "disabled"]:
			var texture := CCRVisualStyle._load_texture_png_source(str(paths[state]))
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
	var dialog_assets := {
		CCRVisualStyle.DIALOG_PANEL_PATH: CCRVisualStyle.DIALOG_PANEL_SIZE,
		CCRVisualStyle.DIALOG_CONFIRM_BUTTON_PATH: Vector2(260, 80),
		CCRVisualStyle.DIALOG_CANCEL_BUTTON_PATH: Vector2(260, 80),
	}
	for path in dialog_assets:
		var texture := load(str(path)) as Texture2D
		if texture == null or texture.get_size() != dialog_assets[path]:
			return _fail("exit_dialog_asset_wrong_%s" % str(path))
		var image := texture.get_image()
		if image == null or image.get_pixel(0, 0).a > 0.1:
			return _fail("exit_dialog_asset_alpha_missing_%s" % str(path))
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
	if not _assert_button_text_shifted(nav_buttons.buttons[0]):
		return false
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
		if node_name == "HandPageButton":
			if button.has_node("AssetActionCooldown"):
				return _fail("hand_page_button_must_not_have_cooldown")
		elif not _assert_action_cooldown(button):
			return false
		if node_name == "HandSynthesizeButton" and button.text != "锻造":
			return _fail("hand_synthesize_text_not_forge")
	var action_buttons: Array[Button] = []
	for node_name in targets:
		action_buttons.append(center.find_child(str(node_name), true, false) as Button)
	if not _assert_icon_column_aligned(action_buttons, "action"):
		return false
	for button in action_buttons:
		if button.get_theme_font_size("font_size") < 16:
			return _fail("action_button_font_not_increased_%s" % button.name)
		if not _assert_button_text_shifted(button):
			return false
	return true

func _assert_vault(main: MainUI) -> bool:
	var center := main.get("_center_area") as Control
	var targets := {
		"VaultOrganizeButton": "vault_organize",
		"VaultSynthesizeButton": "vault_synthesize",
		"VaultExpandGoldButton": "vault_expand_gold",
		"VaultExpandGemButton": "vault_expand_gem",
	}
	for node_name in targets:
		var button := center.find_child(str(node_name), true, false) as Button
		if button == null or not _assert_button(button, str(targets[node_name]), "vault_action"):
			return _fail("vault_button_missing_%s" % str(node_name))
		if not _assert_action_cooldown(button):
			return false
		if not _assert_vault_button_vertical_layout(button):
			return false
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
	for node_name in ["StaminaIcon", "GoldIcon", "GemIcon", "RollPrefetchIcon", "LevelIcon", "CombatPowerIcon", "ExperienceIcon"]:
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
	var currency := main.get("_currency") as CurrencyUI
	var roll_icon := main.find_child("RollPrefetchIcon", true, false) as TextureRect
	var gem_size := currency.get_resource_icon_global_rect("gem").size if currency != null else Vector2.ZERO
	if roll_icon == null or currency == null or roll_icon.custom_minimum_size != Vector2(roundf(gem_size.x * CurrencyUI.ROLL_PREFETCH_ICON_SCALE), roundf(gem_size.y * CurrencyUI.ROLL_PREFETCH_ICON_SCALE)):
		return _fail("roll_prefetch_icon_size_wrong")
	var level_icon := main.find_child("LevelIcon", true, false) as TextureRect
	var combat_icon := main.find_child("CombatPowerIcon", true, false) as TextureRect
	if level_icon.custom_minimum_size != Vector2(36, 36) or combat_icon.custom_minimum_size != Vector2(36, 36):
		return _fail("player_status_icons_not_double_size")
	return true

func _assert_steam_deck_metrics(main: MainUI) -> bool:
	var nav_buttons := main.get("_nav_buttons") as NavButtons
	var expected_width := 102.0
	var expected_nav_height := 800.0 * MainUI.NAV_BUTTON_HEIGHT_RATIO
	nav_buttons.configure_button_metrics(expected_width, expected_nav_height)
	nav_buttons.call("_layout_buttons")
	for button in nav_buttons.buttons:
		if absf(button.size.x - expected_width) > 1.0 or absf(button.size.y - expected_nav_height) > 1.0:
			return _fail("steam_deck_navigation_size_changed_by_icon_%s" % str(button.size))
		if button.get_theme_constant("icon_max_width") != 27:
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
		var expected_icon_width := 36
		if button.get_theme_constant("icon_max_width") != expected_icon_width:
			return _fail("steam_deck_action_icon_ratio_wrong_%s" % node_name)
		if not _assert_vault_button_vertical_layout(button):
			return false
	return true

func _assert_max_resolution_metrics(main: MainUI) -> bool:
	# CI 主机可能把窗口尺寸限制在物理屏幕内，因此直接用正式最大分辨率驱动布局公式。
	main.call("_configure_card_slot_size", Vector2(2560, 1440))
	var nav_height := float(main.call("_nav_button_height", Vector2(2560, 1440)))
	var expected_nav_height := 1440.0 * MainUI.NAV_BUTTON_HEIGHT_RATIO
	if absf(nav_height - expected_nav_height) > 0.01:
		return _fail("max_resolution_navigation_height_ratio_wrong_%s" % nav_height)
	var nav_buttons := main.get("_nav_buttons") as NavButtons
	nav_buttons.configure_button_metrics(260.0, nav_height)
	nav_buttons.call("_layout_buttons")
	for button in nav_buttons.buttons:
		if button.get_theme_constant("icon_max_width") != 49:
			return _fail("max_resolution_navigation_icon_ratio_wrong")
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
	var organize := center.find_child("VaultOrganizeButton", true, false) as Button
	if synthesize.size != Vector2(VaultUI.VAULT_ACTION_BUTTON_WIDTH, VaultUI.VAULT_ACTION_BUTTON_HEIGHT):
		return _fail("max_resolution_vault_action_size_wrong")
	if synthesize.get_theme_constant("icon_max_width") != int(VaultUI.VAULT_ACTION_ICON_SIZE):
		return _fail("max_resolution_action_icon_not_108px")
	if gold_expand.get_theme_constant("icon_max_width") != int(VaultUI.VAULT_ACTION_ICON_SIZE):
		return _fail("max_resolution_currency_button_icon_not_108px")
	if organize == null or organize.position.y >= synthesize.position.y:
		return _fail("vault_organize_button_not_above_synthesize")
	for button in [organize, synthesize, gold_expand, center.find_child("VaultExpandGemButton", true, false) as Button]:
		if not _assert_vault_button_vertical_layout(button):
			return false
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

func _assert_button_text_shifted(button: Button) -> bool:
	if button.alignment != HORIZONTAL_ALIGNMENT_CENTER:
		return _fail("button_text_not_center_aligned_%s" % button.name)
	var style := button.get_theme_stylebox("normal") as StyleBoxTexture
	var icon_width := float(button.get_theme_constant("icon_max_width"))
	if style == null or absf((style.content_margin_left - style.content_margin_right) - icon_width) > 0.1:
		return _fail("button_text_margin_not_shifted_%s" % button.name)
	return true

func _assert_vault_button_vertical_layout(button: Button) -> bool:
	if button.alignment != HORIZONTAL_ALIGNMENT_CENTER:
		return _fail("vault_button_text_not_center_aligned_%s" % button.name)
	var icon := CCRVisualStyle.get_button_icon(button)
	var caption := CCRVisualStyle.get_button_text_label(button)
	if icon == null or caption == null or not caption.visible:
		return _fail("vault_button_vertical_nodes_missing_%s" % button.name)
	if icon.texture == null or icon.texture.get_size().x < VaultUI.VAULT_ACTION_ICON_SIZE * 2.0:
		return _fail("vault_button_icon_source_not_high_resolution_%s" % button.name)
	var scale := button.size.y / VaultUI.VAULT_ACTION_BUTTON_HEIGHT
	var expected_icon_size := roundf(VaultUI.VAULT_ACTION_ICON_SIZE * scale)
	var expected_icon_top := VaultUI.VAULT_ACTION_ICON_TOP * scale
	var expected_text_top := (VaultUI.VAULT_ACTION_ICON_TOP + VaultUI.VAULT_ACTION_ICON_SIZE + VaultUI.VAULT_ACTION_TEXT_GAP) * scale
	if icon.size.distance_to(Vector2(expected_icon_size, expected_icon_size)) > 1.0:
		return _fail("vault_button_icon_size_wrong_%s" % button.name)
	if absf(icon.position.x - (button.size.x - icon.size.x) * 0.5) > 1.0:
		return _fail("vault_button_icon_not_centered_%s" % button.name)
	if absf(icon.position.y - expected_icon_top) > 1.0:
		return _fail("vault_button_icon_top_wrong_%s" % button.name)
	if caption.text != CCRVisualStyle.get_relic_button_caption_text(button):
		return _fail("vault_button_caption_not_synced_%s" % button.name)
	if button.text != "":
		return _fail("vault_button_native_text_not_empty_%s" % button.name)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color", "font_disabled_color"]:
		if button.get_theme_color(state).a > 0.001:
			return _fail("vault_button_native_text_visible_%s_%s" % [button.name, state])
	if absf(caption.position.x) > 0.1 or absf(caption.size.x - button.size.x) > 0.1:
		return _fail("vault_button_caption_not_centered_%s" % button.name)
	if absf(caption.position.y - expected_text_top) > 1.0:
		return _fail("vault_button_caption_top_wrong_%s" % button.name)
	if button.disabled:
		if not _color_close(caption.get_theme_color("font_color"), CCRVisualStyle.RELIC_BUTTON_DISABLED_TEXT):
			return _fail("vault_button_caption_not_gray_when_disabled_%s" % button.name)
	else:
		if not _color_close(caption.get_theme_color("font_color"), CCRVisualStyle.RELIC_BUTTON_VAULT_TEXT):
			return _fail("vault_button_caption_not_navigation_normal_color_%s" % button.name)
		button.mouse_entered.emit()
		if not _color_close(caption.get_theme_color("font_color"), CCRVisualStyle.RELIC_BUTTON_HOVER_TEXT):
			return _fail("vault_button_caption_not_white_on_hover_%s" % button.name)
		button.mouse_exited.emit()
		if not _color_close(caption.get_theme_color("font_color"), CCRVisualStyle.RELIC_BUTTON_NAV_TEXT):
			return _fail("vault_button_caption_not_navigation_color_after_hover_%s" % button.name)
	return true

func _assert_action_cooldown(button: Button) -> bool:
	var cooldown := button.get_node_or_null("AssetActionCooldown") as ColorRect
	if cooldown == null:
		return _fail("button_cooldown_missing_%s" % button.name)
	if cooldown.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		return _fail("button_cooldown_blocks_input_%s" % button.name)
	if cooldown.size.distance_to(button.size) > 0.1:
		return _fail("button_cooldown_size_wrong_%s" % button.name)
	var icon := CCRVisualStyle.get_button_icon(button)
	if icon != null and cooldown.z_index <= icon.z_index:
		return _fail("button_cooldown_below_icon_%s" % button.name)
	cooldown.start()
	if not cooldown.visible or not cooldown.is_cooling_down():
		return _fail("button_cooldown_did_not_start_%s" % button.name)
	var shader_material := cooldown.material as ShaderMaterial
	if shader_material == null or float(shader_material.get_shader_parameter("remaining")) <= 0.0:
		return _fail("button_cooldown_shader_inactive_%s" % button.name)
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

func _color_close(a: Color, b: Color, tolerance: float = 0.001) -> bool:
	return absf(a.r - b.r) <= tolerance and absf(a.g - b.g) <= tolerance and absf(a.b - b.b) <= tolerance and absf(a.a - b.a) <= tolerance

func _fail(reason: String) -> bool:
	if _failed:
		return false
	_failed = true
	push_error("BUTTON_THEME_ICON " + reason)
	get_tree().quit(1)
	return false
