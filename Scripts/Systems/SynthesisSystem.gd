extends Node

# 合成系统 — 通过 ApiClient 调用后端合成 API

signal synthesis_requested(slots: Array, source_type: String)
signal synthesis_succeeded(result: Dictionary)
signal synthesis_failed(reason: String)

func synthesize(slot_indices: Array, source_type: String = "hand") -> void:
	if slot_indices.size() != 5:
		push_error("合成需要恰好5个槽位索引")
		synthesis_failed.emit(Localization.t("error.synthesis.need_five"))
		return

	# 检查是否有重复
	var seen: Dictionary = {}
	for idx in slot_indices:
		if seen.has(idx):
			synthesis_failed.emit(Localization.t("error.synthesis.duplicate"))
			return
		seen[idx] = true

	synthesis_requested.emit(slot_indices, source_type)

	if source_type == "hand":
		var sync_resp := await GameManager.sync_pool_hand_layout()
		if not sync_resp.get("success", false):
			synthesis_failed.emit(Localization.t("error.synthesis.sync", [sync_resp.get("error", "")]))
			return

	# 通过 ApiClient 调用服务端
	var resp = await ApiClient.synthesize(slot_indices, source_type)
	if resp["success"]:
		var result_data: Dictionary = resp["data"]
		synthesis_succeeded.emit(result_data)
	else:
		synthesis_failed.emit(resp["error"])
