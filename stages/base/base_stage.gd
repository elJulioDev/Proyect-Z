extends Node2D
class_name BaseStage
## Escenario base: lee su StageData (.tres) y define fondo/paredes/spawns.
## Los fighters y el HUD los instancia GameManager.

@export var stage_data: StageData

@onready var background_sprite: Sprite2D = $Background
@onready var floor_body: StaticBody2D = $Floor
@onready var left_wall: StaticBody2D = $LeftWall
@onready var right_wall: StaticBody2D = $RightWall
@onready var p1_spawn: Marker2D = $P1_Spawn
@onready var p2_spawn: Marker2D = $P2_Spawn
@onready var stage_camera: Camera2D = $Camera2D
@onready var filter: ColorRect = $FilterLayer/Filter

var player1: BaseCharacter
var player2: BaseCharacter


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	background_sprite.z_index = -10
	apply_config()


func apply_config() -> void:
	if stage_data == null:
		return
	background_sprite.texture = stage_data.background
	background_sprite.position = Vector2.ZERO
	floor_body.position.y = stage_data.floor_y
	left_wall.position.x = -stage_data.wall_limit
	right_wall.position.x = stage_data.wall_limit
	p1_spawn.position = Vector2(-stage_data.spawn_distance, stage_data.floor_y - 50)
	p2_spawn.position = Vector2(stage_data.spawn_distance, stage_data.floor_y - 50)
	stage_camera.zoom = stage_data.camera_zoom
	filter.color = stage_data.filter_color
	if stage_data.background:
		var bg_size: Vector2 = stage_data.background.get_size()
		stage_camera.limit_left = int(-bg_size.x / 2.0)
		stage_camera.limit_right = int(bg_size.x / 2.0)
		stage_camera.limit_top = int(-bg_size.y / 2.0)
		stage_camera.limit_bottom = int(bg_size.y / 2.0)


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
