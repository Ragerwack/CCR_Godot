extends Control
class_name CardDisplay

const CCRVisualStyle = preload("res://Scripts/UI/CCRVisualStyle.gd")

signal card_clicked(card: CardInfo, index: int)
signal card_double_clicked(card: CardInfo, index: int)
signal card_drag_started(card: CardInfo, index: int)
signal card_drag_ended(card: CardInfo, index: int)
signal card_hover_changed(display: CardDisplay, active: bool)

@export var show_color_border: bool = true
@export var show_card_name: bool = true
@export var card_scale: float = 1.0

var card: CardInfo = null
var card_index: int = -1
var is_selected: bool = false
var last_click_button_index: int = MOUSE_BUTTON_LEFT

# ── 拖拽属性（由父级 CardSlotUI 设置） ──
var drag_source: String = ""   # "pool" / "hand" / "vault"
var is_draggable: bool = true   # 锁定时为 false

var _card_bg: ColorRect
var _card_shadow: Panel
var _art_shadow: Panel
var _art_image: TextureRect
var _deck_name_region: Control
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
var _card_name_region: Control
var _series_tag_region: Control
var _series_tag_label: Label
var _rarity_shine_overlay: ColorRect
var _rarity_shine_material: ShaderMaterial
var _blue_draw_back: TextureRect
var _active_title_text_color: Color = CARD_TEXT_COLOR
var _hovered: bool = false
var _dragging_preview: bool = false
var _drop_targeted: bool = false
var _drag_anchor_ratio: Vector2 = Vector2(0.5, 0.5)
var _has_drag_anchor: bool = false
var _scale_tween: Tween = null
var _rarity_shine_tween: Tween = null
var hover_uses_slot_bounds: bool = true
var hover_scale_enabled: bool = true

