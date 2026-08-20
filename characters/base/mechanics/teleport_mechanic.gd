class_name TeleportMechanic extends Mechanic

const DISTANCE := 280.0
const COOLDOWN := 0.8

var _cooldown := 0.0


func _physics_process(delta: float) -> void:
	if _cooldown > 0.0:
		_cooldown -= delta


func execute() -> bool:
	if _cooldown > 0.0:
		return false
	var c := character
	var dir := c.controller.move_axis
	if dir == 0.0:
		dir = 1.0 if c.facing_right else -1.0
	c.global_position += Vector2(DISTANCE * dir, 0.0)
	c.velocity.x = 0.0
	_cooldown = COOLDOWN
	c.force_state("teleport", {"duration": 0.08})
	return true
