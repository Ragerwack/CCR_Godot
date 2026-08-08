extends Node

signal resolution_changed(size: Vector2i)
signal window_mode_changed(fullscreen: bool)

const CONFIG_SECTION := "display"
const CONFIG_RESOLUTION_KEY := "resolution"
const CONFIG_WINDOW_MODE_KEY := "window_mode"
const WINDOW_MODE_FULLSCREEN_KEY := "fullscreen"
const WINDOW_MODE_WINDOWED_KEY := "windowed"
const DEFAULT_RESOLUTION := Vector2i(1920, 1200)
const STEAM_DECK_RESOLUTION := Vector2i(1280, 800)
const SUPPORTED_RESOLUTIONS := [
	Vector2i(1280, 800),
	Vector2i(1920, 1200),
	Vector2i(1920, 1080),
	Vector2i(2560, 1600),
	Vector2i(2560, 1440),
]

var current_resolution: Vector2i = DEFAULT_RESOLUTION
var fullscreen_enabled: bool = true

func _ready() -> void:
	apply_startup_resolution()

func apply_startup_resolution() -> void:
	var saved_resolution := get_saved_resolution()
	var target_resolution := DEFAULT_RESOLUTION
	if is_supported_resolution(saved_resolution):
		target_resolution = saved_resolution
	elif is_steam_deck_device():
		target_resolution = STEAM_DECK_RESOLUTION
	current_resolution = target_resolution
	apply_window_mode(get_saved_fullscreen_enabled(), false)
	if not fullscreen_enabled:
		apply_resolution(target_resolution, false)
	else:
		resolution_changed.emit(target_resolution)

func apply_resolution(size: Vector2i, persist: bool = true) -> bool:
	if not is_supported_resolution(size):
		return false
	current_resolution = size
	# Godot 的全屏模式始终使用显示器原生尺寸，不能通过 window_set_size()
	# 切换显示器视频模式。玩家主动选择具体分辨率时切回对应大小的窗口，
	# 避免设置被保存却没有任何可见效果。
	if fullscreen_enabled:
		apply_window_mode(false, persist)
	else:
		_apply_windowed_resolution(size)
	if persist:
		Config.set_value(CONFIG_SECTION, CONFIG_RESOLUTION_KEY, resolution_to_key(size))
	resolution_changed.emit(size)
	return true

func apply_window_mode(fullscreen: bool, persist: bool = true) -> bool:
	fullscreen_enabled = fullscreen
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		_apply_windowed_resolution(current_resolution)
	if persist:
		Config.set_value(CONFIG_SECTION, CONFIG_WINDOW_MODE_KEY, window_mode_to_key(fullscreen))
	window_mode_changed.emit(fullscreen)
	return true

func get_supported_resolutions() -> Array:
	return SUPPORTED_RESOLUTIONS.duplicate()

func is_supported_resolution(size: Vector2i) -> bool:
	for resolution in SUPPORTED_RESOLUTIONS:
		if resolution == size:
			return true
	return false

func get_saved_resolution() -> Vector2i:
	return key_to_resolution(str(Config.get_value(CONFIG_SECTION, CONFIG_RESOLUTION_KEY, "")))

func get_current_resolution() -> Vector2i:
	return current_resolution

func is_fullscreen_enabled() -> bool:
	return fullscreen_enabled

func get_saved_fullscreen_enabled() -> bool:
	var key := str(Config.get_value(CONFIG_SECTION, CONFIG_WINDOW_MODE_KEY, ""))
	if key == WINDOW_MODE_WINDOWED_KEY:
		return false
	if key == WINDOW_MODE_FULLSCREEN_KEY:
		return true
	return true

func window_mode_to_key(fullscreen: bool) -> String:
	return WINDOW_MODE_FULLSCREEN_KEY if fullscreen else WINDOW_MODE_WINDOWED_KEY

func resolution_to_key(size: Vector2i) -> String:
	return "%dx%d" % [size.x, size.y]

func key_to_resolution(key: String) -> Vector2i:
	var parts := key.split("x", false)
	if parts.size() != 2:
		return Vector2i.ZERO
	return Vector2i(int(parts[0]), int(parts[1]))

func resolution_label(size: Vector2i) -> String:
	return "%d x %d (%s)" % [size.x, size.y, _aspect_label(size)]

func is_steam_deck_device() -> bool:
	for env_name in ["SteamDeck", "STEAMDECK"]:
		if OS.has_environment(env_name):
			var value := OS.get_environment(env_name).to_lower()
			if value == "1" or value == "true":
				return true
	if OS.get_name() != "Linux":
		return false
	if not _has_steam_runtime_hint():
		return false
	var screen_size := DisplayServer.screen_get_size(DisplayServer.window_get_current_screen())
	return screen_size == STEAM_DECK_RESOLUTION or screen_size == Vector2i(STEAM_DECK_RESOLUTION.y, STEAM_DECK_RESOLUTION.x)

func _has_steam_runtime_hint() -> bool:
	for env_name in ["SteamGameId", "SteamAppId", "SteamOverlayGameId", "GAMESCOPE_WAYLAND_DISPLAY"]:
		if OS.has_environment(env_name):
			return true
	return false

func _aspect_label(size: Vector2i) -> String:
	var divisor := _gcd(size.x, size.y)
	var width_ratio := size.x / divisor
	var height_ratio := size.y / divisor
	# 16:10 是玩家更熟悉的显示器宽高比写法，避免把等价的 8:5 误解为另一种规格。
	if width_ratio == 8 and height_ratio == 5:
		return "16:10"
	return "%d:%d" % [width_ratio, height_ratio]

func _gcd(a: int, b: int) -> int:
	var x := absi(a)
	var y := absi(b)
	while y != 0:
		var t := y
		y = x % y
		x = t
	return max(1, x)

func _center_window(size: Vector2i) -> void:
	var screen := DisplayServer.window_get_current_screen()
	var usable_rect := DisplayServer.screen_get_usable_rect(screen)
	if usable_rect.size.x <= 0 or usable_rect.size.y <= 0:
		return
	var offset := (usable_rect.size - size) / 2
	var position := usable_rect.position + Vector2i(max(0, offset.x), max(0, offset.y))
	DisplayServer.window_set_position(position)

func _apply_windowed_resolution(size: Vector2i) -> void:
	DisplayServer.window_set_size(size)
	_center_window(size)
