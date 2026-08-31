## La estructura de `jugador.tscn`, que es lo único que este spec puede romper en una escena.
##
## No afirma que el jugador «se sienta bien»: afirma que la escena tiene los nodos que
## `src/escenas/jugador.gd` busca por nombre y que los dos números escritos a mano en el `.tscn`
## siguen siendo los de `reglas_del_jugador.gd`. Un `.tscn` no puede leer una constante de
## GDScript, así que ésta es la única forma de que no se separen en silencio.
##
## **La escena se instancia y NO se entra al árbol.** `instantiate()` alcanza para leer la
## jerarquía y las propiedades —medido—, y entrarla haría correr `_ready()`, que toma el cursor
## y arranca a leer el `RayCast3D`: cosas que en headless no significan nada.
extends GdUnitTestSuite

const ReglasDelJugador := preload("res://src/dominio/reglas_del_jugador.gd")
const ESCENA_DEL_JUGADOR := "res://src/escenas/jugador.tscn"


func _jugador() -> CharacterBody3D:
	return auto_free(load(ESCENA_DEL_JUGADOR).instantiate())


func test_la_raiz_del_jugador_es_un_cuerpo_que_camina() -> void:
	assert_object(_jugador()).is_instanceof(CharacterBody3D)


func test_la_camara_esta_a_la_altura_que_declara_el_dominio() -> void:
	var jugador := _jugador()
	assert_bool(jugador.has_node("Camara")).is_true()
	var camara: Node = jugador.get_node("Camara")
	assert_object(camara).is_instanceof(Camera3D)
	assert_float(camara.position.y).is_equal_approx(ReglasDelJugador.ALTURA_DE_LA_CAMARA, 1e-5)


func test_la_mira_cuelga_de_la_camara_y_alcanza_lo_que_declara_el_dominio() -> void:
	# La mira va colgada de la cámara y no del cuerpo: el pitch se aplica a la cámara, así que
	# un rayo colgado del cuerpo apuntaría siempre al horizonte.
	var jugador := _jugador()
	assert_bool(jugador.has_node("Camara/Mira")).is_true()
	var mira: Node = jugador.get_node("Camara/Mira")
	assert_object(mira).is_instanceof(RayCast3D)
	assert_bool(mira.enabled).is_true()
	assert_vector(mira.target_position).is_equal_approx(
		Vector3(0.0, 0.0, -ReglasDelJugador.ALCANCE_DE_LA_MIRA), Vector3(1e-5, 1e-5, 1e-5)
	)


func test_el_cuerpo_tiene_una_forma_de_colision() -> void:
	# Sin forma el jugador atraviesa las paredes del blockout, y el síntoma —«me caigo del
	# almacén»— no nombra al `.tscn` que lo causó.
	var jugador := _jugador()
	assert_bool(jugador.has_node("Cuerpo")).is_true()
	var cuerpo: Node = jugador.get_node("Cuerpo")
	assert_object(cuerpo).is_instanceof(CollisionShape3D)
	assert_object(cuerpo.shape).is_not_null()


func test_las_cuatro_acciones_del_dominio_estan_declaradas_en_el_proyecto() -> void:
	# El par de String entre `reglas_del_jugador.gd` y la sección `[input]` de `project.godot`
	# no lo verifica nadie más: renombrar la constante sin tocar el proyecto deja una dirección
	# que no responde, y el juego arranca igual.
	for accion in [
		ReglasDelJugador.ACCION_ADELANTE,
		ReglasDelJugador.ACCION_ATRAS,
		ReglasDelJugador.ACCION_IZQUIERDA,
		ReglasDelJugador.ACCION_DERECHA,
	]:
		(
			assert_bool(InputMap.has_action(accion))
			. override_failure_message(
				"falta la acción `%s` en la sección [input] de project.godot" % accion
			)
			. is_true()
		)


func test_el_jugador_avisa_cuando_enfoca_y_cuando_pierde_el_objetivo() -> void:
	# Son el punto donde se cuelga el spec 006: sin ellas, agarrar un objeto no tiene de dónde
	# enterarse de que hay uno enfocado.
	var jugador := _jugador()
	assert_bool(jugador.has_signal("objetivo_enfocado")).is_true()
	assert_bool(jugador.has_signal("objetivo_perdido")).is_true()


func test_suspender_y_reanudar_llegan_hasta_el_control_del_dominio() -> void:
	# Son la única puerta por la que el 006 (examinar un objeto) y el 009 (abrir la computadora)
	# pueden clavar cámara y locomoción. El test mira `_control` por dentro a propósito: lo que
	# hay que probar es que las dos líneas no son un no-op, y agregarle al jugador un tercer
	# método público sólo para poder mirarlo sería API que ningún spec pidió.
	var jugador := _jugador()
	assert_bool(jugador.has_method("suspender")).is_true()
	assert_bool(jugador.has_method("reanudar")).is_true()
	jugador.suspender()
	assert_bool(jugador._control.esta_suspendido()).is_true()
	jugador.reanudar()
	assert_bool(jugador._control.esta_suspendido()).is_false()


func test_suspender_con_algo_enfocado_avisa_que_se_perdio_el_objetivo() -> void:
	# Mientras dura la suspensión `observar()` devuelve `false`, así que si el aviso no saliera
	# en el momento de suspender no saldría nunca: quien escucha se quedaría con el cartel de
	# «se puede agarrar» prendido durante toda la atención del comprador.
	var jugador := _jugador()
	var aviso_recibido := [false]
	jugador.objetivo_perdido.connect(func() -> void: aviso_recibido[0] = true)
	jugador._control.observar(26558334344, 2.0, true)
	jugador.suspender()
	assert_bool(aviso_recibido[0]).is_true()
