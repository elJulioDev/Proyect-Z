class_name ChargeMechanic extends Mechanic
## Carga de ki (P): muestra el aura y restaura saltos/dashes mientras se mantiene P.
## ponytail: sin medidor de ki todavía; el buff es solo cosmético + reset.

func execute() -> bool:
	if character.state_id() not in ["locomotion", "air"]:
		return false
	character.jumps_left = character.MAX_JUMPS
	character.air_dashes_left = character.AIR_DASH_LIMIT
	character.force_state("charge")
	return true
