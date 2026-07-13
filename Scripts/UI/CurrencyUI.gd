extends Control
class_name CurrencyUI

const CCRVisualStyle = preload("res://Scripts/UI/CCRVisualStyle.gd")

var _gold_label: Label
var _gems_label: Label
var _stamina_label: Label
var _status_icons: Array[TextureRect] = []
var _icon_size: float = 22.0

func configure_icon_size(icon_size: float) -> void:
	_icon_size = maxf(1.0, icon_size)
	for icon in _status_icons:
		icon.custom_minimum_size = Vector2(_icon_size, _icon_size)
		icon.size = Vector2(_icon_size, _icon_size)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	setup_ui()
	GameManager.player_data.changed.connect(_on_player_data_changed)
	GameManager.free_refresh_cooldown_updated.connect(_on_free_refresh_cooldown_updated)
	GameManager.free_refresh_ready.connect(_on_free_refresh_ready)
	refresh()

func setup_ui() -> void:
	# 水平并排：体力 → 金币 → 宝石
	var hbox = HBoxContainer.new()
	hbox.name = "CurrencyStatusRow"
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.alignment = BoxContainer.ALIGNMENT_END
	hbox.add_theme_constant_override("separation", 6)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hbox)

	_stamina_label = _create_status_item(hbox, "status_stamina", "StaminaIcon", "StaminaLabel")
	_gold_label = _create_status_item(hbox, "status_gold", "GoldIcon", "GoldLabel")
	_gems_label = _create_status_item(hbox, "status_gem", "GemIcon", "GemsLabel")

func _create_status_item(parent: HBoxContainer, icon_id: String, icon_name: String, label_name: String) -> Label:
	var item := HBoxContainer.new()
	item.name = label_name.trim_suffix("Label") + "Status"
	item.alignment = BoxContainer.ALIGNMENT_CENTER
	item.add_theme_constant_override("separation", 1)
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon := CCRVisualStyle.make_status_icon(icon_id, icon_name, _icon_size)
	_status_icons.append(icon)
	item.add_child(icon)
	var label := Label.new()
	label.name = label_name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 18)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item.add_child(label)
	parent.add_child(item)
	return label

func _on_player_data_changed() -> void:
	refresh()

func _on_free_refresh_cooldown_updated(_remaining: float) -> void:
	refresh()

func _on_free_refresh_ready() -> void:
	refresh()

func refresh() -> void:
	var pd = GameManager.player_data
	_stamina_label.text = "%d/%d" % [GameManager.get_stamina_display_current(), GameManager.get_stamina_display_max()]
	_gold_label.text = "%d" % pd.gold
	_gems_label.text = "%d" % pd.gems
