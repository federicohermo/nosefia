## Paso de Godot del generador de la variante. El SVG es la entrada editable del arte.
## Se invoca con .claude/scripts/blender/generar_cindolor_vencido.py.
extends SceneTree

const ORIGINAL := "res://assets/models/producto_cindolor.res"
const VARIANTE := "res://assets/models/producto_cindolor_vencido.res"
const TEXTURA_BASE := "res://assets/models/SEPT_JUEGOS_PROTOTIPO_cindolor completo.png"
const TEXTURA := "res://assets/models/cindolor_vencido.png"
const MARCA := "res://assets/source/products-cam/cindolor/vencimiento.svg"
## Coordenadas normalizadas dentro de la isla UV del dorso. No alcanzan sus costuras.
const POSICION := Vector2(0.695, 0.52)
const ANCHO := 0.285


func _initialize() -> void:
	var argumentos := OS.get_cmdline_user_args()
	if "--textura" in argumentos:
		quit(_textura())
	elif "--malla" in argumentos:
		quit(_malla())
	elif "--comprobar" in argumentos:
		quit(_comprobar())
	else:
		push_error("Elegir --textura, --malla o --comprobar")
		quit(1)


func _textura() -> int:
	var base := Image.load_from_file(ProjectSettings.globalize_path(TEXTURA_BASE))
	var marca := Image.new()
	if base == null or marca.load_svg_from_string(FileAccess.get_file_as_string(MARCA)) != OK:
		return 1
	var ancho := roundi(base.get_width() * ANCHO)
	marca.resize(ancho, roundi(ancho * float(marca.get_height()) / marca.get_width()))
	base.convert(Image.FORMAT_RGBA8)
	marca.convert(Image.FORMAT_RGBA8)
	base.blend_rect(
		marca,
		Rect2i(Vector2i.ZERO, marca.get_size()),
		Vector2i(roundi(base.get_width() * POSICION.x), roundi(base.get_height() * POSICION.y))
	)
	var error := base.save_png(TEXTURA)
	if error != OK:
		return error
	# El mismo frente debe atravesar también la misma compresión y el mismo filtrado.
	var origen := ConfigFile.new()
	var destino := ConfigFile.new()
	if origen.load(TEXTURA_BASE + ".import") != OK:
		return 1
	if FileAccess.file_exists(TEXTURA + ".import"):
		destino.load(TEXTURA + ".import")
	destino.set_value("remap", "importer", "texture")
	destino.set_value("remap", "type", "CompressedTexture2D")
	for clave in origen.get_section_keys("params"):
		destino.set_value("params", clave, origen.get_value("params", clave))
	return destino.save(TEXTURA + ".import")


func _malla() -> int:
	var base := load(ORIGINAL) as ArrayMesh
	var textura := load(TEXTURA) as Texture2D
	if base == null or textura == null:
		return 1
	var variante := base.duplicate() as ArrayMesh
	for indice in variante.get_surface_count():
		var material := base.surface_get_material(indice) as StandardMaterial3D
		if material == null:
			push_error("La fuente necesita un material estándar por superficie")
			return 1
		var copia := material.duplicate() as StandardMaterial3D
		copia.albedo_texture = textura
		variante.surface_set_material(indice, copia)
	return ResourceSaver.save(variante, VARIANTE)


## Compara relaciones con la fuente actual: no fija cantidades ni valores del artista.
static func diferencias(base: ArrayMesh, variante: ArrayMesh) -> PackedStringArray:
	var errores := PackedStringArray()
	if base.get_surface_count() != variante.get_surface_count():
		return PackedStringArray(["superficies"])
	for indice in base.get_surface_count():
		if base.surface_get_arrays(indice) != variante.surface_get_arrays(indice):
			errores.append("geometría o UV")
		if base.surface_get_primitive_type(indice) != variante.surface_get_primitive_type(indice):
			errores.append("primitiva")
		var material := base.surface_get_material(indice) as StandardMaterial3D
		var copia := variante.surface_get_material(indice) as StandardMaterial3D
		if material == null or copia == null or material == copia:
			errores.append("material independiente")
			continue
		for propiedad: Dictionary in material.get_property_list():
			var nombre: String = propiedad.name
			if not (int(propiedad.usage) & PROPERTY_USAGE_STORAGE):
				continue
			if nombre in ["albedo_texture", "resource_name", "resource_local_to_scene"]:
				continue
			if material.get(nombre) != copia.get(nombre):
				errores.append("material: " + nombre)
		if copia.albedo_texture == null or material.albedo_texture == null:
			errores.append("textura ausente")
		elif copia.albedo_texture.get_size() != material.albedo_texture.get_size():
			errores.append("dimensiones de textura")
		elif copia.albedo_texture.resource_path == material.albedo_texture.resource_path:
			errores.append("textura sin variante")
	return errores


func _comprobar() -> int:
	var base := load(ORIGINAL) as ArrayMesh
	var variante := load(VARIANTE) as ArrayMesh
	if base == null or variante == null:
		return 1
	var errores := diferencias(base, variante)
	var importacion_base := ConfigFile.new()
	var importacion_variante := ConfigFile.new()
	if importacion_base.load(TEXTURA_BASE + ".import") != OK:
		return 1
	if importacion_variante.load(TEXTURA + ".import") != OK:
		return 1
	for clave in importacion_base.get_section_keys("params"):
		if (
			importacion_base.get_value("params", clave)
			!= importacion_variante.get_value("params", clave)
		):
			errores.append("importación: " + clave)
	if not errores.is_empty():
		push_error(str(errores))
		return 1
	if not _testigos(base, variante):
		return 1
	print("estructura y testigos: OK")
	return 0


static func _testigos(base: ArrayMesh, variante: ArrayMesh) -> bool:
	# Testigos en memoria: demuestran que la comprobación rechaza pérdidas reales.
	var rota := variante.duplicate() as ArrayMesh
	rota.clear_surfaces()
	if diferencias(base, rota).is_empty():
		return false
	rota = variante.duplicate() as ArrayMesh
	var material := variante.surface_get_material(0).duplicate() as StandardMaterial3D
	material.shading_mode = (material.shading_mode + 1) % 3
	rota.surface_set_material(0, material)
	if diferencias(base, rota).is_empty():
		return false
	material = variante.surface_get_material(0).duplicate() as StandardMaterial3D
	material.albedo_texture = null
	rota.surface_set_material(0, material)
	return not diferencias(base, rota).is_empty()
