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

var card_display: CardDisplay = null
var is_occupied: bool = false
var _lock_label: Label = null
var _lock_overlay: ColorRect = null
var _glow_effect: ColorRect = null

# ── 拖拽视觉状态 ──
var _drag_out_overlay: ColorRect = null   # 卡牌被拖出时的灰色遮罩
var _drop_highlight: ColorRect = null     # 拖拽悬停时的高亮边框
var _bg_rect: ColorRect = null            # 背景引用（用于恢复颜色）

const DRAG_OUT_COLOR: Color = Color(0.1, 0.1, 0.12, 0.5)
const DROP_HIGHLIGHT_COLOR: Color = Color(0.2, 0.8, 0.3, 0.35)

func _ready() -> void:
	custom_minimum_size = Vector2(97, 135)   # 88×123 再增大 10% → 97×135
	setup_ui()
	gui_input.connect(_on_gui_input)

	# 监听全局拖拽状态（用于清理视觉状态）
	if DragSystem != null:
		DragSystem.drag_ended.connect(_on_global_drag_ended)
		DragSystem.drag_cancelled.connect(_on_global_drag_cancelled)

func setup_ui() -> void:
	_bg_rect = ColorRect.new()
	_bg_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg_rect.color = empty_color
	_bg_rect.name = "Background"
	add_child(_bg_rect)

	var border = ColorRect.new()
	border.set_anchors_preset(Control.PRESET_FULL_RECT)
	border.position = Vector2(1, 1)
	border.size = size - Vector2(2, 2)
	border.color = border_color
	border.name = "Border"
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
	add_child(_lock_label)

	# --- 拖出遮罩（初始隐藏） ---
	_drag_out_overlay = ColorRect.new()
	_drag_out_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_drag_out_overlay.color = DRAG_OUT_COLOR
	_drag_out_overlay.visible = false
	_drag_out_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_drag_out_overlay)

	# --- 放置高亮边框（初始隐藏） ---
	_drop_highlight = ColorRect.new()
	_drop_highlight.set_anchors_preset(Control.PRESET_FULL_RECT)
	_drop_highlight.color = DROP_HIGHLIGHT_COLOR
	_drop_highlight.visible = false
	_drop_highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_drop_highlight)

	# --- 解锁光晕（初始隐藏） ---
	_glow_effect = ColorRect.new()
	_glow_effect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_glow_effect.position = Vector2(-3, -3)
	_glow_effect.size = size + Vector2(6, 6)
	_glow_effect.color = Color(0.3, 0.8, 1.0, 0.4)
	_glow_effect.visible = false
	_glow_effect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_glow_effect)
	# 阴影效果的简化版 — 用带透明度的蓝色边框模拟光晕

	# mouse_entered → 隐藏光晕
	mouse_entered.connect(_on_mouse_entered)

	# 初始化锁定状态
	_set_lock_visible()

func set_card(card: CardInfo, idx: int = -1) -> void:
	if card != null:
		card_display.set_card(card, idx if idx >= 0 else slot_index)
		card_display.visible = true
		card_display.is_draggable = _unlocked and can_drag_from
		card_display.drag_source = area_type
		is_occupied = true
		_hide_drag_out()
	else:
		clear_slot()

func clear_slot() -> void:
	card_display.clear()
	card_display.visible = false
	card_display.is_draggable = false
	card_display.drag_source = ""
	is_occupied = false
	_hide_drag_out()
	_hide_drop_highlight()

## 显示解锁光晕（新解锁槽位的视觉提示）
func show_unlock_glow() -> void:
	if _glow_effect:
		_glow_effect.visible = true

## 鼠标进入时隐藏光晕
func _on_mouse_entered() -> void:
	if _glow_effect:
		_glow_effect.visible = false

func get_card() -> CardInfo:
	return card_display.card

## 设置槽位是否解锁。锁定时显示半透明遮罩 + 🔒 标识
func set_unlocked(val: bool) -> void:
	var was_locked = not _unlocked
	_unlocked = val
	_set_lock_visible()
	# 同步拖拽状态到 CardDisplay
	if card_display:
		card_display.is_draggable = val
	# 从锁定变为解锁时，显示光晕
	if was_locked and val:
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
	_show_drag_out()


func _on_card_drag_ended(_card: CardInfo, _index: int) -> void:
	# 拖拽结束（无论成功或取消）都要隐藏拖出遮罩
	_hide_drag_out()


func _show_drag_out() -> void:
	if _drag_out_overlay:
		_drag_out_overlay.visible = true


func _hide_drag_out() -> void:
	if _drag_out_overlay:
		_drag_out_overlay.visible = false


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
	# 不允许同区域拖拽
	if src == dst:
		return false
	# 允许的路径:
	#   pool <-> hand  (双向)
	#   hand -> vault  (单向)
	# 禁止: vault -> pool, vault -> hand
	match src:
		"pool":
			return dst == "hand"
		"hand":
			return dst == "pool" or dst == "vault"
		"vault":
			return false  # 保险箱只能通过按钮操作取出
	return false


# ══════════════════════════════════════════════════
#  拖拽视觉状态
# ══════════════════════════════════════════════════

func _show_drop_highlight() -> void:
	if _drop_highlight:
		_drop_highlight.visible = true


func _hide_drop_highlight() -> void:
	if _drop_highlight:
		_drop_highlight.visible = false


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
