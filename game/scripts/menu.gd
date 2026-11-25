extends Node2D
## Main menu: pick a name and avatar, then host a room, join one with a code, or play on this phone.

var name_edit: LineEdit
var code_edit: LineEdit
var status_lbl: Label
var avatars: Array = []
var host_btn: Button
var join_btn: Button
var _busy: bool = false


func _ready() -> void:
	Settings.load_settings()
	UI.label(self, "DHAYAM", Vector2(0, 60), Vector2(540, 90), 76, Color(0.62, 0.86, 1.0))
	UI.label(self, "TEAM BOARD GAME", Vector2(0, 150), Vector2(540, 30), 20, Color(1, 1, 1, 0.55))

	name_edit = UI.line_edit(self, "Your name", Vector2(80, 230), Vector2(380, 62), 28)
	name_edit.max_length = 14
	name_edit.text = Settings.player_name
	name_edit.text_changed.connect(_on_name_changed)

	UI.label(self, "Pick your avatar", Vector2(0, 312), Vector2(540, 24), 16, Color(1, 1, 1, 0.55))
	for i in 8:
		var a: AvatarView = AvatarView.new(i, Settings.player_name if Settings.player_name != "" else "?", 52.0)
		a.position = Vector2(41 + i * 58, 342)
		a.clickable = true
		a.selected = (i == Settings.avatar)
		a.picked.connect(_on_avatar)
		add_child(a)
		avatars.append(a)

	host_btn = UI.button(self, "HOST A ROOM", Vector2(70, 440), Vector2(400, 84), 30)
	code_edit = UI.line_edit(self, "CODE", Vector2(70, 560), Vector2(240, 74), 40)
	code_edit.max_length = 4
	code_edit.text_changed.connect(func(t: String) -> void:
		var up: String = t.to_upper()
		if up != t:
			code_edit.text = up
			code_edit.caret_column = up.length())
	join_btn = UI.button(self, "JOIN", Vector2(326, 560), Vector2(144, 74), 28,
		Color(0.45, 0.2, 0.75), UI.PINK, Color.WHITE)
	var local_btn: Button = UI.button(self, "PLAY ON THIS PHONE", Vector2(70, 690), Vector2(400, 66), 22,
		Color(0.09, 0.13, 0.38), Color(0.5, 0.6, 0.9), Color.WHITE)
	status_lbl = UI.label(self, "", Vector2(20, 780), Vector2(500, 70), 20, Color(1.0, 0.55, 0.65))
	status_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UI.label(self, "SaTz Tech", Vector2(0, 915), Vector2(540, 24), 15, Color(1, 1, 1, 0.3))

	host_btn.pressed.connect(_on_host)
	join_btn.pressed.connect(_on_join)
	local_btn.pressed.connect(_on_local)
	Net.room_updated.connect(_on_room)
	Net.error_received.connect(_on_error)
	Net.connection_failed.connect(_on_failed)
	if Session.info.has("lost_msg"):
		_say(str(Session.info["lost_msg"]))
		Session.info = {}
	# Developer test hooks
	if OS.has_environment("DHAYAM_LOCAL"):
		_on_local.call_deferred()
	var auto: String = OS.get_environment("DHAYAM_AUTO")
	if auto != "":
		name_edit.text = OS.get_environment("DHAYAM_NAME") if OS.has_environment("DHAYAM_NAME") else "Auto"
		if OS.has_environment("DHAYAM_URL"):
			Net.url = OS.get_environment("DHAYAM_URL")
		if auto == "host":
			_on_host.call_deferred()
		else:
			_auto_join()
	DevTools.maybe_shot(self)


func _auto_join() -> void:
	var f: String = OS.get_environment("DHAYAM_CODEFILE")
	while not FileAccess.file_exists(f):
		await get_tree().create_timer(0.2).timeout
	await get_tree().create_timer(0.4).timeout
	code_edit.text = FileAccess.get_file_as_string(f).strip_edges()
	_on_join()


func _draw() -> void:
	UI.draw_background(self)


func _say(t: String) -> void:
	status_lbl.text = t


func _on_name_changed(t: String) -> void:
	for a in avatars:
		(a as AvatarView).set_letter(t if t != "" else "?")


func _on_avatar(i: int) -> void:
	Settings.avatar = i
	for a in avatars:
		(a as AvatarView).selected = ((a as AvatarView).idx == i)
		(a as AvatarView).queue_redraw()


func _profile_ok() -> bool:
	var n: String = name_edit.text.strip_edges()
	if n == "":
		_say("Type your name first")
		return false
	Settings.player_name = n
	Settings.save_settings()
	return true


func _on_host() -> void:
	if _busy or not _profile_ok():
		return
	_busy = true
	_say("Connecting...")
	Net.connect_then(func() -> void:
		Net.send("c_create", [Settings.player_name, Settings.avatar, Settings.token]))


func _on_join() -> void:
	if _busy or not _profile_ok():
		return
	var code: String = code_edit.text.strip_edges().to_upper()
	if code.length() < 4:
		_say("Type the 4-letter room code")
		return
	_busy = true
	_say("Connecting...")
	Net.connect_then(func() -> void:
		Net.send("c_join", [code, Settings.player_name, Settings.avatar, Settings.token]))


func _on_local() -> void:
	Session.start_local()
	get_tree().change_scene_to_file("res://main.tscn")


func _on_room(info: Dictionary) -> void:
	if not is_inside_tree():
		return
	Session.info = info
	Session.online = true
	Session.code = info["code"]
	get_tree().change_scene_to_file("res://lobby.tscn")


func _on_error(text: String) -> void:
	if not is_inside_tree():
		return
	_busy = false
	_say(text)


func _on_failed() -> void:
	if not is_inside_tree():
		return
	_busy = false
	_say("Could not reach the game server. Check your internet and try again.")
