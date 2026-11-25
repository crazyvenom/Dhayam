class_name ReactionIcon
extends Control
## One tappable reaction: a face or a short phrase.

signal picked(msg: int)

var msg: int = 0


func _init(m: int = 0, sz: Vector2 = Vector2(64, 64)) -> void:
	msg = m
	custom_minimum_size = sz
	size = sz
	mouse_filter = Control.MOUSE_FILTER_STOP


func _gui_input(event: InputEvent) -> void:
	var e: InputEventMouseButton = event as InputEventMouseButton
	if e != null and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		picked.emit(msg)
		accept_event()


func _draw() -> void:
	if Reactions.is_face(msg):
		draw_circle(size / 2.0, minf(size.x, size.y) / 2.0 + 2.0, Color(0.31, 0.89, 1.0, 0.18))
		Reactions.draw_face(self, size / 2.0, minf(size.x, size.y) / 2.0 - 4.0, msg)
	else:
		draw_style_box(UI.box(Color(0.14, 0.18, 0.5), UI.CYAN, 12, 4.0), Rect2(Vector2.ZERO, size))
		var f: Font = ThemeDB.fallback_font
		draw_string(f, Vector2(0, size.y / 2.0 + 6.0), Reactions.phrase(msg), HORIZONTAL_ALIGNMENT_CENTER, size.x, 15, Color.WHITE)
