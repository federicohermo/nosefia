## Vuelca a JSON y binario lo que el visor de Three.js necesita, leÃƒÂ­do de las escenas reales.
##
##   & $env:GODOT_BIN --headless --path . --script res://build/prototipo-threejs/tools/volcar.gd
##
## - Estructura: cada malla con su transformaciÃƒÂ³n, sus materiales y su geometrÃƒÂ­a con UV2.
## - Productos: la malla de cada producto con su base horneada, la disposiciÃƒÂ³n y las copias que
##   el juego dibuja (fila de adelante de cada tanda), con el mismo reajuste de base que hace
##   `reposicion_manual.gd`.
## - Luces y entorno de `ambiente_del_almacen.tscn` y `estructura_del_almacen.tscn`.
## - El atlas del lightmap: la primera pÃƒÂ¡gina del EXR, en mitades flotantes.
extends SceneTree

var SALIDA := OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "res://build/prototipo-threejs/datos/"
const MODELO := "res://assets/models/SEPT_JUEGOS_PROTOTIPO.glb"
const ESTRUCTURA := "res://src/escenas/puestos/estructura_del_almacen.tscn"
const AMBIENTE := "res://src/escenas/puestos/ambiente_del_almacen.tscn"
const CONTENIDO := "res://src/escenas/puestos/contenido_del_estante.tscn"
const REPOSICION := "res://src/escenas/puestos/reposicion_manual.tscn"
const DISPOSICION := "res://src/escenas/puestos/disposicion_de_la_gondola.tres"
const ATLAS := "res://src/escenas/almacen.exr"

var _bytes := PackedByteArray()
var _mallas := {}
var _materiales := {}
var _texturas := {}
var _dibujos: Array = []


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SALIDA))
	var estructura := (load(ESTRUCTURA) as PackedScene).instantiate()
	_volcar_estructura(estructura)
	var ambiente := (load(AMBIENTE) as PackedScene).instantiate()
	_volcar_ambiente(ambiente)
	var productos := _volcar_productos()
	_volcar_atlas()
	var documento := {
		"dibujos": _dibujos,
		"mallas": _mallas,
		"materiales": _materiales,
		"texturas": _texturas,
		"productos": productos,
		"luces": _luces,
		"entorno": _entorno,
		"cajas": _cajas,
		"geometria_bytes": _bytes.size(),
	}
	var archivo := FileAccess.open(SALIDA + "escena.json", FileAccess.WRITE)
	archivo.store_string(JSON.stringify(documento))
	archivo.close()
	var bin := FileAccess.open(SALIDA + "geometria.bin", FileAccess.WRITE)
	bin.store_buffer(_bytes)
	bin.close()
	print(
		"dibujos ", _dibujos.size(),
		" mallas ", _mallas.size(),
		" materiales ", _materiales.size(),
		" texturas ", _texturas.size(),
		" bytes ", _bytes.size()
	)
	quit()


func _volcar_estructura(raiz: Node) -> void:
	_volcar_luces_de(raiz)
	var lista: Array[MeshInstance3D] = []
	_recorrer(raiz, lista)
	for nodo in lista:
		var ruta := str(raiz.get_path_to(nodo))
		_dibujos.append(_dibujo_de(nodo, _mundo(nodo), ruta, nodo.visible))
	_cajas = _cajas_de(raiz)


var _luces: Array = []
var _entorno := {}
var _cajas := {}


## Las cajas que necesita una cÃƒÂ¡mara para encuadrar: mostrador, gÃƒÂ³ndolas, heladeras y pasillo.
func _cajas_de(raiz: Node) -> Dictionary:
	var salida := {}
	for nodo in raiz.find_children("*", "Node3D", true, false):
		var nombre := str(nodo.name)
		if nodo is MeshInstance3D and (nodo as MeshInstance3D).mesh != null:
			var caja: AABB = _mundo(nodo as MeshInstance3D) * (nodo as MeshInstance3D).mesh.get_aabb()
			salida[ruta_de(raiz, nodo)] = [
				caja.position.x, caja.position.y, caja.position.z,
				caja.end.x, caja.end.y, caja.end.z,
			]
	return salida


func ruta_de(raiz: Node, nodo: Node) -> String:
	return str(raiz.get_path_to(nodo))


