extends Control
class_name DeckCollectionUI

# 博物馆 — 展示所有已合成圣物，按颜色分组

const CARDS_PER_ROW: int = 6
const CARD_WIDTH: float = 150.0
const CARD_HEIGHT: float = 200.0
const CARD_SPACING: float = 24.0
const SECTION_SPACING: float = 20.0
const HEADER_HEIGHT: float = 32.0

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

func _ready() -> void:
	setup_ui()
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
	_scroll_container.offset_top = 50
	_scroll_container.offset_bottom = 0
	_scroll_container.offset_left = 10
	_scroll_container.offset_right = -10
	add_child(_scroll_container)

	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", SECTION_SPACING)
	_scroll_container.add_child(_content)

func render_decks() -> void:
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
	var groups: Dictionary = {}  # CardColor.ColorType -> Array[Dictionary]
	for relic in relics:
		var color_type: int = int(relic.get("color", CardColor.ColorType.WHITE))
		if not groups.has(color_type):
			groups[color_type] = []
		groups[color_type].append(relic)

	for color_type in groups.keys():
		groups[color_type].sort_custom(_sort_relics_by_name)

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
	for d in decks:
		var key := "%s|%s|%d" % [d.series_name, d.deck_name, int(d.color)]
		if not by_key.has(key):
			by_key[key] = {
				"id": d.id,
				"series_name": d.series_name,
				"deck_name": d.deck_name,
				"color": int(d.color),
				"count": 0,
				"combat_power": d.combat_power,
			}
		by_key[key]["count"] = int(by_key[key]["count"]) + 1
		by_key[key]["combat_power"] = max(int(by_key[key]["combat_power"]), d.combat_power)

	var relics: Array[Dictionary] = []
	for key in by_key.keys():
		relics.append(by_key[key])
	return relics

func _sort_relics_by_name(a: Dictionary, b: Dictionary) -> bool:
	var a_series := str(a.get("series_name", ""))
	var b_series := str(b.get("series_name", ""))
	if a_series == b_series:
		return str(a.get("deck_name", "")) < str(b.get("deck_name", ""))
	return a_series < b_series

func _create_color_header(color_type: int, count: int) -> Control:
	var hdr = HBoxContainer.new()
	hdr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr.custom_minimum_size = Vector2(0, HEADER_HEIGHT)

	var color_name = CardColor.get_name(color_type)
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
	flow.add_theme_constant_override("h_separation", CARD_SPACING)
	flow.add_theme_constant_override("v_separation", CARD_SPACING)

	for relic in relics:
		var card = _create_relic_card(relic)
		flow.add_child(card)

	return flow

func _create_relic_card(relic: Dictionary) -> Control:
	var card_container = Control.new()
	card_container.custom_minimum_size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	card_container.size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	var color_type := int(relic.get("color", CardColor.ColorType.WHITE))

	# 当前暂无圣物专有图片，先用颜色矩形占位；后续美术图实装时替换这一层。
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
