extends Node2D
## The Dhayam game screen. It works the same way on one phone and online:
## every dice throw and move is an "action". Online, the server decides the dice and sends the
## same actions to every phone; this screen applies them to the rules engine and animates them.

const BOARD_SCALE: float = 0.57
const BOARD_POS: Vector2 = Vector2(14.0, 74.0)
const RED_COL: Color = UI.RED_COL
const BLUE_COL: Color = UI.BLUE_COL
const CYAN: Color = UI.CYAN

var gs: GameState
var board: BoardView
var coins: Array = [[], []]
var chips_box: HBoxContainer
var roll_btn: Button
var status_lbl: Label
var turn_lbl: Label
var sum_lbl: Label
var stick1: StickView
var stick2: StickView
var banner: Label
var exit_btn: Button
var sfx: Sfx

var queue: Array = []            # actions waiting to be played
var processing: bool = false     # an action is being animated
var chips_view: Array = []       # the collected numbers as currently shown
var selected: int = -1           # chosen number (index into chips_view)
var awaiting: bool = false       # online: asked the server, waiting for its answer
var _await_id: int = 0
var _actions_applied: int = 0
var _exit_armed: bool = false
var _auto_turns: int = 0


func _ready() -> void:
	Settings.load_settings()
	if Session.roster.is_empty():
		Session.start_local()
	gs = GameState.new(Session.teams())
	sfx = Sfx.new()
	add_child(sfx)
	sfx.start_music()
	board = BoardView.new()
	board.gs = gs
	board.position = BOARD_POS
	board.scale = Vector2(BOARD_SCALE, BOARD_SCALE)
	add_child(board)
	for t in 2:
		for c in 12:
			var coin: Coin = Coin.new()
			coin.team = t
			coin.coin_id = c
			board.add_child(coin)
			coins[t].append(coin)
	_build_ui()
	# Joining or re-joining a game in progress: replay everything that happened, instantly
	var lg: PackedInt32Array = Session.replay_log
	for i in range(0, lg.size(), 3):
		if lg[i] == 0:
			gs.apply_roll(lg[i + 1], lg[i + 2])
		else:
			gs.apply_move(lg[i + 1], lg[i + 2])
		_actions_applied += 1
	Session.replay_log = PackedInt32Array()
	_refresh_all(false)
	_sync_ui()
	if gs.winner >= 0:
		_show_win(gs.winner)
	if Session.online:
		Net.action_received.connect(_on_net_action)
		Net.room_updated.connect(_on_net_room)
		Net.game_started.connect(_on_net_started)
		Net.connection_lost.connect(_on_net_lost)
		Net.error_received.connect(func(t: String) -> void: _set_status(t))
	# Fade in from black (the intro and menu fade out to black)
	modulate = Color(0, 0, 0, 1)
	create_tween().tween_property(self, "modulate", Color.WHITE, 0.5)
	# Developer test modes (only active when these environment variables are set)
	if OS.has_environment("DHAYAM_AUTOPLAY"):
		Engine.time_scale = 8.0
		_autoplay()
	if OS.has_environment("DHAYAM_SHOT") and (OS.has_environment("DHAYAM_AUTOPLAY") or OS.has_environment("DHAYAM_LOCAL")):
		var secs: float = float(OS.get_environment("DHAYAM_SECONDS")) if OS.has_environment("DHAYAM_SECONDS") else 0.6
		await get_tree().create_timer(secs, true, false, true).timeout
		get_viewport().get_texture().get_image().save_png(OS.get_environment("DHAYAM_SHOT"))
		print("turns played: ", _auto_turns, "  winner: ", gs.winner)
		get_tree().quit()


func _autoplay() -> void:
	while true:
		await get_tree().create_timer(0.05, true, false, true).timeout
		if processing or awaiting or gs.winner >= 0:
			continue
		if gs.phase == "roll":
			_auto_turns += 1
			_on_roll_pressed()
		elif gs.phase == "spend":
			var bm: Dictionary = gs.best_move()
			if not bm.is_empty():
				selected = bm["chip"]
				_request_move(bm["coin"])


