class_name DashState extends BaseState
## Dash (doble toque A/D): desplazamiento rápido mostrando los sprites de movimiento.

const DASH_SPEED := 1400.0
const DASH_DURATION := 0.12
const DASH_COOLDOWN := 0.40
const AIR_DASH_LIMIT := 1

var _timer := 0.0
var _dir := 1.0


func enter(_args: Dictionary = {}) -> void:
	var c := character
	_timer = DASH_DURATION
	_dir = c.controller.move_axis if c.controller.move_axis != 0.0 else (1.0 if c.facing_right else -1.0)
	c.velocity.y = 0.0
	c.animator.play_anim("move_left" if (_dir < 0.0) == c.facing_right else "move_right")
	if not c.is_on_floor():
		c.air_dashes_left -= 1
	c.dash_cd = DASH_COOLDOWN


func physics(delta: float) -> void:
	var c := character
	_timer -= delta
	if _timer <= 0.0:
		c.velocity.x = 0.0
		c.state_machine.change("locomotion" if c.is_on_floor() else "air")
		return
	c.velocity.x = DASH_SPEED * _dir
	c.animator.play_anim("move_left" if (_dir < 0.0) == c.facing_right else "move_right")
