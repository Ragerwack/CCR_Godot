extends Control
class_name RelicView

const CCRVisualStyle = preload("res://Scripts/UI/CCRVisualStyle.gd")

const RELIC_CONFIGS := {
	CardColor.ColorType.WHITE: {
		"layout": "res://Resources/Relics/final/relic_white_layout.json",
		"frame": "res://Resources/Relics/final/relic_white_frame.png",
	},
	CardColor.ColorType.GREEN: {
		"layout": "res://Resources/Relics/final/relic_green_layout.json",
		"frame": "res://Resources/Relics/final/relic_green_frame.png",
	},
	CardColor.ColorType.BLUE: {
		"layout": "res://Resources/Relics/final/relic_blue_layout.json",
		"frame": "res://Resources/Relics/final/relic_blue_frame.png",
	},
	CardColor.ColorType.PURPLE: {
		"layout": "res://Resources/Relics/final/relic_purple_layout.json",
		"frame": "res://Resources/Relics/final/relic_purple_frame.png",
	},
	CardColor.ColorType.ORANGE: {
		"layout": "res://Resources/Relics/final/relic_orange_layout.json",
		"frame": "res://Resources/Relics/final/relic_orange_frame.png",
	},
	CardColor.ColorType.BLACK: {
		"layout": "res://Resources/Relics/final/relic_black_layout.json",
		"frame": "res://Resources/Relics/final/relic_black_frame.png",
	},
	CardColor.ColorType.RED: {
		"layout": "res://Resources/Relics/final/relic_red_layout.json",
		"frame": "res://Resources/Relics/final/relic_red_frame.png",
	},
}
const CARD_ART_PREFIX := "res://Resources/Cards/"
const DISPLAY_SCALE_CONFIG_PATH := "res://Resources/Relics/final/relic_display_scales.json"
const RELIC_VISIBLE_BOUNDS := {
	CardColor.ColorType.WHITE: {"height": 1983.0, "bottom": 1765.0},
	CardColor.ColorType.GREEN: {"height": 1983.0, "bottom": 1690.0},
	CardColor.ColorType.BLUE: {"height": 2170.0, "bottom": 2058.0},
	CardColor.ColorType.PURPLE: {"height": 1672.0, "bottom": 1437.0},
	CardColor.ColorType.ORANGE: {"height": 1672.0, "bottom": 1540.0},
	CardColor.ColorType.BLACK: {"height": 1672.0, "bottom": 1488.0},
	CardColor.ColorType.RED: {"height": 1672.0, "bottom": 1467.0},
}

static var _display_scale_cache: Dictionary = {}
static var _display_scale_loaded: bool = false

var _layout: Dictionary = {}
var _shadow_texture: TextureRect = null
var _slot_views: Array[TextureRect] = []
var _frame: TextureRect = null
var _pending_cards: Array = []
var _relic_color: int = CardColor.ColorType.WHITE


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = false
	_load_layout()
	_build_view()
	_apply_layout()
	if not _pending_cards.is_empty():
		set_cards(_pending_cards)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and not _slot_views.is_empty():
		_apply_layout()


func set_cards(cards: Array) -> void:
	_pending_cards = cards.duplicate()
	if _slot_views.is_empty():
		return
	var cards_by_number: Dictionary = {}
	for card in cards:
		if card is CardInfo:
			cards_by_number[int(card.card_number)] = card
	for index in range(_slot_views.size()):
		var card = cards_by_number.get(index + 1)
		_slot_views[index].texture = _load_card_texture(card) if card != null else null


func set_relic_color(color_type: int) -> bool:
	if not RELIC_CONFIGS.has(color_type):
		return false
	if _relic_color == color_type and not _layout.is_empty():
		return true
	_relic_color = color_type
	if is_node_ready():
		_rebuild_view()
	else:
		_load_layout()
	return true


func get_relic_color() -> int:
	return _relic_color


func get_aspect_ratio() -> float:
	var canvas: Dictionary = _layout.get("canvas", {})
	var width := float(canvas.get("width", 793.0))
	var height := maxf(float(canvas.get("height", 1983.0)), 1.0)
	return width / height


func get_label_layout() -> Dictionary:
	return _layout.get("label_layout", {}).duplicate(true)


static func supports_color(color_type: int) -> bool:
	return RELIC_CONFIGS.has(color_type)


static func get_layout_path(color_type: int) -> String:
	var config: Dictionary = RELIC_CONFIGS.get(color_type, {})
	return str(config.get("layout", ""))


static func get_frame_path(color_type: int) -> String:
	var config: Dictionary = RELIC_CONFIGS.get(color_type, {})
	return str(config.get("frame", ""))


static func get_display_scale(color_type: int) -> float:
	_ensure_display_scale_cache()
	var color_key := _color_key(color_type)
	return maxf(0.05, float(_display_scale_cache.get(color_key, 1.0)))


static func get_display_scales() -> Dictionary:
	_ensure_display_scale_cache()
	return _display_scale_cache.duplicate(true)


static func get_visible_bottom_ratio(color_type: int) -> float:
	var bounds: Dictionary = RELIC_VISIBLE_BOUNDS.get(color_type, {})
	var height := maxf(float(bounds.get("height", 1.0)), 1.0)
	return clampf((float(bounds.get("bottom", height - 1.0)) + 1.0) / height, 0.0, 1.0)


