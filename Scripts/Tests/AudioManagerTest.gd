extends Node

const REQUIRED_EVENTS := [
	"ui_hover", "ui_press", "ui_back", "nav_transition",
	"card_select", "card_move", "hand_page",
	"draw_white", "draw_green", "draw_blue", "draw_purple", "draw_orange", "draw_black",
	"forge_start", "forge_success", "vault_store", "discard", "slot_unlock",
	"currency_gold", "currency_gem", "level_up", "error_soft",
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
		if AudioManager.get_sfx_variant_count(event_name) < 2:
			return _fail("variation_" + event_name)
	if AudioManager.is_sfx_playback_enabled():
		return _fail("procedural_sfx_should_be_disabled")

	var original_sfx := AudioManager.sfx_volume
	var original_muted := AudioManager.is_muted
	AudioManager.set_muted(false)
	AudioManager.set_sfx_volume(0.5)
	AudioManager.play_sfx("ui_press", 1.0, 0.0)
	if AudioManager.get_last_played_sfx_event() != "":
		return _fail("disabled_direct_play")

	AudioManager.set_muted(true)
	AudioManager.play_sfx("card_select")
	if AudioManager.get_last_played_sfx_event() != "":
		return _fail("mute_guard")
	AudioManager.set_muted(false)

	var nav_button := Button.new()
	nav_button.name = "AudioTestNavigation"
	nav_button.set_meta("ccr_button_variant", "navigation")
	add_child(nav_button)
	await get_tree().process_frame
	await get_tree().process_frame
	nav_button.pressed.emit()
	if AudioManager.get_last_played_sfx_event() != "":
		return _fail("disabled_dynamic_button_binding")

	AudioManager.fade_all_audio_to_silence(0.0)
	AudioManager.play_sfx("error_soft")
	if AudioManager.get_last_played_sfx_event() != "":
		return _fail("cinematic_silence_guard")
	AudioManager.restore_all_audio(0.0)
	await get_tree().process_frame
	if AudioManager.is_cinematic_silence_active():
		return _fail("cinematic_restore")

	AudioManager.set_sfx_volume(original_sfx)
	AudioManager.set_muted(original_muted)
	print("AUDIO_MANAGER ok events=%d assets=57 pool=%d playback_enabled=false" % [AudioManager.get_sfx_event_count(), AudioManager.get_sfx_pool_size()])
	get_tree().quit(0)

func _fail(reason: String) -> void:
	push_error("AUDIO_MANAGER " + reason)
	get_tree().quit(1)
