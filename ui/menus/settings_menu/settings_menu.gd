extends Control
## Menú de configuraciones, inspirado en la interfaz del mod Sodium de
## Minecraft: categorías a la izquierda, opciones agrupadas en paneles a la
## derecha. Toda la disposición visual vive en la escena (settings_menu.tscn);
## este script solo se encarga de:
##   1) mostrar la página de opciones según la categoría activa
##   2) filtrar filas con la barra de búsqueda
##   3) aplicar efectos en vivo (volumen general, modo de ventana)
##   4) guardar / cargar / restablecer valores
##   5) volver al menú principal

const MAIN_MENU_PATH := "res://ui/menus/main_menu/menu.tscn"
const SAVE_PATH := "user://settings.cfg"
const SAVE_SECTION := "settings"

@onready var _search: LineEdit = $Root/Layout/TopBar/SearchField
@onready var _reset_button: Button = $Root/Layout/TopBar/ResetButton
@onready var _apply_button: Button = $Root/Layout/BottomBar/ApplyButton
@onready var _done_button: Button = $Root/Layout/BottomBar/DoneButton

@onready var _cat_display: Button = $Root/Layout/MainArea/Sidebar/CategoryList/CatDisplay
@onready var _cat_sound: Button = $Root/Layout/MainArea/Sidebar/CategoryList/CatSound
@onready var _cat_game: Button = $Root/Layout/MainArea/Sidebar/CategoryList/CatGame

@onready var _page_display: VBoxContainer = $Root/Layout/MainArea/OptionsScroll/Pages/PageDisplay
@onready var _page_sound: VBoxContainer = $Root/Layout/MainArea/OptionsScroll/Pages/PageSound
@onready var _page_game: VBoxContainer = $Root/Layout/MainArea/OptionsScroll/Pages/PageGame

## Filas con integración real a sistemas del motor (ver _apply_live_effects).
@onready var _window_mode_row: CycleRow = $Root/Layout/MainArea/OptionsScroll/Pages/PageDisplay/PanelWindowMode/RowWindowMode
@onready var _master_volume_row: SliderRow = $Root/Layout/MainArea/OptionsScroll/Pages/PageSound/PanelMasterVolume/RowMasterVolume

var _pages: Array = []
var _category_buttons: Array = []
var _default_snapshot: Dictionary = {}


func _ready() -> void:
	_pages = [_page_display, _page_sound, _page_game]
	_category_buttons = [_cat_display, _cat_sound, _cat_game]
	for i in _category_buttons.size():
		_category_buttons[i].toggled.connect(_on_category_toggled.bind(i))
	_search.text_changed.connect(_on_search_text_changed)
	_reset_button.pressed.connect(_on_reset_pressed)
	_apply_button.pressed.connect(_on_apply_pressed)
	_done_button.pressed.connect(_on_done_pressed)
	_show_page(0)
	_store_defaults()
	_load_settings()


# ─── Categorías (sidebar → página) ──────────────────────────────────────────

func _on_category_toggled(pressed: bool, index: int) -> void:
	if pressed:
		_show_page(index)


func _show_page(index: int) -> void:
	for i in _pages.size():
		_pages[i].visible = (i == index)
	if _search:
		_search.text = ""
	_on_search_text_changed("")


# ─── Búsqueda ───────────────────────────────────────────────────────────────

func _on_search_text_changed(text: String) -> void:
	var query := text.to_lower().strip_edges()
	for page in _pages:
		if page.visible:
			_filter_page(page, query)


func _filter_page(page: VBoxContainer, query: String) -> void:
	for panel in page.get_children():
		var any_visible := false
		for row in _rows_in(panel):
			var shown := query.is_empty() or _row_label(row).to_lower().contains(query)
			row.visible = shown
			any_visible = any_visible or shown
		if panel is CanvasItem:
			panel.visible = any_visible


func _row_label(row: Node) -> String:
	var lt = row.get("label_text")
	if lt != null:
		return str(lt)
	var lbl := row.get_node_or_null("Label")
	return lbl.text if lbl else ""