func _volcar_ambiente(ambiente: Node) -> void:
	for nodo in ambiente.find_children("*", "Light3D", true, false):
		_luces.append(_luz_de(nodo as Light3D))
	for nodo in get_root().find_children("Almacen", "Node3D", true, false):
		pass
	for nodo in ambiente.find_children("*", "WorldEnvironment", true, false):
		var entorno: Environment = (nodo as WorldEnvironment).environment
		_entorno = {
			"fondo": _color(entorno.background_color),
			"fondo_modo": entorno.background_mode,
			"ambiente_fuente": entorno.ambient_light_source,
			"ambiente_color": _color(entorno.ambient_light_color),
			"ambiente_energia": entorno.ambient_light_energy,
			"ambiente_cielo": entorno.ambient_light_sky_contribution,
			"reflejo_fuente": entorno.reflected_light_source,
			"tono": entorno.tonemap_mode,
			"tono_exposicion": entorno.tonemap_exposure,
			"niebla": entorno.fog_enabled,
			"niebla_color": _color(entorno.fog_light_color),
			"niebla_energia": entorno.fog_light_energy,
			"niebla_densidad": entorno.fog_density,
			"niebla_inicio": entorno.fog_depth_begin,
			"niebla_fin": entorno.fog_depth_end,
			"niebla_curva": entorno.fog_depth_curve,
			"saturacion": entorno.adjustment_saturation,
			"brillo": entorno.adjustment_brightness,
			"contraste": entorno.adjustment_contrast,
			"ajustes": entorno.adjustment_enabled,
			"glow": entorno.glow_enabled,
		}


## Las luces de la estructura (heladeras) se suman a las del ambiente, sin repetir.
func _volcar_luces_de(raiz: Node) -> void:
	for nodo in raiz.find_children("*", "Light3D", true, false):
		var luz := _luz_de(nodo as Light3D)
		luz["ruta"] = ruta_de(raiz, nodo)
		_luces.append(luz)


func _luz_de(luz: Light3D) -> Dictionary:
	var t := _mundo(luz)
	var salida := {
		"tipo": luz.get_class(),
		"transform": _transform(t),
		"color": _color(luz.light_color),
		"energia": luz.light_energy,
		"indirecta": luz.light_indirect_energy,
		"tamano": luz.light_size,
		"horneado": luz.light_bake_mode,
		"sombra": luz.shadow_enabled,
		"especular": luz.light_specular,
	}
	if luz is OmniLight3D:
		salida["rango"] = (luz as OmniLight3D).omni_range
		salida["atenuacion"] = (luz as OmniLight3D).omni_attenuation
	if luz is SpotLight3D:
		var foco := luz as SpotLight3D
		salida["rango"] = foco.spot_range
		salida["angulo"] = foco.spot_angle
		salida["atenuacion"] = foco.spot_attenuation
		salida["angulo_atenuacion"] = foco.spot_angle_attenuation
	if luz.get_class() == "AreaLight3D":
		var tam: Vector2 = luz.get("area_size")
		salida["area_tamano"] = [tam.x, tam.y]
		salida["area_rango"] = luz.get("area_range")
		salida["area_atenuacion"] = luz.get("area_attenuation")
		salida["area_normalizar"] = luz.get("area_normalize_energy")
	if luz is DirectionalLight3D:
		salida["energia_sombra"] = (luz as DirectionalLight3D).directional_shadow_max_distance
	return salida


func _volcar_productos() -> Array:
	var contenido := (load(CONTENIDO) as PackedScene).instantiate()
	var reposicion := (load(REPOSICION) as PackedScene).instantiate()
	var guia := reposicion.get_node_or_null("Guia")
	var disposicion: Resource = load(DISPOSICION)
	var productos: Array = []
	var bases: Dictionary = {}
	for nodo in contenido.get_children():
		var malla_nodo := nodo as MeshInstance3D
		if malla_nodo == null or malla_nodo.mesh == null:
			continue
		var id: int = malla_nodo.get_meta("producto_id")
		var base := _mundo(malla_nodo).basis
		var hija := _malla_con_la_vuelta(malla_nodo.mesh, base)
		productos.append({
			"id": id,
			"nombre": str(malla_nodo.name),
			"malla": _registrar_malla(hija, "producto:%d" % id),
			"materiales": _materiales_de_la_malla(hija),
			"base": _basis(base),
			"aabb": _aabb((hija as Mesh).get_aabb()),
		})
		bases[id] = base
	var principales: Array = disposicion.get("principales")
	var guias: Array = disposicion.get("guias")
	var filas: PackedInt32Array = disposicion.get("filas_de_adelante")
	var productos_de_las_guias: PackedInt32Array = disposicion.get("productos_de_las_guias")
	var filas_guias: PackedInt32Array = disposicion.get("filas_de_adelante_de_las_guias")
	var frente := []
	for id in productos.size():
		var bloque: PackedFloat32Array = principales[id]
		var cuantas := bloque.size() / 12
		var atras: int = cuantas - filas[id]
		frente.append({
			"id": id,
			"principal": _copias(_trozo(bloque, atras)),
			"guias": [],
		})
	for indice in guias.size():
		var id := productos_de_las_guias[indice]
		var bloque: PackedFloat32Array = guias[indice]
		var desde := _mundo(guia.get_child(indice) as MeshInstance3D).basis
		var hacia: Basis = bases[id]
		var cambio := desde * hacia.inverse()
		var cuantas := bloque.size() / 12
		var atras: int = cuantas - filas_guias[indice]
		var rebanada := _trozo(bloque, atras)
		frente[id]["guias"].append_array(_copias(_rebasar(rebanada, cambio)))
	for id in productos.size():
		productos[id]["principal"] = frente[id]["principal"]
		productos[id]["guias"] = frente[id]["guias"]
	var total := 0
	for producto: Dictionary in productos:
		total += producto["principal"].size() + producto["guias"].size()
	print("copias de productos: ", total)
	return productos


