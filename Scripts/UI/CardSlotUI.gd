extends Control
class_name CardSlotUI

signal slot_clicked(index: int)
signal slot_double_clicked(index: int)
signal card_dropped(target_index: int, card: CardInfo, source: String, source_index: int)
signal slot_unlock_requested(index: int)

@export var slot_index: int = 0
@export var show_empty: bool = true
@export var empty_color: Color = Color(0.15, 0.15, 0.2, 1.0)
@export var border_color: Color = Color(0.3, 0.3, 0.4, 1.0)
@export var _unlocked: bool = true

## 该槽位所属区域: "pool" / "hand" / "vault"
var area_type: String = ""
## 是否允许从此槽位拖出卡牌（保险箱设为 false）
var can_drag_from: bool = true
## 是否登记为真实可查找槽位；翻页动画临时槽位不参与拖拽定位
var register_drag_slot: bool = true

var card_display: CardDisplay = null
var is_occupied: bool = false
var _lock_label: Label = null
var _lock_overlay: ColorRect = null
var _glow_effect: ColorRect = null
var _selected_highlight: Panel = null

# ── 拖拽视觉状态 ──
var _drag_out_overlay: ColorRect = null   # 卡牌被拖出时的灰色遮罩
var _drop_highlight: Panel = null         # 拖拽悬停空槽时的外框光圈
var _bg_rect: ColorRect = null            # 背景引用（用于恢复颜色）
var _drop_highlight_active: bool = false
var _slot_hover_active: bool = false
var _return_animation_running: bool = false
var _transfer_animation_running: bool = false
var slot_data_index: int = -1

const DRAG_OUT_COLOR: Color = Color(0.1, 0.1, 0.12, 0.5)
static var SLOT_SIZE: Vector2 = Vector2(107, 149)
const RETURN_ANIMATION_DURATION: float = 0.25

static func configure_slot_size(slot_size: Vector2) -> void:
	SLOT_SIZE = slot_size
	CardDisplay.configure_card_size(slot_size)

func _ready() -> void:
	custom_minimum_size = SLOT_SIZE
	size = SLOT_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(false)
	if register_drag_slot:
		add_to_group("card_slots")
	setup_ui()
	gui_input.connect(_on_gui_input)

	# 监听全局拖拽状态（用于清理视觉状态）
	if DragSystem != null:
		DragSystem.drag_ended.connect(_on_global_drag_ended)
		DragSystem.drag_cancelled.connect(_on_global_drag_cancelled)
		DragSystem.return_to_source_requested.connect(_on_return_to_source_requested)

