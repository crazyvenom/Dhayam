class_name Settings
extends RefCounted
## Player settings that are remembered between sessions (stored on the phone).

const PATH: String = "user://settings.cfg"

static var music_on: bool = true
static var sfx_on: bool = true
static var player_name: String = ""
static var avatar: int = 0
static var token: String = ""        # secret id that lets this phone reclaim its seat after a disconnect
static var _loaded: bool = false


static func load_settings() -> void:
	if _loaded:
		return
	_loaded = true
	var cf: ConfigFile = ConfigFile.new()
	if cf.load(PATH) == OK:
		music_on = cf.get_value("audio", "music_on", true)
		sfx_on = cf.get_value("audio", "sfx_on", true)
		player_name = cf.get_value("player", "name", "")
		avatar = cf.get_value("player", "avatar", 0)
		token = cf.get_value("player", "token", "")
	if OS.has_environment("DHAYAM_TOKEN"):      # test copies of the game pretend to be different phones
		token = OS.get_environment("DHAYAM_TOKEN")
		return
	if token == "":
		for i in 16:
			token += "abcdefghijklmnopqrstuvwxyz0123456789"[randi() % 36]
		save_settings()


static func save_settings() -> void:
	if OS.has_environment("DHAYAM_TOKEN"):
		return
	var cf: ConfigFile = ConfigFile.new()
	cf.set_value("audio", "music_on", music_on)
	cf.set_value("audio", "sfx_on", sfx_on)
	cf.set_value("player", "name", player_name)
	cf.set_value("player", "avatar", avatar)
	cf.set_value("player", "token", token)
	cf.save(PATH)
