extends SceneTree
## Analiza el spritesheet de Goku y calcula los Rect2 centrados para cada frame.
## Ejecutar: godot --headless -s tools/center_frames.gd

const GRID_W := 170
const GRID_H := 92
const COLS := 10
const ROWS := 13
const TOTAL := 121

const SPRITESHEET := "res://characters/goku/forms/spritesheet.png"


func _init() -> void:
	var tex: Texture2D = load(SPRITESHEET)
	if tex == null:
		print("No se pudo cargar ", SPRITESHEET)
		quit(1)
		return
	var img: Image = tex.get_image()
	if img == null:
		print("No se pudo obtener la imagen")
		quit(1)
		return

	print("# Frames centrados (Rect2):")
	print("# idx | frame | col | row | rect")
	for i in TOTAL:
		var col := i % COLS
		var row := i / COLS
		var cell_x := col * GRID_W
		var cell_y := row * GRID_H
		var bbox := _find_bbox(img, cell_x, cell_y, GRID_W, GRID_H)
		if bbox == Rect2i():
			# Sprite vacío
			print("# frame %d: vacío" % (i + 1))
			continue
		# Centro del sprite real vs centro de la celda
		var sprite_cx := bbox.position.x + bbox.size.x / 2.0
		var sprite_cy := bbox.position.y + bbox.size.y / 2.0
		var cell_cx := cell_x + GRID_W / 2.0
		var cell_cy := cell_y + GRID_H / 2.0
		# Rect2 centrado: mismo tamaño de celda, desplazado para que el sprite quede al centro
		var off_x := sprite_cx - cell_cx
		var off_y := sprite_cy - cell_cy
		var rx := cell_x + off_x
		var ry := cell_y + off_y
		print("# frame %d: Rect2(%d, %d, %d, %d)  bbox=(%d,%d,%d,%d) off=(%.1f,%.1f)" % [
			i + 1, int(rx), int(ry), GRID_W, GRID_H,
			bbox.position.x, bbox.position.y, bbox.size.x, bbox.size.y,
			off_x, off_y
		])
	quit()


func _find_bbox(img: Image, cx: int, cy: int, cw: int, ch: int) -> Rect2i:
	var min_x := cw
	var min_y := ch
	var max_x := 0
	var max_y := 0
	var found := false
	for y in range(cy, cy + ch):
		for x in range(cx, cx + cw):
			if x < 0 or x >= img.get_width() or y < 0 or y >= img.get_height():
				continue
			var c := img.get_pixel(x, y)
			if c.a > 0.1:
				found = true
				if x < min_x:
					min_x = x
				if y < min_y:
					min_y = y
				if x > max_x:
					max_x = x
				if y > max_y:
					max_y = y
	if not found:
		return Rect2i()
	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)
