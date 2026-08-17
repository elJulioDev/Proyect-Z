class_name AttackData extends Resource
## Definición de un ataque del moveset de un personaje.

@export var id: String = ""
@export var damage: float = 1.0
@export var knockback: Vector2 = Vector2.ZERO
@export var stun: float = 0.0
@export var active_time: float = 0.1
@export var lockout: float = 0.2
@export var anim: String = ""
@export var hitbox_scale: Vector2 = Vector2.ONE
