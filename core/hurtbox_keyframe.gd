class_name HurtboxKeyframe extends Resource
## Keyframe de hurtbox para un frame especifico de animacion.
## Controla la forma y posicion de la hurtbox del personaje durante un ataque.

@export var frame: int = 0
@export var offset: Vector2 = Vector2.ZERO
@export var size: Vector2 = Vector2(30, 45)
