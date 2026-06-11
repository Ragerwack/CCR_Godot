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
var _art_image: TextureRect
var _card_name_label: Label
var _deck_name_label: Label
var _description_panel: Panel
var _description_label: Label
var _color_border: TextureRect
var _color_image_map: Dictionary = {}
var _fallback_color_rect: ColorRect
var _number_badge: Panel
var _number_label: Label
var _color_bar: ColorRect
var _series_tag_label: Label
var _hovered: bool = false
var _dragging_preview: bool = false
var _drop_targeted: bool = false
var _drag_anchor_ratio: Vector2 = Vector2(0.5, 0.5)
var _has_drag_anchor: bool = false
var _scale_tween: Tween = null
var hover_uses_slot_bounds: bool = true

static var CARD_SIZE: Vector2 = Vector2(107, 149)
static var _shared_color_image_map: Dictionary = {}
static var _texture_cache: Dictionary = {}
const HOVER_SCALE: float = 2.0
const DROP_TARGET_SCALE: float = 1.08
const HOVER_TRANSITION_DURATION: float = 0.3
const CARD_CANVAS_SIZE: Vector2 = Vector2(1000, 1400)
const FRAME_SOURCE_SIZE: Vector2 = Vector2(1060, 1484)
const CANVAS_SOURCE_OFFSET: Vector2 = Vector2(30, 42)
const ART_PATH_PREFIX: String = "res://Resources/Cards/"
const CARD_TEXT_COLOR: Color = Color(0.294118, 0.333333, 0.388235, 1.0)
const INFO_PANEL_BORDER_COLOR: Color = Color(0.850980, 0.866667, 0.898039, 1.0)
const INFO_PANEL_BG_COLOR: Color = Color(0.972549, 0.976471, 0.984314, 1.0)

static func configure_card_size(card_size: Vector2) -> void:
	CARD_SIZE = card_size

func _ready() -> void:
	custom_minimum_size = CARD_SIZE
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

	_art_image = TextureRect.new()
	_art_image.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_art_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_art_image.clip_contents = true
	_art_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_art_image)

	_deck_name_label = Label.new()
	_deck_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_deck_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_deck_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_deck_name_label.clip_contents = true
	_deck_name_label.add_theme_color_override("font_color", CARD_TEXT_COLOR)
	add_child(_deck_name_label)

	_number_badge = Panel.new()
	_number_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = INFO_PANEL_BG_COLOR
	badge_style.border_color = INFO_PANEL_BORDER_COLOR
	badge_style.set_border_width_all(3)
	badge_style.corner_radius_top_left = 999
	badge_style.corner_radius_top_right = 999
	badge_style.corner_radius_bottom_left = 999
	badge_style.corner_radius_bottom_right = 999
	_number_badge.add_theme_stylebox_override("panel", badge_style)
	add_child(_number_badge)

	_number_label = Label.new()
	_number_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_number_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_number_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_number_label.clip_contents = true
	_number_label.add_theme_color_override("font_color", CARD_TEXT_COLOR)
	_number_badge.add_child(_number_label)

	_card_name_label = Label.new()
	_card_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_card_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_card_name_label.clip_contents = true
	_card_name_label.add_theme_color_override("font_color", CARD_TEXT_COLOR)
	add_child(_card_name_label)

	_description_panel = Panel.new()
	_description_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var desc_style := StyleBoxFlat.new()
	desc_style.bg_color = INFO_PANEL_BG_COLOR
	desc_style.border_color = INFO_PANEL_BORDER_COLOR
	desc_style.set_border_width_all(2)
	desc_style.corner_radius_top_left = 4
	desc_style.corner_radius_top_right = 4
	desc_style.corner_radius_bottom_left = 4
	desc_style.corner_radius_bottom_right = 4
	_description_panel.add_theme_stylebox_override("panel", desc_style)
	add_child(_description_panel)

	_description_label = Label.new()
	_description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_description_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_description_label.add_theme_color_override("font_color", CARD_TEXT_COLOR)
	_description_label.clip_contents = true
	add_child(_description_label)

	_series_tag_label = Label.new()
	_series_tag_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_series_tag_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_series_tag_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_series_tag_label.clip_contents = true
	_series_tag_label.add_theme_color_override("font_color", CARD_TEXT_COLOR)
	add_child(_series_tag_label)

	_color_bar = ColorRect.new()
	_color_bar.color = Color.WHITE
	_color_bar.visible = false
	add_child(_color_bar)

	mouse_filter = MOUSE_FILTER_STOP
	_apply_card_layout()

	gui_input.connect(_on_gui_input)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	if DragSystem != null:
		DragSystem.drag_started.connect(_on_global_drag_started)
		DragSystem.drag_ended.connect(_on_global_drag_ended)
		DragSystem.drag_cancelled.connect(_on_global_drag_cancelled)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		pivot_offset = size * 0.5
		_apply_card_layout()
	elif what == NOTIFICATION_DRAG_END:
		_dragging_preview = false
		_apply_hover_transform()
		# 通知父级 CardSlotUI 清理拖出遮罩
		card_drag_ended.emit(card, card_index)
		# Godot 原生拖拽取消时（未落在有效 drop target），_drop_data 不会被调用
		# 而 signal drag_ended 不会被 DragSystem 记录，所以需要通知 DragSystem
		# is_dragging() 只有在 DragSystem.start_drag 被调用后才为 true
		# 这里直接从父级（CardSlotUI）获取需要的信息
		if DragSystem != null and DragSystem.is_dragging():
			DragSystem.cancel_drag()

