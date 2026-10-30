## Una caja soltada sobre un estante con mercadería no queda metida entre los envases.
##
## **Con la caja ya soltada, los envases no están en la simulación**: sólo los ven las manos
## mientras llevan algo. El caso apunta al pie de un envase puesto, desde el pasillo, y suelta la
## caja por el mismo camino que el juego. Para afirmar el resultado vuelve a prender los envases,
## que es lo que el juego hace con la caja en la mano. La premisa va primero: sin un envase bajo el
## punto apuntado, un caso en verde no probaría nada.
extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.tscn")
const AperturaConLugar := preload("res://test/escenas/apertura_con_lugar.gd")
const JugadorDelLocal := preload("res://src/escenas/jugador.gd")

## A cuánto del pie del envase se para el jugador, en metros, y a cuántos costados se prueba.
const DISTANCIA_AL_ESTANTE := 1.3
const COSTADOS: Array[float] = [0.0, 1.0]

## Cuánto puede apartarse de la fila la mira para contar como apuntada a ella, en metros.
const MARGEN_DE_LA_MIRA := 0.05

## Lo que se achica la caja al preguntar, porque apoyarse sobre algo es tocarlo.
const ACHICADO := 0.02


func test_la_caja_soltada_sobre_un_estante_con_stock_no_queda_entre_los_envases() -> void:
	var almacen := await _abrir()
	var apuntado := _apuntar_a_un_envase(almacen)
	assert_dict(apuntado).override_failure_message("Premisa: un envase al alcance").is_not_empty()
	if apuntado.is_empty():
		return
	var caja: RigidBody3D = apuntado["caja"]
	var agarre: Agarre = almacen.get("_agarre")
	assert_bool(agarre.pedir_agarrar(caja.get("datos"), caja)).is_true()
	await _prender_los_envases(almacen)
	var punto: Vector3 = apuntado["punto"]
	var media := _tamano(caja) / 2.0
	(
		assert_bool(
			_toca_envases(almacen, Transform3D(Basis.IDENTITY, punto + Vector3.UP * media.y), caja)
		)
		. override_failure_message(
			"Premisa: apoyada en el punto apuntado, la caja queda entre envases"
		)
		. is_true()
	)
	agarre.soltar(true)
	for cuadro in 4:
		await get_tree().physics_frame
	assert_object(agarre.manos().sostenido()).is_null()
	await _prender_los_envases(almacen)
	var forma: CollisionShape3D = caja.get_node("Cuerpo")
	var limites := LimitesDeForma.de(forma.shape)
	var pose := Transform3D(
		forma.global_basis.orthonormalized(), forma.global_transform * limites.get_center()
	)
	assert_bool(_toca_envases(almacen, pose, caja)).is_false()


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


## Deja la mercadería a la vista de las cajas, como cuando las manos llevan algo.
func _prender_los_envases(almacen: Node3D) -> void:
	almacen.get("_reposicion_manual").call("_mostrar_la_mercaderia_a_las_manos", true)
	await get_tree().physics_frame


## El primer envase puesto al que la mira de un jugador parado en el pasillo le cae al pie. Devuelve
## la caja que se va a soltar y el punto que la mira toca, o nada si ningún envase sirve.
func _apuntar_a_un_envase(almacen: Node3D) -> Dictionary:
	var puesto: Node3D = almacen.get("_reposicion_manual")
	var disposicion: DisposicionDeLaGondola = puesto.get("disposicion")
	var repositor: Repositor = almacen.get("_repositor")
	for producto in Catalogo.todos():
		var caja: RigidBody3D = almacen.get("_cajas_de_productos")[producto.id]
		var frente := DisposicionDeLaGondola.frente(
			disposicion.principales[producto.id], disposicion.filas_de_adelante[producto.id]
		)
		for casillero: int in repositor.estante().casilleros_ocupados(producto):
			var zona: AABB = puesto.call("zona", producto.id, casillero)
			var pie := zona.get_center() - Vector3.UP * zona.size.y / 2.0
			for costado in COSTADOS:
				var de_pie := (
					pie + frente * DISTANCIA_AL_ESTANTE + frente.cross(Vector3.UP) * costado
				)
				var golpe := _parar_y_mirar(almacen, caja, de_pie, pie)
				if _cae_al_pie(golpe, zona):
					return {"caja": caja, "punto": golpe["position"]}
	return {}


