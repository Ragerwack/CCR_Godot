extends RefCounted
class_name MuseumRelicThumbnailCache

const CACHE_VERSION := "v2_h720"
const CACHE_ROOT := "user://museum_relic_thumbnails/"
const THUMBNAIL_HEIGHT := 720
const CARD_ART_PREFIX := "res://Resources/Cards/"

static var _texture_cache: Dictionary = {}


static func get_thumbnail_texture(color_type: int, deck_key: String, deck_def_id: int, cards: Array) -> Texture2D:
	var cache_path := get_cache_path(color_type, deck_key, deck_def_id)
	if _texture_cache.has(cache_path):
		return _texture_cache[cache_path]
	if not FileAccess.file_exists(cache_path):
		var generated := generate_thumbnail(color_type, cache_path, cards)
		if generated == null:
			return null
		_texture_cache[cache_path] = generated
		return generated
	var image := Image.load_from_file(cache_path)
	if image == null or image.is_empty():
		var regenerated := generate_thumbnail(color_type, cache_path, cards)
		if regenerated == null:
			return null
		_texture_cache[cache_path] = regenerated
		return regenerated
	var texture := ImageTexture.create_from_image(image)
	_texture_cache[cache_path] = texture
	return texture


static func prewarm_thumbnail(color_type: int, deck_key: String, deck_def_id: int, series_name: String, deck_name: String) -> void:
	if not RelicView.supports_color(color_type):
		return
	var cache_path := get_cache_path(color_type, deck_key, deck_def_id)
	if _texture_cache.has(cache_path) or FileAccess.file_exists(cache_path):
		return
	var cards := _get_relic_cards(deck_key, deck_def_id, series_name, deck_name)
	if cards.is_empty():
		return
	get_thumbnail_texture(color_type, deck_key, deck_def_id, cards)


static func generate_thumbnail(color_type: int, cache_path: String, cards: Array) -> Texture2D:
	var layout := _load_layout(color_type)
	if layout.is_empty():
		return null
	var canvas: Dictionary = layout.get("canvas", {})
	var canvas_width := float(canvas.get("width", 793.0))
	var canvas_height := maxf(float(canvas.get("height", 1983.0)), 1.0)
	var thumb_height: int = THUMBNAIL_HEIGHT
	var thumb_width: int = max(1, roundi(float(thumb_height) * canvas_width / canvas_height))
	var output := Image.create(thumb_width, thumb_height, false, Image.FORMAT_RGBA8)
	output.fill(Color(0, 0, 0, 0))

	var cards_by_number: Dictionary = {}
	for card in cards:
		if card is CardInfo:
			cards_by_number[int(card.card_number)] = card

	var slot_data: Array = layout.get("slots", [])
	for index in range(slot_data.size()):
		var card: CardInfo = cards_by_number.get(index + 1)
		if card == null:
			continue
		var card_image := _load_card_image(card)
		if card_image == null or card_image.is_empty():
			continue
		var slot: Dictionary = slot_data[index]
		var dest := Rect2i(
			roundi(float(thumb_width) * float(slot.get("x_ratio", 0.0))),
			roundi(float(thumb_height) * float(slot.get("y_ratio", 0.0))),
			max(1, roundi(float(thumb_width) * float(slot.get("width_ratio", 0.0)))),
			max(1, roundi(float(thumb_height) * float(slot.get("height_ratio", 0.0))))
		)
		_blit_cover(output, card_image, dest)

	var frame_image := _load_frame_image(color_type)
	if frame_image != null and not frame_image.is_empty():
		frame_image.convert(Image.FORMAT_RGBA8)
		frame_image.resize(thumb_width, thumb_height, Image.INTERPOLATE_LANCZOS)
		output.blend_rect(frame_image, Rect2i(Vector2i.ZERO, frame_image.get_size()), Vector2i.ZERO)

	_ensure_cache_dir()
	var err := output.save_png(cache_path)
	if err != OK:
		FileLogger.warn("博物馆 relic 缩略图保存失败: " + cache_path + " err=" + str(err))
	var texture := ImageTexture.create_from_image(output)
	FileLogger.perf("museum_relic_thumbnail_generated", {"color": color_type, "path": cache_path, "width": thumb_width, "height": thumb_height, "saved": err == OK})
	return texture


