class_name CardInfo
extends RefCounted

var id: String
var series_name: String
var deck_name: String
var deck_name_cn: String   # 中文卡组名（后端新增）
var card_number: int       # 1-5
var color: CardColor.ColorType
var card_name: String
var description: String
var type: String           # "基本卡组" or "限时卡组"
var series_style: String

func _init(data: Dictionary = {}):
	id = data.get("id", "")
	series_name = data.get("series_name", "")
	deck_name = data.get("deck_name", "")
	deck_name_cn = data.get("deck_name_cn", "")
	card_number = data.get("card_number", 1)
	var color_str = data.get("color", "白")
	if color_str is int:
		color = color_str as CardColor.ColorType
	else:
		color = CardColor.from_string(str(color_str))
	card_name = data.get("card_name", "")
	description = data.get("description", "")
	type = data.get("type", "限时卡组")
	series_style = data.get("series_style", "")

func to_dict() -> Dictionary:
	return {
		"id": id,
		"series_name": series_name,
		"deck_name": deck_name,
		"deck_name_cn": deck_name_cn,
		"card_number": card_number,
		"color": color,
		"card_name": card_name,
		"description": description,
		"type": type,
		"series_style": series_style,
	}

func get_full_name() -> String:
	return "%s-%s[%d]" % [deck_name, card_name, card_number]

# 唯一标识: series_deck_number_color
func get_uid() -> String:
	return "%s_%s_%d_%d" % [series_name, deck_name, card_number, color]
