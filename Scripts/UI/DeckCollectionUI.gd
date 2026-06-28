extends Control
class_name DeckCollectionUI

# 博物馆 — 展示所有已合成圣物，按颜色分组

const CARDS_PER_ROW: int = 6
const CARD_WIDTH: float = 150.0
const CARD_HEIGHT: float = 200.0
const CARD_SPACING: float = 24.0
const CARD_HORIZONTAL_SPACING: float = CARD_SPACING * 0.5
const SECTION_SPACING: float = 20.0
const HEADER_HEIGHT: float = 32.0
const FILTER_BAR_TOP: float = 48.0
const FILTER_BAR_HEIGHT: float = 38.0
const VISUAL_RELIC_LABEL_HEIGHT: float = 72.0
const RELIC_SCREEN_HEIGHT_RATIO: float = 3.0 / 5.0
const RELIC_VIEW_SCENE = preload("res://Scenes/UI/RelicView.tscn")
const THUMBNAIL_CACHE = preload("res://Scripts/UI/MuseumRelicThumbnailCache.gd")
const CardDisplayScript = preload("res://Scripts/UI/CardDisplay.gd")
const VIEW_RELIC_MOVE_SECONDS: float = 0.5
const VIEW_CARD_INTERVAL_SECONDS: float = 0.2
const VIEW_CARD_MOVE_SECONDS: float = 0.5
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

# 颜色排序顺序（从高到低）
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
var _content: VBoxContainer = null
var _empty_label: Label = null
var _filter_bar: HBoxContainer = null
var _color_filter_button: MenuButton = null
var _sort_option: OptionButton = null
var _series_option: OptionButton = null
var _last_render_viewport_height: float = 0.0
var _resize_render_queued: bool = false
var _view_overlay: Control = null
var _view_blur: ColorRect = null
var _view_relic: TextureRect = null
var _view_source_card: Control = null
var _view_source_card_modulate: Color = Color.WHITE
var _view_card_displays: Array[CardDisplay] = []
var _view_cards: Array = []
var _view_color: int = CardColor.ColorType.WHITE
var _view_source_rect: Rect2 = Rect2()
var _view_state: int = 0
var _view_busy: bool = false
var _view_cancel_requested: bool = false
var _selected_colors: Dictionary = {}
var _available_colors: Array[int] = []
var _selected_series: String = ""
var _sort_mode: String = "standard"

enum ViewState {
	NONE,
	RELIC_CENTERED,
	CARDS_VISIBLE,
	CARDS_HIDDEN,
}

func _ready() -> void:
	setup_ui()
	render_decks()

func _notification(what: int) -> void:
	if what != NOTIFICATION_RESIZED or not is_node_ready() or _content == null:
		return
	var viewport_height := get_viewport_rect().size.y
	if absf(viewport_height - _last_render_viewport_height) <= 1.0 or _resize_render_queued:
		return
	_resize_render_queued = true
	call_deferred("_rerender_after_viewport_resize")

func _rerender_after_viewport_resize() -> void:
	_resize_render_queued = false
	if is_inside_tree():
		render_decks()

func setup_ui() -> void:
	# 标题
	var title = Label.new()
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.position = Vector2(0, 10)
	title.size = Vector2(400, 32)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.text = Localization.t("ui.deck_collection.title")
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0, 1.0))  # 金色
	title.name = "MuseumTitle"
	add_child(title)

	_create_filter_bar()

	# 空状态提示（初始隐藏）
	_empty_label = Label.new()
	_empty_label.set_anchors_preset(Control.PRESET_CENTER)
	_empty_label.position = Vector2(0, 20)
	_empty_label.size = Vector2(400, 40)
	_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_label.text = Localization.t("ui.deck_collection.empty")
	_empty_label.add_theme_font_size_override("font_size", 16)
	_empty_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1.0))
	_empty_label.visible = false
	_empty_label.name = "MuseumEmpty"
	add_child(_empty_label)

	# 滚动容器
	_scroll_container = ScrollContainer.new()
	_scroll_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scroll_container.offset_top = 94
	_scroll_container.offset_bottom = 0
	_scroll_container.offset_left = 10
	_scroll_container.offset_right = -10
	add_child(_scroll_container)

	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", SECTION_SPACING)
	_scroll_container.add_child(_content)

