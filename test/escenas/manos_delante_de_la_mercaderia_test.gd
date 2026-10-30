## Lo que se lleva en las manos queda delante de los envases de la góndola, y no metido entre ellos.
##
## **Los envases son sólo dibujo**: sin un cuerpo propio, los brazos de las manos los atraviesan y
## frenan recién contra el metal del estante. Los casos paran al jugador a medio metro de cada
## lado de una góndola con stock, lo hacen mirar a varias alturas y afirman, en cada postura, que
## la forma entera de lo que lleva no toca ningún envase. La premisa de cada recorrido es que había
## mercadería delante: sin ella, un recorrido en verde no probaría nada.
extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.tscn")
const AperturaConLugar := preload("res://test/escenas/apertura_con_lugar.gd")
const JugadorDelLocal := preload("res://src/escenas/jugador.gd")

## A cuánto del contorno de la góndola se para el jugador, en metros: lo que la mano alcanza a
## meterse entre los envases.
const DISTANCIA_A_LA_GONDOLA := 0.5

## Hacia qué altura mira el jugador en cada lado, en metros.
const ALTURAS_DE_LA_MIRA: Array[float] = [0.3, 0.6, 0.9, 1.2, 1.5, 1.8]

## Hasta dónde se busca mercadería delante de la cámara, en metros.
const ALCANCE_DE_LA_PRUEBA := 1.5

## Cuadros de la mano para llegar a su largo libre, aunque tenga que estirarse.
const CUADROS_PARA_ASENTAR_LA_MANO := 60


func test_un_producto_en_la_mano_queda_delante_de_los_envases() -> void:
	var almacen := await _abrir()
	almacen.get("_reposicion_manual").retirar(Producto.Id.MALBARDO)
	var agarre: Agarre = almacen.get("_agarre")
	var unidad := agarre.cuerpo_sostenido() as RigidBody3D
	assert_object(unidad).is_not_null()
	var resultado := await _recorrer(almacen, _formas_de(unidad))
	assert_int(resultado["con_mercaderia"]).is_greater(0)
	assert_array(resultado["tocadas"]).is_empty()


func test_un_util_en_la_mano_de_carga_queda_delante_de_los_envases() -> void:
	var almacen := await _abrir()
	var util := _llevar_el_jabon(almacen)
	var resultado := await _recorrer(almacen, _formas_de(util))
	assert_int(resultado["con_mercaderia"]).is_greater(0)
	assert_array(resultado["tocadas"]).is_empty()


func test_la_caja_y_su_volumen_en_el_cuerpo_quedan_delante_de_los_envases() -> void:
	var almacen := await _abrir()
	var jugador: CharacterBody3D = almacen.get("_jugador")
	var agarre: Agarre = almacen.get("_agarre")
	var caja: RigidBody3D = almacen.get("_cajas_de_productos")[Producto.Id.MALBARDO]
	assert_bool(agarre.pedir_agarrar(caja.get("datos"), caja)).is_true()
	var volumen_en_el_cuerpo: CollisionShape3D = jugador.get_node("FormaDeLaCaja")
	assert_bool(volumen_en_el_cuerpo.disabled).is_false()
	var formas := _formas_de(caja)
	formas.append(volumen_en_el_cuerpo)
	var resultado := await _recorrer(almacen, formas)
	assert_int(resultado["con_mercaderia"]).is_greater(0)
	assert_array(resultado["tocadas"]).is_empty()


func test_frente_a_un_casillero_vacio_la_mano_entra_al_hueco() -> void:
	var almacen := await _abrir()
	var puesto: Node = almacen.get("_reposicion_manual")
	var llena: Dictionary[Producto.Id, int] = {}
	AperturaConLugar.abrir_con_faltantes(almacen, llena)
	var jabon := _llevar_el_jabon(almacen)
	var con_stock := await _distancias_de_la_mano(almacen, jabon)
	var casilleros: Dictionary[Producto.Id, int] = puesto.call("casilleros")
	AperturaConLugar.abrir_con_faltantes(almacen, casilleros)
	var sin_stock := await _distancias_de_la_mano(almacen, jabon)
	var entra_mas := 0
	for indice in con_stock.size():
		assert_float(sin_stock[indice]).is_greater_equal(con_stock[indice] - 0.01)
		if sin_stock[indice] > con_stock[indice] + 0.03:
			entra_mas += 1
	assert_int(entra_mas).is_greater(0)


