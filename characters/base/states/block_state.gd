class_name BlockState extends BaseState
## Guardia: frena en seco al personaje mientras se mantiene Q.
## 3 posturas: de pie (block), agachado (block_crouch), en el aire (block_air).

var _crouching := false

func enter(args: Dictionary = {}) -> void:
	_crouching = args.get("crouching", false)
	_play_anim()


func physics(_delta: float) -> void:
	var c := character
	if not c.controller.block_held:
		if _crouching and c.is_on_floor():
			c.state_machine.change("crouch")
		else:
			c.state_machine.change("locomotion" if c.is_on_floor() else "air")
		return
	c.velocity.x = 0.0
	_crouching = c.controller.crouch_held and c.is_on_floor()
	_play_anim()


func _play_anim() -> void:
	var c := character
	if not c.is_on_floor():
		c.animator.play_anim("block_air")
	elif _crouching:
		c.animator.play_anim("block_crouch")
	else:
		c.animator.play_anim("block")
