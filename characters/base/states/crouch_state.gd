class_name CrouchState extends BaseState
## Agacharse: personaje se agacha manteniendo la tecla S.
## No puede saltar ni correr mientras agachado.

func enter(_args: Dictionary = {}) -> void:
	character.animator.play_anim("crouch")

func physics(_delta: float) -> void:
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
		c.state_machine.change("jump")
		return
