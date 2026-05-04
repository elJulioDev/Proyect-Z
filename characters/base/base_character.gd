extends CharacterBody2D
class_name BaseCharacter

var stats: Dictionary = {}
var current_state: String = "idle"
var facing_right: bool = true

# Físicas reales 2D para un fighting game
var gravity: float = 1200.0 # Gravedad constante hacia abajo en el eje Y
var jump_velocity: float = -600.0 # Negativo porque en Godot el eje Y sube con valores negativos

@export var char_json_path: String = ""

@onready var sprite = $Sprite2D
@onready var anim_player = $AnimationPlayer

# Nodos para el sistema de sombras
@onready var shadow_sprite = $Shadow
@onready var floor_ray = $FloorRay

# Parámetros visuales de la sombra
var base_shadow_scale = Vector2(2.8, 1.5) # Escala 1:1, respetará el tamaño de tu pixel art
var shadow_offset_y = 25.0 # Ajusta este número (ej. -5.0 o 5.0) para centrar la sombra en el piso
var max_jump_height = 400.0 # Altura de referencia máxima para el cálculo

func _ready():
	# Desvinculamos la sombra de las transformaciones del jugador para que no rote ni herede escalas raras
	shadow_sprite.top_level = true 
	
	load_character_data()
	if not stats.has("base_statistics"):
		stats["base_statistics"] = {"speed": 250}

func _physics_process(delta):
	# 1. Aplicar Gravedad
	if not is_on_floor():
		velocity.y += gravity * delta
		current_state = "jump"

	# 2. Manejo del Salto
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity
		current_state = "jump"

	# 3. Manejo del Movimiento Horizontal (Solo Izquierda/Derecha)
	var direction = Input.get_axis("move_left", "move_right")
	var speed = stats["base_statistics"].get("speed", 250)

	if direction != 0:
		velocity.x = direction * speed
		if is_on_floor():
			current_state = "move"
	else:
		velocity.x = move_toward(velocity.x, 0, speed) 
		if is_on_floor():
			current_state = "idle"

	update_facing_direction()
	
	# move_and_slide se encarga de las colisiones y actualiza is_on_floor()
	move_and_slide()
	
	# Ejecutar el cálculo dinámico de la sombra en cada fotograma
	update_shadow()

func update_shadow():
	if not floor_ray.is_colliding():
		shadow_sprite.visible = false
		return

	shadow_sprite.visible = true
	var floor_pos = floor_ray.get_collision_point()
	
	# POSICIONAR: La sombra sigue al jugador en X, pero se ancla al piso en Y
	shadow_sprite.global_position = Vector2(global_position.x, floor_pos.y + shadow_offset_y)

	# FÍSICAS DE ALTURA
	var distance = abs(global_position.y - floor_pos.y)
	var ratio = clamp(distance / max_jump_height, 0.0, 1.0)

	# ESCALA DINÁMICA DEL ÓVALO
	# Al saltar, la sombra se hace un poco más ancha pero no pierde su forma
	var scale_x = lerp(1.0, 1.3, ratio)
	var scale_y = lerp(1.0, 0.8, ratio) 
	shadow_sprite.scale = base_shadow_scale * Vector2(scale_x, scale_y)
	
	# OPACIDAD NATIVA
	# 60% de opacidad en el suelo, bajando a 15% en el punto más alto del salto
	shadow_sprite.modulate.a = lerp(0.6, 0.15, ratio)

func update_facing_direction():
	if velocity.x > 0:
		facing_right = true
	elif velocity.x < 0:
		facing_right = false
	
	sprite.flip_h = !facing_right

func load_character_data():
	if char_json_path == "": return
	
	var file = FileAccess.open(char_json_path, FileAccess.READ)
	if file:
		var json = JSON.new()
		var error = json.parse(file.get_as_text())
		if error == OK:
			stats = json.data