static var CARD_SIZE: Vector2 = Vector2(107, 149)
static var _shared_color_image_map: Dictionary = {}
static var _texture_cache: Dictionary = {}
static var _art_texture_cache: Dictionary = {}
static var _rounded_mask_shader: Shader = null
static var _green_draw_shine_shader: Shader = null
const HOVER_SCALE: float = 2.0
const DROP_TARGET_SCALE: float = 1.08
const HOVER_TRANSITION_DURATION: float = 0.3
const CARD_CANVAS_SIZE: Vector2 = Vector2(1000, 1400)
const FRAME_SOURCE_SIZE: Vector2 = Vector2(1060, 1484)
const CANVAS_SOURCE_OFFSET: Vector2 = Vector2(30, 42)
const ART_PATH_PREFIX: String = "res://Resources/Cards/"
const CARD_TEXT_COLOR: Color = Color(0.294118, 0.333333, 0.388235, 1.0)
const CARD_TEXT_COLOR_GREEN: Color = Color(1.000000, 0.878431, 0.513725, 1.0)
const CARD_TEXT_COLOR_BLUE: Color = Color(0.023529, 0.113725, 0.258824, 1.0)
const CARD_TEXT_COLOR_PURPLE: Color = Color(1.000000, 0.886275, 0.552941, 1.0)
const CARD_TEXT_COLOR_ORANGE: Color = Color(0.258824, 0.070588, 0.125490, 1.0)
const CARD_TEXT_COLOR_BLACK: Color = Color(0.941176, 0.800000, 0.403922, 1.0)
const CARD_TEXT_COLOR_RED: Color = Color(1.000000, 0.858824, 0.592157, 1.0)
const INFO_PANEL_BORDER_COLOR: Color = Color(0.850980, 0.866667, 0.898039, 1.0)
const INFO_PANEL_BG_COLOR: Color = Color(0.972549, 0.976471, 0.984314, 1.0)
const CARD_CORNER_RADIUS_RATIO: float = 1.0 / 13.0
const GREEN_DRAW_SHINE_DURATION: float = 0.50
const BLUE_DRAW_FLIP_DURATION: float = 0.60
const BLUE_DRAW_SHINE_DURATION: float = GREEN_DRAW_SHINE_DURATION
const ART_CORNER_RADIUS_RATIO: float = 0.1
const ART_RECT_RATIO: Rect2 = Rect2(0.06, 0.09, 0.88, 0.56)
const DECK_NAME_RECT_RATIO: Rect2 = Rect2(0.10, 0.01, 0.80, 0.07)
const CARD_NAME_RECT_RATIO: Rect2 = Rect2(0.10, 0.67, 0.80, 0.06)
const DESCRIPTION_RECT_RATIO: Rect2 = Rect2(0.08, 0.75, 0.84, 0.17)
const SERIES_TAG_RECT_RATIO: Rect2 = Rect2(0.10, 0.94, 0.80, 0.05)
const NUMBER_BADGE_RECT_RATIO: Rect2 = Rect2(0.811, 0.008, 0.179, 0.128)
const DECK_NAME_FONT_CANVAS: float = 92.0
const CARD_NAME_FONT_CANVAS: float = 62.0
const DESCRIPTION_FONT_CANVAS: float = 34.0
const SERIES_TAG_FONT_CANVAS: float = 32.0
const NUMBER_BADGE_FONT_CANVAS: float = 80.0
const CARD_ROUNDED_MASK_SHADER: String = """
shader_type canvas_item;

uniform float aspect_ratio = 0.718;
uniform float radius_ratio = 0.0769230769;

void fragment() {
	vec4 source = texture(TEXTURE, UV) * COLOR;
	vec2 point = vec2(UV.x - 0.5, (UV.y - 0.5) / aspect_ratio);
	vec2 half_size = vec2(0.5, 0.5 / aspect_ratio);
	vec2 distance_to_corner = abs(point) - half_size + vec2(radius_ratio);
	float signed_distance = length(max(distance_to_corner, vec2(0.0)))
		+ min(max(distance_to_corner.x, distance_to_corner.y), 0.0)
		- radius_ratio;
	float edge = max(fwidth(signed_distance), 0.0005);
	source.a *= 1.0 - smoothstep(-edge, edge, signed_distance);
	COLOR = source;
}
"""
const GREEN_DRAW_SHINE_SHADER: String = """
shader_type canvas_item;

uniform float progress = -0.20;
uniform float aspect_ratio = 0.718;
uniform float radius_ratio = 0.0769230769;
uniform vec4 shine_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
	vec2 point = vec2(UV.x - 0.5, (UV.y - 0.5) / aspect_ratio);
	vec2 half_size = vec2(0.5, 0.5 / aspect_ratio);
	vec2 distance_to_corner = abs(point) - half_size + vec2(radius_ratio);
	float signed_distance = length(max(distance_to_corner, vec2(0.0)))
		+ min(max(distance_to_corner.x, distance_to_corner.y), 0.0)
		- radius_ratio;
	float rounded_edge = max(fwidth(signed_distance), 0.0005);
	float rounded_alpha = 1.0 - smoothstep(-rounded_edge, rounded_edge, signed_distance);

	// 光带沿左上到右下方向移动；颜色由抽卡稀有度传入。
	float diagonal = (UV.x + UV.y) * 0.5;
	float distance_to_band = abs(diagonal - progress);
	float soft_band = 1.0 - smoothstep(0.025, 0.125, distance_to_band);
	float bright_core = 1.0 - smoothstep(0.0, 0.035, distance_to_band);
	float alpha = (soft_band * 0.28 + bright_core * 0.16) * rounded_alpha;
	COLOR = vec4(shine_color.rgb, alpha * shine_color.a);
}
"""

static func configure_card_size(card_size: Vector2) -> void:
	CARD_SIZE = card_size

func _ready() -> void:
	custom_minimum_size = CARD_SIZE
	setup_ui()

