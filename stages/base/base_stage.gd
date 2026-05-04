extends Node2D
class_name BaseStage

@export var stage_config_path: String = ""

@onready var background_sprite = $Background
@onready var floor_body = $Floor
@onready var left_wall = $LeftWall
@onready var right_wall = $RightWall
@onready var p1_spawn = $P1_Spawn
@onready var p2_spawn = $P2_Spawn

# Nueva cámara del escenario
@onready var stage_camera = $Camera2D

# Variables para guardar a los jugadores
var player1: CharacterBody2D = null
var player2: CharacterBody2D = null

var config_data: Dictionary = {}

func _ready():
	# Buscar a los jugadores en la escena (Goku está instanciado como "BaseCharacter")
	if has_node("BaseCharacter"):
		player1 = get_node("BaseCharacter")
	
	# Si más adelante añades un P2 (por ejemplo "Player2"), lo buscas aquí:
	if has_node("Player2"):
		player2 = get_node("Player2")

	if load_config():
		apply_config()
	
	# Mover a los jugadores a sus puntos de aparición configurados
	if player1:
		player1.global_position = p1_spawn.global_position
	if player2:
		player2.global_position = p2_spawn.global_position

func load_config() -> bool:
	if stage_config_path == "" or not FileAccess.file_exists(stage_config_path):
		return false
	
	var file = FileAccess.open(stage_config_path, FileAccess.READ)
	var json = JSON.new()
	if json.parse(file.get_as_text()) == OK:
		config_data = json.data
		return true
	return false

func apply_config():
	# 1. Cargar fondo
	var tex = load(config_data["assets"]["background"])
	if tex:
		background_sprite.texture = tex
		# Centrar el fondo en el origen (0,0)
		background_sprite.position = Vector2.ZERO

	# 2. Configurar dimensiones físicas basadas en el (0,0) y el JSON
	var dim = config_data["dimensions"]
	
	# Posicionar el suelo (Eje Y)
	floor_body.position.y = dim["floor_y"]
	
	# Posicionar muros laterales usando valores absolutos (- y +)
	left_wall.position.x = -dim["wall_limit"]
	right_wall.position.x = dim["wall_limit"]
	
	# Posicionar puntos de aparición
	p1_spawn.position = Vector2(-dim["spawn_distance"], dim["floor_y"] - 50)
	p2_spawn.position = Vector2(dim["spawn_distance"], dim["floor_y"] - 50)
	
	# Opcional: Evitar que la cámara se salga de los bordes de la imagen de fondo
	if tex and stage_camera:
		var bg_size = tex.get_size()
		# Como el fondo está en Vector2.ZERO, los bordes son la mitad de su tamaño total
		stage_camera.limit_left = int(-bg_size.x / 2.0)
		stage_camera.limit_right = int(bg_size.x / 2.0)
		stage_camera.limit_top = int(-bg_size.y / 2.0)
		stage_camera.limit_bottom = int(bg_size.y / 2.0)

	print("Escenario ", config_data["name"], " configurado y colisiones ajustadas.")

func _physics_process(delta):
	# Sistema de Cámara Dinámica
	if not stage_camera: return
	
	# Si hay 2 jugadores, la cámara busca el centro exacto entre ambos
	if player1 and player2:
		var target_pos = (player1.global_position + player2.global_position) / 2.0
		# Reducimos la resta para que la cámara baje (antes era -100)
		target_pos.y -= 30 
		stage_camera.global_position = stage_camera.global_position.lerp(target_pos, 5 * delta)
		
	# Si solo está P1 (por ahora probando a Goku), la cámara lo sigue a él
	elif player1:
		var target_pos = player1.global_position
		# Mismo ajuste para 1 jugador
		target_pos.y -= 30
		stage_camera.global_position = stage_camera.global_position.lerp(target_pos, 5 * delta)