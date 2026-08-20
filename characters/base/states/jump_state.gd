class_name JumpState extends BaseState
## Salto instantáneo: aplica la velocidad de salto y pasa directo al aire.
## Con args {"super": true} aplica el gran salto (desde agachado con buen timing).

const SUPER_JUMP_VELOCITY := -1000.0

func enter(args: Dictionary = {}) -> void:
	var c := character
	var super_jump: bool = args.get("super", false)
	c.velocity.y = SUPER_JUMP_VELOCITY if super_jump else c.jump_velocity
	c.jumps_left = 0 if super_jump else c.jumps_left - 1
	c.animator.play_anim("jump_rise")
	c.state_machine.change("air")