func _draw() -> void:
	UI.draw_background(self)


# ------------------------------------------------------------------ UI

func _build_ui() -> void:
	UI.label(self, "DHAYAM", Vector2(0, 6), Vector2(540, 28), 22, Color(0.62, 0.86, 1.0, 0.8))
	turn_lbl = UI.label(self, "", Vector2(60, 34), Vector2(420, 36), 26, RED_COL)

	stick1 = StickView.new()
	stick1.position = Vector2(34, 758)
	add_child(stick1)
	stick2 = StickView.new()
	stick2.position = Vector2(94, 758)
	add_child(stick2)
	stick1.set_value(2)
	stick2.set_value(1)

	sum_lbl = UI.label(self, "?", Vector2(150, 752), Vector2(120, 100), 72, CYAN)
	UI.label(self, "RESULT", Vector2(150, 842), Vector2(120, 20), 12, Color(1, 1, 1, 0.5))

	roll_btn = UI.button(self, "ROLL", Vector2(300, 765), Vector2(210, 90), 34)
	roll_btn.pressed.connect(_on_roll_pressed)

	chips_box = HBoxContainer.new()
	chips_box.position = Vector2(20, 878)
	chips_box.size = Vector2(500, 44)
	chips_box.add_theme_constant_override("separation", 8)
	chips_box.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(chips_box)

	status_lbl = UI.label(self, "", Vector2(10, 924), Vector2(520, 30), 16, Color(1, 1, 1, 0.85))

	# Sound buttons (top right): music on/off and sound effects on/off, remembered between sessions
	var music_btn: ToggleIcon = ToggleIcon.new("music", Settings.music_on)
	music_btn.position = Vector2(432, 12)
	music_btn.toggled_state.connect(func(on: bool) -> void: sfx.set_music(on))
	add_child(music_btn)
	var sfx_btn: ToggleIcon = ToggleIcon.new("sfx", Settings.sfx_on)
	sfx_btn.position = Vector2(484, 12)
	sfx_btn.toggled_state.connect(func(on: bool) -> void: sfx.set_sfx(on))
	add_child(sfx_btn)

	exit_btn = UI.button(self, "EXIT", Vector2(12, 14), Vector2(86, 42), 16,
		Color(0.09, 0.13, 0.38), Color(0.5, 0.6, 0.9), Color.WHITE)
	exit_btn.pressed.connect(_on_exit)

	banner = UI.label(self, "", Vector2(30, 380), Vector2(480, 120), 26, Color.WHITE)
	banner.add_theme_stylebox_override("normal", UI.box(Color(0.05, 0.05, 0.2, 0.95), UI.PINK, 18, 12.0))
	banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	banner.z_index = 80
	banner.visible = false


func _set_status(text: String) -> void:
	status_lbl.text = text


func _player_name(p: int) -> String:
	if p >= 0 and p < Session.roster.size():
		return str(Session.roster[p]["name"])
	return "?"


func _show_turn_label(team: int, player: int) -> void:
	var col: Color = RED_COL if team == 0 else BLUE_COL
	var t: String
	if Session.online and player == Session.my_player():
		t = "YOUR TURN"
	else:
		t = "%s'S TURN" % _player_name(player).to_upper()
	turn_lbl.text = t
	turn_lbl.add_theme_color_override("font_color", col)


func _refresh_chips() -> void:
	for ch in chips_box.get_children():
		ch.queue_free()
	for i in chips_view.size():
		var b: Button = Button.new()
		b.text = str(chips_view[i])
		b.custom_minimum_size = Vector2(56, 42)
		b.add_theme_font_size_override("font_size", 22)
		if i == selected:
			UI.style_button(b, Color(0.31, 0.89, 1.0), Color(1, 1, 1), Color(0.02, 0.1, 0.22))
		else:
			UI.style_button(b, Color(0.14, 0.18, 0.5), CYAN, Color.WHITE)
		b.pressed.connect(_on_chip.bind(i))
		chips_box.add_child(b)


func _is_my_turn() -> bool:
	return (not Session.online) or gs.active == Session.my_player()


