extends Control
class_name VaultUI

signal card_clicked(card: CardInfo)
signal card_dragged(card: CardInfo, from_slot: int)

@export var columns: int = 8

var slot_count: int = 2
var slots: Array[CardSlotUI] = []
var _raw_slot_data: Array = []  # 服务端原始槽位数据（含 unlocked 等信息）
var _slot_viewport: ScrollContainer = null
var _slot_canvas: Control = null
var _organize_btn: Button = null
var _organize_cooldown: Control = null
var _organize_busy: bool = false
var _gold_unlock_btn: Button = null
var _gold_unlock_cost_label: Label = null
var _gem_unlock_btn: Button = null
var _gem_unlock_cost_label: Label = null
var _unlock_buttons_busy: bool = false
var _gold_unlock_cooldown: Control = null
var _gem_unlock_cooldown: Control = null
var _action_panel: Control = null
var _side_button_width: float = 110.0
var _side_button_height: float = 36.0

# ── 选中合成相关 ──
var _selected_slots: Array[int] = []     # 单选槽位；保留数组形态便于复用现有高亮逻辑
var _synthesize_btn: Button = null
var _synthesize_cooldown: Control = null
var _relic_preview: RelicView = null


const SELECT_BORDER_COLOR: Color = Color(1.0, 0.84, 0.0, 0.7)  # 金色
const RELIC_VIEW_SCENE = preload("res://Scenes/UI/RelicView.tscn")
const SynthesisAnimationOverlayScript = preload("res://Scripts/UI/SynthesisAnimationOverlay.gd")
const AssetActionCooldownScript = preload("res://Scripts/UI/AssetActionCooldown.gd")
const CCRVisualStyle = preload("res://Scripts/UI/CCRVisualStyle.gd")
const VAULT_COLUMNS: int = 8
const MAX_VISIBLE_ROWS: int = 4
const EXTRA_LOCKED_ROWS: int = 1
const VAULT_GRID_LEFT_MARGIN: float = 40.0
const SLOT_SPACING: float = 8.0
const VAULT_GRID_SHADOW_SAFE_PADDING: Vector2 = Vector2(24.0, 24.0)
const UNLOCK_PANEL_WIDTH: float = 130.0
const UNLOCK_PANEL_RIGHT_MARGIN: float = 10.0
const BUTTON_LABEL_HEIGHT: float = 24.0
const UNLOCK_KEY_TEXTURE_PATH := "res://Resources/UI/Icons/Status/status_slot_key.png"
const UNLOCK_KEY_REVERSE_DURATION: float = 0.80
const UNLOCK_KEY_TARGET_DURATION: float = 1.20
const UNLOCK_KEY_FADE_DURATION: float = 0.08
const UNLOCK_KEY_REVERSE_DISTANCE: float = 58.0
const UNLOCK_KEY_START_SPINS_PER_SECOND: float = 5.0
const UNLOCK_KEY_SCALE: float = 2.0
var _nav_target_rect: Rect2 = Rect2()
var _vault_nav_target_rect: Rect2 = Rect2()
var _stamina_target_rect: Rect2 = Rect2()
var _gold_target_rect: Rect2 = Rect2()
var _gems_target_rect: Rect2 = Rect2()
var _vault_synthesis_animation_running: bool = false
var _synthesis_hidden_indices: Dictionary = {}

func configure_side_button_metrics(button_width: float, button_height: float) -> void:
	_side_button_width = maxf(70.0, button_width)
	_side_button_height = maxf(28.0, button_height)
	if is_node_ready():
		_layout_right_actions()
		_layout_slot_label()

func _ready() -> void:
	columns = VAULT_COLUMNS
	slot_count = _calculate_render_slot_count()
	setup_ui()
	GameManager.player_data.changed.connect(_on_player_data_changed)

	# 监听拖拽事件
	if DragSystem != null:
		DragSystem.drag_ended.connect(_on_drag_ended)
		DragSystem.drag_cancelled.connect(_on_drag_cancelled)

func set_synthesis_nav_target_rect(rect: Rect2) -> void:
	_nav_target_rect = rect

func set_synthesis_reward_target_rects(museum_rect: Rect2, vault_rect: Rect2, gold_rect: Rect2, gems_rect: Rect2, stamina_rect: Rect2 = Rect2()) -> void:
	_nav_target_rect = museum_rect
	_vault_nav_target_rect = vault_rect
	_gold_target_rect = gold_rect
	_gems_target_rect = gems_rect
	_stamina_target_rect = stamina_rect

func _load_from_server() -> void:
	await GameManager.sync_vault_from_server()
	await GameManager.sync_vault_slot_quote_from_server()
	_update_slot_count_from_server()
	refresh_display()

func setup_ui() -> void:
	# 槽位标签
	var slot_label = Label.new()
	slot_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	slot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	slot_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	slot_label.text = Localization.t("ui.vault.slot_count", [GameManager.player_data.vault_cards.size(), slot_count])
	slot_label.name = "SlotLabel"
	add_child(slot_label)

	_slot_viewport = ScrollContainer.new()
	_slot_viewport.name = "VaultSlotViewport"
	_slot_viewport.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_slot_viewport)

	_slot_canvas = Control.new()
	_slot_canvas.name = "VaultSlotCanvas"
	_slot_viewport.add_child(_slot_canvas)

	_create_relic_preview()

	# ── 合成按钮（初始隐藏） ──
	_synthesize_btn = Button.new()
	_synthesize_btn.name = "VaultSynthesizeButton"
	_synthesize_btn.text = Localization.t("ui.synthesis.vault.count", [0])
	_synthesize_btn.visible = true
	_synthesize_btn.disabled = true
	CCRVisualStyle.apply_relic_button(_synthesize_btn, "action_synthesize")
	_synthesize_cooldown = _attach_action_cooldown(_synthesize_btn)
	_synthesize_btn.pressed.connect(_on_synthesize_pressed)

	_create_unlock_panel()
	_create_slot_grid()
	_layout_slot_label()
	_layout_right_actions()
	refresh_display()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout_relic_preview()
		_layout_slot_label()
		_layout_right_actions()

func _create_relic_preview() -> void:
	_relic_preview = RELIC_VIEW_SCENE.instantiate() as RelicView
	_relic_preview.name = "RelicPreview"
	_relic_preview.visible = false
	_relic_preview.z_index = 5
	add_child(_relic_preview)
	_layout_relic_preview()

