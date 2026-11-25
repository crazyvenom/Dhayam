class_name Room
extends Node
## One game room on the server: lobby, teams, the game itself, computer players for
## disconnected people, and the turn timer. Runs only on the server.

const MAX_PER_TEAM: int = 5
const BOT_PAUSE: float = 0.9      # seconds a computer player "thinks" between actions

var code: String = ""
var net: Node
var host_seat: int = -1
## Each seat: {"peer", "name", "avatar", "team", "token", "connected", "bot"}
var seats: Array = []
var started: bool = false
var gs: GameState
var roster: Array = []            # player number -> seat index
var log: PackedInt32Array = PackedInt32Array()   # every action: triples (0,a,b) = roll, (1,coin,chip) = move
var timer_sec: int = 0            # 0 = no turn timer
var ready_at: float = 0.0         # earliest time the next automatic action may happen
var idle_since: float = 0.0
var auto_for: int = -1            # player number being played automatically after a timeout
var empty_since: float = -1.0


func now() -> float:
	return Time.get_ticks_msec() / 1000.0


# ------------------------------------------------------------------ seats

func seat_of_peer(peer: int) -> int:
	for i in seats.size():
		if seats[i]["peer"] == peer and seats[i]["connected"]:
			return i
	return -1


func team_count(team: int) -> int:
	var n: int = 0
	for s in seats:
		if s["team"] == team:
			n += 1
	return n


## Adds a new player to the lobby (smaller team first). Returns the seat or -1 if the room is full.
func add_player(peer: int, player_name: String, avatar: int, token: String) -> int:
	var team: int = 0 if team_count(0) <= team_count(1) else 1
	if team_count(team) >= MAX_PER_TEAM:
		return -1
	seats.append({"peer": peer, "name": player_name, "avatar": avatar, "team": team,
		"token": token, "connected": true, "bot": false})
	empty_since = -1.0
	return seats.size() - 1


## A returning player (same token) takes their old seat back. Returns the seat or -1.
func reconnect(peer: int, token: String) -> int:
	if token == "":
		return -1
	for i in seats.size():
		if seats[i]["token"] == token:
			seats[i]["peer"] = peer
			seats[i]["connected"] = true
			seats[i]["bot"] = false
			empty_since = -1.0
			return i
	return -1


func any_connected() -> bool:
	for s in seats:
		if s["connected"]:
			return true
	return false


func peer_left(peer: int) -> void:
	var i: int = seat_of_peer(peer)
	if i < 0:
		return
	if started:
		seats[i]["connected"] = false
		seats[i]["bot"] = true          # a computer player takes over until they return
	else:
		seats.remove_at(i)
		if host_seat == i:
			host_seat = 0 if seats.size() > 0 else -1
		elif host_seat > i:
			host_seat -= 1
	if not any_connected():
		empty_since = now()
	elif host_seat >= 0 and host_seat < seats.size() and not seats[host_seat]["connected"]:
		for j in seats.size():
			if seats[j]["connected"]:
				host_seat = j
				break
	broadcast_info()


func set_team(peer: int, team: int) -> String:
	var i: int = seat_of_peer(peer)
	if i < 0 or started or (team != 0 and team != 1):
		return "Can't change team now"
	if seats[i]["team"] != team and team_count(team) >= MAX_PER_TEAM:
		return "That team is full (5 players)"
	seats[i]["team"] = team
	broadcast_info()
	return ""


func set_timer(peer: int, sec: int) -> void:
	if seat_of_peer(peer) == host_seat and not started and [0, 15, 30, 60].has(sec):
		timer_sec = sec
		broadcast_info()


# ------------------------------------------------------------------ messages to players

func info_for(seat: int) -> Dictionary:
	var plist: Array = []
	for i in seats.size():
		var s: Dictionary = seats[i]
		plist.append({"seat": i, "name": s["name"], "avatar": s["avatar"], "team": s["team"],
			"connected": s["connected"], "bot": s["bot"], "host": i == host_seat})
	return {"code": code, "me": seat, "host": host_seat, "started": started, "timer": timer_sec, "players": plist}


func broadcast_info() -> void:
	for i in seats.size():
		if seats[i]["connected"]:
			net.send_to(seats[i]["peer"], "s_room", [info_for(i)])


func start_info(seat: int) -> Dictionary:
	var r: Array = []
	for i in roster.size():
		var s: Dictionary = seats[roster[i]]
		r.append({"seat": roster[i], "name": s["name"], "avatar": s["avatar"], "team": s["team"]})
	return {"code": code, "me": seat, "roster": r, "timer": timer_sec, "log": log}


