extends Control
class_name CardDisplay

signal card_clicked(card: CardInfo, index: int)
signal card_double_clicked(card: CardInfo, index: int)
signal card_drag_started(card: CardInfo, index: int)
signal card_drag_ended(card: CardInfo, index: int)

@export var show_color_border: bool = true
@export var show_card_name: bool = true
@export var card_scale: float = 1.0

var card: CardInfo = null
var card_index: int = -1
var is_selected: bool = false

# ── 拖拽属性（由父级 CardSlotUI 设置） ──
var drag_source: String = ""   # "pool" / "hand" / "vault"
var is_draggable: bool = true   # 锁定时为 false

var _card_bg: ColorRect
var _card_name_label: Label
var _deck_name_label: Label
var _description_label: Label
var _color_border: TextureRect
var _color_image_map: Dictionary = {}
var _fallback_color_rect: ColorRect
var _number_label: Label
var _color_bar: ColorRect

func _ready() -> void:
	custom_minimum_size = Vector2(97, 135)   # 与 CardSlotUI 槽位尺寸一致
	setup_ui()

func setup_ui() -> void:
	_card_bg = ColorRect.new()
	_card_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_card_bg.color = Color(0.2, 0.2, 0.25, 1.0)
	add_child(_card_bg)

	_color_border = TextureRect.new()
	_color_border.set_anchors_preset(Control.PRESET_FULL_RECT)
	_color_border.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_color_border.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_color_border.visible = show_color_border
	add_child(_color_border)

	_fallback_color_rect = ColorRect.new()
	_fallback_color_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fallback_color_rect.color = Color(1, 1, 1, 0.1)
	_fallback_color_rect.visible = false
	add_child(_fallback_color_rect)

	_load_color_images()

	# ═══ 88×123 紧凑布局 ═══
	# 顶部留 2px 边距，卡组名 14px
	# 卡名区域居中，最多 50px
	# 描述 30px
	# 颜色条 + 序号底部 4px 边距
	# 总计: 2+14+2+50+2+30+2+6+4+4+2+5 = 123

	# --- 卡组名（顶部，黄金色）---
	_deck_name_label = Label.new()
	_deck_name_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_deck_name_label.position = Vector2(2, 2)
	_deck_name_label.size = Vector2(-4, 16)
	_deck_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_deck_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_deck_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_deck_name_label.clip_contents = true
	_deck_name_label.add_theme_font_size_override("font_size", 9)
	_deck_name_label.add_theme_color_override("font_color", Color(1, 0.9, 0.5, 0.85))
	add_child(_deck_name_label)

	# --- 子卡名（中部大字）---
	_card_name_label = Label.new()
	_card_name_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_card_name_label.position = Vector2(3, 20)
	_card_name_label.size = Vector2(-6, 48)
	_card_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_card_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_card_name_label.clip_contents = true
	_card_name_label.add_theme_font_size_override("font_size", 12)
	add_child(_card_name_label)

	# --- 描述文字（中部下方，较小字体）---
	_description_label = Label.new()
	_description_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_description_label.position = Vector2(3, 72)
	_description_label.size = Vector2(-6, 28)
	_description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_description_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_description_label.add_theme_font_size_override("font_size", 7)
	_description_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.45))
	_description_label.clip_contents = true
	add_child(_description_label)

	# --- 颜色条（底部 4px 边距内）---
	# 底部宽锚点，position.y 从底部向上偏移
	# 颜色条底部距卡片底部 4px，颜色条高 5px → 顶部距底部 9px
	# 所以 position.y = 9 (从底部向上 9px)
	_color_bar = ColorRect.new()
	_color_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_color_bar.position = Vector2(6, 9)
	_color_bar.size = Vector2(-12, 5)
	_color_bar.color = Color.WHITE
	add_child(_color_bar)

	# --- 序号（叠在颜色条上方）---
	# 底部锚点，position.y = 5 表示从底部向上 5px，叠在颜色条内容区域
	_number_label = Label.new()
	_number_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_number_label.position = Vector2(0, 7)
	_number_label.size = Vector2(0, 12)
	_number_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_number_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_number_label.clip_contents = true
	_number_label.add_theme_font_size_override("font_size", 9)
	_number_label.add_theme_color_override("font_color", Color(0, 0, 0, 0.85))
	add_child(_number_label)

	mouse_filter = MOUSE_FILTER_STOP

	gui_input.connect(_on_gui_input)

