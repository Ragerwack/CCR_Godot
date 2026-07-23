extends Control
class_name CardSlotUI

const CCRVisualStyle = preload("res://Scripts/UI/CCRVisualStyle.gd")
const BlackCardDrawOverlayScript = preload("res://Scripts/UI/BlackCardDrawOverlay.gd")
const OrangeCardDrawOverlayScript = preload("res://Scripts/UI/OrangeCardDrawOverlay.gd")
const PurpleCardDrawOverlayScript = preload("res://Scripts/UI/PurpleCardDrawOverlay.gd")

signal slot_clicked(index: int)
signal slot_double_clicked(index: int)
signal card_dropped(target_index: int, card: CardInfo, source: String, source_index: int)
signal slot_unlock_requested(index: int)

@export var slot_index: int = 0
@export var show_empty: bool = true
@export var empty_color: Color = Color(0.15, 0.15, 0.2, 0.28)
@export var border_color: Color = Color(0.3, 0.3, 0.4, 0.22)
@export var _unlocked: bool = true

## 该槽位所属区域: "pool" / "hand" / "vault"
var area_type: String = ""
## 是否允许从此槽位拖出卡牌
var can_drag_from: bool = true
## 是否登记为真实可查找槽位；翻页动画临时槽位不参与拖拽定位
var register_drag_slot: bool = true

var card_display: CardDisplay = null
var is_occupied: bool = false
var _lock_icon: TextureRect = null
var _lock_overlay: ColorRect = null
var _glow_effect: ColorRect = null
var _selected_highlight: Panel = null
var _focus_highlight: Panel = null
var _slot_shadow: Panel = null
var _slot_inner_shadow: Control = null

# ── 拖拽视觉状态 ──
var _drag_out_overlay: ColorRect = null   # 卡牌被拖出时的灰色遮罩
var _drop_highlight: Panel = null         # 拖拽悬停空槽时的外框光圈
var _bg_rect: ColorRect = null            # 背景引用（用于恢复颜色）
var _drop_highlight_active: bool = false
var _slot_hover_active: bool = false
var _return_animation_running: bool = false
var _transfer_animation_running: bool = false
var slot_data_index: int = -1
var _hover_preview: CardDisplay = null
var last_click_button_index: int = MOUSE_BUTTON_LEFT

const DRAG_OUT_COLOR: Color = Color(0.1, 0.1, 0.12, 0.32)
const SLOT_SHADOW_COLOR: Color = Color(0, 0, 0, 0.16)
const LOCK_OVERLAY_COLOR: Color = Color(0, 0, 0, 0.38)
const LOCK_ICON_ID := "status_lock"
static var SLOT_SIZE: Vector2 = Vector2(107, 149)
const RETURN_ANIMATION_DURATION: float = 0.25
const DROP_IN_HEIGHT: float = 72.0
const DROP_IN_DURATION: float = 0.20
const DROP_IN_BOUNCE_DURATION: float = 0.11
const DROP_IN_FLASH_DURATION: float = 0.16
const DROP_IN_START_SCALE: Vector2 = Vector2(1.08, 1.08)
const DROP_IN_IMPACT_SCALE: Vector2 = Vector2(1.04, 0.96)
const DROP_IN_BOUNCE_SCALE: Vector2 = Vector2(0.985, 1.025)
const DROP_IN_START_ROTATION: float = -2.0
const DROP_IN_IMPACT_ROTATION: float = 0.8
const DROP_IN_BOUNCE_Y: float = -4.0
const DRAW_DROP_TOTAL_DURATION: float = DROP_IN_DURATION + DROP_IN_BOUNCE_DURATION
## 基础落卡完成还包括落地后确认闪光，下一张卡必须等它消失。
const DRAW_DROP_COMPLETE_DURATION: float = DRAW_DROP_TOTAL_DURATION + DROP_IN_FLASH_DURATION
const GREEN_RARITY_SHINE_DURATION: float = CardDisplay.GREEN_DRAW_SHINE_DURATION
const BLUE_DRAW_FLIP_DURATION: float = CardDisplay.BLUE_DRAW_FLIP_DURATION
const BLUE_RARITY_SHINE_DURATION: float = CardDisplay.BLUE_DRAW_SHINE_DURATION
const PURPLE_DRAW_PRESENTATION_DURATION: float = PurpleCardDrawOverlayScript.TOTAL_DURATION
const ORANGE_DRAW_PRESENTATION_DURATION: float = OrangeCardDrawOverlayScript.TOTAL_DURATION
const BLACK_DRAW_PRESENTATION_DURATION: float = BlackCardDrawOverlayScript.TOTAL_DURATION

