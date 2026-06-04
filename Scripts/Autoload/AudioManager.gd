extends Node

signal volume_changed(bgm: float, sfx: float)

var bgm_volume: float = 0.8
var sfx_volume: float = 0.8
var is_muted: bool = false

var _bgm_player: AudioStreamPlayer
var _sfx_player: AudioStreamPlayer

func _ready() -> void:
	bgm_volume = Config.get_value("audio", "bgm_volume", 0.8)
	sfx_volume = Config.get_value("audio", "sfx_volume", 0.8)
	is_muted = Config.get_value("audio", "muted", false)

	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.name = "BGMPlayer"
	_bgm_player.volume_db = _volume_to_db(bgm_volume)
	add_child(_bgm_player)

	_sfx_player = AudioStreamPlayer.new()
	_sfx_player.name = "SFXPlayer"
	_sfx_player.volume_db = _volume_to_db(sfx_volume)
	add_child(_sfx_player)

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
	_sfx_player.volume_db = _volume_to_db(sfx_volume) if not is_muted else -80.0
	Config.set_value("audio", "sfx_volume", sfx_volume)
	volume_changed.emit(bgm_volume, sfx_volume)

func set_muted(muted: bool) -> void:
	is_muted = muted
	_bgm_player.volume_db = -80.0 if muted else _volume_to_db(bgm_volume)
	_sfx_player.volume_db = -80.0 if muted else _volume_to_db(sfx_volume)
	Config.set_value("audio", "muted", is_muted)
	volume_changed.emit(bgm_volume, sfx_volume)

func toggle_mute() -> void:
	set_muted(not is_muted)

# SFX 播放（短音效）
func play_sfx(sfx_name: String, volume: float = 1.0) -> void:
	# 后续资源准备好后加载并播放
	pass

# BGM 播放
func play_bgm(bgm_name: String) -> void:
	# 后续资源准备好后加载并播放
	pass

func stop_bgm() -> void:
	_bgm_player.stop()
