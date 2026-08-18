class_name StateMachine extends Node
## Máquina de estados: cada hijo de este nodo es un estado (BaseState).
## El id de un estado es su nombre en minúsculas.

var character: BaseCharacter
var current: BaseState


func _ready() -> void:
	character = get_parent() as BaseCharacter
	for child in get_children():
		if child is BaseState:
			child.name = child.name.to_lower()
			child.character = character
			child.machine = self


func change(state_id: String, args: Dictionary = {}) -> void:
	var next := get_node_or_null(state_id.to_lower()) as BaseState
	if next == null:
		return
	if current:
		current.exit()
	current = next
	current.enter(args)


func physics(delta: float) -> void:
	if current:
		current.physics(delta)
