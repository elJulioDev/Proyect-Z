class_name BaseState extends Node
## Estado base de la máquina de estados del personaje.
## Los estados concretos viven en characters/base/states/.

var character: BaseCharacter
var machine: StateMachine


func enter(_args: Dictionary = {}) -> void:
	pass


func exit() -> void:
	pass


func physics(_delta: float) -> void:
	pass
