## Lo que ningún mueble futuro puede reabrir: cada sólido donde cabe un objeto tiene volumen.
##
## Una forma cóncava es hueca. Lo que queda del todo adentro no toca ninguna cara y no choca con
## nada, y las preguntas «¿entra acá?» del juego no lo ven. Se mide sobre el almacén entero, así
## que un mueble nuevo del modelo entra solo.
extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.tscn")

## Las capas de lo que un objeto soltado puede atravesar: la del mundo y la del contorno.
const CAPAS_DE_LOS_SOLIDOS := 1 | ReglasDeLosObjetos.CAPA_DEL_CONTORNO

## Cuánto se mete hacia adentro un punto de una cara, o una esquina de una caja, antes de
## preguntar de qué lado cae.
const EPSILON := 0.001


func _almacen() -> Node3D:
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	await get_tree().physics_frame
	await get_tree().physics_frame
	return almacen


## Lo que se agarra en el almacén: los rígidos que contestan el contrato de interactuar.
static func _agarrables(raiz: Node) -> Array[RigidBody3D]:
	var salida: Array[RigidBody3D] = []
	for cuerpo: RigidBody3D in raiz.find_children("*", "RigidBody3D", true, false):
		if cuerpo.has_method(ReglasDeLosObjetos.METODO_INTERACTUAR):
			salida.append(cuerpo)
	return salida


## El medio lado menor del agarrable más chico, en metros. Se lee de la escena: un producto nuevo
## más chico lo baja solo.
static func _corte(raiz: Node) -> float:
	var corte := INF
	for cuerpo in _agarrables(raiz):
		for forma: CollisionShape3D in cuerpo.find_children("*", "CollisionShape3D", true, false):
			var lados := (
				forma.shape.get_debug_mesh().get_aabb().size * forma.global_basis.get_scale()
			)
			corte = minf(corte, minf(lados.x, minf(lados.y, lados.z)) / 2.0)
	return corte


## Las piezas conexas de una lista de caras: dos caras son de la misma pieza si comparten un
## vértice.
static func _piezas(caras: PackedVector3Array) -> Array[PackedVector3Array]:
	var padre := {}
	for indice in caras.size():
		padre[_clave(caras[indice])] = _clave(caras[indice])
	for indice in range(0, caras.size(), 3):
		var raiz := _raiz(padre, _clave(caras[indice]))
		for lado in [1, 2]:
			var otra := _raiz(padre, _clave(caras[indice + lado]))
			if otra != raiz:
				padre[otra] = raiz
	var grupos := {}
	for indice in range(0, caras.size(), 3):
		var raiz := _raiz(padre, _clave(caras[indice]))
		# Un arreglo empaquetado se copia al leerlo: se arma afuera y se vuelve a guardar.
		var pieza: PackedVector3Array = grupos.get(raiz, PackedVector3Array())
		pieza.append_array([caras[indice], caras[indice + 1], caras[indice + 2]])
		grupos[raiz] = pieza
	var salida: Array[PackedVector3Array] = []
	for pieza: PackedVector3Array in grupos.values():
		salida.append(pieza)
	return salida


static func _clave(vertice: Vector3) -> Vector3i:
	return Vector3i((vertice * 10000.0).round())


static func _raiz(padre: Dictionary, clave: Vector3i) -> Vector3i:
	while padre[clave] != clave:
		clave = padre[clave]
	return clave


## Si en la pieza cabe el agarrable más chico: los tres lados de su caja envolvente lo superan.
static func _cabe(pieza: PackedVector3Array, corte: float) -> bool:
	var limites := AABB(pieza[0], Vector3.ZERO)
	for vertice in pieza:
		limites = limites.expand(vertice)
	return minf(limites.size.x, minf(limites.size.y, limites.size.z)) > corte * 2.0


static func _exento(forma: CollisionShape3D) -> bool:
	for nodo: Node in [forma, forma.get_parent()]:
		if VolumenDeLosSolidos.exime(nodo.get_meta(VolumenDeLosSolidos.CLAVE_DE_EXENCION, null)):
			return true
	return false