func setup_ui() -> void:
	clip_contents = false
	_card_shadow = CCRVisualStyle.make_shadow_panel("CardShadow", int(roundf(CARD_SIZE.x * 0.08)), 14, Vector2(5, 8), CCRVisualStyle.CARD_SHADOW)
	_card_shadow.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_card_shadow.position = Vector2.ZERO
	_card_shadow.size = CARD_SIZE
	add_child(_card_shadow)

	_card_bg = ColorRect.new()
	_card_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_card_bg.color = Color(0.2, 0.2, 0.25, 1.0)
	_card_bg.material = _new_rounded_mask_material(CARD_SIZE)
	add_child(_card_bg)

	_fallback_color_rect = ColorRect.new()
	_fallback_color_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fallback_color_rect.color = Color(1, 1, 1, 0.1)
	_fallback_color_rect.material = _new_rounded_mask_material(CARD_SIZE)
	_fallback_color_rect.visible = false
	add_child(_fallback_color_rect)

	_load_color_images()

	_color_border = TextureRect.new()
	_color_border.set_anchors_preset(Control.PRESET_FULL_RECT)
	_color_border.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_color_border.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_color_border.material = _new_rounded_mask_material(CARD_SIZE)
	_color_border.visible = show_color_border
	add_child(_color_border)

	_blue_draw_back = TextureRect.new()
	_blue_draw_back.name = "BlueDrawCardBack"
	_blue_draw_back.set_anchors_preset(Control.PRESET_FULL_RECT)
	_blue_draw_back.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_blue_draw_back.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_blue_draw_back.material = _new_rounded_mask_material(CARD_SIZE)
	_blue_draw_back.texture = _color_image_map.get(CardColor.ColorType.BLUE)
	_blue_draw_back.visible = false
	_blue_draw_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_blue_draw_back)

	_art_shadow = CCRVisualStyle.make_shadow_panel("ArtCenteredShadow", int(roundf(CARD_SIZE.x * ART_RECT_RATIO.size.x * ART_CORNER_RADIUS_RATIO)), 8, Vector2.ZERO, Color(0, 0, 0, 0.34))
	_art_shadow.set_anchors_preset(Control.PRESET_TOP_LEFT)
	add_child(_art_shadow)

	_art_image = TextureRect.new()
	_art_image.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_art_image.stretch_mode = TextureRect.STRETCH_SCALE
	_art_image.clip_contents = true
	_art_image.custom_minimum_size = Vector2.ZERO
	_art_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_art_image)

	_deck_name_region = Control.new()
	_deck_name_region.name = "DeckNameRegion"
	_deck_name_region.clip_contents = true
	_deck_name_region.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_deck_name_region)

	_deck_name_label = Label.new()
	_deck_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_deck_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_deck_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_deck_name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_deck_name_label.clip_text = true
	_deck_name_label.clip_contents = true
	_deck_name_label.custom_minimum_size = Vector2.ZERO
	_deck_name_label.add_theme_color_override("font_color", CARD_TEXT_COLOR)
	_deck_name_region.add_child(_deck_name_label)

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
	_number_label.clip_text = true
	_number_label.clip_contents = true
	_number_label.add_theme_color_override("font_color", CARD_TEXT_COLOR)
	_number_badge.add_child(_number_label)

	_card_name_region = Control.new()
	_card_name_region.name = "CardNameRegion"
	_card_name_region.clip_contents = true
	_card_name_region.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_card_name_region)

	_card_name_label = Label.new()
	_card_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_card_name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_card_name_label.clip_text = true
	_card_name_label.clip_contents = true
	_card_name_label.custom_minimum_size = Vector2.ZERO
	_card_name_label.add_theme_color_override("font_color", CARD_TEXT_COLOR)
	_card_name_region.add_child(_card_name_label)

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
	_description_label.clip_text = true
	_description_label.add_theme_color_override("font_color", CARD_TEXT_COLOR)
	_description_label.clip_contents = true
	_description_label.custom_minimum_size = Vector2.ZERO
	add_child(_description_label)

	_series_tag_region = Control.new()
	_series_tag_region.name = "SeriesTagRegion"
	_series_tag_region.clip_contents = true
	_series_tag_region.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_series_tag_region)

	_series_tag_label = Label.new()
	_series_tag_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_series_tag_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_series_tag_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_series_tag_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_series_tag_label.clip_text = true
	_series_tag_label.clip_contents = true
	_series_tag_label.custom_minimum_size = Vector2.ZERO
	_series_tag_label.add_theme_color_override("font_color", CARD_TEXT_COLOR)
	_series_tag_region.add_child(_series_tag_label)

	_color_bar = ColorRect.new()
	_color_bar.color = Color.WHITE
	_color_bar.visible = false
	add_child(_color_bar)

	_rarity_shine_overlay = ColorRect.new()
	_rarity_shine_overlay.name = "GreenDrawShine"
	_rarity_shine_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rarity_shine_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rarity_shine_overlay.color = Color.WHITE
	_rarity_shine_material = _new_green_draw_shine_material(size if size.x > 0.0 and size.y > 0.0 else CARD_SIZE)
	_rarity_shine_overlay.material = _rarity_shine_material
	_rarity_shine_overlay.visible = false
	add_child(_rarity_shine_overlay)

	mouse_filter = MOUSE_FILTER_STOP
	_apply_card_layout()

	gui_input.connect(_on_gui_input)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	if DragSystem != null:
		DragSystem.drag_started.connect(_on_global_drag_started)
		DragSystem.drag_ended.connect(_on_global_drag_ended)
		DragSystem.drag_cancelled.connect(_on_global_drag_cancelled)

static func _new_rounded_mask_material(card_size: Vector2, corner_radius_ratio: float = CARD_CORNER_RADIUS_RATIO) -> ShaderMaterial:
	if _rounded_mask_shader == null:
		_rounded_mask_shader = Shader.new()
		_rounded_mask_shader.code = CARD_ROUNDED_MASK_SHADER
	var material := ShaderMaterial.new()
	material.shader = _rounded_mask_shader
	material.set_shader_parameter("aspect_ratio", card_size.x / maxf(card_size.y, 1.0))
	material.set_shader_parameter("radius_ratio", corner_radius_ratio)
	return material

