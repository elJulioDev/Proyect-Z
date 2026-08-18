class_name FighterController extends Node
## Entrada virtual del luchador. La IA y el teclado la rellenan igual,
## así los estados no saben quién manda.

var character: BaseCharacter
var opponent: BaseCharacter

var move_axis: float = 0.0
var jump_pressed: bool = false
var dash_pressed: bool = false
var block_pressed: bool = false
var block_held: bool = false
var attack_punch_pressed: bool = false
var attack_kick_pressed: bool = false
var attack_ki_pressed: bool = false
var special_1_pressed: bool = false
var special_2_pressed: bool = false
var special_3_pressed: bool = false
var charge_held: bool = false
var charge_ki_pressed: bool = false
var crouch_held: bool = false


func tick() -> void:
	pass


class KeyboardController:
	extends FighterController

	const TAP_WINDOW := 0.25

	var _last_tap_dir := 0.0
	var _last_tap_time := 0.0

	func tick() -> void:
		move_axis = Input.get_axis("move_left", "move_right")
		jump_pressed = Input.is_action_just_pressed("jump")
		block_pressed = Input.is_action_just_pressed("block")
		block_held = Input.is_action_pressed("block")
		attack_punch_pressed = Input.is_action_just_pressed("attack_punch")
		attack_kick_pressed = Input.is_action_just_pressed("attack_kick")
		attack_ki_pressed = Input.is_action_just_pressed("attack_ki")
		special_1_pressed = Input.is_action_just_pressed("special_1")
		special_2_pressed = Input.is_action_just_pressed("special_2")
		special_3_pressed = Input.is_action_just_pressed("special_3")
		charge_held = Input.is_action_pressed("charge_ki")
		charge_ki_pressed = Input.is_action_just_pressed("charge_ki")
		crouch_held = Input.is_action_pressed("move_down")
		dash_pressed = _check_double_tap()

	func _check_double_tap() -> bool:
		var dir := 0.0
		if Input.is_action_just_pressed("move_left"):
			dir = -1.0
		elif Input.is_action_just_pressed("move_right"):
			dir = 1.0
		if dir == 0.0:
			return false
		var now := Time.get_ticks_msec() / 1000.0
		if dir == _last_tap_dir and now - _last_tap_time <= TAP_WINDOW:
			_last_tap_time = now
			return true
		_last_tap_dir = dir
		_last_tap_time = now
		return false


class DummyController:
	extends FighterController
	## Blanco de prueba: no lee entrada, solo permanece quieto y recibe golpes.


class KeyboardControllerP2:
	extends FighterController
	## Solo movimiento: flechas izq/der + salto con flecha arriba.

	var _prev_up := false

	func tick() -> void:
		move_axis = float(Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_LEFT))
		var cur_up := Input.is_physical_key_pressed(KEY_UP)
		jump_pressed = cur_up and not _prev_up
		_prev_up = cur_up


class AIController:
	extends FighterController
	## IA muy básica: persigue al rival y ataca si está cerca.
	## ponytail: heurística simple; mejórala con decisión por distancia cuando haya más estados.

	func tick() -> void:
		if character == null or opponent == null:
			return
		var dist := absf(opponent.global_position.x - character.global_position.x)
		move_axis = signf(opponent.global_position.x - character.global_position.x)
		if dist > 320.0 and randf() < 0.012:
			dash_pressed = true
		if randf() < 0.004:
			jump_pressed = true
		if dist < 150.0 and randf() < 0.05:
			attack_punch_pressed = true
		elif dist < 240.0 and randf() < 0.012:
			attack_kick_pressed = true
