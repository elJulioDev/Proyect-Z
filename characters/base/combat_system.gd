class_name CombatSystem extends Node
## Combate data-driven con frame data, cancelaciones por peso y cadenas de combo.
## Startup → Active → Recovery. Cancelaciones: peso nuevo >= peso actual.
## Combos: al presionar el mismo boton durante cancel, avanza en la cadena.
## Buffer: input durante startup se conserva y se dispara al abrir ventana de cancel.
## Combinaciones: ventana corta para detectar J+K, J+P, etc.

var character: BaseCharacter
@onready var hitbox: Area2D = get_parent().get_node("Hitbox")

var is_attacking := false
var current_attack: AttackData
var lockout_timer := 0.0
var _current_weight: int = -1
var _combo_chain: Array = []
var _buffered_id := ""
var _buffer_timer := 0.0

const INPUT_BUFFER := 0.12
const COMBO_WINDOW := 0.05

var _pending_button := ""
var _pending_timer := 0.0


func _ready() -> void:
	character = get_parent()
	hitbox.monitoring = false
	hitbox.area_entered.connect(_on_hitbox_area_entered)


func _physics_process(delta: float) -> void:
	if lockout_timer > 0.0:
		lockout_timer -= delta
	if _buffer_timer > 0.0:
		_buffer_timer -= delta
	elif _buffered_id != "":
		_buffered_id = ""
	_read_input()
	if _buffered_id != "" and _try_attack(_buffered_id):
		_buffered_id = ""
		_buffer_timer = 0.0


func _read_input() -> void:
	var c := character
	var context := _get_context()
	var data := c.data
	var map: Dictionary = data.attack_map

	# Recopilar botones pulsados este frame
	var just_pressed: Array = []
	if c.controller.light_pressed and map.has("light"):
		just_pressed.append("light")
	if c.controller.medium_pressed and map.has("medium"):
		just_pressed.append("medium")
	if c.controller.heavy_pressed and map.has("heavy"):
		just_pressed.append("heavy")
	if c.controller.ki_pressed and map.has("ki"):
		just_pressed.append("ki")

	# Si hay 2+ botones este frame, buscar combinacion directamente
	if just_pressed.size() >= 2:
		var combo_id := _find_combination(just_pressed)
		if combo_id != "":
			_try_or_buffer(combo_id)
			_pending_button = ""
			_pending_timer = 0.0
			return

	# Si hay 1 boton y hay pending de otro, buscar combinacion
	if just_pressed.size() == 1:
		var btn: String = just_pressed[0]
		if _pending_button != "" and _pending_button != btn:
			var combo_id := _find_combination([_pending_button, btn])
			if combo_id != "":
				_try_or_buffer(combo_id)
				_pending_button = ""
				_pending_timer = 0.0
				return
		# Guardar como pending para esperar segundo boton
		_pending_button = btn
		_pending_timer = COMBO_WINDOW

	# Tick del pending timer
	if _pending_timer > 0.0:
		_pending_timer -= c.get_physics_process_delta_time()
		if _pending_timer <= 0.0:
			# Ventana expirada, ejecutar boton pendiente
			var btn := _pending_button
			_pending_button = ""
			_pending_timer = 0.0
			if btn != "":
				var atk_id := _resolve_attack(btn, context)
				if atk_id != "":
					_try_or_buffer(atk_id)


func _get_context() -> String:
	if character.is_airborne():
		return "air"
	if character.state_id() == "crouch":
		return "crouch"
	return "ground"


func _resolve_attack(button: String, context: String) -> String:
	var map: Dictionary = character.data.attack_map
	if not map.has(button):
		return ""
	var ctx_map: Dictionary = map[button]
	if ctx_map.has(context):
		var atk_id: String = ctx_map[context]
		if atk_id in character.data.attacks:
			return atk_id
	# Fallback: intentar ground, luego air
	if ctx_map.has("ground") and ctx_map["ground"] in character.data.attacks:
		return ctx_map["ground"]
	if ctx_map.has("air") and ctx_map["air"] in character.data.attacks:
		return ctx_map["air"]
	return ""


func _find_combination(buttons: Array) -> String:
	var sorted_btns := buttons.duplicate()
	sorted_btns.sort()
	for combo in character.data.combinations:
		var combo_buttons: Array = combo.get("buttons", [])
		var sorted_combo: Array = combo_buttons.duplicate()
		sorted_combo.sort()
		if sorted_btns == sorted_combo:
			var atk_id: String = combo.get("attack_id", "")
			if atk_id in character.data.attacks:
				return atk_id
	return ""


func _try_or_buffer(atk_id: String) -> void:
	if _try_attack(atk_id):
		_buffered_id = ""
		_buffer_timer = 0.0
	else:
		_buffered_id = atk_id
		_buffer_timer = INPUT_BUFFER


func _try_attack(pressed: String) -> bool:
	var c := character
	if _can_cancel_with(pressed):
		var current_id := current_attack.id if current_attack != null else ""
		if current_id != "" and _combo_chain.has(current_id) and _combo_chain.has(pressed):
			var next_id := _get_combo_next(current_id)
			if next_id != "":
				_do_attack(next_id)
				return true
		_start_chain(pressed)
		return true
	if lockout_timer <= 0.0 and c.can_act():
		_start_chain(pressed)
		return true
	return false


func _start_chain(pressed: String) -> void:
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
