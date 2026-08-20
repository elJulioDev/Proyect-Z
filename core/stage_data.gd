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
## Límite horizontal de paredes (|x|). Si es 0, se calcula desde el ancho del fondo menos wall_margin.
@export var wall_limit: float = 0.0
## Píxeles que la pared deja desde el borde del fondo cuando wall_limit es 0.
@export var wall_margin: float = 40.0
## Distancia de aparición de los fighters respecto al centro.
@export var spawn_distance: float = 380.0

## Filtro de atmósfera: ColorRect que cubre todo el escenario por encima de los fighters.
@export var filter_color: Color = Color(0, 0, 0, 0)  ## rgba, alpha controla la transparencia
