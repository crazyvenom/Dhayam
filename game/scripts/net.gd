extends Node
## Networking for Dhayam. The very same script runs inside the app (as the client) and on the
## server (started with the option --server). Messages are Godot RPC calls over a WebSocket.
##   c_*  : phone -> server        s_*  : server -> phone

const PORT: int = 8080
const DEFAULT_URL: String = "ws://129.225.111.216:8080"

signal connected_ok
signal connection_failed
signal connection_lost
signal room_updated(info: Dictionary)
signal error_received(text: String)
signal game_started(info: Dictionary)
signal action_received(action: Dictionary)
signal chat_received(seat: int, msg: int)
signal voice_received(seat: int, data: PackedByteArray)

var is_server: bool = false
var manager: RoomManager
var url: String = DEFAULT_URL
var online: bool = false          # client: currently connected to the server
var _pending: Callable = Callable()


func _ready() -> void:
	is_server = OS.get_cmdline_user_args().has("--server")
	if is_server:
		_start_server()
	else:
		multiplayer.connected_to_server.connect(_on_connected)
		multiplayer.connection_failed.connect(_on_failed)
		multiplayer.server_disconnected.connect(_on_lost)


# ------------------------------------------------------------------ server side

func _start_server() -> void:
	var peer: WebSocketMultiplayerPeer = WebSocketMultiplayerPeer.new()
	var err: int = peer.create_server(PORT)
	if err != OK:
		push_error("Could not open port %d (error %d)" % [PORT, err])
		get_tree().quit(1)
		return
	multiplayer.multiplayer_peer = peer
	manager = RoomManager.new()
	manager.net = self
	add_child(manager)
	multiplayer.peer_connected.connect(func(id: int) -> void: print("peer connected ", id))
	multiplayer.peer_disconnected.connect(func(id: int) -> void:
		print("peer disconnected ", id)
		manager.peer_gone(id))
	print("Dhayam server listening on port ", PORT)


func send_to(peer: int, method: String, args: Array = []) -> void:
	if not multiplayer.get_peers().has(peer):
		return                                  # that player already disconnected
	callv("rpc_id", [peer, method] + args)


@rpc("any_peer", "call_remote", "reliable")
func c_create(player_name: String, avatar: int, token: String) -> void:
	if is_server:
		manager.create(multiplayer.get_remote_sender_id(), player_name, avatar, token)


@rpc("any_peer", "call_remote", "reliable")
func c_join(code: String, player_name: String, avatar: int, token: String) -> void:
	if is_server:
		manager.join(multiplayer.get_remote_sender_id(), code, player_name, avatar, token)


@rpc("any_peer", "call_remote", "reliable")
func c_team(team: int) -> void:
	if is_server:
		manager.team(multiplayer.get_remote_sender_id(), team)


@rpc("any_peer", "call_remote", "reliable")
func c_timer(sec: int) -> void:
	if is_server:
		manager.set_timer(multiplayer.get_remote_sender_id(), sec)


@rpc("any_peer", "call_remote", "reliable")
func c_start() -> void:
	if is_server:
		manager.start(multiplayer.get_remote_sender_id())


@rpc("any_peer", "call_remote", "reliable")
func c_rematch() -> void:
	if is_server:
		manager.rematch(multiplayer.get_remote_sender_id())


@rpc("any_peer", "call_remote", "reliable")
func c_roll() -> void:
	if is_server:
		manager.roll(multiplayer.get_remote_sender_id())


@rpc("any_peer", "call_remote", "reliable")
func c_move(coin: int, chip: int) -> void:
	if is_server:
		manager.move(multiplayer.get_remote_sender_id(), coin, chip)


@rpc("any_peer", "call_remote", "reliable")
func c_leave() -> void:
	if is_server:
		manager.leave(multiplayer.get_remote_sender_id())


@rpc("any_peer", "call_remote", "reliable")
func c_chat(msg: int) -> void:
	if is_server:
		manager.chat(multiplayer.get_remote_sender_id(), msg)


@rpc("any_peer", "call_remote", "reliable")
func c_voice(data: PackedByteArray) -> void:
	if is_server:
		manager.voice(multiplayer.get_remote_sender_id(), data)


@rpc("any_peer", "call_remote", "reliable")
func c_listen(on: bool) -> void:
	if is_server:
		manager.listen(multiplayer.get_remote_sender_id(), on)


# ------------------------------------------------------------------ client side

## Connect to the server (if not connected yet) and then run the given action.
func connect_then(action: Callable) -> void:
	_pending = action
	if online:
		_run_pending()
		return
	var peer: WebSocketMultiplayerPeer = WebSocketMultiplayerPeer.new()
	if peer.create_client(url) != OK:
		connection_failed.emit()
		return
	multiplayer.multiplayer_peer = peer


func _run_pending() -> void:
	var p: Callable = _pending
	_pending = Callable()
	if p.is_valid():
		p.call()


func _on_connected() -> void:
	online = true
	connected_ok.emit()
	_run_pending()


func _on_failed() -> void:
	online = false
	multiplayer.multiplayer_peer = null
	connection_failed.emit()


func _on_lost() -> void:
	online = false
	multiplayer.multiplayer_peer = null
	connection_lost.emit()


func disconnect_from_server() -> void:
	if online:
		send("c_leave")
	online = false
	_pending = Callable()
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null


func send(method: String, args: Array = []) -> void:
	if online:
		callv("rpc_id", [1, method] + args)


@rpc("authority", "call_remote", "reliable")
func s_room(info: Dictionary) -> void:
	if not is_server:
		room_updated.emit(info)


@rpc("authority", "call_remote", "reliable")
func s_error(text: String) -> void:
	if not is_server:
		error_received.emit(text)


@rpc("authority", "call_remote", "reliable")
func s_start(info: Dictionary) -> void:
	if not is_server:
		game_started.emit(info)


@rpc("authority", "call_remote", "reliable")
func s_action(action: Dictionary) -> void:
	if not is_server:
		action_received.emit(action)


@rpc("authority", "call_remote", "reliable")
func s_chat(seat: int, msg: int) -> void:
	if not is_server:
		chat_received.emit(seat, msg)


@rpc("authority", "call_remote", "reliable")
func s_voice(seat: int, data: PackedByteArray) -> void:
	if not is_server:
		voice_received.emit(seat, data)
