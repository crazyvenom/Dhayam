class_name BoardView
extends Node2D
## Draws the Neon Arena board from the squares in the rules engine.

var gs: GameState

var _panel: StyleBoxFlat
var _glow: StyleBoxFlat
var _sq: StyleBoxFlat
var _sq_red: StyleBoxFlat
var _sq_blue: StyleBoxFlat
var _sq_x: StyleBoxFlat

const CYAN := Color(0.31, 0.89, 1.0)
const PINK := Color(1.0, 0.31, 0.85)


func _ready() -> void:
	_panel = _box(Color(0.063, 0.086, 0.314), CYAN, 3, 40)
	_glow = _box(Color(0.31, 0.89, 1.0, 0.16), Color(0, 0, 0, 0), 0, 18)
	_sq = _box(Color(0.11, 0.14, 0.44), CYAN, 3, 8)
	_sq_red = _box(Color(0.20, 0.10, 0.36), Color(1.0, 0.45, 0.55), 3, 8)
	_sq_blue = _box(Color(0.10, 0.16, 0.46), Color(0.45, 0.70, 1.0), 3, 8)
	_sq_x = _box(Color(0.23, 0.11, 0.53), PINK, 3, 8)
	queue_redraw()


## Squares on straight stretches are drawn perfectly upright, only the diagonals stay tilted.
func _snap(a: float) -> float:
	var q: float = roundf(a / (PI / 2.0)) * (PI / 2.0)
	return q if absf(a - q) < 0.25 else a


func _box(bg: Color, border: Color, bw: int, radius: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	return s


func _draw() -> void:
	if gs == null or _panel == null:
		return
	var font: Font = ThemeDB.fallback_font
	draw_style_box(_panel, Rect2(8, 8, 904, 1124))

	# Bases
	for t in 2:
		var c: Vector2 = Routes.RED_BASE if t == 0 else Routes.BLUE_BASE
		var col: Color = Color(1.0, 0.45, 0.55) if t == 0 else Color(0.45, 0.70, 1.0)
		var r: float = Routes.BASE_R
		draw_circle(c, r, Color(col.r, col.g, col.b, 0.07))
		draw_arc(c, r, 0.0, TAU, 72, Color(col.r, col.g, col.b, 0.25), 14.0)
		draw_arc(c, r, 0.0, TAU, 72, col, 4.0)
		draw_string(font, c + Vector2(-150, -r - 8), "RED BASE" if t == 0 else "BLUE BASE",
			HORIZONTAL_ALIGNMENT_CENTER, 300, 20, Color(col.r, col.g, col.b, 0.9))

	# Finish oval
	draw_set_transform(Routes.OVAL, 0.0, Vector2(1.0, Routes.OVAL_RY / Routes.OVAL_RX))
	draw_circle(Vector2.ZERO, Routes.OVAL_RX, Color(0.31, 0.89, 1.0, 0.07))
	draw_arc(Vector2.ZERO, Routes.OVAL_RX, 0.0, TAU, 96, Color(0.31, 0.89, 1.0, 0.25), 14.0)
	draw_arc(Vector2.ZERO, Routes.OVAL_RX, 0.0, TAU, 96, CYAN, 4.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_string(font, Routes.OVAL + Vector2(-150, -Routes.OVAL_RY - 12), "FINISH",
		HORIZONTAL_ALIGNMENT_CENTER, 300, 24, Color(0.62, 0.86, 1.0, 0.6))

	# Collect each unique square once (squares shared by both teams are drawn once)
	var squares: Dictionary = {}
	var owners: Dictionary = {}
	for t in 2:
		for s in gs.routes[t]:
			var k: String = Routes.key(s["pos"])
			if not squares.has(k):
				squares[k] = s
				owners[k] = t
			elif owners[k] != t:
				owners[k] = -1   # shared

	# Pass 1: glow under every square
	for k in squares:
		var s: Dictionary = squares[k]
		draw_set_transform(s["pos"], 0.0 if gs.safe.has(k) else _snap(s["ang"]), Vector2.ONE)
		draw_style_box(_glow, Rect2(-34, -34, 68, 68))
	# Pass 2: square bodies
	for k in squares:
		var s2: Dictionary = squares[k]
		var is_safe: bool = gs.safe.has(k)
		draw_set_transform(s2["pos"], 0.0 if is_safe else _snap(s2["ang"]), Vector2.ONE)
		var box: StyleBoxFlat = _sq
		if is_safe:
			box = _sq_x
		elif owners[k] == 0:
			box = _sq_red
		elif owners[k] == 1:
			box = _sq_blue
		draw_style_box(box, Rect2(-25, -25, 50, 50))
		if is_safe:
			draw_line(Vector2(-20, -20), Vector2(20, 20), PINK, 3.0)
			draw_line(Vector2(20, -20), Vector2(-20, 20), PINK, 3.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
