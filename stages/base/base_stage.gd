extends Node2D
class_name BaseStage
## Escenario base: lee su StageData (.tres) y define fondo/paredes/spawns.
## Los fighters y el HUD los instancia GameManager.

const VIEWPORT_SIZE := Vector2(1280, 720)

@export var stage_data: StageData

@onready var background_sprite: Sprite2D = $Background
@onready var floor_body: StaticBody2D = $Floor
@onready var left_wall: StaticBody2D = $LeftWall
@onready var right_wall: StaticBody2D = $RightWall
@onready var p1_spawn: Marker2D = $P1_Spawn
@onready var p2_spawn: Marker2D = $P2_Spawn
@onready var stage_camera: Camera2D = $Camera2D

var _filter_layer: CanvasLayer
var _particle_layer: Node2D
var _fighter_tint_shader: Shader
var _fighter_tint_material: ShaderMaterial

var player1: BaseCharacter:
	set(v):
		player1 = v
		if player1:
			player1.shadows_enabled = stage_data.shadows_enabled if stage_data else true
			player1.effects_enabled = stage_data.effects_enabled if stage_data else true
			_apply_fighter_tint(player1)
var player2: BaseCharacter:
	set(v):
		player2 = v
		if player2:
			player2.shadows_enabled = stage_data.shadows_enabled if stage_data else true
			player2.effects_enabled = stage_data.effects_enabled if stage_data else true
			_apply_fighter_tint(player2)

## Margen horizontal alrededor de los fighters que debe caber en pantalla.
const ZOOM_PADDING := 240.0
## Ancho de mundo visible en el zoom máximo (cerca).
const MAX_ZOOM_WORLD_WIDTH := 850.0

var _min_zoom := 1.0
var _max_zoom := 2.0
var _zoom_speed := 4.0
var _cam_look_y := 0.0


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	background_sprite.z_index = -10
	_setup_filter_layers()
	apply_config()


func _setup_filter_layers() -> void:
	# FilterLayer: en layer 0 (con el mundo del juego), para que el HUD (layer 1) quede encima
	_filter_layer = CanvasLayer.new()
	_filter_layer.name = "FilterLayer"
	_filter_layer.layer = 0
	_filter_layer.set_script(load("res://stages/base/filter_layer.gd"))
	add_child(_filter_layer)

	# ParticleLayer: hijo de Camera2D para que siga el viewport automáticamente
	_particle_layer = Node2D.new()
	_particle_layer.name = "ParticleLayer"
	_particle_layer.set_script(load("res://stages/base/particle_layer.gd"))
	stage_camera.add_child(_particle_layer)

	# Pre-cargar shader de tinte para fighters
	_fighter_tint_shader = load("res://core/shaders/fighter_tint.gdshader")
	_fighter_tint_material = ShaderMaterial.new()
	_fighter_tint_material.shader = _fighter_tint_shader


func apply_config() -> void:
	if stage_data == null:
		return
	background_sprite.texture = stage_data.background
	background_sprite.position = Vector2.ZERO
	# Suelo: línea infinita (colisión muy ancha) fijada en floor_y, los personajes no se caen
	floor_body.position.y = stage_data.floor_y
	floor_body.scale.x = 100000.0

	# Paredes: límite del fondo menos margen, o manual si wall_limit > 0
	var wall_limit := stage_data.wall_limit
	if stage_data.background and wall_limit <= 0.0:
		wall_limit = stage_data.background.get_size().x / 2.0 - stage_data.wall_margin
	left_wall.position.x = -wall_limit
	right_wall.position.x = wall_limit
	p1_spawn.position = Vector2(-stage_data.spawn_distance, stage_data.floor_y)
	p2_spawn.position = Vector2(stage_data.spawn_distance, stage_data.floor_y)

	# Filtros visuales
	_apply_filter()

	if stage_data.background:
		var bg_size: Vector2 = stage_data.background.get_size()
		stage_camera.limit_left = int(-bg_size.x / 2.0)
		stage_camera.limit_right = int(bg_size.x / 2.0)
		stage_camera.limit_top = int(-bg_size.y / 2.0)
		stage_camera.limit_bottom = int(bg_size.y / 2.0)
		# _min_zoom: no más pequeño que el que muestra todo el fondo
		var zoom_x := VIEWPORT_SIZE.x / bg_size.x
		var zoom_y := VIEWPORT_SIZE.y / bg_size.y
		_min_zoom = maxf(zoom_x, zoom_y)
		stage_camera.zoom = Vector2(_min_zoom, _min_zoom)
	_max_zoom = VIEWPORT_SIZE.x / MAX_ZOOM_WORLD_WIDTH

	# La cámara mira un poco arriba del suelo
	_cam_look_y = stage_data.floor_y - 80.0


func _apply_filter() -> void:
	var filter_data: StageFilter = stage_data.filter

	if _filter_layer.has_method("apply"):
		_filter_layer.apply(filter_data)
	if _particle_layer.has_method("apply"):
		_particle_layer.apply(filter_data, VIEWPORT_SIZE)


func _apply_fighter_tint(character: BaseCharacter) -> void:
	if stage_data == null:
		return
	var filter_data: StageFilter = stage_data.filter
	if filter_data == null or not filter_data.color_grading_enabled:
		return
	if filter_data.tint_color.a <= 0.01:
		return

	# Aplicar material de tinte al Sprite2D del fighter
	var sprite := character.get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null:
		return
	var mat := ShaderMaterial.new()
	mat.shader = _fighter_tint_shader
	mat.set_shader_parameter("tint_color", filter_data.tint_color)
	sprite.material = mat


func _physics_process(delta: float) -> void:
	if not stage_camera or not player1:
		return
	# Centro entre ambos fighters
	var target := player1.global_position
	if player2:
		target = (player1.global_position + player2.global_position) / 2.0
	target.y = _cam_look_y

	# Vertical: centrar entre el fighter más alto y el más bajo para que ambos queden en foco
	var top_y := player1.global_position.y
	var bottom_y := player1.global_position.y
	if player2:
		top_y = minf(top_y, player2.global_position.y)
		bottom_y = maxf(bottom_y, player2.global_position.y)
	var mid_y := (top_y + bottom_y) / 2.0
	target.y = minf(mid_y, _cam_look_y)

	# Zoom para que ambos fighters + margen quepan en pantalla; cerca = zoom in, lejos = zoom out
	var desired_zoom := _max_zoom
	if player2:
		var dist := absf(player1.global_position.x - player2.global_position.x)
		desired_zoom = VIEWPORT_SIZE.x / (dist + ZOOM_PADDING)
		desired_zoom = clampf(desired_zoom, _min_zoom, _max_zoom)
	var z := lerpf(stage_camera.zoom.x, desired_zoom, _zoom_speed * delta)
	stage_camera.zoom = Vector2(z, z)

	stage_camera.global_position = stage_camera.global_position.lerp(target, 5.0 * delta)
