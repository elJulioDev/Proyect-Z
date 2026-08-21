class_name HitboxKeyframe extends Resource
## Keyframe de hitbox para un frame especifico de animacion.
## Controla la forma y posicion de la hitbox frame a frame.

@export var frame: int = 0
@export var offset: Vector2 = Vector2.ZERO
@export var size: Vector2 = Vector2(50, 40)
@export var active: bool = true
