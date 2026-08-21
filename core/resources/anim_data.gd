class_name AnimData extends Resource
## Animación simple por frames sobre la hoja de sprites del personaje.

@export var frames: Array[Rect2] = []
@export var offsets: Array[Vector2] = []
@export var fps: float = 10.0
@export var loop: bool = true
