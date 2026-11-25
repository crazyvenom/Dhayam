extends SceneTree
## Plays many random games with the rules engine and checks that nothing breaks.
## Run:  Godot --headless --path game --script res://tests/test_logic.gd

const GAMES: int = 400
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
	unit_tests()

	var layouts: Array = [
		[0, 1], [0, 0, 1], [0, 1, 1, 1], [0, 0, 0, 1, 1], [0, 0, 0, 0, 0, 1, 1, 1, 1, 1], [0, 1, 0, 1, 0, 1],
	]
	var wins: Array = [0, 0]
	var unfinished: int = 0
	var total_actions: int = 0
	var captures: int = 0
	for g in GAMES:
		var teams: Array = layouts[g % layouts.size()]
		var gs := GameState.new(teams)
		var log: Array = []
		var played: Dictionary = {}
		var actions: int = 0
		while gs.winner < 0 and actions < 40000:
			actions += 1
			var player_before: int = gs.active
			played[player_before] = true
			var ev: Array
			if gs.phase == "roll":
				var a: int = randi() % 4
				var b: int = randi() % 4
				ev = gs.apply_roll(a, b)
				log.append({"k": "roll", "a": a, "b": b})
			else:
				var options: Array = []
				for i in gs.collected.size():
					for c in gs.legal_coins(i):
						options.append([i, c])
				check(options.size() > 0, "spend phase with no legal move")
				if options.is_empty():
					break
				# half the time play the computer's choice, half random
				var pick: Array = options[randi() % options.size()]
				if randi() % 2 == 0:
					var bm: Dictionary = gs.best_move()
					pick = [bm["chip"], bm["coin"]]
				ev = gs.apply_move(pick[1], pick[0])
				log.append({"k": "move", "coin": pick[1], "chip": pick[0]})
				for e in ev:
					if e["t"] == "move":
						captures += (e["captured"] as Array).size()
			check(ev.size() > 0, "valid action returned no events")
			check(gs.turn == gs.players[gs.active]["team"], "turn team does not match active player")
			board_check(gs)
		total_actions += actions
		if gs.winner >= 0:
			wins[gs.winner] += 1
			# every player of both teams should have had turns in a long game
			for i in gs.players.size():
				check(played.has(i), "player %d never played (layout %s)" % [i, str(teams)])
			# replaying the log must give the identical game
			var rp := GameState.new(teams)
			for act in log:
				if act["k"] == "roll":
					rp.apply_roll(act["a"], act["b"])
				else:
					rp.apply_move(act["coin"], act["chip"])
			check(rp.pos == gs.pos and rp.active == gs.active and rp.winner == gs.winner, "replay differs")
		else:
			unfinished += 1
	print(GAMES, " random games -> red wins: ", wins[0], "  blue wins: ", wins[1], "  unfinished: ", unfinished)
	print("average actions per game: ", total_actions / GAMES, "   captures seen: ", captures)
	print("PROBLEMS FOUND: ", problems)
	quit(1 if problems > 0 else 0)


func unit_tests() -> void:
	# The 1 and 5 rule: while a coin is in base, only a base coin may use a 1 or 5
	var t := GameState.new()
	t.pos[0][0] = 10
	check(not t.can_move(0, 0, 5), "5 must not move a board coin while a coin is in base")
	check(t.can_move(0, 1, 5), "5 must bring a base coin out")
	check(not t.can_move(0, 0, 1), "1 must not move a board coin while a coin is in base")
	check(t.can_move(0, 1, 1), "1 must bring a base coin out")
	check(t.can_move(0, 0, 3), "3 should move a board coin")
	for c in 12:
		t.pos[0][c] = 10 + c
	check(t.can_move(0, 0, 5), "5 must move a coin once the base is empty")
	check(t.can_move(0, 0, 1), "1 must move a coin once the base is empty")

	# Unlocking is per player: 2 Red players, 1 Blue player
	var u := GameState.new([0, 0, 1])
	check(u.active == 0 and u.turn == 0, "Red player 0 should start")
	var ev: Array = u.apply_roll(0, 1)          # a 1: unlock + coin out
	check(u.unlocked[0] and not u.unlocked[1], "only the rolling player unlocks")
	check(ev[1]["t"] == "unlock", "first 1 should unlock")
	ev = u.apply_roll(1, 1)                       # 2: ends rolling, player 0 has a coin out
	check(ev[0]["kind"] == "spend", "a 2 after unlocking ends the roll")
	u.apply_move(0, 0)                            # move the coin 2 squares
	check(u.turn == 1 and u.active == 2, "after Red it is Blue's turn (player 2)")
	u.apply_roll(0, 2)                            # Blue player rolls a 2 but is locked
	check(u.turn == 0 and u.active == 1, "after Blue, Red's SECOND player is next")
	ev = u.apply_roll(1, 1)                       # Red player 1 rolls a 2 but is still locked
	check(ev[0]["kind"] == "fail_locked", "teammate must unlock on their own")

	# Rotation: Red 0, Blue 2, Red 1, Blue 2, Red 0 ...
	var r := GameState.new([0, 0, 1])
	var order: Array = []
	for i in 6:
		order.append(r.active)
		r.apply_roll(0, 2)                        # always a failed (locked) roll
	check(order == [0, 2, 1, 2, 0, 2], "turn rotation wrong: %s" % str(order))

	# Invalid actions are rejected
	var v := GameState.new()
	check(v.apply_move(0, 0).is_empty(), "move before any roll must be rejected")
	check(v.apply_roll(4, 0).is_empty(), "bad dice value must be rejected")
	print("unit tests done")


func board_check(gs: GameState) -> void:
	# Two different teams must never share a square.
	for c0 in 12:
		var p0: int = gs.pos[0][c0]
		if p0 < 0 or p0 >= gs.n_sq:
			continue
		var k: String = gs.keys[0][p0]
		for c1 in 12:
			var p1: int = gs.pos[1][c1]
			if p1 >= 0 and p1 < gs.n_sq and gs.keys[1][p1] == k:
				check(false, "teams share a square " + k)
