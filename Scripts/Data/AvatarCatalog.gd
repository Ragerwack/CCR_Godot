class_name AvatarCatalog
extends RefCounted

## P1 头像目录只包含 CCR 原生基础头像。服务器保存稳定 ID，不保存客户端资源路径。
const DEFAULT_AVATAR_ID := "basic.north_star"
const AVATARS: Array[Dictionary] = [
	{"id": "basic.north_star", "name_key": "ui.profile.avatar.north_star", "path": "res://Resources/Avatars/Basic/01_北极星徽章.png"},
	{"id": "basic.moon_phase", "name_key": "ui.profile.avatar.moon_phase", "path": "res://Resources/Avatars/Basic/02_月相徽章.png"},
	{"id": "basic.comet", "name_key": "ui.profile.avatar.comet", "path": "res://Resources/Avatars/Basic/03_彗星徽章.png"},
	{"id": "basic.armillary", "name_key": "ui.profile.avatar.armillary", "path": "res://Resources/Avatars/Basic/04_天球仪徽章.png"},
	{"id": "basic.ostrich_curator", "name_key": "ui.profile.avatar.ostrich", "path": "res://Resources/Avatars/Basic/05_鸵鸟馆员.png"},
	{"id": "basic.camel_archivist", "name_key": "ui.profile.avatar.camel", "path": "res://Resources/Avatars/Basic/06_骆驼档案员.png"},
	{"id": "basic.bat_observer", "name_key": "ui.profile.avatar.bat", "path": "res://Resources/Avatars/Basic/07_蝙蝠观测员.png"},
	{"id": "basic.lynx_appraiser", "name_key": "ui.profile.avatar.lynx", "path": "res://Resources/Avatars/Basic/08_猞猁鉴定师.png"},
	{"id": "basic.magnifier", "name_key": "ui.profile.avatar.magnifier", "path": "res://Resources/Avatars/Basic/09_鉴定放大镜.png"},
	{"id": "basic.seal", "name_key": "ui.profile.avatar.seal", "path": "res://Resources/Avatars/Basic/10_馆藏封蜡章.png"},
	{"id": "basic.display_key", "name_key": "ui.profile.avatar.display_key", "path": "res://Resources/Avatars/Basic/11_展柜钥匙.png"},
	{"id": "basic.astrolabe", "name_key": "ui.profile.avatar.astrolabe", "path": "res://Resources/Avatars/Basic/12_星盘仪.png"},
]

static func get_unlocked_avatar_ids() -> Array[String]:
	var ids: Array[String] = []
	for avatar in AVATARS:
		ids.append(str(avatar["id"]))
	return ids

static func is_known_avatar(avatar_id: String) -> bool:
	return not get_avatar(avatar_id).is_empty()

static func get_avatar(avatar_id: String) -> Dictionary:
	for avatar in AVATARS:
		if str(avatar["id"]) == avatar_id:
			return avatar
	return {}

static func get_texture(avatar_id: String) -> Texture2D:
	var avatar := get_avatar(avatar_id)
	if avatar.is_empty():
		avatar = get_avatar(DEFAULT_AVATAR_ID)
	return load(str(avatar["path"])) as Texture2D
