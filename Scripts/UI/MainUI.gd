extends Control
class_name MainUI

@export var enable_debug: bool = false

const LEFT_PANEL_WIDTH: int = 120
const TOP_BAR_HEIGHT: int = 90
const EXP_BAR_RATIO: float = 0.06   # 底部经验条占屏比

var _player_info: PlayerInfoUI
var _currency: CurrencyUI
var _nav_buttons: NavButtons
var _center_area: Control
var _exp_bar_ui: ExpBarUI

# 子面板
var _card_pool_ui: CardPoolUI = null
var _hand_area_ui: HandAreaUI = null
var _vault_ui: VaultUI = null
var _synthesis_panel: SynthesisPanelUI = null
var _deck_collection_ui: DeckCollectionUI = null

# 加载遮罩
var _loading_overlay: ColorRect = null

func _ready() -> void:
	setup_ui()

	GameManager.scene_changed.connect(_on_scene_changed)
	_nav_buttons.nav_button_clicked.connect(_on_nav_button)
	ApiClient.auth_expired.connect(_on_auth_expired)

	# 总是先显示开机界面（全屏覆盖在一切之上）
	_show_splash_screen()

# ══════════════════════════════════════════════════
#  开机界面（Splash Screen）
# ══════════════════════════════════════════════════

func _show_splash_screen() -> void:
	# 隐藏所有游戏UI组件（导航栏、PlayerInfo、经验条等）
	_set_game_ui_visible(false)

	var splash = SplashScreenUI.new()
	splash.login_completed.connect(_on_splash_completed)
	add_child(splash)

func _set_game_ui_visible(visible: bool) -> void:
	if _player_info: _player_info.visible = visible
	if _currency: _currency.visible = visible
	if _nav_buttons: _nav_buttons.visible = visible
	if _exp_bar_ui: _exp_bar_ui.visible = visible

func _on_splash_completed() -> void:
	# 显示游戏UI，进入主界面
	_set_game_ui_visible(true)
	_initialize_card_pool.call_deferred()
	call_deferred("_deferred_server_sync")

func _deferred_server_sync() -> void:
	_show_loading_light(true)
	await GameManager.sync_all_from_server()
	_show_loading_light(false)
	# 同步完成后刷新当前视图，确保数据填充到 UI
	refresh_current_view()

func _initialize_card_pool() -> void:
	if not ApiClient.is_logged_in():
		return
	# 如果卡池已有数据（从 sync_all 并行加载得到），跳过加载
	if CardPoolSystem.current_pool.size() > 0:
		return
	_show_loading_light(true)
	await CardPoolSystem.load_pool_from_server()
	_show_loading_light(false)

# ══════════════════════════════════════════════════
#  加载遮罩
# ══════════════════════════════════════════════════

func _show_loading(show: bool) -> void:
	if show:
		if _loading_overlay == null:
			_loading_overlay = ColorRect.new()
			_loading_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
			_loading_overlay.color = Color(0, 0, 0, 0.3)
			_loading_overlay.mouse_filter = Control.MOUSE_FILTER_STOP

			# 添加加载文字提示
			var label = Label.new()
			label.name = "LoadingLabel"
			label.set_anchors_preset(Control.PRESET_CENTER)
			label.position = Vector2(0, -100)
			label.size = Vector2(200, 40)
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.text = "加载中..."
			label.add_theme_font_size_override("font_size", 18)
			label.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
			_loading_overlay.add_child(label)

			add_child(_loading_overlay)
		_loading_overlay.visible = true
	else:
		if _loading_overlay != null:
			# 完全清除遮罩，防止残留阻塞点击
			remove_child(_loading_overlay)
			_loading_overlay.queue_free()
			_loading_overlay = null

## 轻量加载提示 — 不阻挡点击，仅显示半透明遮罩 + 加载文字
var _loading_light: ColorRect = null

