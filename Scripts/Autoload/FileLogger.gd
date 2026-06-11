extends Node
## FileLogger — 文件日志系统
## 将所有 print / 错误信息写入本地文件，方便远程调试
## 
## 用法：直接替换 print() 调用，或者挂在 autoload 后全局可访问
##   FileLogger.log("登录请求已发送")
##   FileLogger.error("API响应错误: " + err_msg)
##   FileLogger.http("GET /api/user/profile → 200 OK")
##
## 日志文件位置: user://logs/ccr-YYYY-MM-DD.log
## 在 macOS 上 = ~/Library/Application Support/CCR_Godot/logs/ccr-YYYY-MM-DD.log

# ══════════════════════════════════════════════════
#  常量
# ══════════════════════════════════════════════════

const LOG_LEVEL_DEBUG: int = 0
const LOG_LEVEL_INFO: int = 1
const LOG_LEVEL_WARN: int = 2
const LOG_LEVEL_ERROR: int = 3

const LOG_LEVEL_NAMES: Dictionary = {
	LOG_LEVEL_DEBUG: "DEBUG",
	LOG_LEVEL_INFO:  "INFO",
	LOG_LEVEL_WARN:  "WARN",
	LOG_LEVEL_ERROR: "ERROR",
}

## 日志保留天数
const MAX_LOG_DAYS: int = 7

# ══════════════════════════════════════════════════
#  状态
# ══════════════════════════════════════════════════

var _log_dir: String = ""
var _current_file: String = ""
var _file: FileAccess = null
var _current_date: String = ""
var _enabled: bool = true

## 日志级别过滤器：只记录 >= 此级别的日志
var log_level: int = LOG_LEVEL_DEBUG

## 是否同时输出到 Godot 控制台
var echo_to_console: bool = true

# ══════════════════════════════════════════════════
#  初始化
# ══════════════════════════════════════════════════

func _ready() -> void:
	_setup_log_dir()
	_rotate_log_file()
	_clean_old_logs()
	info("FileLogger 初始化完成，日志目录: " + _log_dir)

func _setup_log_dir() -> void:
	_log_dir = "user://logs/"
	var dir = DirAccess.open("user://")
	if dir:
		if not dir.dir_exists("logs"):
			dir.make_dir("logs")
	
	# macOS 上 user:// 的具体路径：
	# ~/Library/Application Support/Godot/app_userdata/CCR_Godot/logs/
	# 或者导出后：~/Library/Application Support/CCR_Godot/logs/
	
	var abs_dir = ProjectSettings.globalize_path(_log_dir)
	print("[FileLogger] 日志目录: " + abs_dir)

func _repeat_char(ch: String, count: int) -> String:
	var result = ""
	for i in range(count):
		result += ch
	return result

func _get_date_string() -> String:
	return Time.get_datetime_string_from_system(false).split("T")[0]

func _rotate_log_file() -> void:
	var today = _get_date_string()
	if today == _current_date and _file != null:
		return  # 还是今天，文件已打开
	
	_current_date = today
	_current_file = _log_dir + "ccr-" + today + ".log"
	
	# 关闭旧文件
	if _file != null:
		_file.close()
	
	# 打开新文件（追加模式）
	_file = FileAccess.open(_current_file, FileAccess.WRITE_READ)
	if _file == null:
		print("[FileLogger] 无法打开日志文件: " + _current_file + " err=" + str(FileAccess.get_open_error()))
		_enabled = false
		return
	
	# 追加模式：移到文件末尾
	_file.seek_end()
	
	# 写入分隔行
	_file.store_string("\n")
	_file.store_string(_repeat_char("─", 60) + "\n")
	_file.store_string("[会话开始] " + Time.get_datetime_string_from_system() + "\n")
	_file.store_string(_repeat_char("─", 60) + "\n")
	_file.store_string("\n")
	
	_enabled = true

