extends Control
class_name NavButtons

signal nav_button_clicked(id: String)

const NAV_ITEMS: Array[Dictionary] = [
	{"id": "card_pool", "label_key": "ui.nav.card_pool", "enabled": true},
	{"id": "vault", "label_key": "ui.nav.vault", "enabled": true},
	{"id": "deck_panel", "label_key": "ui.nav.deck_panel", "enabled": true},
	{"id": "auction", "label_key": "ui.nav.auction", "enabled": false},
	{"id": "ladder", "label_key": "ui.nav.ladder", "enabled": false},
	{"id": "mail", "label_key": "ui.nav.mail", "enabled": false},
]

var buttons: Array[Button] = []
var selected_index: int = 0

func _ready() -> void:
	setup_ui()

func setup_ui() -> void:
	var btn_height = 36
	var spacing = 4
	var total_btn_h = NAV_ITEMS.size() * btn_height + (NAV_ITEMS.size() - 1) * spacing
	# 垂直居中：计算起始 Y，使按钮组整体在容器中居中
	var pad_top = max(4.0, (size.y - total_btn_h) / 2.0)
	var pad_left = 8
	var btn_width = size.x - pad_left * 2

	for i in range(NAV_ITEMS.size()):
		var item := NAV_ITEMS[i]
		var y = pad_top + i * (btn_height + spacing)
		var btn = Button.new()
		btn.set_anchors_preset(Control.PRESET_TOP_LEFT)
		btn.position = Vector2(pad_left, y)
		btn.size = Vector2(btn_width, btn_height)
		var label := Localization.t(item["label_key"])
		btn.text = label if item.get("enabled", true) else Localization.t("ui.nav.coming_soon", [label])
		btn.disabled = not item.get("enabled", true)
		btn.pressed.connect(_on_button_pressed.bind(i))
		_apply_style(btn, i == selected_index)
		buttons.append(btn)
		add_child(btn)

func _on_button_pressed(index: int) -> void:
	if not NAV_ITEMS[index].get("enabled", true):
		return
	selected_index = index
	for i in range(buttons.size()):
		_apply_style(buttons[i], i == selected_index)
	nav_button_clicked.emit(NAV_ITEMS[index]["id"])

func _apply_style(btn: Button, selected: bool) -> void:
	var style = StyleBoxFlat.new()
	if selected:
		style.bg_color = Color(0.3, 0.5, 0.8, 1.0)  # 蓝色高亮
	else:
		style.bg_color = Color(0.2, 0.2, 0.3, 1.0)  # 深色背景
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	btn.add_theme_stylebox_override("normal", style)
