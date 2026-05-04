extends Node
class_name CombatSystem
## Sistema de combate simple estilo Z Legends / Warriors of the Universe
## Adjunta este nodo como hijo de BaseCharacter.

# ─────────────────────────────────────────────────────────────────────────────
#  REFERENCIAS
# ─────────────────────────────────────────────────────────────────────────────
@onready var character: BaseCharacter = get_parent()
@onready var hitbox: Area2D           = character.get_node("Hitbox")
@onready var anim:   AnimationPlayer  = character.get_node("AnimationPlayer")

# ─────────────────────────────────────────────────────────────────────────────
#  CONSTANTES DE TIMING (en segundos)
# ─────────────────────────────────────────────────────────────────────────────
const COMBO_WINDOW:   float = 0.55   # tiempo máximo entre golpes para continuar combo
const ATTACK_LOCKOUT: float = 0.22   # tiempo mínimo entre ataques (evita spam)
const HIT_STUN:       float = 0.18   # duración del hitstun del receptor

# ─────────────────────────────────────────────────────────────────────────────
#  DEFINICIÓN DE ATAQUES
#  Cada ataque tiene: daño base, knockback, duración de hitbox activa, animación
# ─────────────────────────────────────────────────────────────────────────────
const ATTACKS: Dictionary = {
	"light": {
		"damage": 4.0,  "knockback": Vector2(220, -60),
		"active": 0.10, "anim": "attack_light", "stun": 0.14
	},
	"mid": {
		"damage": 8.0,  "knockback": Vector2(300, -100),
		"active": 0.14, "anim": "attack_mid",   "stun": 0.20
	},
	"heavy": {
		"damage": 14.0, "knockback": Vector2(420, -180),
		"active": 0.18, "anim": "attack_heavy", "stun": 0.30
	},
	# Ataques aéreos (mismos inputs en el aire)
	"air_light": {
		"damage": 5.0,  "knockback": Vector2(180, -140),
		"active": 0.10, "anim": "attack_air_light", "stun": 0.14
	},
	"air_mid": {
		"damage": 9.0,  "knockback": Vector2(260, -200),
		"active": 0.14, "anim": "attack_air_mid",   "stun": 0.22
	},
	"air_heavy": {
		"damage": 16.0, "knockback": Vector2(340, -260),
		"active": 0.18, "anim": "attack_air_heavy", "stun": 0.32
	},
}

# ─────────────────────────────────────────────────────────────────────────────
#  CADENAS DE COMBOS (secuencias de ataques que forman un combo especial)
#  Formato: [lista de ataques en orden] → nombre del remate
# ─────────────────────────────────────────────────────────────────────────────
const COMBO_CHAINS: Array = [
	{ "sequence": ["light", "light", "mid"],   "finisher": "combo_lll_finish" },
	{ "sequence": ["light", "mid", "heavy"],   "finisher": "combo_lmh_finish" },
	{ "sequence": ["mid",   "mid",   "heavy"], "finisher": "combo_mmh_finish" },
	{ "sequence": ["light", "light", "light", "heavy"], "finisher": "combo_lllh_finish" },
]

# ─────────────────────────────────────────────────────────────────────────────
#  ESTADO INTERNO
# ─────────────────────────────────────────────────────────────────────────────
var is_attacking:   bool  = false
var attack_timer:   float = 0.0   # hitbox activa
var lockout_timer:  float = 0.0   # pausa entre ataques
var combo_timer:    float = 0.0   # ventana para continuar combo
var combo_sequence: Array = []     # historial del combo actual
var current_attack: String = ""


# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	hitbox.monitoring = false
	hitbox.area_entered.connect(_on_hitbox_area_entered)


func _physics_process(delta: float) -> void:
	_tick(delta)
	_read_input()


