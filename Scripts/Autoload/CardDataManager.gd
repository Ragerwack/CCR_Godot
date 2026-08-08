extends Node

signal data_loaded
signal card_generated(card: CardInfo)

const CARD_DATA_PATH = "res://Resources/Cards/card-data.json"
const CARD_LOCALIZATION_PATH = "res://Resources/Cards/card-localization.json"

var all_series: Array[CardSeries] = []
var all_cards: Array[CardInfo] = []
var _card_localization: Dictionary = {}

var _series_by_name: Dictionary = {}
var _cards_by_series: Dictionary = {}
var _cards_by_deck: Dictionary = {}
var _cards_by_deck_id: Dictionary = {}
var _cards_by_deck_key: Dictionary = {}
var _cards_by_deck_alias: Dictionary = {}
var _cards_by_id: Dictionary = {}
var _cards_by_asset_key: Dictionary = {}

# 编号概率: 1号30%, 2号25%, 3号20%, 4号15%, 5号10%
const NUMBER_WEIGHTS: Array[float] = [30.0, 25.0, 20.0, 15.0, 10.0]

func _ready() -> void:
	load_card_data()

func load_card_data() -> bool:
	if not FileAccess.file_exists(CARD_DATA_PATH):
		push_error("Card data file not found: " + CARD_DATA_PATH)
		return false

	var file = FileAccess.open(CARD_DATA_PATH, FileAccess.READ)
	if file == null:
		push_error("Failed to open card data: " + str(FileAccess.get_open_error()))
		return false

	var json_str = file.get_as_text()
	file.close()

	var json = JSON.new()
	if json.parse(json_str) != OK:
		push_error("Failed to parse JSON")
		return false

	var data = json.get_data()
	_card_localization = _load_card_localization()
	# Support both: old flat { "cards": [...] } and new nested { "series": [...] }
	if data is Dictionary and data.has("series"):
		_parse_series_format(data["series"])
		data_loaded.emit()
		return true
	elif data is Dictionary and data.has("cards"):
		_parse_old_cards_format(data["cards"])
		data_loaded.emit()
		return true
	return false

func _load_card_localization() -> Dictionary:
	if not FileAccess.file_exists(CARD_LOCALIZATION_PATH):
		push_warning("Card localization file not found: " + CARD_LOCALIZATION_PATH)
		return {}
	var file := FileAccess.open(CARD_LOCALIZATION_PATH, FileAccess.READ)
	if file == null:
		push_warning("Failed to open card localization: " + str(FileAccess.get_open_error()))
		return {}
	var json := JSON.new()
	var parse_result := json.parse(file.get_as_text())
	file.close()
	if parse_result != OK or not (json.get_data() is Dictionary):
		push_warning("Failed to parse card localization: " + CARD_LOCALIZATION_PATH)
		return {}
	return json.get_data() as Dictionary

func _localization_entry(table_name: String, key: Variant) -> Dictionary:
	var table = _card_localization.get(table_name, {})
	if not table is Dictionary:
		return {}
	var entry = table.get(str(key), {})
	return entry as Dictionary if entry is Dictionary else {}

func _english_override(table_name: String, key: Variant) -> Dictionary:
	return _localization_entry(table_name, key)

