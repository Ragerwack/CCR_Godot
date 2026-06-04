extends Node

# 简单配置管理（JSON文件存储）
# 存储路径: user://config.json

var _config: Dictionary = {}
var _save_path: String = "user://config.json"

func _ready() -> void:
	_load()

func _load() -> void:
	if FileAccess.file_exists(_save_path):
		var file = FileAccess.open(_save_path, FileAccess.READ)
		if file != null:
			var json_str = file.get_as_text()
			file.close()
			var json = JSON.new()
			if json.parse(json_str) == OK:
				_config = json.get_data()
				if not _config is Dictionary:
					_config = {}

func _save() -> void:
	var file = FileAccess.open(_save_path, FileAccess.WRITE)
	if file != null:
		var json_str = JSON.stringify(_config, "\t")
		file.store_string(json_str)
		file.close()

func get_value(section: String, key: String, default = null):
	if _config.has(section) and _config[section] is Dictionary:
		return _config[section].get(key, default)
	return default

func set_value(section: String, key: String, value) -> void:
	if not _config.has(section):
		_config[section] = {}
	_config[section][key] = value
	_save()