static func _new_green_draw_shine_material(card_size: Vector2) -> ShaderMaterial:
	if _green_draw_shine_shader == null:
		_green_draw_shine_shader = Shader.new()
		_green_draw_shine_shader.code = GREEN_DRAW_SHINE_SHADER
	var material := ShaderMaterial.new()
	material.shader = _green_draw_shine_shader
	material.set_shader_parameter("progress", -0.20)
	material.set_shader_parameter("shine_color", Color.WHITE)
	material.set_shader_parameter("aspect_ratio", card_size.x / maxf(card_size.y, 1.0))
	material.set_shader_parameter("radius_ratio", CARD_CORNER_RADIUS_RATIO)
	return material

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		pivot_offset = size * 0.5
		_apply_card_layout()
		_update_green_draw_shine_mask()
		refresh_title_text_color()
	elif what == NOTIFICATION_THEME_CHANGED:
		refresh_title_text_color()
	elif what == NOTIFICATION_DRAG_END:
		_dragging_preview = false
		_apply_hover_transform()
		refresh_title_text_color()
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
	card_hover_changed.emit(self, true)
	AudioManager.play_sfx("card_preview", 1.0, 0.0)
	if not hover_scale_enabled:
		return
	_hovered = true
	_apply_hover_transform()

func _on_mouse_exited() -> void:
	if hover_uses_slot_bounds:
		var parent = get_parent()
		if parent != null and parent.has_method("set_slot_hovered"):
			parent.set_slot_hovered(false)
		return
	if card != null:
		card_hover_changed.emit(self, false)
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

func _ratio_rect(rect_ratio: Rect2) -> Rect2:
	return _ratio_rect_for(size, rect_ratio)

func _ratio_rect_for(target_size: Vector2, rect_ratio: Rect2) -> Rect2:
	return Rect2(
		Vector2(target_size.x * rect_ratio.position.x, target_size.y * rect_ratio.position.y),
		Vector2(target_size.x * rect_ratio.size.x, target_size.y * rect_ratio.size.y)
	)

func _font_size(canvas_px: float, minimum: int = 6) -> int:
	return maxi(minimum, int(round(size.y * canvas_px / CARD_CANVAS_SIZE.y)))

func _font_size_for(target_size: Vector2, canvas_px: float, minimum: int = 6) -> int:
	return maxi(minimum, int(round(target_size.y * canvas_px / CARD_CANVAS_SIZE.y)))

func _apply_rect(node: Control, rect: Rect2) -> void:
	node.set_anchors_preset(Control.PRESET_TOP_LEFT)
	node.custom_minimum_size = Vector2.ZERO
	node.position = rect.position
	node.size = rect.size

func _center_label_in_region(label: Label, region: Control) -> void:
	if label == null or region == null:
		return
	var min_size := label.get_combined_minimum_size()
	var label_height := maxf(region.size.y, min_size.y)
	label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	label.position = Vector2(0.0, (region.size.y - label_height) * 0.5)
	label.size = Vector2(region.size.x, label_height)

func _apply_panel_shadow_style(panel: Panel, corner_radius: int, shadow_size: int, shadow_offset: Vector2, color: Color) -> void:
	if panel == null:
		return
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.01)
	style.border_color = Color(0.0, 0.0, 0.0, 0.0)
	style.set_corner_radius_all(corner_radius)
	style.shadow_color = color
	style.shadow_size = shadow_size
	style.shadow_offset = shadow_offset
	panel.add_theme_stylebox_override("panel", style)

func _fit_label_font_size(label: Label, base_canvas_px: float, minimum: int = 6, target_size: Vector2 = Vector2.ZERO) -> void:
	if label == null:
		return
	var base_size := _font_size(base_canvas_px, minimum)
	var fitting_size := target_size if target_size.x > 0.0 and target_size.y > 0.0 else label.size
	var fitted_size := _fit_text_font_size(label, base_size, minimum, fitting_size)
	label.add_theme_font_size_override("font_size", fitted_size)

func _fit_label_font_size_to_region_max(label: Label, minimum: int = 6, target_size: Vector2 = Vector2.ZERO) -> void:
	if label == null:
		return
	var fitting_size := target_size if target_size.x > 0.0 and target_size.y > 0.0 else label.size
	var max_candidate := maxi(minimum, int(ceil(fitting_size.y * 2.0)))
	var fitted_size := _fit_text_font_size(label, max_candidate, minimum, fitting_size)
	label.add_theme_font_size_override("font_size", fitted_size)

