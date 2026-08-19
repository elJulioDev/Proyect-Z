extends CanvasLayer
## HUD de combate: enlaza barras de vida y nombres a los luchadores del escenario.

@onready var p1_health: SlantBar = $Root/Margins/Viewport/Health/Content/P1Health
@onready var p2_health: SlantBar = $Root/Margins/Viewport/Health/Content/P2Health
@onready var p1_energy: SlantBar = $Root/Margins/Viewport/Energy/Content/P1Energy
@onready var p2_energy: SlantBar = $Root/Margins/Viewport/Energy/Content/P2Energy
@onready var p1_name: Label = $Root/Margins/Viewport/Names/Content/P1Name
@onready var p2_name: Label = $Root/Margins/Viewport/Names/Content/P2Name
@onready var p1_level: RichTextLabel = $Root/Margins/Viewport/Levels/Content/P1Level
@onready var p2_level: RichTextLabel = $Root/Margins/Viewport/Levels/Content/P2Level


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	# Los luchadores se spawnean en BaseStage._ready (después de este nodo).
	await get_tree().process_frame
	var stage := get_parent() as BaseStage
	if stage and stage.player1:
		_wire(stage.player1, p1_health, p1_name, p1_energy, p1_level, false)
	if stage and stage.player2:
		_wire(stage.player2, p2_health, p2_name, p2_energy, p2_level, true)


func _wire(fighter: BaseCharacter, bar: SlantBar, name_label: Label, energy_bar: SlantBar, level_label: RichTextLabel, inverted: bool) -> void:
	if fighter.data:
		name_label.text = fighter.data.display_name
	energy_bar.value = fighter.energy.current_energy / fighter.energy.MAX_ENERGY
	level_label.text = ("[font_size=35]%d[/font_size] lv." if inverted else "lv. [font_size=35]%d[/font_size]") % fighter.energy.level()
	fighter.health.health_changed.connect(func(current: float, max_hp: float) -> void:
		bar.chip = bar.value
		bar.value = current / max_hp
	)
	fighter.energy.energy_changed.connect(func(current: float, max_energy: float) -> void:
		energy_bar.value = current / max_energy
		var lvl := fighter.energy.level()
		level_label.text = ("[font_size=35]%d[/font_size] lv." if inverted else "lv. [font_size=35]%d[/font_size]") % lvl
	)
