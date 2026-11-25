class_name UI
extends RefCounted
## Small helpers to build the neon-style screens (menu, lobby) in code.

const CYAN: Color = Color(0.31, 0.89, 1.0)
const RED_COL: Color = Color(1.0, 0.45, 0.55)
const BLUE_COL: Color = Color(0.45, 0.70, 1.0)
const PINK: Color = Color(1.0, 0.31, 0.85)


static func label(parent: Node, text: String, pos: Vector2, sz: Vector2, font_size: int, col: Color,
		align: int = HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.position = pos
	l.size = sz
	l.horizontal_alignment = align as HorizontalAlignment
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", col)
	parent.add_child(l)
	return l


static func box(bg: Color, border: Color, radius: int = 14, glow: float = 8.0) -> StyleBoxFlat:
	var s: StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(2)
	s.set_corner_radius_all(radius)
	s.shadow_color = Color(border.r, border.g, border.b, 0.45)
	s.shadow_size = int(glow)
	return s


static func style_button(b: Button, bg: Color, border: Color, text_col: Color) -> void:
	for state in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(state, box(bg, border))
	b.add_theme_stylebox_override("disabled", box(bg.darkened(0.55), border.darkened(0.6)))
	for cname in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(cname, text_col)
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.35))


static func button(parent: Node, text: String, pos: Vector2, sz: Vector2, font_size: int,
		bg: Color = Color(0.12, 0.65, 1.0), border: Color = Color(0.31, 0.89, 1.0),
		text_col: Color = Color(0.02, 0.1, 0.22)) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.position = pos
	b.size = sz
	b.add_theme_font_size_override("font_size", font_size)
	style_button(b, bg, border, text_col)
	parent.add_child(b)
	return b


static func line_edit(parent: Node, placeholder: String, pos: Vector2, sz: Vector2, font_size: int) -> LineEdit:
	var e: LineEdit = LineEdit.new()
	e.placeholder_text = placeholder
	e.position = pos
	e.size = sz
	e.alignment = HORIZONTAL_ALIGNMENT_CENTER
	e.add_theme_font_size_override("font_size", font_size)
	e.add_theme_stylebox_override("normal", box(Color(0.06, 0.09, 0.30), CYAN.darkened(0.2), 14, 4.0))
	e.add_theme_stylebox_override("focus", box(Color(0.08, 0.12, 0.38), CYAN, 14, 8.0))
	e.add_theme_color_override("font_color", Color.WHITE)
	e.add_theme_color_override("font_placeholder_color", Color(1, 1, 1, 0.35))
	e.add_theme_color_override("caret_color", CYAN)
	parent.add_child(e)
	return e


## The dark neon background used by the menu and the lobby.
static func draw_background(n: CanvasItem) -> void:
	n.draw_rect(Rect2(0, 0, 540, 960), Color(0.043, 0.063, 0.188))
	n.draw_circle(Vector2(270, -60), 430.0, Color(0.17, 0.11, 0.43, 0.55))
	n.draw_circle(Vector2(270, 1000), 360.0, Color(0.10, 0.20, 0.50, 0.30))
