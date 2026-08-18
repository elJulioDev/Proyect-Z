class_name HealthSystem extends Node
## Vida, daño, hitstun y knockback. Lee las stats del CharacterData.
## Soporta bloqueo: daño reducido + blockstun en vez de hitstun completo.

signal health_changed(current: float, max_hp: float)
signal character_died()

var character: BaseCharacter

var max_hp := 100.0
var current_hp := 100.0
var is_in_hitstun := false
var hitstun_timer := 0.0
var is_dead := false


func _ready() -> void:
	character = get_parent()


func setup(data: CharacterData) -> void:
	max_hp = data.stats.get("life", 100.0)
	current_hp = max_hp
	health_changed.emit(current_hp, max_hp)


func _physics_process(delta: float) -> void:
	_tick_hitstun(delta)


func receive_hit(damage: float, knockback: Vector2, stun_duration: float, block_damage: float, blockstun: float, is_blocking: bool) -> void:
	if is_dead:
		return
	var defense: float = character.data.stats.get("defense", 0.0)
	if is_blocking:
		var chip := maxf(1.0, block_damage - defense * 0.15)
		current_hp = maxf(0.0, current_hp - chip)
		health_changed.emit(current_hp, max_hp)
		character.velocity = Vector2(knockback.x * 0.3, 0.0)
		is_in_hitstun = true
		hitstun_timer = blockstun
		character.force_state("hit")
	else:
		var actual_damage := maxf(1.0, damage - defense * 0.15)
		current_hp = maxf(0.0, current_hp - actual_damage)
		health_changed.emit(current_hp, max_hp)
		character.velocity = knockback
		is_in_hitstun = true
		hitstun_timer = stun_duration
		character.force_state("hit")
	if current_hp <= 0.0:
		_die()


func _tick_hitstun(delta: float) -> void:
	if not is_in_hitstun:
		return
	hitstun_timer -= delta
	if hitstun_timer <= 0.0:
		is_in_hitstun = false


func _die() -> void:
	is_dead = true
	character.force_state("dead")
	character.set_physics_process(false)
	character_died.emit()
	var tw := character.create_tween()
	tw.tween_property(character.animator, "modulate:a", 0.0, 0.6).set_delay(0.3)


func heal(amount: float) -> void:
	current_hp = min(max_hp, current_hp + amount)
	health_changed.emit(current_hp, max_hp)


func is_blocking_input() -> bool:
	return is_in_hitstun or is_dead
