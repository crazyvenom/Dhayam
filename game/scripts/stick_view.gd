class_name StickView
extends Control
## One of the two dice sticks. Shows 0 to 3 dots.

var value: int = 0
var _body: StyleBoxFlat


func _init() -> void:
	custom_minimum_size = Vector2(46, 120)
	size = Vector2(46, 120)
	_body = StyleBoxFlat.new()
	_body.bg_color = Color(1.0, 0.86, 0.45)
	_body.set_corner_radius_all(16)
	_body.border_color = Color(1, 1, 1)
	_body.set_border_width_all(2)
	_body.shadow_color = Color(1.0, 0.7, 0.2, 0.55)
	_body.shadow_size = 12


func set_value(v: int) -> void:
	value = v
	queue_redraw()


func _draw() -> void:
	draw_style_box(_body, Rect2(Vector2.ZERO, size))
	var cx: float = size.x / 2.0
	var cy: float = size.y / 2.0
	var brown: Color = Color(0.42, 0.23, 0.0)
	if value == 0:
		draw_rect(Rect2(cx - 9, cy - 2, 18, 4), Color(brown.r, brown.g, brown.b, 0.6))
		return
	var spacing: float = 26.0
	var start: float = cy - (value - 1) * spacing / 2.0
	for i in value:
		draw_circle(Vector2(cx, start + i * spacing), 7.0, brown)
