class_name BlockState extends BaseState
## Guardia: frena en seco al personaje mientras se mantiene el botón.
## Animación según estado: en el suelo (block) o en el aire (block_air).

func enter(_args: Dictionary = {}) -> void:
	character.animator.play_anim("block")


func physics(_delta: float) -> void:
	var c := character
	if not c.controller.block_held:
		c.state_machine.change("locomotion" if c.is_on_floor() else "air")
		return
	c.velocity.x = 0.0
	c.animator.play_anim("block_air" if not c.is_on_floor() else "block")
