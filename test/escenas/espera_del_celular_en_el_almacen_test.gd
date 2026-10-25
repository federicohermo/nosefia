## Desde la cuarta noche, el celular sube después de que la persiana termina de bajar y de una
## espera con la persiana baja. La pausa congela la espera, y las noches de prueba no cambian.
extends GdUnitTestSuite

const AvanceDeDevolucion := preload("res://test/avance_de_devolucion.gd")
const RelojDePrueba := preload("res://test/reloj_de_prueba.gd")

const ESCENA_DEL_ALMACEN := "res://src/escenas/almacen.tscn"
const ESPERA := DevolucionDelJefe.SEGUNDOS_DE_ESPERA_DEL_CELULAR
const COMPLETA := ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA

var _ruta_guardado: String


func before_test() -> void:
	_ruta_guardado = Guardado.ruta_por_defecto
	Guardado.ruta_por_defecto = "user://espera_del_celular_628.guardado"
	Guardado.new().borrar()


func after_test() -> void:
	get_tree().paused = false
	Guardado.new().borrar()
	Guardado.ruta_por_defecto = _ruta_guardado


## La noche ya cerrada, con la persiana todavía bajando.
func _cerrada(jornada: int, medios: int = 0) -> Node3D:
	var almacen: Node3D = auto_free(load(ESCENA_DEL_ALMACEN).instantiate())
	almacen.set("_partida", Partida.desde({"jornada": jornada, "medios": medios}))
	add_child(almacen)
	await get_tree().process_frame
	RelojDePrueba.avanzar_turno(
		almacen.get_node("Servicios/RelojDelTurno"), Reglas.DURACION_DEL_TURNO
	)
	return almacen


func _persiana(almacen: Node3D) -> PersianaDeLaNoche:
	return almacen.get_node("Interfaz/PersianaDeLaNoche")


func _celular(almacen: Node3D) -> CelularDelEmpleado:
	return almacen.get_node("Interfaz/CelularDelEmpleado")


func _pantalla(almacen: Node3D) -> PantallaDeDevolucion:
	return almacen.get("_pantalla")


func _esc() -> InputEventAction:
	var esc := InputEventAction.new()
	esc.action = &"ui_cancel"
	esc.pressed = true
	return esc


## Cuenta `segundos` del cuadro del almacén, que es donde corre la espera.
func _esperar(almacen: Node3D, segundos: float) -> void:
	almacen.call("_process", segundos)


func _comprobar_que_sube_a_los_dos_segundos(almacen: Node3D) -> void:
	_esperar(almacen, ESPERA - 0.01)
	assert_bool(_pantalla(almacen).visible).is_false()
	assert_bool(_celular(almacen).celular().abierto()).is_false()
	_esperar(almacen, 0.01)
	assert_bool(_pantalla(almacen).visible).is_true()
	assert_bool(_celular(almacen).celular().abierto()).is_true()


func test_el_celular_sube_dos_segundos_despues_de_la_persiana() -> void:  # AC-EMP-095
	var almacen := await _cerrada(COMPLETA)
	assert_bool(_persiana(almacen).en_pantalla()).is_true()
	assert_bool(_pantalla(almacen).visible).is_false()
	assert_bool(_celular(almacen).celular().abierto()).is_false()
	_esperar(almacen, ESPERA)
	assert_bool(_celular(almacen).celular().abierto()).is_false()
	AvanceDeDevolucion.terminar_la_bajada(_persiana(almacen))
	assert_bool(_persiana(almacen).en_pantalla()).is_true()
	assert_bool(_celular(almacen).celular().abierto()).is_false()
	_esperar(almacen, ESPERA - 0.01)
	assert_bool(_pantalla(almacen).visible).is_false()
	assert_bool(_celular(almacen).celular().abierto()).is_false()
	_esperar(almacen, 0.01)
	assert_bool(_pantalla(almacen).visible).is_true()
	assert_bool(_celular(almacen).celular().abierto()).is_true()
	assert_bool(_celular(almacen).celular().fijo()).is_true()
	assert_int(_celular(almacen).celular().chat()).is_equal(Conversacion.Interlocutor.JEFE)
	assert_int(_pantalla(almacen).a_la_vista()).is_equal(1)
	assert_bool((almacen.get("_jugador") as Node).call("suspendido")).is_true()
	(
		assert_bool((almacen.get_node("Servicios/RelojDelTurno") as RelojDelTurno).corriendo())
		. is_false()
	)


func test_el_despido_sube_el_celular_a_los_dos_segundos() -> void:  # AC-EMP-095
	var almacen := await _cerrada(COMPLETA, 3 * Reglas.MEDIOS_POR_APERCIBIMIENTO)
	assert_int((almacen.get("_partida") as Partida).final()).is_equal(Partida.Final.DESPEDIDO)
	AvanceDeDevolucion.terminar_la_bajada(_persiana(almacen))
	_comprobar_que_sube_a_los_dos_segundos(almacen)


func test_el_contrato_cumplido_sube_el_celular_a_los_dos_segundos() -> void:  # AC-EMP-095
	var almacen := await _cerrada(ReglasDeLaPartida.JORNADAS_DE_LA_PARTIDA)
	AvanceDeDevolucion.terminar_la_bajada(_persiana(almacen))
	_comprobar_que_sube_a_los_dos_segundos(almacen)
	assert_int(_celular(almacen).celular().chat()).is_equal(Conversacion.Interlocutor.JEFE)


func test_la_pausa_congela_la_espera_y_al_reanudar_sigue() -> void:  # AC-EMP-095
	var almacen := await _cerrada(COMPLETA)
	AvanceDeDevolucion.terminar_la_bajada(_persiana(almacen))
	_esperar(almacen, 1.0)
	var pausa: ControlDePausa = almacen.get_node("Interfaz/ControlDePausa")
	pausa._input(_esc())
	assert_bool(get_tree().paused).is_true()
	_esperar(almacen, 5.0)
	assert_bool(_pantalla(almacen).visible).is_false()
	assert_bool(_celular(almacen).celular().abierto()).is_false()
	pausa._input(_esc())
	assert_bool(get_tree().paused).is_false()
	_esperar(almacen, ESPERA - 1.0 - 0.01)
	assert_bool(_pantalla(almacen).visible).is_false()
	_esperar(almacen, 0.01)
	assert_bool(_pantalla(almacen).visible).is_true()
	assert_bool(_celular(almacen).celular().abierto()).is_true()


func test_pausar_con_la_persiana_bajando_empieza_la_espera_al_terminar() -> void:  # AC-EMP-095
	var almacen := await _cerrada(COMPLETA)
	var pausa: ControlDePausa = almacen.get_node("Interfaz/ControlDePausa")
	pausa._input(_esc())
	assert_bool(get_tree().paused).is_true()
	_esperar(almacen, 10.0)
	assert_bool(_pantalla(almacen).visible).is_false()
	pausa._input(_esc())
	assert_bool(get_tree().paused).is_false()
	_esperar(almacen, ESPERA)
	assert_bool(_pantalla(almacen).visible).is_false()
	AvanceDeDevolucion.terminar_la_bajada(_persiana(almacen))
	_comprobar_que_sube_a_los_dos_segundos(almacen)


func test_la_tercera_noche_cierra_sin_celular_aunque_pase_la_espera() -> void:  # AC-EMP-095
	var almacen := await _cerrada(COMPLETA - 1)
	AvanceDeDevolucion.terminar_la_bajada(_persiana(almacen))
	_esperar(almacen, 10.0)
	assert_bool(_pantalla(almacen).visible).is_false()
	assert_bool(_celular(almacen).celular().abierto()).is_false()