## Las copias de un bloque pasado a la base del producto dibujado.
func _rebasar(bloque: PackedFloat32Array, cambio: Basis) -> PackedFloat32Array:
	var salida := PackedFloat32Array()
	for indice in bloque.size() / 12:
		var t := _copia(bloque, indice)
		var b := t.basis * cambio
		var o := t.origin
		salida.append_array([b.x.x, b.y.x, b.z.x, o.x, b.x.y, b.y.y, b.z.y, o.y, b.x.z, b.y.z, b.z.z, o.z])
	return salida


func _trozo(bloque: PackedFloat32Array, desde: int) -> PackedFloat32Array:
	return bloque.slice(desde * 12)


func _copia(bloque: PackedFloat32Array, indice: int) -> Transform3D:
	var d := indice * 12
	return Transform3D(
		Vector3(bloque[d + 0], bloque[d + 4], bloque[d + 8]),
		Vector3(bloque[d + 1], bloque[d + 5], bloque[d + 9]),
		Vector3(bloque[d + 2], bloque[d + 6], bloque[d + 10]),
		Vector3(bloque[d + 3], bloque[d + 7], bloque[d + 11])
	)


func _copias(bloque: PackedFloat32Array) -> Array:
	var salida := []
	for indice in bloque.size() / 12:
		salida.append(_transform(_copia(bloque, indice)))
	return salida


func _malla_con_la_vuelta(malla: Mesh, vuelta: Basis) -> ArrayMesh:
	var resultado := ArrayMesh.new()
	for superficie in malla.get_surface_count():
		var herramienta := SurfaceTool.new()
		herramienta.append_from(malla, superficie, Transform3D(vuelta, Vector3.ZERO))
		herramienta.set_material(malla.surface_get_material(superficie))
		herramienta.commit(resultado)
	return resultado


func _volcar_atlas() -> void:
	var imagen := Image.load_from_file(ATLAS)
	if imagen == null:
		print("no se pudo leer el EXR")
		return
	print("atlas ", imagen.get_size(), " formato ", imagen.get_format())
	var pagina := imagen.get_region(Rect2i(0, 0, imagen.get_width(), imagen.get_width()))
	pagina.convert(Image.FORMAT_RGBAH)
	var archivo := FileAccess.open(SALIDA + "lightmap.bin", FileAccess.WRITE)
	archivo.store_buffer(pagina.get_data())
	archivo.close()
	_entorno["atlas"] = {
		"ancho": pagina.get_width(),
		"alto": pagina.get_height(),
		"formato": "RGBAH",
		"paginas": imagen.get_height() / imagen.get_width(),
	}


func _dibujo_de(nodo: MeshInstance3D, transform: Transform3D, ruta: String, visible: bool) -> Dictionary:
	var malla := nodo.mesh
	return {
		"ruta": ruta,
		"malla": _registrar_malla(malla, ""),
		"materiales": _materiales_de_la_malla(malla),
		"override": _registrar_material(nodo.material_override),
		"transform": _transform(transform),
		"visible": visible,
		"gi": nodo.gi_mode,
		"sombra": nodo.cast_shadow,
	}


func _materiales_de_la_malla(malla: Mesh) -> Array:
	if malla == null:
		return []
	var salida := []
	for superficie in malla.get_surface_count():
		salida.append(_registrar_material(malla.surface_get_material(superficie)))
	return salida


