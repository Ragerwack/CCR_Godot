extends Control
class_name DeckCollectionUI

signal filter_controls_rect_changed(rect: Rect2)

const CCRVisualStyle = preload("res://Scripts/UI/CCRVisualStyle.gd")
const CCRLinkedVerticalScrollBarScript = preload("res://Scripts/UI/CCRLinkedVerticalScrollBar.gd")

# 博物馆 — 展示所有已合成圣物

const RELICS_PER_ROW: int = 5
const RELIC_TARGET_MIN_ITEMS_PER_ROW: int = 6
const CARD_WIDTH: float = 150.0
const CARD_HEIGHT: float = 200.0
const CARD_SPACING: float = 24.0
const CARD_HORIZONTAL_SPACING: float = 4.0
const SECTION_SPACING: float = 20.0
const HEADER_HEIGHT: float = 32.0
const FILTER_BAR_TOP: float = 12.0
const FILTER_BAR_HEIGHT: float = 56.0
const FILTER_FONT_SIZE: int = 17
const FILTER_CONTROL_FONT_SIZE: int = FILTER_FONT_SIZE
const FILTER_CONTROL_HEIGHT: float = 56.0
const FILTER_OPTION_VISUAL_HEIGHT: int = 49
const FILTER_RARITY_ICON_HEIGHT: int = 48
const FILTER_BAR_GAP: int = 10
const FILTER_PROGRESS_WIDTH: float = 220.0
const FILTER_OPTION_WIDTH: float = 317.0
const MUSEUM_SCROLLBAR_RESOURCE_ICON_HALF_WIDTH: float = 11.0
const TODAY_DECK_KEY_ROW_HEIGHT: float = 26.0
const TODAY_DECK_INFO_ROW_HEIGHT: float = 26.0
const TODAY_DECK_CARD_ROW_SEPARATOR: float = 4.0
const TODAY_DECK_SCROLL_BOTTOM_MARGIN: float = 18.0
const VISUAL_RELIC_LABEL_HEIGHT: float = 72.0
const RELIC_SCALE_MULTIPLIER: float = 1.30
const RELIC_SCREEN_HEIGHT_RATIO: float = (3.0 / 5.0) * RELIC_SCALE_MULTIPLIER
const MUSEUM_TEXT_DARK: Color = Color(0.10, 0.085, 0.065, 0.96)
const MUSEUM_TEXT_MUTED: Color = Color(0.19, 0.16, 0.12, 0.88)
const MUSEUM_RARITY_CHECK_TEXT: Color = Color(0.03, 0.025, 0.018, 1.0)
const RELIC_VIEW_SCENE = preload("res://Scenes/UI/RelicView.tscn")
const THUMBNAIL_CACHE = preload("res://Scripts/UI/MuseumRelicThumbnailCache.gd")
const CardDisplayScript = preload("res://Scripts/UI/CardDisplay.gd")
const VIEW_RELIC_MOVE_SECONDS: float = 0.5
const VIEW_CARD_INTERVAL_SECONDS: float = 0.2
const VIEW_CARD_MOVE_SECONDS: float = 0.5
const TODAY_VISIBLE_SERIES_FILTER: String = "__today_visible_decks__"
const VIEW_BLUR_SHADER_CODE: String = """
shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform float blur_radius = 4.0;
uniform vec4 tint : source_color = vec4(0.03, 0.04, 0.06, 0.42);

void fragment() {
	vec2 pixel = SCREEN_PIXEL_SIZE * blur_radius;
	vec4 color = texture(screen_texture, SCREEN_UV) * 0.20;
	color += texture(screen_texture, SCREEN_UV + vec2(pixel.x, 0.0)) * 0.12;
	color += texture(screen_texture, SCREEN_UV - vec2(pixel.x, 0.0)) * 0.12;
	color += texture(screen_texture, SCREEN_UV + vec2(0.0, pixel.y)) * 0.12;
	color += texture(screen_texture, SCREEN_UV - vec2(0.0, pixel.y)) * 0.12;
	color += texture(screen_texture, SCREEN_UV + vec2(pixel.x, pixel.y)) * 0.08;
	color += texture(screen_texture, SCREEN_UV + vec2(-pixel.x, pixel.y)) * 0.08;
	color += texture(screen_texture, SCREEN_UV + vec2(pixel.x, -pixel.y)) * 0.08;
	color += texture(screen_texture, SCREEN_UV + vec2(-pixel.x, -pixel.y)) * 0.08;
	COLOR = mix(color, tint, tint.a);
}
"""

# 稀有度排序顺序（从高到低）
const COLOR_ORDER: Array[int] = [
	6,
	5,
	4,
	3,
	2,
	1,
	0,
]

var _scroll_container: ScrollContainer = null
var _vertical_scrollbar: VScrollBar = null
var _content: VBoxContainer = null
var _empty_label: Label = null
var _filter_bar: HBoxContainer = null
var _color_filter_row: HBoxContainer = null
var _color_filter_checks: Dictionary = {}
var _sort_option: OptionButton = null
var _series_option: OptionButton = null
var _collection_progress_label: LineEdit = null
var _last_render_viewport_height: float = 0.0
var _resize_render_queued: bool = false
var _filter_geometry_emit_queued: bool = false
var _view_overlay: Control = null
var _view_blur: ColorRect = null
var _view_relic: TextureRect = null
var _view_relic_shadow: TextureRect = null
var _view_source_card: Control = null
var _view_source_card_modulate: Color = Color.WHITE
var _view_source_relic_key: String = ""
var _view_card_displays: Array[CardDisplay] = []
var _view_cards: Array = []
var _view_color: int = CardColor.ColorType.WHITE
var _view_source_rect: Rect2 = Rect2()
var _view_state: int = 0
var _view_busy: bool = false
var _view_cancel_requested: bool = false
var _selected_colors: Dictionary = {}
var _available_colors: Array[int] = []
var _selected_series: String = TODAY_VISIBLE_SERIES_FILTER
var _sort_mode: String = "standard"
var _top_padding: float = FILTER_BAR_TOP
var _session_scroll_vertical: int = 0
var _restore_scroll_pending: bool = false

static var _session_filter_state: Dictionary = {}

enum ViewState {
	NONE,
	RELIC_CENTERED,
	CARDS_VISIBLE,
	CARDS_HIDDEN,
}

func _ready() -> void:
	setup_ui()
	_restore_session_filter_state()
	render_decks()
	if not Localization.locale_changed.is_connected(_on_locale_changed):
		Localization.locale_changed.connect(_on_locale_changed)

func _on_locale_changed(_locale: String) -> void:
	if not is_inside_tree():
		return
	# 当前筛选值历史上保存的是显示文本；语言切换后旧语言名称不能
	# 再作为新语言的筛选条件，清除具体系列并保留“今日可见”语义。
	if _selected_series != TODAY_VISIBLE_SERIES_FILTER:
		_selected_series = ""
	if _empty_label != null:
		_empty_label.text = Localization.t("ui.deck_collection.empty")
	render_decks()

func configure_layout(top_padding: float) -> void:
	_top_padding = maxf(0.0, top_padding)
	if is_node_ready():
		_apply_shell_layout()

func _notification(what: int) -> void:
	if what != NOTIFICATION_RESIZED or not is_node_ready() or _content == null:
		return
	_layout_empty_label()
	_queue_filter_controls_rect_changed()
	var viewport_height := get_viewport_rect().size.y
	if absf(viewport_height - _last_render_viewport_height) <= 1.0 or _resize_render_queued:
		_layout_vertical_scrollbar()
		return
	_resize_render_queued = true
	call_deferred("_rerender_after_viewport_resize")

func _rerender_after_viewport_resize() -> void:
	_resize_render_queued = false
	if is_inside_tree():
		render_decks()

