class_name ChargeMechanic extends Mechanic
## Carga de ki (P): muestra el aura y restaura saltos/dashes mientras se mantiene P.
## Solo se puede cargar si la energía es menor a 150 (nivel 3); a barra llena
## el sistema de carga queda bloqueado.

func execute() -> bool:
	if character.state_id() not in ["locomotion", "air"]:
		return false
	if character.energy and not character.energy.can_charge():
		return false
	character.jumps_left = character.MAX_JUMPS
	character.air_dashes_left = character.AIR_DASH_LIMIT
	character.force_state("charge")
	return true
