extends Node
## InputManager — Sistema de controles personalizados
## Autoload: agrega este nodo como Singleton en Project > Project Settings > Autoload
## con el nombre "InputManager"

# Ruta donde se guarda el archivo de controles del jugador
const SAVE_PATH := "user://controls.cfg"

# Mapa de acciones → nombre legible para la UI de configuración
const ACTION_LABELS := {
	"move_left":    "Mover Izquierda",
	"move_right":   "Mover Derecha",
	"move_up":      "Arriba / Menú",
	"move_down":    "Abajo / Agacharse",
	"jump":         "Saltar",
	"block":        "Guardia",
	"attack_punch": "Golpe (Combo)",
	"attack_kick":  "Patada (Combo)",
	"attack_ki":    "Disparo Ki",
	"charge_ki":    "Cargar Ki",
	"special_1":    "Mecánica Global 1",
	"special_2":    "Mecánica Global 2",
	"special_3":    "Dragon Rush",
}

# Teclas por defecto (backup para resetear)
var _defaults: Dictionary = {}


func _ready() -> void:
	_cache_defaults()
	load_controls()


# ─────────────────────────────────────────────────────────────────────────────
func _cache_defaults() -> void:
	for action in ACTION_LABELS.keys():
		if InputMap.has_action(action):
			_defaults[action] = InputMap.action_get_events(action).duplicate(true)


# ─────────────────────────────────────────────────────────────────────────────
## Guarda el mapa actual en disco
func save_controls() -> void:
	var cfg := ConfigFile.new()
	for action in ACTION_LABELS.keys():
		if not InputMap.has_action(action): continue
		var events := InputMap.action_get_events(action)
		var serialized := []
		for ev in events:
			if ev is InputEventKey:
				serialized.append({"type": "key", "keycode": ev.physical_keycode})
			elif ev is InputEventJoypadButton:
				serialized.append({"type": "joypad_btn", "button": ev.button_index})
			elif ev is InputEventJoypadMotion:
				serialized.append({"type": "joypad_axis", "axis": ev.axis, "value": ev.axis_value})
		cfg.set_value("controls", action, serialized)
	cfg.save(SAVE_PATH)


# ─────────────────────────────────────────────────────────────────────────────
## Carga controles guardados. Si no existe el archivo, usa los del proyecto.
func load_controls() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK: return

	for action in ACTION_LABELS.keys():
		if not cfg.has_section_key("controls", action): continue
		if not InputMap.has_action(action): continue

		InputMap.action_erase_events(action)
		var serialized: Array = cfg.get_value("controls", action, [])
		for data in serialized:
			var ev: InputEvent
			match data.get("type", ""):
				"key":
					var ke := InputEventKey.new()
					ke.physical_keycode = data["keycode"]
					ev = ke
				"joypad_btn":
					var je := InputEventJoypadButton.new()
					je.button_index = data["button"]
					ev = je
				"joypad_axis":
					var ae := InputEventJoypadMotion.new()
					ae.axis       = data["axis"]
					ae.axis_value = data["value"]
					ev = ae
			if ev:
				InputMap.action_add_event(action, ev)


# ─────────────────────────────────────────────────────────────────────────────
## Reasigna una acción a un evento nuevo
func remap_action(action: String, new_event: InputEvent) -> void:
	if not InputMap.has_action(action): return
	InputMap.action_erase_events(action)
	InputMap.action_add_event(action, new_event)
	save_controls()


# ─────────────────────────────────────────────────────────────────────────────
## Restaura todos los controles a los valores por defecto del proyecto
func reset_to_defaults() -> void:
	for action in _defaults.keys():
		InputMap.action_erase_events(action)
		for ev in _defaults[action]:
			InputMap.action_add_event(action, ev)
	# Borra el archivo guardado
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)


# ─────────────────────────────────────────────────────────────────────────────
## Devuelve la primera tecla/botón de una acción como texto para la UI
func get_action_display(action: String) -> String:
	if not InputMap.has_action(action): return "—"
	var events := InputMap.action_get_events(action)
	if events.is_empty(): return "—"
	var ev := events[0]
	if ev is InputEventKey:
		return OS.get_keycode_string(ev.get_physical_keycode_with_modifiers())
	if ev is InputEventJoypadButton:
		return "Btn %d" % ev.button_index
	if ev is InputEventJoypadMotion:
		return "Axis %d (%.0f)" % [ev.axis, ev.axis_value]
	return "—"