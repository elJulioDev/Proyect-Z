class_name CrouchState extends BaseState
## Agacharse: personaje se agacha manteniendo la tecla S.
## Saltar dentro de GRAN_SALTO_WINDOW tras agacharse ejecuta un gran salto.

const GRAN_SALTO_WINDOW := 0.3
var _time := 0.0

func enter(_args: Dictionary = {}) -> void:
	_time = 0.0
	character.animator.play_anim("crouch")

func physics(delta: float) -> void:
	_time += delta
	var c := character
	if not c.is_on_floor():
		c.state_machine.change("air")
		return
	c.velocity.x = 0.0
	if c.controller.block_held:
		c.state_machine.change("block", {"crouching": true})
		return
	if not c.controller.crouch_held:
		c.state_machine.change("locomotion")
		return
	if c.controller.jump_pressed:
		c.state_machine.change("jump", {"super": _time <= GRAN_SALTO_WINDOW})
		return
