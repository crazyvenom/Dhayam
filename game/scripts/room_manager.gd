class_name RoomManager
extends Node
## Keeps all rooms on the server and routes each request from a phone to its room.

const CODE_CHARS: String = "ABCDEFGHJKMNPQRSTUVWXYZ23456789"
const MAX_ROOMS: int = 60

var net: Node
var rooms: Dictionary = {}       # code -> Room
var peer_room: Dictionary = {}   # peer id -> code
var _clean_timer: float = 0.0


func _new_code() -> String:
	for attempt in 50:
		var c: String = ""
		for i in 4:
			c += CODE_CHARS[randi() % CODE_CHARS.length()]
		if not rooms.has(c):
			return c
	return ""


func _clean_name(n: String) -> String:
	var s: String = n.strip_edges().left(14)
	return s if s != "" else "Player"


func _room_of(peer: int) -> Room:
	if peer_room.has(peer) and rooms.has(peer_room[peer]):
		return rooms[peer_room[peer]]
	return null


func create(peer: int, player_name: String, avatar: int, token: String) -> void:
	leave(peer)
	if rooms.size() >= MAX_ROOMS:
		net.send_to(peer, "s_error", ["The server is busy. Try again in a minute."])
		return
	var code: String = _new_code()
	if code == "":
		net.send_to(peer, "s_error", ["Could not create a room."])
		return
	var r: Room = Room.new()
	r.code = code
	r.net = net
	add_child(r)
	rooms[code] = r
	var seat: int = r.add_player(peer, _clean_name(player_name), clampi(avatar, 0, 7), token)
	r.host_seat = seat
	peer_room[peer] = code
	print("room ", code, " created")
	r.broadcast_info()


func join(peer: int, code: String, player_name: String, avatar: int, token: String) -> void:
	leave(peer)
	code = code.strip_edges().to_upper()
	if not rooms.has(code):
		net.send_to(peer, "s_error", ["No room with the code " + code])
		return
	var r: Room = rooms[code]
	var seat: int = r.reconnect(peer, token)
	if seat >= 0:                       # a returning player gets their seat back
		peer_room[peer] = code
		if r.started:
			r.send_game_start(seat)
		r.broadcast_info()
		return
	if r.started:
		net.send_to(peer, "s_error", ["That game has already started"])
		return
	seat = r.add_player(peer, _clean_name(player_name), clampi(avatar, 0, 7), token)
	if seat < 0:
		net.send_to(peer, "s_error", ["That room is full"])
		return
	peer_room[peer] = code
	r.broadcast_info()


func leave(peer: int) -> void:
	var r: Room = _room_of(peer)
	peer_room.erase(peer)
	if r != null:
		r.peer_left(peer)


func peer_gone(peer: int) -> void:
	leave(peer)


func team(peer: int, t: int) -> void:
	var r: Room = _room_of(peer)
	if r == null:
		return
	var err: String = r.set_team(peer, t)
	if err != "":
		net.send_to(peer, "s_error", [err])


func set_timer(peer: int, sec: int) -> void:
	var r: Room = _room_of(peer)
	if r != null:
		r.set_timer(peer, sec)


func start(peer: int) -> void:
	var r: Room = _room_of(peer)
	if r == null:
		return
	var err: String = r.start_game(peer)
	if err != "":
		net.send_to(peer, "s_error", [err])


func rematch(peer: int) -> void:
	var r: Room = _room_of(peer)
	if r != null:
		r.rematch(peer)


func roll(peer: int) -> void:
	var r: Room = _room_of(peer)
	if r != null:
		r.act_roll(peer)


func move(peer: int, coin: int, chip: int) -> void:
	var r: Room = _room_of(peer)
	if r != null:
		r.act_move(peer, coin, chip)


func chat(peer: int, msg: int) -> void:
	var r: Room = _room_of(peer)
	if r == null:
		return
	var seat: int = r.seat_of_peer(peer)
	if seat >= 0 and msg >= 0 and msg < 12:
		r.broadcast_chat(seat, msg)


## Remove rooms nobody has been in for a minute.
func _process(delta: float) -> void:
	_clean_timer += delta
	if _clean_timer < 5.0:
		return
	_clean_timer = 0.0
	for code in rooms.keys():
		var r: Room = rooms[code]
		if not r.any_connected() and r.empty_since >= 0.0 and r.now() - r.empty_since > 60.0:
			print("room ", code, " closed (empty)")
			rooms.erase(code)
			r.queue_free()
