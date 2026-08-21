extends Node
## Gestiona el lifecycle de la pelea: rondas, KO, victoria.

signal round_ended(winner: int)
signal fight_ended(final_winner: int)

var player1: BaseCharacter
var player2: BaseCharacter
var p1_wins := 0
var p2_wins := 0
var max_rounds := 1
var round_num := 0
var fight_active := false


func setup(p1: BaseCharacter, p2: BaseCharacter) -> void:
	player1 = p1
	player2 = p2
	p1.health.character_died.connect(_on_p1_died)
	p2.health.character_died.connect(_on_p2_died)


func start_round() -> void:
	round_num += 1
	fight_active = true


func _on_p1_died() -> void:
	_end_round(2)


func _on_p2_died() -> void:
	_end_round(1)


func _end_round(winner: int) -> void:
	if not fight_active:
		return
	fight_active = false
	if winner == 1:
		p1_wins += 1
	else:
		p2_wins += 1
	round_ended.emit(winner)
	# Por ahora: 1 ronda → fight ended
	var final_winner := winner if p1_wins > p2_wins else 2 if p2_wins > p1_wins else 0
	fight_ended.emit(final_winner)