func _layout_relic_preview() -> void:
	if _relic_preview == null:
		return
	var viewport_size := size if size.x > 0.0 and size.y > 0.0 else get_viewport_rect().size
	var preview_height := minf(450.0, maxf(280.0, viewport_size.y - 250.0))
	var preview_width := preview_height * _relic_preview.get_aspect_ratio()
	var right_edge := _right_region_left_x() - 10.0
	_relic_preview.size = Vector2(preview_width, preview_height)
	_relic_preview.position = Vector2(right_edge - preview_width, maxf(80.0, (viewport_size.y - preview_height) * 0.5))

func _create_unlock_panel() -> void:
	_action_panel = Control.new()
	_action_panel.name = "VaultActionPanel"
	_action_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	add_child(_action_panel)

	_organize_btn = Button.new()
	_organize_btn.name = "VaultOrganizeButton"
	_organize_btn.text = Localization.t("ui.vault.organize")
	_organize_btn.pressed.connect(_on_organize_vault_pressed)
	CCRVisualStyle.apply_relic_button(_organize_btn, "vault_organize")
	_action_panel.add_child(_organize_btn)
	_organize_cooldown = _attach_action_cooldown(_organize_btn)

	_action_panel.add_child(_synthesize_btn)

	_gold_unlock_btn = Button.new()
	_gold_unlock_btn.name = "VaultExpandGoldButton"
	_gold_unlock_btn.text = Localization.t("ui.vault.unlock_gold")
	_gold_unlock_btn.pressed.connect(func(): _on_unlock_slot_pressed("gold"))
	CCRVisualStyle.apply_relic_button(_gold_unlock_btn, "vault_expand_gold")
	_action_panel.add_child(_gold_unlock_btn)
	_gold_unlock_cooldown = _attach_action_cooldown(_gold_unlock_btn)

	_gold_unlock_cost_label = Label.new()
	_gold_unlock_cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gold_unlock_cost_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_action_panel.add_child(_gold_unlock_cost_label)

	_gem_unlock_btn = Button.new()
	_gem_unlock_btn.name = "VaultExpandGemButton"
	_gem_unlock_btn.text = Localization.t("ui.vault.unlock_gem")
	_gem_unlock_btn.pressed.connect(func(): _on_unlock_slot_pressed("gem"))
	CCRVisualStyle.apply_relic_button(_gem_unlock_btn, "vault_expand_gem")
	_action_panel.add_child(_gem_unlock_btn)
	_gem_unlock_cooldown = _attach_action_cooldown(_gem_unlock_btn)

	_gem_unlock_cost_label = Label.new()
	_gem_unlock_cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gem_unlock_cost_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_action_panel.add_child(_gem_unlock_cost_label)

func _layout_slot_label() -> void:
	var label := get_node_or_null("SlotLabel") as Label
	if label == null:
		return
	var label_size := Vector2(maxf(_side_button_width, 120.0), 28.0)
	label.size = label_size
	label.custom_minimum_size = label_size
	label.position = Vector2(_right_region_center_x() - label_size.x * 0.5, maxf(0.0, _grid_side_width() * 0.5 - label_size.y * 0.5))

func _layout_right_actions() -> void:
	if _action_panel == null:
		return
	var button_size := Vector2(_side_button_width, _side_button_height)
	for button in [_organize_btn, _synthesize_btn, _gold_unlock_btn, _gem_unlock_btn]:
		var typed_button := button as Button
		if typed_button != null:
			typed_button.custom_minimum_size = button_size
			typed_button.size = button_size
			var icon_ratio := 2.0 / 3.0 if typed_button == _synthesize_btn else 0.5
			CCRVisualStyle.configure_relic_button_metrics(typed_button, _side_button_height, icon_ratio)
			typed_button.add_theme_font_size_override("font_size", _action_font_size())
	for label in [_gold_unlock_cost_label, _gem_unlock_cost_label]:
		var typed_label := label as Label
		if typed_label != null:
			typed_label.custom_minimum_size = Vector2(_side_button_width, BUTTON_LABEL_HEIGHT)

	var button_step := _side_button_height + BUTTON_LABEL_HEIGHT + 8.0
	var content_height := _side_button_height + button_step * 3.0 + BUTTON_LABEL_HEIGHT
	_action_panel.size = Vector2(_side_button_width, content_height)
	_action_panel.position = Vector2(_right_region_center_x() - _side_button_width * 0.5, maxf(0.0, (size.y - content_height) * 0.5))

	var button_rows := [_organize_btn, _synthesize_btn, _gold_unlock_btn, _gem_unlock_btn]
	for i in range(button_rows.size()):
		var button := button_rows[i] as Button
		if button != null:
			button.position = Vector2(0.0, button_step * float(i))
	if _gold_unlock_cost_label != null:
		_gold_unlock_cost_label.size = Vector2(_side_button_width, BUTTON_LABEL_HEIGHT)
		_gold_unlock_cost_label.position = Vector2(0.0, _gold_unlock_btn.position.y + _side_button_height + 2.0)
	if _gem_unlock_cost_label != null:
		_gem_unlock_cost_label.size = Vector2(_side_button_width, BUTTON_LABEL_HEIGHT)
		_gem_unlock_cost_label.position = Vector2(0.0, _gem_unlock_btn.position.y + _side_button_height + 2.0)

func _action_font_size() -> int:
	if _side_button_width < 120.0:
		return 11 if Localization.locale == "en" else 12
	return 14 if Localization.locale == "en" else 15