func _fit_text_font_size(label: Label, base_size: int, minimum: int, fitting_size: Vector2) -> int:
	var text := label.text.strip_edges()
	if text == "" or fitting_size.x <= 0.0 or fitting_size.y <= 0.0:
		return base_size
	var font := label.get_theme_font("font")
	if font == null:
		return base_size
	var max_width := fitting_size.x * 0.98
	var max_height := fitting_size.y * 0.98
	for font_size in range(base_size, minimum - 1, -1):
		var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
		var line_height := font.get_height(font_size)
		if text_size.x <= max_width and line_height <= max_height:
			return font_size
	return minimum

func _refresh_label_font_sizes(deck_size: Vector2 = Vector2.ZERO, card_name_size: Vector2 = Vector2.ZERO, series_size: Vector2 = Vector2.ZERO) -> void:
	_fit_label_font_size_to_region_max(_deck_name_label, 6, deck_size)
	_number_label.add_theme_font_size_override("font_size", _font_size(NUMBER_BADGE_FONT_CANVAS, 8))
	_fit_label_font_size(_card_name_label, CARD_NAME_FONT_CANVAS, 6, card_name_size)
	_description_label.add_theme_font_size_override("font_size", _font_size(DESCRIPTION_FONT_CANVAS, 6))
	_fit_label_font_size(_series_tag_label, SERIES_TAG_FONT_CANVAS, 5, series_size)

func _apply_card_layout() -> void:
	if _art_image == null or _art_shadow == null or _deck_name_region == null or _deck_name_label == null or _number_badge == null or _card_name_region == null or _card_name_label == null or _description_panel == null or _description_label == null or _series_tag_region == null or _series_tag_label == null:
		return

	if size.x <= 0 or size.y <= 0:
		size = CARD_SIZE
	if _card_shadow != null:
		_card_shadow.size = size

	var art_rect := _ratio_rect(ART_RECT_RATIO)
	_apply_rect(_art_shadow, art_rect)
	_apply_panel_shadow_style(
		_art_shadow,
		int(roundf(art_rect.size.x * ART_CORNER_RADIUS_RATIO)),
		maxi(4, int(roundf(art_rect.size.x * 0.055))),
		Vector2.ZERO,
		Color(0, 0, 0, 0.34)
	)
	_apply_rect(_art_image, art_rect)
	_art_image.material = null
	var deck_rect := _ratio_rect(DECK_NAME_RECT_RATIO)
	var badge_rect := _ratio_rect(NUMBER_BADGE_RECT_RATIO)
	var card_name_rect := _ratio_rect(CARD_NAME_RECT_RATIO)
	var series_rect := _ratio_rect(SERIES_TAG_RECT_RATIO)
	_apply_rect(_deck_name_region, deck_rect)
	_apply_rect(_number_badge, badge_rect)
	_apply_rect(_card_name_region, card_name_rect)
	var desc_rect := _ratio_rect(DESCRIPTION_RECT_RATIO)
	_apply_rect(_description_panel, desc_rect)
	_apply_rect(_description_label, desc_rect.grow(-maxf(2.0, size.x * 16.0 / FRAME_SOURCE_SIZE.x)))
	_apply_rect(_series_tag_region, series_rect)

	_refresh_label_font_sizes(deck_rect.size, card_name_rect.size, series_rect.size)
	_center_label_in_region(_deck_name_label, _deck_name_region)
	_center_label_in_region(_card_name_label, _card_name_region)
	_center_label_in_region(_series_tag_label, _series_tag_region)
	refresh_title_text_color()

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
	stop_draw_rarity_effect()
	stop_blue_draw_flip()
	card = c
	card_index = idx
	_update_display()

func clear() -> void:
	stop_draw_rarity_effect()
	stop_blue_draw_flip()
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
	_apply_title_text_color(CardColor.ColorType.WHITE)

func play_green_draw_shine(duration: float = GREEN_DRAW_SHINE_DURATION) -> void:
	if card != null and card.color == CardColor.ColorType.GREEN:
		_play_draw_shine(Color.WHITE, duration)

func play_blue_draw_shine(duration: float = BLUE_DRAW_SHINE_DURATION) -> void:
	if card != null and card.color == CardColor.ColorType.BLUE:
		_play_draw_shine(Color(0.31, 0.72, 1.0, 1.0), duration)

