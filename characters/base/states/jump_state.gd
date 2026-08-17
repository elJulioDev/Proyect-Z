class_name JumpState extends BaseState
## Salto instantáneo: aplica la velocidad de salto y pasa directo al aire.

func enter(_args: Dictionary = {}) -> void:
	var c := character
	c.velocity.y = c.jump_velocity
	c.jumps_left -= 1
	c.animator.play_anim("jump_rise")
	c.state_machine.change("air")
