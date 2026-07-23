extends Node

const REQUIRED_EVENTS := [
	"ui_hover", "ui_press", "card_preview",
	"draw_white", "draw_green", "draw_blue", "draw_blue_flip", "draw_purple", "draw_purple_lightning", "draw_orange", "draw_orange_fire_ring", "draw_black", "draw_black_hole",
	"forge_art_flight",
	"forge_success_white", "forge_success_green", "forge_success_blue", "forge_success_purple",
	"forge_success_orange", "forge_success_black", "forge_success_red",
	"slot_unlock", "currency_gold", "currency_gem",
	"level_up", "stamina_full",
]

func _ready() -> void:
	await get_tree().process_frame
	AudioManager.reload_sfx_library()
	if AudioManager.get_sfx_event_count() != REQUIRED_EVENTS.size():
		return _fail("event_count_%d" % AudioManager.get_sfx_event_count())
	if AudioManager.get_sfx_pool_size() != 12:
		return _fail("pool_size_%d" % AudioManager.get_sfx_pool_size())
	for event_name in REQUIRED_EVENTS:
		if not AudioManager.has_sfx(event_name):
			return _fail("missing_" + event_name)
		if AudioManager.get_sfx_variant_count(event_name) < 1:
			return _fail("variation_" + event_name)
	if not AudioManager.is_sfx_playback_enabled():
		return _fail("official_sfx_should_be_enabled")
	if AudioManager.get_bgm_track_count("login") != 4:
		return _fail("login_music_count_%d" % AudioManager.get_bgm_track_count("login"))
	if AudioManager.get_bgm_track_count("auction") != 2:
		return _fail("auction_music_count_%d" % AudioManager.get_bgm_track_count("auction"))
	if AudioManager.get_bgm_track_count("game") != 8:
		return _fail("game_music_count_%d" % AudioManager.get_bgm_track_count("game"))
	if absf(AudioManager.get_event_gain("card_preview") - 0.378) > 0.001:
		return _fail("card_preview_gain_%s" % str(AudioManager.get_event_gain("card_preview")))
	if absf(AudioManager.get_event_pitch_scale("card_preview") - 0.50) > 0.001:
		return _fail("card_preview_pitch_%s" % str(AudioManager.get_event_pitch_scale("card_preview")))
	if absf(AudioManager.get_event_gain("draw_blue") - 1.0) > 0.001:
		return _fail("draw_blue_gain_%s" % str(AudioManager.get_event_gain("draw_blue")))
	if absf(AudioManager.get_event_pitch_scale("draw_blue") - 1.0) > 0.001:
		return _fail("draw_blue_pitch_%s" % str(AudioManager.get_event_pitch_scale("draw_blue")))
	if absf(AudioManager.get_event_gain("draw_blue_flip") - 1.0) > 0.001:
		return _fail("draw_blue_flip_gain_%s" % str(AudioManager.get_event_gain("draw_blue_flip")))
	if absf(AudioManager.get_event_pitch_scale("draw_blue_flip") - 1.0) > 0.001:
		return _fail("draw_blue_flip_pitch_%s" % str(AudioManager.get_event_pitch_scale("draw_blue_flip")))
	if absf(AudioManager.get_event_gain("draw_purple_lightning") - 0.90) > 0.001:
		return _fail("purple_lightning_gain_%s" % str(AudioManager.get_event_gain("draw_purple_lightning")))
	if absf(AudioManager.get_event_gain("draw_orange_fire_ring") - 0.92) > 0.001:
		return _fail("orange_fire_ring_gain_%s" % str(AudioManager.get_event_gain("draw_orange_fire_ring")))
	if absf(AudioManager.get_event_gain("draw_black_hole") - 0.92) > 0.001:
		return _fail("black_hole_gain_%s" % str(AudioManager.get_event_gain("draw_black_hole")))

	var original_sfx := AudioManager.sfx_volume
	var original_muted := AudioManager.is_muted
	AudioManager.set_muted(false)
	AudioManager.set_sfx_volume(0.5)
	AudioManager.play_sfx("ui_press", 1.0, 0.0)
	if AudioManager.get_last_played_sfx_event() != "ui_press":
		return _fail("direct_play_failed")

	AudioManager.set_muted(true)
	AudioManager.play_sfx("card_preview")
	if AudioManager.get_last_played_sfx_event() != "ui_press":
		return _fail("mute_guard")
	AudioManager.set_muted(false)

	var nav_button := Button.new()
	nav_button.name = "AudioTestNavigation"
	nav_button.set_meta("ccr_button_variant", "navigation")
	add_child(nav_button)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(0.05).timeout
	nav_button.pressed.emit()
	if AudioManager.get_last_played_sfx_event() != "ui_press":
		return _fail("dynamic_button_binding")

	AudioManager.fade_all_audio_to_silence(0.0)
	AudioManager.play_sfx("ui_hover")
	if AudioManager.get_last_played_sfx_event() != "ui_press":
		return _fail("cinematic_silence_guard")
	AudioManager.play_cinematic_sfx("draw_black_hole", 1.0, 0.0)
	if AudioManager.get_last_played_sfx_event() != "draw_black_hole":
		return _fail("cinematic_sfx_bypass_failed")
	AudioManager.restore_all_audio(0.0)
	await get_tree().process_frame
	if AudioManager.is_cinematic_silence_active():
		return _fail("cinematic_restore")

	AudioManager.set_sfx_volume(original_sfx)
	AudioManager.set_muted(original_muted)
	print("AUDIO_MANAGER ok events=%d sfx_assets=26 music=14 pool=%d playback_enabled=true" % [AudioManager.get_sfx_event_count(), AudioManager.get_sfx_pool_size()])
	get_tree().quit(0)

func _fail(reason: String) -> void:
	push_error("AUDIO_MANAGER " + reason)
	get_tree().quit(1)