func _create_slot_grid() -> void:
	var slot_size = CardSlotUI.SLOT_SIZE
	var render_rows := maxi(1, int(ceil(float(slot_count) / float(columns))))
	var visible_rows := mini(MAX_VISIBLE_ROWS, render_rows)
	var total_width = columns * slot_size.x + (columns - 1) * SLOT_SPACING
	var content_height = render_rows * slot_size.y + (render_rows - 1) * SLOT_SPACING
	var viewport_height = visible_rows * slot_size.y + (visible_rows - 1) * SLOT_SPACING
	var viewport_width_with_shadow = total_width + VAULT_GRID_SHADOW_SAFE_PADDING.x * 2.0
	var viewport_height_with_shadow = viewport_height + VAULT_GRID_SHADOW_SAFE_PADDING.y * 2.0
	var canvas_width_with_shadow = total_width + VAULT_GRID_SHADOW_SAFE_PADDING.x * 2.0
	var canvas_height_with_shadow = content_height + VAULT_GRID_SHADOW_SAFE_PADDING.y * 2.0
	var available_width = size.x if size.x > 0.0 else get_viewport_rect().size.x
	var right_reserved = _right_region_width()
	var start_x = _centered_grid_start_x(total_width)
	if start_x + total_width + right_reserved > available_width:
		start_x = maxf(VAULT_GRID_LEFT_MARGIN, available_width - total_width - right_reserved)
	var start_y = 56.0

	if _slot_viewport != null:
		_slot_viewport.position = Vector2(start_x - VAULT_GRID_SHADOW_SAFE_PADDING.x, start_y - VAULT_GRID_SHADOW_SAFE_PADDING.y)
		_slot_viewport.size = Vector2(viewport_width_with_shadow, viewport_height_with_shadow)
		_slot_viewport.custom_minimum_size = _slot_viewport.size
	if _slot_canvas != null:
		_slot_canvas.size = Vector2(canvas_width_with_shadow, canvas_height_with_shadow)
		_slot_canvas.custom_minimum_size = _slot_canvas.size

	for i in range(slots.size(), slot_count):
		var slot = CardSlotUI.new()
		slot.slot_index = i
		slot.custom_minimum_size = slot_size
		slot.area_type = "vault"
		slot.can_drag_from = true
		slot.slot_clicked.connect(_on_slot_clicked)
		slot.card_dropped.connect(_on_card_dropped)
		slot.slot_unlock_requested.connect(func(idx: int): GameManager.handle_unlock_slot("vault", idx))
		slots.append(slot)
		if _slot_canvas != null:
			_slot_canvas.add_child(slot)
		else:
			add_child(slot)

	for i in range(slots.size()):
		var row = i / columns
		var col = i % columns
		var x = VAULT_GRID_SHADOW_SAFE_PADDING.x + col * (slot_size.x + SLOT_SPACING)
		var y = VAULT_GRID_SHADOW_SAFE_PADDING.y + row * (slot_size.y + SLOT_SPACING)
		slots[i].position = Vector2(x, y)
		slots[i].visible = i < slot_count


func _centered_grid_start_x(total_width: float) -> float:
	var viewport_width := get_viewport_rect().size.x
	var centered_global_left := maxf(0.0, (viewport_width - total_width) * 0.5)
	var parent_global_x := global_position.x if is_inside_tree() else 0.0
	return maxf(0.0, centered_global_left - parent_global_x)

func _grid_width() -> float:
	return VAULT_COLUMNS * CardSlotUI.SLOT_SIZE.x + (VAULT_COLUMNS - 1) * SLOT_SPACING

func _grid_side_width() -> float:
	var viewport_width := get_viewport_rect().size.x
	return maxf(0.0, (viewport_width - _grid_width()) * 0.5)

func _right_region_left_x() -> float:
	var parent_global_x := global_position.x if is_inside_tree() else 0.0
	var grid_global_left := _grid_side_width()
	return grid_global_left + _grid_width() - parent_global_x

func _right_region_width() -> float:
	var viewport_width := get_viewport_rect().size.x
	var parent_global_x := global_position.x if is_inside_tree() else 0.0
	return maxf(0.0, viewport_width - parent_global_x - _right_region_left_x())

func _right_region_center_x() -> float:
	return _right_region_left_x() + _right_region_width() * 0.5

func _on_player_data_changed() -> void:
	refresh_display()

# ── 卡牌拖放到此槽位 ──
func _on_card_dropped(target_index: int, card: CardInfo, source: String, source_index: int) -> void:
	if source == "hand":
		var ok := await _handle_hand_to_vault(card, source_index, target_index)
		if ok:
			DragSystem.notify_drop_completed(card, source, "vault")
		else:
			DragSystem.cancel_drag()
		return

	if source == "vault":
		var ok := await _handle_vault_to_vault(card, source_index, target_index)
		if ok:
			DragSystem.notify_drop_completed(card, source, "vault")
		else:
			DragSystem.cancel_drag()
		return

	DragSystem.cancel_drag()


func _handle_hand_to_vault(card: CardInfo, hand_idx: int, vault_target_idx: int) -> bool:
	var hand = GameManager.player_data.hand_cards
	var vault = GameManager.player_data.vault_cards
	if hand_idx < 0 or hand_idx >= hand.size() or hand[hand_idx] == null:
		print("[VaultUI] 手牌槽位无效")
		return false

	var target_idx := vault_target_idx
	if target_idx < 0 or target_idx >= GameManager.player_data.vault_slots or not _is_vault_slot_unlocked(target_idx):
		target_idx = -1
	elif target_idx < vault.size() and vault[target_idx] != null:
		target_idx = -1

	if target_idx < 0:
		for i in range(GameManager.player_data.vault_slots):
			if not _is_vault_slot_unlocked(i):
				continue
			if i >= vault.size() or vault[i] == null:
				target_idx = i
				break

	if target_idx < 0:
		print("[VaultUI] 保险箱已满")
		return false

	var sync_resp := await GameManager.sync_pool_hand_layout()
	if not sync_resp.get("success", false):
		print("[VaultUI] 存保险箱前同步失败: ", sync_resp.get("error", ""))
		return false

	var resp := await ApiClient.move_to_vault("hand", hand_idx, target_idx)
	if not resp.get("success", false):
		print("[VaultUI] 存保险箱失败: ", resp.get("error", ""))
		return false

	hand[hand_idx] = null

	while vault.size() <= target_idx:
		vault.append(null)
	vault[target_idx] = card

	# 选中状态可能因数据变化而失效，清除
	_clear_selection()
	GameManager.player_data.changed.emit()
	card_dragged.emit(card, target_idx)
	return true


