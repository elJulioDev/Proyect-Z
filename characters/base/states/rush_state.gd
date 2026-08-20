class_name RushState extends BaseState
## Dragon Rush: 3 fases — prep (vuelo hacia arriba + encuadre),
## start (flash de 1 frame), fly (vuelo hasta impacto con oponente).

const PREP_HEIGHT := 150.0
const PREP_RISE_SPEED := 500.0
const FLY_SPEED := 1500.0
const ENERGY_DRAIN := 20.0

var _phase := 0
var _timer := 0.0
var _target_pos := Vector2.ZERO
var _hit_landed := false
var _fly_target_y := 0.0
var _pos_played := false


func enter(_args: Dictionary = {}) -> void:
	_phase = 0
	_timer = 0.0
	_hit_landed = false
	_pos_played = false

	var c := character
	c.velocity = Vector2.ZERO
	c.animator.play_anim("dragon_rush")
	if c.controller and c.controller.opponent:
		_target_pos = c.controller.opponent.global_position
	_fly_target_y = c.global_position.y - PREP_HEIGHT


func exit() -> void:
	var hb := character.combat.hitbox
	hb.set_deferred("monitoring", false)
	if hb.area_entered.is_connected(_on_hit):
		hb.area_entered.disconnect(_on_hit)
	character.animator.rotation = 0.0


func physics(delta: float) -> void:
	match _phase:
		0:
			_phase_prep(delta)
		1:
			_phase_start(delta)
		2:
			_phase_fly(delta)


func _phase_prep(_delta: float) -> void:
	var c := character

	if c.controller and c.controller.opponent:
		_target_pos = c.controller.opponent.global_position
		if c.animator.frame >= 2:
			c.facing_right = _target_pos.x > c.global_position.x
			c.animator.flip_h = not c.facing_right

	if c.is_on_floor():
		if c.global_position.y > _fly_target_y:
			c.velocity.y = -PREP_RISE_SPEED
		else:
			c.velocity.y = 0.0
			c.global_position.y = _fly_target_y

	if not c.animator.is_playing():
		_phase = 1
		_timer = 0.0


func _phase_start(delta: float) -> void:
	_timer += delta
	if not _pos_played:
		_pos_played = true
		character.animator.play_anim("dragon_rush_pos")
	var pos_anim: AnimData = character.data.animations.get("dragon_rush_pos")
	if pos_anim and _timer >= pos_anim.frames.size() / pos_anim.fps:
		# Solo entra al vuelo si la tecla sigue mantenida; si fue un tap, termina tras la preparación
		if not (character.controller and character.controller.special_3_held):
			_end_rush()
			return
		_phase = 2
		_hit_landed = false
		var c := character
		c.animator.play_anim("dragon_rush_loop")
		var hb := c.combat.hitbox
		hb.area_entered.connect(_on_hit, CONNECT_ONE_SHOT)
		hb.monitoring = true


func _phase_fly(delta: float) -> void:
	var c := character
	if c.controller and not c.controller.special_3_held:
		_cancel_rush()
		return
	c.energy.spend(ENERGY_DRAIN * delta)
	if c.energy.current_energy <= 0.0:
		_cancel_rush()
		return
	if c.controller and c.controller.opponent:
		_target_pos = c.controller.opponent.global_position

	var dir := (_target_pos - c.global_position).normalized()
	c.velocity = dir * FLY_SPEED
	c.facing_right = dir.x > 0.0
	c.animator.flip_h = not c.facing_right
	var lean := clampf(dir.y * 0.5, -0.5, 0.5)
	c.animator.rotation = lean if c.facing_right else -lean

	if c.global_position.distance_to(_target_pos) < 60.0:
		_do_hit()
		_end_rush()


func _on_hit(area: Area2D) -> void:
	if area.name != "Hurtbox":
		return
	var target: Node = area.get_parent()
	if target == character or not target.has_method("receive_hit"):
		return
	if _hit_landed:
		return
	_hit_landed = true
	var kb_dir := 1.0 if character.facing_right else -1.0
	target.receive_hit(12.0, Vector2(520.0 * kb_dir, -160.0), 0.25, 0.0, 0.0, false)


func _do_hit() -> void:
	if _hit_landed:
		return
	_hit_landed = true
	var c := character
	if c.controller and c.controller.opponent:
		var kb_dir := 1.0 if c.facing_right else -1.0
		c.controller.opponent.receive_hit(12.0, Vector2(520.0 * kb_dir, -160.0), 0.25, 0.0, 0.0, false)


func _cancel_rush() -> void:
	_end_rush()


func _end_rush() -> void:
	var c := character
	c.velocity = Vector2.ZERO
	var hb := c.combat.hitbox
	hb.set_deferred("monitoring", false)
	if hb.area_entered.is_connected(_on_hit):
		hb.area_entered.disconnect(_on_hit)
	c.state_machine.change("locomotion" if c.is_on_floor() else "air")
