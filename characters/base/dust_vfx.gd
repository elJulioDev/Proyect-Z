class_name DustVFX extends Node2D
## Efectos de polvo durante carga de energía.
## dust1/dust2/dust4: loopean mientras se mantenga la tecla de carga.
## dust3: se dispara UNA sola vez al iniciar la sesión de carga y desaparece
## sola al terminar su animación (no se repite aunque se siga cargando).
##
## Cada "sesión" de carga (desde que se presiona hasta que se suelta) fija un
## ancla de posición UNA sola vez al iniciar (posición del personaje + suelo).
## Las instancias spawneadas quedan ancladas a ese punto para siempre — no
## siguen al personaje ni se "reciclan" entre sesiones. Al soltar la tecla,
## las instancias en loop no se destruyen de golpe: dejan de loopear y
## terminan su ciclo actual antes de autodestruirse, quedando donde estaban.
## Al volver a cargar (en el mismo punto o en otro), se crea una sesión nueva
## e independiente, con sus propias instancias.

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

## Keys que loopean indefinidamente mientras se mantenga la carga (una sola
## instancia por sesión, no se re-spawnean).
const LOOPING_KEYS := ["dust1", "dust2", "dust4"]
## Keys que se disparan UNA sola vez al iniciar la sesión y se autodestruyen
## al terminar su animación.
const BURST_KEYS := ["dust3"]

const DEFAULT_OFFSETS := {
	"dust1": Vector2(0, 0),
	"dust2": Vector2(0, 0),
	"dust3": Vector2(0, -80),
	"dust4": Vector2(0, 0),
}

const DEFAULT_Z_INDEX := {
	"dust1": 2,
	"dust2": -1,
	"dust3": 2,
	"dust4": 2,
}

var _dust_data: Dictionary = {}
var _preview_sprites: Dictionary = {}
## key -> SpriteFrames "plantilla" (nunca se muta ni se usa directamente en
## gameplay; cada instancia gameplay duplica esta plantilla).
var _sprite_frames_template: Dictionary = {}

var _character: BaseCharacter = null

## true mientras se mantiene la tecla de carga (una "sesión" en curso).
var _charging_active := false
## Posición del mundo fijada al iniciar la sesión actual. No se actualiza
## mientras dure la sesión, aunque el personaje se mueva.
var _session_anchor := Vector2.ZERO
## key (de LOOPING_KEYS) -> AnimatedSprite2D activo de la sesión actual.
var _session_loops: Dictionary = {}


func _ready() -> void:
	top_level = true
	for key in DUST_CONFIG:
		_dust_data[key] = {
			"base_offset": DEFAULT_OFFSETS.get(key, Vector2.ZERO),
			"frame_offsets": [],
			"z_index": DEFAULT_Z_INDEX.get(key, 2),
			"fps": DUST_CONFIG[key]["fps"],
		}
		_build_preview_sprite(key)
		_cache_template_sf(key)


func init_offsets(character_data: CharacterData) -> void:
	for key in DUST_CONFIG:
		_dust_data[key] = {
			"base_offset": DEFAULT_OFFSETS.get(key, Vector2.ZERO),
			"frame_offsets": [],
			"z_index": DEFAULT_Z_INDEX.get(key, 2),
			"fps": DUST_CONFIG[key]["fps"],
		}
	if character_data == null or character_data.dust_offsets.size() == 0:
		return
	for key in character_data.dust_offsets:
		if key not in _dust_data:
			continue
		var raw = character_data.dust_offsets[key]
		if raw is Vector2:
			_dust_data[key]["base_offset"] = raw
		elif raw is Dictionary:
			if raw.has("base_offset"):
				_dust_data[key]["base_offset"] = raw["base_offset"]
			if raw.has("frame_offsets"):
				_dust_data[key]["frame_offsets"] = raw["frame_offsets"]
			if raw.has("z_index"):
				_dust_data[key]["z_index"] = raw["z_index"]
			if raw.has("fps"):
				_dust_data[key]["fps"] = raw["fps"]
	for key in _dust_data:
		if key in _preview_sprites:
			_preview_sprites[key].z_index = _dust_data[key]["z_index"]


