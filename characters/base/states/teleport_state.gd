class_name TeleportState extends BaseState
## Breve parpadeo tras el teletransporte (mecánica teleport).

var _timer := 0.0


func enter(args: Dictionary = {}) -> void:
	_timer = args.get("duration", 0.1)
	character.animator.play_anim("teleport_vertical")


func physics(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		character.state_machine.change("locomotion" if character.is_on_floor() else "air")