func _build_localized_texts(series_id: int, deck_id: int, card_data: Dictionary, sname: String, sen: String, dname: String, den: String) -> Dictionary:
	var card_id := str(int(card_data.get("card_id", 0)))
	var texts: Dictionary = {
		"zh-CN": {
			"series_name": sname,
			"deck_name": dname,
			"card_name": str(card_data.get("name_zh", "")),
			"description": str(card_data.get("desc_zh", "")),
		},
		"en": {
			"series_name": sen,
			"deck_name": den,
			"card_name": str(card_data.get("name_en", "")),
			"description": str(card_data.get("desc_en", "")),
		},
		# 繁体中文按翻译标准由客户端的统一转换规则处理。
		"zh-TW": {
			"series_name": sname,
			"deck_name": dname,
			"card_name": str(card_data.get("name_zh", "")),
			"description": str(card_data.get("desc_zh", "")),
		},
	}

	var series_locales := _localization_entry("series", series_id)
	var deck_key := "%d:%d" % [series_id, deck_id]
	var deck_locales := _localization_entry("decks", deck_key)
	var card_locales := _localization_entry("cards", card_id)
	for locale_key in ["ja", "ko"]:
		texts[locale_key] = {
			"series_name": str(series_locales.get(locale_key, sname)),
			"deck_name": str(deck_locales.get(locale_key, dname)),
			"card_name": str(card_locales.get(locale_key, {}).get("name", card_data.get("name_en", ""))),
			"description": str(card_locales.get(locale_key, {}).get("description", card_data.get("desc_en", ""))),
		}

	var deck_english_overrides = _card_localization.get("english_deck_overrides", {})
	if deck_english_overrides is Dictionary and deck_english_overrides.has(deck_key):
		texts["en"]["deck_name"] = str(deck_english_overrides[deck_key])
	var card_english_override := _english_override("english_card_overrides", card_id)
	if not card_english_override.is_empty():
		if card_english_override.has("name"):
			texts["en"]["card_name"] = str(card_english_override["name"])
		if card_english_override.has("description"):
			texts["en"]["description"] = str(card_english_override["description"])
	return texts

# New 3-level format: series → decks → cards
func _parse_series_format(series_array: Array) -> void:
	all_cards.clear()
	all_series.clear()
	_series_by_name.clear()
	_cards_by_series.clear()
	_cards_by_deck.clear()
	_cards_by_deck_id.clear()
	_cards_by_deck_key.clear()
	_cards_by_deck_alias.clear()
	_cards_by_id.clear()
	_cards_by_asset_key.clear()
	var global_deck_def_id := 1

	for series_data in series_array:
		var series_id := int(series_data.get("series_id", 0))
		var sname = series_data.get("name_zh", "")
		var sen = series_data.get("name_en", "")
		var cat = series_data.get("category", "限时卡组")

		# Create CardSeries
		var cs = CardSeries.new({
			"type": cat,
			"series_name": sname,
			"series_style": sen,
		})

		# Process decks
		for deck_data in series_data.get("decks", []):
			var deck_id := int(deck_data.get("deck_id", 0))
			var dname = deck_data.get("name_zh", "")
			var den = deck_data.get("name_en", "")

			for card_data in deck_data.get("cards", []):
				var localized_texts := _build_localized_texts(series_id, deck_id, card_data, sname, sen, dname, den)
				var english_texts: Dictionary = localized_texts.get("en", {})
				var card = CardInfo.new({
					"id": str(int(card_data.get("card_id", 0))),
					"card_asset_id": int(card_data.get("number", 1)),
					"deck_asset_id": deck_id,
					"series_asset_id": series_id,
					"deck_definition_id": global_deck_def_id,
					"series_definition_id": series_id,
					"series_name": sname,
					"series_name_zh": sname,
					"series_name_en": sen,
					"deck_name": dname,
					"deck_name_cn": dname,
					"deck_name_zh": dname,
					"deck_name_en": str(english_texts.get("deck_name", den)),
					"card_number": int(card_data.get("number", 1)),
					"color": "白",  # 默认白色，抽卡时随机分配
					"card_name": card_data.get("name_zh", ""),
					"card_name_zh": card_data.get("name_zh", ""),
					"card_name_en": str(english_texts.get("card_name", card_data.get("name_en", ""))),
					"description": card_data.get("desc_zh", ""),
					"description_zh": card_data.get("desc_zh", ""),
					"description_en": str(english_texts.get("description", card_data.get("desc_en", ""))),
					"localized_texts": localized_texts,
					"image_path": card_data.get("image", ""),
					"type": cat,
					"series_style": sen,
				})
				all_cards.append(card)
				_cards_by_id[_normalized_card_id(card.id)] = card
				_cards_by_asset_key[_card_asset_key(series_id, deck_id, card.card_asset_id)] = card
				cs.add_card(card)

		all_series.append(cs)
		_series_by_name[sname] = cs
		if sen != "":
			_series_by_name[sen] = cs
		_cards_by_series[sname] = _filter_cards_by_series(sname)
		if sen != "":
			_cards_by_series[sen] = _filter_cards_by_series(sname)

		# Build deck-level lookup
		for deck_data in series_data.get("decks", []):
			var dn = deck_data.get("name_zh", "")
			var den = deck_data.get("name_en", "")
			var deck_cards = cs.get_deck_cards(dn)
			_cards_by_deck[sname + "/" + dn] = deck_cards
			if sen != "" and den != "":
				_cards_by_deck[sen + "/" + den] = deck_cards
			# JSON 的 deck_id 是系列内排序号，会在每个系列从 1 重新开始；
			# 服务端 DeckDef.id 则按种子文件遍历顺序全局生成。
			_cards_by_deck_id[global_deck_def_id] = deck_cards
			var deck_key := _make_deck_key(sen, str(deck_data.get("name_en", "")))
			if deck_key != "":
				_cards_by_deck_key[deck_key] = deck_cards
			global_deck_def_id += 1
	_rebuild_deck_alias_lookup()