func setup_ui() -> void:
	_create_filter_bar()

	# 空状态提示（初始隐藏）
	_empty_label = Label.new()
	_empty_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_empty_label.size = Vector2(520, 40)
	_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_empty_label.text = Localization.t("ui.deck_collection.empty")
	_empty_label.add_theme_font_size_override("font_size", 16)
	_empty_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1.0))
	_empty_label.visible = false
	_empty_label.name = "MuseumEmpty"
	add_child(_empty_label)
	_layout_empty_label()

	# 滚动容器
	_scroll_container = ScrollContainer.new()
	_scroll_container.name = "DeckCollectionScroll"
	_scroll_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scroll_container.offset_top = _top_padding + FILTER_BAR_HEIGHT + 8.0
	_scroll_container.offset_bottom = 0
	_scroll_container.offset_left = 0
	_scroll_container.offset_right = -_scrollbar_reserved_width()
	add_child(_scroll_container)

	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.custom_minimum_size = Vector2(_content_width(), 0.0)
	_content.add_theme_constant_override("separation", SECTION_SPACING)
	_scroll_container.add_child(_content)

	_vertical_scrollbar = CCRLinkedVerticalScrollBarScript.new() as VScrollBar
	_vertical_scrollbar.name = "MuseumVerticalScrollbar"
	_vertical_scrollbar.z_index = 8
	add_child(_vertical_scrollbar)
	_vertical_scrollbar.call("bind_scroll_container", _scroll_container)
	_layout_vertical_scrollbar()

func _create_filter_bar() -> void:
	_filter_bar = HBoxContainer.new()
	_filter_bar.name = "MuseumFilterBar"
	_filter_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_filter_bar.offset_left = 0
	_filter_bar.offset_right = -_scrollbar_reserved_width()
	_filter_bar.offset_top = _top_padding
	_filter_bar.offset_bottom = _top_padding + FILTER_BAR_HEIGHT
	_filter_bar.add_theme_constant_override("separation", FILTER_BAR_GAP)
	_filter_bar.alignment = BoxContainer.ALIGNMENT_BEGIN
	_filter_bar.resized.connect(_queue_filter_controls_rect_changed)
	add_child(_filter_bar)

	_collection_progress_label = LineEdit.new()
	_collection_progress_label.name = "MuseumCollectionProgress"
	_collection_progress_label.editable = false
	_collection_progress_label.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_collection_progress_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_collection_progress_label.custom_minimum_size = Vector2(FILTER_PROGRESS_WIDTH, FILTER_CONTROL_HEIGHT)
	_collection_progress_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_collection_progress_label.add_theme_font_size_override("font_size", FILTER_FONT_SIZE)
	CCRVisualStyle.apply_settings_line_edit(_collection_progress_label)
	CCRVisualStyle.apply_settings_line_edit_height(_collection_progress_label, int(FILTER_CONTROL_HEIGHT))
	_apply_collection_progress_text_color()
	_filter_bar.add_child(_collection_progress_label)

	_series_option = OptionButton.new()
	_series_option.name = "MuseumSeriesOption"
	_series_option.item_selected.connect(_on_series_selected)
	_series_option.add_theme_font_size_override("font_size", FILTER_CONTROL_FONT_SIZE)
	CCRVisualStyle.apply_settings_option_button(_series_option)
	_configure_filter_option_button(_series_option)
	_filter_bar.add_child(_series_option)

	_color_filter_row = HBoxContainer.new()
	_color_filter_row.name = "MuseumColorFilter"
	_color_filter_row.alignment = BoxContainer.ALIGNMENT_BEGIN
	_color_filter_row.custom_minimum_size.y = FILTER_CONTROL_HEIGHT
	_color_filter_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_color_filter_row.add_theme_constant_override("separation", 6)
	_color_filter_row.minimum_size_changed.connect(_queue_filter_controls_rect_changed)
	_filter_bar.add_child(_color_filter_row)

	_sort_option = OptionButton.new()
	_sort_option.name = "MuseumSortOption"
	_sort_option.add_item(Localization.t("ui.deck_collection.sort.recent"))
	_sort_option.set_item_metadata(0, "recent")
	_sort_option.add_item(Localization.t("ui.deck_collection.sort.oldest"))
	_sort_option.set_item_metadata(1, "oldest")
	_sort_option.add_item(Localization.t("ui.deck_collection.sort.standard"))
	_sort_option.set_item_metadata(2, "standard")
	_sort_option.select(2)
	_sort_option.item_selected.connect(_on_sort_selected)
	_sort_option.add_theme_font_size_override("font_size", FILTER_CONTROL_FONT_SIZE)
	CCRVisualStyle.apply_settings_option_button(_sort_option)
	_configure_filter_option_button(_sort_option)
	_filter_bar.add_child(_sort_option)

func _configure_filter_option_button(option: OptionButton) -> void:
	if option == null:
		return
	var control_size := Vector2i(int(roundf(FILTER_OPTION_WIDTH)), int(roundf(FILTER_CONTROL_HEIGHT)))
	CCRVisualStyle.apply_settings_option_button_geometry(option, control_size, FILTER_OPTION_VISUAL_HEIGHT)
	option.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	option.get_popup().add_theme_font_size_override("font_size", FILTER_CONTROL_FONT_SIZE)
	option.resized.connect(_queue_filter_controls_rect_changed)

func get_filter_controls_global_rect() -> Rect2:
	if _collection_progress_label == null or _sort_option == null or not _collection_progress_label.is_inside_tree() or not _sort_option.is_inside_tree():
		return Rect2()
	var first_rect := _collection_progress_label.get_global_rect()
	var last_rect := _sort_option.get_global_rect()
	return Rect2(first_rect.position, last_rect.end - first_rect.position)

func _queue_filter_controls_rect_changed() -> void:
	if _filter_geometry_emit_queued or not is_inside_tree():
		return
	_filter_geometry_emit_queued = true
	_emit_filter_controls_rect_changed.call_deferred()

func _emit_filter_controls_rect_changed() -> void:
	await get_tree().process_frame
	_filter_geometry_emit_queued = false
	if not is_inside_tree():
		return
	var rect := get_filter_controls_global_rect()
	if rect.size.x > 0.0:
		filter_controls_rect_changed.emit(rect)

func _filter_cell(child: Control, align: HorizontalAlignment, min_width: float, expand: bool = false) -> Control:
	var cell := Control.new()
	cell.custom_minimum_size = Vector2(min_width, FILTER_BAR_HEIGHT)
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL if expand else Control.SIZE_SHRINK_CENTER
	child.set_anchors_preset(Control.PRESET_TOP_LEFT)
	child.custom_minimum_size = Vector2(maxf(child.custom_minimum_size.x, min_width), FILTER_BAR_HEIGHT)
	child.size = child.custom_minimum_size
	child.position = Vector2.ZERO
	cell.add_child(child)
	cell.resized.connect(func():
		var child_width := maxf(child.custom_minimum_size.x, min_width)
		if expand:
			child_width = maxf(child_width, cell.size.x)
		else:
			child_width = minf(child_width, cell.size.x)
		child.size = Vector2(child_width, FILTER_BAR_HEIGHT)
		match align:
			HORIZONTAL_ALIGNMENT_RIGHT:
				child.position = Vector2(cell.size.x - child_width, 0.0)
			HORIZONTAL_ALIGNMENT_CENTER:
				child.position = Vector2((cell.size.x - child_width) * 0.5, 0.0)
			_:
				child.position = Vector2(0.0, 0.0)
	)
	return cell

func _apply_shell_layout() -> void:
	if _filter_bar != null:
		_filter_bar.offset_top = _top_padding
		_filter_bar.offset_bottom = _top_padding + FILTER_BAR_HEIGHT
		_filter_bar.offset_right = -_scrollbar_reserved_width()
	if _scroll_container != null:
		_scroll_container.offset_top = _top_padding + FILTER_BAR_HEIGHT + 8.0
		_scroll_container.offset_right = -_scrollbar_reserved_width()
	_layout_empty_label()
	_layout_vertical_scrollbar()

