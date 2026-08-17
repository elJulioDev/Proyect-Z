class_name TransformMechanic extends Mechanic

## Cambia a la forma indicada en args (e.g. {"form": "ssj"}).
func execute() -> bool:
	if args.is_empty():
		return false
	var form_id: String = args.get("form", "")
	var form: CharacterData = character.data.forms.get(form_id, null)
	if form == null:
		return false
	character.transform_to(form_id)
	return true