## Lo que toca la mira de un jugador parado ahí, mirando a ese punto. Vacío si ahí no hay piso.
func _parar_y_mirar(
	almacen: Node3D, caja: RigidBody3D, de_pie: Vector3, hacia: Vector3
) -> Dictionary:
	var jugador: CharacterBody3D = almacen.get("_jugador")
	var espacio := almacen.get_world_3d().direct_space_state
	var suelo := PhysicsRayQueryParameters3D.create(
		Vector3(de_pie.x, 3.0, de_pie.z), Vector3(de_pie.x, -1.0, de_pie.z), 1
	)
	suelo.exclude = [jugador.get_rid(), caja.get_rid()]
	var piso := espacio.intersect_ray(suelo)
	if piso.is_empty() or piso["collider"] != almacen.get_node("Estructura/SueloSolido"):
		return {}
	jugador.call("ubicar", Transform3D(Basis.IDENTITY, piso["position"] + Vector3.UP * 0.005))
	var camara: Camera3D = jugador.get_node("Giro/Camara")
	camara.position = Vector3.UP * ReglasDelJugador.ALTURA_DE_LA_CAMARA
	camara.rotation = Vector3.ZERO
	var vista := Transform3D(Basis.IDENTITY, camara.global_position).looking_at(hacia)
	var angulos := vista.basis.get_euler()
	var control: ControlDelJugador = jugador.get("_control")
	control.orientar(angulos.y)
	control.girar(Vector2(0, -angulos.x / ReglasDelJugador.SENSIBILIDAD_DEL_MOUSE))
	control.avanzar_el_dibujo(1.0)
	jugador.call("_aplicar_la_rotacion")
	var ojo: Transform3D = jugador.call("mira")
	var consulta := PhysicsRayQueryParameters3D.create(
		ojo.origin,
		ojo.origin - ojo.basis.z * ReglasDelJugador.ALCANCE_DE_LA_MIRA,
		caja.collision_mask
	)
	consulta.exclude = [jugador.get_rid(), caja.get_rid()]
	return espacio.intersect_ray(consulta)


## Si la mira pegó en el metal, al pie del envase y no en otra cosa.
func _cae_al_pie(golpe: Dictionary, envase: AABB) -> bool:
	if golpe.is_empty():
		return false
	var punto: Vector3 = golpe["position"]
	var normal: Vector3 = golpe["normal"]
	var zona := envase.grow(MARGEN_DE_LA_MIRA)
	return (
		normal.y >= ReglasDeLosObjetos.APOYO_HORIZONTAL
		and absf(punto.y - envase.position.y) <= MARGEN_DE_LA_MIRA
		and punto.x >= zona.position.x
		and punto.x <= zona.end.x
		and punto.z >= zona.position.z
		and punto.z <= zona.end.z
	)


func _tamano(caja: RigidBody3D) -> Vector3:
	var forma: CollisionShape3D = caja.get_node("Cuerpo")
	return (forma.shape as BoxShape3D).size * forma.global_basis.get_scale()


## Si una caja de ese tamaño, en esa pose, se superpone a algún envase puesto.
func _toca_envases(almacen: Node3D, pose: Transform3D, caja: RigidBody3D) -> bool:
	var achicada := BoxShape3D.new()
	achicada.margin = 0.0
	achicada.size = _tamano(caja) - Vector3.ONE * ACHICADO
	var consulta := PhysicsShapeQueryParameters3D.new()
	consulta.shape = achicada
	consulta.transform = pose
	consulta.collision_mask = JugadorDelLocal.CAPA_DE_LA_MERCADERIA
	return not almacen.get_world_3d().direct_space_state.intersect_shape(consulta, 1).is_empty()