const FRAME_PATH_PREFIX: String = "res://Resources/Themes/card_frames/"

func _load_color_images() -> void:
	var color_map = {
		CardColor.ColorType.WHITE: "frame_white.png",
		CardColor.ColorType.GREEN: "frame_green.png",
		CardColor.ColorType.BLUE: "frame_blue.png",
		CardColor.ColorType.PURPLE: "frame_purple.png",
		CardColor.ColorType.ORANGE: "frame_orange.png",
		CardColor.ColorType.BLACK: "frame_black.png",
		CardColor.ColorType.RED: "frame_red.png",
	}
	for color_type in color_map:
		var path = FRAME_PATH_PREFIX + color_map[color_type]
		if ResourceLoader.exists(path, "Texture2D"):
			_color_image_map[color_type] = ResourceLoader.load(path)
		else:
			push_warning("[CardDisplay] 纹理缺失: " + path)

func _apply_color_border(ct: CardColor.ColorType) -> void:
	if _color_image_map.has(ct):
		var tex: Texture2D = _color_image_map[ct]
		_color_border.texture = tex
		_color_border.visible = true
		_fallback_color_rect.visible = false
	else:
		_color_border.visible = false
		_fallback_color_rect.visible = true
		_fallback_color_rect.color = _get_color_by_card_color(ct)

func set_card(c: CardInfo, idx: int = -1) -> void:
	card = c
	card_index = idx
	_update_display()

func clear() -> void:
	card = null
	card_index = -1
	_card_name_label.text = ""
	_deck_name_label.text = ""
	_description_label.text = ""
	_number_label.text = ""
	_color_bar.color = Color(0.2, 0.2, 0.25, 1.0)

func _update_display() -> void:
	if card == null:
		clear()
		return

	# 卡组名（顶部，后端 deck_name 已本地化，优先使用）
	var deck_display = card.deck_name
	if deck_display == "":
		deck_display = card.series_name
	_deck_name_label.text = deck_display

	# 子卡名（中部大字）
	if show_card_name:
		_card_name_label.text = card.card_name
	else:
		_card_name_label.text = ""

	# 描述文字
	_description_label.text = card.description

	# 序号（底部）
	_number_label.text = "#%d" % card.card_number

	# 颜色条 + 边框
	if show_color_border:
		_apply_color_border(card.color)
	_color_bar.color = _get_color_by_card_color(card.color)

func _get_color_by_card_color(c: CardColor.ColorType) -> Color:
	match c:
		CardColor.ColorType.WHITE: return Color(0.9, 0.9, 0.9, 0.8)
		CardColor.ColorType.GREEN: return Color(0.2, 0.8, 0.2, 0.8)
		CardColor.ColorType.BLUE: return Color(0.2, 0.4, 0.9, 0.8)
		CardColor.ColorType.PURPLE: return Color(0.7, 0.2, 0.9, 0.8)
		CardColor.ColorType.ORANGE: return Color(1.0, 0.6, 0.1, 0.8)
		CardColor.ColorType.BLACK: return Color(0.1, 0.1, 0.1, 0.9)
		CardColor.ColorType.RED: return Color(0.9, 0.1, 0.1, 0.8)
	return Color.WHITE

func set_selected(s: bool) -> void:
	is_selected = s
	if s:
		_card_bg.color = Color(0.4, 0.4, 0.3, 1.0)
	else:
		_card_bg.color = Color(0.2, 0.2, 0.25, 1.0)

var _double_click_timer: float = 0.0
var _click_count: int = 0

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb = event as InputEventMouseButton
		if mb.pressed:
			if mb.double_click:
				_click_count += 1
				if _click_count >= 2:
					_click_count = 0
					if card != null:
						card_double_clicked.emit(card, card_index)
			else:
				_click_count = 1
				_double_click_timer = 0.3  # 300ms window
				if card != null:
					card_clicked.emit(card, card_index)


# ══════════════════════════════════════════════════
#  原生拖拽（Godot 4 DnD）
# ══════════════════════════════════════════════════

