extends CharacterBody2D
class_name BaseCharacter

# ─────────────────────────────────────────────────────────────────────────────
#  DATOS DEL PERSONAJE
# ─────────────────────────────────────────────────────────────────────────────
var stats: Dictionary = {}
var facing_right: bool = true

@export var char_json_path: String = ""

@onready var sprite        = $Sprite2D
@onready var anim_player   = $AnimationPlayer
@onready var shadow_sprite = $Shadow
@onready var floor_ray     = $FloorRay
@onready var state_machine = $StateMachine

# ─────────────────────────────────────────────────────────────────────────────
#  FÍSICA
# ─────────────────────────────────────────────────────────────────────────────
var gravity:       float = 1200.0
var jump_velocity: float = -620.0

# ─────────────────────────────────────────────────────────────────────────────
#  ESTADO CENTRAL
# ─────────────────────────────────────────────────────────────────────────────
var current_state: String = "idle"

# ─────────────────────────────────────────────────────────────────────────────
#  SISTEMA DE SALTO
# ─────────────────────────────────────────────────────────────────────────────
const MAX_JUMPS:        int   = 2
const DOUBLE_JUMP_MULT: float = 0.85   # 85 % de potencia en el 2º salto
var   jumps_left:       int   = MAX_JUMPS
var   is_jumping:       bool  = false

# ─────────────────────────────────────────────────────────────────────────────
#  SISTEMA DE DASH
# ─────────────────────────────────────────────────────────────────────────────
const DASH_SPEED:         float = 900.0
const DASH_DURATION:      float = 0.18
const DASH_COOLDOWN:      float = 0.40
const AIR_DASH_LIMIT:     int   = 1

var dash_timer:       float = 0.0
var dash_cd_timer:    float = 0.0
var air_dashes_left:  int   = AIR_DASH_LIMIT
var is_dashing:       bool  = false
var dash_direction:   float = 0.0

# ─────────────────────────────────────────────────────────────────────────────
#  SISTEMA DE TELETRANSPORTE (SLOT 3)
# ─────────────────────────────────────────────────────────────────────────────
const TELEPORT_DISTANCE:  float = 280.0
const TELEPORT_COOLDOWN:  float = 0.80

var teleport_cd_timer: float = 0.0
var _teleport_flash:   float = 0.0  # para efecto visual

# ─────────────────────────────────────────────────────────────────────────────
#  GUARDIA
# ─────────────────────────────────────────────────────────────────────────────
var is_blocking: bool  = false

# ─────────────────────────────────────────────────────────────────────────────
#  SOMBRA
# ─────────────────────────────────────────────────────────────────────────────
var base_shadow_scale: Vector2 = Vector2(2.8, 1.5)
var shadow_offset_y:   float   = 25.0
var max_jump_height:   float   = 400.0


# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	shadow_sprite.top_level = true
	load_character_data()
	if not stats.has("base_statistics"):
		stats["base_statistics"] = {"speed": 250}


# ─────────────────────────────────────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	_tick_timers(delta)

	# Dash activo: omite gravedad y control normal
	if is_dashing:
		_process_dash(delta)
		move_and_slide()
		update_shadow()
		return

	_apply_gravity(delta)
	_handle_jump()
	_handle_dash()
	_handle_teleport()
	_handle_block()
	_handle_movement()
	_update_state()
	update_facing_direction()
	move_and_slide()
	update_shadow()

	# Aterrizaje: restaurar recursos aéreos
	if is_on_floor():
		jumps_left    = MAX_JUMPS
		air_dashes_left = AIR_DASH_LIMIT
		if is_jumping:
			is_jumping = false


# ─────────────────────────────────────────────────────────────────────────────
#  TEMPORIZADORES
# ─────────────────────────────────────────────────────────────────────────────
func _tick_timers(delta: float) -> void:
	if dash_cd_timer   > 0.0: dash_cd_timer   -= delta
	if teleport_cd_timer > 0.0: teleport_cd_timer -= delta
	if _teleport_flash   > 0.0:
		_teleport_flash -= delta
		var t = clamp(_teleport_flash / 0.15, 0.0, 1.0)
		sprite.modulate = Color(1.0 + t, 1.0 + t, 1.0 + t, 1.0)


# ─────────────────────────────────────────────────────────────────────────────
#  GRAVEDAD
# ─────────────────────────────────────────────────────────────────────────────
func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta


# ─────────────────────────────────────────────────────────────────────────────
#  SALTO / DOBLE SALTO
# ─────────────────────────────────────────────────────────────────────────────
func _handle_jump() -> void:
	if not Input.is_action_just_pressed("jump"): return
	if jumps_left <= 0: return

	var multiplier = 1.0 if jumps_left == MAX_JUMPS else DOUBLE_JUMP_MULT
	velocity.y = jump_velocity * multiplier
	jumps_left -= 1
	is_jumping = true
	current_state = "jump"

	# Efecto visual: pequeño "squash" en el doble salto
	if jumps_left == 0:
		_trigger_double_jump_vfx()


