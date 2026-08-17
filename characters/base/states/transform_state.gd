class_name TransformState extends BaseState
## Animación de transformación: cambia datos y animador, luego reanuda.

var _timer := 0.0


func enter(args: Dictionary = {}) -> void:
	_timer = args.get("duration", 0.6)
	character.animator.play_anim("transform")


func physics(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		character.state_machine.change("locomotion" if character.is_on_floor() else "air")