func _filter_cards_by_series(series_name: String) -> Array[CardInfo]:
	var out: Array[CardInfo] = []
	for c in all_cards:
		if c.series_name == series_name:
			out.append(c)
	return out

# Old flat format: { "cards": [ { "series_name":..., "deck_name":..., ... } ] }
func _parse_old_cards_format(cards_array: Array) -> void:
	all_cards.clear()
	all_series.clear()
	_series_by_name.clear()
	_cards_by_series.clear()
	_cards_by_deck.clear()
	_cards_by_deck_id.clear()
	_cards_by_deck_key.clear()
	_cards_by_deck_alias.clear()
	_cards_by_id.clear()
	_cards_by_asset_key.clear()

	var series_map: Dictionary = {}

	for card_data in cards_array:
		var card = CardInfo.new(card_data)
		all_cards.append(card)
		_cards_by_id[_normalized_card_id(card.id)] = card
		if card.series_asset_id > 0 and card.deck_asset_id > 0 and card.card_asset_id > 0:
			_cards_by_asset_key[_card_asset_key(card.series_asset_id, card.deck_asset_id, card.card_asset_id)] = card

		if not series_map.has(card.series_name):
			series_map[card.series_name] = {
				"type": card.type,
				"series_name": card.series_name,
				"series_style": card.series_style,
				"decks": {}
			}

		var s = series_map[card.series_name]
		if not s["decks"].has(card.deck_name):
			s["decks"][card.deck_name] = []
		s["decks"][card.deck_name].append(card)

	for series_name in series_map:
		var sdata = series_map[series_name]
		var cs = CardSeries.new(sdata)
		all_series.append(cs)
		_series_by_name[series_name] = cs
		_cards_by_series[series_name] = all_cards.filter(func(c): return c.series_name == series_name)

		for deck_name in cs.get_deck_names():
			var key = series_name + "/" + deck_name
			_cards_by_deck[key] = cs.get_deck_cards(deck_name)
	_rebuild_deck_alias_lookup()

func get_all_series() -> Array[CardSeries]:
	return all_series

func get_series_by_name(name: String) -> CardSeries:
	return _series_by_name.get(name)

func get_cards_by_series(series_name: String) -> Array[CardInfo]:
	return _to_card_info_array(_cards_by_series.get(series_name, []))

func get_cards_by_deck(series_name: String, deck_name: String) -> Array[CardInfo]:
	var key = series_name + "/" + deck_name
	return _to_card_info_array(_cards_by_deck.get(key, []))

func get_cards_by_deck_id(deck_def_id: int) -> Array[CardInfo]:
	return _to_card_info_array(_cards_by_deck_id.get(deck_def_id, []))

func get_cards_by_asset_ids(series_asset_id: int, deck_asset_id: int) -> Array[CardInfo]:
	var cards: Array[CardInfo] = []
	if series_asset_id <= 0 or deck_asset_id <= 0:
		return cards
	for card_number in range(1, 6):
		var source = _cards_by_asset_key.get(_card_asset_key(series_asset_id, deck_asset_id, card_number))
		if source is CardInfo:
			cards.append(_localized_card_info(source as CardInfo))
	return cards

func _card_asset_key(series_asset_id: int, deck_asset_id: int, card_asset_id: int) -> String:
	return "%d:%d:%d" % [series_asset_id, deck_asset_id, card_asset_id]

