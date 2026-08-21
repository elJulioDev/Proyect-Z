extends Node2D

const COLOR_HURTBOX := Color(0.0, 1.0, 0.0, 0.4)
const COLOR_HITBOX := Color(1.0, 0.0, 0.0, 0.4)


func _draw() -> void:
	var p := get_parent() as Node
	if p == null:
		return
	var hurtbox := p.get_node_or_null("Hurtbox") as Area2D
	var hitbox_node: Area2D = null
	var combat := p.get_node_or_null("CombatSystem")
	if combat:
		hitbox_node = combat.get("hitbox")
	_draw_box(hurtbox, COLOR_HURTBOX)
	_draw_box(hitbox_node, COLOR_HITBOX)


func _draw_box(area: Area2D, color: Color) -> void:
	if area == null:
		return
	var col: CollisionShape2D = area.get_node_or_null("CollisionShape2D")
	if col == null or col.shape == null:
		return
	var rect: RectangleShape2D = col.shape as RectangleShape2D
	if rect == null:
		return
	var size: Vector2 = rect.size
	var pos: Vector2 = area.position + col.position
	draw_rect(Rect2(pos - size * 0.5, size), color, true)