func _show_loading_light(show: bool) -> void:
	if show:
		if _loading_light == null:
			_loading_light = ColorRect.new()
			_loading_light.set_anchors_preset(Control.PRESET_FULL_RECT)
			_loading_light.color = Color(0, 0, 0, 0.15)  # 更淡
			_loading_light.mouse_filter = Control.MOUSE_FILTER_IGNORE  # 不阻挡点击

			var label = Label.new()
			label.name = "LoadingLabel"
			label.set_anchors_preset(Control.PRESET_CENTER)
			label.position = Vector2(0, -100)
			label.size = Vector2(200, 40)
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.text = "同步数据中..."
			label.add_theme_font_size_override("font_size", 14)
			label.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
			_loading_light.add_child(label)

			add_child(_loading_light)
		_loading_light.visible = true
	else:
		if _loading_light != null:
			remove_child(_loading_light)
			_loading_light.queue_free()
			_loading_light = null

# ══════════════════════════════════════════════════
#  登录 & 认证过期
# ══════════════════════════════════════════════════

func _show_login() -> void:
	var login_ui := LoginUI.new()
	login_ui.login_completed.connect(_on_login_completed)
	login_ui.name = "LoginUI"
	get_tree().root.call_deferred("add_child", login_ui)

func _on_login_completed() -> void:
	_show_loading(true)
	await GameManager.sync_all_from_server()
	_show_loading(false)
	_initialize_card_pool()
	refresh_current_view()

func _on_auth_expired() -> void:
	_show_login()

func _on_logout_pressed() -> void:
	ApiClient.logout()
	GameManager.player_data = PlayerData.new()
	GameManager.free_refresh_count = 1
	GameManager.free_refresh_cooldown = 0.0
	CardPoolSystem.current_pool.clear()
	_show_login()

# ══════════════════════════════════════════════════
#  UI 搭建
# ══════════════════════════════════════════════════

func setup_ui() -> void:
	var vp_size = get_viewport_rect().size
	var exp_bar_h = int(vp_size.y * EXP_BAR_RATIO)

	# ── 顶部栏：PlayerInfo（左上）+ Currency（右上贴边） ──
	_player_info = PlayerInfoUI.new()
	_player_info.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_player_info.position = Vector2(10, 10)
	_player_info.size = Vector2(LEFT_PANEL_WIDTH, 130)
	add_child(_player_info)

	_currency = CurrencyUI.new()
	_currency.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	# 金币+宝石并排显示，位于菜单按钮左侧（菜单 btn offset_left=-50）
	# CurrencyUI 宽 ~130px，右侧留 5px 间距给菜单按钮
	_currency.offset_left = -185   # -(130 宽 + 50 菜单宽 + 5 间距)
	_currency.offset_right = -55   # -(50 菜单宽 + 5 间距)
	_currency.offset_top = 10
	_currency.offset_bottom = 46   # 10 + 36 高（单行）
	add_child(_currency)

	# ── 菜单按钮（右上角，currency 右边） ──
	var menu_btn = Button.new()
	menu_btn.text = "\u2630"
	menu_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	menu_btn.position = Vector2(0, 10)
	menu_btn.offset_left = -50
	menu_btn.offset_right = -5
	menu_btn.offset_top = 10
	menu_btn.offset_bottom = 50
	menu_btn.pressed.connect(_show_menu)
	add_child(menu_btn)

	# ── 左侧导航 ──
	_nav_buttons = NavButtons.new()
	_nav_buttons.set_anchors_preset(Control.PRESET_TOP_LEFT)
	# 导航栏占满左侧栏从 TOP_BAR_HEIGHT 到底部经验条上方，内部按钮垂直居中
	_nav_buttons.offset_left = 0
	_nav_buttons.offset_right = LEFT_PANEL_WIDTH
	_nav_buttons.offset_top = TOP_BAR_HEIGHT
	_nav_buttons.offset_bottom = vp_size.y - exp_bar_h
	add_child(_nav_buttons)

	# ── 中央内容区（无右侧面板，全宽） ──
	_center_area = Control.new()
	_center_area.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_center_area.position = Vector2(LEFT_PANEL_WIDTH, TOP_BAR_HEIGHT)
	_center_area.size = Vector2(vp_size.x - LEFT_PANEL_WIDTH, vp_size.y - TOP_BAR_HEIGHT - exp_bar_h)
	_center_area.name = "CenterArea"
	add_child(_center_area)

	# ── 底部经验条 ──
	_exp_bar_ui = ExpBarUI.new()
	add_child(_exp_bar_ui)

	# 默认视图
	_show_card_pool()

	if enable_debug:
		_setup_debug_panel()