# ─── Accesores (usados por el tool) ─────────────────────────────────────────

func get_base_offset(key: String) -> Vector2:
	return _dust_data.get(key, {}).get("base_offset", Vector2.ZERO)


func get_frame_offset(key: String, frame_idx: int) -> Vector2:
	var offsets: Array = _dust_data.get(key, {}).get("frame_offsets", [])
	if frame_idx >= 0 and frame_idx < offsets.size():
		var v = offsets[frame_idx]
		if v is Vector2:
			return v
	return Vector2.ZERO


func get_dust_z_index(key: String) -> int:
	return _dust_data.get(key, {}).get("z_index", 2)


func get_dust_fps_value(key: String) -> float:
	return _dust_data.get(key, {}).get("fps", DUST_CONFIG.get(key, {}).get("fps", 12.0))


func set_dust_fps_value(key: String, value: float) -> void:
	if key in _dust_data:
		_dust_data[key]["fps"] = value


func set_base_offset(key: String, value: Vector2) -> void:
	if key in _dust_data:
		_dust_data[key]["base_offset"] = value


func set_frame_offset(key: String, frame_idx: int, value: Vector2) -> void:
	if key not in _dust_data:
		return
	var offsets: Array = _dust_data[key]["frame_offsets"]
	while offsets.size() <= frame_idx:
		offsets.append(Vector2.ZERO)
	offsets[frame_idx] = value


func set_dust_z_index(key: String, value: int) -> void:
	if key in _dust_data:
		_dust_data[key]["z_index"] = value
		if key in _preview_sprites:
			_preview_sprites[key].z_index = value


func to_character_dust_offsets() -> Dictionary:
	var result: Dictionary = {}
	for key in _dust_data:
		result[key] = _dust_data[key].duplicate(true)
	return result


# ─── SpriteFrames plantilla ─────────────────────────────────────────────────

func _cache_template_sf(key: String) -> void:
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
	_sprite_frames_template[key] = frames


func _get_template_sf(key: String) -> SpriteFrames:
	if key in _sprite_frames_template:
		return _sprite_frames_template[key]
	_cache_template_sf(key)
	return _sprite_frames_template.get(key)


## Cada instancia gameplay recibe su PROPIA copia del SpriteFrames, para poder
## cambiarle loop/fps sin afectar a otras instancias vivas de la misma key.
func _make_instance_sf(key: String) -> SpriteFrames:
	var template := _get_template_sf(key)
	if template == null:
		return null
	return template.duplicate(true)


# ─── Preview (tool) ─────────────────────────────────────────────────────────

func _build_preview_sprite(key: String) -> void:
	var sf := _get_template_sf(key)
	if sf == null:
		return
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = sf
	sprite.visible = false
	sprite.z_index = get_dust_z_index(key)
	add_child(sprite)
	_preview_sprites[key] = sprite


func preview_show(key: String, frame_idx: int, anchor_global_pos: Vector2) -> void:
	if key not in _preview_sprites:
		return
	for k in _preview_sprites:
		_preview_sprites[k].visible = (k == key)
	var sprite: AnimatedSprite2D = _preview_sprites[key]
	sprite.stop()
	sprite.animation = "charge_dust"
	sprite.sprite_frames.set_animation_speed("charge_dust", get_dust_fps_value(key))
	sprite.frame = clampi(frame_idx, 0, DUST_CONFIG[key]["num_sprites"] - 1)
	sprite.position = _get_offset(key, frame_idx)
	global_position = anchor_global_pos


func preview_hide() -> void:
	for k in _preview_sprites:
		_preview_sprites[k].visible = false


func get_dust_frame_count(key: String) -> int:
	return DUST_CONFIG[key]["num_sprites"] if key in DUST_CONFIG else 0


func get_dust_loop(key: String) -> bool:
	return DUST_CONFIG[key].get("loop", false) if key in DUST_CONFIG else false


