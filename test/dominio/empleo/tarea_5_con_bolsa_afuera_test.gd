## La Tarea 5 de la jornada 5 cuando una bolsa quedó afuera: qué texto gana y en qué jornadas.
extends GdUnitTestSuite

const T := Tarea.Tipo
const L := Partida.Llamado

const COMPLETA := ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA


func _partida_de_la_noche(
	jornada: int, cumplidas: Array[T], llamados: Array[L], bolsa_afuera: bool = false
) -> Partida:
	var partida := Partida.desde({"jornada": jornada})
	partida.abrir_la_jornada()
	for tarea: Tarea in partida.obligatorias():
		if cumplidas.has(tarea.tipo()):
			tarea.completar()
	for llamado: L in llamados:
		partida.anotar_llamado(llamado)
	partida.bolsa_afuera = bolsa_afuera
	partida.cerrar_la_jornada(cumplidas.size())
	return partida


func _tipos_de(jornada: int) -> Array[T]:
	var todas: Array[T] = []
	for tarea: Tarea in Apertura.obligatorias(jornada):
		todas.append(tarea.tipo())
	return todas


func _con_la_basura_sin_cumplir(jornada: int) -> Array[T]:
	var cumplidas := _tipos_de(jornada)
	cumplidas.erase(T.SACAR_LA_BASURA)
	return cumplidas


func test_una_bolsa_afuera_cambia_la_tarea_5_de_la_jornada_5() -> void:  # AC-EMP-096
	var segunda := COMPLETA + 1
	var partida := _partida_de_la_noche(segunda, _con_la_basura_sin_cumplir(segunda), [], true)
	var mensajes := DevolucionDelJefe.new(segunda, partida).mensajes()
	var ventana: String = DevolucionDelJefe.PARTICULARES_CON_BOLSA_AFUERA[segunda]
	assert_int(mensajes.count(ventana)).is_equal(1)
	assert_array(mensajes).not_contains([DevolucionDelJefe.PARTICULARES[segunda]])
	assert_int(mensajes.size()).is_equal(3)


func test_sin_bolsa_afuera_la_tarea_5_de_la_jornada_5_sigue_igual() -> void:  # AC-EMP-096
	var segunda := COMPLETA + 1
	var partida := _partida_de_la_noche(segunda, _con_la_basura_sin_cumplir(segunda), [])
	var mensajes := DevolucionDelJefe.new(segunda, partida).mensajes()
	assert_int(mensajes.count(DevolucionDelJefe.PARTICULARES[segunda])).is_equal(1)
	assert_array(mensajes).not_contains([DevolucionDelJefe.PARTICULARES_CON_BOLSA_AFUERA[segunda]])


func test_una_bolsa_que_volvio_al_contenedor_no_deja_tarea_5() -> void:  # AC-EMP-096
	var segunda := COMPLETA + 1
	var partida := _partida_de_la_noche(segunda, _tipos_de(segunda), [])
	var mensajes := DevolucionDelJefe.new(segunda, partida).mensajes()
	assert_int(mensajes.size()).is_equal(2)
	assert_array(mensajes).not_contains([DevolucionDelJefe.PARTICULARES[segunda]])
	assert_array(mensajes).not_contains([DevolucionDelJefe.PARTICULARES_CON_BOLSA_AFUERA[segunda]])


func test_la_bolsa_afuera_solo_cambia_la_jornada_5() -> void:  # AC-EMP-096
	var ventana: String = DevolucionDelJefe.PARTICULARES_CON_BOLSA_AFUERA[COMPLETA + 1]
	for jornada: int in [COMPLETA, COMPLETA + 2, COMPLETA + 3]:
		var partida := _partida_de_la_noche(jornada, [], [], true)
		assert_array(DevolucionDelJefe.new(jornada, partida).mensajes()).not_contains([ventana])


func test_el_texto_de_la_ventana_solo_existe_en_la_jornada_5() -> void:  # AC-EMP-096
	assert_array(DevolucionDelJefe.PARTICULARES_CON_BOLSA_AFUERA.keys()).contains_exactly(
		[COMPLETA + 1]
	)
