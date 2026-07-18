extends Node

signal volume_changed(bgm: float, sfx: float)
signal sfx_played(event_name: String)

const SFX_ROOT := "res://Resources/Audio/SFX"
const OFFICIAL_SFX_ROOT := "res://Resources/Audio/SFXOfficial"
const BGM_ROOT := "res://Resources/Audio/Music"
const LOGIN_MUSIC_ROOT := "res://Resources/Audio/Music/Login"
const GAME_MUSIC_ROOT := "res://Resources/Audio/Music/Game"
const AUCTION_MUSIC_ROOT := "res://Resources/Audio/Music/Auction"
const SFX_POOL_SIZE := 12
const DEFAULT_PITCH_VARIATION := 0.025
const SFX_PLAYBACK_ENABLED := true
const AUDIO_EXTENSIONS := ["ogg", "wav", "mp3"]

const EVENT_COOLDOWNS: Dictionary = {
	"ui_hover": 0.045,
	"ui_press": 0.025,
	"nav_transition": 0.08,
	"card_select": 0.045,
	"card_move": 0.06,
	"hand_page": 0.16,
	"draw_white": 0.10,
	"draw_green": 0.14,
	"draw_blue": 0.20,
	"draw_purple": 0.30,
	"draw_orange": 0.40,
	"draw_black": 0.80,
	"forge_start": 0.45,
	"forge_art_flight": 0.02,
	"forge_success_white": 0.60,
	"forge_success_green": 0.60,
	"forge_success_blue": 0.60,
	"forge_success_purple": 0.60,
	"forge_success_orange": 0.60,
	"forge_success_black": 0.60,
	"forge_success_red": 0.60,
	"vault_store": 0.18,
	"discard": 0.18,
	"level_up": 0.80,
	"card_preview": 0.12,
	"error_soft": 0.20,
}

const EVENT_GAINS: Dictionary = {
	"ui_hover": 0.34,
	"ui_press": 0.48,
	"ui_back": 0.48,
	"nav_transition": 0.44,
	"card_select": 0.48,
	"card_move": 0.56,
	"hand_page": 0.50,
	"draw_white": 0.48,
	"draw_green": 0.54,
	"draw_blue": 0.60,
	"draw_purple": 0.68,
	"draw_orange": 0.72,
	"draw_black": 0.74,
	"forge_start": 0.64,
	"forge_art_flight": 0.58,
	"forge_success_white": 0.76,
	"forge_success_green": 0.78,
	"forge_success_blue": 0.80,
	"forge_success_purple": 0.84,
	"forge_success_orange": 0.86,
	"forge_success_black": 0.88,
	"forge_success_red": 0.90,
	"vault_store": 0.58,
	"discard": 0.46,
	"slot_unlock": 0.62,
	"currency_gold": 0.52,
	"currency_gem": 0.56,
	"level_up": 0.70,
	"card_preview": 0.378,
	"error_soft": 0.48,
}

const EVENT_PITCH_SCALES: Dictionary = {
	"card_preview": 0.50,
}

var bgm_volume: float = 0.8
var sfx_volume: float = 0.8
var is_muted: bool = false

var _bgm_player: AudioStreamPlayer
var _sfx_player: AudioStreamPlayer
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_library: Dictionary = {}
var _bgm_library: Dictionary = {}
var _stream_cache: Dictionary = {}
var _last_event_played_msec: Dictionary = {}
var _last_variant_index: Dictionary = {}
var _last_bgm_index: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _last_played_sfx_event: String = ""
var _current_bgm_context: String = ""
var _current_bgm_path: String = ""
var _bgm_loop_enabled: bool = false
var _master_bus_index: int = -1
var _master_volume_before_cinematic: float = 0.0
var _cinematic_audio_tween: Tween = null
var _cinematic_silence_active: bool = false
var _missing_sfx_warned: Dictionary = {}

func _ready() -> void:
	_rng.randomize()
	bgm_volume = Config.get_value("audio", "bgm_volume", 0.8)
	sfx_volume = Config.get_value("audio", "sfx_volume", 0.8)
	is_muted = Config.get_value("audio", "muted", false)

	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.name = "BGMPlayer"
	_bgm_player.volume_db = _volume_to_db(bgm_volume)
	_bgm_player.finished.connect(_on_bgm_finished)
	add_child(_bgm_player)

	for index in range(SFX_POOL_SIZE):
		var player := AudioStreamPlayer.new()
		player.name = "SFXPlayer" if index == 0 else "SFXPlayer%02d" % (index + 1)
		player.set_meta("ccr_sfx_gain", 1.0)
		player.volume_db = _volume_to_db(sfx_volume)
		add_child(player)
		_sfx_players.append(player)
	_sfx_player = _sfx_players[0]
	reload_sfx_library()
	reload_bgm_library()

	_master_bus_index = AudioServer.get_bus_index("Master")
	if _master_bus_index >= 0:
		_master_volume_before_cinematic = AudioServer.get_bus_volume_db(_master_bus_index)

	get_tree().node_added.connect(_on_tree_node_added)
	_bind_existing_buttons.call_deferred()
	_bind_game_signals.call_deferred()