func _clean_old_logs() -> void:
	var dir = DirAccess.open(_log_dir)
	if dir == null:
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	var today_unix = Time.get_unix_time_from_system()
	
	while file_name != "":
		if file_name.begins_with("ccr-") and file_name.ends_with(".log"):
			var date_str = file_name.trim_prefix("ccr-").trim_suffix(".log")
			# 尝试解析日期：ccr-2026-05-28.log
			var parts = date_str.split("-")
			if parts.size() == 3:
				var log_date_unix = _date_to_unix(int(parts[0]), int(parts[1]), int(parts[2]))
				var days_old = (today_unix - log_date_unix) / 86400
				if days_old > MAX_LOG_DAYS:
					dir.remove(file_name)
					print("[FileLogger] 清理旧日志: " + file_name)
		file_name = dir.get_next()
	dir.list_dir_end()

func _date_to_unix(year: int, month: int, day: int) -> int:
	var date_dict = {
		"year": year,
		"month": month,
		"day": day,
		"hour": 0,
		"minute": 0,
		"second": 0
	}
	return Time.get_unix_time_from_datetime_dict(date_dict)

# ══════════════════════════════════════════════════
#  核心日志方法
# ══════════════════════════════════════════════════

func _write(level: int, tag: String, message: String) -> void:
	if not _enabled or level < log_level:
		return
	
	_rotate_log_file()  # 检查是否要换日
	
	if _file == null:
		return
	
	var timestamp = Time.get_datetime_string_from_system()
	var line = timestamp + " [" + LOG_LEVEL_NAMES.get(level, "????") + "]" + tag + " " + message
	
	_file.store_string(line + "\n")
	_file.flush()  # 立即写入，防止崩溃丢失
	
	if echo_to_console:
		print(line)

# ══════════════════════════════════════════════════
#  公开 API
# ══════════════════════════════════════════════════

static func log(message: String, tag: String = "") -> void:
	var inst = _get_instance()
	if inst:
		inst._write(LOG_LEVEL_INFO, tag, message)

static func debug(message: String, tag: String = "") -> void:
	var inst = _get_instance()
	if inst:
		inst._write(LOG_LEVEL_DEBUG, tag, message)

static func info(message: String, tag: String = "") -> void:
	var inst = _get_instance()
	if inst:
		inst._write(LOG_LEVEL_INFO, tag, message)

static func warn(message: String, tag: String = "") -> void:
	var inst = _get_instance()
	if inst:
		inst._write(LOG_LEVEL_WARN, tag, message)

static func error(message: String, tag: String = "") -> void:
	var inst = _get_instance()
	if inst:
		inst._write(LOG_LEVEL_ERROR, tag, message)

## 专门记录 HTTP 请求/响应
static func http(method: String, url: String, status_code: int = 0, body_summary: String = "") -> void:
	var msg = method + " " + url
	if status_code > 0:
		msg += " → " + str(status_code)
	if body_summary != "":
		msg += " | " + body_summary
	var inst = _get_instance()
	if inst:
		inst._write(LOG_LEVEL_INFO, "[HTTP]", msg)

## 专门记录性能埋点
static func perf(event: String, fields: Dictionary = {}) -> void:
	var parts: Array[String] = []
	for key in fields.keys():
		parts.append(str(key) + "=" + str(fields[key]))
	var msg := event
	if not parts.is_empty():
		msg += " | " + ", ".join(parts)
	var inst = _get_instance()
	if inst:
		inst._write(LOG_LEVEL_INFO, "[PERF]", msg)

## 获取日志目录的绝对路径
static func get_log_path() -> String:
	var inst = _get_instance()
	if inst:
		return ProjectSettings.globalize_path(inst._log_dir)
	return ""

# ══════════════════════════════════════════════════
#  内部
# ══════════════════════════════════════════════════

static func _get_instance() -> FileLogger:
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null:
		var node := tree.root.get_node_or_null("FileLogger")
		if node is FileLogger:
			return node
	return null

# ══════════════════════════════════════════════════
#  生命周期
# ══════════════════════════════════════════════════

func _exit_tree() -> void:
	if _file:
		_file.store_string("\n[会话结束] " + Time.get_datetime_string_from_system() + "\n")
		_file.close()
		_file = null
