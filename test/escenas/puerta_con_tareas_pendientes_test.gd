## Qué piensa el protagonista al usar la puerta de entrada en las noches de prueba, y que la
## puerta no cambie por eso. Qué texto toca lo prueba el dominio; acá, que el almacén lo pase.
extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.tscn")
const ENTRADA := "Estructura/puertaentrada/CuerpoDeLaHoja"
const S := SubtitulosDeLosGestos.Id
const PRIMERA_COMPLETA := ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA

var _ruta_guardado: String


func before_test() -> void:
	_ruta_guardado = Guardado.ruta_por_defecto
	Guardado.ruta_por_defecto = "user://puerta_608.guardado"
	Guardado.new().borrar()


func after_test() -> void:
	get_tree().paused = false
	Guardado.new().borrar()
	Guardado.ruta_por_defecto = _ruta_guardado


func _abrir(jornada: int) -> Node3D:
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	almacen.set("_partida", Partida.desde({"jornada": jornada}))
	almacen.set("compradores_de_la_apertura", func(_n: int) -> Array[Comprador]: return [])
	add_child(almacen)
	(almacen.get("_reloj") as RelojDelTurno).set_process(false)
	almacen.get("_jugador").set_physics_process(false)
	await get_tree().process_frame
	almacen.get("_jugador").call("reanudar")
	return almacen


func _linea(almacen: Node3D) -> String:
	return (almacen.get("_hud").get("_subtitulo") as Label).text


func _cumplir(almacen: Node3D) -> void:
	var reloj: RelojDelTurno = almacen.get("_reloj")
	for tarea in (almacen.get("_partida") as Partida).obligatorias():
		reloj.completar(tarea)


func _usar_la_puerta(almacen: Node3D) -> void:
	var jugador: Node3D = almacen.get("_jugador")
	jugador.set("_enfocado", almacen.get_node(ENTRADA))
	for pulsado: bool in [true, false]:
		var evento := InputEventMouseButton.new()
		evento.button_index = MOUSE_BUTTON_LEFT
		evento.pressed = pulsado
		jugador.call("_unhandled_input", evento)


func test_con_pendientes_la_entrada_piensa_y_sigue_trabada() -> void:  # AC-SUB-024
	for jornada: int in range(
		ReglasDeLaPartida.PRIMERA_JORNADA, ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA
	):
		var almacen := await _abrir(jornada)
		var entrada: Node3D = almacen.get_node(ENTRADA)
		var trabadas: Array[Node3D] = []
		entrada.connect("puerta_trabada", trabadas.append)
		assert_str(_linea(almacen)).is_empty()
		_usar_la_puerta(almacen)
		assert_str(_linea(almacen)).is_equal(
			SubtitulosDeLosGestos.texto(S.PUERTA_CON_TAREAS_PENDIENTES)
		)
		assert_array(trabadas).is_equal([entrada])
		assert_bool(entrada.call("puerta").abierta()).is_false()
		assert_bool((almacen.get("_reloj") as RelojDelTurno).corriendo()).is_true()
		var jugador: Node3D = almacen.get("_jugador")
		var examen := InputEventAction.new()
		examen.action = ReglasDeLosObjetos.ACCION_EXAMINAR
		examen.pressed = true
		jugador.call("_unhandled_input", examen)
		assert_str(_linea(almacen)).is_equal(
			SubtitulosAlExaminar.de_lo_fijo(SubtitulosAlExaminar.ENTRADA_PRINCIPAL)
		)
		assert_bool(jugador.get("examen").esta_examinando()).is_false()
		assert_bool(jugador.call("suspendido")).is_false()
		assert_bool(entrada.call("puerta").abierta()).is_false()


func test_usarla_dos_veces_deja_una_sola_linea_que_empieza_de_nuevo() -> void:  # AC-SUB-024
	var almacen := await _abrir(ReglasDeLaPartida.PRIMERA_JORNADA)
	var texto := SubtitulosDeLosGestos.texto(S.PUERTA_CON_TAREAS_PENDIENTES)
	var hud: Hud = almacen.get("_hud")
	_usar_la_puerta(almacen)
	hud.call("_process", Subtitulo.duracion(texto) + Subtitulo.DESVANECIDO / 2.0)
	assert_float((hud.get("_subtitulo") as Label).modulate.a).is_less(1.0)
	_usar_la_puerta(almacen)
	assert_str(_linea(almacen)).is_equal(texto)
	assert_float((hud.get("_subtitulo") as Label).modulate.a).is_equal(1.0)


func test_con_todo_cumplido_sale_sin_pensar_aunque_el_aviso_espere() -> void:  # AC-SUB-024
	var almacen := await _abrir(ReglasDeLaPartida.PRIMERA_JORNADA)
	var pila: PilaDeNotificaciones = almacen.get_node("Interfaz/PilaDeNotificaciones")
	pila.actualizar_computadora(true)
	_cumplir(almacen)
	assert_bool(almacen.call("_puede_salir")).is_true()
	_usar_la_puerta(almacen)
	assert_str(_linea(almacen)).is_empty()
	assert_bool(almacen.get("_jugador").call("suspendido")).is_true()


func test_descumplir_una_tarea_devuelve_el_pensamiento() -> void:  # AC-SUB-024
	var almacen := await _abrir(ReglasDeLaPartida.PRIMERA_JORNADA)
	var reloj: RelojDelTurno = almacen.get("_reloj")
	_cumplir(almacen)
	assert_bool(almacen.call("_puede_salir")).is_true()
	var tarea: Tarea = (almacen.get("_partida") as Partida).obligatorias()[0]
	assert_bool(reloj.descumplir(tarea)).is_true()
	assert_bool(almacen.call("_puede_salir")).is_false()
	_usar_la_puerta(almacen)
	assert_str(_linea(almacen)).is_equal(
		SubtitulosDeLosGestos.texto(S.PUERTA_CON_TAREAS_PENDIENTES)
	)


func test_desde_la_primera_jornada_completa_no_piensa() -> void:  # AC-SUB-024
	var almacen := await _abrir(PRIMERA_COMPLETA)
	_usar_la_puerta(almacen)
	assert_str(_linea(almacen)).is_empty()