# ══════════════════════════════════════════════════
#  导航
# ══════════════════════════════════════════════════

func _on_nav_button(label: String) -> void:
	match label:
		"抽卡":      _show_card_pool()
		"保险箱":    _show_vault()
		"博物馆":    _show_deck_collection()
		"拍卖行":    _show_message("拍卖行")
		"天梯榜":    _show_message("天梯榜")
		"邮箱":      _show_message("邮箱")

# ══════════════════════════════════════════════════
#  中央视图切换
# ══════════════════════════════════════════════════

func _show_card_pool() -> void:
	_clear_center()

	_card_pool_ui = CardPoolUI.new()
	_card_pool_ui.card_double_clicked.connect(_on_card_pool_double_click)

	_hand_area_ui = HandAreaUI.new()
	# 连接手牌区操作信号
	_hand_area_ui.synthesize_requested.connect(_on_hand_synthesize)
	_hand_area_ui.discard_requested.connect(_on_hand_discard)
	_hand_area_ui.vault_save_requested.connect(_on_hand_save_to_vault)
	_hand_area_ui.card_double_clicked.connect(_on_hand_double_click)

	# 计算卡槽总高度（用于垂直居中）
	var slot_h = 135
	var slot_spacing = 8
	var pool_start_y = 24
	var hand_start_y = 12
	var pool_total_h = pool_start_y + 2 * (slot_h + slot_spacing) - slot_spacing  # 302
	var hand_total_h = hand_start_y + 2 * (slot_h + slot_spacing) - slot_spacing  # 290
	var sep_h = 4
	var total_h = pool_total_h + sep_h + hand_total_h  # 596

	# 垂直居中：卡池+手牌整体在中央区域居中
	var vbox = VBoxContainer.new()
	vbox.name = "CardPoolHandVBox"
	var vy = maxi(0, int((_center_area.size.y - total_h) / 2))
	vbox.position = Vector2(0, vy)
	vbox.size = Vector2(_center_area.size.x, total_h)
	vbox.add_theme_constant_override("separation", 0)
	_center_area.add_child(vbox)

	# 卡池区（上半固定高度，不拉伸）
	var pool_container = Control.new()
	pool_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pool_container.custom_minimum_size = Vector2(0, pool_total_h)
	vbox.add_child(pool_container)

	_card_pool_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	pool_container.add_child(_card_pool_ui)

	# 分隔线
	var sep = HSeparator.new()
	vbox.add_child(sep)

	# 手牌区（下半固定高度，不拉伸）
	var hand_container = Control.new()
	hand_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hand_container.custom_minimum_size = Vector2(0, hand_total_h)
	vbox.add_child(hand_container)

	_hand_area_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	hand_container.add_child(_hand_area_ui)
	_hand_area_ui.refresh_display()

func _show_vault() -> void:
	_clear_center()
	_vault_ui = VaultUI.new()
	_vault_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_center_area.add_child(_vault_ui)

func _show_deck_collection() -> void:
	_clear_center()
	_deck_collection_ui = DeckCollectionUI.new()
	_deck_collection_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_center_area.add_child(_deck_collection_ui)
	_deck_collection_ui.refresh()

func _show_synthesis_panel() -> void:
	_clear_center()
	_synthesis_panel = SynthesisPanelUI.new()
	_synthesis_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_synthesis_panel.synthesis_completed.connect(_on_synthesis_completed)
	_synthesis_panel.synthesis_cancelled.connect(_on_synthesis_cancelled)
	_center_area.add_child(_synthesis_panel)

func _on_synthesis_completed(_result: Dictionary) -> void:
	pass

func _on_synthesis_cancelled() -> void:
	_show_card_pool()

