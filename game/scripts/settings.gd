class_name Settings
extends RefCounted
## Player settings that are remembered between sessions (stored on the phone).

const PATH: String = "user://settings.cfg"

static var music_on: bool = true
static var sfx_on: bool = true
static var _loaded: bool = false


static func load_settings() -> void:
	if _loaded:
		return
	_loaded = true
	var cf: ConfigFile = ConfigFile.new()
	if cf.load(PATH) == OK:
		music_on = cf.get_value("audio", "music_on", true)
		sfx_on = cf.get_value("audio", "sfx_on", true)


static func save_settings() -> void:
	var cf: ConfigFile = ConfigFile.new()
	cf.set_value("audio", "music_on", music_on)
	cf.set_value("audio", "sfx_on", sfx_on)
	cf.save(PATH)