func _handle_vault_to_vault(card: CardInfo, source_vault_idx: int, target_vault_idx: int) -> bool:
	var vault = GameManager.player_data.vault_cards
	if target_vault_idx < 0 or target_vault_idx >= GameManager.player_data.vault_slots or not _is_vault_slot_unlocked(target_vault_idx):
		print("[VaultUI] 目标保险箱槽位无效")
		return false

	source_vault_idx = _resolve_card_index(vault, card, source_vault_idx)
	if source_vault_idx < 0:
		print("[VaultUI] 源保险箱槽位无效")
		return false
	if not _is_vault_slot_unlocked(source_vault_idx):
		print("[VaultUI] 源保险箱槽位未解锁")
		return false

	while vault.size() <= maxi(source_vault_idx, target_vault_idx):
		vault.append(null)
	if source_vault_idx == target_vault_idx:
		return true

	var old_vault := vault.duplicate()
	var target_card = vault[target_vault_idx]
	if target_card != null:
		DragSystem.play_swap_animation("vault", source_vault_idx, "vault", target_vault_idx, card, target_card)
	vault[target_vault_idx] = vault[source_vault_idx]
	vault[source_vault_idx] = target_card
	_clear_selection()

	GameManager.player_data.changed.emit()
	card_dragged.emit(card, source_vault_idx)

	if ApiClient.is_logged_in():
		var sync_resp := await ApiClient.sync_vault_layout(vault)
		if not sync_resp.get("success", false):
			print("[VaultUI] 保险箱布局同步失败: ", sync_resp.get("error", ""))
			GameManager.player_data.vault_cards = old_vault
			await GameManager.sync_vault_from_server()
			GameManager.player_data.changed.emit()
			return false

	return true


func _resolve_card_index(cards: Array, card: CardInfo, preferred_idx: int) -> int:
	if preferred_idx >= 0 and preferred_idx < cards.size() and cards[preferred_idx] != null:
		return preferred_idx
	for i in range(cards.size()):
		if cards[i] != null and cards[i].get_uid() == card.get_uid():
			return i
	return -1


func refresh_display() -> void:
	var render_started := Time.get_ticks_msec()
	FileLogger.perf("ui_render_start", {"page": "vault", "component": "slot_grid"})
	var cards = GameManager.player_data.vault_cards
	_raw_slot_data = GameManager.vault_raw_slot_data
	_update_slot_count_from_server()
	_create_slot_grid()
	for i in range(slot_count):
		if i >= slots.size():
			continue
		# 应用锁定状态
		var unlocked := _is_vault_slot_unlocked(i)
		slots[i].set_unlocked(unlocked)
		
		if not _is_synthesis_hidden(i) and i < cards.size() and cards[i] != null:
			slots[i].set_card(cards[i], i)
		else:
			slots[i].clear_slot()

		# 恢复选中高亮
		_update_slot_selection_visual(i)
		slots[i].refresh_card_title_text_color()

	var label = get_node_or_null("SlotLabel") as Label
	if label != null:
		label.text = Localization.t("ui.vault.slot_count", [_count_occupied(cards), _count_unlocked_slots()])

	_update_unlock_buttons()
	_update_organize_button()

	# 更新合成按钮状态
	_update_synthesize_button()
	FileLogger.perf("ui_render_done", {"page": "vault", "component": "slot_grid", "slots": slot_count, "total_ms": Time.get_ticks_msec() - render_started})

func _update_organize_button() -> void:
	if _organize_btn == null:
		return
	_organize_btn.disabled = _organize_busy or _is_organize_cooling_down() or not ApiClient.is_logged_in()

func _update_unlock_buttons() -> void:
	var quote: Dictionary = GameManager.vault_slot_quote
	var costs: Dictionary = quote.get("costs", {})
	var gold_cost := int(costs.get("gold", 20))
	var gem_cost := int(costs.get("gem", 10))
	var has_quote := not quote.is_empty()

	if _gold_unlock_btn != null:
		_gold_unlock_btn.disabled = _unlock_buttons_busy or _is_unlock_cooling_down(_gold_unlock_cooldown)
	if _gem_unlock_btn != null:
		_gem_unlock_btn.disabled = _unlock_buttons_busy or _is_unlock_cooling_down(_gem_unlock_cooldown)
	if _gold_unlock_cost_label != null:
		_gold_unlock_cost_label.text = Localization.t("ui.vault.unlock_gold_cost", [gold_cost]) if has_quote else Localization.t("ui.vault.unlock_cost_loading")
	if _gem_unlock_cost_label != null:
		_gem_unlock_cost_label.text = Localization.t("ui.vault.unlock_gem_cost", [gem_cost]) if has_quote else Localization.t("ui.vault.unlock_cost_loading")

func _on_organize_vault_pressed() -> void:
	if _organize_busy or not ApiClient.is_logged_in():
		return
	if not _try_start_organize_cooldown():
		return
	_organize_busy = true
	_update_organize_button()
	await _wait_for_prior_asset_operations()
	if not is_inside_tree():
		_organize_busy = false
		return

	var resp := await ApiClient.organize_vault()
	if resp.get("success", false):
		var data: Dictionary = resp.get("data", {})
		var vault_slots: Array = data.get("vault", [])
		if not vault_slots.is_empty():
			GameManager.apply_vault_slots_from_server(vault_slots)
		else:
			await GameManager.sync_vault_from_server()
		_clear_selection()
	else:
		print("[VaultUI] 整理保险箱失败: ", resp.get("error", "未知错误"))
		AudioManager.play_sfx("error_soft")
		await GameManager.sync_vault_from_server()

	_organize_busy = false
	if is_inside_tree():
		refresh_display()

func _try_start_organize_cooldown() -> bool:
	if _organize_cooldown == null:
		return true
	var accepted: bool = _organize_cooldown.try_start()
	_update_organize_button()
	return accepted

func _is_organize_cooling_down() -> bool:
	return _organize_cooldown != null and _organize_cooldown.is_cooling_down()