func _layout_empty_label() -> void:
	if _empty_label == null:
		return
	var viewport_size := get_viewport_rect().size
	var center_global: Vector2 = viewport_size * 0.5
	var center_local: Vector2 = center_global - global_position if is_inside_tree() else size * 0.5
	_empty_label.position = center_local - _empty_label.size * 0.5

func _layout_vertical_scrollbar() -> void:
	if _vertical_scrollbar == null:
		return
	var first_card_top := _today_deck_first_card_top()
	var last_card_bottom := _today_deck_last_card_bottom()
	var protected_caps_height := float(CCRVisualStyle.SETTINGS_VERTICAL_SCROLLBAR_TRACK_END_MARGIN * 2)
	var scrollbar_height := maxf(protected_caps_height, last_card_bottom - first_card_top)
	var scrollbar_size := Vector2(CCRLinkedVerticalScrollBarScript.CONTROL_SIZE.x, scrollbar_height)
	_vertical_scrollbar.size = scrollbar_size
	_vertical_scrollbar.custom_minimum_size = scrollbar_size
	var scrollbar_x := maxf(0.0, size.x - scrollbar_size.x - MUSEUM_SCROLLBAR_RESOURCE_ICON_HALF_WIDTH)
	_vertical_scrollbar.position = Vector2(scrollbar_x, first_card_top)

func _today_deck_first_card_top() -> float:
	var scroll_top := _top_padding + TODAY_DECK_KEY_ROW_HEIGHT + 10.0
	return scroll_top + TODAY_DECK_INFO_ROW_HEIGHT + TODAY_DECK_CARD_ROW_SEPARATOR

func _today_deck_last_card_bottom() -> float:
	var scroll_top := _top_padding + TODAY_DECK_KEY_ROW_HEIGHT + 10.0
	var scroll_bottom := maxf(scroll_top, size.y - TODAY_DECK_SCROLL_BOTTOM_MARGIN)
	return scroll_bottom - _today_deck_card_shadow_bottom_bleed()

func _today_deck_card_shadow_bottom_bleed() -> float:
	return float(CardDisplay.CARD_SHADOW_SIZE) + maxf(0.0, CardDisplay.CARD_SHADOW_OFFSET.y)

func _content_width() -> float:
	return maxf(0.0, size.x - _scrollbar_reserved_width())

func _scrollbar_reserved_width() -> float:
	return CCRLinkedVerticalScrollBarScript.CONTROL_SIZE.x + MUSEUM_SCROLLBAR_RESOURCE_ICON_HALF_WIDTH

func render_decks() -> void:
	_last_render_viewport_height = get_viewport_rect().size.y
	var render_started := Time.get_ticks_msec()
	FileLogger.perf("ui_render_start", {"page": "deck_panel", "component": "deck_grid"})
	_capture_scroll_vertical()
	if _content != null:
		_content.custom_minimum_size.x = _content_width()
	_layout_vertical_scrollbar()
	# 清空内容
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()

	var all_decks = DeckSystem.get_player_decks()
	if all_decks.is_empty():
		_empty_label.visible = true
		if _scroll_container:
			_scroll_container.visible = false
		FileLogger.perf("ui_render_done", {"page": "deck_panel", "component": "deck_grid", "count": 0, "total_ms": Time.get_ticks_msec() - render_started})
		return

	_empty_label.visible = false
	if _scroll_container:
		_scroll_container.visible = true

	var relics := _aggregate_relics(all_decks)
	_update_filter_options(relics)
	relics = _apply_color_filter(_apply_series_filter(relics))
	_update_collection_progress(relics)
	_sort_relic_list(relics)
	if relics.is_empty():
		_empty_label.visible = true
		if _scroll_container:
			_scroll_container.visible = false
		FileLogger.perf("ui_render_done", {"page": "deck_panel", "component": "relic_grid", "count": all_decks.size(), "display_count": 0, "total_ms": Time.get_ticks_msec() - render_started})
		return

	_empty_label.visible = false
	if _scroll_container:
		_scroll_container.visible = true

	# 以单一五列网格展示全部圣物。颜色仍可通过筛选器筛选，避免按颜色分组后
	# 每组只有一件时退化成“一行一个”的展示。
	_content.add_child(_create_card_grid(relics))
	_schedule_scroll_restore()
	FileLogger.perf("ui_render_done", {"page": "deck_panel", "component": "relic_grid", "count": all_decks.size(), "display_count": relics.size(), "total_ms": Time.get_ticks_msec() - render_started})

func get_session_scroll_vertical() -> int:
	if _scroll_container != null:
		return _scroll_container.scroll_vertical
	return _session_scroll_vertical

func set_session_scroll_vertical(value: int) -> void:
	_session_scroll_vertical = maxi(0, value)
	_schedule_scroll_restore()

func _capture_scroll_vertical() -> void:
	if _scroll_container == null or _restore_scroll_pending:
		return
	_session_scroll_vertical = _scroll_container.scroll_vertical

func _schedule_scroll_restore() -> void:
	if _scroll_container == null or _restore_scroll_pending:
		return
	_restore_scroll_pending = true
	_restore_session_scroll_vertical.call_deferred()

func _restore_session_scroll_vertical() -> void:
	if not is_inside_tree():
		_restore_scroll_pending = false
		return
	await get_tree().process_frame
	if is_instance_valid(_scroll_container):
		_scroll_container.scroll_vertical = _session_scroll_vertical
	_restore_scroll_pending = false

func _aggregate_relics(decks: Array[Deck]) -> Array[Dictionary]:
	var by_key: Dictionary = {}
	for source_index in range(decks.size()):
		var d := decks[source_index]
		var key := "%s|%s|%d" % [d.series_name, d.deck_name, int(d.color)]
		if not by_key.has(key):
			by_key[key] = {
				"id": d.id,
				"deck_def_id": d.deck_def_id,
				"deck_def_key": d.deck_def_key,
				"deck_asset_id": d.deck_asset_id,
				"series_asset_id": d.series_asset_id,
				"series_name": d.series_name,
				"deck_name": d.deck_name,
				"color": int(d.color),
				"count": 0,
				"combat_power": d.combat_power,
				"first_index": source_index,
				"last_index": source_index,
			}
		by_key[key]["count"] = int(by_key[key]["count"]) + 1
		by_key[key]["combat_power"] = max(int(by_key[key]["combat_power"]), d.combat_power)
		by_key[key]["first_index"] = mini(int(by_key[key]["first_index"]), source_index)
		by_key[key]["last_index"] = maxi(int(by_key[key]["last_index"]), source_index)

	var relics: Array[Dictionary] = []
	for key in by_key.keys():
		relics.append(by_key[key])
	return relics

func _update_filter_options(relics: Array[Dictionary]) -> void:
	_update_series_filter_options(relics)
	_update_color_filter_options(_apply_series_filter(relics))

func _update_color_filter_options(relics: Array[Dictionary]) -> void:
	var color_set: Dictionary = {}
	for relic in relics:
		color_set[int(relic.get("color", CardColor.ColorType.WHITE))] = true
	var colors: Array[int] = []
	for color_type in COLOR_ORDER:
		if color_set.has(color_type):
			colors.append(color_type)
	_available_colors = colors
	for key in _selected_colors.keys():
		if not color_set.has(int(key)):
			_selected_colors.erase(key)
	for color_type in colors:
		if not _selected_colors.has(color_type):
			_selected_colors[color_type] = true

	_rebuild_color_filter_checks(colors)
	for color_type in colors:
		var check_box := _color_filter_checks.get(color_type) as CheckBox
		if check_box != null:
			check_box.set_pressed_no_signal(bool(_selected_colors.get(color_type, true)))

