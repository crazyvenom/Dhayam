extends Node2D
## SaTz Tech studio intro ("Assemble"): coloured tiles fly in and lock into a badge,
## the S appears, the name slides up, then the game starts. No skip: it is only a few seconds.

const TILE: float = 50.0
const GAP: float = 6.0
const ORIGIN: Vector2 = Vector2(133.0, 290.0)   # top-left corner of the 5 x 5 badge
const HOLD_SECONDS: float = 3.6                 # when the fade-out to the game begins

var _glyph: Line2D
var _name: RichTextLabel
var _tech: Label


func _ready() -> void:
	if OS.has_environment("DHAYAM_SKIP_INTRO"):
		_go.call_deferred()
		return
	_build()
	# Intro sound: plays if audio/intro.wav exists (the chosen sting is copied there)
	Settings.load_settings()
	if Settings.sfx_on and ResourceLoader.exists("res://audio/intro.wav"):
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.stream = load("res://audio/intro.wav")
		player.volume_db = -3.0
		add_child(player)
		player.play()
	if OS.has_environment("DHAYAM_INTRO_SHOT"):
		var secs: float = float(OS.get_environment("DHAYAM_SECONDS")) if OS.has_environment("DHAYAM_SECONDS") else 2.0
		await get_tree().create_timer(secs).timeout
		get_viewport().get_texture().get_image().save_png(OS.get_environment("DHAYAM_INTRO_SHOT"))
		get_tree().quit()
		return
	await get_tree().create_timer(HOLD_SECONDS).timeout
	var tw: Tween = create_tween()
	tw.tween_property(self, "modulate", Color(0, 0, 0, 1), 0.35)
	await tw.finished
	_go()


func _draw() -> void:
	draw_rect(Rect2(0, 0, 540, 960), Color(0.02, 0.024, 0.05))
	draw_circle(Vector2(270, 430), 280.0, Color(0.30, 0.35, 1.0, 0.06))
	draw_circle(Vector2(270, 430), 190.0, Color(0.45, 0.35, 1.0, 0.05))


func _build() -> void:
	# 25 tiles that fly in from random places and lock into a 5 x 5 badge
	for i in 25:
		var col: int = i % 5
		var row: int = int(i / 5.0)
		var tile: Panel = Panel.new()
		tile.size = Vector2(TILE, TILE)
		tile.pivot_offset = Vector2(TILE, TILE) / 2.0
		var sb: StyleBoxFlat = StyleBoxFlat.new()
		sb.bg_color = Color.from_ok_hsl((220.0 + col * 10.0 + row * 8.0) / 360.0, 0.85, 0.55 + row * 0.03)
		sb.set_corner_radius_all(11)
		tile.add_theme_stylebox_override("panel", sb)
		var target: Vector2 = ORIGIN + Vector2(col, row) * (TILE + GAP)
		tile.position = target + Vector2(randf_range(-300.0, 300.0), randf_range(-480.0, 480.0))
		tile.rotation = deg_to_rad(randf_range(-180.0, 180.0))
		tile.scale = Vector2(0.3, 0.3)
		tile.modulate.a = 0.0
		add_child(tile)
		var d: float = 0.1 + i * 0.035
		var tw: Tween = create_tween().set_parallel(true)
		tw.tween_property(tile, "position", target, 0.9).set_delay(d).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		tw.tween_property(tile, "rotation", 0.0, 0.9).set_delay(d).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		tw.tween_property(tile, "scale", Vector2.ONE, 0.9).set_delay(d).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		tw.tween_property(tile, "modulate:a", 1.0, 0.35).set_delay(d)

	# The white S drawn over the badge
	_glyph = Line2D.new()
	_glyph.points = _s_points()
	_glyph.width = 26.0
	_glyph.default_color = Color.WHITE
	_glyph.joint_mode = Line2D.LINE_JOINT_ROUND
	_glyph.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_glyph.end_cap_mode = Line2D.LINE_CAP_ROUND
	_glyph.antialiased = true
	_glyph.modulate.a = 0.0
	add_child(_glyph)
	create_tween().tween_property(_glyph, "modulate:a", 1.0, 0.5).set_delay(1.7)

	# Name and "TECH"
	_name = RichTextLabel.new()
	_name.bbcode_enabled = true
	_name.scroll_active = false
	_name.text = "[center][color=#5b8cff]S[/color][color=#7a80ff]a[/color][color=#9a74ff]T[/color][color=#b46bff]z[/color][/center]"
	_name.size = Vector2(540, 120)
	_name.position = Vector2(0, 630)
	_name.add_theme_font_size_override("normal_font_size", 96)
	_name.modulate.a = 0.0
	add_child(_name)
	var tn: Tween = create_tween().set_parallel(true)
	tn.tween_property(_name, "modulate:a", 1.0, 0.6).set_delay(2.1)
	tn.tween_property(_name, "position:y", 600.0, 0.6).set_delay(2.1).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	_tech = Label.new()
	_tech.text = "T   E   C   H"
	_tech.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tech.size = Vector2(540, 40)
	_tech.position = Vector2(0, 755)
	_tech.add_theme_font_size_override("font_size", 30)
	_tech.add_theme_color_override("font_color", Color(0.67, 0.71, 1.0))
	_tech.modulate.a = 0.0
	add_child(_tech)
	var tt: Tween = create_tween().set_parallel(true)
	tt.tween_property(_tech, "modulate:a", 1.0, 0.6).set_delay(2.4)
	tt.tween_property(_tech, "position:y", 730.0, 0.6).set_delay(2.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## The S shape, built from three curves, scaled to fit the badge.
func _s_points() -> PackedVector2Array:
	var segs: Array = [
		[Vector2(72, 30), Vector2(60, 18), Vector2(30, 20), Vector2(30, 36)],
		[Vector2(30, 36), Vector2(30, 52), Vector2(70, 48), Vector2(70, 64)],
		[Vector2(70, 64), Vector2(70, 80), Vector2(38, 82), Vector2(26, 70)],
	]
	var pts: PackedVector2Array = PackedVector2Array()
	var g: float = (TILE * 5.0 + GAP * 4.0) / 100.0
	for s in segs:
		for i in 21:
			if pts.size() > 0 and i == 0:
				continue
			var t: float = i / 20.0
			var u: float = 1.0 - t
			var p: Vector2 = s[0] * u * u * u + s[1] * 3.0 * u * u * t + s[2] * 3.0 * u * t * t + s[3] * t * t * t
			pts.append(ORIGIN + p * g)
	return pts


func _go() -> void:
	get_tree().change_scene_to_file("res://main.tscn")
