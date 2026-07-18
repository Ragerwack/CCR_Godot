extends Control
class_name CurrencyUI

const CCRVisualStyle = preload("res://Scripts/UI/CCRVisualStyle.gd")
const AssetNumberRollScript = preload("res://Scripts/UI/AssetNumberRoll.gd")
const ROW_HORIZONTAL_SAFE_MARGIN: float = 6.0

var _gold_number
var _gems_number
var _stamina_number
var _status_icons: Array[TextureRect] = []
var _icon_size: float = 22.0
var _status_row: HBoxContainer
var _base_row_width: float = 0.0
var _layout_fit_queued: bool = false

func configure_icon_size(icon_size: float) -> void:
	_icon_size = maxf(1.0, icon_size)
	for icon in _status_icons:
		icon.custom_minimum_size = Vector2(_icon_size, _icon_size)
		icon.size = Vector2(_icon_size, _icon_size)
	_fit_status_row_width()

# 保持右边界不动；资源数字变长时，图标和数字作为同一项向左扩展。
func configure_layout(base_row_width: float) -> void:
	_base_row_width = maxf(0.0, base_row_width)
	_fit_status_row_width()

func get_required_row_height() -> float:
	if _status_row == null:
		return _icon_size
	return maxf(_icon_size, _status_row.get_combined_minimum_size().y)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	setup_ui()
	GameManager.player_data.changed.connect(_on_player_data_changed)
	GameManager.free_refresh_cooldown_updated.connect(_on_free_refresh_cooldown_updated)
	GameManager.free_refresh_ready.connect(_on_free_refresh_ready)
	refresh()

func setup_ui() -> void:
	# 水平并排：体力 → 金币 → 宝石
	_status_row = HBoxContainer.new()
	_status_row.name = "CurrencyStatusRow"
	_status_row.set_anchors_preset(Control.PRESET_FULL_RECT)
	_status_row.alignment = BoxContainer.ALIGNMENT_END
	_status_row.add_theme_constant_override("separation", 6)
	_status_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_status_row)
	_status_row.offset_left = ROW_HORIZONTAL_SAFE_MARGIN
	_status_row.offset_right = -ROW_HORIZONTAL_SAFE_MARGIN
	_status_row.minimum_size_changed.connect(_queue_fit_status_row_width)

	_stamina_number = _create_status_item(_status_row, "status_stamina", "StaminaIcon", "StaminaLabel")
	_gold_number = _create_status_item(_status_row, "status_gold", "GoldIcon", "GoldLabel")
	_gems_number = _create_status_item(_status_row, "status_gem", "GemIcon", "GemsLabel")

func _create_status_item(parent: HBoxContainer, icon_id: String, icon_name: String, label_name: String) -> Control:
	var item := HBoxContainer.new()
	item.name = label_name.trim_suffix("Label") + "Status"
	item.alignment = BoxContainer.ALIGNMENT_CENTER
	item.add_theme_constant_override("separation", 1)
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon := CCRVisualStyle.make_status_icon(icon_id, icon_name, _icon_size)
	_status_icons.append(icon)
	item.add_child(icon)
	var number := AssetNumberRollScript.new()
	number.name = label_name.trim_suffix("Label") + "NumberRoll"
	number.configure(label_name, 18)
	item.add_child(number)
	parent.add_child(item)
	return number

func _on_player_data_changed() -> void:
	refresh()

func _on_free_refresh_cooldown_updated(_remaining: float) -> void:
	refresh()

func _on_free_refresh_ready() -> void:
	refresh()

func refresh() -> void:
	var pd = GameManager.player_data
	var stamina_current := GameManager.get_stamina_display_current()
	var stamina_max := GameManager.get_stamina_display_max()
	_stamina_number.set_display("%d/%d" % [stamina_current, stamina_max], stamina_current, stamina_max)
	_gold_number.set_display("%d" % pd.gold, int(pd.gold))
	_gems_number.set_display("%d" % pd.gems, int(pd.gems))
	_fit_status_row_width()

func get_resource_icon_global_rect(resource_type: String) -> Rect2:
	var node_name := "GemIcon"
	match resource_type:
		"stamina":
			node_name = "StaminaIcon"
		"gold":
			node_name = "GoldIcon"
		"gems", "gem":
			node_name = "GemIcon"
	var icon := find_child(node_name, true, false) as TextureRect
	if icon == null or not icon.is_inside_tree():
		return Rect2()
	return icon.get_global_rect()

func _fit_status_row_width() -> void:
	_layout_fit_queued = false
	if _status_row == null:
		return
	# Container 的最小宽度会随数字增长；右侧 offset 不变，因此新增宽度只向左扩展。
	# 两侧安全边距用于容纳字体抗锯齿边缘，避免逻辑尺寸刚好但末位像素仍被裁切。
	var content_width := ceilf(_status_row.get_combined_minimum_size().x + ROW_HORIZONTAL_SAFE_MARGIN * 2.0)
	var target_width := maxf(_base_row_width, content_width)
	if target_width <= 0.0:
		return
	custom_minimum_size.x = target_width
	offset_left = offset_right - target_width

func _queue_fit_status_row_width() -> void:
	if _layout_fit_queued:
		return
	_layout_fit_queued = true
	call_deferred("_fit_status_row_width")