func _rebuild_color_filter_checks(colors: Array[int]) -> void:
	if _color_filter_row == null:
		return
	var wanted: Dictionary = {}
	for color_type in colors:
		wanted[color_type] = true
	for color_type in _color_filter_checks.keys():
		if wanted.has(int(color_type)):
			continue
		var stale_check := _color_filter_checks[color_type] as CheckBox
		if stale_check != null and is_instance_valid(stale_check):
			_color_filter_row.remove_child(stale_check)
			stale_check.queue_free()
		_color_filter_checks.erase(color_type)
	for color_type in colors:
		var check_box := _color_filter_checks.get(color_type) as CheckBox
		if check_box == null:
			check_box = CheckBox.new()
			check_box.name = "MuseumColorFilter%d" % color_type
			check_box.text = _museum_relic_tier_name(color_type)
			check_box.button_pressed = bool(_selected_colors.get(color_type, true))
			check_box.custom_minimum_size = Vector2(0.0, FILTER_CONTROL_HEIGHT)
			check_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			check_box.add_theme_font_size_override("font_size", FILTER_CONTROL_FONT_SIZE)
			CCRVisualStyle.apply_settings_check_box(check_box)
			CCRVisualStyle.apply_settings_check_box_icon_size(check_box, FILTER_RARITY_ICON_HEIGHT)
			_apply_museum_rarity_check_text_color(check_box)
			check_box.toggled.connect(_on_color_filter_toggled.bind(color_type))
			_color_filter_checks[color_type] = check_box
			_color_filter_row.add_child(check_box)
		_color_filter_row.move_child(check_box, colors.find(color_type))
	_queue_filter_controls_rect_changed()

func _apply_museum_rarity_check_text_color(check_box: CheckBox) -> void:
	if check_box == null:
		return
	check_box.add_theme_color_override("font_color", MUSEUM_RARITY_CHECK_TEXT)
	check_box.add_theme_color_override("font_hover_color", MUSEUM_RARITY_CHECK_TEXT)
	check_box.add_theme_color_override("font_pressed_color", MUSEUM_RARITY_CHECK_TEXT)
	check_box.add_theme_color_override("font_focus_color", MUSEUM_RARITY_CHECK_TEXT)
	check_box.add_theme_color_override("font_disabled_color", MUSEUM_RARITY_CHECK_TEXT)
	check_box.add_theme_constant_override("outline_size", 0)

func _update_series_filter_options(relics: Array[Dictionary]) -> void:
	var series_set: Dictionary = {}
	for relic in relics:
		var series := str(relic.get("series_name", ""))
		if series != "":
			series_set[series] = true
	var series_list: Array[String] = []
	for series in series_set.keys():
		series_list.append(str(series))
	series_list.sort()
	if _selected_series != "" and _selected_series != TODAY_VISIBLE_SERIES_FILTER and not series_set.has(_selected_series):
		_selected_series = ""

	_series_option.clear()
	_series_option.add_item(Localization.t("ui.deck_collection.series_all"))
	_series_option.set_item_metadata(0, "")
	_series_option.add_item(Localization.t("ui.deck_collection.series_today_visible"))
	_series_option.set_item_metadata(1, TODAY_VISIBLE_SERIES_FILTER)
	var selected_index := 1 if _selected_series == TODAY_VISIBLE_SERIES_FILTER else 0
	for i in range(series_list.size()):
		_series_option.add_item(series_list[i])
		_series_option.set_item_metadata(i + 2, series_list[i])
		if series_list[i] == _selected_series:
			selected_index = i + 2
	_series_option.select(selected_index)

func _apply_relic_filters(relics: Array[Dictionary]) -> Array[Dictionary]:
	return _apply_color_filter(_apply_series_filter(relics))

func _apply_series_filter(relics: Array[Dictionary]) -> Array[Dictionary]:
	var filtered: Array[Dictionary] = []
	for relic in relics:
		if _selected_series == TODAY_VISIBLE_SERIES_FILTER:
			if not _is_today_visible_relic(relic):
				continue
		elif _selected_series != "" and str(relic.get("series_name", "")) != _selected_series:
			continue
		filtered.append(relic)
	return filtered

func _apply_color_filter(relics: Array[Dictionary]) -> Array[Dictionary]:
	var filtered: Array[Dictionary] = []
	var has_active_color := false
	for color_type in _available_colors:
		if bool(_selected_colors.get(color_type, true)):
			has_active_color = true
			break
	if not has_active_color:
		return filtered
	for relic in relics:
		var color_type := int(relic.get("color", CardColor.ColorType.WHITE))
		if not bool(_selected_colors.get(color_type, true)):
			continue
		filtered.append(relic)
	return filtered

func _is_today_visible_relic(relic: Dictionary) -> bool:
	var decks = GameManager.draw_key.get("decks", [])
	if not decks is Array:
		return false
	var relic_id := int(relic.get("deck_def_id", 0))
	var relic_deck_asset_id := int(relic.get("deck_asset_id", 0))
	var relic_series_asset_id := int(relic.get("series_asset_id", 0))
	var relic_key := str(relic.get("deck_def_key", ""))
	var relic_series := str(relic.get("series_name", ""))
	var relic_deck := str(relic.get("deck_name", ""))
	for deck in decks:
		if not deck is Dictionary:
			continue
		var deck_data := deck as Dictionary
		var deck_id := int(deck_data.get("deck_def_id", 0))
		if relic_id > 0 and deck_id > 0 and relic_id == deck_id:
			return true
		if (
			relic_series_asset_id > 0
			and relic_deck_asset_id > 0
			and relic_series_asset_id == int(deck_data.get("series_asset_id", 0))
			and relic_deck_asset_id == int(deck_data.get("deck_asset_id", 0))
		):
			return true
		var deck_key := str(deck_data.get("deck_def_key", ""))
		if relic_key != "" and deck_key != "" and relic_key == deck_key:
			return true
		if relic_series == str(deck_data.get("series_name", "")) and relic_deck == str(deck_data.get("deck_name", "")):
			return true
	return false

func _sort_relic_list(relics: Array[Dictionary]) -> void:
	relics.sort_custom(_sort_relics)

func _sort_relics(a: Dictionary, b: Dictionary) -> bool:
	match _sort_mode:
		"recent":
			var a_recent := int(a.get("first_index", 0))
			var b_recent := int(b.get("first_index", 0))
			if a_recent != b_recent:
				return a_recent < b_recent
		"oldest":
			var a_oldest := int(a.get("last_index", 0))
			var b_oldest := int(b.get("last_index", 0))
			if a_oldest != b_oldest:
				return a_oldest > b_oldest
		_:
			var a_rarity_rank := _rarity_sort_rank(int(a.get("color", CardColor.ColorType.WHITE)))
			var b_rarity_rank := _rarity_sort_rank(int(b.get("color", CardColor.ColorType.WHITE)))
			if a_rarity_rank != b_rarity_rank:
				return a_rarity_rank < b_rarity_rank
			var a_series_index := _series_sort_index(str(a.get("series_name", "")))
			var b_series_index := _series_sort_index(str(b.get("series_name", "")))
			if a_series_index != b_series_index:
				return a_series_index < b_series_index
			var a_deck_index := _deck_sort_index(a)
			var b_deck_index := _deck_sort_index(b)
			if a_deck_index != b_deck_index:
				return a_deck_index < b_deck_index
	var a_series := str(a.get("series_name", ""))
	var b_series := str(b.get("series_name", ""))
	if a_series == b_series:
		return str(a.get("deck_name", "")) < str(b.get("deck_name", ""))
	return a_series < b_series

func _rarity_sort_rank(color_type: int) -> int:
	var rank := COLOR_ORDER.find(color_type)
	return rank if rank >= 0 else COLOR_ORDER.size()

func _series_sort_index(series_name: String) -> int:
	var all_series := CardDataManager.get_all_series()
	for i in range(all_series.size()):
		var series = all_series[i]
		if series is CardSeries and (series as CardSeries).series_name == series_name:
			return i
	return 1000000

