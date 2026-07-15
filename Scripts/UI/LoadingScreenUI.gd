extends Control
class_name LoadingScreenUI

const BASE_SIZE := Vector2(2560.0, 1600.0)
const SMALL_SCREEN_MAX_WIDTH := 1400.0
const LOADING_TEXT_COLOR := Color.WHITE

var _background_image: TextureRect = null
var _bottom_gradient: ColorRect = null
var _loading_panel: PanelContainer = null
var _margin: MarginContainer = null
var _tip_category_label: Label = null
var _tip_title_label: Label = null
var _tip_body_label: Label = null
var _tip_short_label: Label = null
var _progress_text_label: Label = null
var _progress_bar: ProgressBar = null
var _version_label: Label = null
var _server_status_label: Label = null
var _progress_tween: Tween = null
var _tip_tween: Tween = null
var _panel_tween: Tween = null
var _setup_done := false
var _tip_initialized := false

func _ready() -> void:
	_setup_ui()
	apply_fullscreen_layout()
	get_viewport().size_changed.connect(apply_fullscreen_layout)
	_fade_panel_in()

func set_background(texture: Texture2D) -> void:
	if _background_image == null:
		_setup_ui()
	_background_image.texture = texture

func set_tip(category: String, title: String, body: String, short_tip: String = "") -> void:
	if _tip_title_label == null:
		_setup_ui()
	if _tip_initialized:
		return
	_tip_initialized = true
	if _tip_tween != null:
		_tip_tween.kill()
	_tip_category_label.text = category.to_upper()
	_tip_title_label.text = title
	_tip_body_label.text = body
	_tip_short_label.text = "短提示 · " + short_tip if not short_tip.is_empty() else ""
	_tip_tween = create_tween()
	_tip_tween.tween_property(_loading_panel, "modulate:a", 0.72, 0.12)
	_tip_tween.tween_property(_loading_panel, "modulate:a", 1.0, 0.18)

func set_progress(value: float, status_text: String) -> void:
	if _progress_bar == null:
		_setup_ui()
	var next_value := clampf(value, 0.0, 100.0)
	if _progress_tween != null:
		_progress_tween.kill()
	_progress_tween = create_tween()
	_progress_tween.tween_property(_progress_bar, "value", next_value, 0.24).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_progress_text_label.text = status_text
	_progress_text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

func set_server_status(text: String) -> void:
	if _server_status_label == null:
		_setup_ui()
	_server_status_label.text = text

func set_version(text: String) -> void:
	if _version_label == null:
		_setup_ui()
	_version_label.text = text

func _setup_ui() -> void:
	if _setup_done:
		return
	_setup_done = true
	_force_full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_STOP

	_background_image = TextureRect.new()
	_background_image.name = "BackgroundImage"
	_force_full_rect(_background_image)
	_background_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_background_image.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(_background_image)

	_bottom_gradient = ColorRect.new()
	_bottom_gradient.name = "BottomGradient"
	_bottom_gradient.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bottom_gradient.material = _make_bottom_gradient_material()
	add_child(_bottom_gradient)

	_loading_panel = PanelContainer.new()
	_loading_panel.name = "LoadingPanel"
	_loading_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_loading_panel.add_theme_stylebox_override("panel", _make_panel_style())
	add_child(_loading_panel)

	_margin = MarginContainer.new()
	_margin.name = "PanelMargin"
	_loading_panel.add_child(_margin)

	var vbox := VBoxContainer.new()
	vbox.name = "LoadingContent"
	vbox.add_theme_constant_override("separation", 14)
	_margin.add_child(vbox)

	_tip_category_label = _make_label("TipCategoryLabel", LOADING_TEXT_COLOR, 20)
	# 载入提示只展示标题、正文、短提示三层；分类字段只保留为数据元信息。
	_tip_category_label.visible = false
	vbox.add_child(_tip_category_label)

	_tip_title_label = _make_label("TipTitleLabel", LOADING_TEXT_COLOR, 34)
	_tip_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip_title_label.custom_minimum_size = Vector2(0, 44)
	vbox.add_child(_tip_title_label)

	_tip_body_label = _make_label("TipBodyLabel", LOADING_TEXT_COLOR, 24)
	_tip_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip_body_label.custom_minimum_size = Vector2(0, 76)
	vbox.add_child(_tip_body_label)

	_tip_short_label = _make_label("TipShortLabel", LOADING_TEXT_COLOR, 18)
	_tip_short_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip_short_label.custom_minimum_size = Vector2(0, 38)
	vbox.add_child(_tip_short_label)

	var bottom_right := VBoxContainer.new()
	bottom_right.name = "BottomRightInfo"
	bottom_right.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	bottom_right.offset_left = -390
	bottom_right.offset_top = -96
	bottom_right.offset_right = -32
	bottom_right.offset_bottom = -24
	bottom_right.alignment = BoxContainer.ALIGNMENT_END
	bottom_right.add_theme_constant_override("separation", 6)
	bottom_right.custom_minimum_size = Vector2(358, 0)
	bottom_right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bottom_right)

	_server_status_label = _make_label("ServerStatusLabel", LOADING_TEXT_COLOR, 17)
	_server_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_server_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bottom_right.add_child(_server_status_label)

	_progress_text_label = _make_label("ProgressTextLabel", LOADING_TEXT_COLOR, 20)
	_progress_text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_progress_text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bottom_right.add_child(_progress_text_label)

	_progress_bar = ProgressBar.new()
	_progress_bar.name = "LoadingProgressBar"
	_progress_bar.min_value = 0.0
	_progress_bar.max_value = 100.0
	_progress_bar.value = 0.0
	_progress_bar.show_percentage = false
	_progress_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_progress_bar.custom_minimum_size = Vector2(220, 8)
	_progress_bar.add_theme_stylebox_override("background", _make_progress_style(Color(0.102, 0.141, 0.200, 1.0)))
	_progress_bar.add_theme_stylebox_override("fill", _make_progress_style(Color(0.788, 0.706, 0.478, 1.0)))
	bottom_right.add_child(_progress_bar)

	_version_label = _make_label("VersionLabel", LOADING_TEXT_COLOR, 17)
	_version_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bottom_right.add_child(_version_label)