func get_cards_by_deck_key(deck_def_key: String) -> Array[CardInfo]:
	return _to_card_info_array(_cards_by_deck_key.get(deck_def_key.strip_edges().to_lower(), []))

## 生产数据库的自增 ID 会在重新 seed 后继续增长，不能假设它永远等于
## 客户端静态资源的 1..68。服务端尚未返回 deck_def_key 的旧接口，使用
## 系列名 + 卡组名的任一已知语言作为兼容定位，随后仍按卡内编号 1..5 取卡。
func get_cards_by_deck_alias(series_name: String, deck_name: String) -> Array[CardInfo]:
	return _to_card_info_array(_cards_by_deck_alias.get(_deck_alias_key(series_name, deck_name), []))

func _rebuild_deck_alias_lookup() -> void:
	_cards_by_deck_alias.clear()
	for card in all_cards:
		if card == null:
			continue
		_register_deck_alias(card.series_name, card.deck_name, card)
		_register_deck_alias(card.series_name_zh, card.deck_name_zh, card)
		_register_deck_alias(card.series_name_en, card.deck_name_en, card)
		for locale_texts in card.localized_texts.values():
			if locale_texts is Dictionary:
				_register_deck_alias(
					str(locale_texts.get("series_name", "")),
					str(locale_texts.get("deck_name", "")),
					card
				)

func _register_deck_alias(series_name: String, deck_name: String, card: CardInfo) -> void:
	var alias_key := _deck_alias_key(series_name, deck_name)
	if alias_key == "" or card == null:
		return
	var cards: Array = _cards_by_deck_alias.get(alias_key, [])
	if not cards.has(card):
		cards.append(card)
	_cards_by_deck_alias[alias_key] = cards

func _deck_alias_key(series_name: String, deck_name: String) -> String:
	var series_alias := _normalize_text_alias(series_name)
	var deck_alias := _normalize_text_alias(deck_name)
	if series_alias == "" or deck_alias == "":
		return ""
	return series_alias + "\u001f" + deck_alias

func _normalize_text_alias(value: String) -> String:
	var normalized := value.strip_edges().to_lower()
	normalized = normalized.replace("’", "'").replace("‘", "'")
	normalized = normalized.replace("–", "-").replace("—", "-")
	var whitespace := RegEx.new()
	whitespace.compile("\\s+")
	return whitespace.sub(normalized, " ", true)

func _make_deck_key(series_name_en: String, deck_name_en: String) -> String:
	var normalized := (series_name_en + "__" + deck_name_en).strip_edges().to_lower()
	var whitespace := RegEx.new()
	whitespace.compile("\\s+")
	normalized = whitespace.sub(normalized, "_", true)
	var invalid_chars := RegEx.new()
	invalid_chars.compile("[^a-z0-9_]")
	return invalid_chars.sub(normalized, "", true)

func _to_card_info_array(value: Variant) -> Array[CardInfo]:
	# Dictionary.get() 的静态返回类型是 Variant；即使字典中保存的是卡牌数组，
	# 直接从强类型函数返回仍会在运行时被 Godot 视为普通 Array 并抛错。
	var cards: Array[CardInfo] = []
	if value is Array:
		for card in value:
			if card is CardInfo:
				cards.append(_localized_card_info(card))
	return cards

func _localized_card_info(card: CardInfo) -> CardInfo:
	if card == null:
		return null
	var copy := CardInfo.new(card.to_dict())
	return localize_card_in_place(copy)