func _deck_sort_index(relic: Dictionary) -> int:
	var series_name := str(relic.get("series_name", ""))
	var deck_name := str(relic.get("deck_name", ""))
	var series := CardDataManager.get_series_by_name(series_name)
	if series != null:
		var deck_names := series.get_deck_names()
		for i in range(deck_names.size()):
			if str(deck_names[i]) == deck_name:
				return i
	var deck_def_id := int(relic.get("deck_def_id", 0))
	return deck_def_id if deck_def_id > 0 else 1000000

func _on_color_filter_pressed(id: int) -> void:
	var current := bool(_selected_colors.get(id, true))
	_selected_colors[id] = not current
	_save_session_filter_state()
	render_decks()

func _on_color_filter_toggled(pressed: bool, color_type: int) -> void:
	_selected_colors[color_type] = pressed
	_save_session_filter_state()
	render_decks()

func _on_sort_selected(index: int) -> void:
	_sort_mode = str(_sort_option.get_item_metadata(index))
	_save_session_filter_state()
	render_decks()

func _on_series_selected(index: int) -> void:
	_selected_series = str(_series_option.get_item_metadata(index))
	_save_session_filter_state()
	render_decks()

func _create_color_header(color_type: int, count: int) -> Control:
	var hdr = HBoxContainer.new()
	hdr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr.custom_minimum_size = Vector2(0, HEADER_HEIGHT)

	var color_label = Label.new()
	color_label.text = "■ " + Localization.t("ui.deck_collection.color_header", [_museum_relic_tier_name(color_type)])
	color_label.add_theme_font_size_override("font_size", 16)
	# 粗体设置 — Godot 中无法直接用 bool 设置 bold，改用 add_theme_font_size_override 即可
	color_label.add_theme_color_override("font_color", _get_color_text(color_type))
	color_label.add_theme_constant_override("outline_size", 1)
	hdr.add_child(color_label)

	# 计数
	var count_label = Label.new()
	count_label.text = Localization.t("ui.deck_collection.kind_count", [count])
	count_label.add_theme_font_size_override("font_size", 13)
	count_label.add_theme_color_override("font_color", MUSEUM_TEXT_MUTED)
	hdr.add_child(count_label)

	# 占满剩余空间
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr.add_child(spacer)

	return hdr

func _create_card_grid(relics: Array) -> Container:
	var flow = HFlowContainer.new()
	flow.name = "MuseumRelicGrid"
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flow.custom_minimum_size = Vector2(_content_width(), 0.0)
	flow.size = Vector2(_content_width(), 0.0)
	flow.add_theme_constant_override("h_separation", CARD_HORIZONTAL_SPACING)
	flow.add_theme_constant_override("v_separation", CARD_SPACING)

	for relic in relics:
		var card = _create_relic_card(relic)
		flow.add_child(card)

	return flow

func _get_relics_that_fit_first_row(relics: Array) -> int:
	if relics.is_empty():
		return 0
	var available_width := _content_width()
	if available_width <= 1.0:
		available_width = get_viewport_rect().size.x
	var used_width := 0.0
	var count := 0
	for relic in relics:
		if not relic is Dictionary:
			continue
		var relic_data: Dictionary = relic
		var item_width := _get_relic_card_width(relic_data)
		var needed_width := item_width if count == 0 else CARD_HORIZONTAL_SPACING + item_width
		if count > 0 and used_width + needed_width > available_width + 0.1:
			break
		used_width += needed_width
		count += 1
	return count

func _get_relic_card_width(relic: Dictionary) -> float:
	var color_type := int(relic.get("color", CardColor.ColorType.WHITE))
	if RelicView.supports_color(color_type):
		return _get_visual_relic_size(color_type).x
	return CARD_WIDTH

func _create_relic_card(relic: Dictionary) -> Control:
	var color_type := int(relic.get("color", CardColor.ColorType.WHITE))
	if RelicView.supports_color(color_type):
		return _create_visual_relic_card(relic)

	var card_container = Control.new()
	card_container.custom_minimum_size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	card_container.size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	_register_relic_source_card(card_container, relic)

	# 尚未实装正式图片的其他颜色继续使用颜色矩形占位。
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = _get_card_bg_color(color_type)
	bg.name = "RelicCardBg"

	var border_rect = ColorRect.new()
	border_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	border_rect.position = Vector2(1, 1)
	border_rect.size = Vector2(CARD_WIDTH - 2, CARD_HEIGHT - 2)
	border_rect.color = _get_color_text(color_type)
	border_rect.modulate = Color(1, 1, 1, 0.18)
	border_rect.name = "RelicCardBorder"

	card_container.add_child(bg)
	card_container.add_child(border_rect)

	var grad_overlay = ColorRect.new()
	grad_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	grad_overlay.color = Color(1, 1, 1, 0.05)
	grad_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grad_overlay.name = "RelicCardOverlay"
	card_container.add_child(grad_overlay)

	var series_label = Label.new()
	series_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	series_label.position = Vector2(10, 18)
	series_label.size = Vector2(-20, 28)
	series_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	series_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	series_label.text = str(relic.get("series_name", ""))
	series_label.add_theme_font_size_override("font_size", 14)
	series_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
	series_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	series_label.name = "RelicCardSeries"
	card_container.add_child(series_label)

	var name_label = Label.new()
	name_label.set_anchors_preset(Control.PRESET_CENTER)
	name_label.position = Vector2(0, -18)
	name_label.size = Vector2(CARD_WIDTH - 20, 58)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.text = str(relic.get("deck_name", ""))
	name_label.add_theme_font_size_override("font_size", 24)
	name_label.add_theme_color_override("font_color", Color(1, 1, 1, 1.0))
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.name = "RelicCardName"
	card_container.add_child(name_label)

	# 编号标识 — 小字显示 1-5（代表集齐）
	var num_label = Label.new()
	num_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	num_label.position = Vector2(10, 54)
	num_label.size = Vector2(-20, 20)
	num_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num_label.text = "1 2 3 4 5"
	num_label.add_theme_font_size_override("font_size", 10)
	num_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
	num_label.name = "RelicCardSlots"
	card_container.add_child(num_label)

	var count_label = Label.new()
	count_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	count_label.position = Vector2(0, 6)
	count_label.size = Vector2(0, 24)
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	count_label.text = Localization.t("ui.deck_collection.relic_count", [int(relic.get("count", 1))])
	count_label.add_theme_font_size_override("font_size", 14)
	count_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0, 1.0))
	count_label.name = "RelicCardCount"
	card_container.add_child(count_label)

	_apply_relic_source_view_visibility(card_container, relic)
	return card_container