func apply_fullscreen_layout() -> void:
	_force_full_rect(self)
	if _background_image != null:
		_force_full_rect(_background_image)
	_apply_responsive_layout()

func _apply_responsive_layout() -> void:
	if _loading_panel == null:
		return
	var vp_size := _viewport_size()
	_bottom_gradient.anchor_left = 0.0
	_bottom_gradient.anchor_right = 1.0
	_bottom_gradient.anchor_top = 0.62
	_bottom_gradient.anchor_bottom = 1.0
	_bottom_gradient.offset_left = 0.0
	_bottom_gradient.offset_right = 0.0
	_bottom_gradient.offset_top = 0.0
	_bottom_gradient.offset_bottom = 0.0

	var small := vp_size.x <= SMALL_SCREEN_MAX_WIDTH or vp_size.y <= 850.0
	_loading_panel.anchor_left = 0.14 if small else 0.24
	_loading_panel.anchor_top = 0.45 if small else 0.56
	_loading_panel.anchor_right = 0.86 if small else 0.76
	_loading_panel.anchor_bottom = 0.84 if small else 0.88
	_loading_panel.offset_left = 0.0
	_loading_panel.offset_top = 0.0
	_loading_panel.offset_right = 0.0
	_loading_panel.offset_bottom = 0.0

	var scale := clampf(minf(vp_size.x / BASE_SIZE.x, vp_size.y / BASE_SIZE.y), 0.52, 1.0)
	var padding := int(roundf(48.0 * scale))
	_margin.add_theme_constant_override("margin_left", padding)
	_margin.add_theme_constant_override("margin_top", padding)
	_margin.add_theme_constant_override("margin_right", padding)
	_margin.add_theme_constant_override("margin_bottom", padding)

	_tip_category_label.add_theme_font_size_override("font_size", maxi(13, int(roundf(20.0 * scale))))
	_tip_title_label.add_theme_font_size_override("font_size", maxi(22, int(roundf(34.0 * scale))))
	_tip_body_label.add_theme_font_size_override("font_size", maxi(16, int(roundf(24.0 * scale))))
	_tip_short_label.add_theme_font_size_override("font_size", maxi(14, int(roundf(18.0 * scale))))
	_progress_text_label.add_theme_font_size_override("font_size", maxi(13, int(roundf(20.0 * scale))))
	_server_status_label.add_theme_font_size_override("font_size", maxi(12, int(roundf(17.0 * scale))))
	_version_label.add_theme_font_size_override("font_size", maxi(12, int(roundf(17.0 * scale))))

func _force_full_rect(control: Control) -> void:
	if control == null:
		return
	control.set_anchors_preset(Control.PRESET_TOP_LEFT)
	control.offset_left = 0.0
	control.offset_top = 0.0
	control.position = Vector2.ZERO
	control.size = _viewport_size()

func _viewport_size() -> Vector2:
	var vp_size := get_viewport_rect().size
	if vp_size.x <= 0.0 or vp_size.y <= 0.0:
		return DisplayServer.window_get_size()
	return vp_size

func _fade_panel_in() -> void:
	if _loading_panel == null:
		return
	_loading_panel.modulate.a = 0.0
	if _panel_tween != null:
		_panel_tween.kill()
	_panel_tween = create_tween()
	_panel_tween.tween_property(_loading_panel, "modulate:a", 1.0, 0.32).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _make_label(node_name: String, color: Color, font_size: int) -> Label:
	var label := Label.new()
	label.name = node_name
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", font_size)
	label.clip_text = false
	return label

func _make_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.027, 0.067, 0.122, 0.52)
	style.border_color = Color(0.851, 0.867, 0.898, 0.24)
	style.set_border_width_all(1)
	style.set_corner_radius_all(20)
	return style

func _make_progress_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(4)
	return style

func _make_bottom_gradient_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;

void fragment() {
	float alpha = smoothstep(0.0, 1.0, UV.y) * 0.78;
	COLOR = vec4(0.012, 0.028, 0.058, alpha);
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	return material
