@tool
extends Control
class_name CategoryIcon

enum Kind { PERFORMANCE, SOUND, GAME }

@export var kind: Kind = Kind.PERFORMANCE
@export var line_color := Color(1, 1, 1, 0.92)
@export var line_width := 2.0

func _draw() -> void:
	match kind:
		Kind.PERFORMANCE: _draw_monitor()
		Kind.SOUND: _draw_speaker()
		Kind.GAME: _draw_gamepad()

func _draw_monitor() -> void:
	var w := size.x
	var h := size.y
	draw_rect(Rect2(w * 0.06, h * 0.08, w * 0.88, h * 0.62), line_color, false, line_width)
	draw_line(Vector2(w * 0.5, h * 0.7), Vector2(w * 0.5, h * 0.86), line_color, line_width)
	draw_line(Vector2(w * 0.28, h * 0.94), Vector2(w * 0.72, h * 0.94), line_color, line_width)

func _draw_speaker() -> void:
	var w := size.x
	var h := size.y
	var pts := PackedVector2Array([
		Vector2(w * 0.08, h * 0.36), Vector2(w * 0.34, h * 0.36),
		Vector2(w * 0.58, h * 0.1), Vector2(w * 0.58, h * 0.9),
		Vector2(w * 0.34, h * 0.64), Vector2(w * 0.08, h * 0.64),
		Vector2(w * 0.08, h * 0.36),
	])
	draw_polyline(pts, line_color, line_width, true)
	draw_arc(Vector2(w * 0.66, h * 0.5), w * 0.14, -0.9, 0.9, 10, line_color, line_width)
	draw_arc(Vector2(w * 0.66, h * 0.5), w * 0.26, -0.9, 0.9, 10, line_color, line_width)

func _draw_gamepad() -> void:
	var w := size.x
	var h := size.y
	draw_rect(Rect2(w * 0.05, h * 0.32, w * 0.9, h * 0.42), line_color, false, line_width)
	draw_line(Vector2(w * 0.26, h * 0.42), Vector2(w * 0.26, h * 0.62), line_color, line_width)
	draw_line(Vector2(w * 0.16, h * 0.52), Vector2(w * 0.36, h * 0.52), line_color, line_width)
	draw_circle(Vector2(w * 0.74, h * 0.44), w * 0.045, line_color)
	draw_circle(Vector2(w * 0.84, h * 0.54), w * 0.045, line_color)