func _on_unlock_slot_pressed(currency: String) -> void:
	if _unlock_buttons_busy:
		return
	var cooldown := _gold_unlock_cooldown if currency == "gold" else _gem_unlock_cooldown
	if not _try_start_unlock_cooldown(cooldown):
		return
	_unlock_buttons_busy = true
	_update_unlock_buttons()

	var quote: Dictionary = GameManager.vault_slot_quote
	if quote.is_empty():
		var quote_resp := await GameManager.sync_vault_slot_quote_from_server()
		if not quote_resp.get("success", false):
			print("[VaultUI] 获取保险箱解锁报价失败: ", quote_resp.get("error", ""))
			_unlock_buttons_busy = false
			_update_unlock_buttons()
			return
		quote = GameManager.vault_slot_quote
	var slot_index := int(quote.get("next_slot_index", _count_unlocked_slots()))
	await _prepare_unlock_animation_target(slot_index)
	var resp := await ApiClient.unlock_slot("vault", slot_index, currency)
	if not resp.get("success", false):
		print("[VaultUI] 保险箱槽位购买失败: ", resp.get("error", "未知错误"))
		AudioManager.play_sfx("error_soft")
		await GameManager.sync_vault_from_server()
		await GameManager.sync_vault_slot_quote_from_server()
		_unlock_buttons_busy = false
		if is_inside_tree():
			refresh_display()
		return

	await _play_unlock_key_animation(currency, slot_index)
	var profile_resp := await ApiClient.get_profile()
	if profile_resp.get("success", false):
		GameManager.apply_profile(profile_resp["data"])
	await GameManager.sync_vault_from_server()
	await GameManager.sync_vault_slot_quote_from_server()

	_unlock_buttons_busy = false
	if is_inside_tree():
		refresh_display()

func _prepare_unlock_animation_target(slot_index: int) -> void:
	if slot_index < 0:
		return
	if slot_index >= slot_count:
		var target_rows := int(floor(float(slot_index) / float(columns))) + 1
		slot_count = maxi(slot_count, target_rows * columns)
	_create_slot_grid()
	await get_tree().process_frame
	_scroll_unlock_slot_into_view(slot_index)
	await get_tree().process_frame

func _scroll_unlock_slot_into_view(slot_index: int) -> void:
	if _slot_viewport == null or slot_index < 0 or slot_index >= slots.size():
		return
	var slot := slots[slot_index] as CardSlotUI
	if slot == null:
		return
	var current_scroll := float(_slot_viewport.scroll_vertical)
	var visible_top := current_scroll
	var visible_bottom := current_scroll + _slot_viewport.size.y
	var slot_top := slot.position.y - VAULT_GRID_SHADOW_SAFE_PADDING.y
	var slot_bottom := slot.position.y + slot.size.y + VAULT_GRID_SHADOW_SAFE_PADDING.y
	if slot_top < visible_top:
		_slot_viewport.scroll_vertical = maxi(0, int(floor(slot_top)))
	elif slot_bottom > visible_bottom:
		_slot_viewport.scroll_vertical = maxi(0, int(ceil(slot_bottom - _slot_viewport.size.y)))

func _play_unlock_key_animation(currency: String, slot_index: int) -> void:
	if not is_inside_tree() or get_tree() == null:
		return
	if slot_index < 0 or slot_index >= slots.size():
		return
	var target_slot := slots[slot_index] as CardSlotUI
	if target_slot == null or not target_slot.is_inside_tree():
		return
	var target_rect := target_slot.get_lock_icon_global_rect()
	if target_rect.size.x <= 1.0 or target_rect.size.y <= 1.0:
		var fallback_size := Vector2.ONE * clampf(CardSlotUI.SLOT_SIZE.x * 0.45, 39.0, 63.0)
		target_rect = Rect2(target_slot.get_global_rect().get_center() - fallback_size * 0.5, fallback_size)

	var source_button := _gold_unlock_btn if currency == "gold" else _gem_unlock_btn
	var source_rect := source_button.get_global_rect() if source_button != null and source_button.is_inside_tree() else Rect2()
	var start_center := Vector2(size.x * 0.5, size.y * 0.5)
	if source_rect.size.x > 1.0 and source_rect.size.y > 1.0:
		start_center = Vector2(source_rect.position.x + source_rect.size.x * 0.5, source_rect.position.y + source_rect.size.y + 10.0)

	var target_center := target_rect.get_center()
	var edge := maxf(target_rect.size.x, target_rect.size.y)
	var icon := TextureRect.new()
	icon.name = "VaultUnlockKeyIcon"
	icon.texture = load(UNLOCK_KEY_TEXTURE_PATH) as Texture2D
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.size = Vector2(edge, edge) * UNLOCK_KEY_SCALE
	icon.position = start_center - icon.size * 0.5
	icon.pivot_offset = icon.size * 0.5
	icon.z_index = 3500
	get_tree().root.add_child(icon)

	var away := (start_center - target_center).normalized()
	if away.length() <= 0.01:
		away = Vector2.DOWN
	var reverse_center := start_center + away * maxf(UNLOCK_KEY_REVERSE_DISTANCE, edge * 1.15)
	var side := away.rotated(PI * 0.5) * clampf(start_center.distance_to(target_center) * 0.16, 38.0, 120.0)
	var control_center := reverse_center.lerp(target_center, 0.50) + side
	var reverse_tangent := (control_center - reverse_center).normalized()
	if reverse_tangent.length() <= 0.01:
		reverse_tangent = (target_center - reverse_center).normalized()
	var reverse_end_rotation := _key_rotation_for_direction(reverse_tangent)
	var spin_sweep := 360.0 * UNLOCK_KEY_START_SPINS_PER_SECOND * UNLOCK_KEY_REVERSE_DURATION * 0.5
	var start_rotation := reverse_end_rotation - spin_sweep
	icon.rotation_degrees = start_rotation
	var last_target_rotation := reverse_end_rotation

	var tween := create_tween()
	tween.tween_method(func(progress: float):
		if not is_instance_valid(icon):
			return
		var eased := 1.0 - pow(1.0 - progress, 3.0)
		var center := start_center.lerp(reverse_center, eased)
		var spin_progress := 2.0 * progress - progress * progress
		icon.position = center - icon.size * 0.5
		icon.rotation_degrees = start_rotation + spin_sweep * spin_progress
	, 0.0, 1.0, UNLOCK_KEY_REVERSE_DURATION).set_trans(Tween.TRANS_LINEAR)
	tween.tween_method(func(progress: float):
		if not is_instance_valid(icon):
			return
		var accelerated := progress * progress
		var center := _quadratic_bezier(reverse_center, control_center, target_center, accelerated)
		var tangent := _quadratic_bezier_tangent(reverse_center, control_center, target_center, accelerated)
		if tangent.length() <= 0.01:
			tangent = target_center - center
		var desired_rotation := _key_rotation_for_direction(tangent)
		var continuous_rotation := _nearest_equivalent_angle_degrees(desired_rotation, last_target_rotation)
		last_target_rotation = continuous_rotation
		icon.position = center - icon.size * 0.5
		icon.rotation_degrees = continuous_rotation
	, 0.0, 1.0, UNLOCK_KEY_TARGET_DURATION).set_trans(Tween.TRANS_LINEAR)
	tween.tween_callback(func():
		if is_instance_valid(target_slot):
			target_slot.consume_reward_key_unlock()
		AudioManager.play_sfx("slot_unlock", 1.0, 0.0)
	)
	tween.tween_property(icon, "modulate:a", 0.0, UNLOCK_KEY_FADE_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func():
		if is_instance_valid(icon):
			icon.queue_free()
	)
	await tween.finished