func _create_visual_relic_card(relic: Dictionary) -> Control:
	var color_type := int(relic.get("color", CardColor.ColorType.WHITE))
	if not RelicView.supports_color(color_type):
		return Control.new()
	var relic_size := _get_visual_relic_size(color_type)
	var relic_width := relic_size.x
	var relic_height := relic_size.y
	var relic_slot_height := _get_visual_relic_slot_height()
	var container := Control.new()
	container.name = "RelicCard%d" % color_type
	container.custom_minimum_size = Vector2(relic_width, relic_slot_height + VISUAL_RELIC_LABEL_HEIGHT + 4.0)
	container.size = container.custom_minimum_size
	container.mouse_filter = Control.MOUSE_FILTER_STOP
	_register_relic_source_card(container, relic)

	var box := VBoxContainer.new()
	box.name = "RelicCardBox"
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.add_theme_constant_override("separation", 4)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(box)

	var relic_host := Control.new()
	relic_host.name = "RelicHost"
	relic_host.custom_minimum_size = Vector2(relic_width, relic_slot_height)
	relic_host.size = relic_host.custom_minimum_size
	relic_host.clip_contents = false
	box.add_child(relic_host)

	var label_box := VBoxContainer.new()
	label_box.name = "RelicCardLabels"
	label_box.custom_minimum_size = Vector2(relic_width, VISUAL_RELIC_LABEL_HEIGHT)
	label_box.add_theme_constant_override("separation", 0)
	box.add_child(label_box)

	var series_label := Label.new()
	series_label.name = "RelicCardSeries"
	series_label.custom_minimum_size = Vector2(relic_width, 20)
	series_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	series_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	series_label.text = str(relic.get("series_name", ""))
	series_label.add_theme_font_size_override("font_size", 14)
	series_label.add_theme_color_override("font_color", MUSEUM_TEXT_MUTED)
	series_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	series_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label_box.add_child(series_label)

	var name_label := Label.new()
	name_label.name = "RelicCardName"
	name_label.custom_minimum_size = Vector2(relic_width, 26)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.text = str(relic.get("deck_name", ""))
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.add_theme_color_override("font_color", MUSEUM_TEXT_DARK)
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label_box.add_child(name_label)

	var count_label := Label.new()
	count_label.name = "RelicCardCount"
	count_label.custom_minimum_size = Vector2(relic_width, 20)
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	count_label.text = Localization.t("ui.deck_collection.relic_count", [int(relic.get("count", 1))])
	count_label.add_theme_font_size_override("font_size", 14)
	count_label.add_theme_color_override("font_color", MUSEUM_TEXT_MUTED)
	count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label_box.add_child(count_label)

	var cards := _get_relic_cards(relic)
	var thumbnail := TextureRect.new()
	thumbnail.name = "RelicThumbnail"
	thumbnail.set_anchors_preset(Control.PRESET_TOP_LEFT)
	thumbnail.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumbnail.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	thumbnail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	thumbnail.texture = THUMBNAIL_CACHE.get_thumbnail_texture(
		color_type,
		str(relic.get("deck_def_key", "")),
		int(relic.get("deck_def_id", 0)),
		cards
	)
	thumbnail.size = relic_size
	thumbnail.position = _get_visual_relic_canvas_position(color_type, relic_size, relic_host.custom_minimum_size)
	var relic_shadow := CCRVisualStyle.make_texture_shadow(thumbnail, "RelicThumbnailShadow", Vector2(10, 16), CCRVisualStyle.RELIC_SHADOW)
	relic_host.add_child(relic_shadow)
	relic_host.add_child(thumbnail)

	if thumbnail.texture == null:
		var relic_view := RELIC_VIEW_SCENE.instantiate() as RelicView
		if relic_view.set_relic_color(color_type):
			relic_view.name = "RelicView"
			relic_view.set_anchors_preset(Control.PRESET_TOP_LEFT)
			relic_view.position = thumbnail.position
			relic_view.size = relic_size
			relic_view.custom_minimum_size = Vector2.ZERO
			relic_view.set_cards(cards)
			relic_host.add_child(relic_view)

	var hover_frame := Panel.new()
	hover_frame.name = "RelicHoverFrame"
	hover_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	hover_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hover_frame.visible = false
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = Color(1.0, 0.82, 0.18, 0.05)
	frame_style.border_color = Color(1.0, 0.78, 0.18, 1.0)
	frame_style.set_border_width_all(3)
	frame_style.corner_radius_top_left = 4
	frame_style.corner_radius_top_right = 4
	frame_style.corner_radius_bottom_left = 4
	frame_style.corner_radius_bottom_right = 4
	hover_frame.add_theme_stylebox_override("panel", frame_style)
	container.add_child(hover_frame)

	var hit_area := ColorRect.new()
	hit_area.name = "RelicHitArea"
	hit_area.set_anchors_preset(Control.PRESET_FULL_RECT)
	hit_area.color = Color(1, 1, 1, 0.0)
	hit_area.mouse_filter = Control.MOUSE_FILTER_STOP
	container.add_child(hit_area)

	hit_area.mouse_entered.connect(func(): hover_frame.visible = _view_state == ViewState.NONE)
	hit_area.mouse_exited.connect(func(): hover_frame.visible = false)
	hit_area.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and _view_state == ViewState.NONE:
			hover_frame.visible = false
			_start_relic_view(relic, thumbnail, container)
	)

	_apply_relic_source_view_visibility(container, relic)
	return container

func _get_visual_relic_size(color_type: int) -> Vector2:
	var aspect_ratio := THUMBNAIL_CACHE.get_aspect_ratio(color_type)
	var display_scale := RelicView.get_display_scale(color_type)
	var relic_base_height := _get_visual_relic_base_height()
	return Vector2(relic_base_height * display_scale * aspect_ratio, relic_base_height * display_scale)

func _get_visual_relic_slot_height() -> float:
	var max_height := 1.0
	for supported_color in RelicView.RELIC_CONFIGS.keys():
		max_height = maxf(max_height, _get_visual_relic_size(int(supported_color)).y)
	return max_height

func _get_visual_relic_canvas_position(color_type: int, relic_size: Vector2, host_size: Vector2) -> Vector2:
	var visible_bottom := RelicView.get_visible_bottom_ratio(color_type) * relic_size.y
	return Vector2((host_size.x - relic_size.x) * 0.5, host_size.y - visible_bottom)

func _get_visual_relic_base_height() -> float:
	var ideal_height := get_viewport_rect().size.y * RELIC_SCREEN_HEIGHT_RATIO
	var available_width := size.x
	if available_width <= 1.0:
		available_width = get_viewport_rect().size.x
	var target_items := maxi(RELICS_PER_ROW, RELIC_TARGET_MIN_ITEMS_PER_ROW)
	var max_width := maxf(1.0, (available_width - CARD_HORIZONTAL_SPACING * float(target_items - 1)) / float(target_items))
	var base_height := ideal_height
	for supported_color in RelicView.RELIC_CONFIGS.keys():
		var aspect_ratio := THUMBNAIL_CACHE.get_aspect_ratio(int(supported_color))
		var display_scale := RelicView.get_display_scale(int(supported_color))
		base_height = minf(base_height, max_width / maxf(aspect_ratio * display_scale, 0.01))
	return maxf(1.0, base_height)

func _start_relic_view(relic: Dictionary, thumbnail: TextureRect, source_card: Control) -> void:
	if _view_state != ViewState.NONE or _view_busy:
		return
	_view_cards = _get_relic_cards(relic)
	_view_cancel_requested = false
	var relic_rect := thumbnail.get_global_rect()
	_view_color = int(relic.get("color", CardColor.ColorType.WHITE))
	_view_source_rect = relic_rect
	_view_source_card = source_card
	_view_source_relic_key = _relic_source_key(relic)
	_view_source_card_modulate = _view_source_card.modulate
	_set_relic_source_cards_hidden(_view_source_relic_key, true)
	_view_overlay = Control.new()
	_view_overlay.name = "MuseumRelicViewOverlay"
	_view_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_view_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_view_overlay.z_index = 1000
	_view_overlay.gui_input.connect(_on_view_overlay_input)
	get_tree().root.add_child(_view_overlay)

	_view_blur = ColorRect.new()
	_view_blur.name = "MuseumViewBlur"
	_view_blur.set_anchors_preset(Control.PRESET_FULL_RECT)
	_view_blur.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view_blur.visible = false
	var blur_shader := Shader.new()
	blur_shader.code = VIEW_BLUR_SHADER_CODE
	var blur_material := ShaderMaterial.new()
	blur_material.shader = blur_shader
	_view_blur.material = blur_material
	_view_overlay.add_child(_view_blur)

	_view_relic = TextureRect.new()
	_view_relic.name = "MuseumViewedRelic"
	_view_relic.texture = thumbnail.texture
	_view_relic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_view_relic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_view_relic.position = relic_rect.position
	_view_relic.size = relic_rect.size
	_view_relic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view_relic_shadow = CCRVisualStyle.make_texture_shadow(_view_relic, "MuseumViewedRelicShadow", Vector2(12, 18), CCRVisualStyle.RELIC_SHADOW)
	_view_overlay.add_child(_view_relic_shadow)
	_view_overlay.add_child(_view_relic)

	_view_state = ViewState.RELIC_CENTERED
	_view_busy = true
	var target_center := Vector2(get_viewport_rect().size.x / 7.0, get_viewport_rect().size.y * 0.5)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_view_relic, "position", target_center - relic_rect.size * 0.5, VIEW_RELIC_MOVE_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	if is_instance_valid(_view_relic_shadow):
		tween.tween_property(_view_relic_shadow, "position", target_center - relic_rect.size * 0.5 + Vector2(12, 18), VIEW_RELIC_MOVE_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	if _view_cancel_requested:
		_finish_relic_view()
		return
	if is_instance_valid(_view_blur):
		_view_blur.visible = true
	_view_busy = false

func _on_view_overlay_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton) or not event.pressed:
		return
	accept_event()
	if event.button_index == MOUSE_BUTTON_RIGHT:
		_view_cancel_requested = true
		if not _view_busy:
			_finish_relic_view()
		return
	if _view_busy:
		return
	if event.button_index == MOUSE_BUTTON_LEFT:
		_advance_relic_view()

