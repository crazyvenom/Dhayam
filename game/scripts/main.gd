extends Node2D
## Dhayam - first playable (two teams on one screen, taking turns).

const BOARD_SCALE: float = 0.57
const BOARD_POS: Vector2 = Vector2(14.0, 74.0)
const RED_COL: Color = Color(1.0, 0.45, 0.55)
const BLUE_COL: Color = Color(0.45, 0.70, 1.0)
const CYAN: Color = Color(0.31, 0.89, 1.0)

var gs: GameState = GameState.new()
var board: BoardView
var coins: Array = [[], []]
var chips_box: HBoxContainer
var roll_btn: Button
var status_lbl: Label
var turn_lbl: Label
var sum_lbl: Label
var stick1: StickView
var stick2: StickView
var selected: int = -1       # index into gs.collected
var busy: bool = false
var sfx: Sfx


func _ready() -> void:
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
	_refresh_all(false)
	_begin_turn()
	# Fade in from black (the intro fades out to black)
	modulate = Color(0, 0, 0, 1)
	create_tween().tween_property(self, "modulate", Color.WHITE, 0.5)
	# Developer test modes (only active when these environment variables are set)
	if OS.has_environment("DHAYAM_AUTOPLAY"):
		Engine.time_scale = 8.0
		_autoplay()
	if OS.has_environment("DHAYAM_SHOT"):
		var secs: float = float(OS.get_environment("DHAYAM_SECONDS")) if OS.has_environment("DHAYAM_SECONDS") else 0.6
		await get_tree().create_timer(secs, true, false, true).timeout
		get_viewport().get_texture().get_image().save_png(OS.get_environment("DHAYAM_SHOT"))
		print("turns played: ", _auto_turns, "  winner: ", gs.winner)
		get_tree().quit()


var _auto_turns: int = 0


func _autoplay() -> void:
	while true:
		await get_tree().create_timer(0.05, true, false, true).timeout
		if busy or gs.phase == "over":
			continue
		if gs.phase == "roll":
			_auto_turns += 1
			_on_roll()
		elif gs.phase == "spend":
			var options: Array = []
			for c in 12:
				if coins[gs.turn][c].movable:
					options.append(c)
			if options.size() > 0:
				_play_move(options[randi() % options.size()])


func _draw() -> void:
	draw_rect(Rect2(0, 0, 540, 960), Color(0.043, 0.063, 0.188))
	draw_circle(Vector2(270, -60), 430.0, Color(0.17, 0.11, 0.43, 0.55))
	draw_circle(Vector2(270, 1000), 360.0, Color(0.10, 0.20, 0.50, 0.30))


# ------------------------------------------------------------------ UI

func _label(text: String, pos: Vector2, sz: Vector2, font_size: int, col: Color) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.position = pos
	l.size = sz
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", col)
	add_child(l)
	return l


func _style(bg: Color, border: Color, radius: int = 14) -> StyleBoxFlat:
	var s: StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(2)
	s.set_corner_radius_all(radius)
	s.shadow_color = Color(border.r, border.g, border.b, 0.45)
	s.shadow_size = 8
	return s


func _style_button(b: Button, bg: Color, border: Color, text_col: Color) -> void:
	for state in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(state, _style(bg, border))
	b.add_theme_stylebox_override("disabled", _style(bg.darkened(0.55), border.darkened(0.6)))
	for cname in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(cname, text_col)
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.35))


