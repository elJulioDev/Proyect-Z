class_name StageData extends Resource
## Datos de un escenario. Cada escenario es un .tres de este tipo:
## textura de fondo + dimensiones + colisiones + cámara.
## No hay escena por escenario: base_stage.tscn es la única y lee estos datos.

@export var id: String = ""
@export var display_name: String = ""

@export var background: Texture2D = null
@export var music: AudioStream = null

## Altura del suelo (pixeles).
@export var floor_y: float = 200.0
## Límite horizontal de paredes (|x|).
@export var wall_limit: float = 675.0
## Distancia de aparición de los fighters respecto al centro.
@export var spawn_distance: float = 380.0

## Zoom de la cámara del escenario.
@export var camera_zoom: Vector2 = Vector2(1.2, 1.2)

## Filtro de atmósfera: ColorRect que cubre todo el escenario por encima de los fighters.
@export var filter_color: Color = Color(0, 0, 0, 0)  ## rgba, alpha controla la transparencia
