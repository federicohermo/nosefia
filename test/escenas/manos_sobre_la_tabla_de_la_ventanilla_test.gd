## Lo que se lleva en la mano queda sobre la tabla de la ventanilla, y no metido en la madera.
##
## El cuerpo del jugador pasa por la tabla: tiene que llegar a la pared. La mano no. El caso para
## al jugador contra la pared de la ventanilla, lo hace mirar a varios puntos de la tabla y afirma,
## en cada postura, que la forma entera de lo que lleva no entra en ella. La premisa es que la mano
## suelta, con el brazo estirado, sí entraba: sin eso, un recorrido en verde no probaría nada.
extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.tscn")
const AperturaConLugar := preload("res://test/escenas/apertura_con_lugar.gd")

## La malla de la tabla en el modelo: es lo que el jugador ve.
const TABLA := "local_tabla_ventanilla"

## Una capa que nada del juego usa: la mira sólo la sonda que copia el volumen de la tabla.
const CAPA_DE_LA_SONDA := 1 << 19

## Cuánto se achica la sonda, en metros: apoyarse en la tabla es tocarla, y eso no es atravesarla.
const HOLGURA := 0.01

## A qué puntos de la cara de arriba mira el jugador, en fracción del ancho y del fondo de la tabla.
const ANCHOS: Array[float] = [0.2, 0.5, 0.8]
const FONDOS: Array[float] = [0.2, 0.5, 0.8]

## Cuadros de la mano para llegar a su largo libre, aunque tenga que estirarse.
const CUADROS_PARA_ASENTAR_LA_MANO := 60


func test_un_producto_en_la_mano_no_entra_en_la_tabla() -> void:
	var almacen := await _abrir()
	almacen.get("_reposicion_manual").retirar(Producto.Id.MALBARDO)
	var agarre: Agarre = almacen.get("_agarre")
	var unidad := agarre.cuerpo_sostenido() as RigidBody3D
	assert_object(unidad).is_not_null()
	var jugador: CharacterBody3D = almacen.get("_jugador")
	var tabla := _caja_de_la_tabla(almacen)
	_poner_la_sonda(almacen, tabla)
	_parar_contra_la_ventanilla(almacen, jugador)
	var brazo: SpringArm3D = jugador.get_node("Giro/Camara/BrazoDeProducto")
	var con_la_tabla_delante := 0
	var metidas: Array[String] = []
	for ancho in ANCHOS:
		for fondo in FONDOS:
			var punto := Vector3(
				tabla.position.x + tabla.size.x * ancho,
				tabla.end.y,
				tabla.position.z + tabla.size.z * fondo
			)
			await _mirar_y_asentar(jugador, punto)
			if not _la_mano_suelta_entra(almacen, brazo):
				continue
			con_la_tabla_delante += 1
			for forma in _formas_de(unidad):
				if _toca_la_sonda(almacen, forma.shape, forma.global_transform):
					metidas.append("mirando a %v" % punto)
					break
	assert_int(con_la_tabla_delante).is_greater(0)
	assert_array(metidas).is_empty()


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


func _caja_de_la_tabla(almacen: Node3D) -> AABB:
	var malla := almacen.get_node("Estructura").find_child(TABLA, true, false) as MeshInstance3D
	assert_object(malla).is_not_null()
	return malla.global_transform * malla.get_aabb()


func _poner_la_sonda(almacen: Node3D, tabla: AABB) -> void:
	var caja := BoxShape3D.new()
	caja.size = tabla.size - Vector3.ONE * HOLGURA * 2.0
	var forma := CollisionShape3D.new()
	forma.shape = caja
	var sonda: StaticBody3D = auto_free(StaticBody3D.new())
	sonda.collision_layer = CAPA_DE_LA_SONDA
	sonda.collision_mask = 0
	sonda.add_child(forma)
	almacen.add_child(sonda)
	sonda.global_position = tabla.get_center()


## El jugador camina de frente hasta que la pared lo frena, como en el juego.
func _parar_contra_la_ventanilla(almacen: Node3D, jugador: CharacterBody3D) -> void:
	var ventana: Node3D = almacen.get_node("Estructura/Ventanilla")
	jugador.global_position = Vector3(
		ventana.global_position.x, jugador.global_position.y, ventana.global_position.z - 2.0
	)
	jugador.velocity = Vector3.ZERO
	jugador.move_and_collide(Vector3(0, 0, 3.0))


func _mirar_y_asentar(jugador: CharacterBody3D, punto: Vector3) -> void:
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
	for cuadro in 3:
		await get_tree().physics_frame
	for cuadro in CUADROS_PARA_ASENTAR_LA_MANO:
		jugador.call("_acomodar_las_manos", 1.0 / 60.0)


## La mano con el brazo estirado del todo, que es donde iría si nada la frenara.
func _la_mano_suelta_entra(almacen: Node3D, brazo: SpringArm3D) -> bool:
	var libre := Transform3D(
		Basis.IDENTITY, brazo.global_transform * Vector3(0.0, 0.0, brazo.spring_length)
	)
	return _toca_la_sonda(almacen, brazo.shape, libre)


func _toca_la_sonda(almacen: Node3D, forma: Shape3D, donde: Transform3D) -> bool:
	var consulta := PhysicsShapeQueryParameters3D.new()
	consulta.shape = forma
	consulta.transform = donde
	consulta.collision_mask = CAPA_DE_LA_SONDA
	return not almacen.get_world_3d().direct_space_state.intersect_shape(consulta, 1).is_empty()


func _formas_de(cuerpo: RigidBody3D) -> Array[CollisionShape3D]:
	var formas: Array[CollisionShape3D] = []
	for forma: CollisionShape3D in cuerpo.find_children("*", "CollisionShape3D", false, false):
		if not forma.disabled and forma.shape != null:
			formas.append(forma)
	return formas