## Si el punto cae adentro de una forma con volumen: una caja, un convexo o un contorno.
static func _con_volumen(espacio: PhysicsDirectSpaceState3D, punto: Vector3) -> bool:
	var consulta := PhysicsPointQueryParameters3D.new()
	consulta.position = punto
	consulta.collision_mask = CAPAS_DE_LOS_SOLIDOS
	for golpe in espacio.intersect_point(consulta, 32):
		var forma := PhysicsServer3D.body_get_shape(golpe["rid"], golpe["shape"])
		if PhysicsServer3D.shape_get_type(forma) != PhysicsServer3D.SHAPE_CONCAVE_POLYGON:
			return true
	return false


## Los nodos con una pieza cóncava donde cabe un objeto y que no tiene volumen detrás.
##
## Se prueba, por cada cara, el punto que queda `EPSILON` hacia adentro de su centro.
static func _sin_volumen(raiz: Node3D, corte: float) -> Array[String]:
	var espacio := raiz.get_world_3d().direct_space_state
	var faltan: Array[String] = []
	for cuerpo: CollisionObject3D in raiz.find_children("*", "CollisionObject3D", true, false):
		if cuerpo.collision_layer & CAPAS_DE_LOS_SOLIDOS == 0:
			continue
		for forma: CollisionShape3D in cuerpo.find_children("*", "CollisionShape3D", false, false):
			if forma.disabled or not forma.shape is ConcavePolygonShape3D or _exento(forma):
				continue
			var caras := (forma.shape as ConcavePolygonShape3D).get_faces()
			for indice in caras.size():
				caras[indice] = forma.global_transform * caras[indice]
			for pieza in _piezas(caras):
				if _cabe(pieza, corte) and not _pieza_con_volumen(espacio, pieza):
					faltan.append(str(raiz.get_path_to(cuerpo.get_parent())))
					break
	return faltan


static func _pieza_con_volumen(
	espacio: PhysicsDirectSpaceState3D, pieza: PackedVector3Array
) -> bool:
	for indice in range(0, pieza.size(), 3):
		var a := pieza[indice]
		var b := pieza[indice + 1]
		var c := pieza[indice + 2]
		var hacia_adentro := (b - a).cross(c - a)
		if hacia_adentro.is_zero_approx():
			continue
		var punto := (a + b + c) / 3.0 + hacia_adentro.normalized() * EPSILON
		if not _con_volumen(espacio, punto):
			return false
	return true


func test_el_corte_sale_del_agarrable_mas_chico() -> void:
	var almacen: Node3D = await _almacen()
	var corte := _corte(almacen)
	assert_float(corte).is_greater(0.0)
	assert_float(corte).is_less(INF)


func test_cada_pieza_donde_cabe_un_objeto_tiene_volumen() -> void:
	var almacen: Node3D = await _almacen()
	var faltan := _sin_volumen(almacen, _corte(almacen))
	(
		assert_array(faltan)
		. override_failure_message("sin volumen ni exención: %s" % ", ".join(faltan))
		. is_empty()
	)


## El caso de arriba recorre un almacén que ya cumple. Éste le arma el defecto —un sólido cóncavo
## sin volumen— y afirma que lo nombra; con una exención vacía lo sigue nombrando.
func test_una_pieza_nueva_sin_volumen_se_nombra_y_una_exencion_vacia_no_la_salva() -> void:
	var raiz: Node3D = auto_free(Node3D.new())
	add_child(raiz)
	var mueble := Node3D.new()
	mueble.name = "mueble_nuevo"
	raiz.add_child(mueble)
	var cuerpo := StaticBody3D.new()
	mueble.add_child(cuerpo)
	var forma := CollisionShape3D.new()
	var cubo := BoxMesh.new()
	cubo.size = Vector3.ONE
	forma.shape = cubo.create_trimesh_shape()
	cuerpo.add_child(forma)
	await get_tree().physics_frame
	assert_array(_sin_volumen(raiz, 0.06)).contains_exactly(["mueble_nuevo"])
	forma.set_meta(VolumenDeLosSolidos.CLAVE_DE_EXENCION, "")
	assert_array(_sin_volumen(raiz, 0.06)).contains_exactly(["mueble_nuevo"])
	forma.set_meta(VolumenDeLosSolidos.CLAVE_DE_EXENCION, "un adorno que no se alcanza")
	assert_array(_sin_volumen(raiz, 0.06)).is_empty()
	forma.remove_meta(VolumenDeLosSolidos.CLAVE_DE_EXENCION)
	var volumen := CollisionShape3D.new()
	var caja := BoxShape3D.new()
	caja.size = Vector3.ONE
	volumen.shape = caja
	cuerpo.add_child(volumen)
	await get_tree().physics_frame
	assert_array(_sin_volumen(raiz, 0.06)).is_empty()