func test_con_las_manos_vacias_la_mercaderia_no_hace_de_pared() -> void:
	var almacen := await _abrir()
	var repositor: Repositor = almacen.get("_repositor")
	var ocupados := repositor.estante().casilleros_ocupados(Catalogo.de(Producto.Id.MALBARDO))
	assert_int(ocupados.size()).is_greater(0)
	var centro := _centro_de_un_envase(almacen, Producto.Id.MALBARDO, ocupados[0])
	assert_array(_envases_en(almacen, centro)).is_empty()
	_llevar_el_jabon(almacen)
	await get_tree().physics_frame
	assert_array(_envases_en(almacen, centro)).is_not_empty()


func test_el_envase_que_se_saca_ya_no_frena_la_mano() -> void:
	var almacen := await _abrir()
	var repositor: Repositor = almacen.get("_repositor")
	var ocupados := repositor.estante().casilleros_ocupados(Catalogo.de(Producto.Id.MALBARDO))
	assert_int(ocupados.size()).is_greater(1)
	var sacado := _centro_de_un_envase(almacen, Producto.Id.MALBARDO, ocupados[0])
	var otro := _centro_de_un_envase(almacen, Producto.Id.MALBARDO, ocupados[1])
	almacen.get("_reposicion_manual").call(
		"agarrar_de_la_gondola", Producto.Id.MALBARDO, ocupados[0]
	)
	var agarre: Agarre = almacen.get("_agarre")
	assert_object(agarre.cuerpo_sostenido()).is_not_null()
	await get_tree().physics_frame
	assert_array(_envases_en(almacen, otro)).is_not_empty()
	assert_array(_envases_en(almacen, sacado)).is_empty()


## El almacén con la góndola completa, y el jugador quieto: lo mueven los casos.
func _abrir() -> Node3D:
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	almacen.set(
		"_partida",
		Partida.desde({"jornada": ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA + 1, "medios": 0})
	)
	add_child(almacen)
	AperturaConLugar.abrir_con_todo_el_lugar(almacen)
	await get_tree().physics_frame
	var jugador: CharacterBody3D = almacen.get("_jugador")
	jugador.set_physics_process(false)
	return almacen


func _llevar_el_jabon(almacen: Node3D) -> RigidBody3D:
	var jabon: RigidBody3D = almacen.get_node("Objetos/JabonRosa")
	var agarre: Agarre = almacen.get("_agarre")
	assert_bool(agarre.pedir_agarrar(jabon.get("datos"), jabon)).is_true()
	return jabon


## Cada lado de la góndola a `DISTANCIA_A_LA_GONDOLA`, mirando a su centro a cada altura. Una
## postura es el lugar donde se para el jugador y el punto que mira.
func _posturas(almacen: Node3D) -> Array[Array]:
	var gondola := almacen.get_node("Estructura/gondolanueva") as MeshInstance3D
	var mueble := gondola.global_transform * gondola.get_aabb()
	var centro := mueble.get_center()
	var posturas: Array[Array] = []
	for hacia: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.BACK, Vector3.FORWARD]:
		var mitad := mueble.size.dot(hacia.abs()) / 2.0
		var donde := centro + hacia * (mitad + DISTANCIA_A_LA_GONDOLA)
		donde.y = 0.11
		for altura: float in ALTURAS_DE_LA_MIRA:
			posturas.append([donde, Vector3(centro.x, altura, centro.z)])
	return posturas


## Lleva al jugador a una postura y deja las manos en el largo que les toca ahí.
func _ir_a(almacen: Node3D, postura: Array) -> void:
	var jugador: CharacterBody3D = almacen.get("_jugador")
	jugador.global_position = postura[0]
	_mirar(jugador, postura[1])
	for cuadro in 3:
		await get_tree().physics_frame
	for cuadro in CUADROS_PARA_ASENTAR_LA_MANO:
		jugador.call("_acomodar_las_manos", 1.0 / 60.0)
	jugador.call("_acomodar_la_caja")


## En cuántas posturas había mercadería delante, y en cuáles lo que se lleva tocó un envase.
func _recorrer(almacen: Node3D, formas: Array[CollisionShape3D]) -> Dictionary:
	var con_mercaderia := 0
	var tocadas: Array[String] = []
	var jugador: CharacterBody3D = almacen.get("_jugador")
	for postura in _posturas(almacen):
		await _ir_a(almacen, postura)
		if not _hay_mercaderia_delante(almacen, jugador):
			continue
		con_mercaderia += 1
		for forma in formas:
			if _toca_envases(almacen, forma):
				tocadas.append("desde %v mirando %v" % [postura[0], postura[1]])
				break
	return {"con_mercaderia": con_mercaderia, "tocadas": tocadas}