func clear_cards() -> void:
	for slot in _slot_views:
		slot.texture = null


func get_slot_count() -> int:
	return _slot_views.size()


func get_populated_slot_count() -> int:
	var count := 0
	for slot in _slot_views:
		if slot.texture != null:
			count += 1
	return count


func _load_layout() -> void:
	_layout.clear()
	var config: Dictionary = RELIC_CONFIGS.get(_relic_color, {})
	var layout_path := str(config.get("layout", ""))
	var file := FileAccess.open(layout_path, FileAccess.READ)
	if file == null:
		push_error("[RelicView] 无法读取布局: " + layout_path)
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		_layout = parsed
	else:
		push_error("[RelicView] 布局 JSON 无效: " + layout_path)


func _rebuild_view() -> void:
	for slot in _slot_views:
		if is_instance_valid(slot):
			slot.free()
	_slot_views.clear()
	if is_instance_valid(_shadow_texture):
		_shadow_texture.free()
	_shadow_texture = null
	if is_instance_valid(_frame):
		_frame.free()
	_frame = null
	_load_layout()
	_build_view()
	_apply_layout()
	set_cards(_pending_cards)


func _build_view() -> void:
	if _layout.is_empty():
		return
	for slot_data in _layout.get("slots", []):
		var slot := TextureRect.new()
		slot.name = "Slot%d" % int(slot_data.get("id", _slot_views.size() + 1))
		slot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		slot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.z_index = int(_layout.get("rendering", {}).get("slot_z_index", 0))
		_slot_views.append(slot)
		add_child(slot)

	_frame = TextureRect.new()
	_frame.name = "Frame"
	_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	_frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_frame.stretch_mode = TextureRect.STRETCH_SCALE
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.z_index = int(_layout.get("rendering", {}).get("frame_z_index", 10))
	var config: Dictionary = RELIC_CONFIGS.get(_relic_color, {})
	_frame.texture = load(str(config.get("frame", "")))
	_shadow_texture = CCRVisualStyle.make_texture_shadow(_frame, "RelicShadow", Vector2(12, 18), CCRVisualStyle.RELIC_SHADOW)
	_shadow_texture.z_index = -5
	add_child(_shadow_texture)
	add_child(_frame)


func _apply_layout() -> void:
	if _layout.is_empty() or size.x <= 0.0 or size.y <= 0.0:
		return
	var slot_data: Array = _layout.get("slots", [])
	for index in range(mini(_slot_views.size(), slot_data.size())):
		var data: Dictionary = slot_data[index]
		var slot := _slot_views[index]
		slot.position = Vector2(size.x * float(data.get("x_ratio", 0.0)), size.y * float(data.get("y_ratio", 0.0)))
		slot.size = Vector2(size.x * float(data.get("width_ratio", 0.0)), size.y * float(data.get("height_ratio", 0.0)))


func _load_card_texture(card: CardInfo):
	if card == null:
		return null
	var explicit_path := _normalize_art_path(card.image_path)
	if explicit_path != "" and ResourceLoader.exists(explicit_path, "Texture2D"):
		return ResourceLoader.load(explicit_path)
	var card_id := int(card.id)
	if card_id <= 0:
		return null
	var base := "card_%03d" % card_id
	for extension: String in [".jpg", ".png", ".webp", ".jpeg"]:
		var path: String = CARD_ART_PREFIX + base + extension
		if ResourceLoader.exists(path, "Texture2D"):
			return ResourceLoader.load(path)
	return null


func _normalize_art_path(raw_path: String) -> String:
	var path := raw_path.strip_edges()
	if path == "":
		return ""
	if path.begins_with("res://"):
		return path
	return CARD_ART_PREFIX + path.get_file()


static func _ensure_display_scale_cache() -> void:
	if _display_scale_loaded:
		return
	_display_scale_loaded = true
	_display_scale_cache = {
		"white": 1.0,
		"green": 1.0,
		"blue": 1.0,
		"purple": 1.0,
		"orange": 1.0,
		"black": 1.0,
		"red": 1.0,
	}
	var file := FileAccess.open(DISPLAY_SCALE_CONFIG_PATH, FileAccess.READ)
	if file == null:
		push_warning("[RelicView] 未找到圣物展示倍率配置，使用默认 1.0: " + DISPLAY_SCALE_CONFIG_PATH)
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_warning("[RelicView] 圣物展示倍率配置 JSON 无效，使用默认 1.0: " + DISPLAY_SCALE_CONFIG_PATH)
		return
	var scales = parsed.get("scales", {})
	if not scales is Dictionary:
		return
	for key in _display_scale_cache.keys():
		if scales.has(key):
			_display_scale_cache[key] = maxf(0.05, float(scales.get(key, 1.0)))


static func _color_key(color_type: int) -> String:
	match color_type:
		CardColor.ColorType.WHITE:
			return "white"
		CardColor.ColorType.GREEN:
			return "green"
		CardColor.ColorType.BLUE:
			return "blue"
		CardColor.ColorType.PURPLE:
			return "purple"
		CardColor.ColorType.ORANGE:
			return "orange"
		CardColor.ColorType.BLACK:
			return "black"
		CardColor.ColorType.RED:
			return "red"
		_:
			return "white"
