extends SceneTree

const CARPETA_COMPRADORES: String = "res://assets/characters"
const LIMITE_RESIDUO: int = 3
const LIMITE_ISLA: int = 13


func _initialize() -> void:
	var aplicar: bool = "--aplicar" in OS.get_cmdline_user_args()
	var directorio: DirAccess = DirAccess.open(CARPETA_COMPRADORES)
	if directorio == null:
		push_error("No se puede abrir " + CARPETA_COMPRADORES)
		quit(1)
		return
	var carpetas: PackedStringArray = directorio.get_directories()
	carpetas.sort()
	var rutas: PackedStringArray = []
	for nombre: String in carpetas:
		var carpeta: String = CARPETA_COMPRADORES.path_join(nombre)
		if not FileAccess.file_exists(carpeta.path_join("idle.tres")):
			continue
		var archivos: PackedStringArray = DirAccess.get_files_at(carpeta)
		archivos.sort()
		for archivo: String in archivos:
			if archivo.get_extension().to_lower() == "png":
				rutas.append(carpeta.path_join(archivo))
	if rutas.is_empty():
		push_error("No se encontraron PNG de compradores junto a idle.tres.")
		quit(1)
		return
	var total_pixeles: int = 0
	var total_imagenes: int = 0
	for ruta: String in rutas:
		var imagen: Image = Image.new()
		var error: Error = imagen.load(ProjectSettings.globalize_path(ruta))
		if error != OK:
			push_error("No se puede cargar %s. Error %d." % [ruta, error])
			quit(1)
			return
		if imagen.get_format() != Image.FORMAT_RGBA8:
			push_error("Se esperaba RGBA8 en " + ruta)
			quit(1)
			return
		var datos: PackedByteArray = imagen.get_data()
		var pixeles: int = 0
		for indice: int in range(3, datos.size(), 4):
			if datos[indice] > 0 and datos[indice] <= LIMITE_RESIDUO:
				datos[indice] = 0
				pixeles += 1
		pixeles += _limpiar_islas(datos, imagen.get_width(), imagen.get_height())
		if pixeles > 0:
			total_imagenes += 1
			if aplicar:
				imagen.set_data(
					imagen.get_width(), imagen.get_height(), false, Image.FORMAT_RGBA8, datos
				)
				error = imagen.save_png(ruta)
				if error != OK:
					push_error("No se puede guardar %s. Error %d." % [ruta, error])
					quit(1)
					return
		total_pixeles += pixeles
		print("%s. Píxeles con alfa residual %d." % [ruta, pixeles])
	print(
		(
			"%s. %d PNG revisados, %d con residuos, %d píxeles."
			% [
				"Aplicado" if aplicar else "Sólo informe",
				rutas.size(),
				total_imagenes,
				total_pixeles
			]
		)
	)
	quit()


func _limpiar_islas(datos: PackedByteArray, ancho: int, alto: int) -> int:
	var visitados: PackedByteArray = []
	visitados.resize(ancho * alto)
	var eliminados: int = 0
	for inicio: int in range(ancho * alto):
		var alfa: int = datos[inicio * 4 + 3]
		if visitados[inicio] != 0 or alfa == 0 or alfa > LIMITE_ISLA:
			continue
		var componente: PackedInt32Array = [inicio]
		visitados[inicio] = 1
		var cursor: int = 0
		var toca_figura: bool = false
		while cursor < componente.size():
			var pixel: int = componente[cursor]
			cursor += 1
			var x: int = pixel % ancho
			var y: int = pixel / ancho
			for vecino_y: int in range(maxi(0, y - 1), mini(alto, y + 2)):
				for vecino_x: int in range(maxi(0, x - 1), mini(ancho, x + 2)):
					var vecino: int = vecino_y * ancho + vecino_x
					var alfa_vecino: int = datos[vecino * 4 + 3]
					if alfa_vecino > LIMITE_ISLA:
						toca_figura = true
					elif alfa_vecino > 0 and visitados[vecino] == 0:
						visitados[vecino] = 1
						componente.append(vecino)
		if not toca_figura:
			for pixel: int in componente:
				datos[pixel * 4 + 3] = 0
			eliminados += componente.size()
	return eliminados