## A qué distancia de la cámara queda lo que se lleva, en cada postura.
func _distancias_de_la_mano(almacen: Node3D, cuerpo: Node3D) -> Array[float]:
	var jugador: CharacterBody3D = almacen.get("_jugador")
	var camara: Camera3D = jugador.get_node("Giro/Camara")
	var distancias: Array[float] = []
	for postura in _posturas(almacen):
		await _ir_a(almacen, postura)
		distancias.append(cuerpo.global_position.distance_to(camara.global_position))
	return distancias


func _hay_mercaderia_delante(almacen: Node3D, jugador: CharacterBody3D) -> bool:
	var camara: Camera3D = jugador.get_node("Giro/Camara")
	var desde := camara.global_position
	var consulta := PhysicsRayQueryParameters3D.create(
		desde,
		desde - camara.global_basis.z * ALCANCE_DE_LA_PRUEBA,
		JugadorDelLocal.CAPA_DE_LA_MERCADERIA
	)
	return not almacen.get_world_3d().direct_space_state.intersect_ray(consulta).is_empty()


## Si la forma, con su lugar de ahora, se superpone a algún envase. Una caja, o una forma escalada
## —la de la caja del depósito—, se prueba con su caja un poco achicada: tocarse al ras no es
## meterse.
func _toca_envases(almacen: Node3D, forma: CollisionShape3D) -> bool:
	var consulta := PhysicsShapeQueryParameters3D.new()
	var escala := forma.global_basis.get_scale()
	if escala.is_equal_approx(Vector3.ONE) and not forma.shape is BoxShape3D:
		consulta.shape = forma.shape
		consulta.transform = forma.global_transform
	else:
		var limites := LimitesDeForma.de(forma.shape)
		var caja := BoxShape3D.new()
		caja.margin = 0.0
		caja.size = limites.size * escala - Vector3.ONE * 0.02
		consulta.shape = caja
		consulta.transform = Transform3D(
			forma.global_basis.orthonormalized(), forma.global_transform * limites.get_center()
		)
	consulta.collision_mask = JugadorDelLocal.CAPA_DE_LA_MERCADERIA
	return not almacen.get_world_3d().direct_space_state.intersect_shape(consulta, 1).is_empty()


func _centro_de_un_envase(almacen: Node3D, id: Producto.Id, casillero: int) -> Vector3:
	var caja: AABB = almacen.get("_reposicion_manual").call("zona", id, casillero)
	return caja.get_center()


func _envases_en(almacen: Node3D, punto: Vector3) -> Array[Dictionary]:
	var consulta := PhysicsPointQueryParameters3D.new()
	consulta.position = punto
	consulta.collision_mask = JugadorDelLocal.CAPA_DE_LA_MERCADERIA
	return almacen.get_world_3d().direct_space_state.intersect_point(consulta, 1)


## Las formas con las que el cuerpo choca: las apagadas no cuentan.
func _formas_de(cuerpo: RigidBody3D) -> Array[CollisionShape3D]:
	var formas: Array[CollisionShape3D] = []
	for forma: CollisionShape3D in cuerpo.find_children("*", "CollisionShape3D", false, false):
		if not forma.disabled and forma.shape != null:
			formas.append(forma)
	return formas


func _mirar(jugador: CharacterBody3D, punto: Vector3) -> void:
	var control: ControlDelJugador = jugador.get("_control")
	var hacia := (
		punto - (jugador.global_position + Vector3.UP * ReglasDelJugador.ALTURA_DE_LA_CAMARA)
	)
	var yaw := atan2(-hacia.x, -hacia.z)
	var pitch := atan2(hacia.y, Vector2(hacia.x, hacia.z).length())
	var giro := Vector2(wrapf(control.yaw() - yaw, -PI, PI), control.pitch() - pitch)
	control.girar(giro / ReglasDelJugador.SENSIBILIDAD_DEL_MOUSE)
	control.avanzar_el_dibujo(SuavizadoDelGiro.VENTANA)
	jugador.call("_aplicar_la_rotacion")
	jugador.force_update_transform()