func _try_start_unlock_cooldown(cooldown: Control) -> bool:
	if cooldown == null:
		return true
	var accepted: bool = cooldown.try_start()
	_update_unlock_buttons()
	return accepted


func _is_unlock_cooling_down(cooldown: Control) -> bool:
	return cooldown != null and cooldown.is_cooling_down()

func _on_slot_clicked(index: int) -> void:
	if index >= slots.size():
		return
	var slot = slots[index]
	if not slot.is_occupied or not slot.is_unlocked():
		return

	# 保险箱和手牌一样，一次只允许选中一张卡牌。
	if _selected_slots.has(index):
		_selected_slots.erase(index)
	else:
		for old in _selected_slots.duplicate():
			_update_slot_selection_visual(old)
		_selected_slots.clear()
		_selected_slots.append(index)

	# 更新视觉
	for i in slots.size():
		_update_slot_selection_visual(i)

	_update_synthesize_button()

	var card = slot.get_card()
	if card != null:
		card_clicked.emit(card)

func _update_slot_selection_visual(slot_idx: int) -> void:
	if slot_idx >= slots.size():
		return
	var slot = slots[slot_idx]
	var is_selected = _selected_slots.has(slot_idx) and not _is_synthesis_hidden(slot_idx)

	# 清理旧版覆盖式选中框；选中视觉统一使用 CardSlotUI 的底层光圈，避免遮住卡面文字颜色。
	var to_remove: Array[Node] = []
	for child in slot.get_children():
		if child is ColorRect and child.name in ["VaultSelectHighlight", "VaultSelectNumBg"]:
			to_remove.append(child)
		if child is Label and child.name == "VaultSelectNum":
			to_remove.append(child)
	for node in to_remove:
		slot.remove_child(node)
		node.queue_free()

	slot.set_selected(is_selected)
	slot.refresh_card_title_text_color()

func _clear_selection() -> void:
	_selected_slots.clear()
	for i in slots.size():
		_update_slot_selection_visual(i)
	_update_synthesize_button()

func _update_synthesize_button() -> void:
	if _synthesize_btn == null:
		return
	if _relic_preview != null:
		_relic_preview.visible = false
		_relic_preview.clear_cards()

	var count = _selected_slots.size()
	if count <= 0:
		_synthesize_btn.visible = true
		_synthesize_btn.text = Localization.t("ui.synthesis.vault.count", [0])
		_synthesize_btn.disabled = true
		return

	var vault = GameManager.player_data.vault_cards
	var selected_idx := int(_selected_slots[0])
	if _vault_synthesis_animation_running or _is_synthesis_hidden(selected_idx) or selected_idx < 0 or selected_idx >= vault.size() or vault[selected_idx] == null:
		_synthesize_btn.visible = true
		_synthesize_btn.text = Localization.t("ui.synthesis.vault.count", [0])
		_synthesize_btn.disabled = true
		return

	var synthesis_indices := _find_synthesizable_indices_for_card(vault[selected_idx], selected_idx)
	_synthesize_btn.visible = true
	if synthesis_indices.size() == 5:
		_synthesize_btn.text = Localization.t("ui.synthesis.vault.valid")
		_synthesize_btn.disabled = _is_synthesize_cooling_down()
	else:
		_synthesize_btn.text = Localization.t("ui.synthesis.vault.count", [1])
		_synthesize_btn.disabled = true

func controller_synthesize() -> void:
	_on_synthesize_pressed()

func _validate_synthesis_cards(cards: Array[CardInfo]) -> bool:
	if cards.size() != 5:
		return false

	var series = cards[0].series_name
	var deck = cards[0].deck_name
	var color = cards[0].color
	var numbers: Array[int] = []

	for c in cards:
		if c.series_name != series or c.deck_name != deck or c.color != color:
			return false
		numbers.append(c.card_number)

	numbers.sort()
	return numbers == [1, 2, 3, 4, 5]

func _on_synthesize_pressed() -> void:
	if _vault_synthesis_animation_running:
		return
	if not _try_start_synthesize_cooldown():
		return
	if _selected_slots.size() != 1:
		return

	# 不让合成动画抢跑到仍在前序资产请求之后排队的合成请求前面。
	_vault_synthesis_animation_running = true
	await _wait_for_prior_asset_operations()
	if not is_inside_tree() or _selected_slots.size() != 1:
		_vault_synthesis_animation_running = false
		_update_synthesize_button()
		return

	var vault = GameManager.player_data.vault_cards
	var selected_idx := int(_selected_slots[0])
	if selected_idx < 0 or selected_idx >= vault.size() or vault[selected_idx] == null:
		_vault_synthesis_animation_running = false
		_update_synthesize_button()
		return
	var selected_slots := _find_synthesizable_indices_for_card(vault[selected_idx], selected_idx)
	if selected_slots.size() != 5:
		_vault_synthesis_animation_running = false
		_update_synthesize_button()
		return

	_synthesize_btn.disabled = true
	_synthesize_btn.text = Localization.t("ui.synthesis.vault.done")

	var animation_sources := get_synthesis_animation_sources(selected_slots)
	hide_synthesis_slots_for_animation(selected_slots)
	var overlay = SynthesisAnimationOverlayScript.new()
	overlay.name = "VaultSynthesisAnimationOverlay"
	overlay.setup(animation_sources, _nav_target_rect, true)
	get_tree().root.add_child(overlay)
	var completion := {"done": false, "success": false, "result": {}, "error": ""}
	_confirm_vault_synthesis_for_animation.call_deferred(selected_slots.duplicate(), overlay, completion)
	await overlay.play()
	await _wait_for_vault_synthesis_completion(completion)
	_vault_synthesis_animation_running = false

	if completion.get("success", false):
		_apply_vault_synthesis_pending_removal(selected_slots)
		_apply_vault_synthesis_confirmed_result(completion.get("result", {}))
		_sync_after_vault_synthesis_success_background()
	else:
		print("[VaultUI] 合成失败: ", completion.get("error", "未知错误"))
		await _recover_after_vault_synthesis_failure()