## Las esquinas de cada caja de volumen, metidas `EPSILON`, caen adentro de la malla visible del
## mueble. Una caja que asoma sería una pared invisible.
func test_cada_caja_de_volumen_va_por_dentro_de_la_malla_visible() -> void:
	var almacen: Node3D = await _almacen()
	var estructura: Node3D = almacen.get_node("Estructura")
	var afuera: Array[String] = []
	var medidas := 0
	for malla: MeshInstance3D in estructura.find_children("*", "MeshInstance3D", true, false):
		var cajas := _cajas_de_volumen(malla)
		if cajas.is_empty():
			continue
		var caras := malla.mesh.get_faces()
		for indice in caras.size():
			caras[indice] = malla.global_transform * caras[indice]
		for forma in cajas:
			medidas += 1
			for esquina in _esquinas(forma):
				if not _punto_adentro(caras, esquina):
					afuera.append(str(estructura.get_path_to(forma)))
					break
	assert_int(medidas).override_failure_message("no se midió ninguna caja").is_greater(0)
	(
		assert_array(afuera)
		. override_failure_message("asoman de la malla: %s" % ", ".join(afuera))
		. is_empty()
	)


## Las cajas de volumen de un mueble, que se llaman `Volumen`. El contorno de una góndola no
## entra: la envuelve entera a propósito, porque es lo que choca el jugador.
static func _cajas_de_volumen(malla: MeshInstance3D) -> Array[CollisionShape3D]:
	var salida: Array[CollisionShape3D] = []
	for cuerpo in malla.get_children():
		if not cuerpo is StaticBody3D:
			continue
		for forma in cuerpo.get_children():
			if (
				forma is CollisionShape3D
				and forma.shape is BoxShape3D
				and str(forma.name).begins_with("Volumen")
			):
				salida.append(forma)
	return salida


static func _esquinas(forma: CollisionShape3D) -> PackedVector3Array:
	var medio := (forma.shape as BoxShape3D).size / 2.0 - Vector3.ONE * EPSILON
	var salida := PackedVector3Array()
	for x in [-1.0, 1.0]:
		for y in [-1.0, 1.0]:
			for z in [-1.0, 1.0]:
				salida.append(forma.global_transform * (medio * Vector3(x, y, z)))
	return salida


## El mismo oráculo que el de lo soltado: la primera cara que cruza algún rayo, vista de espaldas.
static func _punto_adentro(caras: PackedVector3Array, punto: Vector3) -> bool:
	for direccion: Vector3 in [
		Vector3(1.0, 0.0013, 0.0007), Vector3(0.0019, 1.0, 0.0003), Vector3(0.0005, -0.0021, 1.0)
	]:
		for sentido in [1.0, -1.0]:
			var mas_cerca := INF
			var de_espaldas := false
			for indice in range(0, caras.size(), 3):
				var a := caras[indice]
				var b := caras[indice + 1]
				var c := caras[indice + 2]
				var cruce: Variant = Geometry3D.ray_intersects_triangle(
					punto, direccion * sentido, a, b, c
				)
				if cruce == null:
					continue
				var distancia := punto.distance_to(cruce)
				if distancia < mas_cerca:
					mas_cerca = distancia
					de_espaldas = (b - a).cross(c - a).dot(direccion * sentido) < 0.0
			if de_espaldas:
				return true
	return false


## Todo lo que se suelta choca con el contorno de los muebles y con las paredes, que están en su
## capa.
func test_todo_lo_que_se_suelta_choca_con_la_capa_del_contorno() -> void:
	var almacen: Node3D = await _almacen()
	var agarrables := _agarrables(almacen.get_node("Objetos"))
	assert_array(agarrables).is_not_empty()
	for cuerpo in agarrables:
		(
			assert_int(cuerpo.collision_mask & ReglasDeLosObjetos.CAPA_DEL_CONTORNO)
			. override_failure_message("`%s` no choca con la capa del contorno" % cuerpo.name)
			. is_not_zero()
		)