func _play_draw_shine(shine_color: Color, duration: float) -> void:
	stop_draw_rarity_effect()
	if _rarity_shine_overlay == null or _rarity_shine_material == null or get_tree() == null:
		return
	_rarity_shine_overlay.visible = true
	_rarity_shine_material.set_shader_parameter("progress", -0.20)
	_rarity_shine_material.set_shader_parameter("shine_color", shine_color)
	_rarity_shine_tween = create_tween()
	_rarity_shine_tween.tween_method(_set_green_draw_shine_progress, -0.20, 1.20, maxf(0.01, duration)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_rarity_shine_tween.finished.connect(func():
		_rarity_shine_tween = null
		if _rarity_shine_overlay != null:
			_rarity_shine_overlay.visible = false
	)

func stop_draw_rarity_effect() -> void:
	if _rarity_shine_tween != null and _rarity_shine_tween.is_valid():
		_rarity_shine_tween.kill()
	_rarity_shine_tween = null
	if _rarity_shine_material != null:
		_rarity_shine_material.set_shader_parameter("progress", -0.20)
	if _rarity_shine_overlay != null:
		_rarity_shine_overlay.visible = false

func is_green_draw_shine_playing() -> bool:
	return _rarity_shine_overlay != null and _rarity_shine_overlay.visible

func _set_green_draw_shine_progress(value: float) -> void:
	if _rarity_shine_material != null:
		_rarity_shine_material.set_shader_parameter("progress", value)

func _update_green_draw_shine_mask() -> void:
	if _rarity_shine_material == null:
		return
	var current_size := size if size.x > 0.0 and size.y > 0.0 else CARD_SIZE
	_rarity_shine_material.set_shader_parameter("aspect_ratio", current_size.x / maxf(current_size.y, 1.0))

## 蓝卡浮空翻转：背面只显示蓝色卡牌背景图，不显示插图或文字。
func begin_blue_draw_flip() -> void:
	if card == null or card.color != CardColor.ColorType.BLUE:
		return
	_set_blue_draw_back_visible(false)
	set_blue_draw_flip_progress(0.0)

func set_blue_draw_flip_progress(progress: float) -> void:
	if card == null or card.color != CardColor.ColorType.BLUE:
		return
	var clamped_progress := clampf(progress, 0.0, 1.0)
	_set_blue_draw_back_visible(clamped_progress >= 0.25 and clamped_progress < 0.75)
	var horizontal_scale := maxf(0.025, absf(cos(clamped_progress * TAU)))
	scale = Vector2(horizontal_scale, 1.0)

func finish_blue_draw_flip() -> void:
	_set_blue_draw_back_visible(false)
	scale = Vector2.ONE

func stop_blue_draw_flip() -> void:
	finish_blue_draw_flip()

func is_blue_draw_back_visible() -> bool:
	return _blue_draw_back != null and _blue_draw_back.visible

func _set_blue_draw_back_visible(visible: bool) -> void:
	if _blue_draw_back == null:
		return
	_blue_draw_back.visible = visible
	var front_visible := not visible
	if _color_border != null:
		_color_border.visible = front_visible and show_color_border and card != null
	if _fallback_color_rect != null:
		_fallback_color_rect.visible = false
	for node in [_art_shadow, _art_image, _deck_name_region, _number_badge, _card_name_region, _description_panel, _description_label, _series_tag_region, _color_bar]:
		if node != null:
			node.visible = front_visible
	if visible and _rarity_shine_overlay != null:
		_rarity_shine_overlay.visible = false

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
	_apply_title_text_color(card.color)
	_apply_card_layout()
	_apply_card_art(card)

	# 颜色条 + 边框
	if show_color_border:
		_apply_color_border(card.color)
	_color_bar.color = _get_color_by_card_color(card.color)

func _apply_card_art(card_info: CardInfo) -> void:
	_art_image.texture = null
	var explicit_path := _normalize_art_path(card_info.image_path)
	var explicit_tex = _load_art_texture_cached(explicit_path)
	if explicit_tex != null:
		_art_image.texture = explicit_tex
		return
	var card_id := int(card_info.id)
	if card_id <= 0:
		return
	var base: String = "card_%03d" % card_id
	for ext: String in [".jpg", ".png", ".webp", ".jpeg"]:
		var path: String = ART_PATH_PREFIX + base + ext
		var tex = _load_art_texture_cached(path)
		if tex != null:
			_art_image.texture = tex
			return

func get_art_texture() -> Texture2D:
	return _art_image.texture if _art_image != null else null

func get_art_rect() -> Rect2:
	return Rect2(_art_image.position, _art_image.size) if _art_image != null else Rect2()

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

func _load_art_texture_cached(path: String):
	if path == "":
		return null
	var art_size := _art_image.size if _art_image != null and _art_image.size.x > 0.0 and _art_image.size.y > 0.0 else _ratio_rect_for(CARD_SIZE, ART_RECT_RATIO).size
	var aspect := art_size.x / maxf(art_size.y, 1.0)
	var cache_key := "%s|%.4f" % [path, aspect]
	if _art_texture_cache.has(cache_key):
		return _art_texture_cache[cache_key]
	if not ResourceLoader.exists(path, "Texture2D"):
		return null
	var source_texture := ResourceLoader.load(path, "Texture2D") as Texture2D
	if source_texture == null:
		return null
	var rounded := _make_cropped_rounded_art_texture(source_texture, aspect)
	if rounded != null:
		_art_texture_cache[cache_key] = rounded
	return rounded

func _make_cropped_rounded_art_texture(source_texture: Texture2D, target_aspect: float) -> Texture2D:
	var image := source_texture.get_image()
	if image == null or image.is_empty():
		return null
	image.convert(Image.FORMAT_RGBA8)
	var source_size := image.get_size()
	if source_size.x <= 0 or source_size.y <= 0 or target_aspect <= 0.0:
		return null

	var crop_width := source_size.x
	var crop_height := int(round(float(crop_width) / target_aspect))
	if crop_height > source_size.y:
		crop_height = source_size.y
		crop_width = int(round(float(crop_height) * target_aspect))
	crop_width = clampi(crop_width, 1, source_size.x)
	crop_height = clampi(crop_height, 1, source_size.y)
	var crop_pos := Vector2i(
		int(floor(float(source_size.x - crop_width) * 0.5)),
		int(floor(float(source_size.y - crop_height) * 0.5))
	)
	var cropped := image.get_region(Rect2i(crop_pos, Vector2i(crop_width, crop_height)))
	_apply_rounded_alpha_to_image(cropped, int(round(float(crop_width) * ART_CORNER_RADIUS_RATIO)))
	return ImageTexture.create_from_image(cropped)

func _apply_rounded_alpha_to_image(image: Image, radius: int) -> void:
	var width := image.get_width()
	var height := image.get_height()
	if width <= 0 or height <= 0:
		return
	radius = clampi(radius, 1, mini(width, height) / 2)
	var radius_f := float(radius)
	for y in range(radius):
		for x in range(radius):
			var dx := radius_f - float(x) - 0.5
			var dy := radius_f - float(y) - 0.5
			if sqrt(dx * dx + dy * dy) <= radius_f:
				continue
			_set_alpha(image, x, y, 0.0)
			_set_alpha(image, width - 1 - x, y, 0.0)
			_set_alpha(image, x, height - 1 - y, 0.0)
			_set_alpha(image, width - 1 - x, height - 1 - y, 0.0)

func _set_alpha(image: Image, x: int, y: int, alpha: float) -> void:
	var pixel := image.get_pixel(x, y)
	pixel.a = alpha
	image.set_pixel(x, y, pixel)

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

func _get_title_text_color(c: CardColor.ColorType) -> Color:
	match c:
		CardColor.ColorType.GREEN: return CARD_TEXT_COLOR_GREEN
		CardColor.ColorType.BLUE: return CARD_TEXT_COLOR_BLUE
		CardColor.ColorType.PURPLE: return CARD_TEXT_COLOR_PURPLE
		CardColor.ColorType.ORANGE: return CARD_TEXT_COLOR_ORANGE
		CardColor.ColorType.BLACK: return CARD_TEXT_COLOR_BLACK
		CardColor.ColorType.RED: return CARD_TEXT_COLOR_RED
		_: return CARD_TEXT_COLOR

func _apply_title_text_color(c: CardColor.ColorType) -> void:
	if _deck_name_label == null or _card_name_label == null or _series_tag_label == null:
		return
	_active_title_text_color = _get_title_text_color(c)
	_deck_name_label.add_theme_color_override("font_color", _active_title_text_color)
	_card_name_label.add_theme_color_override("font_color", _active_title_text_color)
	_series_tag_label.add_theme_color_override("font_color", _active_title_text_color)

func refresh_title_text_color() -> void:
	if card == null:
		_apply_title_text_color(CardColor.ColorType.WHITE)
	else:
		_apply_title_text_color(card.color)

func set_selected(s: bool) -> void:
	is_selected = s


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
			last_click_button_index = mb.button_index
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

	var shadow := CCRVisualStyle.make_shadow_panel("DragPreviewShadow", int(roundf(CARD_SIZE.x * 0.08)), 18, Vector2(7, 10), CCRVisualStyle.CARD_SHADOW)
	shadow.position = Vector2.ZERO
	shadow.size = CARD_SIZE
	card_layer.add_child(shadow)

	# 背景 — 不设锚点，手动设 size
	var bg = ColorRect.new()
	bg.position = Vector2(0, 0)
	bg.size = CARD_SIZE
	bg.color = Color(0.2, 0.2, 0.25, 1.0)
	bg.material = _new_rounded_mask_material(CARD_SIZE)
	card_layer.add_child(bg)

	# 复制颜色卡框。当前卡框资源是完整 RGB 背景，不是透明挖空外框，
	# 因此必须位于插图下方，否则会遮住运行时插图。
	if _color_border.visible and _color_border.texture != null:
		var border = TextureRect.new()
		border.position = Vector2(0, 0)
		border.size = CARD_SIZE
		border.texture = _color_border.texture
		border.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		border.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		border.material = _new_rounded_mask_material(CARD_SIZE)
		border.modulate = Color(1, 1, 1, 1)
		card_layer.add_child(border)

	var title_text_color := _get_title_text_color(card.color if card != null else CardColor.ColorType.WHITE)

	if _art_image.texture != null:
		var art_rect := _ratio_rect_for(CARD_SIZE, ART_RECT_RATIO)
		var art_shadow := CCRVisualStyle.make_shadow_panel(
			"DragPreviewArtShadow",
			int(roundf(art_rect.size.x * ART_CORNER_RADIUS_RATIO)),
			maxi(4, int(roundf(art_rect.size.x * 0.055))),
			Vector2.ZERO,
			Color(0, 0, 0, 0.34)
		)
		art_shadow.position = art_rect.position
		art_shadow.size = art_rect.size
		card_layer.add_child(art_shadow)

		var art = TextureRect.new()
		art.position = art_rect.position
		art.size = art_rect.size
		art.texture = _art_image.texture
		art.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		art.stretch_mode = TextureRect.STRETCH_SCALE
		art.clip_contents = true
		art.material = null
		card_layer.add_child(art)

	# 复制卡组名
	var deck_rect := _ratio_rect_for(CARD_SIZE, DECK_NAME_RECT_RATIO)
	var deck_lbl = Label.new()
	deck_lbl.position = deck_rect.position
	deck_lbl.size = deck_rect.size
	deck_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	deck_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	deck_lbl.text = _deck_name_label.text
	var deck_font_candidate := maxi(6, int(ceil(deck_rect.size.y * 2.0)))
	deck_lbl.add_theme_font_size_override("font_size", _fit_text_font_size(deck_lbl, deck_font_candidate, 6, deck_rect.size))
	deck_lbl.add_theme_color_override("font_color", title_text_color)
	deck_lbl.clip_contents = true
	card_layer.add_child(deck_lbl)

	var badge_rect := _ratio_rect_for(CARD_SIZE, NUMBER_BADGE_RECT_RATIO)
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
	number_lbl.add_theme_font_size_override("font_size", _font_size_for(CARD_SIZE, NUMBER_BADGE_FONT_CANVAS, 8))
	number_lbl.add_theme_color_override("font_color", CARD_TEXT_COLOR)
	badge.add_child(number_lbl)

	# 复制卡名
	var name_rect := _ratio_rect_for(CARD_SIZE, CARD_NAME_RECT_RATIO)
	var name_lbl = Label.new()
	name_lbl.position = name_rect.position
	name_lbl.size = name_rect.size
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_lbl.text = _card_name_label.text
	name_lbl.add_theme_font_size_override("font_size", _font_size_for(CARD_SIZE, CARD_NAME_FONT_CANVAS, 6))
	name_lbl.add_theme_color_override("font_color", title_text_color)
	name_lbl.clip_contents = true
	card_layer.add_child(name_lbl)

	var desc_rect := _ratio_rect_for(CARD_SIZE, DESCRIPTION_RECT_RATIO)
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
	desc_lbl.add_theme_font_size_override("font_size", _font_size_for(CARD_SIZE, DESCRIPTION_FONT_CANVAS, 6))
	desc_lbl.add_theme_color_override("font_color", CARD_TEXT_COLOR)
	desc_lbl.clip_contents = true
	card_layer.add_child(desc_lbl)

	var series_rect := _ratio_rect_for(CARD_SIZE, SERIES_TAG_RECT_RATIO)
	var series_lbl = Label.new()
	series_lbl.position = series_rect.position
	series_lbl.size = series_rect.size
	series_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	series_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	series_lbl.text = _series_tag_label.text
	series_lbl.add_theme_font_size_override("font_size", _font_size_for(CARD_SIZE, SERIES_TAG_FONT_CANVAS, 5))
	series_lbl.add_theme_color_override("font_color", title_text_color)
	series_lbl.clip_contents = true
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
