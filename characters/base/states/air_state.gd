class_name AirState extends BaseState
## Aire: gravedad, doble salto, dash aéreo y aterrizaje.
## La animación sigue la fase física del salto: subir (jump_rise) y caer (jump_fall).
## Al aterrizar pasa directo a idle sin frame de recuperación.

const AIR_FRICTION := 500.0

var _was_rising := true


func enter(_args: Dictionary = {}) -> void:
	_was_rising = true
	character.animator.play_anim("jump_rise")


func physics(delta: float) -> void:
	var c := character
	if c.is_on_floor():
		c.velocity.x = 0.0
		c.state_machine.change("locomotion")
		return
	# Transición subir → caer (apex)
	if _was_rising and c.velocity.y >= 0.0:
		_was_rising = false
		c.animator.play_anim("jump_fall")
	var axis := c.controller.move_axis
	if axis != 0.0:
		c.velocity.x = axis * c.get_speed()
	else:
		c.velocity.x = move_toward(c.velocity.x, 0.0, AIR_FRICTION * delta)
	if c.controller.block_held:
		c.state_machine.change("block")
		return
	if c.controller.jump_pressed and c.jumps_left > 0:
		c.velocity.y = c.jump_velocity
		c.jumps_left -= 1
		_was_rising = true
		c.animator.play_anim("jump_rise")
	if c.controller.dash_pressed and c.dash_cd <= 0.0 and c.air_dashes_left > 0:
		c.state_machine.change("dash")
