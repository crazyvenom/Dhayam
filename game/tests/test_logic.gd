extends SceneTree
## Plays many random games with the rules engine and checks that nothing breaks.
## Run:  Godot --headless --path game --script res://tests/test_logic.gd

const GAMES: int = 1500
var problems: int = 0


func check(cond: bool, msg: String) -> void:
	if not cond:
		problems += 1
		if problems < 15:
			print("PROBLEM: ", msg)


func _init() -> void:
	var gs0 := GameState.new()
	print("squares per route: ", gs0.n_sq, "   safe squares: ", gs0.safe.size())
	check(gs0.routes[0].size() == gs0.routes[1].size(), "routes differ in length")

	# Rule: with a coin still in base, a 5 may only bring a coin out
	var t := GameState.new()
	t.pos[0][0] = 10                       # one coin on the board, 11 still in base
	check(not t.can_move(0, 0, 5), "5 must not move a board coin while a coin is in base")
	check(t.can_move(0, 1, 5), "5 must bring a base coin out")
	check(t.can_move(0, 0, 3), "3 should still move a board coin")
	check(t.can_move(0, 0, 1), "1 should still move a board coin")
	for c in 12:
		t.pos[0][c] = 10 + c               # nobody left in base
	check(t.can_move(0, 0, 5), "5 must move a coin once the base is empty")
	print("5-rule checks done")

	# Dice odds over all 16 stick combinations
	var counts: Dictionary = {}
	for a in 4:
		for b in 4:
			var v: int = a + b
			if v == 0:
				v = 12
			counts[v] = counts.get(v, 0) + 1
	print("dice odds (out of 16): ", counts)

	var wins: Array = [0, 0]
	var unfinished: int = 0
	var total_turns: int = 0
	var captures: int = 0
	for g in GAMES:
		var gs := GameState.new()
		var turns: int = 0
		while gs.winner < 0 and turns < 6000:
			turns += 1
			var rolling: bool = true
			var spent_all: bool = false
			while rolling:
				var a: int = randi() % 4
				var b: int = randi() % 4
				var v: int = a + b
				if v == 0:
					v = 12
				var out: Dictionary = gs.on_roll(v)
				match out["kind"]:
					"fail_locked":
						rolling = false
						spent_all = true
					"unlock", "more":
						pass
					"spend":
						rolling = false
			if not spent_all:
				while not gs.collected.is_empty() and gs.any_legal():
					var options: Array = []
					for i in gs.collected.size():
						for c in 12:
							if gs.can_move(gs.turn, c, gs.collected[i]):
								options.append([i, c])
					var pick: Array = options[randi() % options.size()]
					var vv: int = gs.collected[pick[0]]
					var res: Dictionary = gs.do_move(gs.turn, pick[1], vv)
					gs.collected.remove_at(pick[0])
					captures += (res["captured"] as Array).size()
					_check_board(gs)
					if gs.winner >= 0:
						break
			if gs.winner >= 0:
				break
			gs.collected.clear()
			if gs.bonus_pending > 0:
				gs.bonus_pending -= 1
				gs.phase = "roll"
			else:
				gs.next_turn()
		total_turns += turns
		if gs.winner >= 0:
			wins[gs.winner] += 1
		else:
			unfinished += 1
	print(GAMES, " random games -> red wins: ", wins[0], "  blue wins: ", wins[1], "  unfinished: ", unfinished)
	print("average turns per game: ", total_turns / GAMES, "   captures seen: ", captures)
	print("PROBLEMS FOUND: ", problems)
	quit(1 if problems > 0 else 0)


func _check_board(gs: GameState) -> void:
	# Two different teams must never share an X square.
	for c0 in 12:
		var p0: int = gs.pos[0][c0]
		if p0 < 0 or p0 >= gs.n_sq:
			continue
		var k: String = gs.keys[0][p0]
		for c1 in 12:
			var p1: int = gs.pos[1][c1]
			if p1 >= 0 and p1 < gs.n_sq and gs.keys[1][p1] == k:
				check(not gs.safe.has(k), "both teams on safe square " + k)
				check(false, "teams share a square " + k)
