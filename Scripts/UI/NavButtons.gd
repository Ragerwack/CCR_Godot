extends Control
class_name NavButtons

signal nav_button_clicked(id: String)

const CCRVisualStyle = preload("res://Scripts/UI/CCRVisualStyle.gd")

const NAV_ITEMS: Array[Dictionary] = [
	{"id": "today_decks", "label_key": "ui.nav.today_decks", "icon_id": "nav_today_decks", "enabled": true},
	{"id": "card_pool", "label_key": "ui.nav.card_pool", "icon_id": "nav_card_pool", "enabled": true},
	{"id": "vault", "label_key": "ui.nav.vault", "icon_id": "nav_vault", "enabled": true},
	{"id": "deck_panel", "label_key": "ui.nav.deck_panel", "icon_id": "nav_museum", "enabled": true},
	{"id": "auction", "label_key": "ui.nav.auction", "icon_id": "nav_auction", "enabled": false},
	{"id": "ladder", "label_key": "ui.nav.ladder", "icon_id": "nav_leaderboard", "enabled": false},
	{"id": "mail", "label_key": "ui.nav.mail", "icon_id": "nav_mail", "enabled": false},
	{"id": "settings", "label_key": "ui.nav.settings", "icon_id": "nav_settings", "enabled": true},
	{"id": "exit_game", "label_key": "ui.nav.exit_game", "icon_id": "nav_exit", "enabled": true},
]

var buttons: Array[Button] = []
var selected_index: int = 1
var _button_width: float = 96.0
var _button_height: float = 36.0

func _ready() -> void:
	setup_ui()

func configure_button_metrics(button_width: float, button_height: float) -> void:
	_button_width = maxf(64.0, button_width)
	_button_height = maxf(24.0, button_height)
	if is_node_ready():
		_layout_buttons()

func setup_ui() -> void:
	for i in range(NAV_ITEMS.size()):
		var item := NAV_ITEMS[i]
		var btn = Button.new()
		btn.name = "NavButton_%s" % str(item["id"])
		btn.set_anchors_preset(Control.PRESET_TOP_LEFT)
		btn.add_theme_font_size_override("font_size", _font_size())
		var label := Localization.t(item["label_key"])
		btn.text = label
		btn.tooltip_text = "" if item.get("enabled", true) else Localization.t("ui.nav.coming_soon", [label])
		btn.disabled = not item.get("enabled", true)
		btn.pressed.connect(_on_button_pressed.bind(i))
		_apply_style(btn, i == selected_index)
		buttons.append(btn)
		add_child(btn)
	_layout_buttons()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_node_ready():
		_layout_buttons()

func _layout_buttons() -> void:
	if buttons.is_empty():
		return
	var btn_width := minf(_button_width, maxf(0.0, size.x))
	var btn_height := _button_height
	var total_btn_h := buttons.size() * btn_height
	var first_gap := maxf(4.0, (size.y - total_btn_h) / float(buttons.size() + 1))
	# 第一项保持原位；其余项压缩间距，使最后一项整体上移一个按钮高度。
	var compressed_gap := first_gap
	if buttons.size() > 1:
		compressed_gap = maxf(0.0, first_gap - btn_height / float(buttons.size() - 1))
	var x := (size.x - btn_width) * 0.5
	for i in range(buttons.size()):
		var btn := buttons[i]
		btn.position = Vector2(x, first_gap + i * (btn_height + compressed_gap))
		btn.custom_minimum_size = Vector2(btn_width, btn_height)
		btn.size = Vector2(btn_width, btn_height)
		CCRVisualStyle.configure_relic_button_metrics(btn, btn_height)

func refresh_labels() -> void:
	for i in range(mini(buttons.size(), NAV_ITEMS.size())):
		var item := NAV_ITEMS[i]
		var label := Localization.t(item["label_key"])
		buttons[i].text = label
		buttons[i].tooltip_text = "" if item.get("enabled", true) else Localization.t("ui.nav.coming_soon", [label])
		buttons[i].add_theme_font_size_override("font_size", _font_size())

func select_by_id(id: String) -> void:
	for i in range(NAV_ITEMS.size()):
		if str(NAV_ITEMS[i].get("id", "")) == id:
			selected_index = i
			for j in range(buttons.size()):
				_apply_style(buttons[j], j == selected_index)
			return

func get_button_global_rect(id: String) -> Rect2:
	for i in range(mini(NAV_ITEMS.size(), buttons.size())):
		if str(NAV_ITEMS[i].get("id", "")) == id:
			return buttons[i].get_global_rect()
	return Rect2()

func select_next_enabled(direction: int) -> void:
	if NAV_ITEMS.is_empty():
		return
	var step := 1 if direction >= 0 else -1
	for offset in range(1, NAV_ITEMS.size() + 1):
		var index := wrapi(selected_index + offset * step, 0, NAV_ITEMS.size())
		if NAV_ITEMS[index].get("enabled", true):
			_on_button_pressed(index)
			return

func _on_button_pressed(index: int) -> void:
	if not NAV_ITEMS[index].get("enabled", true):
		return
	selected_index = index
	for i in range(buttons.size()):
		_apply_style(buttons[i], i == selected_index)
	nav_button_clicked.emit(NAV_ITEMS[index]["id"])

func _apply_style(btn: Button, selected: bool) -> void:
	var index := buttons.find(btn)
	if index < 0:
		index = get_child_count()
	var icon_id := "nav_card_pool"
	if index >= 0 and index < NAV_ITEMS.size():
		icon_id = str(NAV_ITEMS[index].get("icon_id", icon_id))
	CCRVisualStyle.apply_relic_button(btn, icon_id, selected, "navigation")

func _font_size() -> int:
	if _button_width < 120.0:
		return 11 if Localization.locale == "en" else 13
	return 13 if Localization.locale == "en" else 16
