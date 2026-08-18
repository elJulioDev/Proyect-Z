class_name CombatSystem extends Node
## Combate data-driven con frame data, cancelaciones por peso y cadenas de combo.
## Startup → Active → Recovery. Cancelaciones: peso nuevo >= peso actual.
## Combos: al presionar el mismo botón durante cancel, avanza en la cadena.

var character: BaseCharacter
@onready var hitbox: Area2D = get_parent().get_node("Hitbox")

var is_attacking := false
var current_attack: AttackData
var lockout_timer := 0.0
var _current_weight: int = -1
var _combo_chain: Array = []


func _ready() -> void:
	character = get_parent()
	hitbox.monitoring = false
	hitbox.area_entered.connect(_on_hitbox_area_entered)


func _physics_process(delta: float) -> void:
	if lockout_timer > 0.0:
		lockout_timer -= delta
	_read_input()


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
	if pressed == "":
		return
	if _can_cancel_with(pressed):
		var current_id := current_attack.id if current_attack != null else ""
		var next_id := _get_combo_next(current_id)
		if next_id != "":
			_do_attack(next_id)
		else:
			_combo_chain = _find_combo_chain(pressed)
			if _combo_chain.size() > 0:
				_do_attack(_combo_chain[0])
			else:
				_do_attack(pressed)
	elif c.can_act():
		_combo_chain = _find_combo_chain(pressed)
		if _combo_chain.size() > 0:
			_do_attack(_combo_chain[0])
		else:
			_do_attack(pressed)


func _can_cancel_with(new_attack_id: String) -> bool:
	var c := character
	if c.state_id() != "attack":
		return false
	var atk_state: AttackState = c.state_machine.current
	if atk_state == null or not atk_state is AttackState:
		return false
	if not atk_state.can_cancel():
		return false
	var new_data: AttackData = c.data.attacks.get(new_attack_id, null)
	if new_data == null:
		return false
	return new_data.weight >= _current_weight


func _pick(ground_id: String, air_id: String, airborne: bool) -> String:
	var data := character.data
	if airborne and air_id in data.attacks:
		return air_id
	return ground_id if ground_id in data.attacks else air_id


func _find_combo_chain(attack_id: String) -> Array:
	for combo in character.data.combos:
		var seq: Array = combo.get("sequence", [])
		if seq.is_empty() or seq[0] != attack_id:
			continue
		var chain: Array = seq.duplicate()
		if combo.has("finisher") and chain.size() > 0:
			chain[chain.size() - 1] = combo.finisher
		return chain
	return []


func _get_combo_next(current_id: String) -> String:
	if _combo_chain.is_empty():
		return ""
	var idx := _combo_chain.find(current_id)
	if idx < 0 or idx >= _combo_chain.size() - 1:
		return ""
	return _combo_chain[idx + 1]


func _do_attack(attack_id: String) -> void:
	var c := character
	if not c.data.attacks.has(attack_id):
		return
	var data: AttackData = c.data.attacks[attack_id]
	lockout_timer = data.lockout
	_current_weight = data.weight
	current_attack = data
	c.state_machine.change("attack", {"id": attack_id})


func get_current_weight() -> int:
	return _current_weight


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
	var is_blocking: bool = target.state_id() == "block"
	target.receive_hit(current_attack.damage, knockback, current_attack.stun, current_attack.block_damage, current_attack.blockstun, is_blocking)
	hitbox.set_deferred("monitoring", false)
