class_name Mechanic extends Node
## Base de una mecánica global (special_1..4): ki, teleport, transformación...
## Se instancia por slot del CharacterData y vive mientras dura la pelea.

var character: BaseCharacter
var args: Dictionary = {}


func setup(c: BaseCharacter) -> void:
	character = c


func execute() -> bool:
	return false
