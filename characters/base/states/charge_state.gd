class_name ChargeState extends BaseState
## Carga de energía: secuencia de 4 fases.
## Prep → Aura start → Loop (mientras sostenga tecla) → End → salir.
## La energía se acumula solo en la fase LOOP (a partir del 4º frame), nunca
## al pulsar el botón.

const CHARGE_RATE := 50.0

enum Phase { PREP, START, LOOP, END, DONE }

var _phase: Phase = Phase.PREP


func enter(_args: Dictionary = {}) -> void:
	character.velocity = Vector2.ZERO
	_phase = Phase.PREP
	character.animator.visible = true
	character.animator.play_anim("ki_charge_prep")


func physics(delta: float) -> void:
	match _phase:
		Phase.PREP:
			if not character.animator.is_playing():
				character.animator.visible = true
				_phase = Phase.START
				character.animator.play_anim("ki_charge_start")
		Phase.START:
			if not character.animator.is_playing():
				_phase = Phase.LOOP
				character.animator.play_anim("ki_charge_loop")
		Phase.LOOP:
			character.energy.charge(CHARGE_RATE * delta)
			character.charge_dust_vfx()
			if not character.energy.can_charge() or not character.controller.charge_held:
				_phase = Phase.END
				character.animator.play_anim("ki_charge_end")
				character.stop_dust_vfx()
		Phase.END:
			if not character.animator.is_playing():
				_phase = Phase.DONE
				_exit()
		Phase.DONE:
			pass


func _exit() -> void:
	character.animator.visible = true
	character.state_machine.change(
		"locomotion" if character.is_on_floor() else "air"
	)
