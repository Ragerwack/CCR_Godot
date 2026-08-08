class_name CardInfo
extends RefCounted

var id: String
# 服务器数据库关系 ID（用于资产指令回传）与稳定内容资产 ID 必须分离。
# 后三者组成客户端本地化主键，不受数据库重建、自增值或语言影响。
var card_asset_id: int = 0
var deck_asset_id: int = 0
var series_asset_id: int = 0
var deck_definition_id: int = 0
var series_definition_id: int = 0
var instance_id: String = ""
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
## 已由服务端或本地静态定义提供的逐 locale 文案。键使用 zh-CN / en / zh-TW / ja / ko。
## 普通运行时字段仍保存当前显示值，避免改动现有卡牌系统接口。
var localized_texts: Dictionary = {}
var image_path: String
var type: String           # "基本卡组" or "限时卡组"
var series_style: String

func _init(data: Dictionary = {}):
	id = data.get("id", "")
	card_asset_id = int(data.get("card_asset_id", data.get("card_number", 0)))
	deck_asset_id = int(data.get("deck_asset_id", 0))
	series_asset_id = int(data.get("series_asset_id", 0))
	deck_definition_id = int(data.get("deck_definition_id", data.get("deck_def_id", 0)))
	series_definition_id = int(data.get("series_definition_id", data.get("series_id", 0)))
	instance_id = str(data.get("instance_id", ""))
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
	var provided_localized_texts = data.get("localized_texts", {})
	if provided_localized_texts is Dictionary:
		localized_texts = provided_localized_texts.duplicate(true)
	var has_explicit_zh := data.has("series_name_zh") or data.has("deck_name_zh") or data.has("card_name_zh") or data.has("description_zh")
	if not localized_texts.has("zh-CN") and has_explicit_zh:
		localized_texts["zh-CN"] = {
			"series_name": series_name_zh,
			"deck_name": deck_name_zh,
			"card_name": card_name_zh,
			"description": description_zh,
		}
	var has_explicit_en := data.has("series_name_en") or data.has("deck_name_en") or data.has("card_name_en") or data.has("description_en")
	if not localized_texts.has("en") and has_explicit_en:
		localized_texts["en"] = {
			"series_name": series_name_en,
			"deck_name": deck_name_en,
			"card_name": card_name_en,
			"description": description_en,
		}
	image_path = data.get("image_path", data.get("image", data.get("image_url", "")))
	type = data.get("type", "限时卡组")
	series_style = data.get("series_style", "")

func to_dict() -> Dictionary:
	return {
		"id": id,
		"card_asset_id": card_asset_id,
		"deck_asset_id": deck_asset_id,
		"series_asset_id": series_asset_id,
		"deck_definition_id": deck_definition_id,
		"series_definition_id": series_definition_id,
		"instance_id": instance_id,
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
		"localized_texts": localized_texts.duplicate(true),
		"image_path": image_path,
		"type": type,
		"series_style": series_style,
	}

func get_full_name() -> String:
	return "%s-%s[%d]" % [deck_name, card_name, card_number]

# 唯一标识: series_deck_number_color
func get_uid() -> String:
	return "%s_%s_%d_%d" % [series_name, deck_name, card_number, color]

## 当前服务端 PlayerCards 是槽位模型，没有跨槽位稳定的资产实例 ID。
## 教程使用定义 ID、颜色和编号组成兼容引用；未来服务端补齐实例 ID 后优先使用它。
func get_instance_ref() -> String:
	if not instance_id.is_empty():
		return instance_id
	return "card_def:%s:%s:%d" % [id, CardColor.to_api_string(color), card_number]