func _show_message(msg: String) -> void:
	_clear_center()
	var label = Label.new()
	label.set_anchors_preset(Control.PRESET_CENTER)
	label.size = Vector2(400, 100)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.text = msg
	_center_area.add_child(label)

func _show_menu() -> void:
	_clear_center()
	var menu_panel = _build_menu_panel()
	_center_area.add_child(menu_panel)

func _build_menu_panel() -> Control:
	var panel = Control.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.size = Vector2(400, 300)
	panel.add_child(vbox)

	var title = Label.new()
	title.text = "菜单"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	vbox.add_child(title)

	var music_row = _make_slider_row("音乐音量", AudioManager.bgm_volume, func(v): AudioManager.set_bgm_volume(v))
	vbox.add_child(music_row)

	var sfx_row = _make_slider_row("音效音量", AudioManager.sfx_volume, func(v): AudioManager.set_sfx_volume(v))
	vbox.add_child(sfx_row)

	var mute_btn = Button.new()
	mute_btn.text = "🔊 静音" if not AudioManager.is_muted else "🔇 已静音"
	mute_btn.pressed.connect(func():
		AudioManager.toggle_mute()
		mute_btn.text = "🔊 静音" if not AudioManager.is_muted else "🔇 已静音"
	)
	vbox.add_child(mute_btn)

	var sep = HSeparator.new()
	vbox.add_child(sep)

	var logout_btn = Button.new()
	logout_btn.text = "🚪 登出"
	logout_btn.pressed.connect(_on_logout_pressed)
	vbox.add_child(logout_btn)

	var back_btn = Button.new()
	back_btn.text = "返回"
	back_btn.pressed.connect(func(): _show_card_pool())
	vbox.add_child(back_btn)

	return panel

func _make_slider_row(label_text: String, default_val: float, callback: Callable) -> HBoxContainer:
	var row = HBoxContainer.new()
	var lbl = Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(100, 30)
	row.add_child(lbl)

	var slider = HSlider.new()
	slider.min_value = 0
	slider.max_value = 1
	slider.value = default_val
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(callback)
	row.add_child(slider)

	return row

# ══════════════════════════════════════════════════
#  手牌区操作（来自 HandAreaUI 信号）
# ══════════════════════════════════════════════════

func _on_hand_synthesize() -> void:
	_show_synthesis_panel()

func _on_hand_discard() -> void:
	var hand_cards = GameManager.player_data.hand_cards
	if hand_cards.size() == 0:
		return

	# 找最后一张非空手牌
	var idx = -1
	for i in range(hand_cards.size() - 1, -1, -1):
		if hand_cards[i] != null:
			idx = i
			break
	if idx < 0:
		return

	if not ApiClient.is_logged_in():
		hand_cards.remove_at(idx)
		GameManager.player_data.changed.emit()
		if is_instance_valid(_hand_area_ui):
			_hand_area_ui.refresh_display()
		return

	_show_loading(true)
	var resp = await ApiClient.discard_card("hand", idx)
	if resp["success"]:
		if idx < hand_cards.size():
			hand_cards.remove_at(idx)
		GameManager.player_data.changed.emit()
		if is_instance_valid(_hand_area_ui):
			_hand_area_ui.refresh_display()
	else:
		push_error("丢弃失败: ", resp["error"])
	_show_loading(false)

