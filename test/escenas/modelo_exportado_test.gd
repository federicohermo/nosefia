extends GdUnitTestSuite

const MODELO := preload("res://assets/models/SEPT_JUEGOS_PROTOTIPO.glb")
const CONTENIDO := preload("res://src/escenas/puestos/contenido_del_estante.tscn")
const ESTRUCTURA := preload("res://src/escenas/puestos/estructura_del_almacen.tscn")

## Cuánto puede separarse un vértice de la colisión del mismo vértice de la malla, en metros.
const SEPARACION_MAXIMA := 0.001

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


## El mueble que se juega es el del modelo, sin copia en el medio.
##
## **Se mide sobre la escena y no sobre un `.res` horneado.** La escena traía el mueble por un
## recurso propio, y cuando pasó a usar la malla del `.glb` ese recurso quedó sin cargar: el
## test seguía verde comparándolo contra el modelo, que es lo mismo que no mirar nada.
func test_el_mueble_de_la_escena_es_la_malla_del_modelo() -> void:
	var modelo: Node3D = auto_free(MODELO.instantiate())
	var escena: Node3D = auto_free(ESTRUCTURA.instantiate())
	var original: MeshInstance3D = modelo.get_node("gondolanueva")
	var puesta: MeshInstance3D = escena.get_node("gondolanueva")
	assert_object(puesta.mesh).is_same(original.mesh)
	assert_int(puesta.mesh.get_surface_count()).is_equal(original.mesh.get_surface_count())
	for indice in original.mesh.get_surface_count():
		var material: StandardMaterial3D = puesta.mesh.surface_get_material(indice)
		assert_object(material).override_failure_message(str(indice)).is_not_null()
		assert_object(material.albedo_texture).is_not_null()


## La colisión del mueble cubre el mueble entero, y es la que la escena monta.
##
## **Se comparan con tolerancia y no por igualdad.** La malla llega comprimida del `.glb` y la
## forma no, así que el mismo vértice sale con un decimal distinto de cada lado. Medido el
## 2026-09-18: el que más se separa lo hace 0,12 mm sobre un mueble de 5,8 m, y el milímetro
## de abajo deja pasar eso y nada más.
func test_la_colision_corresponde_al_mueble_completo() -> void:
	var escena: Node3D = auto_free(ESTRUCTURA.instantiate())
	var malla: MeshInstance3D = escena.get_node("gondolanueva")
	var forma: CollisionShape3D = escena.get_node("gondolanueva/StaticBody3D/CollisionShape3D")
	var caras := malla.mesh.get_faces()
	var choque: PackedVector3Array = forma.shape.get_faces()
	assert_int(choque.size()).is_equal(caras.size())
	for indice in caras.size():
		(
			assert_float(choque[indice].distance_to(caras[indice]))
			. override_failure_message("%d: %s contra %s" % [indice, choque[indice], caras[indice]])
			. is_less(SEPARACION_MAXIMA)
		)


func test_el_contenido_conserva_material_y_textura_de_cada_producto() -> void:
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
func test_reponer_recupera_los_productos_independientes_del_modelo() -> void:
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