func _update_movable() -> void:
	var legal: Array = []
	if _is_my_turn() and not processing and not awaiting and gs.phase == "spend" \
			and selected >= 0 and selected < gs.collected.size():
		legal = gs.legal_coins(selected)
	for t in 2:
		for c in 12:
			(coins[t][c] as Coin).movable = (t == gs.turn and legal.has(c))


## Show the real current state: whose turn, what to do, which buttons work.
func _sync_ui() -> void:
	_show_turn_label(gs.turn, gs.active)
	chips_view = gs.collected.duplicate()
	var mine: bool = _is_my_turn()
	roll_btn.disabled = not (mine and gs.phase == "roll" and not awaiting)
	if mine and gs.phase == "spend":
		_auto_select()
	else:
		selected = -1
	_refresh_chips()
	_update_movable()
	if gs.winner >= 0:
		return
	if mine:
		if gs.phase == "roll":
			_set_status("Roll the sticks!" if gs.unlocked[gs.active] else "Roll a 1 to bring out your first coin")
		else:
			_set_status("Tap a number, then tap a glowing coin")
	else:
		_set_status("%s is playing..." % _player_name(gs.active))


func _auto_select() -> void:
	var ok: bool = selected >= 0 and selected < gs.collected.size() and not gs.legal_coins(selected).is_empty()
	if not ok:
		selected = -1
		for i in gs.collected.size():
			if not gs.legal_coins(i).is_empty():
				selected = i
				break


# ------------------------------------------------------------------ coin positions

func _slot_pos(t: int, c: int) -> Vector2:
	var p: int = gs.pos[t][c]
	if p == -1:
		return Routes.base_slot(t, c)
	if p == gs.n_sq:
		return Routes.home_slot(t, c)
	return gs.routes[t][p]["pos"]


func _refresh_all(animate: bool) -> void:
	var groups: Dictionary = {}
	for t in 2:
		for c in 12:
			var p: int = gs.pos[t][c]
			if p >= 0 and p < gs.n_sq:
				var k: String = gs.keys[t][p]
				if not groups.has(k):
					groups[k] = []
				groups[k].append(t * 100 + c)
	for t in 2:
		for c in 12:
			var target: Vector2 = _slot_pos(t, c)
			var p2: int = gs.pos[t][c]
			if p2 >= 0 and p2 < gs.n_sq:
				var g: Array = groups[gs.keys[t][p2]]
				if g.size() > 1:
					var idx: int = g.find(t * 100 + c)
					target += Vector2((idx - (g.size() - 1) / 2.0) * 16.0, (idx % 2) * 8.0)
			var coin: Coin = coins[t][c]
			var s: float = 0.55 if p2 == gs.n_sq else 1.0   # finished coins are drawn smaller
			if animate:
				var tw: Tween = create_tween().set_parallel(true)
				tw.tween_property(coin, "position", target, 0.2)
				tw.tween_property(coin, "scale", Vector2(s, s), 0.2)
			else:
				coin.position = target
				coin.scale = Vector2(s, s)


func _anim_move(team: int, c: int, from: int, to: int) -> void:
	var coin: Coin = coins[team][c]
	coin.z_index = 10
	var path: Array = []
	if from == -1:
		path.append(gs.routes[team][0]["pos"])
	else:
		for i in range(from + 1, mini(to, gs.n_sq - 1) + 1):
			path.append(gs.routes[team][i]["pos"])
		if to == gs.n_sq:
			path.append(Routes.home_slot(team, c))
	var tw: Tween = create_tween()
	if from == -1:
		sfx.play("coin_out")
	for p in path:
		tw.tween_property(coin, "position", p, 0.09)
		if from != -1:
			tw.tween_callback(sfx.play.bind("step", randf_range(0.95, 1.1)))
	await tw.finished
	coin.z_index = 0


# ------------------------------------------------------------------ actions and events

func _enqueue(action: Dictionary) -> void:
	awaiting = false
	queue.append(action)
	if not processing:
		_drain()


