extends GdUnitTestSuite

const MODELO := preload("res://assets/models/SEPT_JUEGOS_PROTOTIPO.glb")
const CONTENIDO := preload("res://src/escenas/puestos/contenido_del_estante.tscn")
const ESTRUCTURA := preload("res://src/escenas/puestos/estructura_del_almacen.tscn")

## Cuánto puede separarse un vértice de la colisión del mismo vértice de la malla, en metros.
const SEPARACION_MAXIMA := 0.001

## El lado de la celda con la que se buscan los vertices por cercanía, en metros. Un
## centímetro es diez veces la separación que se tolera: alcanza para que el par caiga en
## la celda propia o en una de al lado, y deja pocos vertices por celda.
const CELDA := 0.01

## Qué malla del modelo le toca a cada producto, en el orden de `Producto.Id`. Es el mapeo, y
## está acá escrito a mano a propósito: si el orden del catálogo y el del contenido se separan,
## `_preparar_modelos` le da a un producto el modelo de otro sin que nada lo diga.
const DEL_MODELO := [
	"gondolanueva2/Actroncito",
	"gondolanueva2/durextra",
	"gondolanueva/burgaloo",
	"gondolanueva/Zucarachas",
	"gondolanueva/snackpapas1_003",
	"gondolanueva/malbardocig",
	"gondolanueva/pringles3_002",
	"gondolanueva2/alfajorescaja2-2oeste1",
	"gondolanueva/lataarvejas_002",
	"gondolanueva/chisitos2",
	"gondolanueva/oremos",
	"gondolanueva/pepitos2_025",
	"gondolanueva2/saladix-2oeste2",
	"gondolanueva/wakas_021",
	"heladeranueva/bebida helada02-este2",
	"gondolanueva2/cereal-2norte2",
	"gondolanueva2/fideos2",
	"amargadito",
	"cindolor",
	"flimpof",
	"donsaturados",
	"petisas",
	"macumbas",
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
		# **O trae textura o trae un color propio.** Una superficie puede ser un color plano a
		# propósito —el zócalo de la góndola lo es—, y exigirle textura a todas dejaba el test
		# rojo por una decisión de arte. Lo que sigue cazando es el enlace roto, que es el caso
		# que importa: una imagen que no resuelve deja la superficie en blanco y sin textura.
		var pintado: bool = material.albedo_color != Color.WHITE
		(
			assert_bool(material.albedo_texture != null or pintado)
			. override_failure_message("superficie %d sin textura ni color" % indice)
			. is_true()
		)


## La colisión del mueble cubre el mueble entero, y es la que la escena monta.
##
## **Se comparan como conjunto y no vertice por vertice.** El importador de Godot no conserva
## el orden de las caras de la malla al hornear la forma: con el modelo del 2026-09-19 sólo 29
## de 3252 vertices caen en el mismo indice, y las dos geometrias son la misma.
##
## **Se comparan con tolerancia y no por igualdad**: la malla llega comprimida del `.glb` y la
## forma no, asi que el mismo vertice sale con un decimal distinto de cada lado.
##
## **Y se buscan por cercanía, no ordenando las dos listas.** Ordenarlas con un comparador
## aproximado no da un orden total: dos vertices que empatan por el eje que se mira quedan en
## cualquier orden, y basta que el artista parta la malla en mas materiales para que los dos
## lados empaten distinto. Con eso el test se ponia rojo con dos mil lineas por una geometria
## que es la misma. Buscar cada vertice en su celda y en las de al lado no depende de ningun
## orden.
func test_la_colision_corresponde_al_mueble_completo() -> void:
	var escena: Node3D = auto_free(ESTRUCTURA.instantiate())
	var malla: MeshInstance3D = escena.get_node("gondolanueva")
	var forma: CollisionShape3D = escena.get_node("gondolanueva/StaticBody3D/CollisionShape3D")
	var caras: PackedVector3Array = malla.mesh.get_faces()
	var choque: PackedVector3Array = forma.shape.get_faces()
	assert_int(choque.size()).is_equal(caras.size())
	var casilleros := _por_celda(caras)
	var sueltos := 0
	var peor := 0.0
	for punto in choque:
		var cerca := _distancia_mas_corta(casilleros, punto)
		if cerca >= SEPARACION_MAXIMA:
			sueltos += 1
			peor = maxf(peor, cerca)
	(
		assert_int(sueltos)
		. override_failure_message(
			(
				"%d de %d vertices de la forma no tienen par en la malla (el peor, a %.4f)"
				% [sueltos, choque.size(), peor]
			)
		)
		. is_equal(0)
	)


## Los vertices repartidos en celdas de un centimetro, para buscarlos por cercanía.
func _por_celda(puntos: PackedVector3Array) -> Dictionary:
	var casilleros := {}
	for punto in puntos:
		var celda := Vector3i((punto / CELDA).floor())
		if not casilleros.has(celda):
			casilleros[celda] = PackedVector3Array()
		casilleros[celda].append(punto)
	return casilleros


## Lo que dista el vertice del más cercano de la otra malla. Mira su celda y las 26 de al lado,
## que es todo lo que puede haber a menos de un centímetro.
func _distancia_mas_corta(casilleros: Dictionary, punto: Vector3) -> float:
	var celda := Vector3i((punto / CELDA).floor())
	var corta := INF
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			for dz in [-1, 0, 1]:
				var vecina := celda + Vector3i(dx, dy, dz)
				if not casilleros.has(vecina):
					continue
				for otro in casilleros[vecina]:
					corta = minf(corta, punto.distance_to(otro))
	return corta


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
		var sueltos := _sin_par_con_su_uv(copia.mesh, original.mesh)
		(
			assert_int(sueltos)
			. override_failure_message(
				"%s: %d vértices sin su UV en el modelo" % [copia.name, sueltos]
			)
			. is_equal(0)
		)


## Reponer coloca el producto del modelo, no una copia parecida.
##
## La malla viaja **intacta**: la escala y el giro van en el nodo del contenido, que es lo que
## `_preparar_modelos` hornea. Por eso acá se comparan los vértices, y aparte el tamaño que el
## par malla-nodo da en el mundo, que es lo que el jugador ve en el estante.
##
## **Con tolerancia y por cercanía, no decimal por decimal.** El modelo se importa con el
## segundo juego de UV para el horneado de la luz, y ese paso vuelve a empaquetar cada malla:
## el mismo vértice sale con un decimal distinto del que guardó el contenido.
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
			var casilleros := _por_celda(
				original.mesh.surface_get_arrays(superficie)[Mesh.ARRAY_VERTEX]
			)
			var sueltos := 0
			for punto in copia.mesh.surface_get_arrays(superficie)[Mesh.ARRAY_VERTEX]:
				if _distancia_mas_corta(casilleros, punto) >= SEPARACION_MAXIMA:
					sueltos += 1
			(
				assert_int(sueltos)
				. override_failure_message(
					"%s: %d vértices sin par en el modelo" % [copia.name, sueltos]
				)
				. is_equal(0)
			)
		var antes: AABB = original.transform * original.mesh.get_aabb()
		var despues: AABB = copia.transform * copia.mesh.get_aabb()
		(
			assert_bool(despues.size.is_equal_approx(antes.size))
			. override_failure_message("%s: %s contra %s" % [copia.name, despues.size, antes.size])
			. is_true()
		)


## Cuántos vértices de la copia no tienen en el modelo un vértice en el mismo lugar y con la
## misma UV. Se busca por cercanía: el segundo juego de UV del horneado parte y reordena los
## vértices al importar, así que ni el orden ni la cantidad se conservan.
func _sin_par_con_su_uv(copia: Mesh, original: Mesh) -> int:
	var del_modelo: Array = original.surface_get_arrays(0)
	var vertices: PackedVector3Array = del_modelo[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = del_modelo[Mesh.ARRAY_TEX_UV]
	var casilleros := {}
	for indice in vertices.size():
		var celda := Vector3i((vertices[indice] / CELDA).floor())
		if not casilleros.has(celda):
			casilleros[celda] = PackedInt32Array()
		casilleros[celda].append(indice)
	var de_la_copia: Array = copia.surface_get_arrays(0)
	var sueltos := 0
	for indice in (de_la_copia[Mesh.ARRAY_VERTEX] as PackedVector3Array).size():
		var punto: Vector3 = de_la_copia[Mesh.ARRAY_VERTEX][indice]
		var uv: Vector2 = de_la_copia[Mesh.ARRAY_TEX_UV][indice]
		if not _hay_par(casilleros, vertices, uvs, punto, uv):
			sueltos += 1
	return sueltos


func _hay_par(
	casilleros: Dictionary,
	vertices: PackedVector3Array,
	uvs: PackedVector2Array,
	punto: Vector3,
	uv: Vector2
) -> bool:
	var celda := Vector3i((punto / CELDA).floor())
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			for dz in [-1, 0, 1]:
				for otro in casilleros.get(celda + Vector3i(dx, dy, dz), PackedInt32Array()):
					if (
						punto.distance_to(vertices[otro]) < SEPARACION_MAXIMA
						and uv.distance_to(uvs[otro]) < SEPARACION_MAXIMA
					):
						return true
	return false