func _wait_for_prior_asset_operations() -> void:
	while is_inside_tree() and (
		CardPoolSystem.has_pending_confirm()
		or ApiClient.has_pending_asset_requests()
	):
		await get_tree().process_frame

func _wait_for_vault_synthesis_completion(completion: Dictionary) -> void:
	while is_inside_tree() and not bool(completion.get("done", false)):
		await get_tree().process_frame

func _try_start_synthesize_cooldown() -> bool:
	if _synthesize_cooldown == null:
		return true
	var accepted: bool = _synthesize_cooldown.try_start()
	_update_synthesize_button()
	return accepted

func _is_synthesize_cooling_down() -> bool:
	return _synthesize_cooldown != null and _synthesize_cooldown.is_cooling_down()

func _attach_action_cooldown(button: Button) -> Control:
	var existing := button.get_node_or_null("AssetActionCooldown") as Control
	if existing != null:
		return existing
	var cooldown := AssetActionCooldownScript.new() as Control
	cooldown.name = "AssetActionCooldown"
	cooldown.set_anchors_preset(Control.PRESET_FULL_RECT)
	cooldown.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cooldown.z_index = 128
	button.add_child(cooldown)
	if button == _synthesize_btn:
		cooldown.cooldown_finished.connect(_update_synthesize_button)
	elif button == _organize_btn:
		cooldown.cooldown_finished.connect(_update_organize_button)
	else:
		cooldown.cooldown_finished.connect(_update_unlock_buttons)
	return cooldown

