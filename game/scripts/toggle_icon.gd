class_name ToggleIcon
extends Control
## A round neon on/off button drawn in code: a music note ("music") or a speaker ("sfx").

signal toggled_state(on: bool)

const CYAN: Color = Color(0.31, 0.89, 1.0)
const OFF: Color = Color(0.5, 0.55, 0.7)

var kind: String = "music"
var on: bool = true


func _init(k: String = "music", initial: bool = true) -> void:
	kind = k
	on = initial
	custom_minimum_size = Vector2(46, 46)
	size = Vector2(46, 46)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _gui_input(event: InputEvent) -> void:
	var e: InputEventMouseButton = event as InputEventMouseButton
	if e != null and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		on = not on
		queue_redraw()
		toggled_state.emit(on)
		accept_event()


func _draw() -> void:
	var c: Vector2 = size / 2.0
	var col: Color = CYAN if (on or kind == "chat") else OFF
	draw_circle(c, 23.0, Color(col.r, col.g, col.b, 0.15))
	draw_circle(c, 21.0, Color(0.09, 0.12, 0.36, 0.95))
	draw_arc(c, 21.0, 0.0, TAU, 40, col, 2.5)
	if kind == "chat":
		Reactions.draw_face(self, c, 12.0, 0)
		return
	if kind == "music":
		draw_circle(c + Vector2(-5, 8), 5.5, col)
		draw_line(c + Vector2(0, 8), c + Vector2(0, -11), col, 3.0)
		draw_line(c + Vector2(0, -11), c + Vector2(9, -6), col, 3.0)
	else:
		var body: PackedVector2Array = PackedVector2Array([
			c + Vector2(-12, -4), c + Vector2(-6, -4), c + Vector2(1, -10),
			c + Vector2(1, 10), c + Vector2(-6, 4), c + Vector2(-12, 4)])
		draw_colored_polygon(body, col)
		if on:
			draw_arc(c + Vector2(1, 0), 7.0, -0.8, 0.8, 8, col, 2.5)
			draw_arc(c + Vector2(1, 0), 12.0, -0.8, 0.8, 10, col, 2.5)
	if not on:
		draw_line(c + Vector2(-14, 14), c + Vector2(14, -14), Color(1.0, 0.3, 0.4), 3.5)