func _drain() -> void:
	processing = true
	roll_btn.disabled = true
	_update_movable()
	while queue.size() > 0:
		var a: Dictionary = queue.pop_front()
		var evs: Array
		if a["k"] == "roll":
			evs = gs.apply_roll(a["a"], a["b"])
		else:
			evs = gs.apply_move(a["coin"], a["chip"])
		for e in evs:
			await _play_event(e)
		_actions_applied += 1
		DevTools.check_stop(self, gs, _actions_applied)
	processing = false
	_sync_ui()


func _play_event(e: Dictionary) -> void:
	match e["t"]:
		"roll":
			await _ev_roll(e)
		"unlock":
			await _anim_move(e["team"], e["coin"], -1, 0)
			_refresh_all(true)
		"move":
			await _ev_move(e)
		"lost":
			_set_status("No legal move - numbers lost")
			chips_view = []
			_refresh_chips()
			await get_tree().create_timer(1.2).timeout
		"bonus":
			_set_status("Bonus roll!")
			chips_view = []
			_refresh_chips()
		"turn":
			_show_turn_label(e["team"], e["player"])
			chips_view = []
			selected = -1
			_refresh_chips()
		"win":
			_show_win(e["team"])


func _ev_roll(e: Dictionary) -> void:
	sfx.play("dice_roll")
	for i in 9:
		stick1.set_value(randi() % 4)
		stick2.set_value(randi() % 4)
		await get_tree().create_timer(0.1).timeout
	stick1.set_value(e["a"])
	stick2.set_value(e["b"])
	var v: int = e["v"]
	sum_lbl.text = str(v)
	chips_view = e["chips"]
	selected = -1
	_refresh_chips()
	var who: String = _player_name(e["player"])
	match e["kind"]:
		"fail_locked":
			sfx.play("fail")
			_set_status("%s needs a 1 to start - the turn passes" % who)
			await get_tree().create_timer(1.0).timeout
		"unlock":
			sfx.play_result(v)
			_set_status("A 1! %s's first coin is out - roll again" % who)
		"more":
			sfx.play_result(v)
			_set_status("%d - bonus roll! Roll again" % v)
		_:
			sfx.play_result(v)


func _ev_move(e: Dictionary) -> void:
	var team: int = e["team"]
	var to: int = e["to"]
	await _anim_move(team, e["coin"], e["from"], to)
	chips_view = e["chips"]
	selected = -1
	_refresh_chips()
	var captured: Array = e["captured"]
	if captured.size() > 0:
		sfx.play("capture")
		_set_status("Captured %d coin(s)! Bonus roll" % captured.size())
	elif e["finished"]:
		sfx.play("finish")
	elif to >= 0 and gs.safe.has(gs.keys[team][to]):
		sfx.play("safe")
	_refresh_all(true)
	await get_tree().create_timer(0.3).timeout


# ------------------------------------------------------------------ input

func _set_awaiting() -> void:
	awaiting = true
	_await_id += 1
	var my_id: int = _await_id
	roll_btn.disabled = true
	_update_movable()
	await get_tree().create_timer(3.0).timeout
	if awaiting and my_id == _await_id:     # the server never answered: let the player try again
		awaiting = false
		_sync_ui()


func _on_roll_pressed() -> void:
	if processing or awaiting or gs.phase != "roll" or not _is_my_turn():
		return
	roll_btn.disabled = true
	if Session.online:
		_set_awaiting()
		Net.send("c_roll")
	else:
		_enqueue({"k": "roll", "a": randi() % 4, "b": randi() % 4})


func _on_chip(i: int) -> void:
	if processing or awaiting or gs.phase != "spend" or not _is_my_turn() or i >= gs.collected.size():
		return
	if not gs.legal_coins(i).is_empty():
		sfx.play("tick")
		selected = i
		_refresh_chips()
		_update_movable()
	else:
		_set_status("%d has no legal move right now" % gs.collected[i])


func _request_move(coin: int) -> void:
	if processing or awaiting or gs.phase != "spend" or not _is_my_turn() or selected < 0:
		return
	if Session.online:
		var chip: int = selected
		_set_awaiting()
		Net.send("c_move", [coin, chip])
	else:
		_enqueue({"k": "move", "coin": coin, "chip": selected})


