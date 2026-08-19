@tool
extends Control
class_name RoundDots

@export var total_rounds: int = 2
@export var rounds_won: int = 0
@export var slot_size: float = 20.0
@export var spacing: float = 6.0
@export var filled_color := Color(0.08, 0.08, 0.08)
@export var empty_color := Color(0.4, 0.4, 0.4, 0.6)
@export var flip: bool = false
@export var slot_textures: Array[Texture2D] = []

func _draw() -> void:
	var radius := slot_size * 0.5
	for i in total_rounds:
		var x = radius + i * (slot_size + spacing)
		if flip:
			x = size.x - x
		var pos = Vector2(x, radius)
		draw_circle(pos + Vector2(2, 2), radius, Color(0, 0, 0, 0.5))
		draw_circle(pos, radius, filled_color if i < rounds_won else empty_color)
		if i < slot_textures.size() and slot_textures[i]:
			var tex: Texture2D = slot_textures[i]
			draw_texture_rect(tex, Rect2(pos - Vector2(radius, radius), Vector2(slot_size, slot_size)), false)