class_name EnergySystem extends Node
## Energía cargada: máximo 150, divisible en 3 niveles de 50.
## La gasta cada técnica (special). Solo se carga durante la fase LOOP de la
## animación de carga (no al presionar el botón).

signal energy_changed(current: float, max_energy: float)

const MAX_ENERGY := 150.0
const LEVEL_STEP := 50.0

var character: BaseCharacter
var current_energy := 0.0


func _ready() -> void:
	character = get_parent()


func setup(_data: CharacterData) -> void:
	current_energy = 0.0
	energy_changed.emit(current_energy, MAX_ENERGY)


func charge(amount: float) -> void:
	if not can_charge():
		return
	current_energy = minf(MAX_ENERGY, current_energy + amount)
	energy_changed.emit(current_energy, MAX_ENERGY)


func can_charge() -> bool:
	return current_energy < MAX_ENERGY


func level() -> int:
	return floori(current_energy / LEVEL_STEP)
