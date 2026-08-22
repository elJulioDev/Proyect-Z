@tool
extends Node2D
## Overlay de dibujo para la herramienta de personajes.
## Dibuja hitbox, hurtbox, floor, dust y crosshair.

var tool_ref: Node = null


func _draw() -> void:
	if tool_ref:
		tool_ref._render_overlay(self)
