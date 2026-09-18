extends GdUnitTestSuite

const MODELO := preload("res://assets/SEPT_JUEGOS_PROTOTIPO.glb")
const CONTENIDO := preload("res://src/escenas/puestos/contenido_del_estante.tscn")
const SOPORTE := preload("res://assets/models/gondola_soporte.res")
const COLISION := preload("res://assets/models/gondola_colision.res")

## Qué malla del modelo le toca a cada producto, en el orden de `Producto.Id`. Es el mapeo, y
## está acá escrito a mano a propósito: si el orden del catálogo y el del contenido se separan,
## `_preparar_modelos` le da a un producto el modelo de otro sin que nada lo diga.
const DEL_MODELO := [
	"Actroncito_002",
	"gondolanueva/durextra",
	"gondolanueva/burgaloo",
	"gondolanueva/Zucarachas",
	"gondolanueva/snackpapas1_001",
	"gondolanueva/malbardocig",
	"pringles",
	"alfajorescaja2",
	"lataarvejas",
	"gondolanueva/chisitos2",
	"oremos",
	"pepitos"
]


func test_el_mueble_conserva_todas_sus_caras_y_materiales() -> void:  # 041-AC7
	var modelo: Node3D = auto_free(MODELO.instantiate())
	var original: ArrayMesh = modelo.get_node("gondolanueva").mesh
	assert_int(SOPORTE.get_surface_count()).is_equal(original.get_surface_count())
	for indice in original.get_surface_count():
		if indice >= SOPORTE.get_surface_count():
			continue
		var antes := original.surface_get_arrays(indice)
		var despues := SOPORTE.surface_get_arrays(indice)
		assert_array(despues[Mesh.ARRAY_VERTEX]).is_equal(antes[Mesh.ARRAY_VERTEX])
		assert_array(despues[Mesh.ARRAY_TEX_UV]).is_equal(antes[Mesh.ARRAY_TEX_UV])
		var material: StandardMaterial3D = SOPORTE.surface_get_material(indice)
		var previo: StandardMaterial3D = original.surface_get_material(indice)
		assert_object(material.albedo_texture).is_same(previo.albedo_texture)
		assert_float(material.roughness).is_equal(previo.roughness)
		assert_int(material.cull_mode).is_equal(previo.cull_mode)


func test_la_colision_corresponde_al_mueble_completo() -> void:  # 041-AC3
	var modelo: Node3D = auto_free(MODELO.instantiate())
	var original: ArrayMesh = modelo.get_node("gondolanueva").mesh
	assert_array(COLISION.get_faces()).is_equal(original.get_faces())


func test_el_contenido_conserva_material_y_textura_de_cada_producto() -> void:  # 041-AC7
	var modelo: Node3D = auto_free(MODELO.instantiate())
	var contenido: Node3D = auto_free(CONTENIDO.instantiate())
	for id in DEL_MODELO.size():
		var copia: MeshInstance3D = contenido.get_child(id)
		var original: MeshInstance3D = modelo.get_node(DEL_MODELO[id])
		var material: StandardMaterial3D = copia.mesh.surface_get_material(0)
		var previo: StandardMaterial3D = original.mesh.surface_get_material(0)
		assert_object(material).override_failure_message(copia.name).is_not_null()
		assert_object(material.albedo_texture).is_same(previo.albedo_texture)
		assert_array(copia.mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV]).is_equal(
			original.mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV]
		)


## Reponer coloca el producto del modelo, no una copia parecida.
##
## La malla viaja **intacta**: la escala y el giro van en el nodo del contenido, que es lo que
## `_preparar_modelos` hornea. Por eso acá se comparan los vértices tal cual, y aparte el tamaño
## que el par malla-nodo da en el mundo, que es lo que el jugador ve en el estante.
func test_reponer_recupera_los_productos_independientes_del_modelo() -> void:  # 041-AC9
	var modelo: Node3D = auto_free(MODELO.instantiate())
	var contenido: Node3D = auto_free(CONTENIDO.instantiate())
	assert_int(contenido.get_child_count()).is_equal(DEL_MODELO.size())
	assert_int(Catalogo.todos().size()).is_equal(DEL_MODELO.size())
	for id in DEL_MODELO.size():
		var copia: MeshInstance3D = contenido.get_child(id)
		var original: MeshInstance3D = modelo.get_node(DEL_MODELO[id])
		assert_str(copia.name).is_equal(Catalogo.de(id).nombre)
		assert_int(copia.mesh.get_surface_count()).is_equal(original.mesh.get_surface_count())
		for superficie in original.mesh.get_surface_count():
			(
				assert_array(copia.mesh.surface_get_arrays(superficie)[Mesh.ARRAY_VERTEX])
				. override_failure_message(copia.name)
				. is_equal(original.mesh.surface_get_arrays(superficie)[Mesh.ARRAY_VERTEX])
			)
		var antes: AABB = original.transform * original.mesh.get_aabb()
		var despues: AABB = copia.transform * copia.mesh.get_aabb()
		(
			assert_bool(despues.size.is_equal_approx(antes.size))
			. override_failure_message("%s: %s contra %s" % [copia.name, despues.size, antes.size])
			. is_true()
		)
