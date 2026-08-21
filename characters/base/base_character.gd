class_name BaseCharacter extends CharacterBody2D
## Personaje base: delgado a propósito. La lógica está en los estados
## (StateMachine) y los subsistemas (CombatSystem, HealthSystem, MechanicSystem).
## Un luchador concreto instancia base_character.tscn y asigna su CharacterData.

const MAX_JUMPS := 2
const gravity := 1200.0
const FLOAT_FALL_SPEED := 100.0
const jump_velocity := -620.0
const AIR_DASH_LIMIT := 1

const Controllers := preload("res://core/controllers.gd")

@export var character_data: CharacterData
@export var controller: FighterController

var data: CharacterData
var facing_right := true
var jumps_left := MAX_JUMPS
var dash_cd := 0.0
var air_dashes_left := AIR_DASH_LIMIT

@onready var animator: CharacterAnimator = $Animator
@onready var shadow_sprite: Sprite2D = $Shadow
@onready var floor_ray: RayCast2D = $FloorRay
@onready var state_machine: StateMachine = $StateMachine
@onready var combat: CombatSystem = $CombatSystem
@onready var health: HealthSystem = $HealthSystem
@onready var energy: EnergySystem = $EnergySystem
@onready var mechanics: MechanicSystem = $MechanicSystem

var base_shadow_scale := Vector2(2.8, 1.5)
var shadow_offset_y := 25.0
var max_jump_height := 400.0
var debug_mode := false
var debug_boxes := false
var _f1_held := false
var _debug_node: Node2D


func _ready() -> void:
	data = character_data
	shadow_sprite.top_level = true
	
	# Asegurar que la sombra se dibuja detrás de los personajes pero sobre el mapa
	shadow_sprite.z_index = -1 
	
	if controller == null:
		set_controller(Controllers.KeyboardController.new())
	if data:
		animator.setup(data)
		health.setup(data)
		energy.setup(data)
		mechanics.rebuild()
		state_machine.change("locomotion")

	_debug_node = Node2D.new()
	_debug_node.z_index = 100
	_debug_node.visible = false
	add_child(_debug_node)
	_debug_node.set_script(preload("res://characters/base/debug_draw.gd"))


func _process(_delta: float) -> void:
	if debug_boxes:
		_debug_node.queue_redraw()


func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.keycode == KEY_F1:
			_f1_held = event.pressed
		elif event.pressed and _f1_held and event.keycode == KEY_H:
			debug_boxes = not debug_boxes
			_debug_node.visible = debug_boxes


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
			match event.keycode:
				KEY_R:
					_reload_data()
				KEY_X:
					energy.spend(energy.current_energy)
				KEY_0:
					debug_mode = false
					animator.play_anim("idle")
				KEY_1:
					debug_mode = true
					velocity = Vector2.ZERO
					animator.play_anim("light_1")
				KEY_2:
					debug_mode = true
					velocity = Vector2.ZERO
					animator.play_anim("light_2")
				KEY_3:
					debug_mode = true
					velocity = Vector2.ZERO
					animator.play_anim("light_3")
				KEY_4:
					debug_mode = true
					velocity = Vector2.ZERO
					animator.play_anim("dragon_rush")
				KEY_5:
					debug_mode = true
					velocity = Vector2.ZERO
					animator.play_anim("dragon_rush_pos")
				KEY_6:
					debug_mode = true
					velocity = Vector2.ZERO
					animator.play_anim("dragon_rush_loop")
				KEY_7:
					debug_mode = true
					velocity = Vector2.ZERO
					animator.play_anim("heavy")
				KEY_8:
					debug_mode = true
					velocity = Vector2.ZERO
					animator.play_anim("medium")
				KEY_9:
					debug_mode = true
					velocity = Vector2.ZERO
					animator.play_anim("dragon_rush")


