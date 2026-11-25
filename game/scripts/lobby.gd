extends Node2D
## The room lobby: see the code, pick Red or Blue, and (for the host) set the timer and start.

var dyn: Node2D
var status_lbl: Label
var _leaving: bool = false


func _ready() -> void:
	dyn = Node2D.new()
	add_child(dyn)
	status_lbl = UI.label(self, "", Vector2(20, 900), Vector2(500, 40), 18, Color(1.0, 0.55, 0.65))
	Net.room_updated.connect(_on_room)
	Net.game_started.connect(_on_game_started)
	Net.error_received.connect(func(t: String) -> void: status_lbl.text = t)
	Net.connection_lost.connect(_on_lost)
	_rebuild()
	DevTools.maybe_shot(self)


func _draw() -> void:
	UI.draw_background(self)


func _on_room(info: Dictionary) -> void:
	if not is_inside_tree():
		return
	Session.info = info
	_rebuild()


func _on_game_started(start: Dictionary) -> void:
	if not is_inside_tree():
		return
	Session.set_online_start(start)
	get_tree().change_scene_to_file("res://main.tscn")


func _on_lost() -> void:
	if not is_inside_tree():
		return
	Session.info = {"lost_msg": "Connection lost. Check your internet and join again."}
	Session.online = false
	get_tree().change_scene_to_file("res://menu.tscn")


func _team_members(team: int) -> Array:
	var res: Array = []
	for p in Session.info["players"]:
		if p["team"] == team:
			res.append(p)
	return res


func _rebuild() -> void:
	for c in dyn.get_children():
		c.queue_free()
	var info: Dictionary = Session.info
	var me: int = info["me"]
	var is_host: bool = info["host"] == me
	var my_team: int = -1
	for p in info["players"]:
		if p["seat"] == me:
			my_team = p["team"]

	var leave: Button = UI.button(dyn, "LEAVE", Vector2(12, 12), Vector2(96, 42), 16,
		Color(0.09, 0.13, 0.38), Color(0.5, 0.6, 0.9), Color.WHITE)
	leave.pressed.connect(_on_leave)

	UI.label(dyn, "ROOM CODE", Vector2(0, 30), Vector2(540, 26), 18, Color(1, 1, 1, 0.55))
	UI.label(dyn, info["code"], Vector2(0, 58), Vector2(540, 110), 100, UI.CYAN)
	UI.label(dyn, "Tell your friends this code to join", Vector2(0, 170), Vector2(540, 26), 16, Color(1, 1, 1, 0.55))
	var copy: Button = UI.button(dyn, "COPY CODE", Vector2(190, 204), Vector2(160, 44), 16,
		Color(0.09, 0.13, 0.38), UI.CYAN, Color.WHITE)
	copy.pressed.connect(func() -> void:
		DisplayServer.clipboard_set(str(info["code"]))
		status_lbl.text = "Code copied")

	for t in 2:
		var x: float = 20.0 + t * 260.0
		var col: Color = UI.RED_COL if t == 0 else UI.BLUE_COL
		var panel: Panel = Panel.new()
		panel.position = Vector2(x, 270)
		panel.size = Vector2(240, 360)
		panel.add_theme_stylebox_override("panel", UI.box(Color(col.r * 0.12, col.g * 0.12, col.b * 0.3, 0.85), col, 16, 8.0))
		dyn.add_child(panel)
		var members: Array = _team_members(t)
		UI.label(dyn, "%s TEAM  %d/5" % ["RED" if t == 0 else "BLUE", members.size()],
			Vector2(x, 278), Vector2(240, 36), 22, col)
		for i in members.size():
			var p: Dictionary = members[i]
			var y: float = 322.0 + i * 60.0
			var av: AvatarView = AvatarView.new(p["avatar"], p["name"], 44.0)
			av.position = Vector2(x + 12, y)
			av.modulate.a = 1.0 if p["connected"] else 0.4
			dyn.add_child(av)
			var tag: String = ""
			if p["host"]:
				tag = "HOST"
			if p["seat"] == me:
				tag = (tag + " YOU").strip_edges()
			var nm: Label = UI.label(dyn, p["name"], Vector2(x + 62, y - 2), Vector2(170, 28), 20, Color.WHITE,
				HORIZONTAL_ALIGNMENT_LEFT)
			nm.clip_text = true
			if tag != "":
				UI.label(dyn, tag, Vector2(x + 62, y + 22), Vector2(170, 20), 13, col, HORIZONTAL_ALIGNMENT_LEFT)
		var jb: Button = UI.button(dyn, "JOIN " + ("RED" if t == 0 else "BLUE"), Vector2(x, 642), Vector2(240, 56), 22,
			Color(col.r * 0.55, col.g * 0.55, col.b * 0.6), col, Color.WHITE)
		jb.disabled = (my_team == t) or members.size() >= 5
		jb.pressed.connect(func() -> void: Net.send("c_team", [t]))

	# Turn timer (host chooses)
	var timers: Array = [0, 15, 30, 60]
	var cur: int = int(info["timer"])
	UI.label(dyn, "Turn timer", Vector2(20, 716), Vector2(200, 50), 20, Color(1, 1, 1, 0.8), HORIZONTAL_ALIGNMENT_LEFT)
	var tb: Button = UI.button(dyn, "OFF" if cur == 0 else "%d s" % cur, Vector2(330, 716), Vector2(190, 50), 22,
		Color(0.09, 0.13, 0.38), UI.CYAN, Color.WHITE)
	if is_host:
		tb.pressed.connect(func() -> void:
			Net.send("c_timer", [timers[(timers.find(cur) + 1) % timers.size()]]))
	else:
		tb.disabled = true

	# Start
	if is_host:
		var ready: bool = _team_members(0).size() >= 1 and _team_members(1).size() >= 1
		if OS.get_environment("DHAYAM_AUTO") == "host":          # developer test hook
			var cf: String = OS.get_environment("DHAYAM_CODEFILE")
			if cf != "" and not FileAccess.file_exists(cf):
				var fh: FileAccess = FileAccess.open(cf, FileAccess.WRITE)
				fh.store_string(str(info["code"]))
				fh.close()
			var want: int = int(OS.get_environment("DHAYAM_PLAYERS")) if OS.has_environment("DHAYAM_PLAYERS") else 2
			if ready and (info["players"] as Array).size() >= want:
				Net.send("c_start")
		var sb: Button = UI.button(dyn, "START GAME", Vector2(70, 790), Vector2(400, 86), 32)
		sb.disabled = not ready
		sb.pressed.connect(func() -> void: Net.send("c_start"))
		status_lbl.text = "" if ready else "Each team needs at least one player"
	else:
		UI.label(dyn, "Waiting for the host to start...", Vector2(0, 800), Vector2(540, 60), 24, Color(1, 1, 1, 0.7))


func _on_leave() -> void:
	if _leaving:
		return
	_leaving = true
	Net.disconnect_from_server()
	Session.online = false
	Session.info = {}
	get_tree().change_scene_to_file("res://menu.tscn")
