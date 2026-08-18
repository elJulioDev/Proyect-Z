class_name AttackState extends BaseState
## Ejecuta un ataque con fases: startup → active → recovery.
## Timer propio sincronizado con la animación.
## Safety net: si la animación termina antes de los timers, sale igualmente.

enum Phase { STARTUP, ACTIVE, RECOVERY }

var _phase: Phase = Phase.STARTUP
var _phase_timer: float = 0.0
var _data: AttackData
var _fps: float = 12.0
var _total_duration: float = 0.0


func enter(args: Dictionary = {}) -> void:
	var id: String = args.get("id", "punch")
	_data = character.data.attacks.get(id, null)
	if _data == null:
		character.state_machine.change("locomotion" if character.is_on_floor() else "air")
		return
	_fps = _get_anim_fps()
	_total_duration = float(_data.startup_frames + _data.active_frames + _data.recovery_frames) / _fps
	_phase = Phase.STARTUP
	_phase_timer = float(_data.startup_frames) / _fps
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
	match _phase:
		Phase.STARTUP:
			if _phase_timer <= 0.0:
				_phase = Phase.ACTIVE
				_phase_timer = float(_data.active_frames) / _fps
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
	character.combat.hitbox.monitoring = false
	character.combat.is_attacking = false


func _exit_attack() -> void:
	character.combat.hitbox.monitoring = false
	character.combat.is_attacking = false
	character.combat.current_attack = null
	var next_state: String = "locomotion" if character.is_on_floor() else "air"
	character.state_machine.change(next_state)


func _get_anim_fps() -> float:
	var anim_data: AnimData = character.data.animations.get(_data.anim, null)
	if anim_data != null and anim_data.fps > 0.0:
		return anim_data.fps
	return 12.0
