class_name AttackState extends BaseState
## Ejecuta un ataque con fases: startup → active → recovery.
## Aplica hitbox/hurtbox keyframes por frame de animacion.
## Fallback: si no hay keyframes, usa hitbox_scale/hitbox_offset legacy.

enum Phase { STARTUP, ACTIVE, RECOVERY }

const BASE_HITBOX_SIZE := Vector2(50, 40)
const BASE_HURTBOX_SIZE := Vector2(30, 45)

var _phase: Phase = Phase.STARTUP
var _phase_timer: float = 0.0
var _data: AttackData
var _fps: float = 12.0
var _total_duration: float = 0.0
var _hitbox_shape: RectangleShape2D
var _hurtbox_shape: RectangleShape2D
var _shapes_ready := false
var _has_hitbox_keyframes := false
var _has_hurtbox_keyframes := false


func _ensure_shapes() -> void:
	if _shapes_ready:
		return
	var hitbox: Area2D = character.get_node("Hitbox")
	_hitbox_shape = hitbox.get_node("CollisionShape2D").shape as RectangleShape2D
	var hurtbox: Area2D = character.get_node("Hurtbox")
	_hurtbox_shape = hurtbox.get_node("CollisionShape2D").shape as RectangleShape2D
	_shapes_ready = true


func enter(args: Dictionary = {}) -> void:
	_ensure_shapes()
	var id: String = args.get("id", "punch")
	_data = character.data.attacks.get(id, null)
	if _data == null:
		character.state_machine.change("locomotion" if character.is_on_floor() else "air")
		return
	_fps = _get_anim_fps()
	_total_duration = float(_data.startup_frames + _data.active_frames + _data.recovery_frames) / _fps
	_phase = Phase.STARTUP
	_phase_timer = float(_data.startup_frames) / _fps
	_has_hitbox_keyframes = _data.hitbox_keyframes.size() > 0
	_has_hurtbox_keyframes = _data.hurtbox_keyframes.size() > 0
	character.velocity.x = 0.0
	character.animator.play_anim(_data.anim)
	character.combat.hitbox.monitoring = false
	character.combat.is_attacking = false


func physics(delta: float) -> void:
	if _data == null:
		return
	if not character.animator.is_playing():
		_exit_attack()
		return
	_phase_timer -= delta
	_apply_keyframes()
	match _phase:
		Phase.STARTUP:
			if _phase_timer <= 0.0:
				_phase = Phase.ACTIVE
				_phase_timer = float(_data.active_frames) / _fps
				# Fallback legacy si no hay keyframes
				if not _has_hitbox_keyframes:
					character.combat.hitbox.scale = _data.hitbox_scale
					character.combat.hitbox.position = _data.hitbox_offset
				character.combat.hitbox.monitoring = true
				character.combat.is_attacking = true
		Phase.ACTIVE:
			if _phase_timer <= 0.0:
				_phase = Phase.RECOVERY
				_phase_timer = float(_data.recovery_frames) / _fps
				character.combat.hitbox.monitoring = false
				character.combat.is_attacking = false
		Phase.RECOVERY:
			if _phase_timer <= 0.0:
				_exit_attack()


func get_phase() -> Phase:
	return _phase


func can_cancel() -> bool:
	return _phase == Phase.RECOVERY


func exit() -> void:
	_reset_shapes()
	character.combat.hitbox.monitoring = false
	character.combat.is_attacking = false


func _exit_attack() -> void:
	_reset_shapes()
	character.combat.hitbox.monitoring = false
	character.combat.is_attacking = false
	character.combat.current_attack = null
	var next_state: String = "locomotion" if character.is_on_floor() else "air"
	character.state_machine.change(next_state)


func _apply_keyframes() -> void:
	var frame_idx := character.animator.frame
	var facing := 1.0 if character.facing_right else -1.0

	if _has_hitbox_keyframes:
		var kf := _find_keyframe(_data.hitbox_keyframes, frame_idx)
		if kf != null and kf.active:
			_hitbox_shape.size = kf.size
			character.combat.hitbox.position = Vector2(kf.offset.x * facing, kf.offset.y)
			character.combat.hitbox.scale = Vector2.ONE
		else:
			character.combat.hitbox.monitoring = false
			character.combat.is_attacking = false

	if _has_hurtbox_keyframes:
		var kf := _find_keyframe(_data.hurtbox_keyframes, frame_idx)
		if kf != null:
			_hurtbox_shape.size = kf.size
			character.get_node("Hurtbox").position = Vector2(kf.offset.x * facing, kf.offset.y)


func _find_keyframe(keyframes: Array, frame_idx: int) -> Resource:
	for kf in keyframes:
		if kf.frame == frame_idx:
			return kf
	return null


func _reset_shapes() -> void:
	_hitbox_shape.size = BASE_HITBOX_SIZE
	_hurtbox_shape.size = BASE_HURTBOX_SIZE
	character.combat.hitbox.position = Vector2.ZERO
	character.combat.hitbox.scale = Vector2.ONE
	character.get_node("Hurtbox").position = Vector2.ZERO


func _get_anim_fps() -> float:
	var anim_data: AnimData = character.data.animations.get(_data.anim, null)
	if anim_data != null and anim_data.fps > 0.0:
		return anim_data.fps
	return 12.0
