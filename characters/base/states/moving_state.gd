class_name MovingState extends BaseState
## Movimiento horizontal: mantiene la animación de movimiento mientras se mueve.

func enter(_args: Dictionary = {}) -> void:
	_play_anim()


func physics(_delta: float) -> void:
	var c := character
	var axis := c.controller.move_axis
	if axis == 0.0:
		c.state_machine.change("locomotion")
		return
	var speed := c.get_speed()
	c.velocity.x = axis * speed
	_play_anim()
	if c.controller.jump_pressed:
		c.state_machine.change("jump")
		return
	if c.controller.block_held:
		c.state_machine.change("block")
		return
	if c.controller.dash_pressed and c.dash_cd <= 0.0:
		c.state_machine.change("dash")


func _play_anim() -> void:
	var c := character
	var axis := c.controller.move_axis
	c.animator.play_anim("move_left" if (axis < 0.0) == c.facing_right else "move_right")