func _volume_to_db(v: float) -> float:
	if v <= 0:
		return -80.0
	return linear_to_db(v)

func _volume_from_db(db: float) -> float:
	if db <= -80:
		return 0.0
	return db_to_linear(db)

func set_bgm_volume(v: float) -> void:
	bgm_volume = clampf(v, 0.0, 1.0)
	_bgm_player.volume_db = _volume_to_db(bgm_volume) if not is_muted else -80.0
	Config.set_value("audio", "bgm_volume", bgm_volume)
	volume_changed.emit(bgm_volume, sfx_volume)

func set_sfx_volume(v: float) -> void:
	sfx_volume = clampf(v, 0.0, 1.0)
	for player in _sfx_players:
		var active_gain := float(player.get_meta("ccr_sfx_gain", 1.0))
		player.volume_db = _volume_to_db(clampf(sfx_volume * active_gain, 0.0, 1.0)) if not is_muted else -80.0
	Config.set_value("audio", "sfx_volume", sfx_volume)
	volume_changed.emit(bgm_volume, sfx_volume)

func set_muted(muted: bool) -> void:
	is_muted = muted
	_bgm_player.volume_db = -80.0 if muted else _volume_to_db(bgm_volume)
	for player in _sfx_players:
		var active_gain := float(player.get_meta("ccr_sfx_gain", 1.0))
		player.volume_db = -80.0 if muted else _volume_to_db(clampf(sfx_volume * active_gain, 0.0, 1.0))
	Config.set_value("audio", "muted", is_muted)
	volume_changed.emit(bgm_volume, sfx_volume)

func toggle_mute() -> void:
	set_muted(not is_muted)

## 重新扫描正式音效目录。业务层只使用事件名，不拼接具体文件路径。
func reload_sfx_library() -> void:
	_sfx_library.clear()
	_missing_sfx_warned.clear()
	_stream_cache.clear()
	var files := _audio_files_at(OFFICIAL_SFX_ROOT)
	files.sort()
	for filename in files:
		var basename := filename.get_basename()
		var marker := basename.rfind("_v")
		if marker <= 0:
			continue
		var event_name := basename.substr(0, marker)
		if not _sfx_library.has(event_name):
			_sfx_library[event_name] = []
		_sfx_library[event_name].append(OFFICIAL_SFX_ROOT + "/" + filename)

func reload_bgm_library() -> void:
	_bgm_library = {
		"login": _scan_audio_paths(LOGIN_MUSIC_ROOT),
		"game": _scan_audio_paths(GAME_MUSIC_ROOT),
		"auction": _scan_audio_paths(AUCTION_MUSIC_ROOT),
	}

func _audio_files_at(root: String) -> PackedStringArray:
	if DirAccess.open(root) == null:
		return PackedStringArray()
	var result := PackedStringArray()
	for filename in DirAccess.get_files_at(root):
		if AUDIO_EXTENSIONS.has(filename.get_extension().to_lower()):
			result.append(filename)
	return result

func _scan_audio_paths(root: String) -> Array[String]:
	var files := _audio_files_at(root)
	files.sort()
	var paths: Array[String] = []
	for filename in files:
		paths.append(root + "/" + filename)
	return paths