func get_synthesis_animation_sources(indices: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var vault = GameManager.player_data.vault_cards
	for global_idx in indices:
		var idx := int(global_idx)
		var card: CardInfo = vault[idx] if idx >= 0 and idx < vault.size() else null
		var visible_slot: CardSlotUI = null
		if idx >= 0 and idx < slots.size():
			var slot := slots[idx]
			if _is_slot_visible_for_animation(slot):
				visible_slot = slot
		result.append({
			"index": idx,
			"card": card,
			"global_rect": visible_slot.get_global_rect() if visible_slot != null else Rect2(),
			"visible": visible_slot != null,
		})
	return result

func hide_synthesis_slots_for_animation(indices: Array) -> void:
	_synthesis_hidden_indices.clear()
	for global_idx in indices:
		var idx := int(global_idx)
		_synthesis_hidden_indices[idx] = true
		if idx < 0 or idx >= slots.size():
			continue
		var slot := slots[idx] as CardSlotUI
		if slot == null:
			continue
		slot.clear_slot()
		_update_slot_selection_visual(idx)

func clear_synthesis_animation_hidden_slots() -> void:
	_synthesis_hidden_indices.clear()

func _is_synthesis_hidden(global_idx: int) -> bool:
	return _synthesis_hidden_indices.has(global_idx)

func _play_vault_synthesis_animation(animation_sources: Array[Dictionary]) -> void:
	if animation_sources.is_empty() or get_tree() == null:
		return
	var overlay = SynthesisAnimationOverlayScript.new()
	overlay.name = "VaultSynthesisAnimationOverlay"
	overlay.setup(animation_sources, _nav_target_rect)
	get_tree().root.add_child(overlay)
	await overlay.play()

func _is_slot_visible_for_animation(slot: CardSlotUI) -> bool:
	if slot == null or not slot.is_inside_tree() or not slot.visible or not slot.is_occupied:
		return false
	if _slot_viewport == null or not _slot_viewport.is_inside_tree():
		return true
	var slot_rect := slot.get_global_rect()
	var viewport_rect := _slot_viewport.get_global_rect()
	return viewport_rect.intersects(slot_rect)

func _find_synthesizable_indices_for_card(selected_card: CardInfo, selected_idx: int) -> Array[int]:
	if selected_card == null:
		return []
	var vault = GameManager.player_data.vault_cards
	var by_number: Dictionary = {}
	var selected_number := int(selected_card.card_number)
	if selected_number >= 1 and selected_number <= 5:
		by_number[selected_number] = selected_idx
	for i in range(vault.size()):
		var card = vault[i]
		if card == null or i == selected_idx:
			continue
		if card.series_name != selected_card.series_name:
			continue
		if card.deck_name != selected_card.deck_name:
			continue
		if card.color != selected_card.color:
			continue
		var number := int(card.card_number)
		if number < 1 or number > 5:
			continue
		if not by_number.has(number):
			by_number[number] = i

	var result: Array[int] = []
	for number in [1, 2, 3, 4, 5]:
		if not by_number.has(number):
			return []
		result.append(int(by_number[number]))
	return result

func _confirm_vault_synthesis_for_animation(
	selected_slots: Array,
	overlay: SynthesisAnimationOverlay,
	completion: Dictionary
) -> void:
	var resp = await ApiClient.synthesize(selected_slots, "vault")
	if resp["success"]:
		var result_data: Dictionary = resp["data"]
		completion["success"] = true
		completion["result"] = result_data
		completion["done"] = true
		if is_instance_valid(overlay):
			overlay.set_reward_items(_resolve_vault_synthesis_reward_targets(result_data), true)
	else:
		completion["error"] = str(resp.get("error", "未知错误"))
		completion["done"] = true
		if is_instance_valid(overlay):
			overlay.set_reward_items([], false)

func _resolve_vault_synthesis_reward_targets(result_data: Dictionary) -> Array[Dictionary]:
	var resolved: Array[Dictionary] = []
	for raw_entry in SynthesisAnimationOverlay.extract_reward_entries(result_data):
		var entry: Dictionary = raw_entry.duplicate()
		match str(entry.get("type", "")):
			"gold":
				entry["target_rect"] = _gold_target_rect
			"gems":
				entry["target_rect"] = _gems_target_rect
			"stamina":
				entry["target_rect"] = _stamina_target_rect
			"slot":
				if str(entry.get("slot_type", "")) == "vault":
					entry["target_rect"] = _vault_nav_target_rect
				else:
					var viewport_size := get_viewport_rect().size
					entry["target_rect"] = Rect2(Vector2(viewport_size.x * 0.5 - 21.0, viewport_size.y + 48.0), Vector2(42.0, 42.0))
		resolved.append(entry)
	return resolved

func _apply_vault_synthesis_pending_removal(selected_slots: Array) -> void:
	var vault = GameManager.player_data.vault_cards
	var sorted_indices := selected_slots.duplicate()
	sorted_indices.sort()
	for i in range(sorted_indices.size() - 1, -1, -1):
		var idx = sorted_indices[i]
		if idx < vault.size():
			vault[idx] = null

	clear_synthesis_animation_hidden_slots()
	_clear_selection()
	GameManager.player_data.changed.emit()
	refresh_display()

	if _synthesize_btn != null:
		_synthesize_btn.text = Localization.t("ui.synthesis.vault.count", [0])
		_synthesize_btn.visible = true
		_synthesize_btn.disabled = true

func _apply_vault_synthesis_confirmed_result(result_data: Dictionary) -> void:
	var rewards: Dictionary = result_data.get("rewards", {})
	var gold := int(result_data.get("gold_reward", rewards.get("gold", 0)))
	if gold > 0:
		GameManager.player_data.add_gold(gold)

	var gems := int(rewards.get("gems", 0))
	if gems > 0:
		GameManager.player_data.add_gems(gems)

	var exp_result: Dictionary = result_data.get("exp_result", {})
	if not exp_result.is_empty():
		GameManager.apply_exp_result(exp_result, true)

	var deck_data = result_data.get("deck", {})
	if not deck_data.is_empty():
		DeckSystem.add_synthesized_deck(deck_data)

	GameManager.player_data.changed.emit()

func _sync_after_vault_synthesis_success_background() -> void:
	await GameManager.sync_reward_state_from_server()
	await GameManager.sync_decks_from_server()
	if is_inside_tree():
		refresh_display()

func _recover_after_vault_synthesis_failure() -> void:
	if _synthesize_btn != null:
		_synthesize_btn.text = Localization.t("ui.synthesis.vault.failed")
		_synthesize_btn.disabled = false
	await GameManager.sync_vault_from_server()
	await GameManager.sync_decks_from_server()
	if is_inside_tree():
		clear_synthesis_animation_hidden_slots()
		refresh_display()
		_update_synthesize_button()

func _extract_consumed_indices(result_data: Dictionary) -> Array[int]:
	var consumed = result_data.get("consumed_slots", [])
	var indices: Array[int] = []
	for slot in consumed:
		if slot is Dictionary:
			var idx := int(slot.get("slot_index", -1))
			if idx >= 0:
				indices.append(idx)
	return indices

# ── 全局拖拽事件 ──

func _on_drag_ended(_card: CardInfo, _from: String, _to: String) -> void:
	_refresh_all()


func _on_drag_cancelled() -> void:
	_refresh_all()


func _refresh_all() -> void:
	refresh_display()

func _update_slot_count_from_server() -> void:
	var max_server_index := -1
	for raw in _raw_slot_data:
		if raw is Dictionary:
			max_server_index = maxi(max_server_index, int(raw.get("slot_index", -1)))

	var server_slots := max_server_index + 1
	var card_slots = GameManager.player_data.vault_cards.size()
	if server_slots > 0:
		GameManager.player_data.vault_slots = maxi(GameManager.player_data.vault_slots, server_slots)
	elif card_slots > 0:
		GameManager.player_data.vault_slots = maxi(GameManager.player_data.vault_slots, card_slots)
	slot_count = _calculate_render_slot_count()

func _calculate_render_slot_count() -> int:
	var unlocked_count := _count_unlocked_slots()
	var highest_needed_index := maxi(0, unlocked_count - 1)
	for i in range(GameManager.player_data.vault_cards.size()):
		if GameManager.player_data.vault_cards[i] != null:
			highest_needed_index = maxi(highest_needed_index, i)

	var unlocked_rows := maxi(1, int(ceil(float(highest_needed_index + 1) / float(VAULT_COLUMNS))))
	var rows_to_render := unlocked_rows + EXTRA_LOCKED_ROWS
	return rows_to_render * VAULT_COLUMNS

func _count_occupied(cards: Array) -> int:
	var count := 0
	for card in cards:
		if card != null:
			count += 1
	return count

func _count_unlocked_slots() -> int:
	if _raw_slot_data.is_empty():
		return GameManager.player_data.vault_slots
	var count := 0
	for raw in _raw_slot_data:
		if raw is Dictionary and raw.get("unlocked", false):
			count += 1
	return count

func _is_vault_slot_unlocked(index: int) -> bool:
	if index < 0:
		return false
	for raw in _raw_slot_data:
		if raw is Dictionary and int(raw.get("slot_index", -1)) == index:
			return raw.get("unlocked", false)
	return _raw_slot_data.is_empty() and index < GameManager.player_data.vault_slots

func _quadratic_bezier(a: Vector2, b: Vector2, c: Vector2, t: float) -> Vector2:
	var p := clampf(t, 0.0, 1.0)
	return a * (1.0 - p) * (1.0 - p) + b * 2.0 * (1.0 - p) * p + c * p * p

func _quadratic_bezier_tangent(a: Vector2, b: Vector2, c: Vector2, t: float) -> Vector2:
	var p := clampf(t, 0.0, 1.0)
	return (b - a) * 2.0 * (1.0 - p) + (c - b) * 2.0 * p

func _key_rotation_for_direction(direction: Vector2) -> float:
	if direction.length() <= 0.01:
		return 0.0
	return rad_to_deg(direction.angle()) - 90.0

func _nearest_equivalent_angle_degrees(target_degrees: float, reference_degrees: float) -> float:
	var result := target_degrees
	while result - reference_degrees > 180.0:
		result -= 360.0
	while result - reference_degrees < -180.0:
		result += 360.0
	return result
