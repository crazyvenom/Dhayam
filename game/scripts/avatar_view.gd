class_name AvatarView
extends Control
## A round coloured avatar showing the first letter of a name.

signal picked(index: int)

const COLORS: Array = [
	Color(1.0, 0.45, 0.55), Color(1.0, 0.65, 0.30), Color(0.95, 0.85, 0.30), Color(0.45, 0.90, 0.50),
	Color(0.31, 0.89, 1.00), Color(0.45, 0.60, 1.00), Color(0.70, 0.50, 1.00), Color(1.00, 0.50, 0.85),
]

var idx: int = 0
var letter: String = "?"
var selected: bool = false
var clickable: bool = false


func _init(i: int = 0, letter_text: String = "?", px: float = 44.0) -> void:
	idx = i % COLORS.size()
	letter = letter_text.left(1).to_upper()
	custom_minimum_size = Vector2(px, px)
	size = Vector2(px, px)
	mouse_filter = Control.MOUSE_FILTER_PASS


func set_letter(t: String) -> void:
	letter = t.left(1).to_upper() if t != "" else "?"
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var e: InputEventMouseButton = event as InputEventMouseButton
	if clickable and e != null and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		picked.emit(idx)
		accept_event()


func _draw() -> void:
	var c: Vector2 = size / 2.0
	var r: float = minf(size.x, size.y) / 2.0 - 3.0
	var col: Color = COLORS[idx]
	draw_circle(c, r + 3.0, Color(col.r, col.g, col.b, 0.25 if not selected else 0.55))
	draw_circle(c, r, col.darkened(0.35))
	draw_circle(c + Vector2(-r * 0.2, -r * 0.25), r * 0.72, col)
	draw_arc(c, r, 0.0, TAU, 36, Color(1, 1, 1, 0.9 if selected else 0.4), 3.0 if selected else 2.0)
	var fs: int = int(r * 1.1)
	var f: Font = ThemeDB.fallback_font
	draw_string(f, Vector2(0, c.y + fs * 0.36), letter, HORIZONTAL_ALIGNMENT_CENTER, size.x, fs, Color(1, 1, 1))
