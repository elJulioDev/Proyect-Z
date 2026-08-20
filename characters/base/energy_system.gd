class_name EnergySystem extends Node
## Energía cargada: máximo 150, divisible en barras cuyo tamaño define el HUD
## (cantidad de segmentos de la barra). La gasta cada técnica (special). Solo
## se carga durante la fase LOOP de la animación de carga (no al presionar el botón).

signal energy_changed(current: float, max_energy: float)

const MAX_ENERGY := 150.0

## Barras (segmentos) de la barra de energía del HUD. Lo setea hud.gd.
var bars := 6

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


func spend(amount: float) -> void:
	current_energy = maxf(0.0, current_energy - amount)
	energy_changed.emit(current_energy, MAX_ENERGY)


func can_charge() -> bool:
	return current_energy < MAX_ENERGY


func level() -> int:
	return floori(current_energy / (MAX_ENERGY / bars))