func _unhandled_input(event: InputEvent) -> void:
	var e: InputEventMouseButton = event as InputEventMouseButton
	if e == null or not e.pressed or e.button_index != MOUSE_BUTTON_LEFT:
		return
	if processing or awaiting or gs.phase != "spend" or selected < 0 or not _is_my_turn():
		return
	var lp: Vector2 = board.to_local(e.position)
	var best: int = -1
	var best_d: float = 40.0
	for c in 12:
		var coin: Coin = coins[gs.turn][c]
		if not coin.movable:
			continue
		var d: float = coin.position.distance_to(lp)
		if d < best_d:
			best_d = d
			best = c
	if best >= 0:
		_request_move(best)


func _on_exit() -> void:
	if Session.online and not _exit_armed and gs.winner < 0:
		_exit_armed = true
		exit_btn.text = "SURE?"
		await get_tree().create_timer(2.5).timeout
		_exit_armed = false
		exit_btn.text = "EXIT"
		return
	_leave_to_menu()


func _leave_to_menu() -> void:
	if Session.online:
		Net.disconnect_from_server()
	Session.online = false
	Session.info = {}
	get_tree().change_scene_to_file("res://menu.tscn")


# ------------------------------------------------------------------ online events

func _on_net_action(a: Dictionary) -> void:
	if is_inside_tree():
		_enqueue(a)


func _on_net_room(info: Dictionary) -> void:
	if not is_inside_tree():
		return
	Session.info = info
	if not info["started"]:               # the host chose "play again": back to the lobby
		get_tree().change_scene_to_file("res://lobby.tscn")


func _on_net_started(start: Dictionary) -> void:
	if not is_inside_tree():
		return
	Session.set_online_start(start)       # we re-joined: rebuild the screen from the full history
	get_tree().reload_current_scene()


func _on_net_lost() -> void:
	if not is_inside_tree():
		return
	banner.text = "Connection lost\nReconnecting..."
	banner.visible = true
	for i in 24:
		await get_tree().create_timer(2.5).timeout
		if Net.online:
			return
		Net.connect_then(func() -> void:
			Net.send("c_join", [Session.code, Settings.player_name, Settings.avatar, Settings.token]))
	banner.text = "Could not reconnect"
	await get_tree().create_timer(2.0).timeout
	Session.info = {"lost_msg": "Connection lost. Check your internet and join again."}
	Session.online = false
	get_tree().change_scene_to_file("res://menu.tscn")


# ------------------------------------------------------------------ the end

func _show_win(team: int) -> void:
	sfx.fade_music(1.2)
	sfx.play("win")
	var col: Color = RED_COL if team == 0 else BLUE_COL
	var shade: ColorRect = ColorRect.new()
	shade.color = Color(0, 0, 0, 0.6)
	shade.size = Vector2(540, 960)
	shade.z_index = 50
	add_child(shade)
	var l: Label = UI.label(self, "RED TEAM WINS!" if team == 0 else "BLUE TEAM WINS!",
		Vector2(0, 340), Vector2(540, 90), 52, col)
	l.z_index = 51
	var is_host: bool = Session.online and Session.info.get("host", -1) == Session.me_seat
	if not Session.online or is_host:
		var b: Button = UI.button(self, "PLAY AGAIN", Vector2(150, 470), Vector2(240, 80), 28)
		b.z_index = 51
		if Session.online:
			b.pressed.connect(func() -> void: Net.send("c_rematch"))
		else:
			b.pressed.connect(func() -> void: get_tree().reload_current_scene())
	else:
		var w: Label = UI.label(self, "Waiting for the host to start again...", Vector2(0, 480), Vector2(540, 50), 22, Color(1, 1, 1, 0.8))
		w.z_index = 51
	var m: Button = UI.button(self, "MENU", Vector2(190, 590), Vector2(160, 56), 22,
		Color(0.09, 0.13, 0.38), Color(0.5, 0.6, 0.9), Color.WHITE)
	m.z_index = 51
	m.pressed.connect(_leave_to_menu)
