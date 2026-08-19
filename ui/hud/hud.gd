extends CanvasLayer
## HUD de combate: enlaza barras de vida y nombres a los luchadores del escenario.

@onready var p1_health: SlantBar = $Root/Margins/Viewport/Health/Content/P1Health
@onready var p2_health: SlantBar = $Root/Margins/Viewport/Health/Content/P2Health
@onready var p1_name: Label = $Root/Margins/Viewport/Names/Content/P1Name
@onready var p2_name: Label = $Root/Margins/Viewport/Names/Content/P2Name


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	# Los luchadores se spawnean en BaseStage._ready (después de este nodo).
	await get_tree().process_frame
	var stage := get_parent() as BaseStage
	if stage and stage.player1:
		_wire(stage.player1, p1_health, p1_name)
	if stage and stage.player2:
		_wire(stage.player2, p2_health, p2_name)


func _wire(fighter: BaseCharacter, bar: SlantBar, name_label: Label) -> void:
	if fighter.data:
		name_label.text = fighter.data.display_name
	fighter.health.health_changed.connect(func(current: float, max_hp: float) -> void:
		bar.chip = bar.value
		bar.value = current / max_hp
	)
