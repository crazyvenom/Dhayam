class_name Coin
extends Node2D
## One glossy neon coin.

const LIGHT := [Color(1.0, 0.64, 0.69), Color(0.62, 0.83, 1.0)]
const DARK := [Color(0.82, 0.06, 0.23), Color(0.10, 0.30, 0.88)]

var team: int = 0
var coin_id: int = 0
var movable: bool = false:
	set(v):
		movable = v
		queue_redraw()
var _t: float = 0.0


func _process(delta: float) -> void:
	if movable:
		_t += delta
		queue_redraw()


func _draw() -> void:
	var light: Color = LIGHT[team]
	var dark: Color = DARK[team]
	draw_circle(Vector2.ZERO, 31.0, Color(light.r, light.g, light.b, 0.16))   # soft glow
	draw_circle(Vector2(3, 8), 22.0, Color(0, 0, 0, 0.35))                     # shadow
	draw_circle(Vector2.ZERO, 22.0, dark)
	draw_circle(Vector2(-3, -4), 17.0, dark.lerp(light, 0.45))
	draw_circle(Vector2(-6, -8), 10.0, light)
	draw_arc(Vector2.ZERO, 22.0, 0.0, TAU, 40, Color(1, 1, 1, 0.55), 2.5)
	draw_circle(Vector2(-8, -10), 4.0, Color(1, 1, 1, 0.75))
	if movable:
		var r: float = 29.0 + sin(_t * 6.0) * 3.0
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, Color(0.31, 0.89, 1.0, 0.95), 3.5)
