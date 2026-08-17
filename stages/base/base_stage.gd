extends Node2D
class_name BaseStage
## Escenario base: carga su stage.json y spawnea a los luchadores
## definidos por GameManager como hijos "BaseCharacter" y "Player2".

const Controllers := preload("res://core/controllers.gd")

@export var stage_config_path := ""

@onready var background_sprite: Sprite2D = $Background
@onready var floor_body: StaticBody2D = $Floor
@onready var left_wall: StaticBody2D = $LeftWall
@onready var right_wall: StaticBody2D = $RightWall
@onready var p1_spawn: Marker2D = $P1_Spawn
@onready var p2_spawn: Marker2D = $P2_Spawn
@onready var stage_camera: Camera2D = $Camera2D

var player1: BaseCharacter
var player2: BaseCharacter
var config_data := {}


func _ready() -> void:
	if Engine.is_editor_hint():
		return

	background_sprite.z_index = -10
	
	load_config()
	_spawn_fighters()
	_apply_spawns()


func load_config() -> void:
	if stage_config_path == "" or not FileAccess.file_exists(stage_config_path):
		return
	var file := FileAccess.open(stage_config_path, FileAccess.READ)
	var json := JSON.new()
	if json.parse(file.get_as_text()) == OK:
		config_data = json.data
	apply_config()


func apply_config() -> void:
	var tex = load(config_data["assets"]["background"]) if config_data.has("assets") else null
	if tex:
		background_sprite.texture = tex
		background_sprite.position = Vector2.ZERO
	if config_data.has("dimensions"):
		var dim: Dictionary = config_data["dimensions"]
		floor_body.position.y = dim.get("floor_y", floor_body.position.y)
		left_wall.position.x = -dim.get("wall_limit", 675.0)
		right_wall.position.x = dim.get("wall_limit", 675.0)
		p1_spawn.position = Vector2(-dim.get("spawn_distance", 380.0), dim.get("floor_y", 200.0) - 50)
		p2_spawn.position = Vector2(dim.get("spawn_distance", 380.0), dim.get("floor_y", 200.0) - 50)
	if tex and stage_camera:
		var bg_size: Vector2 = tex.get_size()
		stage_camera.limit_left = int(-bg_size.x / 2.0)
		stage_camera.limit_right = int(bg_size.x / 2.0)
		stage_camera.limit_top = int(-bg_size.y / 2.0)
		stage_camera.limit_bottom = int(bg_size.y / 2.0)


func _spawn_fighters() -> void:
	var gm := GameManager
	if not has_node("BaseCharacter") and gm.p1_scene:
		player1 = _spawn_fighter("BaseCharacter", gm.p1_scene)
	if not has_node("Player2") and gm.p2_scene:
		player2 = _spawn_fighter("Player2", gm.p2_scene)
	if player2 and gm.p2_dummy:
		player2.set_controller(Controllers.DummyController.new())
	if player1 and player2:
		player1.controller.opponent = player2
		player2.controller.opponent = player1


func _spawn_fighter(node_name: String, scene: PackedScene) -> BaseCharacter:
	var fighter: BaseCharacter = scene.instantiate()
	fighter.name = node_name
	add_child(fighter)
	return fighter


func _apply_spawns() -> void:
	if player1:
		player1.global_position = p1_spawn.global_position
	if player2:
		player2.global_position = p2_spawn.global_position


func _physics_process(delta: float) -> void:
	if not stage_camera:
		return
	if player1 and player2:
		var target := (player1.global_position + player2.global_position) / 2.0
		target.y -= 30.0
		stage_camera.global_position = stage_camera.global_position.lerp(target, 5.0 * delta)
	elif player1:
		var target := player1.global_position
		target.y -= 30.0
		stage_camera.global_position = stage_camera.global_position.lerp(target, 5.0 * delta)
