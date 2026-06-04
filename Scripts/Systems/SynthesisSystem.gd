extends Node

# 合成系统 — 通过 ApiClient 调用后端合成 API

signal synthesis_requested(slots: Array, source_type: String)
signal synthesis_succeeded(result: Dictionary)
signal synthesis_failed(reason: String)

func synthesize(slot_indices: Array, source_type: String = "hand") -> void:
	if slot_indices.size() != 5:
		push_error("合成需要恰好5个槽位索引")
		synthesis_failed.emit("需要恰好5张卡牌")
		return

	# 检查是否有重复
	var seen: Dictionary = {}
	for idx in slot_indices:
		if seen.has(idx):
			synthesis_failed.emit("卡牌选择不能重复")
			return
		seen[idx] = true

	synthesis_requested.emit(slot_indices, source_type)

	# 通过 ApiClient 调用服务端
	var resp = await ApiClient.synthesize(slot_indices, source_type)
	if resp["success"]:
		var result_data: Dictionary = resp["data"]
		synthesis_succeeded.emit(result_data)
	else:
		synthesis_failed.emit(resp["error"])