## 播放短音效。variation、微随机音高、节流和并发统一在这里处理。
func play_sfx(sfx_name: String, volume: float = 1.0, pitch_variation: float = DEFAULT_PITCH_VARIATION) -> void:
	if not SFX_PLAYBACK_ENABLED:
		return
	if is_muted or sfx_volume <= 0.0 or _cinematic_silence_active:
		return
	if not _sfx_library.has(sfx_name):
		if not _missing_sfx_warned.has(sfx_name):
			_missing_sfx_warned[sfx_name] = true
			FileLogger.warn("音效事件不存在: " + sfx_name)
		return
	var now := Time.get_ticks_msec()
	var cooldown_msec := int(roundf(float(EVENT_COOLDOWNS.get(sfx_name, 0.0)) * 1000.0))
	var last_msec := int(_last_event_played_msec.get(sfx_name, -1000000))
	if now - last_msec < cooldown_msec:
		return

	var variants: Array = _sfx_library[sfx_name]
	if variants.is_empty():
		return
	var variant_index := 0
	if variants.size() > 1:
		variant_index = _rng.randi_range(0, variants.size() - 1)
		var last_index := int(_last_variant_index.get(sfx_name, -1))
		if variant_index == last_index:
			variant_index = (variant_index + 1 + _rng.randi_range(0, variants.size() - 2)) % variants.size()
	var path := str(variants[variant_index])
	var stream := _load_sfx_stream(path)
	if stream == null:
		return
	var player := _acquire_sfx_player()
	if player == null:
		return

	_last_variant_index[sfx_name] = variant_index
	_last_event_played_msec[sfx_name] = now
	_last_played_sfx_event = sfx_name
	player.stream = stream
	var event_pitch := float(EVENT_PITCH_SCALES.get(sfx_name, 1.0))
	player.pitch_scale = maxf(0.05, event_pitch * (1.0 + _rng.randf_range(-absf(pitch_variation), absf(pitch_variation))))
	var event_gain := float(EVENT_GAINS.get(sfx_name, 0.6))
	var combined_gain := clampf(event_gain * volume, 0.0, 1.0)
	player.set_meta("ccr_sfx_gain", combined_gain)
	player.volume_db = _volume_to_db(clampf(sfx_volume * combined_gain, 0.0, 1.0))
	player.set_meta("ccr_sfx_started_msec", now)
	player.play()
	sfx_played.emit(sfx_name)

func _load_sfx_stream(path: String) -> AudioStream:
	if _stream_cache.has(path):
		return _stream_cache[path] as AudioStream
	var stream := load(path) as AudioStream
	if stream == null:
		FileLogger.warn("音效资源加载失败: " + path)
		return null
	_stream_cache[path] = stream
	return stream

func _acquire_sfx_player() -> AudioStreamPlayer:
	for player in _sfx_players:
		if not player.playing:
			return player
	# 并发池占满时复用最早开始的 voice，避免无限创建播放器。
	var oldest: AudioStreamPlayer = null
	var oldest_msec := 0x7FFFFFFF
	for player in _sfx_players:
		var started := int(player.get_meta("ccr_sfx_started_msec", 0))
		if started < oldest_msec:
			oldest = player
			oldest_msec = started
	return oldest

# BGM 播放
func play_bgm(bgm_name: String) -> void:
	var path := BGM_ROOT + "/" + bgm_name + ".ogg"
	if not ResourceLoader.exists(path):
		FileLogger.warn("BGM 资源不存在: " + path)
		return
	_play_bgm_path(path, "", false)

func play_login_music(force: bool = false) -> void:
	_play_random_bgm_from_context("login", force)

func play_game_music_loop(force: bool = false) -> void:
	_play_random_bgm_from_context("game", force)

func play_auction_music_loop(force: bool = false) -> void:
	_play_random_bgm_from_context("auction", force)

func _play_random_bgm_from_context(context: String, force: bool = false) -> void:
	if not force and _current_bgm_context == context and _bgm_player.playing:
		return
	var tracks: Array = _bgm_library.get(context, [])
	if tracks.is_empty():
		FileLogger.warn("音乐列表为空: " + context)
		return
	var index := 0
	if tracks.size() > 1:
		index = _rng.randi_range(0, tracks.size() - 1)
		var last_index := int(_last_bgm_index.get(context, -1))
		if index == last_index:
			index = (index + 1 + _rng.randi_range(0, tracks.size() - 2)) % tracks.size()
	_last_bgm_index[context] = index
	_play_bgm_path(str(tracks[index]), context, true)

func _play_bgm_path(path: String, context: String, loop_playlist: bool) -> void:
	var stream := load(path) as AudioStream
	if stream == null:
		FileLogger.warn("音乐资源加载失败: " + path)
		return
	_current_bgm_context = context
	_current_bgm_path = path
	_bgm_loop_enabled = loop_playlist
	_bgm_player.stream = stream
	_bgm_player.volume_db = -80.0 if is_muted else _volume_to_db(bgm_volume)
	_bgm_player.play()

func _on_bgm_finished() -> void:
	if _bgm_loop_enabled and _current_bgm_context != "":
		_play_random_bgm_from_context(_current_bgm_context, true)