func _on_mouse_entered() -> void:
	if hover_uses_slot_bounds:
		var parent = get_parent()
		if parent != null and parent.has_method("set_slot_hovered"):
			parent.set_slot_hovered(true)
		return
	if card == null:
		return
	_hovered = true
	_apply_hover_transform()

func _on_mouse_exited() -> void:
	if hover_uses_slot_bounds:
		var parent = get_parent()
		if parent != null and parent.has_method("set_slot_hovered"):
			parent.set_slot_hovered(false)
		return
	_hovered = false
	_apply_hover_transform()

func _apply_hover_transform() -> void:
	var global_dragging := DragSystem != null and DragSystem.is_dragging()
	if _hovered and not _dragging_preview and not global_dragging and card != null:
		pivot_offset = size * 0.5
		_tween_visual_scale(Vector2(HOVER_SCALE, HOVER_SCALE), 100)
	elif _drop_targeted and not _dragging_preview and card != null:
		pivot_offset = size * 0.5
		_tween_visual_scale(Vector2(DROP_TARGET_SCALE, DROP_TARGET_SCALE), 90)
	else:
		_tween_visual_scale(Vector2.ONE, 0)


func _tween_visual_scale(target_scale: Vector2, target_z_index: int) -> void:
	if _scale_tween != null and _scale_tween.is_valid():
		_scale_tween.kill()

	if target_z_index > 0:
		z_index = target_z_index

	if not is_inside_tree():
		scale = target_scale
		z_index = target_z_index
		return

	_scale_tween = create_tween()
	_scale_tween.tween_property(self, "scale", target_scale, HOVER_TRANSITION_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_scale_tween.finished.connect(func():
		if target_z_index == 0 and not _hovered and not _drop_targeted:
			z_index = 0
	)

func _on_global_drag_started(_card: CardInfo, _from: String) -> void:
	_apply_hover_transform()

func _on_global_drag_ended(_card: CardInfo, _from: String, _to: String) -> void:
	_dragging_preview = false
	_apply_hover_transform()

func _on_global_drag_cancelled() -> void:
	_dragging_preview = false
	_apply_hover_transform()

const FRAME_PATH_PREFIX: String = "res://Resources/Themes/card_frames/"

func _canvas_rect(x: float, y: float, w: float, h: float) -> Rect2:
	return Rect2(
		Vector2(size.x * (x + CANVAS_SOURCE_OFFSET.x) / FRAME_SOURCE_SIZE.x, size.y * (y + CANVAS_SOURCE_OFFSET.y) / FRAME_SOURCE_SIZE.y),
		Vector2(size.x * w / FRAME_SOURCE_SIZE.x, size.y * h / FRAME_SOURCE_SIZE.y)
	)

func _canvas_rect_for(target_size: Vector2, x: float, y: float, w: float, h: float) -> Rect2:
	return Rect2(
		Vector2(target_size.x * (x + CANVAS_SOURCE_OFFSET.x) / FRAME_SOURCE_SIZE.x, target_size.y * (y + CANVAS_SOURCE_OFFSET.y) / FRAME_SOURCE_SIZE.y),
		Vector2(target_size.x * w / FRAME_SOURCE_SIZE.x, target_size.y * h / FRAME_SOURCE_SIZE.y)
	)

func _font_size(canvas_px: float, minimum: int = 6) -> int:
	return maxi(minimum, int(round(size.y * canvas_px / CARD_CANVAS_SIZE.y)))

func _apply_rect(node: Control, rect: Rect2) -> void:
	node.set_anchors_preset(Control.PRESET_TOP_LEFT)
	node.position = rect.position
	node.size = rect.size

func _apply_card_layout() -> void:
	if _art_image == null or _deck_name_label == null or _number_badge == null or _card_name_label == null or _description_panel == null or _description_label == null or _series_tag_label == null:
		return

	if size.x <= 0 or size.y <= 0:
		size = CARD_SIZE

	_apply_rect(_art_image, _canvas_rect(90, 190, 820, 740))
	_apply_rect(_deck_name_label, _canvas_rect(90, 40, 720, 120))
	_apply_rect(_number_badge, _canvas_rect(900, -90, 190, 190))
	_apply_rect(_card_name_label, _canvas_rect(150, 900, 700, 90))
	var desc_rect := _canvas_rect(140, 1010, 720, 260)
	_apply_rect(_description_panel, desc_rect)
	_apply_rect(_description_label, desc_rect.grow(-maxf(2.0, size.x * 16.0 / FRAME_SOURCE_SIZE.x)))
	_apply_rect(_series_tag_label, _canvas_rect(300, 1320, 400, 60))

	_deck_name_label.add_theme_font_size_override("font_size", _font_size(64, 8))
	_number_label.add_theme_font_size_override("font_size", _font_size(104, 10))
	_card_name_label.add_theme_font_size_override("font_size", _font_size(54, 8))
	_description_label.add_theme_font_size_override("font_size", _font_size(34, 6))
	_series_tag_label.add_theme_font_size_override("font_size", _font_size(28, 6))

func _load_color_images() -> void:
	if not _shared_color_image_map.is_empty():
		_color_image_map = _shared_color_image_map
		return
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
		var tex = _load_texture_cached(path)
		if tex != null:
			_color_image_map[color_type] = tex
		else:
			push_warning("[CardDisplay] 纹理缺失: " + path)
	_shared_color_image_map = _color_image_map

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
	_hovered = false
	_dragging_preview = false
	_apply_hover_transform()
	_card_name_label.text = ""
	_deck_name_label.text = ""
	_description_label.text = ""
	_number_label.text = ""
	_series_tag_label.text = ""
	_art_image.texture = null
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

	# 子卡编号圆环
	_number_label.text = "%d" % card.card_number
	_series_tag_label.text = card.series_name
	_apply_card_art(card)

	# 颜色条 + 边框
	if show_color_border:
		_apply_color_border(card.color)
	_color_bar.color = _get_color_by_card_color(card.color)

func _apply_card_art(card_info: CardInfo) -> void:
	_art_image.texture = null
	var explicit_path := _normalize_art_path(card_info.image_path)
	var explicit_tex = _load_texture_cached(explicit_path)
	if explicit_tex != null:
		_art_image.texture = explicit_tex
		return
	var card_id := int(card_info.id)
	if card_id <= 0:
		return
	var base: String = "card_%03d" % card_id
	for ext: String in [".jpg", ".png", ".webp", ".jpeg"]:
		var path: String = ART_PATH_PREFIX + base + ext
		var tex = _load_texture_cached(path)
		if tex != null:
			_art_image.texture = tex
			return

static func _load_texture_cached(path: String):
	if path == "":
		return null
	if _texture_cache.has(path):
		return _texture_cache[path]
	if not ResourceLoader.exists(path, "Texture2D"):
		return null
	var tex = ResourceLoader.load(path)
	if tex != null:
		_texture_cache[path] = tex
	return tex

func _normalize_art_path(raw_path: String) -> String:
	var p := raw_path.strip_edges()
	if p == "":
		return ""
	if p.begins_with("res://"):
		return p
	var file_name := p.get_file()
	if file_name == "":
		return ""
	return ART_PATH_PREFIX + file_name

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


func set_drop_targeted(active: bool) -> void:
	_drop_targeted = active
	_apply_hover_transform()


func set_slot_hovered(active: bool) -> void:
	if card == null:
		active = false
	_hovered = active
	_apply_hover_transform()

var _double_click_timer: float = 0.0
var _click_count: int = 0

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb = event as InputEventMouseButton
		if mb.pressed:
			_drag_anchor_ratio = _position_to_anchor_ratio(mb.position)
			_has_drag_anchor = true
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

func _get_drag_data(at_position: Vector2) -> Variant:
	# 没有卡牌、不可拖拽、或锁定时不允许拖拽
	if card == null or not is_draggable:
		return null

	var ratio := _drag_anchor_ratio
	if not _has_drag_anchor:
		ratio = _position_to_anchor_ratio(at_position)
	_has_drag_anchor = false
	var card_offset := Vector2(CARD_SIZE.x * ratio.x, CARD_SIZE.y * ratio.y)

	_dragging_preview = true
	_apply_hover_transform()

	# 通知 DragSystem 开始拖拽（用于后续取消逻辑追踪）
	if DragSystem != null:
		DragSystem.start_drag(card, drag_source, card_index, card_offset)

	# 创建半透明拖拽预览。Godot 会接管 preview 根节点位置，因此偏移必须放在子节点上。
	var preview = _create_drag_preview(card_offset)

	set_drag_preview(preview)

	# 通知信号
	card_drag_started.emit(card, card_index)

	# 返回拖拽数据
	return {
		"card": card,
		"source": drag_source,
		"source_index": card_index,
	}


func _position_to_anchor_ratio(pos: Vector2) -> Vector2:
	return Vector2(
		clampf(pos.x / maxf(size.x, 1.0), 0.0, 1.0),
		clampf(pos.y / maxf(size.y, 1.0), 0.0, 1.0)
	)


## 创建拖拽时的半透明预览副本
func _create_drag_preview(card_offset: Vector2) -> Control:
	var preview = Control.new()
	preview.set_anchors_preset(Control.PRESET_TOP_LEFT)
	preview.size = Vector2(1, 1)
	preview.z_index = 4096
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var card_layer = Control.new()
	card_layer.set_anchors_preset(Control.PRESET_TOP_LEFT)
	card_layer.position = -card_offset
	card_layer.size = CARD_SIZE
	card_layer.z_index = 4096
	card_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.add_child(card_layer)

	# 背景 — 不设锚点，手动设 size
	var bg = ColorRect.new()
	bg.position = Vector2(0, 0)
	bg.size = CARD_SIZE
	bg.color = Color(0.2, 0.2, 0.25, 1.0)
	card_layer.add_child(bg)

	if _art_image.texture != null:
		var art_rect := _canvas_rect_for(CARD_SIZE, 90, 190, 820, 740)
		var art = TextureRect.new()
		art.position = art_rect.position
		art.size = art_rect.size
		art.texture = _art_image.texture
		art.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art.clip_contents = true
		card_layer.add_child(art)

	# 复制颜色边框
	if _color_border.visible and _color_border.texture != null:
		var border = TextureRect.new()
		border.position = Vector2(0, 0)
		border.size = CARD_SIZE
		border.texture = _color_border.texture
		border.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		border.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		border.modulate = Color(1, 1, 1, 1)
		card_layer.add_child(border)

	# 复制卡组名
	var deck_rect := _canvas_rect_for(CARD_SIZE, 90, 40, 720, 120)
	var deck_lbl = Label.new()
	deck_lbl.position = deck_rect.position
	deck_lbl.size = deck_rect.size
	deck_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	deck_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	deck_lbl.text = _deck_name_label.text
	deck_lbl.add_theme_font_size_override("font_size", _font_size(64, 8))
	deck_lbl.add_theme_color_override("font_color", CARD_TEXT_COLOR)
	card_layer.add_child(deck_lbl)

	var badge_rect := _canvas_rect_for(CARD_SIZE, 900, -90, 190, 190)
	var badge = Panel.new()
	badge.position = badge_rect.position
	badge.size = badge_rect.size
	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = INFO_PANEL_BG_COLOR
	badge_style.border_color = INFO_PANEL_BORDER_COLOR
	badge_style.set_border_width_all(3)
	badge_style.corner_radius_top_left = 999
	badge_style.corner_radius_top_right = 999
	badge_style.corner_radius_bottom_left = 999
	badge_style.corner_radius_bottom_right = 999
	badge.add_theme_stylebox_override("panel", badge_style)
	card_layer.add_child(badge)

	var number_lbl = Label.new()
	number_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	number_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	number_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	number_lbl.text = _number_label.text
	number_lbl.add_theme_font_size_override("font_size", _font_size(104, 10))
	number_lbl.add_theme_color_override("font_color", CARD_TEXT_COLOR)
	badge.add_child(number_lbl)

	# 复制卡名
	var name_rect := _canvas_rect_for(CARD_SIZE, 150, 900, 700, 90)
	var name_lbl = Label.new()
	name_lbl.position = name_rect.position
	name_lbl.size = name_rect.size
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_lbl.text = _card_name_label.text
	name_lbl.add_theme_font_size_override("font_size", _font_size(54, 8))
	name_lbl.add_theme_color_override("font_color", CARD_TEXT_COLOR)
	card_layer.add_child(name_lbl)

	var desc_rect := _canvas_rect_for(CARD_SIZE, 140, 1010, 720, 260)
	var desc_panel = Panel.new()
	desc_panel.position = desc_rect.position
	desc_panel.size = desc_rect.size
	var desc_style := StyleBoxFlat.new()
	desc_style.bg_color = INFO_PANEL_BG_COLOR
	desc_style.border_color = INFO_PANEL_BORDER_COLOR
	desc_style.set_border_width_all(2)
	desc_style.corner_radius_top_left = 4
	desc_style.corner_radius_top_right = 4
	desc_style.corner_radius_bottom_left = 4
	desc_style.corner_radius_bottom_right = 4
	desc_panel.add_theme_stylebox_override("panel", desc_style)
	card_layer.add_child(desc_panel)

	var desc_lbl = Label.new()
	var desc_inset := maxf(2.0, CARD_SIZE.x * 16.0 / FRAME_SOURCE_SIZE.x)
	var desc_inner := desc_rect.grow(-desc_inset)
	desc_lbl.position = desc_inner.position
	desc_lbl.size = desc_inner.size
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.text = _description_label.text
	desc_lbl.add_theme_font_size_override("font_size", _font_size(34, 6))
	desc_lbl.add_theme_color_override("font_color", CARD_TEXT_COLOR)
	desc_lbl.clip_contents = true
	card_layer.add_child(desc_lbl)

	var series_rect := _canvas_rect_for(CARD_SIZE, 300, 1320, 400, 60)
	var series_lbl = Label.new()
	series_lbl.position = series_rect.position
	series_lbl.size = series_rect.size
	series_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	series_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	series_lbl.text = _series_tag_label.text
	series_lbl.add_theme_font_size_override("font_size", _font_size(28, 6))
	series_lbl.add_theme_color_override("font_color", CARD_TEXT_COLOR)
	card_layer.add_child(series_lbl)

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