func _on_hand_save_to_vault() -> void:
	var hand_cards = GameManager.player_data.hand_cards
	if hand_cards.size() == 0:
		return

	# 找第一张非空手牌
	var source_idx = -1
	var card = null
	for i in range(hand_cards.size()):
		if hand_cards[i] != null:
			source_idx = i
			card = hand_cards[i]
			break
	if source_idx < 0:
		return

	# 找第一个空保险箱槽
	var vault_cards = GameManager.player_data.vault_cards
	var vault_idx = -1
	for i in range(GameManager.player_data.vault_slots):
		if i >= vault_cards.size() or vault_cards[i] == null:
			vault_idx = i
			break
	if vault_idx < 0:
		print("保险箱已满")
		return

	_show_loading(true)

	if not ApiClient.is_logged_in():
		# 离线模式：直接本地移动
		hand_cards.remove_at(source_idx)
		while vault_cards.size() < vault_idx:
			vault_cards.append(null)
		if vault_idx < vault_cards.size():
			vault_cards[vault_idx] = card
		else:
			vault_cards.append(card)
		GameManager.player_data.changed.emit()
		if is_instance_valid(_hand_area_ui):
			_hand_area_ui.refresh_display()
		_show_loading(false)
		return

	var resp = await ApiClient.move_to_vault("hand", source_idx, vault_idx)
	if resp["success"]:
		var result_data: Dictionary = resp["data"]
		var cd = ApiClient.card_slot_to_cardinfo(result_data)
		if card != null:
			cd.id = card.id

		if source_idx < hand_cards.size():
			hand_cards.remove_at(source_idx)

		while vault_cards.size() < vault_idx:
			vault_cards.append(null)
		if vault_idx < vault_cards.size():
			vault_cards[vault_idx] = cd
		else:
			vault_cards.append(cd)

		GameManager.player_data.changed.emit()

		if is_instance_valid(_hand_area_ui):
			_hand_area_ui.refresh_display()
	else:
		print("保存失败: ", resp["error"])

	_show_loading(false)

# ══════════════════════════════════════════════════
#  卡池双击 → 移入手牌
# ══════════════════════════════════════════════════

func _on_card_pool_double_click(card: CardInfo, slot_index: int) -> void:
	if not ApiClient.is_logged_in():
		CardPoolSystem.quick_move_to_hand(card)
		return
	CardPoolSystem.quick_move_to_hand(card)

# ══════════════════════════════════════════════════
#  手牌双击 → 移回卡池
# ══════════════════════════════════════════════════

func _on_hand_double_click(card: CardInfo, slot_index: int) -> void:
	if card == null:
		return
	CardPoolSystem.quick_move_from_hand_to_pool(card, slot_index)

func _on_scene_changed(scene_name: String) -> void:
	match scene_name:
		"CardPool": _show_card_pool()
		"Vault": _show_vault()
		"Main": _show_card_pool()

func _clear_center() -> void:
	for child in _center_area.get_children():
		_center_area.remove_child(child)
		child.queue_free()
	_card_pool_ui = null
	_hand_area_ui = null
	_vault_ui = null
	_synthesis_panel = null
	_deck_collection_ui = null

func refresh_current_view() -> void:
	_clear_center()
	_show_card_pool()

# ══════════════════════════════════════════════════
#  调试面板
# ══════════════════════════════════════════════════

func _setup_debug_panel() -> void:
	var debug = Control.new()
	debug.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	debug.position = Vector2(130, -120)
	debug.size = Vector2(300, 100)

	var panel = Panel.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	debug.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(vbox)

	var add_gold = Button.new()
	add_gold.text = "+100 金币"
	add_gold.pressed.connect(func(): GameManager.player_data.add_gold(100))
	vbox.add_child(add_gold)

	var add_gems = Button.new()
	add_gems.text = "+10 宝石"
	add_gems.pressed.connect(func(): GameManager.player_data.add_gems(10))
	vbox.add_child(add_gems)

	var add_exp = Button.new()
	add_exp.text = "+500 经验"
	add_exp.pressed.connect(func(): GameManager.on_exp_gained(500))
	vbox.add_child(add_exp)

	var sync_btn = Button.new()
	sync_btn.text = "🔄 从服务器同步"
	sync_btn.pressed.connect(func():
		await GameManager.sync_all_from_server()
		print("[DEBUG] 数据已同步")
	)
	vbox.add_child(sync_btn)

	add_child(debug)

	# 菜单按钮（因为导航中去掉了菜单项，在调试面板加一个）
	var menu_btn = Button.new()
	menu_btn.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	menu_btn.position = Vector2(130, -80)
	menu_btn.size = Vector2(80, 36)
	menu_btn.text = "菜单"
	menu_btn.pressed.connect(_show_menu)
	debug.add_child(menu_btn)