## 使用本地静态定义补全卡牌的多语言字段，并按当前语言刷新运行时显示文本。
## 资产身份、颜色、槽位和实例引用都保持不变；因此语言切换不会制造新的卡牌对象。
func localize_card_in_place(card: CardInfo) -> CardInfo:
	if card == null:
		return null
	var source := _canonical_card_for(card)
	if source != null:
		card.image_path = source.image_path
		if source.series_name_zh != "":
			card.series_name_zh = source.series_name_zh
		if source.series_name_en != "":
			card.series_name_en = source.series_name_en
		if source.deck_name_zh != "":
			card.deck_name_zh = source.deck_name_zh
			card.deck_name_cn = source.deck_name_zh
		if source.deck_name_en != "":
			card.deck_name_en = source.deck_name_en
		if source.card_name_zh != "":
			card.card_name_zh = source.card_name_zh
		if source.card_name_en != "":
			card.card_name_en = source.card_name_en
		if source.description_zh != "":
			card.description_zh = source.description_zh
		if source.description_en != "":
			card.description_en = source.description_en
		for locale_key in source.localized_texts.keys():
			if not card.localized_texts.has(locale_key):
				card.localized_texts[locale_key] = (source.localized_texts[locale_key] as Dictionary).duplicate(true)
		# 服务端响应按请求语言只带一套文案。生产 locale 尚未 seed、网络响应
		# 跨越语言切换，或数据库自增 ID 与客户端静态 ID 错位时，响应里的
		# “当前语言”可能仍是英文。已知 340 张卡直接以正式客户端资源为准；
		# 本地没有定义的未来卡牌因 source 为 null，仍保留服务端原文。
		_merge_known_localized_text(source, card)

	var exact_texts: Dictionary = card.localized_texts.get(Localization.locale, {})
	if Localization.uses_english_content():
		card.series_name = _prefer_localized_text(str(exact_texts.get("series_name", "")), card.series_name_en, _prefer_localized_text(card.series_name_zh, card.series_name, ""))
		card.deck_name = _prefer_localized_text(str(exact_texts.get("deck_name", "")), card.deck_name_en, _prefer_localized_text(card.deck_name_zh, card.deck_name, ""))
		card.card_name = _prefer_localized_text(str(exact_texts.get("card_name", "")), card.card_name_en, _prefer_localized_text(card.card_name_zh, card.card_name, ""))
		card.description = _prefer_localized_text(str(exact_texts.get("description", "")), card.description_en, _prefer_localized_text(card.description_zh, card.description, ""))
	else:
		card.series_name = _prefer_localized_text(str(exact_texts.get("series_name", "")), card.series_name_zh, _prefer_localized_text(card.series_name_en, card.series_name, ""))
		card.deck_name = _prefer_localized_text(str(exact_texts.get("deck_name", "")), card.deck_name_zh, _prefer_localized_text(card.deck_name_en, card.deck_name, ""))
		card.card_name = _prefer_localized_text(str(exact_texts.get("card_name", "")), card.card_name_zh, _prefer_localized_text(card.card_name_en, card.card_name, ""))
		card.description = _prefer_localized_text(str(exact_texts.get("description", "")), card.description_zh, _prefer_localized_text(card.description_en, card.description, ""))
	if Localization.locale == "zh-TW":
		card.series_name = Localization.to_traditional_chinese(card.series_name)
		card.deck_name = Localization.to_traditional_chinese(card.deck_name)
		card.card_name = Localization.to_traditional_chinese(card.card_name)
		card.description = Localization.to_traditional_chinese(card.description)
	return card

func _merge_known_localized_text(source: CardInfo, card: CardInfo) -> void:
	if source == null or card == null:
		return
	var target_locale := Localization.locale
	var source_target: Dictionary = source.localized_texts.get(target_locale, {})
	if source_target.is_empty():
		return
	card.localized_texts[target_locale] = source_target.duplicate(true)

