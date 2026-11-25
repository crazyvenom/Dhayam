class_name GameState
extends RefCounted
## The rules of Dhayam as plain code (no graphics). See RULES.md.
## It is a deterministic state machine: given the same list of actions (dice results and
## moves) it always ends in the same state. The server decides the dice; every phone replays
## the same actions, so all screens stay identical.
##
## Position of a coin: -1 = in base, 0..n_sq-1 = on a route square, n_sq = finished (in the oval).

const NO_MOVE := -99
const BONUS_ROLLS := [1, 5, 6, 12]

var routes: Array = [[], []]   # per team: Array of {pos, ang}
var keys: Array = [[], []]     # per team: Array of String (square identity, shared between teams)
var safe: Dictionary = {}      # key -> true for X squares
var n_sq: int = 0
var pos: Array = [[], []]      # pos[team][coin]
var players: Array = []        # [{"team": int}] one entry per player (index = player number)
var members: Array = [[], []]  # team -> player numbers
var rot: Array = [0, 0]        # per team: how many turns the team has finished (for rotation)
var active: int = 0            # player number whose turn it is
var unlocked: Array = []       # per player: has rolled their first 1
var turn: int = 0              # team whose turn it is
var collected: Array = []
var bonus_pending: int = 0
var phase: String = "roll"     # "roll", "spend" or "over"
var winner: int = -1


## player_teams: the team (0 = Red, 1 = Blue) of each player. Default: one player per team.
func _init(player_teams: Array = [0, 1]) -> void:
	var all: Dictionary = {}
	for t in 2:
		routes[t] = Routes.build(t)
		var ks: Array = []
		for s in routes[t]:
			var k: String = Routes.key(s["pos"])
			ks.append(k)
			all[k] = s["pos"]
		keys[t] = ks
		var ps: Array = []
		for c in 12:
			ps.append(-1)
		pos[t] = ps
	n_sq = routes[0].size()
	# Mark safe squares: the square nearest to each X on the board
	for x in Routes.xs():
		var best: String = ""
		var best_d: float = 1e9
		for k in all:
			var d: float = (all[k] as Vector2).distance_to(x)
			if d < best_d:
				best_d = d
				best = k
		if best_d < 45.0:
			safe[best] = true
	for i in player_teams.size():
		var t: int = player_teams[i]
		players.append({"team": t})
		members[t].append(i)
		unlocked.append(false)
	active = members[0][0] if members[0].size() > 0 else members[1][0]
	turn = players[active]["team"]


func is_bonus(v: int) -> bool:
	return BONUS_ROLLS.has(v)


## Coins of the other team standing on the square with this key.
func opponents_at(team: int, k: String) -> Array:
	var res: Array = []
	var o: int = 1 - team
	for c in 12:
		var p: int = pos[o][c]
		if p >= 0 and p < n_sq and keys[o][p] == k:
			res.append(c)
	return res


## Where would this coin land with this number? NO_MOVE if the move is not allowed.
func dest(team: int, coin: int, v: int) -> int:
	var p: int = pos[team][coin]
	if p == n_sq:
		return NO_MOVE
	if p == -1:
		return 0 if (v == 1 or v == 5) else NO_MOVE
	if (v == 5 or v == 1) and has_base_coin(team):
		return NO_MOVE            # while a coin waits in base, a 1 or 5 can only bring a coin out
	var d: int = p + v
	if d > n_sq:
		return NO_MOVE            # exact roll needed to enter the finish
	if d == n_sq:
		return d
	var k: String = keys[team][d]
	if safe.has(k) and opponents_at(team, k).size() > 0:
		return NO_MOVE            # opponent holds this safe square
	return d


func can_move(team: int, coin: int, v: int) -> bool:
	return dest(team, coin, v) != NO_MOVE


func any_legal() -> bool:
	for v in collected:
		for c in 12:
			if can_move(turn, c, v):
				return true
	return false


func has_base_coin(team: int) -> bool:
	return first_base_coin(team) >= 0


func first_base_coin(team: int) -> int:
	for c in 12:
		if pos[team][c] == -1:
			return c
	return -1


## Process a dice result for the current player. Returns {"kind": ..., "coin": ...}
##  fail_locked : player has not unlocked yet and did not roll a 1 -> turn passes
##  unlock      : rolled the first 1 -> a coin came out, roll again
##  more        : bonus number collected, roll again
##  spend       : rolling is over, spend the collected numbers
func on_roll(v: int) -> Dictionary:
	if not unlocked[active]:
		if v == 1:
			unlocked[active] = true
			var c: int = first_base_coin(turn)
			if c >= 0:
				pos[turn][c] = 0
			return {"kind": "unlock", "coin": c}
		return {"kind": "fail_locked", "coin": -1}
	collected.append(v)
	if is_bonus(v):
		return {"kind": "more", "coin": -1}
	phase = "spend"
	return {"kind": "spend", "coin": -1}