func _registrar_malla(malla: Mesh, pista: String) -> String:
	if malla == null:
		return ""
	var clave := malla.resource_path if not malla.resource_path.is_empty() else "malla#%d" % malla.get_instance_id()
	if _mallas.has(clave):
		return clave
	var superficies := []
	for superficie in malla.get_surface_count():
		var a := malla.surface_get_arrays(superficie)
		var pos: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var nor: PackedVector3Array = a[Mesh.ARRAY_NORMAL] if a[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
		var uv: PackedVector2Array = a[Mesh.ARRAY_TEX_UV] if a[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
		var uv2: PackedVector2Array = a[Mesh.ARRAY_TEX_UV2] if a[Mesh.ARRAY_TEX_UV2] != null else PackedVector2Array()
		var tan: PackedFloat32Array = a[Mesh.ARRAY_TANGENT] if a[Mesh.ARRAY_TANGENT] != null else PackedFloat32Array()
		var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX] if a[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var verts := pos.size()
		var entrada := {
			"vertices": verts,
			"pos": _anexar(pos.to_byte_array()),
			"nor": _anexar(nor.to_byte_array()),
			"uv": _anexar(uv.to_byte_array()),
			"uv2": _anexar(uv2.to_byte_array()),
			"tan": _anexar(tan.to_byte_array()),
			"indices": _anexar(idx.to_byte_array()),
			"cuantos_indices": idx.size(),
			"aabb": _aabb(malla.get_aabb()),
		}
		superficies.append(entrada)
	_mallas[clave] = superficies
	return clave


func _anexar(datos: PackedByteArray) -> Array:
	var desde := _bytes.size()
	_bytes.append_array(datos)
	# Alinea a 4 bytes para que los flotantes no queden corridos entre sÃƒÂ­.
	while _bytes.size() % 4 != 0:
		_bytes.append(0)
	return [desde, datos.size()]


func _registrar_material(material: Material) -> String:
	if material == null:
		return ""
	var clave := material.resource_path
	if clave.is_empty():
		clave = "%s#%d" % [material.get_class(), material.get_instance_id()]
	if _materiales.has(clave):
		return clave
	var salida := {"clase": material.get_class(), "nombre": material.resource_name}
	var estandar := material as BaseMaterial3D
	if estandar != null:
		salida["albedo"] = _color(estandar.albedo_color)
		salida["albedo_textura"] = _textura(estandar.albedo_texture)
		salida["metalico"] = estandar.metallic
		salida["especular"] = estandar.metallic_specular
		salida["rugosidad"] = estandar.roughness
		salida["rugosidad_textura"] = _textura(estandar.roughness_texture)
		salida["orm_textura"] = _textura(estandar.orm_texture)
		salida["normal_textura"] = _textura(estandar.normal_texture)
		salida["normal_escala"] = estandar.normal_scale
		salida["normal"] = estandar.normal_enabled
		salida["emision"] = estandar.emission_enabled
		salida["emision_color"] = _color(estandar.emission)
		salida["emision_energia"] = estandar.emission_energy_multiplier
		salida["emision_textura"] = _textura(estandar.emission_texture)
		salida["transparencia"] = estandar.transparency
		salida["alpha_scissor"] = estandar.alpha_scissor_threshold
		salida["cull"] = estandar.cull_mode
		salida["sombras"] = estandar.disable_receive_shadows
		salida["vertices_color"] = estandar.vertex_color_use_as_albedo
		var escala: Vector3 = estandar.uv1_scale
		var corrimiento: Vector3 = estandar.uv1_offset
		salida["uv1_escala"] = [escala.x, escala.y, escala.z]
		salida["uv1_corrimiento"] = [corrimiento.x, corrimiento.y, corrimiento.z]
	_materiales[clave] = salida
	return clave


func _textura(textura: Texture2D) -> String:
	if textura == null:
		return ""
	var ruta := textura.resource_path
	if ruta.is_empty():
		ruta = "%s#%d" % [textura.get_class(), textura.get_instance_id()]
	if not _texturas.has(ruta):
		var imagen := textura.get_image()
		_texturas[ruta] = {
			"ancho": imagen.get_width() if imagen != null else 0,
			"alto": imagen.get_height() if imagen != null else 0,
			"archivo": ruta.get_file(),
		}
	return ruta


func _transform(t: Transform3D) -> Array:
	var b := t.basis
	var o := t.origin
	return [
		b.x.x, b.x.y, b.x.z,
		b.y.x, b.y.y, b.y.z,
		b.z.x, b.z.y, b.z.z,
		o.x, o.y, o.z,
	]


func _basis(b: Basis) -> Array:
	return [
		b.x.x, b.x.y, b.x.z,
		b.y.x, b.y.y, b.y.z,
		b.z.x, b.z.y, b.z.z,
	]


func _color(c: Color) -> Array:
	return [c.r, c.g, c.b, c.a]


func _aabb(caja: AABB) -> Array:
	return [caja.position.x, caja.position.y, caja.position.z, caja.end.x, caja.end.y, caja.end.z]


## La transformaciÃ³n al mundo sin depender de estar en el Ã¡rbol: se compone hacia arriba.
func _mundo(nodo: Node3D) -> Transform3D:
	var t := nodo.transform
	var p := nodo.get_parent()
	while p is Node3D:
		t = (p as Node3D).transform * t
		p = p.get_parent()
	return t


func _recorrer(nodo: Node, lista: Array[MeshInstance3D]) -> void:
	if nodo is MeshInstance3D and (nodo as MeshInstance3D).mesh != null:
		lista.append(nodo as MeshInstance3D)
	for hijo in nodo.get_children():
		_recorrer(hijo, lista)