## 圣物对象只保存当前显示语言。通过稳定 deck_def_id / deck_def_key 回查本地卡牌定义，
## 让博物馆和个人生涯在语言切换后无需等待网络即可重建正确标题。
func localize_deck_in_place(deck: Deck) -> Deck:
	if deck == null:
		return null
	# 生产数据库重复 seed 后，DeckDef.id 可能与客户端静态 1..68 顺序错位。
	# 圣物响应已经带有系列名和卡组名，因此先按五语种别名定位；稳定 key 次之，
	# 数字 ID 只在身份文字也吻合（或完全没有身份文字）时才允许回退。
	var source: CardInfo = null
	if deck.series_asset_id > 0 and deck.deck_asset_id > 0:
		source = _cards_by_asset_key.get(_card_asset_key(deck.series_asset_id, deck.deck_asset_id, 1)) as CardInfo
	if source == null:
		source = _canonical_card_for_aliases(deck.series_name, deck.deck_name, 1)
	if source == null and deck.deck_def_key != "":
		source = _canonical_card_for_deck(0, deck.deck_def_key)
	if source == null and deck.deck_def_id > 0:
		var id_source := _canonical_card_for_deck(deck.deck_def_id, "")
		if id_source != null and (not _deck_has_identity_text(deck) or _source_matches_deck_identity(id_source, deck)):
			source = id_source
	if source == null:
		return deck
	var exact_texts: Dictionary = source.localized_texts.get(Localization.locale, {})
	if not exact_texts.is_empty():
		deck.series_name = _prefer_localized_text(str(exact_texts.get("series_name", "")), deck.series_name, deck.series_name)
		deck.deck_name = _prefer_localized_text(str(exact_texts.get("deck_name", "")), deck.deck_name, deck.deck_name)
	elif Localization.uses_english_content():
		deck.series_name = _prefer_localized_text(source.series_name_en, source.series_name_zh, deck.series_name)
		deck.deck_name = _prefer_localized_text(source.deck_name_en, source.deck_name_zh, deck.deck_name)
	else:
		deck.series_name = _prefer_localized_text(source.series_name_zh, source.series_name_en, deck.series_name)
		deck.deck_name = _prefer_localized_text(source.deck_name_zh, source.deck_name_en, deck.deck_name)
	if Localization.locale == "zh-TW":
		deck.series_name = Localization.to_traditional_chinese(deck.series_name)
		deck.deck_name = Localization.to_traditional_chinese(deck.deck_name)
	return deck

func _deck_has_identity_text(deck: Deck) -> bool:
	return deck != null and (
		deck.series_name.strip_edges() != ""
		or deck.deck_name.strip_edges() != ""
	)

func _source_matches_deck_identity(source: CardInfo, deck: Deck) -> bool:
	if source == null or deck == null:
		return false
	if deck.series_name != "" and not _source_has_text(source, "series_name", deck.series_name):
		return false
	if deck.deck_name != "" and not _source_has_text(source, "deck_name", deck.deck_name):
		return false
	return true

func _canonical_card_for(card: CardInfo) -> CardInfo:
	# 正式契约使用语言无关的内容资产 ID；数据库关系 ID 与名称只用于兼容旧缓存。
	if card.series_asset_id > 0 and card.deck_asset_id > 0 and card.card_asset_id > 0:
		var asset_source = _cards_by_asset_key.get(_card_asset_key(card.series_asset_id, card.deck_asset_id, card.card_asset_id))
		if asset_source is CardInfo:
			return asset_source as CardInfo
	# 优先使用服务端返回的系列名/卡组名/编号。生产数据库重复 seed 后，
	# CardDef.id / DeckDef.id 会继续自增，可能与客户端静态顺序完全不同；
	# 数字 ID 只能在名称也吻合或没有名称元数据时作为兼容回退。
	var source := _canonical_card_for_aliases(card.series_name, card.deck_name, card.card_number)
	if source != null:
		return source
	for locale_texts in card.localized_texts.values():
		if not locale_texts is Dictionary:
			continue
		source = _canonical_card_for_aliases(
			str(locale_texts.get("series_name", "")),
			str(locale_texts.get("deck_name", "")),
			card.card_number
		)
		if source != null:
			return source

	var id_key := _normalized_card_id(card.id)
	if id_key != "" and _cards_by_id.has(id_key):
		source = _cards_by_id[id_key] as CardInfo
		if not _card_has_identity_text(card) or _source_matches_card_identity(source, card):
			return source
	source = _canonical_card_for_deck(card.deck_definition_id, "", card.card_number)
	if source != null and (not _card_has_identity_text(card) or _source_matches_card_identity(source, card)):
		return source
	return null

func _canonical_card_for_aliases(series_name: String, deck_name: String, card_number: int) -> CardInfo:
	var candidates: Array = _cards_by_deck_alias.get(_deck_alias_key(series_name, deck_name), [])
	for candidate in candidates:
		if candidate is CardInfo and (card_number <= 0 or candidate.card_number == card_number):
			return candidate as CardInfo
	return null

func _card_has_identity_text(card: CardInfo) -> bool:
	return (
		card.series_name.strip_edges() != ""
		or card.deck_name.strip_edges() != ""
		or card.card_name.strip_edges() != ""
	)

