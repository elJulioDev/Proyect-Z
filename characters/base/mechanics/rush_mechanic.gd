class_name RushMechanic extends Mechanic
## Dragon Rush (O): tacleo hacia delante con golpe al entrar.

const COOLDOWN := 0.6

var _cooldown := 0.0


func _physics_process(delta: float) -> void:
	if _cooldown > 0.0:
		_cooldown -= delta


func execute() -> bool:
	if _cooldown > 0.0 or character.state_id() not in ["locomotion", "air"]:
		return false
	if character.energy.current_energy <= 0.0:
		return false
	_cooldown = COOLDOWN
	character.force_state("rush")
	return true