func _advance_relic_view() -> void:
	match _view_state:
		ViewState.RELIC_CENTERED:
			_reveal_view_cards()
		ViewState.CARDS_VISIBLE:
			_hide_view_cards()
		ViewState.CARDS_HIDDEN:
			_finish_relic_view()

func _reveal_view_cards() -> void:
	if not is_instance_valid(_view_overlay) or not is_instance_valid(_view_relic):
		return
	_view_busy = true
	_clear_view_cards(false)
	AudioManager.play_sfx("card_preview", 1.0, 0.0)
	var viewport_size := get_viewport_rect().size
	var card_size := Vector2(viewport_size.x * 0.105, viewport_size.x * 0.105 * CardDisplay.CARD_SIZE.y / CardDisplay.CARD_SIZE.x)
	card_size.y = minf(card_size.y, viewport_size.y * 0.34)
	card_size.x = card_size.y * CardDisplay.CARD_SIZE.x / CardDisplay.CARD_SIZE.y
	var render_card_size := card_size * CardDisplay.HOVER_SCALE
	var resting_scale := 1.0 / CardDisplay.HOVER_SCALE
	var start_center := Vector2(viewport_size.x / 7.0, viewport_size.y * 0.5)
	for index in range(mini(5, _view_cards.size())):
		var display := CardDisplayScript.new() as CardDisplay
		display.name = "MuseumViewedSubcard%d" % (index + 1)
		display.hover_uses_slot_bounds = false
		display.hover_scale_enabled = true
		display.is_draggable = false
		display.custom_minimum_size = render_card_size
		display.size = render_card_size
		display.position = start_center - render_card_size * 0.5
		display.pivot_offset = render_card_size * 0.5
		display.configure_visual_scales(resting_scale, 1.0)
		display.modulate.a = 0.0
		_view_overlay.add_child(display)
		display.pivot_offset = render_card_size * 0.5
		var source_card := _view_cards[index] as CardInfo
		display.set_card(_card_with_relic_color(source_card), index)
		_view_card_displays.append(display)
		var target_center := Vector2(viewport_size.x * float(index + 2) / 7.0, viewport_size.y * 0.5)
		var tween := create_tween()
		tween.tween_interval(float(index) * VIEW_CARD_INTERVAL_SECONDS)
		tween.tween_property(display, "position", target_center - render_card_size * 0.5, VIEW_CARD_MOVE_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(display, "modulate:a", 1.0, VIEW_CARD_MOVE_SECONDS * 0.5)
	await get_tree().create_timer(VIEW_CARD_MOVE_SECONDS + VIEW_CARD_INTERVAL_SECONDS * 4.0).timeout
	if _view_cancel_requested:
		_finish_relic_view()
		return
	_view_state = ViewState.CARDS_VISIBLE
	_view_busy = false

func _hide_view_cards() -> void:
	if not is_instance_valid(_view_relic):
		return
	_view_busy = true
	var viewport_size := get_viewport_rect().size
	var start_center := Vector2(viewport_size.x / 7.0, viewport_size.y * 0.5)
	for reverse_index in range(_view_card_displays.size()):
		var index := _view_card_displays.size() - 1 - reverse_index
		var display := _view_card_displays[index]
		if not is_instance_valid(display):
			continue
		var tween := create_tween()
		tween.tween_interval(float(reverse_index) * VIEW_CARD_INTERVAL_SECONDS)
		tween.tween_property(display, "position", start_center - display.size * 0.5, VIEW_CARD_MOVE_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tween.parallel().tween_property(display, "modulate:a", 0.0, VIEW_CARD_MOVE_SECONDS * 0.5)
	await get_tree().create_timer(VIEW_CARD_MOVE_SECONDS + VIEW_CARD_INTERVAL_SECONDS * 4.0).timeout
	_clear_view_cards(true)
	if _view_cancel_requested:
		_finish_relic_view()
		return
	_view_state = ViewState.CARDS_HIDDEN
	_view_busy = false

func _finish_relic_view() -> void:
	if not is_instance_valid(_view_overlay) or not is_instance_valid(_view_relic):
		_reset_relic_view_state()
		return
	_view_busy = true
	if not _view_card_displays.is_empty():
		_view_cancel_requested = false
		await _hide_view_cards()
		_view_busy = true
	var target_pos := _view_source_rect.position
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_view_relic, "position", target_pos, VIEW_RELIC_MOVE_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	if is_instance_valid(_view_relic_shadow):
		tween.tween_property(_view_relic_shadow, "position", target_pos + Vector2(12, 18), VIEW_RELIC_MOVE_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	_reset_relic_view_state()

func _clear_view_cards(free_nodes: bool) -> void:
	for display in _view_card_displays:
		if is_instance_valid(display) and free_nodes:
			display.queue_free()
	if free_nodes:
		_view_card_displays.clear()

func _reset_relic_view_state() -> void:
	if is_instance_valid(_view_overlay):
		_view_overlay.queue_free()
	_view_overlay = null
	_view_blur = null
	_view_relic = null
	_view_relic_shadow = null
	if _view_source_relic_key != "":
		_set_relic_source_cards_hidden(_view_source_relic_key, false)
	if is_instance_valid(_view_source_card):
		_view_source_card.modulate = _view_source_card_modulate
	_view_source_card = null
	_view_source_card_modulate = Color.WHITE
	_view_source_relic_key = ""
	_view_card_displays.clear()
	_view_cards.clear()
	_view_state = ViewState.NONE
	_view_busy = false
	_view_cancel_requested = false

func _card_with_relic_color(card: CardInfo) -> CardInfo:
	if card == null:
		return null
	var copy := CardInfo.new(card.to_dict())
	copy.color = _view_color as CardColor.ColorType
	return copy

func _register_relic_source_card(card: Control, relic: Dictionary) -> void:
	card.set_meta("museum_relic_source_key", _relic_source_key(relic))
	card.add_to_group("museum_relic_source_cards")

func _apply_relic_source_view_visibility(card: Control, relic: Dictionary) -> void:
	if _view_state == ViewState.NONE:
		return
	var key := _relic_source_key(relic)
	if key == "" or key != _view_source_relic_key:
		return
	var modulate := card.modulate
	modulate.a = 0.0
	card.modulate = modulate

func _set_relic_source_cards_hidden(key: String, hidden: bool) -> void:
	if key == "":
		return
	var target_alpha := 0.0 if hidden else 1.0
	for node in get_tree().get_nodes_in_group("museum_relic_source_cards"):
		var card := node as Control
		if card == null or not is_instance_valid(card):
			continue
		if str(card.get_meta("museum_relic_source_key", "")) != key:
			continue
		var modulate := card.modulate
		modulate.a = target_alpha
		card.modulate = modulate

func _relic_source_key(relic: Dictionary) -> String:
	var color_type := int(relic.get("color", CardColor.ColorType.WHITE))
	var deck_key := str(relic.get("deck_def_key", ""))
	if deck_key != "":
		return "%s|%d" % [deck_key, color_type]
	var deck_def_id := int(relic.get("deck_def_id", 0))
	if deck_def_id > 0:
		return "%d|%d" % [deck_def_id, color_type]
	return "%s|%s|%d" % [
		str(relic.get("series_name", "")),
		str(relic.get("deck_name", "")),
		color_type,
	]


func _apply_relic_label_rect(label: Label, layout: Dictionary, relic_width: float, relic_height: float) -> void:
	label.position = Vector2(
		relic_width * float(layout.get("x_ratio", 0.25)),
		relic_height * float(layout.get("y_ratio", 0.75))
	)
	label.size = Vector2(
		relic_width * float(layout.get("width_ratio", 0.5)),
		relic_height * float(layout.get("height_ratio", 0.05))
	)

func _get_relic_cards(relic: Dictionary) -> Array:
	var series_asset_id := int(relic.get("series_asset_id", 0))
	var deck_asset_id := int(relic.get("deck_asset_id", 0))
	var cards: Array = CardDataManager.get_cards_by_asset_ids(series_asset_id, deck_asset_id)
	var deck_def_key := str(relic.get("deck_def_key", ""))
	var deck_def_id := int(relic.get("deck_def_id", 0))
	if cards.is_empty() and deck_def_key != "":
		cards = CardDataManager.get_cards_by_deck_key(deck_def_key)
	if cards.is_empty() and deck_def_id > 0:
		cards = CardDataManager.get_cards_by_deck_id(deck_def_id)
	if cards.is_empty():
		cards = CardDataManager.get_cards_by_deck(
			str(relic.get("series_name", "")),
			str(relic.get("deck_name", ""))
		)
	var ordered := cards.duplicate()
	ordered.sort_custom(func(a: CardInfo, b: CardInfo): return a.card_number < b.card_number)
	return ordered.slice(0, mini(5, ordered.size()))

func _get_card_bg_color(color_type: int) -> Color:
	if color_type == 6:
		return Color(0.6, 0.1, 0.1, 0.85)
	elif color_type == 5:
		return Color(0.15, 0.15, 0.15, 0.9)
	elif color_type == 4:
		return Color(0.7, 0.35, 0.05, 0.85)
	elif color_type == 3:
		return Color(0.45, 0.1, 0.55, 0.85)
	elif color_type == 2:
		return Color(0.15, 0.3, 0.65, 0.85)
	elif color_type == 1:
		return Color(0.1, 0.5, 0.2, 0.85)
	elif color_type == 0:
		return Color(0.5, 0.5, 0.55, 0.7)
	else:
		return Color(0.3, 0.3, 0.35, 0.7)


func _get_color_text(color_type: int) -> Color:
	if color_type == 6:
		return Color(1.0, 0.3, 0.3, 1.0)
	elif color_type == 5:
		return Color(0.8, 0.8, 0.8, 1.0)
	elif color_type == 4:
		return Color(1.0, 0.7, 0.2, 1.0)
	elif color_type == 3:
		return Color(0.9, 0.5, 1.0, 1.0)
	elif color_type == 2:
		return Color(0.4, 0.7, 1.0, 1.0)
	elif color_type == 1:
		return Color(0.4, 1.0, 0.5, 1.0)
	elif color_type == 0:
		return Color(0.9, 0.9, 0.9, 1.0)
	else:
		return Color(1, 1, 1, 1)


func refresh() -> void:
	render_decks()

func contains_relic(deck_definition_id: int, color_type: int) -> bool:
	for deck in DeckSystem.player_decks:
		if deck != null and int(deck.deck_def_id) == deck_definition_id and int(deck.color) == color_type:
			return true
	return false

func _museum_relic_tier_name(color_type: int) -> String:
	match color_type:
		CardColor.ColorType.WHITE:
			return Localization.t("ui.deck_collection.rarity.normal")
		CardColor.ColorType.GREEN:
			return Localization.t("ui.deck_collection.rarity.excellent")
		CardColor.ColorType.BLUE:
			return Localization.t("ui.deck_collection.rarity.rare")
		CardColor.ColorType.PURPLE:
			return Localization.t("ui.deck_collection.rarity.epic")
		CardColor.ColorType.ORANGE:
			return Localization.t("ui.deck_collection.rarity.legendary")
		CardColor.ColorType.BLACK:
			return Localization.t("ui.deck_collection.rarity.ultimate")
		CardColor.ColorType.RED:
			return Localization.t("ui.deck_collection.rarity.cosmic")
	return CardColor.display_name(color_type)

func _apply_filter_control_text_style(control) -> void:
	if control == null:
		return
	for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		control.add_theme_color_override(color_name, MUSEUM_TEXT_DARK)
	control.add_theme_color_override("font_disabled_color", Color(MUSEUM_TEXT_DARK, 0.42))
	control.add_theme_font_size_override("font_size", FILTER_CONTROL_FONT_SIZE)

func _apply_collection_progress_text_color() -> void:
	if _collection_progress_label == null:
		return
	_collection_progress_label.add_theme_color_override("font_color", CCRVisualStyle.SETTINGS_TEXT)
	_collection_progress_label.add_theme_color_override("font_readonly_color", CCRVisualStyle.SETTINGS_TEXT)
	_collection_progress_label.add_theme_color_override("font_uneditable_color", CCRVisualStyle.SETTINGS_TEXT)

func _restore_session_filter_state() -> void:
	if _session_filter_state.is_empty():
		_selected_series = TODAY_VISIBLE_SERIES_FILTER
		_sync_sort_option_to_mode()
		return
	var colors = _session_filter_state.get("selected_colors", {})
	if colors is Dictionary:
		_selected_colors.clear()
		for key in (colors as Dictionary).keys():
			_selected_colors[int(key)] = bool((colors as Dictionary).get(key, true))
	_selected_series = str(_session_filter_state.get("selected_series", ""))
	var saved_sort := str(_session_filter_state.get("sort_mode", "standard"))
	_sort_mode = saved_sort if ["recent", "oldest", "standard"].has(saved_sort) else "standard"
	_sync_sort_option_to_mode()

func _save_session_filter_state() -> void:
	_session_filter_state = {
		"selected_colors": _selected_colors.duplicate(true),
		"selected_series": _selected_series,
		"sort_mode": _sort_mode,
	}

func _sync_sort_option_to_mode() -> void:
	if _sort_option == null:
		return
	for i in range(_sort_option.get_item_count()):
		if str(_sort_option.get_item_metadata(i)) == _sort_mode:
			_sort_option.select(i)
			return
	_sort_mode = "standard"
	_sort_option.select(2)

static func reset_session_filter_state() -> void:
	_session_filter_state.clear()

func _update_collection_progress(filtered_relics: Array[Dictionary]) -> void:
	if _collection_progress_label == null:
		return
	var numerator := filtered_relics.size()
	var denominator := _selected_color_count_for_progress() * _available_deck_def_count_for_progress()
	_collection_progress_label.text = Localization.t("ui.deck_collection.progress", [numerator, denominator])

func _selected_color_count_for_progress() -> int:
	var selected_count := 0
	for color_type in _available_colors:
		if bool(_selected_colors.get(color_type, true)):
			selected_count += 1
	return selected_count

func _available_deck_def_count_for_progress() -> int:
	if _selected_series == TODAY_VISIBLE_SERIES_FILTER:
		var decks = GameManager.draw_key.get("decks", [])
		if not decks is Array:
			return 0
		var visible_decks: Dictionary = {}
		for deck in decks:
			if not deck is Dictionary:
				continue
			var deck_data := deck as Dictionary
			var identity := str(deck_data.get("deck_def_id", 0))
			if identity == "0":
				identity = str(deck_data.get("deck_def_key", ""))
			if identity == "":
				identity = "%s|%s" % [deck_data.get("series_name", ""), deck_data.get("deck_name", "")]
			visible_decks[identity] = true
		return visible_decks.size()
	var total := 0
	for series in CardDataManager.get_all_series():
		if not (series is CardSeries):
			continue
		var card_series := series as CardSeries
		if _selected_series != "" and card_series.series_name != _selected_series:
			continue
		total += card_series.get_deck_names().size()
	return total
