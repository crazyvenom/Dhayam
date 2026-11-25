class_name Routes
extends RefCounted
## Board geometry. Coordinates are in "board units" (a 920 x 1140 drawing of the real board).
## NOTE: square counts per stretch are a first approximation and will be matched to the real board.

const RED_BASE := Vector2(230, 225)
const BLUE_BASE := Vector2(640, 225)
const OVAL := Vector2(455, 900)

## How many squares each stretch of the route has (10 stretches).
const COUNTS := [6, 5, 6, 12, 13, 12, 6, 6, 6, 6]


## Positions of the X (safe) squares on the board.
static func xs() -> Array:
	return [
		Vector2(95, 58), Vector2(440, 58), Vector2(785, 58),
		Vector2(75, 362), Vector2(440, 362), Vector2(805, 362),
		Vector2(75, 710), Vector2(805, 710),
		Vector2(75, 1062), Vector2(440, 1062), Vector2(805, 1062),
		Vector2(190, 465), Vector2(190, 805), Vector2(715, 450), Vector2(715, 795),
		Vector2(440, 700),
	]


static func waypoints(team: int) -> Array:
	var common: Array = [
		Vector2(440, 58), Vector2(440, 362), Vector2(805, 362), Vector2(805, 1062),
		Vector2(75, 1062), Vector2(75, 362), Vector2(440, 362), Vector2(440, 700),
	]
	if team == 0:  # Red: left half of top strip, finishes through the RIGHT inner arm
		return [Vector2(95, 58)] + common + [Vector2(715, 450), Vector2(715, 795)]
	# Blue: right half of top strip, finishes through the LEFT inner arm
	return [Vector2(785, 58)] + common + [Vector2(190, 465), Vector2(190, 805)]


## Returns the list of squares for a team: each is {"pos": Vector2, "ang": float}.
static func build(team: int) -> Array:
	var wps: Array = waypoints(team)
	var first_dir: Vector2 = (wps[1] as Vector2) - (wps[0] as Vector2)
	var out: Array = [{"pos": wps[0], "ang": first_dir.angle()}]
	for s in range(wps.size() - 1):
		var a: Vector2 = wps[s]
		var b: Vector2 = wps[s + 1]
		var n: int = COUNTS[s]
		var ang: float = (b - a).angle()
		for i in range(1, n + 1):
			out.append({"pos": a.lerp(b, float(i) / float(n)), "ang": ang})
	return out


static func key(p: Vector2) -> String:
	return "%d,%d" % [roundi(p.x), roundi(p.y)]


## Where coin number i of a team sits while in the base circle.
static func base_slot(team: int, i: int) -> Vector2:
	var c: Vector2 = RED_BASE if team == 0 else BLUE_BASE
	if i == 0:
		return c
	if i <= 4:
		var a: float = (i - 1) * PI / 2.0 + 0.4
		return c + Vector2(cos(a), sin(a)) * 30.0
	var a2: float = (i - 5) * TAU / 7.0
	return c + Vector2(cos(a2), sin(a2)) * 70.0


## Where coin number i of a team sits once it has reached the finish oval.
static func home_slot(team: int, i: int) -> Vector2:
	var col: int = i % 4
	var row: int = int(i / 4.0)
	var x: float = OVAL.x - 150.0 + col * 40.0 if team == 0 else OVAL.x + 150.0 - col * 40.0
	return Vector2(x, OVAL.y - 42.0 + row * 42.0)
