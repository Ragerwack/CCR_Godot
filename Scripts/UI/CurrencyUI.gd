extends Control
class_name CurrencyUI

var _gold_label: Label
var _gems_label: Label

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS  # 不阻挡点击事件
	setup_ui()
	GameManager.player_data.changed.connect(_on_player_data_changed)

func setup_ui() -> void:
	# 水平并排：金币 → 宝石（使用 HBoxContainer）
	var hbox = HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.alignment = BoxContainer.ALIGNMENT_END
	hbox.add_theme_constant_override("separation", 8)
	hbox.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(hbox)

	_gold_label = Label.new()
	_gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_gold_label.add_theme_font_size_override("font_size", 18)
	_gold_label.text = "💰 100"
	_gold_label.name = "GoldLabel"
	_gold_label.mouse_filter = Control.MOUSE_FILTER_PASS
	hbox.add_child(_gold_label)

	_gems_label = Label.new()
	_gems_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_gems_label.add_theme_font_size_override("font_size", 18)
	_gems_label.text = "💎 10"
	_gems_label.name = "GemsLabel"
	_gems_label.mouse_filter = Control.MOUSE_FILTER_PASS
	hbox.add_child(_gems_label)

func _on_player_data_changed() -> void:
	refresh()

func refresh() -> void:
	var pd = GameManager.player_data
	_gold_label.text = "💰 %d" % pd.gold
	_gems_label.text = "💎 %d" % pd.gems
