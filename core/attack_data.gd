class_name AttackData extends Resource
## Definición de un ataque del moveset de un personaje.
## Frame data basado en FPS de la animación.

@export var id: String = ""
@export var damage: float = 1.0
@export var knockback: Vector2 = Vector2.ZERO
@export var stun: float = 0.0
@export var lockout: float = 0.2
@export var anim: String = ""
@export var hitbox_scale: Vector2 = Vector2.ONE
@export var hitbox_offset: Vector2 = Vector2.ZERO
@export var weight: int = 0
@export var startup_frames: int = 0
@export var active_frames: int = 4
@export var recovery_frames: int = 0
@export var block_damage: float = 0.0
@export var blockstun: float = 0.0