# ─────────────────────────────────────────────────────────────────────────────
#  DASH
# ─────────────────────────────────────────────────────────────────────────────
func _handle_dash() -> void:
	if not Input.is_action_just_pressed("dash"): return
	if dash_cd_timer > 0.0: return
	if not is_on_floor() and air_dashes_left <= 0: return

	dash_direction = 1.0 if facing_right else -1.0
	# Si hay input direccional, prioriza esa dirección
	var h = Input.get_axis("move_left", "move_right")
	if h != 0.0: dash_direction = sign(h)

	is_dashing      = true
	dash_timer      = DASH_DURATION
	dash_cd_timer   = DASH_COOLDOWN
	velocity.y      = 0.0   # cancela caída durante el dash
	current_state   = "dash"

	if not is_on_floor():
		air_dashes_left -= 1


func _process_dash(delta: float) -> void:
	dash_timer -= delta
	if dash_timer <= 0.0:
		is_dashing = false
		velocity.x = 0.0
		return

	velocity.x = DASH_SPEED * dash_direction
	velocity.y = 0.0  # mantiene altura durante el dash aéreo


# ─────────────────────────────────────────────────────────────────────────────
#  TELETRANSPORTE
# ─────────────────────────────────────────────────────────────────────────────
func _handle_teleport() -> void:
	if not Input.is_action_just_pressed("special_3"): return
	if teleport_cd_timer > 0.0: return

	var dir = Input.get_axis("move_left", "move_right")
	if dir == 0.0: dir = 1.0 if facing_right else -1.0

	var destination = global_position + Vector2(TELEPORT_DISTANCE * dir, 0.0)
	global_position   = destination
	teleport_cd_timer = TELEPORT_COOLDOWN
	_teleport_flash   = 0.15
	velocity.x        = 0.0
	current_state     = "teleport"


# ─────────────────────────────────────────────────────────────────────────────
#  GUARDIA
# ─────────────────────────────────────────────────────────────────────────────
func _handle_block() -> void:
	is_blocking = Input.is_action_pressed("block") and is_on_floor()
	if is_blocking:
		current_state = "block"
		velocity.x = move_toward(velocity.x, 0, stats["base_statistics"].get("speed", 250))


# ─────────────────────────────────────────────────────────────────────────────
#  MOVIMIENTO HORIZONTAL
# ─────────────────────────────────────────────────────────────────────────────
func _handle_movement() -> void:
	if is_blocking: return

	var direction = Input.get_axis("move_left", "move_right")
	var speed     = stats["base_statistics"].get("speed", 250)

	if direction != 0.0:
		velocity.x = direction * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)


# ─────────────────────────────────────────────────────────────────────────────
#  ACTUALIZAR ESTADO (PARA ANIMACIONES)
# ─────────────────────────────────────────────────────────────────────────────
func _update_state() -> void:
	if is_dashing:
		current_state = "dash"
		return

	if not is_on_floor():
		current_state = "jump"
		return

	if is_blocking:
		current_state = "block"
		return

	var h = Input.get_axis("move_left", "move_right")
	current_state = "move" if h != 0.0 else "idle"


# ─────────────────────────────────────────────────────────────────────────────
#  DIRECCIÓN DEL SPRITE
# ─────────────────────────────────────────────────────────────────────────────
func update_facing_direction() -> void:
	if velocity.x > 0:
		facing_right = true
	elif velocity.x < 0:
		facing_right = false
	sprite.flip_h = not facing_right


# ─────────────────────────────────────────────────────────────────────────────
#  SOMBRA DINÁMICA
# ─────────────────────────────────────────────────────────────────────────────
func update_shadow() -> void:
	if not floor_ray.is_colliding():
		shadow_sprite.visible = false
		return

	shadow_sprite.visible = true
	var floor_pos = floor_ray.get_collision_point()
	shadow_sprite.global_position = Vector2(global_position.x, floor_pos.y + shadow_offset_y)

	var distance = abs(global_position.y - floor_pos.y)
	var ratio    = clamp(distance / max_jump_height, 0.0, 1.0)
	var scale_x  = lerp(1.0, 1.3, ratio)
	var scale_y  = lerp(1.0, 0.8, ratio)
	shadow_sprite.scale    = base_shadow_scale * Vector2(scale_x, scale_y)
	shadow_sprite.modulate.a = lerp(0.6, 0.15, ratio)


# ─────────────────────────────────────────────────────────────────────────────
#  VFX TEMPORALES
# ─────────────────────────────────────────────────────────────────────────────
func _trigger_double_jump_vfx() -> void:
	# Squash & stretch rápido en el sprite para el doble salto
	var tween = create_tween()
	tween.tween_property(sprite, "scale", Vector2(1.3, 0.7), 0.06)
	tween.tween_property(sprite, "scale", Vector2(0.85, 1.2), 0.08)
	tween.tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.10)


# ─────────────────────────────────────────────────────────────────────────────
#  CARGA DE DATOS
# ─────────────────────────────────────────────────────────────────────────────
func load_character_data() -> void:
	if char_json_path == "": return
	var file = FileAccess.open(char_json_path, FileAccess.READ)
	if file:
		var json  = JSON.new()
		var error = json.parse(file.get_as_text())
		if error == OK:
			stats = json.data


# ─────────────────────────────────────────────────────────────────────────────
#  API PÚBLICA (usada por estados de ataque / mecánicas globales)
# ─────────────────────────────────────────────────────────────────────────────
func is_airborne() -> bool:
	return not is_on_floor()

func can_act() -> bool:
	return not is_dashing and current_state != "teleport"

func get_speed() -> float:
	return stats["base_statistics"].get("speed", 250)