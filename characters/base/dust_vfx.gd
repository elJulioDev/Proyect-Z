class_name DustVFX extends Node2D
## Efectos de polvo durante carga de energía.
## Los 4 spritesheets se reproducen al inicio de la carga.
## El eje Y queda fijo al suelo del escenario; el eje X sigue al personaje.

const MAX_FLOOR_DIST := 180.0

const DUST_CONFIG := {
	"dust1": {
		"path": "res://assets/vfx/dust/dust_spritesheet_1.png",
		"num_sprites": 6, "frame_w": 191, "frame_h": 77, "fps": 12.0, "loop": true,
	},
	"dust2": {
		"path": "res://assets/vfx/dust/dust_spritesheet_2.png",
		"num_sprites": 6, "frame_w": 224, "frame_h": 56, "fps": 12.0, "loop": true,
	},
	"dust3": {
		"path": "res://assets/vfx/dust/dust_spritesheet_3.png",
		"num_sprites": 11, "frame_w": 234, "frame_h": 162, "fps": 14.0, "loop": false,
	},
	"dust4": {
		"path": "res://assets/vfx/dust/dust_spritesheet_4.png",
		"num_sprites": 11, "frame_w": 249, "frame_h": 110, "fps": 20.0, "loop": true,
	},
}

## Offset base de cada tipo de polvo respecto a los pies.
var base_offsets := {
	"dust1": Vector2(0, 0),
	"dust2": Vector2(0, 0),
	"dust3": Vector2(0, -80),
	"dust4": Vector2(0, 0),
}

## Offsets por frame individuales.
var frame_offsets := {}

var _sprites: Dictionary = {}
var _floor_y: float = 0.0
var _active: bool = false
var _pending: bool = false
var _character: BaseCharacter = null


func _ready() -> void:
	top_level = true
	for key in DUST_CONFIG:
		_build_sprite(key)


func _process(_delta: float) -> void:
	if _active and _character:
		global_position.x = _character.global_position.x
	elif _pending and _character:
		_check_floor_proximity()


func _build_sprite(key: String) -> void:
	var cfg: Dictionary = DUST_CONFIG[key]
	var tex: Texture2D = load(cfg["path"])
	if tex == null:
		return
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	frames.add_animation("charge_dust")
	frames.set_animation_speed("charge_dust", cfg["fps"])
	frames.set_animation_loop("charge_dust", cfg.get("loop", false))
	var fw: int = cfg["frame_w"]
	for i in cfg["num_sprites"]:
		var region := Rect2(i * fw, 0, fw, cfg["frame_h"])
		var atlas := AtlasTexture.new()
		atlas.atlas = tex
		atlas.region = region
		frames.add_frame("charge_dust", atlas)
	if key not in frame_offsets:
		var arr: Array[Vector2] = []
		arr.resize(cfg["num_sprites"])
		arr.fill(Vector2.ZERO)
		frame_offsets[key] = arr
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = frames
	sprite.visible = false
	sprite.z_index = -1 if key == "dust2" else 2
	add_child(sprite)
	_sprites[key] = sprite


## Se llama desde charge_state al iniciar la carga.
## Si el personaje está cerca del suelo, activa el dust inmediatamente.
## Si está en el aire, espera a que caiga lo suficiente.
func trigger_charge(character: BaseCharacter) -> void:
	_character = character
	_pending = true
	_active = false
	_check_floor_proximity()


func stop_all() -> void:
	_active = false
	_pending = false
	_character = null
	for key in _sprites:
		var sprite: AnimatedSprite2D = _sprites[key]
		var cfg: Dictionary = DUST_CONFIG[key]
		if cfg.get("loop", false) and sprite.visible:
			sprite.sprite_frames.set_animation_loop("charge_dust", false)


func _check_floor_proximity() -> void:
	if not _character or not _character.floor_ray.is_colliding():
		return
	var floor_y: float = _character.floor_ray.get_collision_point().y
	if absf(_character.global_position.y - floor_y) > MAX_FLOOR_DIST:
		return
	_floor_y = floor_y
	_active = true
	_pending = false
	global_position.x = _character.global_position.x
	global_position.y = _floor_y
	for key in _sprites:
		_play_at_feet(key)


func _play_at_feet(key: String) -> void:
	if key not in _sprites:
		return
	var sprite: AnimatedSprite2D = _sprites[key]
	var cfg: Dictionary = DUST_CONFIG[key]
	var base_off: Vector2 = base_offsets.get(key, Vector2.ZERO)
	sprite.position = base_off + Vector2(0, cfg["frame_h"] * 0.5)
	sprite.visible = true
	sprite.stop()
	if cfg.get("loop", false):
		sprite.sprite_frames.set_animation_loop("charge_dust", true)
	sprite.play("charge_dust")
	if not sprite.animation_finished.is_connected(_on_anim_finished.bind(key)):
		sprite.animation_finished.connect(_on_anim_finished.bind(key), CONNECT_ONE_SHOT)


func _on_anim_finished(key: String) -> void:
	if key in _sprites:
		_sprites[key].visible = false