var _drop_in_tween: Tween = null
var _drop_in_glow_tween: Tween = null
var _purple_draw_overlay: Control = null
var _orange_draw_overlay: Control = null
var _black_draw_overlay: BlackCardDrawOverlay = null

static func configure_slot_size(slot_size: Vector2) -> void:
	SLOT_SIZE = slot_size
	CardDisplay.configure_card_size(slot_size)

func _ready() -> void:
	custom_minimum_size = SLOT_SIZE
	size = SLOT_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	set_process(false)
	if register_drag_slot:
		add_to_group("card_slots")
		add_to_group("controller_focusable")
	setup_ui()
	gui_input.connect(_on_gui_input)
	focus_entered.connect(_on_focus_entered)
	focus_exited.connect(_on_focus_exited)

	# 监听全局拖拽状态（用于清理视觉状态）
	if DragSystem != null:
		DragSystem.drag_ended.connect(_on_global_drag_ended)
		DragSystem.drag_cancelled.connect(_on_global_drag_cancelled)
		DragSystem.return_to_source_requested.connect(_on_return_to_source_requested)

func setup_ui() -> void:
	_slot_shadow = CCRVisualStyle.make_shadow_panel("SlotShadow", int(roundf(SLOT_SIZE.x * 0.08)), 12, Vector2(4, 7), SLOT_SHADOW_COLOR)
	_slot_shadow.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_slot_shadow.position = Vector2.ZERO
	_slot_shadow.size = SLOT_SIZE
	add_child(_slot_shadow)

	_bg_rect = ColorRect.new()
	_bg_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg_rect.color = empty_color
	_bg_rect.material = CardDisplay._new_rounded_mask_material(SLOT_SIZE)
	_bg_rect.name = "Background"
	_bg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg_rect)

	var border = ColorRect.new()
	border.set_anchors_preset(Control.PRESET_TOP_LEFT)
	border.position = Vector2(1, 1)
	border.size = SLOT_SIZE - Vector2(2, 2)
	border.color = border_color
	border.material = CardDisplay._new_rounded_mask_material(SLOT_SIZE)
	border.name = "Border"
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(border)

	_slot_inner_shadow = _make_slot_inner_shadow()
	add_child(_slot_inner_shadow)

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
	_lock_overlay.name = "LockOverlay"
	_lock_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_lock_overlay.color = LOCK_OVERLAY_COLOR
	_lock_overlay.material = CardDisplay._new_rounded_mask_material(SLOT_SIZE)
	_lock_overlay.visible = false
	_lock_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_lock_overlay)

	var lock_icon_size := clampf(SLOT_SIZE.x * 0.45, 39.0, 63.0)
	_lock_icon = CCRVisualStyle.make_status_icon(LOCK_ICON_ID, "LockedSlotIcon", lock_icon_size)
	_lock_icon.position = (SLOT_SIZE - Vector2(lock_icon_size, lock_icon_size)) * 0.5
	_lock_icon.size = Vector2(lock_icon_size, lock_icon_size)
	_lock_icon.visible = false
	add_child(_lock_icon)

	# --- 拖出遮罩（初始隐藏） ---
	_drag_out_overlay = ColorRect.new()
	_drag_out_overlay.name = "DragOutOverlay"
	_drag_out_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_drag_out_overlay.color = DRAG_OUT_COLOR
	_drag_out_overlay.material = CardDisplay._new_rounded_mask_material(SLOT_SIZE)
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
	_selected_highlight.name = "SelectedHighlight"
	_selected_highlight.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_selected_highlight.position = Vector2(-7, -7)
	_selected_highlight.size = SLOT_SIZE + Vector2(14, 14)
	_selected_highlight.visible = false
	_selected_highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var selected_style = StyleBoxFlat.new()
	selected_style.bg_color = Color(1.0, 0.78, 0.18, 0.0)
	selected_style.border_color = Color(1.0, 0.82, 0.22, 1.0)
	selected_style.set_border_width_all(3)
	selected_style.corner_radius_top_left = 7
	selected_style.corner_radius_top_right = 7
	selected_style.corner_radius_bottom_left = 7
	selected_style.corner_radius_bottom_right = 7
	selected_style.shadow_color = Color(1.0, 0.74, 0.14, 0.85)
	selected_style.shadow_size = 14
	_selected_highlight.add_theme_stylebox_override("panel", selected_style)
	add_child(_selected_highlight)
	move_child(_selected_highlight, card_display.get_index())

	_focus_highlight = Panel.new()
	_focus_highlight.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_focus_highlight.position = Vector2(-10, -10)
	_focus_highlight.size = SLOT_SIZE + Vector2(20, 20)
	_focus_highlight.visible = false
	_focus_highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var focus_style = StyleBoxFlat.new()
	focus_style.bg_color = Color(0.35, 0.78, 1.0, 0.04)
	focus_style.border_color = Color(0.5, 0.88, 1.0, 0.95)
	focus_style.set_border_width_all(2)
	focus_style.corner_radius_top_left = 9
	focus_style.corner_radius_top_right = 9
	focus_style.corner_radius_bottom_left = 9
	focus_style.corner_radius_bottom_right = 9
	focus_style.shadow_color = Color(0.35, 0.75, 1.0, 0.55)
	focus_style.shadow_size = 10
	_focus_highlight.add_theme_stylebox_override("panel", focus_style)
	add_child(_focus_highlight)

	# mouse_entered → 隐藏光晕
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

	# 初始化锁定状态
	_set_lock_visible()

