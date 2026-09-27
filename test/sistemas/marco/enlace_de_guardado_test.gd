## El enlace entre el cierre de la jornada y el guardado, con el ciclo corriendo a fuerza de reloj.
extends GdUnitTestSuite

const ENLACE := "res://src/sistemas/marco/enlace_de_guardado.gd"


## Un guardado de verdad que además cuenta cuántas veces lo llamaron.
class GuardadoQueCuenta:
	extends Guardado

	var escrituras: int = 0
	var borrados: int = 0

	func escribir(datos: Dictionary) -> bool:
		escrituras += 1
		return super.escribir(datos)

	func borrar() -> void:
		borrados += 1
		super.borrar()

	func llamadas() -> int:
		return escrituras + borrados


var _reloj: RelojDelTurno
var _ciclo: CicloDeJornadas


func _guardado() -> GuardadoQueCuenta:
	var guardado := GuardadoQueCuenta.new()
	guardado.ruta = create_temp_dir("enlace").path_join("partida.guardado")
	guardado.borrar()
	guardado.borrados = 0
	return guardado


func _arrancar(partida: Partida, guardado: Guardado) -> void:
	_reloj = auto_free(RelojDelTurno.new())
	_ciclo = auto_free(CicloDeJornadas.new())
	auto_free(EnlaceDeGuardado.new(_ciclo, guardado))
	_ciclo.arrancar(partida, _reloj)


func _en_la_jornada(jornada: int) -> Partida:
	return Partida.desde(
		PartidaSerializada.sanear(
			{PartidaSerializada.clave(PartidaSerializada.Campo.JORNADA): jornada}
		)
	)


func _agotar_la_noche() -> void:
	_reloj._process(Reglas.DURACION_DEL_TURNO / Ritmo.SEGUNDOS_DE_TURNO_POR_SEGUNDO_REAL)


func _jugar_la_noche_impecable() -> void:
	for tipo: Tarea.Tipo in Tarea.Tipo.values():
		_reloj.completar(_reloj.obligatoria(tipo))
	_agotar_la_noche()


func test_el_cierre_de_una_jornada_intermedia_guarda_una_vez() -> void:  # AC-SAV-001
	var guardado := _guardado()
	var partida := _en_la_jornada(ReglasDeLaPartida.PRIMERA_JORNADA + 2)
	_arrancar(partida, guardado)
	_agotar_la_noche()
	assert_bool(partida.terminada()).is_false()
	assert_int(guardado.escrituras).is_equal(1)
	assert_int(guardado.llamadas()).is_equal(1)
	var retomada := Partida.desde(guardado.cargar())
	assert_int(retomada.jornada()).is_equal(ReglasDeLaPartida.PRIMERA_JORNADA + 3)
	assert_int(retomada.jornada()).is_equal(partida.jornada())
	assert_int(retomada.apercibimientos()).is_equal(partida.apercibimientos())
	assert_int(retomada.apercibimientos()).is_greater(0)


func test_el_ultimo_cierre_borra_con_una_sola_llamada() -> void:  # AC-SAV-002
	var guardado := _guardado()
	guardado.escribir(PartidaSerializada.sanear({}))
	guardado.escrituras = 0
	var ultima := ReglasDeLaPartida.PRIMERA_JORNADA + ReglasDeLaPartida.JORNADAS_DE_LA_PARTIDA - 1
	var partida := _en_la_jornada(ultima)
	_arrancar(partida, guardado)
	_jugar_la_noche_impecable()
	assert_int(partida.final()).is_equal(Partida.Final.CONTRATO_CUMPLIDO)
	assert_int(guardado.llamadas()).is_equal(1)
	assert_int(guardado.borrados).is_equal(1)
	assert_bool(FileAccess.file_exists(guardado.ruta)).is_false()


func test_dos_noches_graves_seguidas_borran_el_guardado() -> void:  # AC-SAV-003
	var guardado := _guardado()
	var partida := Partida.nueva()
	_arrancar(partida, guardado)
	_agotar_la_noche()
	assert_bool(FileAccess.file_exists(guardado.ruta)).is_true()
	_ciclo.abrir_la_jornada()
	_agotar_la_noche()
	assert_int(partida.final()).is_equal(Partida.Final.DESPEDIDO)
	assert_int(guardado.escrituras).is_equal(1)
	assert_int(guardado.borrados).is_equal(1)
	assert_bool(FileAccess.file_exists(guardado.ruta)).is_false()


func test_un_disco_que_falla_no_frena_la_partida() -> void:  # AC-SAV-005
	var guardado := _guardado()
	guardado.ruta = guardado.ruta.get_base_dir().path_join("no_existe/partida.guardado")
	var partida := Partida.nueva()
	_arrancar(partida, guardado)
	_jugar_la_noche_impecable()
	assert_int(guardado.escrituras).is_equal(1)
	assert_bool(FileAccess.file_exists(guardado.ruta)).is_false()
	assert_bool(_ciclo.abrir_la_jornada()).is_true()
	_jugar_la_noche_impecable()
	assert_int(guardado.escrituras).is_equal(2)


func test_el_enlace_no_decide() -> void:
	var texto := FileAccess.get_file_as_string(ENLACE)
	for nombre: String in ["Legajo", "Consecuencias", "Final", "terminada", "ReglasDeLaPartida"]:
		assert_str(texto).not_contains(nombre)
