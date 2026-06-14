extends Control
class_name CurrencyUI

var _gold_label: Label
var _gems_label: Label
var _stamina_label: Label

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS  # 不阻挡点击事件
	setup_ui()
	GameManager.player_data.changed.connect(_on_player_data_changed)
	GameManager.free_refresh_cooldown_updated.connect(_on_free_refresh_cooldown_updated)
	GameManager.free_refresh_ready.connect(_on_free_refresh_ready)

func setup_ui() -> void:
	# 水平并排：体力 → 金币 → 宝石
	var hbox = HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.alignment = BoxContainer.ALIGNMENT_END
	hbox.add_theme_constant_override("separation", 8)
	hbox.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(hbox)

	_stamina_label = Label.new()
	_stamina_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_stamina_label.add_theme_font_size_override("font_size", 18)
	_stamina_label.text = "⚡ 100/1"
	_stamina_label.name = "StaminaLabel"
	_stamina_label.mouse_filter = Control.MOUSE_FILTER_PASS
	hbox.add_child(_stamina_label)

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

func _on_free_refresh_cooldown_updated(_remaining: float) -> void:
	refresh()

func _on_free_refresh_ready() -> void:
	refresh()

func refresh() -> void:
	var pd = GameManager.player_data
	_stamina_label.text = "⚡ %d/%d" % [GameManager.get_stamina_display_current(), GameManager.get_stamina_display_max()]
	_gold_label.text = "💰 %d" % pd.gold
	_gems_label.text = "💎 %d" % pd.gems