static func _get_relic_cards(deck_key: String, deck_def_id: int, series_name: String, deck_name: String) -> Array:
	var cards: Array = CardDataManager.get_cards_by_deck_key(deck_key) if deck_key != "" else []
	if cards.is_empty():
		cards = CardDataManager.get_cards_by_deck_alias(series_name, deck_name)
	# 数据库关系 ID 不是稳定内容 ID，只作为旧数据完全缺少其他身份时的末级回退。
	if cards.is_empty() and deck_def_id > 0 and series_name == "" and deck_name == "":
		cards = CardDataManager.get_cards_by_deck_id(deck_def_id)
	var ordered := cards.duplicate()
	ordered.sort_custom(func(a: CardInfo, b: CardInfo): return a.card_number < b.card_number)
	return ordered.slice(0, mini(5, ordered.size()))


static func get_aspect_ratio(color_type: int) -> float:
	var layout := _load_layout(color_type)
	var canvas: Dictionary = layout.get("canvas", {})
	var width := float(canvas.get("width", 793.0))
	var height := maxf(float(canvas.get("height", 1983.0)), 1.0)
	return width / height


static func get_cache_path(color_type: int, deck_key: String, deck_def_id: int) -> String:
	var key := deck_key.strip_edges()
	if key == "":
		key = "deck_%d" % deck_def_id
	return CACHE_ROOT + CACHE_VERSION + "/" + _safe_key(str(color_type) + "_" + key) + ".png"


static func _load_layout(color_type: int) -> Dictionary:
	var layout_path := RelicView.get_layout_path(color_type)
	if layout_path == "":
		return {}
	var file := FileAccess.open(layout_path, FileAccess.READ)
	if file == null:
		FileLogger.warn("博物馆 relic 缩略图无法读取布局: " + layout_path)
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}


static func _load_frame_image(color_type: int) -> Image:
	var frame_path := RelicView.get_frame_path(color_type)
	if frame_path == "":
		return null
	var texture := ResourceLoader.load(frame_path, "Texture2D") as Texture2D
	return texture.get_image() if texture != null else null


static func _load_card_image(card: CardInfo) -> Image:
	var path := _resolve_card_art_path(card)
	if path == "":
		return null
	var texture := ResourceLoader.load(path, "Texture2D") as Texture2D
	return texture.get_image() if texture != null else null


static func _resolve_card_art_path(card: CardInfo) -> String:
	var explicit_path := _normalize_art_path(card.image_path)
	if explicit_path != "" and ResourceLoader.exists(explicit_path, "Texture2D"):
		return explicit_path
	var card_id := int(card.id)
	if card_id <= 0:
		return ""
	var base := "card_%03d" % card_id
	for extension: String in [".jpg", ".png", ".webp", ".jpeg"]:
		var path := CARD_ART_PREFIX + base + extension
		if ResourceLoader.exists(path, "Texture2D"):
			return path
	return ""


static func _normalize_art_path(raw_path: String) -> String:
	var path := raw_path.strip_edges()
	if path == "":
		return ""
	if path.begins_with("res://"):
		return path
	return CARD_ART_PREFIX + path.get_file()


static func _blit_cover(output: Image, source: Image, dest: Rect2i) -> void:
	var src := source.duplicate()
	src.convert(Image.FORMAT_RGBA8)
	var src_width: int = src.get_width()
	var src_height: int = src.get_height()
	var target_aspect := float(dest.size.x) / maxf(float(dest.size.y), 1.0)
	var src_aspect := float(src_width) / maxf(float(src_height), 1.0)
	var crop := Rect2i(Vector2i.ZERO, Vector2i(src_width, src_height))
	if src_aspect > target_aspect:
		var crop_width: int = max(1, roundi(float(src_height) * target_aspect))
		crop.position.x = max(0, (src_width - crop_width) / 2)
		crop.size.x = crop_width
	else:
		var crop_height: int = max(1, roundi(float(src_width) / target_aspect))
		crop.position.y = max(0, (src_height - crop_height) / 2)
		crop.size.y = crop_height
	var cropped: Image = src.get_region(crop)
	cropped.resize(dest.size.x, dest.size.y, Image.INTERPOLATE_LANCZOS)
	output.blend_rect(cropped, Rect2i(Vector2i.ZERO, cropped.get_size()), dest.position)


static func _ensure_cache_dir() -> void:
	var dir := DirAccess.open("user://")
	if dir == null:
		return
	dir.make_dir_recursive("museum_relic_thumbnails/" + CACHE_VERSION)


static func _safe_key(raw_key: String) -> String:
	var safe := ""
	for i in range(raw_key.length()):
		var code := raw_key.unicode_at(i)
		var ch := raw_key.substr(i, 1)
		var is_digit := code >= 48 and code <= 57
		var is_upper := code >= 65 and code <= 90
		var is_lower := code >= 97 and code <= 122
		if is_digit or is_upper or is_lower or ch == "_" or ch == "-":
			safe += ch
		else:
			safe += "_"
	return safe
