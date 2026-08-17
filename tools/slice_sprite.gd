extends SceneTree
## Slicer de hojas de sprites — dos modos:
##   1) Detección automática (con ruido, sin grid)
##   2) Grid fijo (sin gaps, orden conocido)
## Uso:
##   godot --headless -s tools/slice_sprite.gd -- <hoja> [destino]
##   godot --headless -s tools/slice_sprite.gd -- <hoja> [destino] --grid 65x75 10

const MIN_FRAME := 8
const BAND_GAP := 3


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("Uso: -- <hoja> [destino] [--grid WxH COLS]")
		quit(1)
		return
	var img := Image.load_from_file(args[0])
	if img == null:
		push_error("No se pudo cargar: " + args[0])
		quit(1)
		return
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	var export_dir := ProjectSettings.globalize_path(args[1]) if args.size() > 1 else ""
	# Detectar modo grid
	var grid_mode := false
	var cell_w := 0
	var cell_h := 0
	var cols := 0
	for i in range(args.size()):
		if args[i] == "--grid" and i + 2 < args.size():
			grid_mode = true
			var dims: PackedStringArray = args[i + 1].split("x")
			cell_w = int(dims[0])
			cell_h = int(dims[1])
			cols = int(args[i + 2])
			break
	if grid_mode:
		print("GRID ", args[0], " ", w, "x", h, "  celda=", cell_w, "x", cell_h, "  cols=", cols)
		if export_dir != "":
			DirAccess.make_dir_recursive_absolute(export_dir)
			var n := _crop_grid(img, w, h, cell_w, cell_h, cols, export_dir)
			print("Listo: ", n, " sprites")
		else:
			var rows := ceili(h / float(cell_h))
			var total := cols * rows
			print("  filas=", rows, "  celdas=", total)
	else:
		print("HOJA ", args[0], " ", w, "x", h, "  gap=", BAND_GAP)
		if export_dir != "":
			var bands := _bands(img, w, h, BAND_GAP)
			for i in bands.size():
				var y0: int = bands[i][0]
				var y1: int = bands[i][1]
				print("BANDA ", i + 1, " y=", y0, "..", y1)
				var folder := export_dir + "/band_%02d" % (i + 1)
				DirAccess.make_dir_recursive_absolute(folder)
				var n := _crop_band(img, w, y0, y1, folder, "band_%02d" % (i + 1))
				print("  -> ", n, " sprites")
			print("Listo. Renombra carpetas y ejecuta build_character_data.gd")
		else:
			var bands := _bands(img, w, h, BAND_GAP)
			for i in bands.size():
				var y0: int = bands[i][0]
				var y1: int = bands[i][1]
				print("BANDA ", i + 1, " y=", y0, "..", y1)
	quit(0)


func _crop_grid(img: Image, w: int, h: int, cell_w: int, cell_h: int, cols: int, folder: String) -> int:
	var rows := ceili(h / float(cell_h))
	var n := 0
	for row in rows:
		for col in cols:
			var x0 := col * cell_w
			var y0 := row * cell_h
			var x1 := mini(x0 + cell_w - 1, w - 1)
			var y1 := mini(y0 + cell_h - 1, h - 1)
			# Skip empty cells
			var has_opaque := false
			for y in range(y0, y1 + 1):
				for x in range(x0, x1 + 1):
					if _opaque(img, x, y):
						has_opaque = true
						break
				if has_opaque:
					break
			if not has_opaque:
				continue
			# Tight crop within cell
			_save_frame(img, x0, x1, y0, y1, folder, "frame_%03d" % (n + 1))
			n += 1
	return n


func _opaque(img: Image, x: int, y: int) -> bool:
	return img.get_pixel(x, y).a > 0.15


func _bands(img: Image, w: int, h: int, gap: int) -> Array:
	var rows: Array = []
	for y in h:
		var has := false
		for x in w:
			if _opaque(img, x, y):
				has = true
				break
		rows.append(has)
	var bands: Array = []
	var start := -1
	var empty_run := 0
	for y in h:
		if rows[y]:
			empty_run = 0
			if start == -1:
				start = y
		elif start != -1:
			empty_run += 1
			if empty_run >= gap:
				bands.append([start, y - gap])
				start = -1
	if start != -1:
		bands.append([start, h - 1])
	return bands


func _crop_band(img: Image, w: int, y0: int, y1: int, folder: String, prefix: String) -> int:
	# 1. Contar píxeles opacos por columna
	var counts: Array = []
	var peak := 0
	for x in w:
		var c := 0
		for y in range(y0, y1 + 1):
			if _opaque(img, x, y):
				c += 1
		counts.append(c)
		peak = maxi(peak, c)
	if peak == 0:
		return 0
	# 2. Umbral adaptativo: columnas por debajo del umbral = separación entre sprites
	var thresh := maxi(3, int(peak * 0.10))
	# 3. Encontrar segmentos: corridas de columnas con count > thresh
	var segments: Array = []
	var seg_start := -1
	for x in w:
		if counts[x] > thresh:
			if seg_start == -1:
				seg_start = x
		else:
			if seg_start != -1:
				segments.append([seg_start, x - 1])
				seg_start = -1
	if seg_start != -1:
		segments.append([seg_start, w - 1])
	# 4. Dentro de cada segmento, buscar pinch points internos
	var final_segments: Array = []
	for seg in segments:
		var sx: int = seg[0]
		var ex: int = seg[1]
		if ex - sx + 1 < MIN_FRAME:
			continue
		# Buscar columnas con count <= thresh rodeadas de columnas altas
		var splits: Array = [sx]
		for x in range(sx + 1, ex):
			if counts[x] <= thresh:
				# Es pinch point si ambos vecinos son altos
				if counts[x - 1] > thresh and x + 1 <= ex and counts[x + 1] > thresh:
					splits.append(x)
		splits.append(ex + 1)
		for j in range(splits.size() - 1):
			var sub_start: int = splits[j]
			var sub_end: int = splits[j + 1] - 1
			if sub_end - sub_start + 1 >= MIN_FRAME:
				final_segments.append([sub_start, sub_end])
	# 5. Recortar cada segmento
	var n := 0
	for seg in final_segments:
		var sx: int = seg[0]
		var ex: int = seg[1]
		_save_frame(img, sx, ex, y0, y1, folder, "%s_%03d" % [prefix, n + 1])
		n += 1
	return n


func _save_frame(img: Image, x0: int, x1: int, y0: int, y1: int, folder: String, name: String) -> void:
	var minx := x1
	var maxx := x0
	var miny := y1
	var maxy := y0
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			if _opaque(img, x, y):
				minx = mini(minx, x)
				maxx = maxi(maxx, x)
				miny = mini(miny, y)
				maxy = maxi(maxy, y)
	var bw := maxx - minx + 1
	var bh := maxy - miny + 1
	if bw < MIN_FRAME or bh < MIN_FRAME:
		return
	var crop := img.get_region(Rect2(minx, miny, bw, bh))
	crop.save_png(folder + "/" + name + ".png")
	print("  ", name, "  ", bw, "x", bh, "  Rect2(", minx, ",", miny, ")")
