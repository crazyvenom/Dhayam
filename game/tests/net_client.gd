extends Node
## A scripted test player that talks to a real server. Used by tests/run_net_test.ps1.
## Options (after --):  --role=host|guest  --url=ws://...  --codefile=PATH  --players=N  --target=N  --name=X
##                      --dropat=N (disconnect after N actions, then reconnect)

var role: String = "guest"
var url: String = "ws://127.0.0.1:8080"
var codefile: String = ""
var expected_players: int = 3
var target: int = 400
var player_name: String = "Test"
var drop_at: int = -1
var token: String = ""

var gs: GameState
var roster: Array = []
var me_seat: int = -1
var count: int = 0
var waiting: bool = false
var start_sent: bool = false
var code: String = ""
var dropped: bool = false
var finished: bool = false
var errors: Array = []
var chat_sent: bool = false


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--role="):
			role = a.substr(7)
		elif a.begins_with("--url="):
			url = a.substr(6)
		elif a.begins_with("--codefile="):
			codefile = a.substr(11)
		elif a.begins_with("--players="):
			expected_players = int(a.substr(10))
		elif a.begins_with("--target="):
			target = int(a.substr(9))
		elif a.begins_with("--name="):
			player_name = a.substr(7)
		elif a.begins_with("--dropat="):
			drop_at = int(a.substr(9))
	token = "tok-" + player_name
	Net.url = url
	Net.room_updated.connect(_on_room)
	Net.game_started.connect(_on_start)
	Net.chat_received.connect(func(seat: int, msg: int) -> void: print(player_name, " CHAT from seat ", seat, " msg ", msg))
	Net.action_received.connect(_on_action)
	Net.error_received.connect(func(t: String) -> void:
		errors.append(t)
		print(player_name, " ERROR: ", t))
	Net.connection_failed.connect(func() -> void: print(player_name, " connection failed"))
	if role == "host":
		Net.connect_then(func() -> void: Net.send("c_create", [player_name, 0, token]))
	else:
		_wait_for_code()
	await get_tree().create_timer(60.0).timeout
	print(player_name, " TIMEOUT count=", count)
	_finish("timeout")


func _wait_for_code() -> void:
	while not FileAccess.file_exists(codefile):
		await get_tree().create_timer(0.1).timeout
	await get_tree().create_timer(0.3).timeout
	code = FileAccess.get_file_as_string(codefile).strip_edges()
	Net.connect_then(func() -> void: Net.send("c_join", [code, player_name, 1, token]))


func _on_room(info: Dictionary) -> void:
	code = info["code"]
	if role == "host":
		if codefile != "" and not FileAccess.file_exists(codefile):
			var f: FileAccess = FileAccess.open(codefile, FileAccess.WRITE)
			f.store_string(code)
			f.close()
		if not start_sent and (info["players"] as Array).size() >= expected_players:
			start_sent = true
			var teams: String = ""
			for p in info["players"]:
				teams += "%s:t%d " % [p["name"], p["team"]]
			print("lobby full: ", teams)
			Net.send("c_start")


func _on_start(info: Dictionary) -> void:
	roster = info["roster"]
	me_seat = info["me"]
	var teams: Array = []
	for r in roster:
		teams.append(r["team"])
	gs = GameState.new(teams)
	count = 0
	waiting = false
	var lg: PackedInt32Array = info["log"]
	for i in range(0, lg.size(), 3):
		if lg[i] == 0:
			gs.apply_roll(lg[i + 1], lg[i + 2])
		else:
			gs.apply_move(lg[i + 1], lg[i + 2])
		count += 1
	print(player_name, " game started, replayed ", count, " actions, I am seat ", me_seat)
	if role == "host" and not chat_sent:
		chat_sent = true
		await get_tree().create_timer(0.5).timeout
		Net.send("c_chat", [7])
		Net.send("c_chat", [2])      # sent immediately after the first: the server must ignore it (spam limit)
	_maybe_act()


func _on_action(a: Dictionary) -> void:
	if gs == null or finished:
		return
	waiting = false
	if a["k"] == "roll":
		gs.apply_roll(a["a"], a["b"])
	else:
		gs.apply_move(a["coin"], a["chip"])
	count += 1
	if drop_at > 0 and count == drop_at and not dropped:
		dropped = true
		print(player_name, " dropping connection at ", count)
		Net.disconnect_from_server()
		await get_tree().create_timer(2.5).timeout
		print(player_name, " reconnecting")
		Net.connect_then(func() -> void: Net.send("c_join", [code, player_name, 1, token]))
		return
	if count >= target or gs.winner >= 0:
		_finish("done")
		return
	_maybe_act()


func _maybe_act() -> void:
	if waiting or gs == null or gs.winner >= 0 or finished:
		return
	var me: int = -1
	for i in roster.size():
		if roster[i]["seat"] == me_seat:
			me = i
	if me < 0 or gs.active != me:
		return
	waiting = true
	if gs.phase == "roll":
		Net.send("c_roll")
	else:
		var bm: Dictionary = gs.best_move()
		if bm.is_empty():
			waiting = false
			return
		Net.send("c_move", [bm["coin"], bm["chip"]])


func _finish(why: String) -> void:
	if finished:
		return
	finished = true
	var h: String = (str(gs.pos) + "|" + str(gs.active) + "|" + str(gs.unlocked) + "|" + str(gs.rot)).md5_text() if gs != null else "none"
	print("RESULT ", player_name, " ", why, " actions=", count, " hash=", h, " winner=", gs.winner if gs != null else -9)
	get_tree().quit()