func _create_filter_bar() -> void:
	_filter_bar = HBoxContainer.new()
	_filter_bar.name = "MuseumFilterBar"
	_filter_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_filter_bar.offset_left = 10
	_filter_bar.offset_right = -10
	_filter_bar.offset_top = FILTER_BAR_TOP
	_filter_bar.offset_bottom = FILTER_BAR_TOP + FILTER_BAR_HEIGHT
	_filter_bar.add_theme_constant_override("separation", 8)
	add_child(_filter_bar)

	_color_filter_button = MenuButton.new()
	_color_filter_button.name = "MuseumColorFilter"
	_color_filter_button.custom_minimum_size = Vector2(170, 32)
	_color_filter_button.get_popup().id_pressed.connect(_on_color_filter_pressed)
	_filter_bar.add_child(_color_filter_button)

	_sort_option = OptionButton.new()
	_sort_option.name = "MuseumSortOption"
	_sort_option.custom_minimum_size = Vector2(170, 32)
	_sort_option.add_item(Localization.t("ui.deck_collection.sort.recent"))
	_sort_option.set_item_metadata(0, "recent")
	_sort_option.add_item(Localization.t("ui.deck_collection.sort.oldest"))
	_sort_option.set_item_metadata(1, "oldest")
	_sort_option.add_item(Localization.t("ui.deck_collection.sort.standard"))
	_sort_option.set_item_metadata(2, "standard")
	_sort_option.select(2)
	_sort_option.item_selected.connect(_on_sort_selected)
	_filter_bar.add_child(_sort_option)

	_series_option = OptionButton.new()
	_series_option.name = "MuseumSeriesOption"
	_series_option.custom_minimum_size = Vector2(210, 32)
	_series_option.item_selected.connect(_on_series_selected)
	_filter_bar.add_child(_series_option)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_filter_bar.add_child(spacer)

func render_decks() -> void:
	_last_render_viewport_height = get_viewport_rect().size.y
	var render_started := Time.get_ticks_msec()
	FileLogger.perf("ui_render_start", {"page": "deck_panel", "component": "deck_grid"})
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
	relics = _apply_relic_filters(relics)
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

	var groups: Dictionary = {}  # CardColor.ColorType -> Array[Dictionary]
	for relic in relics:
		var color_type: int = int(relic.get("color", CardColor.ColorType.WHITE))
		if not groups.has(color_type):
			groups[color_type] = []
		groups[color_type].append(relic)

	for color_type in groups.keys():
		groups[color_type].sort_custom(_sort_relics)

	# 按颜色顺序渲染
	for color_type in COLOR_ORDER:
		if not groups.has(color_type):
			continue
		var relics_in_group: Array = groups[color_type]
		if relics_in_group.is_empty():
			continue

		var section = VBoxContainer.new()
		section.add_theme_constant_override("separation", 6)

		var header = _create_color_header(color_type, relics_in_group.size())
		section.add_child(header)

		var grid = _create_card_grid(relics_in_group)
		section.add_child(grid)

		_content.add_child(section)
	FileLogger.perf("ui_render_done", {"page": "deck_panel", "component": "relic_grid", "count": all_decks.size(), "display_count": relics.size(), "total_ms": Time.get_ticks_msec() - render_started})

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
	_update_color_filter_options(relics)
	_update_series_filter_options(relics)

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

	var popup := _color_filter_button.get_popup()
	popup.clear()
	for color_type in colors:
		popup.add_check_item(CardColor.display_name(color_type), color_type)
		var item_index := popup.get_item_index(color_type)
		if item_index >= 0:
			popup.set_item_checked(item_index, bool(_selected_colors.get(color_type, true)))
	_update_color_filter_button_text()

func _update_color_filter_button_text() -> void:
	var selected_names: Array[String] = []
	for color_type in _available_colors:
		if bool(_selected_colors.get(color_type, true)):
			selected_names.append(CardColor.display_name(color_type))
	if selected_names.size() == _available_colors.size() or selected_names.is_empty():
		_color_filter_button.text = Localization.t("ui.deck_collection.filter.colors_all")
	else:
		_color_filter_button.text = Localization.t("ui.deck_collection.filter.colors", [", ".join(selected_names)])

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
	if _selected_series != "" and not series_set.has(_selected_series):
		_selected_series = ""

	_series_option.clear()
	_series_option.add_item(Localization.t("ui.deck_collection.series_all"))
	_series_option.set_item_metadata(0, "")
	var selected_index := 0
	for i in range(series_list.size()):
		_series_option.add_item(series_list[i])
		_series_option.set_item_metadata(i + 1, series_list[i])
		if series_list[i] == _selected_series:
			selected_index = i + 1
	_series_option.select(selected_index)

