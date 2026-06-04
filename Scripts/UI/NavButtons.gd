extends Control
class_name NavButtons

signal nav_button_clicked(id: String)

@export var button_labels: Array[String] = ["抽卡", "保险箱", "博物馆", "拍卖行", "天梯榜", "邮箱"]

var buttons: Array[Button] = []
var selected_index: int = 0

func _ready() -> void:
	setup_ui()

func setup_ui() -> void:
	var btn_height = 36
	var spacing = 4
	var total_btn_h = button_labels.size() * btn_height + (button_labels.size() - 1) * spacing
	# 垂直居中：计算起始 Y，使按钮组整体在容器中居中
	var pad_top = max(4.0, (size.y - total_btn_h) / 2.0)
	var pad_left = 8
	var btn_width = size.x - pad_left * 2

	for i in range(button_labels.size()):
		var y = pad_top + i * (btn_height + spacing)
		var btn = Button.new()
		btn.set_anchors_preset(Control.PRESET_TOP_LEFT)
		btn.position = Vector2(pad_left, y)
		btn.size = Vector2(btn_width, btn_height)
		btn.text = button_labels[i]
		btn.pressed.connect(_on_button_pressed.bind(i))
		_apply_style(btn, i == selected_index)
		buttons.append(btn)
		add_child(btn)

func _on_button_pressed(index: int) -> void:
	selected_index = index
	for i in range(buttons.size()):
		_apply_style(buttons[i], i == selected_index)
	nav_button_clicked.emit(button_labels[index])

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
