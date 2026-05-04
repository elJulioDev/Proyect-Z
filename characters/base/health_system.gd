extends Node
class_name HealthSystem
## Sistema de vida, daño, hitstun y knockback.
## Adjunta este nodo como hijo de BaseCharacter.

# ─────────────────────────────────────────────────────────────────────────────
#  SEÑALES
# ─────────────────────────────────────────────────────────────────────────────
signal health_changed(current: float, max_hp: float)
signal character_died()
signal hit_received(damage: float)

# ─────────────────────────────────────────────────────────────────────────────
#  REFERENCIAS
# ─────────────────────────────────────────────────────────────────────────────
@onready var character: BaseCharacter = get_parent()
@onready var sprite:    Sprite2D      = character.get_node("Sprite2D")

# ─────────────────────────────────────────────────────────────────────────────
#  ESTADO
# ─────────────────────────────────────────────────────────────────────────────
var max_hp:       float = 100.0
var current_hp:   float = 100.0
var is_in_hitstun: bool = false
var hitstun_timer: float = 0.0
var is_dead:       bool = false

# Flash de daño
var _flash_timer:  float = 0.0
const FLASH_DURATION: float = 0.08
const FLASH_REPS:     int   = 3


func _ready() -> void:
	# Lee la vida base del JSON del personaje
	var stats = character.stats
	if stats.has("base_statistics"):
		max_hp     = stats["base_statistics"].get("life", 100.0)
		current_hp = max_hp
	health_changed.emit(current_hp, max_hp)


func _physics_process(delta: float) -> void:
	_tick_hitstun(delta)
	_tick_flash(delta)


# ─────────────────────────────────────────────────────────────────────────────
#  API PÚBLICA — llamada por CombatSystem del atacante
# ─────────────────────────────────────────────────────────────────────────────
func receive_hit(damage: float, knockback: Vector2, stun_duration: float) -> void:
	if is_dead: return

	# Defensa: reduce el daño recibido
	var defense = character.stats.get("base_statistics", {}).get("defense", 0.0)
	var actual_damage = max(1.0, damage - defense * 0.15)

	current_hp = max(0.0, current_hp - actual_damage)
	health_changed.emit(current_hp, max_hp)
	hit_received.emit(actual_damage)

	# Knockback
	character.velocity = knockback

	# Hitstun — bloquea el input del receptor
	is_in_hitstun  = true
	hitstun_timer  = stun_duration
	character.current_state = "hit"

	_start_flash()

	if current_hp <= 0.0:
		_die()


# ─────────────────────────────────────────────────────────────────────────────
#  HITSTUN
# ─────────────────────────────────────────────────────────────────────────────
func _tick_hitstun(delta: float) -> void:
	if not is_in_hitstun: return
	hitstun_timer -= delta
	if hitstun_timer <= 0.0:
		is_in_hitstun = false
		# Deja que BaseCharacter retome el control
		if not character.is_airborne():
			character.current_state = "idle"


# ─────────────────────────────────────────────────────────────────────────────
#  FLASH VISUAL DE DAÑO
# ─────────────────────────────────────────────────────────────────────────────
func _start_flash() -> void:
	_flash_timer = FLASH_DURATION * FLASH_REPS * 2.0


func _tick_flash(delta: float) -> void:
	if _flash_timer <= 0.0: return
	_flash_timer -= delta
	var beat = fmod(_flash_timer, FLASH_DURATION * 2.0)
	sprite.modulate = Color(1, 0.3, 0.3, 1) if beat > FLASH_DURATION else Color(1, 1, 1, 1)
	if _flash_timer <= 0.0:
		sprite.modulate = Color(1, 1, 1, 1)


# ─────────────────────────────────────────────────────────────────────────────
#  MUERTE
# ─────────────────────────────────────────────────────────────────────────────
func _die() -> void:
	is_dead = true
	character.current_state = "dead"
	character.set_physics_process(false)
	character_died.emit()

	# Animación de caída simple con Tween
	var tw = character.create_tween()
	tw.tween_property(sprite, "modulate:a", 0.0, 0.6).set_delay(0.3)


# ─────────────────────────────────────────────────────────────────────────────
#  HELPERS
# ─────────────────────────────────────────────────────────────────────────────
func heal(amount: float) -> void:
	current_hp = min(max_hp, current_hp + amount)
	health_changed.emit(current_hp, max_hp)

func is_blocking_input() -> bool:
	return is_in_hitstun or is_dead