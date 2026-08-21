class_name CharacterData extends Resource
## Datos completos de un personaje (o de una forma/transformación).
## Cada luchador apunta a un .tres de este tipo; las formas son más CharacterData.

@export var id: String = ""
@export var display_name: String = ""

@export var sprite: Texture2D = null
@export var icon: Texture2D = null

## Si se define, las animaciones se cargan desde carpetas
## (<sprite_dir>/<anim>/<anim>_000.png...); si no, se usan `sprite` + AnimData.frames.
@export var sprite_dir: String = ""

## Estadísticas base del personaje.
@export var stats: Dictionary = {
	"speed": 300.0,
	"life": 100.0,
	"defense": 0.0,
}

## anim_id -> AnimData (frames sobre la hoja de sprites).
@export var animations: Dictionary = {}

## attack_id -> AttackData (moveset del personaje).
@export var attacks: Dictionary = {}

## Mapa de botones a attack_ids por contexto.
## Estructura: {"light": {"ground": "punch", "air": "air_punch", "crouch": "crouch_light"}, ...}
@export var attack_map: Dictionary = {}

## Combinaciones simultaneas: [{buttons: ["light","medium"], attack_id: "combo_lm"}]
@export var combinations: Array = []

## Cadenas de combo: [{"sequence": ["punch", "punch_2", "punch_3"], "finisher": ""}]
@export var combos: Array = []

## slot (special_1..4) -> {"id": mechanic_id, "args": {...}}
@export var mechanics: Dictionary = {}

## form_id -> CharacterData (transformaciones).
@export var forms: Dictionary = {}

## evento -> AudioStream (sfx por personaje).
@export var sfx: Dictionary = {}