func send_game_start(seat: int) -> void:
	net.send_to(seats[seat]["peer"], "s_start", [start_info(seat)])


func broadcast_action(action: Dictionary) -> void:
	for s in seats:
		if s["connected"]:
			net.send_to(s["peer"], "s_action", [action])


func broadcast_chat(from_seat: int, msg: int) -> void:
	for s in seats:
		if s["connected"]:
			net.send_to(s["peer"], "s_chat", [from_seat, msg])


# ------------------------------------------------------------------ the game

## Host presses Start. Returns an error text, or "" on success.
func start_game(peer: int) -> String:
	if seat_of_peer(peer) != host_seat:
		return "Only the host can start"
	if started:
		return "Already started"
	if team_count(0) < 1 or team_count(1) < 1:
		return "Each team needs at least one player"
	var teams: Array = []
	roster = []
	for i in seats.size():
		teams.append(seats[i]["team"])
		roster.append(i)
	gs = GameState.new(teams)
	log = PackedInt32Array()
	started = true
	auto_for = -1
	ready_at = now() + 1.0
	idle_since = ready_at
	for i in seats.size():
		if seats[i]["connected"]:
			send_game_start(i)
	broadcast_info()
	return ""


func rematch(peer: int) -> void:
	if seat_of_peer(peer) != host_seat or not started:
		return
	started = false
	gs = null
	log = PackedInt32Array()
	# players who left during the game are dropped; the rest return to the lobby (host stays host)
	var keep: Array = []
	var new_host: int = 0
	for i in seats.size():
		if seats[i]["connected"]:
			seats[i]["bot"] = false
			if i == host_seat:
				new_host = keep.size()
			keep.append(seats[i])
	seats = keep
	host_seat = new_host if seats.size() > 0 else -1
	broadcast_info()


func act_roll(peer: int) -> void:
	if not started or gs == null:
		return
	var seat: int = seat_of_peer(peer)
	if seat < 0 or roster[gs.active] != seat:
		return
	_apply({"k": "roll", "a": randi() % 4, "b": randi() % 4}, false)


func act_move(peer: int, coin: int, chip: int) -> void:
	if not started or gs == null:
		return
	var seat: int = seat_of_peer(peer)
	if seat < 0 or roster[gs.active] != seat:
		return
	_apply({"k": "move", "coin": coin, "chip": chip}, false)


## Apply an action to the server's copy of the game and tell every phone.
func _apply(action: Dictionary, auto: bool) -> bool:
	var before: int = gs.active
	var ev: Array
	if action["k"] == "roll":
		ev = gs.apply_roll(action["a"], action["b"])
	else:
		ev = gs.apply_move(action["coin"], action["chip"])
	if ev.is_empty():
		return false
	if action["k"] == "roll":
		log.append_array(PackedInt32Array([0, action["a"], action["b"]]))
	else:
		log.append_array(PackedInt32Array([1, action["coin"], action["chip"]]))
	broadcast_action(action)
	var t: float = now()
	ready_at = maxf(t, ready_at) + estimate_seconds(ev) + (BOT_PAUSE if auto else 0.0)
	idle_since = ready_at
	if gs.active != before:
		auto_for = -1
	return true


## Roughly how long the phones need to animate these events (so bots do not run ahead).
func estimate_seconds(ev: Array) -> float:
	var sec: float = 0.1
	for e in ev:
		match e["t"]:
			"roll":
				sec += 1.3
			"unlock":
				sec += 0.6
			"move":
				var steps: int = absi(int(e["to"]) - int(e["from"])) if int(e["from"]) >= 0 else 1
				sec += 0.5 + 0.09 * minf(steps, 12.0) + (0.4 if (e["captured"] as Array).size() > 0 else 0.0)
			"lost":
				sec += 1.3
			"turn", "bonus":
				sec += 0.2
			"win":
				sec += 1.0
	return sec


func _process(_delta: float) -> void:
	if not started or gs == null or gs.winner >= 0:
		return
	var t: float = now()
	if t < ready_at:
		return
	var seat: Dictionary = seats[roster[gs.active]]
	var computer: bool = seat["bot"] or not seat["connected"]
	if timer_sec > 0 and not computer and (t - idle_since) > timer_sec:
		auto_for = gs.active          # ran out of time: the computer plays the rest of this turn
	if not computer and auto_for != gs.active:
		return
	if gs.phase == "roll":
		_apply({"k": "roll", "a": randi() % 4, "b": randi() % 4}, true)
	elif gs.phase == "spend":
		var bm: Dictionary = gs.best_move()
		if bm.is_empty():
			return
		_apply({"k": "move", "coin": bm["coin"], "chip": bm["chip"]}, true)