func _exit_tree() -> void:
	_cancel_purple_draw_overlay()
	_cancel_orange_draw_overlay()
	_cancel_black_draw_overlay()
	_hide_hover_preview()

func _make_slot_inner_shadow() -> Control:
	var root := Control.new()
	root.name = "SlotInsetShadow"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var top_shadow := ColorRect.new()
	top_shadow.name = "TopInsetShadow"
	top_shadow.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_shadow.offset_left = 3
	top_shadow.offset_top = 3
	top_shadow.offset_right = -3
	top_shadow.offset_bottom = 8
	top_shadow.color = Color(0, 0, 0, 0.20)
	top_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top_shadow)

	var left_shadow := ColorRect.new()
	left_shadow.name = "LeftInsetShadow"
	left_shadow.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	left_shadow.offset_left = 3
	left_shadow.offset_top = 3
	left_shadow.offset_right = 8
	left_shadow.offset_bottom = -3
	left_shadow.color = Color(0, 0, 0, 0.14)
	left_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(left_shadow)

	var bottom_highlight := ColorRect.new()
	bottom_highlight.name = "BottomInsetHighlight"
	bottom_highlight.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_highlight.offset_left = 4
	bottom_highlight.offset_top = -6
	bottom_highlight.offset_right = -4
	bottom_highlight.offset_bottom = -3
	bottom_highlight.color = Color(1, 1, 1, 0.08)
	bottom_highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bottom_highlight)

	var right_highlight := ColorRect.new()
	right_highlight.name = "RightInsetHighlight"
	right_highlight.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	right_highlight.offset_left = -6
	right_highlight.offset_top = 4
	right_highlight.offset_right = -3
	right_highlight.offset_bottom = -4
	right_highlight.color = Color(1, 1, 1, 0.06)
	right_highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(right_highlight)

	return root

func is_controller_focusable() -> bool:
	return _unlocked and (is_occupied or show_empty)

func controller_activate() -> void:
	if not _unlocked:
		slot_unlock_requested.emit(slot_index)
	else:
		slot_clicked.emit(slot_index)

