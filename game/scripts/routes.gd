class_name Routes
extends RefCounted
## Board geometry, measured from the clean board diagram (see RULES.md section 9).
## Coordinates are "board units" (a 920 x 1140 drawing).
##
## Squares on the real board:
##  top / middle / bottom rows : X, 5 cells, X(center), 5 cells, X
##  left / right columns       : X, 5 cells, X, 5 cells, X
##  upper center column        : 5 cells      lower center column: 5 cells then the bottom X
##  each diagonal              : 5 cells      each inner arm     : X, 5 cells, X
##  two small X squares sit beside the first cell of the lower center column.

const RED_BASE := Vector2(255, 254)
const BLUE_BASE := Vector2(679, 254)
const BASE_R := 100.0
const OVAL := Vector2(463, 940)
const OVAL_RX := 115.0
const OVAL_RY := 63.0

# Key points
const TL := Vector2(89, 84)
const TC := Vector2(460, 84)
const TR := Vector2(830, 84)
const ML := Vector2(89, 415)
const MC := Vector2(460, 415)
const MR := Vector2(830, 415)
const BL := Vector2(89, 1049)
const BR := Vector2(830, 1049)
const COL1 := Vector2(460, 478)    # first cell of the lower center column
const BX := Vector2(460, 800)      # bottom X where the diagonals meet
const SMALL_L := Vector2(394, 478)
const SMALL_R := Vector2(526, 478)

## Steps along each stretch of a route (both teams use the same counts).
const COUNTS := [6, 6, 6, 12, 12, 12, 5, 1, 1, 5, 6, 6]


## Positions of the X (safe) squares on the board.
static func xs() -> Array:
	return [
		TL, TC, TR, ML, MC, MR, BL, BR, Vector2(460, 1049),
		Vector2(89, 729), Vector2(830, 729),
		SMALL_L, SMALL_R, BX,
		Vector2(196, 531), Vector2(196, 866), Vector2(725, 531), Vector2(725, 866),
	]


## Red travels the outer ring counterclockwise, Blue clockwise (mirror images).
static func waypoints(team: int) -> Array:
	if team == 0:
		return [TL, TC, MC, ML, BL, BR, MR, Vector2(522, 415), SMALL_R, COL1, BX,
			Vector2(725, 531), Vector2(725, 866)]
	return [TR, TC, MC, MR, BR, BL, ML, Vector2(398, 415), SMALL_L, COL1, BX,
		Vector2(196, 531), Vector2(196, 866)]


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
	return c + Vector2(cos(a2), sin(a2)) * 68.0


## Where coin number i sits once it has reached the finish oval (drawn smaller there).
static func home_slot(team: int, i: int) -> Vector2:
	var col: int = i % 4
	var row: int = int(i / 4.0)
	var x: float = OVAL.x - 96.0 + col * 26.0 if team == 0 else OVAL.x + 96.0 - col * 26.0
	return Vector2(x, OVAL.y + (row - 1) * 26.0)