## Un panel envuelve directamente una fila suelta (ej. una única opción de
## ciclo) o un VBoxContainer con varias filas agrupadas, como en Sodium.
func _rows_in(panel: Node) -> Array:
	if panel.get_child_count() == 0:
		return []
	var inner: Node = panel.get_child(0)
	if inner is VBoxContainer:
		return inner.get_children()
	return [inner]


func _all_rows() -> Array:
	var rows: Array = []
	for page in _pages:
		for panel in page.get_children():
			rows.append_array(_rows_in(panel))
	return rows


# ─── Lectura/escritura genérica de filas ────────────────────────────────────
# Soporta los 3 tipos de fila usados en la escena: SliderRow, CycleRow y el
# CheckBox simple (fila HBoxContainer "Label" + "Check", sin script).

func _get_row_state(row: Node) -> Variant:
	if row.has_method("set_value"):
		return row.get_value()
	if row.has_method("set_selected_index"):
		return row.selected_index
	var chk := row.get_node_or_null("Check")
	if chk is CheckBox:
		return chk.button_pressed
	return null


func _set_row_state(row: Node, value: Variant) -> void:
	if value == null:
		return
	if row.has_method("set_value"):
		row.set_value(float(value))
	elif row.has_method("set_selected_index"):
		row.set_selected_index(int(value))
	else:
		var chk := row.get_node_or_null("Check")
		if chk is CheckBox:
			chk.button_pressed = bool(value)


# ─── Restablecer ────────────────────────────────────────────────────────────

func _store_defaults() -> void:
	_default_snapshot.clear()
	for row in _all_rows():
		_default_snapshot[row.name] = _get_row_state(row)


func _on_reset_pressed() -> void:
	for row in _all_rows():
		if _default_snapshot.has(row.name):
			_set_row_state(row, _default_snapshot[row.name])


# ─── Aplicar / Guardar / Cargar ─────────────────────────────────────────────

func _on_apply_pressed() -> void:
	pass


func _on_done_pressed() -> void:
	TransitionManager.transition(0.5, 0.3, 0.5, func():
		get_tree().change_scene_to_file(MAIN_MENU_PATH))


## Efectos con integración real ya disponible en el proyecto: volumen general
## (bus "Master") y modo de ventana. El resto de opciones (música/efectos,
## dificultad de IA, duración de ronda, etc.) quedan guardadas y accesibles
## vía _all_rows()/_get_row_state() para conectarse a sus sistemas cuando
## existan (buses de audio dedicados, ajustes de FightManager, etc.), sin
## tener que tocar esta escena.
func _apply_live_effects() -> void:
	if _master_volume_row:
		var bus_idx := AudioServer.get_bus_index("Master")
		if bus_idx >= 0:
			var v: float = clampf(_master_volume_row.get_value(), 0.0001, 1.0)
			AudioServer.set_bus_volume_db(bus_idx, linear_to_db(v))
	if _window_mode_row:
		var target_mode: DisplayServer.WindowMode
		var target_borderless: bool
		match _window_mode_row.get_value():
			"Pantalla completa":
				target_mode = DisplayServer.WINDOW_MODE_FULLSCREEN
				target_borderless = false
			"Sin bordes":
				target_mode = DisplayServer.WINDOW_MODE_WINDOWED
				target_borderless = true
			_:
				target_mode = DisplayServer.WINDOW_MODE_WINDOWED
				target_borderless = false
		var current_mode := DisplayServer.window_get_mode()
		var current_borderless := DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_BORDERLESS)
		if current_mode != target_mode or current_borderless != target_borderless:
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, target_borderless)
			DisplayServer.window_set_mode(target_mode)


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	for row in _all_rows():
		cfg.set_value(SAVE_SECTION, row.name, _get_row_state(row))
	cfg.save(SAVE_PATH)


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	for row in _all_rows():
		if cfg.has_section_key(SAVE_SECTION, row.name):
			_set_row_state(row, cfg.get_value(SAVE_SECTION, row.name))
