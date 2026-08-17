class_name CombatSystem extends Node
## Combate data-driven: lee los ataques y cadenas del CharacterData.
## Lee el input de ataque, decide el ataque (suelo/aire, remates de combo)
## y aplica daño/knockback cuando la hitbox toca una hurtbox.

const COMBO_WINDOW := 0.55
const BUFFER_TIME := 0.3

var character: BaseCharacter
@onready var hitbox: Area2D = get_parent().get_node("Hitbox")

var is_attacking := false
var attack_timer := 0.0
var lockout_timer := 0.0
var combo_timer := 0.0
var combo_sequence: Array = []
var current_attack: AttackData
var buffered_attack := ""
var buffer_timer := 0.0


func _ready() -> void:
	character = get_parent()
	hitbox.monitoring = false
	hitbox.area_entered.connect(_on_hitbox_area_entered)


func _physics_process(delta: float) -> void:
	_tick(delta)
	_read_input()


func _tick(delta: float) -> void:
	if attack_timer > 0.0:
		attack_timer -= delta
		if attack_timer <= 0.0:
			hitbox.monitoring = false
			is_attacking = false
	if lockout_timer > 0.0:
		lockout_timer -= delta
	if combo_timer > 0.0:
		combo_timer -= delta
		if combo_timer <= 0.0:
			combo_sequence.clear()
	if buffer_timer > 0.0:
		buffer_timer -= delta
		if buffer_timer <= 0.0:
			buffered_attack = ""


func _read_input() -> void:
	var c := character
	var airborne := c.is_airborne()
	var pressed := ""
	if c.controller.attack_punch_pressed:
		pressed = _pick("punch", "air_punch", airborne)
	elif c.controller.attack_kick_pressed:
		pressed = _pick("kick", "air_kick", airborne)
	elif c.controller.attack_ki_pressed:
		pressed = _pick("ki", "air_ki", airborne)
	if pressed != "":
		if lockout_timer > 0.0 or not c.can_act():
			buffered_attack = pressed
			buffer_timer = BUFFER_TIME
			return
		_do_attack(pressed)
	elif buffered_attack != "" and lockout_timer <= 0.0 and c.can_act():
		var id := buffered_attack
		buffered_attack = ""
		_do_attack(id)


func _pick(ground_id: String, air_id: String, airborne: bool) -> String:
	var data := character.data
	if airborne and air_id in data.attacks:
		return air_id
	return ground_id if ground_id in data.attacks else air_id


func _do_attack(attack_id: String) -> void:
	var c := character
	if not c.is_airborne():
		combo_sequence.append(attack_id)
		combo_timer = COMBO_WINDOW
		var finisher := _check_combo_chain()
		if finisher != "":
			combo_sequence.clear()
			attack_id = finisher
	if not c.data.attacks.has(attack_id):
		return
	lockout_timer = c.data.attacks[attack_id].lockout
	c.state_machine.change("attack", {"id": attack_id})


func _check_combo_chain() -> String:
	var best := ""
	var best_len := 0
	for chain in character.data.combos:
		var sequence: Array = chain.get("sequence", [])
		if sequence.size() <= best_len or combo_sequence.size() < sequence.size():
			continue
		if combo_sequence.slice(-sequence.size()) == sequence:
			best = chain.get("finisher", "")
			best_len = sequence.size()
	return best


## Llamado por AttackState al entrar: activa hitbox y animación.
func start_attack(attack_id: String) -> void:
	var data: AttackData = character.data.attacks.get(attack_id, null)
	if data == null:
		return
	current_attack = data
	is_attacking = true
	attack_timer = data.active_time
	hitbox.scale = data.hitbox_scale
	hitbox.monitoring = true
	character.animator.play_anim(data.anim)


func _on_hitbox_area_entered(area: Area2D) -> void:
	if area.name != "Hurtbox":
		return
	var target: Node = area.get_parent()
	if target == character or not target.has_method("receive_hit"):
		return
	if current_attack == null:
		return
	var kb_dir := 1.0 if character.facing_right else -1.0
	var knockback := Vector2(current_attack.knockback.x * kb_dir, current_attack.knockback.y)
	target.receive_hit(current_attack.damage, knockback, current_attack.stun)
	hitbox.set_deferred("monitoring", false)
