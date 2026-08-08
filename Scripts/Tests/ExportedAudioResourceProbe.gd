extends SceneTree

const AUDIO_EXTENSIONS := ["ogg", "wav", "mp3"]
const EXPECTED_COUNTS := {
	"res://Resources/Audio/SFXOfficial": 27,
	"res://Resources/Audio/Music/Login": 4,
	"res://Resources/Audio/Music/Game": 8,
	"res://Resources/Audio/Music/Auction": 2,
}

func _initialize() -> void:
	for root in EXPECTED_COUNTS:
		var count := 0
		for filename in ResourceLoader.list_directory(root):
			if filename.ends_with("/") or not AUDIO_EXTENSIONS.has(filename.get_extension().to_lower()):
				continue
			var stream := ResourceLoader.load(root + "/" + filename) as AudioStream
			if stream == null:
				_fail("load_failed_%s" % filename)
				return
			count += 1
		if count != int(EXPECTED_COUNTS[root]):
			_fail("count_%s_%d" % [root.get_file(), count])
			return
	print("EXPORTED_AUDIO_RESOURCES ok sfx=27 login=4 game=8 auction=2")
	quit(0)

func _fail(reason: String) -> void:
	push_error("EXPORTED_AUDIO_RESOURCES " + reason)
	quit(1)