func _build_ui() -> void:
	_label("DHAYAM", Vector2(0, 6), Vector2(540, 28), 22, Color(0.62, 0.86, 1.0, 0.8))
	turn_lbl = _label("", Vector2(0, 34), Vector2(540, 36), 26, RED_COL)

	stick1 = StickView.new()
	stick1.position = Vector2(34, 758)
	add_child(stick1)
	stick2 = StickView.new()
	stick2.position = Vector2(94, 758)
	add_child(stick2)
	stick1.set_value(2)
	stick2.set_value(1)

	sum_lbl = _label("?", Vector2(150, 752), Vector2(120, 100), 72, CYAN)
	_label("RESULT", Vector2(150, 842), Vector2(120, 20), 12, Color(1, 1, 1, 0.5))

	roll_btn = Button.new()
	roll_btn.text = "ROLL"
	roll_btn.position = Vector2(300, 765)
	roll_btn.size = Vector2(210, 90)
	roll_btn.add_theme_font_size_override("font_size", 34)
	_style_button(roll_btn, Color(0.12, 0.65, 1.0), CYAN, Color(0.02, 0.1, 0.22))
	roll_btn.pressed.connect(_on_roll)
	add_child(roll_btn)

	chips_box = HBoxContainer.new()
	chips_box.position = Vector2(20, 878)
	chips_box.size = Vector2(500, 44)
	chips_box.add_theme_constant_override("separation", 8)
	chips_box.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(chips_box)

	status_lbl = _label("", Vector2(10, 924), Vector2(520, 30), 16, Color(1, 1, 1, 0.85))

	# Sound buttons (top right): music on/off and sound effects on/off, remembered between sessions
	var music_btn: ToggleIcon = ToggleIcon.new("music", Settings.music_on)
	music_btn.position = Vector2(432, 12)
	music_btn.toggled_state.connect(func(on: bool) -> void: sfx.set_music(on))
	add_child(music_btn)
	var sfx_btn: ToggleIcon = ToggleIcon.new("sfx", Settings.sfx_on)
	sfx_btn.position = Vector2(484, 12)
	sfx_btn.toggled_state.connect(func(on: bool) -> void: sfx.set_sfx(on))
	add_child(sfx_btn)


func _set_status(text: String) -> void:
	status_lbl.text = text


func _refresh_chips() -> void:
	for ch in chips_box.get_children():
		ch.queue_free()
	for i in gs.collected.size():
		var v: int = gs.collected[i]
		var b: Button = Button.new()
		b.text = str(v)
		b.custom_minimum_size = Vector2(56, 42)
		b.add_theme_font_size_override("font_size", 22)
		var is_sel: bool = (i == selected)
		if is_sel:
			_style_button(b, Color(0.31, 0.89, 1.0), Color(1, 1, 1), Color(0.02, 0.1, 0.22))
		else:
			_style_button(b, Color(0.14, 0.18, 0.5), CYAN, Color(1, 1, 1))
		b.pressed.connect(_on_chip.bind(i))
		chips_box.add_child(b)


func _update_movable() -> void:
	for t in 2:
		for c in 12:
			var coin: Coin = coins[t][c]
			var can: bool = false
			if gs.phase == "spend" and t == gs.turn and selected >= 0 and selected < gs.collected.size():
				can = gs.can_move(t, c, gs.collected[selected])
			coin.movable = can


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


# ------------------------------------------------------------------ turn flow

func _begin_turn() -> void:
	busy = false
	selected = -1
	_refresh_chips()
	_update_movable()
	var is_red: bool = gs.turn == 0
	turn_lbl.text = "RED'S TURN" if is_red else "BLUE'S TURN"
	turn_lbl.add_theme_color_override("font_color", RED_COL if is_red else BLUE_COL)
	roll_btn.disabled = false
	if gs.unlocked[gs.turn]:
		_set_status("Roll the sticks!")
	else:
		_set_status("Roll a 1 to bring out your first coin")


func _on_roll() -> void:
	if busy or gs.phase != "roll":
		return
	busy = true
	roll_btn.disabled = true
	sfx.play("dice_roll")
	for i in 9:
		stick1.set_value(randi() % 4)
		stick2.set_value(randi() % 4)
		await get_tree().create_timer(0.1).timeout
	var a: int = randi() % 4
	var b: int = randi() % 4
	stick1.set_value(a)
	stick2.set_value(b)
	var v: int = a + b
	if v == 0:
		v = 12
	sum_lbl.text = str(v)
	var out: Dictionary = gs.on_roll(v)
	var kind: String = out["kind"]
	if kind == "fail_locked":
		sfx.play("fail")
		_set_status("Not a 1 - the turn passes")
		await get_tree().create_timer(1.2).timeout
		gs.next_turn()
		_begin_turn()
	elif kind == "unlock":
		sfx.play_result(v)
		_set_status("A 1! Your first coin is out - roll again")
		await _anim_move(gs.turn, out["coin"], -1, 0)
		_refresh_all(true)
		busy = false
		roll_btn.disabled = false
	elif kind == "more":
		sfx.play_result(v)
		_set_status("%d - bonus roll! Roll again" % v)
		_refresh_chips()
		busy = false
		roll_btn.disabled = false
	else:
		sfx.play_result(v)
		_refresh_chips()
		await _enter_spend()


