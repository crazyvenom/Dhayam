class_name MicButton
extends Control
## The big round talk button. Hold it to talk (or tap it in open-mic mode).

signal pressed_down
signal released

const CYAN: Color = Color(0.31, 0.89, 1.0)

var active: bool = false      # drawn glowing while you are being heard
var muted: bool = false       # open-mic mode: crossed out when muted


func _init(px: float = 76.0) -> void:
	size = Vector2(px, px)
	custom_minimum_size = Vector2(px, px)
	mouse_filter = Control.MOUSE_FILTER_STOP


func set_active(v: bool) -> void:
	active = v
	queue_redraw()


func set_muted(v: bool) -> void:
	muted = v
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var e: InputEventMouseButton = event as InputEventMouseButton
	if e != null and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			pressed_down.emit()
		else:
			released.emit()
		accept_event()


func _draw() -> void:
	var c: Vector2 = size / 2.0
	var r: float = minf(size.x, size.y) / 2.0 - 4.0
	var col: Color = Color(0.4, 1.0, 0.6) if active else CYAN
	if muted:
		col = Color(0.5, 0.55, 0.7)
	draw_circle(c, r + 4.0, Color(col.r, col.g, col.b, 0.35 if active else 0.15))
	draw_circle(c, r, Color(0.09, 0.12, 0.36, 0.97))
	draw_arc(c, r, 0.0, TAU, 48, col, 3.5)
	var k: float = r / 38.0
	# microphone: capsule, cradle, stand
	draw_circle(c + Vector2(0, -9) * k, 8.0 * k, col)
	draw_rect(Rect2(c.x - 8.0 * k, c.y - 9.0 * k, 16.0 * k, 17.0 * k), col)
	draw_circle(c + Vector2(0, 8) * k, 8.0 * k, col)
	draw_arc(c + Vector2(0, 6) * k, 15.0 * k, 0.0, PI, 18, col, 3.0 * k)
	draw_line(c + Vector2(0, 21) * k, c + Vector2(0, 28) * k, col, 3.0 * k)
	draw_line(c + Vector2(-9, 28) * k, c + Vector2(9, 28) * k, col, 3.0 * k)
	if muted:
		draw_line(c + Vector2(-24, 24) * k, c + Vector2(24, -24) * k, Color(1.0, 0.3, 0.4), 4.5 * k)
