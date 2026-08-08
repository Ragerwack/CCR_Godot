extends Node

const TEST_PLAYER_ID := 987654321
const SECOND_PLAYER_ID := 987654322
const PlayerStateCacheScript = preload("res://Scripts/Autoload/PlayerStateCache.gd")

func _ready() -> void:
	var cache = PlayerStateCacheScript.new()
	cache.remove_snapshot(TEST_PLAYER_ID)
	cache.remove_snapshot(SECOND_PLAYER_ID)
	var empty_request := cache.build_sync_request(TEST_PLAYER_ID, "zh-CN")
	if empty_request.get("player_id") != null:
		return _fail("new_device_should_not_claim_player_cache")
	if int(empty_request.get("profile_version", -1)) != 0 or int(empty_request.get("relic_inventory_version", -1)) != 0:
		return _fail("new_device_versions_should_be_zero")
	if str(empty_request.get("relic_locale", "")) != "asset-id":
		return _fail("new_device_asset_contract_missing")

	var identity := {
		"id": TEST_PLAYER_ID,
		"username": "cache_tester",
		"avatar": "basic.north_star",
		"country": "CN",
	}
	var relics: Array = [{
		"id": 101,
		"color": "purple",
		"combat_power": 20,
		"status": "active",
		"deck_def": {"id": 23, "asset_id": 1},
		"series": {"id": 3, "asset_id": 2},
	}]
	if not cache.save_snapshot(TEST_PLAYER_ID, 7, 12, "asset-id-v1", identity, relics):
		return _fail("save_failed")
	var loaded := cache.load_snapshot(TEST_PLAYER_ID)
	if loaded.is_empty():
		return _fail("load_failed")
	var payload: Dictionary = loaded.get("payload", {})
	if payload.get("identity", {}).get("username", "") != "cache_tester":
		return _fail("identity_round_trip_failed")
	if payload.get("relics", []).size() != 1:
		return _fail("relic_round_trip_failed")

	var hit_request := cache.build_sync_request(TEST_PLAYER_ID, "zh-CN")
	if int(hit_request.get("player_id", 0)) != TEST_PLAYER_ID:
		return _fail("cached_player_id_missing")
	if int(hit_request.get("profile_version", 0)) != 7 or int(hit_request.get("relic_inventory_version", 0)) != 12:
		return _fail("cached_versions_missing")
	if str(hit_request.get("device_id", "")).length() < 8:
		return _fail("device_id_missing")

	var second_identity := identity.duplicate(true)
	second_identity["id"] = SECOND_PLAYER_ID
	second_identity["username"] = "test1"
	if not cache.save_snapshot(SECOND_PLAYER_ID, 1, 1, "asset-id-v1", second_identity, []):
		return _fail("second_account_save_failed")
	var first_after_second := cache.load_snapshot(TEST_PLAYER_ID)
	var second_loaded := cache.load_snapshot(SECOND_PLAYER_ID)
	if first_after_second.get("payload", {}).get("identity", {}).get("username", "") != "cache_tester":
		return _fail("second_account_overwrote_first_cache")
	if second_loaded.get("payload", {}).get("identity", {}).get("username", "") != "test1":
		return _fail("second_account_cache_identity_wrong")

	var cache_path := "%s/player_%d.json" % [PlayerStateCacheScript.CACHE_DIRECTORY, TEST_PLAYER_ID]
	var file := FileAccess.open(cache_path, FileAccess.WRITE)
	file.store_string("{\"cache_schema_version\":2,\"player_id\":987654321,\"payload_json\":\"tampered\",\"payload_sha256\":\"bad\"}")
	file.close()
	if not cache.load_snapshot(TEST_PLAYER_ID).is_empty():
		return _fail("corrupt_checksum_was_accepted")

	cache.remove_snapshot(TEST_PLAYER_ID)
	cache.remove_snapshot(SECOND_PLAYER_ID)
	print("PLAYER_STATE_CACHE ok new_device=true hit=true accounts_isolated=true corruption_rejected=true")
	get_tree().quit(0)

func _fail(message: String) -> void:
	PlayerStateCacheScript.new().remove_snapshot(TEST_PLAYER_ID)
	PlayerStateCacheScript.new().remove_snapshot(SECOND_PLAYER_ID)
	push_error("PLAYER_STATE_CACHE " + message)
	get_tree().quit(1)