# ─────────────────────────────────────────────────────────────────────────────
#  TEMPORIZADORES
# ─────────────────────────────────────────────────────────────────────────────
func _tick(delta: float) -> void:
	if attack_timer > 0.0:
		attack_timer -= delta
		if attack_timer <= 0.0:
			hitbox.monitoring = false   # desactiva hitbox al terminar el activo
			is_attacking      = false

	if lockout_timer  > 0.0: lockout_timer  -= delta
	if combo_timer    > 0.0:
		combo_timer -= delta
		if combo_timer <= 0.0:
			combo_sequence.clear()      # se acabó la ventana, resetea combo


# ─────────────────────────────────────────────────────────────────────────────
#  LECTURA DE INPUT
# ─────────────────────────────────────────────────────────────────────────────
func _read_input() -> void:
	if lockout_timer > 0.0: return
	if not character.can_act(): return

	var airborne = character.is_airborne()

	if Input.is_action_just_pressed("attack_light"):
		_do_attack("air_light" if airborne else "light")
	elif Input.is_action_just_pressed("attack_mid"):
		_do_attack("air_mid"   if airborne else "mid")
	elif Input.is_action_just_pressed("attack_heavy"):
		_do_attack("air_heavy" if airborne else "heavy")


# ─────────────────────────────────────────────────────────────────────────────
#  EJECUTAR ATAQUE
# ─────────────────────────────────────────────────────────────────────────────
func _do_attack(attack_name: String) -> void:
	var data = ATTACKS.get(attack_name)
	if data == null: return

	# Registrar en la secuencia de combo (solo ataques de piso para cadenas)
	var base_name = attack_name.replace("air_", "")
	if not character.is_airborne():
		combo_sequence.append(base_name)
		combo_timer = COMBO_WINDOW
		_check_combo_chain()

	current_attack    = attack_name
	is_attacking      = true
	attack_timer      = data["active"]
	lockout_timer     = ATTACK_LOCKOUT
	hitbox.monitoring = true

	# Reproducir animación (si existe en el AnimationPlayer)
	var anim_name: String = data["anim"]
	if anim.has_animation(anim_name):
		anim.stop()
		anim.play(anim_name)


# ─────────────────────────────────────────────────────────────────────────────
#  DETECCIÓN DE CADENAS DE COMBO
# ─────────────────────────────────────────────────────────────────────────────
func _check_combo_chain() -> void:
	for chain in COMBO_CHAINS:
		if combo_sequence.size() < chain["sequence"].size(): continue
		# Compara el final de la secuencia con la cadena definida
		var tail = combo_sequence.slice(-chain["sequence"].size())
		if tail == chain["sequence"]:
			_trigger_finisher(chain["finisher"])
			combo_sequence.clear()
			return


func _trigger_finisher(finisher_name: String) -> void:
	# Llama a la animación de remate si existe; la hitbox se amplía brevemente
	if anim.has_animation(finisher_name):
		anim.stop()
		anim.play(finisher_name)
	# Emite señal para que efectos visuales/audio puedan reaccionar
	emit_signal("combo_finisher", finisher_name)


# ─────────────────────────────────────────────────────────────────────────────
#  COLISIÓN — GOLPEAR AL ENEMIGO
# ─────────────────────────────────────────────────────────────────────────────
func _on_hitbox_area_entered(area: Area2D) -> void:
	if area.name != "Hurtbox": return
	var target = area.get_parent()
	if target == character: return
	if not target.has_method("receive_hit"): return

	var data = ATTACKS.get(current_attack, {})
	if data.is_empty(): return

	# Dirección del knockback según el facing del atacante
	var kb_dir = 1.0 if character.facing_right else -1.0
	var knockback = Vector2(data["knockback"].x * kb_dir, data["knockback"].y)

	target.receive_hit(data["damage"], knockback, data["stun"])
	hitbox.monitoring = false   # un solo golpe por swing


# ─────────────────────────────────────────────────────────────────────────────
#  SEÑALES
# ─────────────────────────────────────────────────────────────────────────────
signal combo_finisher(finisher_name: String)