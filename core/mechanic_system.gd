class_name MechanicSystem extends Node
## Instancia una Mechanic por cada slot definido en el CharacterData
## y la dispara cuando se pulsa su botón correspondiente.

const REGISTRY := {
	"teleport": preload("res://characters/base/mechanics/teleport_mechanic.gd"),
	"transform": preload("res://characters/base/mechanics/transform_mechanic.gd"),
	"charge": preload("res://characters/base/mechanics/charge_mechanic.gd"),
	"rush": preload("res://characters/base/mechanics/rush_mechanic.gd"),
}

var character: BaseCharacter
var _mechanics: Dictionary = {}


func _ready() -> void:
	character = get_parent() as BaseCharacter


func rebuild() -> void:
	for slot in _mechanics:
		_mechanics[slot].queue_free()
	_mechanics.clear()
	if character.data == null:
		return
	for slot in character.data.mechanics:
		var cfg: Dictionary = character.data.mechanics[slot]
		var script: GDScript = REGISTRY.get(cfg.get("id", ""), null)
		if script == null:
			continue
		var m: Mechanic = script.new()
		add_child(m)
		m.setup(character)
		m.args = cfg.get("args", {})
		_mechanics[slot] = m


func _physics_process(_delta: float) -> void:
	var c := character
	if c == null or c.controller == null:
		return
	if c.state_id() not in ["locomotion", "air"]:
		return
	for slot in _mechanics:
		if c.controller.get(slot + "_pressed"):
			_mechanics[slot].execute()