## 原生拖拽结束通知（包括取消和成功）
func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		# 通知父级 CardSlotUI 清理拖出遮罩
		card_drag_ended.emit(card, card_index)
		# Godot 原生拖拽取消时（未落在有效 drop target），_drop_data 不会被调用
		# 而 signal drag_ended 不会被 DragSystem 记录，所以需要通知 DragSystem
		# is_dragging() 只有在 DragSystem.start_drag 被调用后才为 true
		# 这里直接从父级（CardSlotUI）获取需要的信息
		if DragSystem != null and DragSystem.is_dragging():
			DragSystem.cancel_drag()


func _get_drag_data(at_position: Vector2) -> Variant:
	# 没有卡牌、不可拖拽、或锁定时不允许拖拽
	if card == null or not is_draggable:
		return null

	# 通知 DragSystem 开始拖拽（用于后续取消逻辑追踪）
	if DragSystem != null:
		DragSystem.start_drag(card, drag_source, card_index)

	# 创建半透明拖拽预览
	var preview = _create_drag_preview()

	# 关键修复：强制预览用 TOP_LEFT 锚点并设固定大小，避免锚点偏移
	preview.set_anchors_preset(Control.PRESET_TOP_LEFT)
	preview.size = Vector2(97, 135)

	# 偏移：鼠标在预览中的相对位置不变
	# at_position 是鼠标在 CardDisplay 内的本地坐标
	# 取负值后，鼠标会定位在 preview 的 at_position 处
	preview.position = -at_position

	set_drag_preview(preview)

	# 通知信号
	card_drag_started.emit(card, card_index)

	# 返回拖拽数据
	return {
		"card": card,
		"source": drag_source,
		"source_index": card_index,
	}


## 创建拖拽时的半透明预览副本
func _create_drag_preview() -> Control:
	var preview = Control.new()
	# 不设 custom_minimum_size，由调用者设 size

	# 背景 — 不设锚点，手动设 size
	var bg = ColorRect.new()
	bg.position = Vector2(0, 0)
	bg.size = Vector2(97, 135)
	bg.color = Color(0.2, 0.2, 0.25, 0.6)  # 半透明
	preview.add_child(bg)

	# 复制颜色边框
	if _color_border.visible and _color_border.texture != null:
		var border = TextureRect.new()
		border.position = Vector2(0, 0)
		border.size = Vector2(97, 135)
		border.texture = _color_border.texture
		border.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		border.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		border.modulate = Color(1, 1, 1, 0.7)
		preview.add_child(border)

	# 复制卡组名
	var deck_lbl = Label.new()
	deck_lbl.position = Vector2(2, 2)
	deck_lbl.size = Vector2(93, 16)
	deck_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	deck_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	deck_lbl.text = _deck_name_label.text
	deck_lbl.add_theme_font_size_override("font_size", 9)
	deck_lbl.add_theme_color_override("font_color", Color(1, 0.9, 0.5, 0.6))
	preview.add_child(deck_lbl)

	# 复制卡名
	var name_lbl = Label.new()
	name_lbl.position = Vector2(3, 20)
	name_lbl.size = Vector2(91, 48)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_lbl.text = _card_name_label.text
	name_lbl.add_theme_font_size_override("font_size", 12)
	name_lbl.modulate = Color(1, 1, 1, 0.8)
	preview.add_child(name_lbl)

	# 复制颜色条
	var bar = ColorRect.new()
	bar.position = Vector2(6, 121)  # 135 - 5 - 9 = 121
	bar.size = Vector2(85, 5)
	bar.color = _color_bar.color
	bar.modulate = Color(1, 1, 1, 0.7)
	preview.add_child(bar)

	return preview


## 将拖放事件转发给父级 CardSlotUI（因为 CardDisplay 覆盖了整个槽位）
func _can_drop_data(_pos: Vector2, data: Variant) -> bool:
	var parent = get_parent()
	if parent != null and parent.has_method("_can_drop_data"):
		return parent._can_drop_data(_pos + position, data)
	return false


func _drop_data(_pos: Vector2, data: Variant) -> void:
	var parent = get_parent()
	if parent != null and parent.has_method("_drop_data"):
		parent._drop_data(_pos + position, data)
