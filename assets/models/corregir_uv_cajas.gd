## Ajusta las seis caras al atlas de las etiquetas, sin repetir fuera de sus islas.
##
## godot --headless --path . --script assets/models/corregir_uv_cajas.gd -- \
##     res://assets/models/caja_de_productos.res
extends SceneTree

const MALLA := "res://assets/models/caja_de_productos.res"
## Tres píxeles del atlas importado evitan tomar el negro vecino con los mipmaps.
const MARGEN := 3.0 / 512.0


func _initialize() -> void:
	var fuente: Mesh = load(MALLA)
	var salida := corregida(fuente)
	var argumentos := OS.get_cmdline_user_args()
	assert(argumentos.size() == 1, "Indicar el recurso de salida después de --")
	var destino := argumentos[0]
	assert(salida.get_aabb() == fuente.get_aabb())
	for superficie in fuente.get_surface_count():
		var antes := fuente.surface_get_arrays(superficie)
		var despues := salida.surface_get_arrays(superficie)
		for atributo in Mesh.ARRAY_MAX:
			if atributo != Mesh.ARRAY_TEX_UV:
				assert(antes[atributo] == despues[atributo], "Sólo deben cambiar las UV")
	assert(ResourceSaver.save(salida, destino) == OK)
	print("UV_CORREGIDAS ", destino)
	quit()


static func corregida(fuente: Mesh) -> ArrayMesh:
	var salida := ArrayMesh.new()
	salida.resource_name = fuente.resource_name
	salida.lightmap_size_hint = fuente.lightmap_size_hint
	var superficies: Array = fuente.get("_surfaces")
	for superficie in fuente.get_surface_count():
		var datos := fuente.surface_get_arrays(superficie)
		var vertices: PackedVector3Array = datos[Mesh.ARRAY_VERTEX]
		var normales: PackedVector3Array = datos[Mesh.ARRAY_NORMAL]
		var uvs: PackedVector2Array = datos[Mesh.ARRAY_TEX_UV]
		var limites := fuente.get_aabb()
		for i in vertices.size():
			var p := (vertices[i] - limites.position) / limites.size
			var n := normales[i]
			var uv: Vector2
			if absf(n.x) > 0.9:
				uv = Vector2(0.25 + (1.0 - p.z if n.x > 0 else p.z) * 0.5, 0.25 + (1.0 - p.y) * 0.5)
			elif absf(n.z) > 0.9:
				uv = Vector2(
					0.75 + (1.0 - p.x) * 0.25 if n.z < 0 else p.x * 0.25, 0.25 + (1.0 - p.y) * 0.5
				)
			else:
				uv = Vector2(
					0.25 + (1.0 - p.z) * 0.5, (1.0 - p.x) * 0.25 if n.y > 0 else 0.75 + p.x * 0.25
				)
			var origen := Vector2(0.25, 0.25)
			var tamano := Vector2(0.5, 0.5)
			if absf(n.z) > 0.9:
				origen.x = 0.75 if n.z < 0 else 0.0
				tamano.x = 0.25
			elif absf(n.y) > 0.9:
				origen.y = 0.0 if n.y > 0 else 0.75
				tamano.y = 0.25
			uvs[i] = (
				origen
				+ Vector2.ONE * MARGEN
				+ (uv - origen) / tamano * (tamano - Vector2.ONE * MARGEN * 2.0)
			)
		# Reconstruir desde arrays recuantiza las normales. Se cambia sólo el buffer de UV;
		# los vértices, índices, normales y materiales conservan sus bytes originales.
		var cruda: Dictionary = superficies[superficie]
		var formato: int = cruda.format
		assert((formato & Mesh.ARRAY_FLAG_COMPRESS_ATTRIBUTES) == 0)
		var paso := RenderingServer.mesh_surface_get_format_attribute_stride(
			formato, vertices.size()
		)
		var inicio := RenderingServer.mesh_surface_get_format_offset(
			formato, vertices.size(), Mesh.ARRAY_TEX_UV
		)
		var atributos: PackedByteArray = cruda.attribute_data
		for i in uvs.size():
			atributos.encode_float(inicio + i * paso, uvs[i].x)
			atributos.encode_float(inicio + i * paso + 4, uvs[i].y)
		cruda.attribute_data = atributos
	salida.set("_surfaces", superficies)
	return salida