# ─── Gameplay ───────────────────────────────────────────────────────────────

## Se llama desde charge_state CADA FRAME mientras se mantiene la carga.
## Solo la PRIMERA llamada de una sesión (mientras _charging_active es false)
## fija el ancla y dispara todo (loops + burst único); las siguientes llamadas
## de la misma sesión no hacen nada.
func trigger_charge(character: BaseCharacter) -> void:
	_character = character
	if not character.floor_ray.is_colliding():
		return
	var floor_y: float = character.floor_ray.get_collision_point().y
	if absf(character.global_position.y - floor_y) > MAX_FLOOR_DIST:
		return
	if _charging_active:
		return
	_start_session(Vector2(character.global_position.x, floor_y))


func _start_session(anchor: Vector2) -> void:
	_charging_active = true
	_session_anchor = anchor
	for key in LOOPING_KEYS:
		_spawn_loop_instance(key, anchor)
	for key in BURST_KEYS:
		_spawn_burst(key, anchor)


## Se llama UNA vez al soltar la tecla de carga (fin de sesión). Las
## instancias en loop no se destruyen: dejan de loopear para terminar su
## ciclo actual y luego se autodestruyen (quedan donde estaban ancladas).
func stop_all() -> void:
	_charging_active = false
	_character = null
	for key in _session_loops.keys():
		var sprite: AnimatedSprite2D = _session_loops[key]
		if is_instance_valid(sprite):
			var sf: SpriteFrames = sprite.sprite_frames
			if sf and sf.has_animation("charge_dust"):
				sf.set_animation_loop("charge_dust", false)
			if not sprite.animation_finished.is_connected(_on_dust_finished):
				sprite.animation_finished.connect(_on_dust_finished.bind(sprite), CONNECT_ONE_SHOT)
	_session_loops.clear()


func _spawn_loop_instance(key: String, anchor: Vector2) -> void:
	var sf := _make_instance_sf(key)
	if sf == null:
		return
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = sf
	sprite.top_level = true
	sprite.z_index = get_dust_z_index(key)
	add_child(sprite)
	sprite.global_position = anchor + _get_offset(key, 0)
	sprite.animation = "charge_dust"
	sf.set_animation_speed("charge_dust", get_dust_fps_value(key))
	sf.set_animation_loop("charge_dust", true)
	sprite.play("charge_dust")
	sprite.frame_changed.connect(_on_dust_frame_changed.bind(sprite, key, anchor))
	_session_loops[key] = sprite


func _spawn_burst(key: String, anchor: Vector2) -> void:
	var sf := _make_instance_sf(key)
	if sf == null:
		return
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = sf
	sprite.top_level = true
	sprite.z_index = get_dust_z_index(key)
	add_child(sprite)
	sprite.global_position = anchor + _get_offset(key, 0)
	sprite.animation = "charge_dust"
	sf.set_animation_speed("charge_dust", get_dust_fps_value(key))
	sf.set_animation_loop("charge_dust", false)
	sprite.play("charge_dust")
	sprite.frame_changed.connect(_on_dust_frame_changed.bind(sprite, key, anchor))
	sprite.animation_finished.connect(_on_dust_finished.bind(sprite), CONNECT_ONE_SHOT)


func _get_offset(key: String, frame_idx: int) -> Vector2:
	var cfg: Dictionary = DUST_CONFIG[key]
	var base_off: Vector2 = get_base_offset(key)
	var frame_off: Vector2 = get_frame_offset(key, frame_idx)
	return base_off + frame_off + Vector2(0, cfg["frame_h"] * 0.5)


func _on_dust_frame_changed(sprite: AnimatedSprite2D, key: String, anchor: Vector2) -> void:
	if is_instance_valid(sprite):
		sprite.global_position = anchor + _get_offset(key, sprite.frame)


func _on_dust_finished(sprite: AnimatedSprite2D) -> void:
	if is_instance_valid(sprite):
		sprite.queue_free()