func _source_matches_card_identity(source: CardInfo, card: CardInfo) -> bool:
	if source == null or card == null:
		return false
	if card.card_number > 0 and source.card_number != card.card_number:
		return false
	if card.series_name != "" and not _source_has_text(source, "series_name", card.series_name):
		return false
	if card.deck_name != "" and not _source_has_text(source, "deck_name", card.deck_name):
		return false
	if card.card_name != "" and not _source_has_text(source, "card_name", card.card_name):
		return false
	return true

func _source_has_text(source: CardInfo, field: String, value: String) -> bool:
	var expected := _normalize_text_alias(value)
	if expected == "":
		return true
	var candidates: Array[String] = []
	match field:
		"series_name":
			candidates.assign([source.series_name, source.series_name_zh, source.series_name_en])
		"deck_name":
			candidates.assign([source.deck_name, source.deck_name_zh, source.deck_name_en])
		"card_name":
			candidates.assign([source.card_name, source.card_name_zh, source.card_name_en])
	for locale_texts in source.localized_texts.values():
		if locale_texts is Dictionary:
			candidates.append(str(locale_texts.get(field, "")))
	for candidate in candidates:
		if _normalize_text_alias(candidate) == expected:
			return true
	return false

func _canonical_card_for_deck(deck_def_id: int, deck_def_key: String = "", card_number: int = 1) -> CardInfo:
	var candidates: Array = []
	if deck_def_key != "":
		candidates = _cards_by_deck_key.get(deck_def_key.strip_edges().to_lower(), [])
	if candidates.is_empty() and deck_def_id > 0:
		candidates = _cards_by_deck_id.get(deck_def_id, [])
	for candidate in candidates:
		if candidate is CardInfo and (card_number <= 0 or candidate.card_number == card_number):
			return candidate as CardInfo
	for candidate in candidates:
		if candidate is CardInfo:
			return candidate as CardInfo
	return null

func _normalized_card_id(value: Variant) -> String:
	var raw := str(value).strip_edges()
	if raw.is_valid_int():
		return str(int(raw))
	return raw

func _prefer_localized_text(primary: String, fallback: String, existing: String) -> String:
	if primary != "":
		return primary
	if fallback != "":
		return fallback
	return existing

# 生成随机颜色
func roll_color() -> CardColor.ColorType:
	var total_weight = 0.0
	for w in CardColor.COLOR_WEIGHTS:
		total_weight += w
	var roll = randf() * total_weight
	var cumulative = 0.0
	for i in range(CardColor.COLOR_WEIGHTS.size()):
		cumulative += CardColor.COLOR_WEIGHTS[i]
		if roll <= cumulative:
			return i as CardColor.ColorType
	return CardColor.ColorType.WHITE

# 生成随机编号
func roll_card_number() -> int:
	var total = 0.0
	for w in NUMBER_WEIGHTS:
		total += w
	var roll = randf() * total
	var cumulative = 0.0
	for i in range(NUMBER_WEIGHTS.size()):
		cumulative += NUMBER_WEIGHTS[i]
		if roll <= cumulative:
			return i + 1
	return 1

# 从指定系列/卡组生成随机卡
func generate_card_from_deck(series_name: String, deck_name: String) -> CardInfo:
	var cards = get_cards_by_deck(series_name, deck_name)
	if cards.is_empty():
		return null
	var color = roll_color()
	var number = roll_card_number()
	for c in cards:
		if c.card_number == number:
			var new_card = CardInfo.new(c.to_dict())
			new_card.color = color
			return new_card
	var base_card = cards[randi() % cards.size()]
	var new_card2 = CardInfo.new(base_card.to_dict())
	new_card2.color = color
	return new_card2

# 填充卡池
func fill_pool(pool_size: int, visible_series: Array[String] = []) -> Array[CardInfo]:
	var result: Array[CardInfo] = []
	var series_to_use = visible_series if not visible_series.is_empty() else Array(_series_by_name.keys())
	for i in range(pool_size):
		if series_to_use.is_empty():
			break
		var sname = series_to_use[randi() % series_to_use.size()]
		var cs = _series_by_name.get(sname)
		if cs == null:
			continue
		var deck_names = cs.get_deck_names()
		if deck_names.is_empty():
			continue
		var dname = deck_names[randi() % deck_names.size()]
		var card = generate_card_from_deck(sname, dname)
		if card != null:
			result.append(card)
	return result
