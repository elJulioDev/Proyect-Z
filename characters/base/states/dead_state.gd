class_name DeadState extends BaseState
## Derrotado: animación de caída y fin.

func enter(_args: Dictionary = {}) -> void:
	character.animator.play_anim("dead")


func physics(_delta: float) -> void:
	pass
