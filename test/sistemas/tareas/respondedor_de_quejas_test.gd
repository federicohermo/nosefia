## Responder las quejas desde el celular: la respuesta entra al chat y la obligatoria cuenta cuando
## las cinco están respondidas y bien.
extends GdUnitTestSuite

const JORNADA := QuejasDeLaJornada.JORNADA
const COMPRADORES: Array[Conversacion.Interlocutor] = [
	Conversacion.Interlocutor.EL_SEBA,
	Conversacion.Interlocutor.SUKO_YANEZ,
	Conversacion.Interlocutor.LUCAS_ORTEGA,
	Conversacion.Interlocutor.FLAVIO_BALBIN,
	Conversacion.Interlocutor.MYRIAM_MELANO,
]

var _reloj: RelojDelTurno = null
var _celular: CelularDelEmpleado = null
var _respondedor: RespondedorDeQuejas = null
var _quejas: QuejasDeLaJornada = null


func before_test() -> void:
	var tareas := Apertura.obligatorias(JORNADA)
	_reloj = auto_free(RelojDelTurno.new())
	_reloj.arrancar(Apertura.turno_de_la_jornada(tareas), tareas)
	_celular = auto_free(CelularDelEmpleado.new())
	_celular.abrir_jornada(JORNADA)
	_respondedor = auto_free(RespondedorDeQuejas.new())
	_respondedor.reloj = _reloj
	_respondedor.celular = _celular
	_quejas = QuejasDeLaJornada.de_la_partida(11)
	_respondedor.arrancar(_quejas)
	_celular.pedir_alternar(false)


func _cumplida() -> bool:
	return _reloj.obligatoria(Tarea.Tipo.RESPONDER_QUEJAS).completada()


func _abrir(quien: Conversacion.Interlocutor) -> void:
	_celular.pedir_volver()
	_celular.pedir_chat(quien)


func _responder(quien: Conversacion.Interlocutor, da_la_razon: bool) -> void:
	_abrir(quien)
	_respondedor.pedir_responder(da_la_razon)


func _responder_bien(quien: Conversacion.Interlocutor) -> void:
	_responder(quien, not _quejas.es_correcto(QuejasDeLaJornada.indice_de(quien)))


func test_con_cuatro_bien_sigue_pendiente_y_con_cinco_se_cumple() -> void:  # AC-SHF-081
	for posicion in COMPRADORES.size() - 1:
		_responder_bien(COMPRADORES[posicion])
	assert_bool(_cumplida()).is_false()
	_responder_bien(COMPRADORES[-1])
	assert_bool(_cumplida()).is_true()


func test_una_equivocada_deja_la_obligatoria_sin_cumplir_aunque_se_insista() -> void:  # AC-SHF-081
	var equivocada := COMPRADORES[0]
	_responder(equivocada, _quejas.es_correcto(QuejasDeLaJornada.indice_de(equivocada)))
	for quien: Conversacion.Interlocutor in COMPRADORES.slice(1):
		_responder_bien(quien)
	assert_bool(_cumplida()).is_false()
	_responder_bien(equivocada)
	assert_bool(_cumplida()).is_false()


func test_con_el_turno_cerrado_las_cinco_bien_no_la_cumplen() -> void:  # AC-SHF-081
	_reloj.avanzar(Reglas.DURACION_DEL_TURNO)
	for quien in COMPRADORES:
		_responder_bien(quien)
	assert_bool(_quejas.cumplida()).is_true()
	assert_bool(_cumplida()).is_false()


func test_el_chat_con_una_queja_pendiente_admite_respuesta_y_despues_no() -> void:  # AC-INV-146
	var quien := COMPRADORES[0]
	assert_bool(_respondedor.admite_respuesta(quien)).is_true()
	assert_bool(_respondedor.admite_respuesta(Conversacion.Interlocutor.JEFE)).is_false()
	_responder(quien, true)
	assert_bool(_respondedor.admite_respuesta(quien)).is_false()


func test_responder_avisa_una_vez_y_deja_la_respuesta_en_el_chat() -> void:  # AC-INV-146
	var avisados: Array[Conversacion.Interlocutor] = []
	_respondedor.queja_respondida.connect(
		func(quien: Conversacion.Interlocutor) -> void: avisados.append(quien)
	)
	var quien := COMPRADORES[1]
	var sin_leer_de_otro := _celular.bandeja().no_leidos(COMPRADORES[2])
	_responder(quien, true)
	_respondedor.pedir_responder(false)
	assert_array(avisados).contains_exactly([quien])
	var mensajes := _celular.bandeja().mensajes_de(quien)
	assert_int(mensajes.size()).is_equal(2)
	assert_bool(mensajes[1].propio).is_true()
	assert_int(_celular.bandeja().no_leidos(quien)).is_zero()
	assert_int(_celular.bandeja().no_leidos(COMPRADORES[2])).is_equal(sin_leer_de_otro)


func test_el_chat_de_una_queja_abre_en_su_primer_mensaje_sin_leer() -> void:  # AC-INV-160
	for quien in COMPRADORES:
		_abrir(quien)
		var lugar := _celular.celular().primer_nuevo()
		assert_int(lugar).is_not_equal(Celular.AL_FINAL)
		assert_bool(_celular.bandeja().mensajes_de(quien)[lugar].propio).is_false()


func test_sin_el_chat_de_una_queja_abierto_no_se_responde_nada() -> void:  # AC-INV-146
	_celular.pedir_volver()
	_respondedor.pedir_responder(true)
	_abrir(Conversacion.Interlocutor.JEFE)
	_respondedor.pedir_responder(true)
	for indice in QuejasDeLaJornada.cantidad():
		assert_bool(_quejas.respondida(indice)).is_false()


func test_con_el_celular_cerrado_no_se_responde_nada() -> void:  # AC-INV-146
	_abrir(COMPRADORES[0])
	_celular.pedir_esc()
	_respondedor.pedir_responder(true)
	assert_bool(_quejas.respondida(0)).is_false()


func test_una_jornada_sin_quejas_no_admite_respuestas() -> void:  # AC-INV-141
	_respondedor.arrancar(null)
	assert_bool(_respondedor.admite_respuesta(COMPRADORES[0])).is_false()
	_responder(COMPRADORES[0], true)
	assert_bool(_quejas.respondida(0)).is_false()
	(
		assert_array(
			_celular.bandeja().conversaciones().filter(
				func(chat: Conversacion) -> bool: return COMPRADORES.has(chat.interlocutor)
			)
		)
		. is_empty()
	)