func _reload_data() -> void:
	if character_data == null:
		return
	var path := character_data.resource_path
	if path.is_empty():
		return
	character_data = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	data = character_data
	animator.setup(data)
	mechanics.rebuild()
	force_state("locomotion" if is_on_floor() else "air")


func _physics_process(delta: float) -> void:
	if dash_cd > 0.0:
		dash_cd -= delta
	if debug_mode:
		if not animator.is_playing():
			debug_mode = false
	else:
		controller.tick()
		state_machine.physics(delta)
	if not is_on_floor():
		if state_id() == "rush":
			pass
		elif velocity.y >= 0.0 and state_id() in ["block", "charge"]:
			velocity.y = FLOAT_FALL_SPEED
		else:
			velocity.y += gravity * delta
	_update_facing()
	move_and_slide()
	update_shadow()
	if is_on_floor():
		jumps_left = MAX_JUMPS
		air_dashes_left = AIR_DASH_LIMIT


# ── API de estados ──────────────────────────────────────────────────────────
func state_id() -> String:
	if state_machine.current == null:
		return ""
	return state_machine.current.name as String


func force_state(state: String, args: Dictionary = {}) -> void:
	state_machine.change(state, args)


func can_act() -> bool:
	return state_id() in ["locomotion", "air", "crouch"]


func is_airborne() -> bool:
	return not is_on_floor()


func get_speed() -> float:
	return data.stats.get("speed", 300.0) if data else 300.0


# ── Controladores ───────────────────────────────────────────────────────────
func set_controller(c: FighterController) -> void:
	if controller and controller != c:
		controller.queue_free()
	controller = c
	if controller and controller.get_parent() != self:
		add_child(controller)
	if controller:
		controller.character = self


# ── Datos y transformaciones ────────────────────────────────────────────────
func transform_to(form_id: String) -> void:
	var form: CharacterData = data.forms.get(form_id, null)
	if form == null:
		return
	data = form
	animator.setup(data)
	mechanics.rebuild()
	force_state("transform", {"duration": 0.6})


# ── Golpes ──────────────────────────────────────────────────────────────────
## Llamado por CombatSystem del atacante sobre este personaje.
func receive_hit(damage: float, knockback: Vector2, stun: float, block_damage: float = 0.0, blockstun: float = 0.0, is_blocking: bool = false) -> void:
	health.receive_hit(damage, knockback, stun, block_damage, blockstun, is_blocking)


# ── VFX ─────────────────────────────────────────────────────────────────────
func double_jump_vfx() -> void:
	var tw := create_tween()
	tw.tween_property(animator, "scale", Vector2(1.3, 0.7), 0.06)
	tw.tween_property(animator, "scale", Vector2(0.85, 1.2), 0.08)
	tw.tween_property(animator, "scale", Vector2.ONE, 0.10)


# ── Auxiliares ──────────────────────────────────────────────────────────────
func _update_facing() -> void:
	if controller and controller.get("opponent") and controller.opponent:
		facing_right = controller.opponent.global_position.x > global_position.x
	elif controller and controller.move_axis != 0.0:
		facing_right = controller.move_axis > 0.0
	elif velocity.x != 0.0:
		facing_right = velocity.x > 0.0
	animator.flip_h = not facing_right


func update_shadow() -> void:
	if not floor_ray.is_colliding():
		shadow_sprite.visible = false
		return
	shadow_sprite.visible = true
	var floor_pos := floor_ray.get_collision_point()
	shadow_sprite.global_position = Vector2(global_position.x, floor_pos.y + shadow_offset_y)
	var distance := absf(global_position.y - floor_pos.y)
	var ratio := clampf(distance / max_jump_height, 0.0, 1.0)
	shadow_sprite.scale = base_shadow_scale * Vector2(lerpf(1.0, 1.3, ratio), lerpf(1.0, 0.8, ratio))
	shadow_sprite.modulate.a = lerpf(0.6, 0.15, distance / max_jump_height)