func set_card(card: CardInfo, idx: int = -1) -> void:
	if idx >= 0:
		slot_data_index = idx
	elif slot_data_index < 0:
		slot_data_index = slot_index
	if _glow_effect:
		_glow_effect.visible = false
	if card != null:
		card_display.set_card(card, idx if idx >= 0 else slot_index)
		card_display.refresh_title_text_color()
		card_display.visible = not _transfer_animation_running
		card_display.is_draggable = _unlocked and can_drag_from
		card_display.drag_source = area_type
		is_occupied = true
		_hide_drag_out()
		_hide_drop_highlight()
	else:
		clear_slot()

func clear_slot() -> void:
	_stop_drop_in_animation()
	_hide_hover_preview()
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
	if card_display != null:
		card_display.refresh_title_text_color()

func refresh_card_title_text_color() -> void:
	if card_display != null:
		card_display.refresh_title_text_color()

## 显示解锁光晕（新解锁槽位的视觉提示）
func show_unlock_glow() -> void:
	if _glow_effect:
		_glow_effect.visible = true

## 抽卡刷新时播放“从上方入槽”的 UI 动画。
func play_draw_drop_in(delay: float = 0.0) -> void:
	if card_display == null or card_display.card == null or not _unlocked:
		return
	if get_tree() == null:
		return
	_stop_drop_in_animation()
	set_slot_hovered(false)
	if card_display.card.color == CardColor.ColorType.PURPLE:
		_play_purple_draw_presentation(delay)
		return
	if card_display.card.color == CardColor.ColorType.ORANGE:
		_play_orange_draw_presentation(delay)
		return
	if card_display.card.color == CardColor.ColorType.BLACK:
		_play_black_draw_presentation(delay)
		return
	card_display.visible = true
	card_display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_display.pivot_offset = card_display.size * 0.5
	card_display.position = Vector2(0.0, -DROP_IN_HEIGHT)
	var is_blue_draw := card_display.card.color == CardColor.ColorType.BLUE
	card_display.scale = Vector2.ONE if is_blue_draw else DROP_IN_START_SCALE
	card_display.rotation_degrees = 0.0 if is_blue_draw else DROP_IN_START_ROTATION
	card_display.modulate = Color(1, 1, 1, 0)
	card_display.z_index = 80

	_drop_in_tween = create_tween()
	if delay > 0.0:
		_drop_in_tween.tween_interval(delay)
	if is_blue_draw:
		_drop_in_tween.set_parallel(true)
		_drop_in_tween.tween_property(card_display, "modulate:a", 1.0, 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_drop_in_tween.tween_callback(card_display.begin_blue_draw_flip)
		_drop_in_tween.tween_method(card_display.set_blue_draw_flip_progress, 0.0, 1.0, BLUE_DRAW_FLIP_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_drop_in_tween.set_parallel(false)
		_drop_in_tween.tween_callback(card_display.finish_blue_draw_flip)
	_drop_in_tween.set_parallel(true)
	if not is_blue_draw:
		_drop_in_tween.tween_property(card_display, "modulate:a", 1.0, 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_drop_in_tween.tween_property(card_display, "position", Vector2.ZERO, DROP_IN_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_drop_in_tween.tween_property(card_display, "scale", DROP_IN_IMPACT_SCALE, DROP_IN_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_drop_in_tween.tween_property(card_display, "rotation_degrees", DROP_IN_IMPACT_ROTATION, DROP_IN_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_drop_in_tween.set_parallel(false)
	_drop_in_tween.tween_property(card_display, "position", Vector2(0.0, DROP_IN_BOUNCE_Y), DROP_IN_BOUNCE_DURATION * 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_drop_in_tween.parallel().tween_property(card_display, "scale", DROP_IN_BOUNCE_SCALE, DROP_IN_BOUNCE_DURATION * 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_drop_in_tween.parallel().tween_property(card_display, "rotation_degrees", 0.0, DROP_IN_BOUNCE_DURATION * 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_drop_in_tween.tween_property(card_display, "position", Vector2.ZERO, DROP_IN_BOUNCE_DURATION * 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_drop_in_tween.parallel().tween_property(card_display, "scale", Vector2.ONE, DROP_IN_BOUNCE_DURATION * 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_drop_in_tween.finished.connect(func():
		_finish_drop_in_animation()
		_play_draw_confirm_flash()
		_play_draw_rarity_effect()
	)


func _play_draw_sfx(color_type: int) -> void:
	var event_name := "draw_white"
	match color_type:
		CardColor.ColorType.GREEN:
			event_name = "draw_green"
		CardColor.ColorType.BLUE:
			event_name = "draw_blue"
		CardColor.ColorType.PURPLE:
			event_name = "draw_purple"
		CardColor.ColorType.ORANGE:
			event_name = "draw_orange"
		CardColor.ColorType.BLACK:
			event_name = "draw_black"
	AudioManager.play_sfx(event_name)


func _stop_drop_in_animation() -> void:
	_cancel_purple_draw_overlay()
	_cancel_orange_draw_overlay()
	_cancel_black_draw_overlay()
	if _drop_in_tween != null and _drop_in_tween.is_valid():
		_drop_in_tween.kill()
	_drop_in_tween = null
	if _drop_in_glow_tween != null and _drop_in_glow_tween.is_valid():
		_drop_in_glow_tween.kill()
	_drop_in_glow_tween = null
	if card_display != null:
		card_display.stop_draw_rarity_effect()
		card_display.stop_blue_draw_flip()
		card_display.position = Vector2.ZERO
		card_display.scale = Vector2.ONE
		card_display.rotation_degrees = 0.0
		card_display.modulate = Color(1, 1, 1, 1)
		card_display.z_index = 0
		card_display.mouse_filter = Control.MOUSE_FILTER_STOP
		card_display.refresh_title_text_color()


func _play_purple_draw_presentation(delay: float) -> void:
	card_display.visible = false
	card_display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_purple_draw_overlay = PurpleCardDrawOverlayScript.new()
	_purple_draw_overlay.name = "PurpleCardDrawOverlay"
	_purple_draw_overlay.setup(card_display.card, Rect2(global_position, size))
	_purple_draw_overlay.presentation_finished.connect(_on_purple_draw_presentation_finished)
	get_tree().root.add_child(_purple_draw_overlay)
	_purple_draw_overlay.play(delay)


func _on_purple_draw_presentation_finished() -> void:
	_purple_draw_overlay = null
	_finish_drop_in_animation()


func _cancel_purple_draw_overlay() -> void:
	if is_instance_valid(_purple_draw_overlay):
		var overlay := _purple_draw_overlay
		_purple_draw_overlay = null
		overlay.cancel()


func _play_black_draw_presentation(delay: float) -> void:
	card_display.visible = false
	card_display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_black_draw_overlay = BlackCardDrawOverlayScript.new()
	_black_draw_overlay.name = "BlackCardDrawOverlay"
	_black_draw_overlay.setup(card_display.card, Rect2(global_position, size))
	_black_draw_overlay.presentation_finished.connect(_on_black_draw_presentation_finished)
	get_tree().root.add_child(_black_draw_overlay)
	_black_draw_overlay.play(delay)


func _play_orange_draw_presentation(delay: float) -> void:
	card_display.visible = false
	card_display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_orange_draw_overlay = OrangeCardDrawOverlayScript.new()
	_orange_draw_overlay.name = "OrangeCardDrawOverlay"
	_orange_draw_overlay.setup(card_display.card, Rect2(global_position, size))
	_orange_draw_overlay.presentation_finished.connect(_on_orange_draw_presentation_finished)
	get_tree().root.add_child(_orange_draw_overlay)
	_orange_draw_overlay.play(delay)


func _on_orange_draw_presentation_finished() -> void:
	_orange_draw_overlay = null
	_finish_drop_in_animation()


func _cancel_orange_draw_overlay() -> void:
	if is_instance_valid(_orange_draw_overlay):
		var overlay: Control = _orange_draw_overlay
		_orange_draw_overlay = null
		overlay.call("cancel")


func _on_black_draw_presentation_finished() -> void:
	_black_draw_overlay = null
	_finish_drop_in_animation()


func _cancel_black_draw_overlay() -> void:
	if is_instance_valid(_black_draw_overlay):
		var overlay := _black_draw_overlay
		_black_draw_overlay = null
		overlay.cancel()


func _finish_drop_in_animation() -> void:
	if card_display == null:
		return
	card_display.visible = true
	card_display.position = Vector2.ZERO
	card_display.scale = Vector2.ONE
	card_display.rotation_degrees = 0.0
	card_display.modulate = Color(1, 1, 1, 1)
	card_display.z_index = 0
	card_display.mouse_filter = Control.MOUSE_FILTER_STOP
	card_display.refresh_title_text_color()
	if card_display.card != null:
		if card_display.card.color == CardColor.ColorType.BLUE:
			_play_draw_sfx(CardColor.ColorType.WHITE)
		else:
			_play_draw_sfx(card_display.card.color)


func _play_draw_confirm_flash() -> void:
	if _glow_effect == null:
		return
	_glow_effect.visible = true
	_glow_effect.color = Color(0.55, 0.85, 1.0, 0.0)
	_drop_in_glow_tween = create_tween()
	_drop_in_glow_tween.tween_property(_glow_effect, "color:a", 0.35, DROP_IN_FLASH_DURATION * 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_drop_in_glow_tween.tween_property(_glow_effect, "color:a", 0.0, DROP_IN_FLASH_DURATION * 0.65).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_drop_in_glow_tween.finished.connect(func():
		if _glow_effect != null:
			_glow_effect.visible = false
	)


func _play_draw_rarity_effect() -> void:
	if card_display == null or card_display.card == null:
		return
	if card_display.card.color == CardColor.ColorType.GREEN:
		card_display.play_green_draw_shine(GREEN_RARITY_SHINE_DURATION)
	elif card_display.card.color == CardColor.ColorType.BLUE:
		card_display.play_blue_draw_shine(BLUE_RARITY_SHINE_DURATION)

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
	if active:
		_show_hover_preview()
	else:
		_hide_hover_preview()
	_update_process_state()

func _show_hover_preview() -> void:
	if not ["pool", "hand", "vault"].has(area_type):
		return
	if card_display == null or card_display.card == null:
		return
	if DragSystem != null and DragSystem.is_dragging():
		return
	if get_tree() == null:
		return
	_hide_hover_preview()

	var viewport_size := get_viewport_rect().size
	var preview_height := viewport_size.y * 0.5
	var preview_width := preview_height * (SLOT_SIZE.x / SLOT_SIZE.y)
	var preview_center := _hover_preview_center(viewport_size, Vector2(preview_width, preview_height))
	var preview_x := clampf(preview_center.x - preview_width * 0.5, 0.0, maxf(0.0, viewport_size.x - preview_width))
	var preview_y := clampf(preview_center.y - preview_height * 0.5, 0.0, maxf(0.0, viewport_size.y - preview_height))

	_hover_preview = CardDisplay.new()
	_hover_preview.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_hover_preview.position = Vector2(preview_x, preview_y)
	_hover_preview.size = Vector2(preview_width, preview_height)
	_hover_preview.custom_minimum_size = _hover_preview.size
	_hover_preview.z_index = 4090
	_hover_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_tree().root.add_child(_hover_preview)
	_hover_preview.set_card(card_display.card, slot_data_index)
	_hover_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	AudioManager.play_sfx("card_preview", 1.0, 0.0)

func _hover_preview_center(viewport_size: Vector2, preview_size: Vector2) -> Vector2:
	if area_type == "pool" or area_type == "hand":
		var is_left_group := slot_index % 8 < 4
		var target_rect := _visible_area_side_rect(["pool", "hand"], not is_left_group)
		if target_rect.size.x > 0.0 and target_rect.size.y > 0.0:
			return target_rect.get_center()

	if area_type == "vault":
		var is_left_group := slot_index % 8 < 4
		var target_rect := _visible_area_side_rect(["vault"], not is_left_group)
		if target_rect.size.x > 0.0 and target_rect.size.y > 0.0:
			return target_rect.get_center()

	var mid_x := viewport_size.x * 0.5
	if global_position.x < mid_x:
		return Vector2(mid_x + mid_x * 0.5, viewport_size.y * 0.5)
	return Vector2(mid_x * 0.5, viewport_size.y * 0.5)

func _visible_area_side_rect(area_types: Array, left_group: bool) -> Rect2:
	var found := false
	var union_rect := Rect2()
	for node in get_tree().get_nodes_in_group("card_slots"):
		var slot := node as CardSlotUI
		if slot == null or slot == self:
			continue
		if not slot.visible or not slot.is_inside_tree():
			continue
		if not area_types.has(slot.area_type):
			continue
		var slot_is_left := slot.slot_index % 8 < 4
		if slot_is_left != left_group:
			continue
		var rect := Rect2(slot.global_position, slot.size)
		if not found:
			union_rect = rect
			found = true
		else:
			union_rect = union_rect.merge(rect)
	return union_rect if found else Rect2()

func _visible_slot_group_rect(target_area: String) -> Rect2:
	var found := false
	var union_rect := Rect2()
	for node in get_tree().get_nodes_in_group("card_slots"):
		var slot := node as CardSlotUI
		if slot == null or slot == self:
			continue
		if not slot.visible or not slot.is_inside_tree():
			continue
		if slot.area_type != target_area:
			continue
		var rect := Rect2(slot.global_position, slot.size)
		if not found:
			union_rect = rect
			found = true
		else:
			union_rect = union_rect.merge(rect)
	return union_rect if found else Rect2()

func _hide_hover_preview() -> void:
	if _hover_preview != null:
		_hover_preview.queue_free()
	_hover_preview = null


func _update_process_state() -> void:
	set_process(_drop_highlight_active or _slot_hover_active)

func get_card() -> CardInfo:
	return card_display.card

## 设置槽位是否解锁。锁定时显示半透明遮罩和闭合挂锁图标。
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

func get_lock_icon_global_rect() -> Rect2:
	if _unlocked or _lock_icon == null or not _lock_icon.visible or not _lock_icon.is_inside_tree():
		return Rect2()
	return _lock_icon.get_global_rect()

## 奖励钥匙抵达时先让锁与钥匙同时消失；随后由服务端结果正式刷新槽位状态。
func consume_reward_key_unlock() -> void:
	if _unlocked:
		return
	if _lock_icon != null:
		_lock_icon.visible = false
	if _lock_overlay != null:
		_lock_overlay.visible = false
	show_unlock_glow()

func _set_lock_visible() -> void:
	var locked = not _unlocked
	if _lock_overlay:
		_lock_overlay.visible = locked
	if _lock_icon:
		_lock_icon.visible = locked
	# 锁定时卡牌不可见
	if locked and card_display:
		card_display.visible = false

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb = event as InputEventMouseButton
		if mb.pressed and (mb.button_index == MOUSE_BUTTON_LEFT or mb.button_index == MOUSE_BUTTON_RIGHT):
			last_click_button_index = mb.button_index
			release_focus.call_deferred()
			if not _unlocked:
				if mb.button_index == MOUSE_BUTTON_LEFT:
					slot_unlock_requested.emit(slot_index)
			else:
				slot_clicked.emit(slot_index)

func _on_card_clicked(card: CardInfo, index: int) -> void:
	if card_display != null:
		last_click_button_index = card_display.last_click_button_index
	release_focus.call_deferred()
	slot_clicked.emit(slot_index)

func _on_card_double_clicked(card: CardInfo, index: int) -> void:
	# 向上传播双击信号给父级（CardPoolUI / HandAreaUI）
	slot_double_clicked.emit(slot_index)

func _on_focus_entered() -> void:
	if _focus_highlight != null:
		_focus_highlight.visible = true

func _on_focus_exited() -> void:
	if _focus_highlight != null:
		_focus_highlight.visible = false


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
		card_display.refresh_title_text_color()


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
	#   vault <-> vault (保险箱内换位 / 移动)
	# 禁止: vault -> pool, vault -> hand
	match src:
		"pool":
			return dst == "pool" or dst == "hand"
		"hand":
			return dst == "hand" or dst == "pool" or dst == "vault"
		"vault":
			return dst == "vault"
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
			card_display.refresh_title_text_color()
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
			card_display.refresh_title_text_color()
	)
