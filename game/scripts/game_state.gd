class_name GameState
extends RefCounted
## The rules of Dhayam as plain code (no graphics). See RULES.md.
## Position of a coin: -1 = in base, 0..n_sq-1 = on a route square, n_sq = finished (in the oval).

const NO_MOVE := -99
const BONUS_ROLLS := [1, 5, 6, 12]

var routes: Array = [[], []]   # per team: Array of {pos, ang}
var keys: Array = [[], []]     # per team: Array of String (square identity, shared between teams)
var safe: Dictionary = {}      # key -> true for X squares
var n_sq: int = 0
var pos: Array = [[], []]      # pos[team][coin]
var unlocked: Array = [false, false]
var turn: int = 0
var collected: Array = []
var bonus_pending: int = 0
var phase: String = "roll"     # "roll", "spend" or "over"
var winner: int = -1


func _init() -> void:
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
	if v == 5 and has_base_coin(team):
		return NO_MOVE            # while a coin waits in base, a 5 can only bring a coin out
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
	if not unlocked[turn]:
		if v == 1:
			unlocked[turn] = true
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


func next_turn() -> void:
	turn = 1 - turn
	collected.clear()
	bonus_pending = 0
	phase = "roll"
