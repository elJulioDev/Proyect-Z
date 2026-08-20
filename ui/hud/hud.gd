extends CanvasLayer
## HUD de combate: enlaza barras de vida y nombres a los luchadores del escenario.

@onready var p1_health: SlantBar = $Root/Margins/Viewport/Health/Content/P1Health
@onready var p2_health: SlantBar = $Root/Margins/Viewport/Health/Content/P2Health
@onready var p1_energy: SegmentedBar = $Root/Margins/Viewport/Energy/Content/P1Energy
@onready var p2_energy: SegmentedBar = $Root/Margins/Viewport/Energy/Content/P2Energy
@onready var p1_name: Label = $Root/Margins/Viewport/Names/Content/P1Name
@onready var p2_name: Label = $Root/Margins/Viewport/Names/Content/P2Name
@onready var p1_level: RichTextLabel = $Root/Margins/Viewport/Levels/Content/P1Level
@onready var p2_level: RichTextLabel = $Root/Margins/Viewport/Levels/Content/P2Level
@onready var p1_portrait: DiamondIcon = $Root/Margins/Viewport/Portraits/Content/P1Portrait
@onready var p2_portrait: DiamondIcon = $Root/Margins/Viewport/Portraits/Content/P2Portrait


func _ready() -> void:
	if Engine.is_editor_hint():
		return


func setup(p1: BaseCharacter, p2: BaseCharacter) -> void:
	if p1:
		_wire(p1, p1_health, p1_name, p1_energy, p1_level, p1_portrait, false)
	if p2:
		_wire(p2, p2_health, p2_name, p2_energy, p2_level, p2_portrait, true)


func _wire(fighter: BaseCharacter, bar: SlantBar, name_label: Label, energy_bar: SegmentedBar, level_label: RichTextLabel, portrait: DiamondIcon, inverted: bool) -> void:
	if fighter.data:
		name_label.text = fighter.data.display_name
		if fighter.data.icon:
			portrait.portrait_texture = fighter.data.icon
	fighter.energy.bars = energy_bar.segments
	energy_bar.value = fighter.energy.current_energy / fighter.energy.MAX_ENERGY
	level_label.text = ("[font_size=35]%d[/font_size] lv." if inverted else "lv. [font_size=35]%d[/font_size]") % fighter.energy.level()
	fighter.health.health_changed.connect(func(current: float, max_hp: float) -> void:
		bar.apply_damage(current / max_hp)
	)
	fighter.energy.energy_changed.connect(func(current: float, max_energy: float) -> void:
		var target := current / max_energy
		if target < energy_bar.value:
			energy_bar.apply_damage(target)
		else:
			energy_bar.fill(target)
		var lvl := fighter.energy.level()
		level_label.text = ("[font_size=35]%d[/font_size] lv." if inverted else "lv. [font_size=35]%d[/font_size]") % lvl
	)