func stop_bgm() -> void:
	_bgm_loop_enabled = false
	_current_bgm_context = ""
	_current_bgm_path = ""
	_bgm_player.stop()

## 黑卡等全屏演出使用 Master 总线衰减，确保所有当前及未来音乐、音效播放器一起静音。
## 这里只改变运行时总线，不改玩家保存的音乐、音效和静音设置。
func fade_all_audio_to_silence(duration: float = 0.5) -> void:
	if _master_bus_index < 0:
		_master_bus_index = AudioServer.get_bus_index("Master")
	if _master_bus_index < 0:
		return
	if _cinematic_audio_tween != null and _cinematic_audio_tween.is_valid():
		_cinematic_audio_tween.kill()
	if not _cinematic_silence_active:
		_master_volume_before_cinematic = AudioServer.get_bus_volume_db(_master_bus_index)
	_cinematic_silence_active = true
	_cinematic_audio_tween = create_tween()
	_cinematic_audio_tween.tween_method(_set_master_volume_db, AudioServer.get_bus_volume_db(_master_bus_index), -80.0, maxf(0.0, duration))

func restore_all_audio(duration: float = 0.5) -> void:
	if _master_bus_index < 0 or not _cinematic_silence_active:
		return
	if _cinematic_audio_tween != null and _cinematic_audio_tween.is_valid():
		_cinematic_audio_tween.kill()
	_cinematic_audio_tween = create_tween()
	_cinematic_audio_tween.tween_method(_set_master_volume_db, AudioServer.get_bus_volume_db(_master_bus_index), _master_volume_before_cinematic, maxf(0.0, duration))
	_cinematic_audio_tween.finished.connect(func():
		_cinematic_audio_tween = null
		_cinematic_silence_active = false
	)

func is_cinematic_silence_active() -> bool:
	return _cinematic_silence_active

func _set_master_volume_db(value: float) -> void:
	if _master_bus_index >= 0:
		AudioServer.set_bus_volume_db(_master_bus_index, value)

func has_sfx(sfx_name: String) -> bool:
	return _sfx_library.has(sfx_name) and not (_sfx_library[sfx_name] as Array).is_empty()

func get_sfx_variant_count(sfx_name: String) -> int:
	return (_sfx_library.get(sfx_name, []) as Array).size()

func get_sfx_event_count() -> int:
	return _sfx_library.size()

func get_sfx_pool_size() -> int:
	return _sfx_players.size()

func is_sfx_playback_enabled() -> bool:
	return SFX_PLAYBACK_ENABLED

func get_bgm_track_count(context: String) -> int:
	return (_bgm_library.get(context, []) as Array).size()

func get_current_bgm_context() -> String:
	return _current_bgm_context

func get_event_gain(event_name: String) -> float:
	return float(EVENT_GAINS.get(event_name, 0.6))

func get_event_pitch_scale(event_name: String) -> float:
	return float(EVENT_PITCH_SCALES.get(event_name, 1.0))

func get_last_played_sfx_event() -> String:
	return _last_played_sfx_event

func _on_tree_node_added(node: Node) -> void:
	if node is BaseButton:
		_bind_button_audio.call_deferred(node as BaseButton)

func _bind_existing_buttons() -> void:
	_bind_buttons_recursive(get_tree().root)

func _bind_buttons_recursive(node: Node) -> void:
	if node is BaseButton:
		_bind_button_audio(node as BaseButton)
	for child in node.get_children():
		_bind_buttons_recursive(child)

func _bind_button_audio(button: BaseButton) -> void:
	if not is_instance_valid(button) or button.has_meta("ccr_audio_bound"):
		return
	button.set_meta("ccr_audio_bound", true)
	button.mouse_entered.connect(_on_button_hovered.bind(button))
	button.pressed.connect(_on_button_pressed.bind(button))

func _on_button_hovered(button: BaseButton) -> void:
	if not is_instance_valid(button) or button.disabled or not button.visible:
		return
	play_sfx("ui_hover")

func _on_button_pressed(button: BaseButton) -> void:
	if not is_instance_valid(button) or button.disabled:
		return
	var event_name := "ui_press"
	play_sfx(event_name)

func _bind_game_signals() -> void:
	var drag_system := get_node_or_null("/root/DragSystem")
	if drag_system != null and drag_system.has_signal("drag_ended") and not drag_system.drag_ended.is_connected(_on_card_drag_ended):
		drag_system.drag_ended.connect(_on_card_drag_ended)

func _on_card_drag_ended(_card: Variant, _from: String, to: String) -> void:
	play_sfx("vault_store" if to == "vault" else "card_move")