func setup_ui() -> void:
	_bg_rect = ColorRect.new()
	_bg_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg_rect.color = empty_color
	_bg_rect.name = "Background"
	_bg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg_rect)

	var border = ColorRect.new()
	border.set_anchors_preset(Control.PRESET_TOP_LEFT)
	border.position = Vector2(1, 1)
	border.size = SLOT_SIZE - Vector2(2, 2)
	border.color = border_color
	border.name = "Border"
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(border)

	card_display = CardDisplay.new()
	card_display.set_anchors_preset(Control.PRESET_FULL_RECT)
	card_display.visible = false
	card_display.card_clicked.connect(_on_card_clicked)
	card_display.card_double_clicked.connect(_on_card_double_clicked)
	card_display.card_drag_started.connect(_on_card_drag_started)
	card_display.card_drag_ended.connect(_on_card_drag_ended)
	add_child(card_display)

	# --- 锁定标识 ---
	_lock_overlay = ColorRect.new()
	_lock_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_lock_overlay.color = Color(0, 0, 0, 0.55)
	_lock_overlay.visible = false
	_lock_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_lock_overlay)

	_lock_label = Label.new()
	_lock_label.set_anchors_preset(Control.PRESET_CENTER)
	_lock_label.position = Vector2(0, 0)
	_lock_label.size = Vector2(60, 40)
	_lock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lock_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_lock_label.text = "🔒"
	_lock_label.add_theme_font_size_override("font_size", 24)
	_lock_label.visible = false
	_lock_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_lock_label)

	# --- 拖出遮罩（初始隐藏） ---
	_drag_out_overlay = ColorRect.new()
	_drag_out_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_drag_out_overlay.color = DRAG_OUT_COLOR
	_drag_out_overlay.visible = false
	_drag_out_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_drag_out_overlay)

	# --- 空槽放置光圈（初始隐藏） ---
	_drop_highlight = Panel.new()
	_drop_highlight.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_drop_highlight.position = Vector2(-6, -6)
	_drop_highlight.size = SLOT_SIZE + Vector2(12, 12)
	_drop_highlight.visible = false
	_drop_highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var drop_style = StyleBoxFlat.new()
	drop_style.bg_color = Color(0.2, 0.55, 1.0, 0.10)
	drop_style.border_color = Color(0.45, 0.85, 1.0, 0.95)
	drop_style.set_border_width_all(3)
	drop_style.corner_radius_top_left = 6
	drop_style.corner_radius_top_right = 6
	drop_style.corner_radius_bottom_left = 6
	drop_style.corner_radius_bottom_right = 6
	drop_style.shadow_color = Color(0.2, 0.65, 1.0, 0.65)
	drop_style.shadow_size = 10
	_drop_highlight.add_theme_stylebox_override("panel", drop_style)
	add_child(_drop_highlight)

	# --- 解锁光晕（初始隐藏） ---
	_glow_effect = ColorRect.new()
	_glow_effect.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_glow_effect.position = Vector2(-3, -3)
	_glow_effect.size = SLOT_SIZE + Vector2(6, 6)
	_glow_effect.color = Color(0.3, 0.8, 1.0, 0.4)
	_glow_effect.visible = false
	_glow_effect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_glow_effect)
	# 阴影效果的简化版 — 用带透明度的蓝色边框模拟光晕

	# --- 选中光圈（初始隐藏） ---
	_selected_highlight = Panel.new()
	_selected_highlight.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_selected_highlight.position = Vector2(-7, -7)
	_selected_highlight.size = SLOT_SIZE + Vector2(14, 14)
	_selected_highlight.visible = false
	_selected_highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var selected_style = StyleBoxFlat.new()
	selected_style.bg_color = Color(1.0, 0.78, 0.18, 0.08)
	selected_style.border_color = Color(1.0, 0.82, 0.22, 1.0)
	selected_style.set_border_width_all(4)
	selected_style.corner_radius_top_left = 7
	selected_style.corner_radius_top_right = 7
	selected_style.corner_radius_bottom_left = 7
	selected_style.corner_radius_bottom_right = 7
	selected_style.shadow_color = Color(1.0, 0.74, 0.14, 0.85)
	selected_style.shadow_size = 14
	_selected_highlight.add_theme_stylebox_override("panel", selected_style)
	add_child(_selected_highlight)

	# mouse_entered → 隐藏光晕
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

	# 初始化锁定状态
	_set_lock_visible()

func set_card(card: CardInfo, idx: int = -1) -> void:
	if idx >= 0:
		slot_data_index = idx
	elif slot_data_index < 0:
		slot_data_index = slot_index
	if _glow_effect:
		_glow_effect.visible = false
	if card != null:
		card_display.set_card(card, idx if idx >= 0 else slot_index)
		card_display.visible = not _transfer_animation_running
		card_display.is_draggable = _unlocked and can_drag_from
		card_display.drag_source = area_type
		is_occupied = true
		_hide_drag_out()
		_hide_drop_highlight()
	else:
		clear_slot()

func clear_slot() -> void:
	if _glow_effect:
		_glow_effect.visible = false
	set_selected(false)
	card_display.clear()
	card_display.visible = false
	card_display.is_draggable = false
	card_display.drag_source = ""
	is_occupied = false
	_hide_drag_out()
	_hide_drop_highlight()


func set_slot_data_index(idx: int) -> void:
	slot_data_index = idx

func set_selected(selected: bool) -> void:
	if _selected_highlight:
		_selected_highlight.visible = selected and is_occupied and _unlocked

## 显示解锁光晕（新解锁槽位的视觉提示）
func show_unlock_glow() -> void:
	if _glow_effect:
		_glow_effect.visible = true

