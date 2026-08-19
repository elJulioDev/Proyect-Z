@tool
extends Control
class_name SlantBar

@export var slant: float = 30.0
@export var flip: bool = false
@export var invert_slant := false
@export var bg_color := Color(0.05, 0.2, 0.22)
@export var chip_color := Color(0.65, 0.85, 1.0, 0.7)
@export var fill_color := Color(1.0, 0.5, 0.1)
@export var border_color := Color.BLACK
@export var shadow_offset := Vector2(3, 3)

@export_range(20.0, 2000.0) var bar_width: float = 0.0:
	set(v):
		bar_width = v
		if bar_width > 0.0:
			if flip:
				offset_left = offset_right - bar_width
			else:
				offset_right = offset_left + bar_width

@export_range(4.0, 200.0) var bar_height: float = 0.0:
	set(v):
		bar_height = v
		if bar_height > 0.0:
			offset_bottom = offset_top + bar_height

@export_range(0.0, 1.0) var value: float = 1.0:
	set(v):
		value = clamp(v, 0.0, 1.0)
		queue_redraw()

@export_range(0.0, 1.0) var chip: float = 1.0:
	set(v):
		chip = clamp(v, 0.0, 1.0)
		queue_redraw()

func _ready() -> void:
	if bar_width <= 0.0:
		bar_width = size.x
	if bar_height <= 0.0:
		bar_height = size.y

func _draw() -> void:
	_poly(size.x, Color(0, 0, 0, 0.35), shadow_offset)
	_poly(size.x, bg_color, Vector2.ZERO)
	_poly(size.x * chip, chip_color, Vector2.ZERO)
	_poly(size.x * value, fill_color, Vector2.ZERO)
	var border = _points(size.x, Vector2.ZERO)
	border.append(border[0])
	draw_polyline(border, border_color, 3.0, true)

func _points(w: float, off: Vector2) -> PackedVector2Array:
	var h = size.y
	var s = min(slant, w)
	var right = size.x
	if flip:
		if invert_slant:
			return PackedVector2Array([
				Vector2(right, 0) + off, Vector2(right - w + s, 0) + off,
				Vector2(right - w, h) + off, Vector2(right - s, h) + off
			])
		return PackedVector2Array([
			Vector2(right - w, 0) + off, Vector2(right - s, 0) + off,
			Vector2(right, h) + off, Vector2(right - w + s, h) + off
		])
	if invert_slant:
		return PackedVector2Array([
			Vector2(0, 0) + off, Vector2(w - s, 0) + off,
			Vector2(w, h) + off, Vector2(s, h) + off
		])
	return PackedVector2Array([
		Vector2(s, 0) + off, Vector2(w, 0) + off,
		Vector2(w - s, h) + off, Vector2(0, h) + off
	])

func _poly(w: float, col: Color, off: Vector2) -> void:
	draw_colored_polygon(_points(w, off), col)