func _apply_relic_filters(relics: Array[Dictionary]) -> Array[Dictionary]:
	var filtered: Array[Dictionary] = []
	var has_active_color := false
	for color_type in _available_colors:
		if bool(_selected_colors.get(color_type, true)):
			has_active_color = true
			break
	for relic in relics:
		var color_type := int(relic.get("color", CardColor.ColorType.WHITE))
		if has_active_color and not bool(_selected_colors.get(color_type, true)):
			continue
		if _selected_series != "" and str(relic.get("series_name", "")) != _selected_series:
			continue
		filtered.append(relic)
	return filtered

func _sort_relic_list(relics: Array[Dictionary]) -> void:
	relics.sort_custom(_sort_relics)

func _sort_relics(a: Dictionary, b: Dictionary) -> bool:
	match _sort_mode:
		"recent":
			var a_recent := int(a.get("last_index", 0))
			var b_recent := int(b.get("last_index", 0))
			if a_recent != b_recent:
				return a_recent > b_recent
		"oldest":
			var a_oldest := int(a.get("first_index", 0))
			var b_oldest := int(b.get("first_index", 0))
			if a_oldest != b_oldest:
				return a_oldest < b_oldest
		_:
			var a_id := int(a.get("deck_def_id", 0))
			var b_id := int(b.get("deck_def_id", 0))
			if a_id != b_id:
				return a_id < b_id
	var a_series := str(a.get("series_name", ""))
	var b_series := str(b.get("series_name", ""))
	if a_series == b_series:
		return str(a.get("deck_name", "")) < str(b.get("deck_name", ""))
	return a_series < b_series

func _on_color_filter_pressed(id: int) -> void:
	var current := bool(_selected_colors.get(id, true))
	_selected_colors[id] = not current
	render_decks()

func _on_sort_selected(index: int) -> void:
	_sort_mode = str(_sort_option.get_item_metadata(index))
	render_decks()

func _on_series_selected(index: int) -> void:
	_selected_series = str(_series_option.get_item_metadata(index))
	render_decks()

func _create_color_header(color_type: int, count: int) -> Control:
	var hdr = HBoxContainer.new()
	hdr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr.custom_minimum_size = Vector2(0, HEADER_HEIGHT)

	var color_name = CardColor.display_name(color_type)
	var color_label = Label.new()
	color_label.text = "■ " + Localization.t("ui.deck_collection.color_header", [color_name])
	color_label.add_theme_font_size_override("font_size", 16)
	# 粗体设置 — Godot 中无法直接用 bool 设置 bold，改用 add_theme_font_size_override 即可
	color_label.add_theme_color_override("font_color", _get_color_text(color_type))
	color_label.add_theme_constant_override("outline_size", 1)
	hdr.add_child(color_label)

	# 计数
	var count_label = Label.new()
	count_label.text = Localization.t("ui.deck_collection.kind_count", [count])
	count_label.add_theme_font_size_override("font_size", 13)
	count_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1.0))
	hdr.add_child(count_label)

	# 占满剩余空间
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr.add_child(spacer)

	return hdr

func _create_card_grid(relics: Array) -> Container:
	# 用 FlowContainer 自动换行
	var flow = FlowContainer.new()
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flow.add_theme_constant_override("h_separation", CARD_HORIZONTAL_SPACING)
	flow.add_theme_constant_override("v_separation", CARD_SPACING)

	for relic in relics:
		var card = _create_relic_card(relic)
		flow.add_child(card)

	return flow

func _create_relic_card(relic: Dictionary) -> Control:
	var color_type := int(relic.get("color", CardColor.ColorType.WHITE))
	if RelicView.supports_color(color_type):
		return _create_visual_relic_card(relic)

	var card_container = Control.new()
	card_container.custom_minimum_size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	card_container.size = Vector2(CARD_WIDTH, CARD_HEIGHT)

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

	return card_container

