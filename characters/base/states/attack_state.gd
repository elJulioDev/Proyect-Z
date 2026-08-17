class_name AttackState extends BaseState
## Ejecuta el ataque elegido por CombatSystem; sale cuando termina la animación.

func enter(args: Dictionary = {}) -> void:
	character.combat.start_attack(args.get("id", "punch"))


func physics(_delta: float) -> void:
	if not character.animator.is_playing():
		character.state_machine.change("locomotion" if character.is_on_floor() else "air")
