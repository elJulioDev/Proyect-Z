extends CanvasLayer
## Overlay técnico (F1): muestra FPS, RAM, stats de render y datos de partida.

@onready var panel: PanelContainer = $Panel
@onready var label: Label = $Panel/Label

var player1: BaseCharacter
var player2: BaseCharacter


func _ready() -> void:
	panel.visible = false


func setup(p1: BaseCharacter, p2: BaseCharacter) -> void:
	player1 = p1
	player2 = p2


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F1:
		panel.visible = not panel.visible
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if not panel.visible:
		return
	label.text = _build_text()


func _build_text() -> String:
	var info := OS.get_memory_info()
	var ram_mb := float(info.get("physical", 0)) / (1024.0 * 1024.0)
	var virtual_mb := float(info.get("virtual", 0)) / (1024.0 * 1024.0)
	var lines: Array[String] = []
	lines.append("FPS: %d (%.1f ms/frame)" % [Engine.get_frames_per_second(), 1000.0 / maxf(Engine.get_frames_per_second(), 0.001)])
	lines.append("Proceso: %.2f ms | Física: %.2f ms" % [
		Performance.get_monitor(Performance.TIME_PROCESS),
		Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS),
	])
	lines.append("RAM física: %.1f MB | Virtual: %.1f MB" % [ram_mb, virtual_mb])
	lines.append("Memoria Godot: %.1f MB | Pico: %.1f MB" % [
		float(Performance.get_monitor(Performance.MEMORY_STATIC)) / (1024.0 * 1024.0),
		float(Performance.get_monitor(Performance.MEMORY_STATIC_MAX)) / (1024.0 * 1024.0),
	])
	lines.append("Nodos: %d | Recursos: %d" % [
		int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),
	])
	lines.append("Objetos: %d | Huérfanos: %d" % [
		int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
	])
	var vmem := int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED))
	if vmem > 0:
		lines.append("VRAM: %.1f MB | Texturas: %.1f MB" % [
			vmem / (1024.0 * 1024.0),
			int(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)) / (1024.0 * 1024.0),
		])
	lines.append("P1: %s | vida %.0f | pos %.0f,%.0f" % [
		String(player1.state_id()) if player1 else "-",
		player1.health.current_hp if player1 else -1.0,
		player1.global_position.x if player1 else 0.0,
		player1.global_position.y if player1 else 0.0,
	])
	lines.append("P2: %s | vida %.0f | pos %.0f,%.0f" % [
		String(player2.state_id()) if player2 else "-",
		player2.health.current_hp if player2 else -1.0,
		player2.global_position.x if player2 else 0.0,
		player2.global_position.y if player2 else 0.0,
	])
	return "\n".join(lines)