## 鼠标进入时隐藏光晕
func _on_mouse_entered() -> void:
	if _glow_effect:
		_glow_effect.visible = false
	set_slot_hovered(true)


func _on_mouse_exited() -> void:
	set_slot_hovered(false)
	if DragSystem != null and DragSystem.is_dragging():
		DragSystem.clear_highlight_target(self)


func _process(_delta: float) -> void:
	var slot_rect := Rect2(global_position, size)
	var mouse_in_slot := slot_rect.has_point(get_global_mouse_position())

	if _slot_hover_active and (DragSystem == null or not DragSystem.is_dragging()) and not mouse_in_slot:
		set_slot_hovered(false)

	if not _drop_highlight_active:
		_update_process_state()
		return
	if DragSystem == null or not DragSystem.is_dragging():
		_hide_drop_highlight()
		return
	if not mouse_in_slot:
		DragSystem.clear_highlight_target(self)


func set_slot_hovered(active: bool) -> void:
	if active and (not is_occupied or card_display == null or not card_display.visible):
		active = false
	_slot_hover_active = active
	if card_display != null:
		card_display.set_slot_hovered(active)
	_update_process_state()


func _update_process_state() -> void:
	set_process(_drop_highlight_active or _slot_hover_active)

func get_card() -> CardInfo:
	return card_display.card

## 设置槽位是否解锁。锁定时显示半透明遮罩 + 🔒 标识
func set_unlocked(val: bool, show_new_unlock_glow: bool = false) -> void:
	var was_locked = not _unlocked
	_unlocked = val
	_set_lock_visible()
	# 同步拖拽状态到 CardDisplay
	if card_display:
		card_display.is_draggable = val and can_drag_from
	# 从锁定变为解锁时，显示光晕
	if was_locked and val and show_new_unlock_glow:
		show_unlock_glow()

func is_unlocked() -> bool:
	return _unlocked

func _set_lock_visible() -> void:
	var locked = not _unlocked
	if _lock_overlay:
		_lock_overlay.visible = locked
	if _lock_label:
		_lock_label.visible = locked
	# 锁定时卡牌不可见
	if locked and card_display:
		card_display.visible = false

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb = event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			if not _unlocked:
				slot_unlock_requested.emit(slot_index)
			else:
				slot_clicked.emit(slot_index)

func _on_card_clicked(card: CardInfo, index: int) -> void:
	slot_clicked.emit(slot_index)

func _on_card_double_clicked(card: CardInfo, index: int) -> void:
	# 向上传播双击信号给父级（CardPoolUI / HandAreaUI）
	slot_double_clicked.emit(slot_index)


# ══════════════════════════════════════════════════
#  拖拽 — 卡牌被从此槽位拖出
# ══════════════════════════════════════════════════

func _on_card_drag_started(_card: CardInfo, _index: int) -> void:
	set_slot_hovered(false)
	_show_drag_out()


func _on_card_drag_ended(_card: CardInfo, _index: int) -> void:
	# 拖拽结束（无论成功或取消）都要隐藏拖出遮罩
	_hide_drag_out()


func _show_drag_out() -> void:
	if card_display:
		card_display.visible = false
	if _drag_out_overlay:
		_drag_out_overlay.visible = false


func _hide_drag_out() -> void:
	if _drag_out_overlay:
		_drag_out_overlay.visible = false
	if _return_animation_running:
		return
	if _transfer_animation_running:
		return
	if card_display != null and is_occupied and _unlocked and card_display.card != null:
		card_display.visible = true


# ══════════════════════════════════════════════════
#  原生拖放 — 接收端（drop target）
# ══════════════════════════════════════════════════

func _can_drop_data(_pos: Vector2, data: Variant) -> bool:
	# 锁定槽位不可接收
	if not _unlocked:
		return false

	# 数据格式检查
	if not (data is Dictionary and data.has("card") and data.has("source")):
		return false

	var src: String = data["source"]
	var dst: String = area_type

	# 验证拖拽路径
	if not _is_valid_drop_path(src, dst):
		return false

	# 高亮当前槽位（并清除其他槽位的高亮）
	DragSystem.set_highlight_target(self)
	_show_drop_highlight()
	return true


