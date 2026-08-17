class_name LocomotionState extends BaseState
## Suelo: moverse, frenar, saltar, correr, bloquear o cambiar de estado por daño.

func enter(_args: Dictionary = {}) -> void:
	character.animator.play_anim("idle")


func physics(_delta: float) -> void:
	var c := character
	if not c.is_on_floor():
		c.state_machine.change("air")
		return
	var axis := c.controller.move_axis
	if c.controller.dash_pressed and c.dash_cd <= 0.0:
		c.state_machine.change("dash")
		return
	if axis != 0.0:
		c.state_machine.change("moving")
		return
	var speed := c.get_speed()
	c.velocity.x = move_toward(c.velocity.x, 0.0, speed)
	c.animator.play_anim("idle")
	if c.controller.block_held:
		c.state_machine.change("block")
		return
	if c.controller.jump_pressed:
		c.state_machine.change("jump")
		return