func _create_visual_relic_card(relic: Dictionary) -> Control:
	var color_type := int(relic.get("color", CardColor.ColorType.WHITE))
	if not RelicView.supports_color(color_type):
		return Control.new()
	var relic_height := get_viewport_rect().size.y * RELIC_SCREEN_HEIGHT_RATIO
	var relic_width := relic_height * THUMBNAIL_CACHE.get_aspect_ratio(color_type)
	var container := Control.new()
	container.name = "RelicCard%d" % color_type
	container.custom_minimum_size = Vector2(relic_width, relic_height + VISUAL_RELIC_LABEL_HEIGHT)
	container.size = container.custom_minimum_size
	container.mouse_filter = Control.MOUSE_FILTER_STOP

	var box := VBoxContainer.new()
	box.name = "RelicCardBox"
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.add_theme_constant_override("separation", 4)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(box)

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
	series_label.add_theme_color_override("font_color", Color(0.76, 0.80, 0.88, 0.9))
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
	name_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.62, 1.0))
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
	count_label.add_theme_color_override("font_color", Color(0.82, 0.70, 0.44, 0.95))
	count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label_box.add_child(count_label)

	var relic_host := Control.new()
	relic_host.name = "RelicHost"
	relic_host.custom_minimum_size = Vector2(relic_width, relic_height)
	relic_host.size = relic_host.custom_minimum_size
	box.add_child(relic_host)

	var cards := _get_relic_cards(relic)
	var thumbnail := TextureRect.new()
	thumbnail.name = "RelicThumbnail"
	thumbnail.set_anchors_preset(Control.PRESET_FULL_RECT)
	thumbnail.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumbnail.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	thumbnail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	thumbnail.texture = THUMBNAIL_CACHE.get_thumbnail_texture(
		color_type,
		str(relic.get("deck_def_key", "")),
		int(relic.get("deck_def_id", 0)),
		cards
	)
	relic_host.add_child(thumbnail)

	if thumbnail.texture == null:
		var relic_view := RELIC_VIEW_SCENE.instantiate() as RelicView
		if relic_view.set_relic_color(color_type):
			relic_view.name = "RelicView"
			relic_view.set_anchors_preset(Control.PRESET_FULL_RECT)
			relic_view.offset_left = 0.0
			relic_view.offset_top = 0.0
			relic_view.offset_right = 0.0
			relic_view.offset_bottom = 0.0
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

	return container

func _start_relic_view(relic: Dictionary, thumbnail: TextureRect, source_card: Control) -> void:
	if _view_state != ViewState.NONE or _view_busy:
		return
	_view_cards = _get_relic_cards(relic)
	_view_cancel_requested = false
	var relic_rect := thumbnail.get_global_rect()
	_view_color = int(relic.get("color", CardColor.ColorType.WHITE))
	_view_source_rect = relic_rect
	_view_source_card = source_card
	_view_source_card_modulate = _view_source_card.modulate
	_view_source_card.modulate.a = 0.0
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
	_view_overlay.add_child(_view_relic)

	_view_state = ViewState.RELIC_CENTERED
	_view_busy = true
	var target_center := Vector2(get_viewport_rect().size.x / 7.0, get_viewport_rect().size.y * 0.5)
	var tween := create_tween()
	tween.tween_property(_view_relic, "position", target_center - relic_rect.size * 0.5, VIEW_RELIC_MOVE_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
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
	var viewport_size := get_viewport_rect().size
	var card_size := Vector2(viewport_size.x * 0.105, viewport_size.x * 0.105 * CardDisplay.CARD_SIZE.y / CardDisplay.CARD_SIZE.x)
	card_size.y = minf(card_size.y, viewport_size.y * 0.34)
	card_size.x = card_size.y * CardDisplay.CARD_SIZE.x / CardDisplay.CARD_SIZE.y
	var start_center := Vector2(viewport_size.x / 7.0, viewport_size.y * 0.5)
	for index in range(mini(5, _view_cards.size())):
		var display := CardDisplayScript.new() as CardDisplay
		display.name = "MuseumViewedSubcard%d" % (index + 1)
		display.hover_uses_slot_bounds = false
		display.hover_scale_enabled = false
		display.is_draggable = false
		display.custom_minimum_size = card_size
		display.size = card_size
		display.position = start_center - card_size * 0.5
		display.modulate.a = 0.0
		_view_overlay.add_child(display)
		var source_card := _view_cards[index] as CardInfo
		display.set_card(_card_with_relic_color(source_card), index)
		_view_card_displays.append(display)
		var target_center := Vector2(viewport_size.x * float(index + 2) / 7.0, viewport_size.y * 0.5)
		var tween := create_tween()
		tween.tween_interval(float(index) * VIEW_CARD_INTERVAL_SECONDS)
		tween.tween_property(display, "position", target_center - card_size * 0.5, VIEW_CARD_MOVE_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
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
	tween.tween_property(_view_relic, "position", target_pos, VIEW_RELIC_MOVE_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
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
	if is_instance_valid(_view_source_card):
		_view_source_card.modulate = _view_source_card_modulate
	_view_source_card = null
	_view_source_card_modulate = Color.WHITE
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
	var deck_def_key := str(relic.get("deck_def_key", ""))
	var deck_def_id := int(relic.get("deck_def_id", 0))
	var cards: Array = CardDataManager.get_cards_by_deck_key(deck_def_key) if deck_def_key != "" else []
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