func _drop_data(_pos: Vector2, data: Variant) -> void:
	_hide_drop_highlight()

	if not (data is Dictionary and data.has("card")):
		return

	var card: CardInfo = data["card"]
	var src: String = data["source"]
	var src_idx: int = data.get("source_index", -1)

	card_dropped.emit(slot_index, card, src, src_idx)


## 验证拖拽路径是否合法
func _is_valid_drop_path(src: String, dst: String) -> bool:
	# 允许的路径:
	#   pool <-> pool  (同区换位 / 移动)
	#   hand <-> hand  (同区换位 / 移动)
	#   pool <-> hand  (双向)
	#   hand -> vault  (单向)
	# 禁止: vault -> pool, vault -> hand
	match src:
		"pool":
			return dst == "pool" or dst == "hand"
		"hand":
			return dst == "hand" or dst == "pool" or dst == "vault"
		"vault":
			return false  # 保险箱只能通过按钮操作取出
	return false


# ══════════════════════════════════════════════════
#  拖拽视觉状态
# ══════════════════════════════════════════════════

func _show_drop_highlight() -> void:
	_drop_highlight_active = true
	_update_process_state()
	if is_occupied and card_display != null and card_display.visible:
		card_display.set_drop_targeted(true)
	elif _drop_highlight:
		_drop_highlight.visible = true


func _hide_drop_highlight() -> void:
	_drop_highlight_active = false
	_update_process_state()
	if _drop_highlight:
		_drop_highlight.visible = false
	if card_display != null:
		card_display.set_drop_targeted(false)


func clear_drop_highlight() -> void:
	_hide_drop_highlight()


# ══════════════════════════════════════════════════
#  全局拖拽结束/取消 → 清理所有视觉状态
# ══════════════════════════════════════════════════

func _on_global_drag_ended(_card: CardInfo, _from: String, _to: String) -> void:
	_hide_drag_out()
	_hide_drop_highlight()


func _on_global_drag_cancelled() -> void:
	_hide_drag_out()
	_hide_drop_highlight()


func _on_return_to_source_requested(card: CardInfo, source: String, source_index: int, start_global_position: Vector2) -> void:
	if not _is_return_animation_source(card, source, source_index):
		return
	_play_return_animation(card, source_index, start_global_position)


func _is_return_animation_source(card: CardInfo, source: String, source_index: int) -> bool:
	if source != area_type:
		return false
	if card == null or card_display == null or card_display.card == null:
		return false
	if card_display.card.get_uid() != card.get_uid():
		return false
	if source_index >= 0:
		return card_display.card_index == source_index or slot_index == source_index
	return true


func _play_return_animation(card: CardInfo, source_index: int, start_global_position: Vector2) -> void:
	if get_tree() == null:
		return

	var anim_card = CardDisplay.new()
	anim_card.custom_minimum_size = SLOT_SIZE
	anim_card.size = SLOT_SIZE
	anim_card.z_index = 1000
	anim_card.modulate = Color(1, 1, 1, 1)
	anim_card.hover_uses_slot_bounds = true
	get_tree().root.add_child(anim_card)
	anim_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	anim_card.global_position = start_global_position
	anim_card.set_card(card, source_index)
	_return_animation_running = true
	if card_display != null:
		card_display.visible = false

	var tween := anim_card.create_tween()
	tween.tween_property(anim_card, "global_position", global_position, RETURN_ANIMATION_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.finished.connect(func():
		anim_card.queue_free()
		_return_animation_running = false
		if card_display != null and is_occupied and _unlocked and card_display.card != null:
			card_display.visible = true
	)


func hide_for_transfer(duration: float) -> void:
	_transfer_animation_running = true
	if card_display != null:
		card_display.visible = false
	var timer := get_tree().create_timer(duration)
	timer.timeout.connect(func():
		_transfer_animation_running = false
		if not _return_animation_running and card_display != null and is_occupied and _unlocked and card_display.card != null:
			card_display.visible = true
	)