## Apply a move of the current team's coin with number v.
func do_move(team: int, coin: int, v: int) -> Dictionary:
	var from: int = pos[team][coin]
	var d: int = dest(team, coin, v)
	var captured: Array = []
	pos[team][coin] = d
	if d >= 0 and d < n_sq:
		var k: String = keys[team][d]
		if not safe.has(k):
			captured = opponents_at(team, k)
			for oc in captured:
				pos[1 - team][oc] = -1
	if captured.size() > 0:
		bonus_pending += 1
	var finished: bool = d == n_sq
	if finished:
		var all_in: bool = true
		for p in pos[team]:
			if p != n_sq:
				all_in = false
		if all_in:
			winner = team
			phase = "over"
	return {"from": from, "to": d, "captured": captured, "finished": finished}


## End the turn: rotate to the next team and its next player.
func next_turn() -> void:
	rot[turn] += 1
	var other: int = 1 - turn
	if members[other].size() > 0:
		turn = other
	var m: Array = members[turn]
	active = m[rot[turn] % m.size()]
	collected.clear()
	bonus_pending = 0
	phase = "roll"


# ------------------------------------------------------------------ actions (used by app and server)

func _turn_event() -> Dictionary:
	return {"t": "turn", "team": turn, "player": active}


## The dice were thrown (a and b are the two sticks, 0 to 3 each). Returns the events that happened,
## or an empty array if the action is not allowed right now.
func apply_roll(a: int, b: int) -> Array:
	var ev: Array = []
	if phase != "roll" or a < 0 or a > 3 or b < 0 or b > 3:
		return ev
	var v: int = a + b
	if v == 0:
		v = 12
	var player: int = active
	var team: int = turn
	var out: Dictionary = on_roll(v)
	var kind: String = out["kind"]
	ev.append({"t": "roll", "a": a, "b": b, "v": v, "kind": kind, "player": player, "team": team,
		"chips": collected.duplicate()})
	if kind == "fail_locked":
		next_turn()
		ev.append(_turn_event())
	elif kind == "unlock":
		ev.append({"t": "unlock", "team": team, "coin": out["coin"]})
	elif kind == "spend":
		if not any_legal():
			ev.append({"t": "lost"})
			ev.append_array(finish_spend())
	return ev


## The current player moved a coin using the collected number at index chip.
func apply_move(coin: int, chip: int) -> Array:
	var ev: Array = []
	if phase != "spend" or chip < 0 or chip >= collected.size() or coin < 0 or coin > 11:
		return ev
	var v: int = collected[chip]
	if not can_move(turn, coin, v):
		return ev
	var team: int = turn
	var res: Dictionary = do_move(team, coin, v)
	collected.remove_at(chip)
	ev.append({"t": "move", "team": team, "coin": coin, "v": v, "from": res["from"], "to": res["to"],
		"captured": res["captured"], "finished": res["finished"], "chips": collected.duplicate()})
	if winner >= 0:
		ev.append({"t": "win", "team": winner})
		return ev
	if collected.is_empty() or not any_legal():
		if not collected.is_empty():
			ev.append({"t": "lost"})
		ev.append_array(finish_spend())
	return ev


## Rolling and spending are over for this turn: either a bonus roll or the next player.
func finish_spend() -> Array:
	collected.clear()
	if bonus_pending > 0:
		bonus_pending -= 1
		phase = "roll"
		return [{"t": "bonus", "player": active}]
	next_turn()
	return [_turn_event()]


## Which coins could move with the collected number at index chip?
func legal_coins(chip: int) -> Array:
	var res: Array = []
	if chip < 0 or chip >= collected.size():
		return res
	for c in 12:
		if can_move(turn, c, collected[chip]):
			res.append(c)
	return res


## A simple computer player: capture > finish > bring a coin out > reach a safe square > progress.
## Returns {"chip": index, "coin": coin} or an empty dictionary if nothing is possible.
func best_move() -> Dictionary:
	var best: Dictionary = {}
	var best_score: float = -1e9
	for i in collected.size():
		var v: int = collected[i]
		for c in 12:
			var d: int = dest(turn, c, v)
			if d == NO_MOVE:
				continue
			var p: int = pos[turn][c]
			var s: float = float(d) * 0.2
			if d == n_sq:
				s += 80.0
			elif d >= 0:
				var k: String = keys[turn][d]
				var victims: int = 0 if safe.has(k) else opponents_at(turn, k).size()
				if victims > 0:
					s += 100.0 + 10.0 * victims
				if safe.has(k):
					s += 25.0
			if p == -1:
				s += 50.0
			elif safe.has(keys[turn][p]):
				s -= 5.0
			if s > best_score:
				best_score = s
				best = {"chip": i, "coin": c}
	return best
