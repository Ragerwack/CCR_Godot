class_name PlayerStateCache
extends RefCounted

## 玩家本地只读快照。文件可随时删除；任何资产判断仍以服务端为准。

const CACHE_SCHEMA_VERSION := 2
const CACHE_DIRECTORY := "user://player-cache/v2"
const DEVICE_ID_PATH := "user://player-cache/device_id.txt"
const MAX_CACHE_BYTES := 64 * 1024 * 1024

func load_snapshot(player_id: int) -> Dictionary:
	if player_id <= 0:
		return {}
	var path := _cache_path(player_id)
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > MAX_CACHE_BYTES:
		return {}
	var root_value = JSON.parse_string(file.get_as_text())
	file.close()
	if not (root_value is Dictionary):
		return {}
	var root: Dictionary = root_value
	if int(root.get("cache_schema_version", 0)) != CACHE_SCHEMA_VERSION:
		return {}
	if int(root.get("player_id", 0)) != player_id:
		return {}
	var payload_json := str(root.get("payload_json", ""))
	if payload_json == "" or str(root.get("payload_sha256", "")) != _sha256(payload_json):
		return {}
	var payload_value = JSON.parse_string(payload_json)
	if not (payload_value is Dictionary):
		return {}
	var payload: Dictionary = payload_value
	if not (payload.get("identity", {}) is Dictionary) or not (payload.get("relics", []) is Array):
		return {}
	root["payload"] = payload
	return root

func build_sync_request(player_id: int, locale: String) -> Dictionary:
	var snapshot := load_snapshot(player_id)
	return {
		"cache_schema_version": CACHE_SCHEMA_VERSION,
		"player_id": player_id if not snapshot.is_empty() else null,
		"profile_version": int(snapshot.get("profile_version", 0)),
		"relic_inventory_version": int(snapshot.get("relic_inventory_version", 0)),
		# 字段为旧服务端请求兼容保留；v2 relic 快照是语言无关资产 ID。
		"relic_locale": "asset-id",
		"device_id": _load_or_create_device_id(),
	}

func save_snapshot(
	player_id: int,
	profile_version: int,
	relic_inventory_version: int,
	content_contract: String,
	identity: Dictionary,
	relics: Array
) -> bool:
	if player_id <= 0 or profile_version < 0 or relic_inventory_version < 0:
		return false
	var payload_json := JSON.stringify({
		"identity": identity,
		"relics": relics,
	})
	var root := {
		"cache_schema_version": CACHE_SCHEMA_VERSION,
		"player_id": player_id,
		"profile_version": profile_version,
		"relic_inventory_version": relic_inventory_version,
		"content_contract": content_contract,
		"saved_at_unix": int(Time.get_unix_time_from_system()),
		"payload_json": payload_json,
		"payload_sha256": _sha256(payload_json),
	}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CACHE_DIRECTORY))
	var path := _cache_path(player_id)
	var temporary_path := path + ".tmp"
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(root))
	file.close()
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	return DirAccess.rename_absolute(
		ProjectSettings.globalize_path(temporary_path),
		ProjectSettings.globalize_path(path)
	) == OK

func remove_snapshot(player_id: int) -> void:
	var path := _cache_path(player_id)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _cache_path(player_id: int) -> String:
	return "%s/player_%d.json" % [CACHE_DIRECTORY, player_id]

func _load_or_create_device_id() -> String:
	if FileAccess.file_exists(DEVICE_ID_PATH):
		var existing_file := FileAccess.open(DEVICE_ID_PATH, FileAccess.READ)
		if existing_file != null:
			var existing := existing_file.get_as_text().strip_edges()
			existing_file.close()
			if existing.length() >= 8 and existing.length() <= 128:
				return existing
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://player-cache"))
	var device_id := "godot:" + Crypto.new().generate_random_bytes(16).hex_encode()
	var file := FileAccess.open(DEVICE_ID_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(device_id)
		file.close()
	return device_id

func _sha256(value: String) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(value.to_utf8_buffer())
	return context.finish().hex_encode()
