extends GdUnitTestSuite

const ReglasDelCierre := preload("res://src/dominio/almacen/reglas_del_cierre.gd")
const CLASE := ReglasDelCierre.Clase
const HABITACION := ReglasDelCierre.Habitacion
const CAJA := preload("res://src/dominio/almacen/caja_de_reposicion.tres")

var _levantar: Pista


func before_test() -> void:
	_levantar = null
	for pista: Pista in CasoDeInvestigacion.de_la_partida().pistas:
		if pista.canal == Pista.Canal.LEVANTAR and not pista.origen.is_empty():
			_levantar = pista
	assert_object(_levantar).is_not_null()


func test_ticket_pista_bolsa_y_vencido_afuera_no_suman_el_motivo() -> void:  # AC-CLN-073
	for eximido: ObjetoDelAlmacen in _eximidos():
		var estados: Array[ReglasDelCierre.Estado] = [_estado(eximido, HABITACION.AFUERA)]
		assert_bool(ReglasDelCierre.hay_objetos_afuera(estados)).is_false()


func test_un_objeto_ordinario_afuera_suma_el_motivo_aunque_haya_un_eximido() -> void:  # AC-CLN-073
	for ordinario: ObjetoDelAlmacen in [_unidad(), _util()]:
		var solo: Array[ReglasDelCierre.Estado] = [_estado(ordinario, HABITACION.AFUERA)]
		assert_bool(ReglasDelCierre.hay_objetos_afuera(solo)).is_true()
		for eximido: ObjetoDelAlmacen in _eximidos():
			var junto: Array[ReglasDelCierre.Estado] = [
				_estado(eximido, HABITACION.AFUERA), _estado(ordinario, HABITACION.AFUERA)
			]
			assert_bool(ReglasDelCierre.hay_objetos_afuera(junto)).is_true()
			junto.reverse()
			assert_bool(ReglasDelCierre.hay_objetos_afuera(junto)).is_true()


func test_una_caja_afuera_suma_el_motivo() -> void:  # AC-CLN-073
	var caja := CAJA
	var estados: Array[ReglasDelCierre.Estado] = [_estado(caja, HABITACION.AFUERA, CLASE.CAJA)]
	assert_bool(ReglasDelCierre.hay_objetos_afuera(estados)).is_true()


func test_la_bolsa_afuera_sigue_contando_como_bolsa_afuera() -> void:  # AC-CLN-073
	var bolsa := _bolsa()
	var afuera: Array[ReglasDelCierre.Estado] = [_estado(bolsa, HABITACION.AFUERA, CLASE.BOLSA)]
	assert_bool(ReglasDelCierre.hay_bolsa_afuera(afuera)).is_true()
	assert_bool(ReglasDelCierre.hay_objetos_afuera(afuera)).is_false()


func test_un_eximido_dentro_del_local_sigue_sin_sumar_el_motivo_de_afuera() -> void:  # AC-CLN-073
	for eximido: ObjetoDelAlmacen in _eximidos():
		var estados: Array[ReglasDelCierre.Estado] = [_estado(eximido, HABITACION.LOCAL)]
		assert_bool(ReglasDelCierre.hay_objetos_afuera(estados)).is_false()


func test_ticket_pista_bolsa_y_vencido_se_tiran_sin_llamado() -> void:  # AC-CLN-050
	for eximido: ObjetoDelAlmacen in _eximidos():
		assert_bool(ReglasDelCierre.esta_eximido(eximido, _levantar.jornada)).is_true()


func test_unidad_utiles_y_caja_no_se_eximen_ni_junto_a_un_eximido() -> void:  # AC-CLN-050
	var caja := CAJA
	var ordinarios: Array[ObjetoDelAlmacen] = [_unidad(), _util(), caja]
	for ordinario: ObjetoDelAlmacen in ordinarios:
		assert_bool(ReglasDelCierre.esta_eximido(ordinario, _levantar.jornada)).is_false()
	assert_bool(ReglasDelCierre.esta_eximido(null, _levantar.jornada)).is_false()


func test_el_objeto_de_una_pista_solo_se_exime_la_jornada_de_su_pista() -> void:  # AC-CLN-050
	var pista := _objeto_de_la_pista()
	for jornada in range(
		ReglasDeLaPartida.PRIMERA_JORNADA, ReglasDeLaPartida.JORNADAS_DE_LA_PARTIDA + 1
	):
		assert_bool(ReglasDelCierre.esta_eximido(pista, jornada)).is_equal(
			jornada == _levantar.jornada
		)


func _eximidos() -> Array[ObjetoDelAlmacen]:
	var vencida := _unidad()
	vencida.vencido = true
	var ticket: Array[Producto] = [Catalogo.de(Producto.Id.ACTRONCITO)]
	return [Ticket.new(ticket), _objeto_de_la_pista(), _bolsa(), vencida]


func _estado(
	objeto: ObjetoDelAlmacen,
	habitacion: ReglasDelCierre.Habitacion,
	clase: ReglasDelCierre.Clase = CLASE.OTRO
) -> ReglasDelCierre.Estado:
	return ReglasDelCierre.Estado.new(
		clase, habitacion, false, objeto.id, ReglasDelCierre.esta_eximido(objeto, _levantar.jornada)
	)


func _unidad() -> UnidadDeProducto:
	return UnidadDeProducto.new(Catalogo.de(Producto.Id.ACTRONCITO))


func _util() -> ObjetoDelAlmacen:
	return load("res://src/dominio/almacen/mopa.tres") as ObjetoDelAlmacen


func _bolsa() -> ObjetoDelAlmacen:
	var bolsa := ObjetoDelAlmacen.new()
	bolsa.id = ReglasDeLaBasura.ids_de_las_bolsas()[0]
	return bolsa


func _objeto_de_la_pista() -> ObjetoDelAlmacen:
	var objeto := ObjetoDelAlmacen.new()
	objeto.id = _levantar.origen
	return objeto
