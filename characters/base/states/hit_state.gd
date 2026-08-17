class_name HitState extends BaseState
## Hitstun: espera a que HealthSystem libere al personaje.

func enter(_args: Dictionary = {}) -> void:
	character.animator.play_anim("hit")


func physics(_delta: float) -> void:
	if not character.health.is_in_hitstun:
		character.state_machine.change("locomotion" if character.is_on_floor() else "air")
