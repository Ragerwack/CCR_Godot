class_name CardInfo
extends RefCounted

var id: String
var series_name: String
var series_name_zh: String
var series_name_en: String
var deck_name: String
var deck_name_cn: String   # 中文卡组名（后端新增）
var deck_name_zh: String
var deck_name_en: String
var card_number: int       # 1-5
var color: CardColor.ColorType
var card_name: String
var card_name_zh: String
var card_name_en: String
var description: String
var description_zh: String
var description_en: String
var image_path: String
var type: String           # "基本卡组" or "限时卡组"
var series_style: String

func _init(data: Dictionary = {}):
	id = data.get("id", "")
	series_name = data.get("series_name", "")
	series_name_zh = data.get("series_name_zh", series_name)
	series_name_en = data.get("series_name_en", "")
	deck_name = data.get("deck_name", "")
	deck_name_cn = data.get("deck_name_cn", "")
	deck_name_zh = data.get("deck_name_zh", deck_name_cn if deck_name_cn != "" else deck_name)
	deck_name_en = data.get("deck_name_en", "")
	card_number = data.get("card_number", 1)
	var color_str = data.get("color", "白")
	if color_str is int:
		color = color_str as CardColor.ColorType
	else:
		color = CardColor.from_string(str(color_str))
	card_name = data.get("card_name", "")
	card_name_zh = data.get("card_name_zh", card_name)
	card_name_en = data.get("card_name_en", "")
	description = data.get("description", "")
	description_zh = data.get("description_zh", description)
	description_en = data.get("description_en", "")
	image_path = data.get("image_path", data.get("image", data.get("image_url", "")))
	type = data.get("type", "限时卡组")
	series_style = data.get("series_style", "")

func to_dict() -> Dictionary:
	return {
		"id": id,
		"series_name": series_name,
		"series_name_zh": series_name_zh,
		"series_name_en": series_name_en,
		"deck_name": deck_name,
		"deck_name_cn": deck_name_cn,
		"deck_name_zh": deck_name_zh,
		"deck_name_en": deck_name_en,
		"card_number": card_number,
		"color": color,
		"card_name": card_name,
		"card_name_zh": card_name_zh,
		"card_name_en": card_name_en,
		"description": description,
		"description_zh": description_zh,
		"description_en": description_en,
		"image_path": image_path,
		"type": type,
		"series_style": series_style,
	}

func get_full_name() -> String:
	return "%s-%s[%d]" % [deck_name, card_name, card_number]

# 唯一标识: series_deck_number_color
func get_uid() -> String:
	return "%s_%s_%d_%d" % [series_name, deck_name, card_number, color]
