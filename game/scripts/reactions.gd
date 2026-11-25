class_name Reactions
extends RefCounted
## The quick reactions players can send: 6 drawn faces and 6 short phrases.
## Message numbers: 0-5 = faces, 6-11 = phrases (the server accepts 0-11).

const FACE_COUNT: int = 6
const PHRASES: Array = ["GG!", "Nice!", "Oops!", "Hurry up!", "Well done", "Thanks!"]


static func is_face(msg: int) -> bool:
	return msg >= 0 and msg < FACE_COUNT


static func phrase(msg: int) -> String:
	return PHRASES[clampi(msg - FACE_COUNT, 0, PHRASES.size() - 1)]


## Draws a face (0 smile, 1 laughing, 2 surprised, 3 angry, 4 crying, 5 cool) centred on c.
static func draw_face(ci: CanvasItem, c: Vector2, r: float, kind: int) -> void:
	var face: Color = Color(1.0, 0.82, 0.25)
	if kind == 3:
		face = Color(1.0, 0.45, 0.35)
	var dark: Color = Color(0.25, 0.14, 0.05)
	var w: float = maxf(2.0, r * 0.1)
	var tear: Color = Color(0.4, 0.7, 1.0)
	ci.draw_circle(c, r, face.darkened(0.35))
	ci.draw_circle(c, r * 0.92, face)
	var ex: float = r * 0.36
	var ey: float = c.y - r * 0.18
	var lp: Vector2 = Vector2(c.x - ex, ey)
	var rp: Vector2 = Vector2(c.x + ex, ey)
	match kind:
		0:
			ci.draw_circle(lp, r * 0.1, dark)
			ci.draw_circle(rp, r * 0.1, dark)
			ci.draw_arc(Vector2(c.x, c.y + r * 0.05), r * 0.5, 0.2 * PI, 0.8 * PI, 12, dark, w)
		1:
			ci.draw_arc(lp + Vector2(0, r * 0.08), r * 0.16, PI * 1.05, PI * 1.95, 8, dark, w)
			ci.draw_arc(rp + Vector2(0, r * 0.08), r * 0.16, PI * 1.05, PI * 1.95, 8, dark, w)
			var mouth: PackedVector2Array = PackedVector2Array()
			for i in 9:
				var a: float = PI * i / 8.0
				mouth.append(Vector2(c.x + cos(a) * r * 0.5, c.y + r * 0.1 + sin(a) * r * 0.45))
			ci.draw_colored_polygon(mouth, dark)
			ci.draw_circle(lp + Vector2(-r * 0.2, r * 0.3), r * 0.1, tear)
			ci.draw_circle(rp + Vector2(r * 0.2, r * 0.3), r * 0.1, tear)
		2:
			ci.draw_circle(lp, r * 0.13, dark)
			ci.draw_circle(rp, r * 0.13, dark)
			ci.draw_circle(Vector2(c.x, c.y + r * 0.4), r * 0.2, dark)
		3:
			ci.draw_circle(lp, r * 0.1, dark)
			ci.draw_circle(rp, r * 0.1, dark)
			ci.draw_line(Vector2(c.x - ex * 1.6, ey - r * 0.3), Vector2(c.x - ex * 0.4, ey - r * 0.1), dark, w)
			ci.draw_line(Vector2(c.x + ex * 1.6, ey - r * 0.3), Vector2(c.x + ex * 0.4, ey - r * 0.1), dark, w)
			ci.draw_arc(Vector2(c.x, c.y + r * 0.75), r * 0.4, 1.2 * PI, 1.8 * PI, 10, dark, w)
		4:
			ci.draw_circle(lp, r * 0.1, dark)
			ci.draw_circle(rp, r * 0.1, dark)
			ci.draw_arc(Vector2(c.x, c.y + r * 0.75), r * 0.4, 1.2 * PI, 1.8 * PI, 10, dark, w)
			ci.draw_line(lp + Vector2(0, r * 0.12), lp + Vector2(0, r * 0.55), tear, w)
			ci.draw_line(rp + Vector2(0, r * 0.12), rp + Vector2(0, r * 0.55), tear, w)
		_:
			ci.draw_rect(Rect2(c.x - ex * 1.7, ey - r * 0.14, ex * 1.4, r * 0.3), dark)
			ci.draw_rect(Rect2(c.x + ex * 0.3, ey - r * 0.14, ex * 1.4, r * 0.3), dark)
			ci.draw_line(Vector2(c.x - ex * 0.3, ey), Vector2(c.x + ex * 0.3, ey), dark, w)
			ci.draw_arc(Vector2(c.x, c.y + r * 0.05), r * 0.5, 0.2 * PI, 0.8 * PI, 12, dark, w)
