class_name Session
extends RefCounted
## What the screens share while the app runs: are we playing online, who is in the room,
## and the starting information of the current game.

static var online: bool = false
static var code: String = ""
static var info: Dictionary = {}          # the latest lobby information from the server
static var roster: Array = []             # game players: [{seat, name, avatar, team}] (index = player number)
static var me_seat: int = -1
static var timer_sec: int = 0
static var replay_log: PackedInt32Array = PackedInt32Array()


static func start_local() -> void:
	online = false
	code = ""
	me_seat = -1
	timer_sec = 0
	replay_log = PackedInt32Array()
	roster = [
		{"seat": 0, "name": "RED", "avatar": 0, "team": 0},
		{"seat": 1, "name": "BLUE", "avatar": 5, "team": 1},
	]


static func set_online_start(start: Dictionary) -> void:
	online = true
	code = start["code"]
	roster = start["roster"]
	me_seat = start["me"]
	timer_sec = start["timer"]
	replay_log = start["log"]


static func teams() -> Array:
	var t: Array = []
	for r in roster:
		t.append(r["team"])
	return t


## My player number in the game, or -1 when playing locally on one phone.
static func my_player() -> int:
	if not online:
		return -1
	for i in roster.size():
		if roster[i]["seat"] == me_seat:
			return i
	return -1