func _has_legal_for(v: int) -> bool:
	for c in 12:
		if gs.can_move(gs.turn, c, v):
			return true
	return false


func _auto_select() -> void:
	var ok: bool = selected >= 0 and selected < gs.collected.size() and _has_legal_for(gs.collected[selected])
	if not ok:
		selected = -1
		for i in gs.collected.size():
			if _has_legal_for(gs.collected[i]):
				selected = i
				break
	_refresh_chips()
	_update_movable()


func _enter_spend() -> void:
	busy = true
	roll_btn.disabled = true
	if not gs.any_legal():
		_set_status("No legal move - numbers lost")
		await get_tree().create_timer(1.3).timeout
		_finish_spend()
		return
	_auto_select()
	_set_status("Tap a number, then tap a glowing coin")
	busy = false


func _on_chip(i: int) -> void:
	if busy or gs.phase != "spend" or i >= gs.collected.size():
		return
	if _has_legal_for(gs.collected[i]):
		sfx.play("tick")
		selected = i
		_refresh_chips()
		_update_movable()
	else:
		_set_status("%d has no legal move right now" % gs.collected[i])


func _unhandled_input(event: InputEvent) -> void:
	var e: InputEventMouseButton = event as InputEventMouseButton
	if e == null or not e.pressed or e.button_index != MOUSE_BUTTON_LEFT:
		return
	if busy or gs.phase != "spend" or selected < 0:
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
		_play_move(best)


func _play_move(c: int) -> void:
	busy = true
	var team: int = gs.turn
	var v: int = gs.collected[selected]
	var res: Dictionary = gs.do_move(team, c, v)
	gs.collected.remove_at(selected)
	selected = -1
	_update_movable()
	_refresh_chips()
	await _anim_move(team, c, res["from"], res["to"])
	var captured: Array = res["captured"]
	var landed: int = res["to"]
	if captured.size() > 0:
		sfx.play("capture")
		_set_status("Captured %d coin(s)! You get a bonus roll" % captured.size())
	elif landed == gs.n_sq:
		sfx.play("finish")
	elif landed >= 0 and gs.safe.has(gs.keys[team][landed]):
		sfx.play("safe")
	_refresh_all(true)
	await get_tree().create_timer(0.35).timeout
	if gs.winner >= 0:
		_show_win()
		return
	if gs.collected.is_empty() or not gs.any_legal():
		if not gs.collected.is_empty():
			_set_status("No more legal moves - leftover numbers lost")
			await get_tree().create_timer(1.0).timeout
		_finish_spend()
		return
	_auto_select()
	_set_status("Tap a number, then tap a glowing coin")
	busy = false


func _finish_spend() -> void:
	gs.collected.clear()
	selected = -1
	_refresh_chips()
	_update_movable()
	if gs.bonus_pending > 0:
		gs.bonus_pending -= 1
		gs.phase = "roll"
		busy = false
		roll_btn.disabled = false
		_set_status("Bonus roll for the capture!")
	else:
		gs.next_turn()
		_begin_turn()


func _show_win() -> void:
	busy = true
	sfx.fade_music(1.2)
	sfx.play("win")
	var is_red: bool = gs.winner == 0
	var col: Color = RED_COL if is_red else BLUE_COL
	var shade: ColorRect = ColorRect.new()
	shade.color = Color(0, 0, 0, 0.6)
	shade.position = Vector2.ZERO
	shade.size = Vector2(540, 960)
	shade.z_index = 50
	add_child(shade)
	var l: Label = _label("RED TEAM WINS!" if is_red else "BLUE TEAM WINS!", Vector2(0, 380), Vector2(540, 90), 52, col)
	l.z_index = 51
	var b: Button = Button.new()
	b.text = "PLAY AGAIN"
	b.position = Vector2(150, 500)
	b.size = Vector2(240, 80)
	b.add_theme_font_size_override("font_size", 28)
	_style_button(b, Color(0.12, 0.65, 1.0), CYAN, Color(0.02, 0.1, 0.22))
	b.z_index = 51
	b.pressed.connect(func() -> void: get_tree().reload_current_scene())
	add_child(b)
