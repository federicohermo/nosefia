## Qué clases de desorden informa el cierre: las mismas condiciones que `hay_desorden`, separadas.
extends GdUnitTestSuite

const ReglasDelCierre := preload("res://src/dominio/almacen/reglas_del_cierre.gd")
const CLASE := ReglasDelCierre.Clase
const HABITACION := ReglasDelCierre.Habitacion
const JORNADA_COMUN := ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA
const JORNADA_DE_POETICO := AnomaliasDeLaJornada.JORNADA_SIN_AZUL


func _estado(
	clase: ReglasDelCierre.Clase, habitacion: ReglasDelCierre.Habitacion, en_mano: bool = false
) -> ReglasDelCierre.Estado:
	return ReglasDelCierre.Estado.new(clase, habitacion, en_mano)


func _clases(
	estados: Array[ReglasDelCierre.Estado], jornada: int = JORNADA_COMUN
) -> Array[ReglasDelCierre.Clase]:
	return ReglasDelCierre.clases_de_desorden(estados, jornada)


func test_una_unidad_suelta_informa_solo_unidades_sueltas() -> void:  # AC-CLN-072
	var estados: Array[ReglasDelCierre.Estado] = [_estado(CLASE.UNIDAD_SUELTA, HABITACION.LOCAL)]
	assert_array(_clases(estados)).is_equal([CLASE.UNIDAD_SUELTA])


func test_dos_cajas_en_el_local_informan_cajas_y_una_sola_ninguna() -> void:  # AC-CLN-072
	var una: Array[ReglasDelCierre.Estado] = [_estado(CLASE.CAJA, HABITACION.LOCAL)]
	assert_array(_clases(una)).is_empty()
	var dos: Array[ReglasDelCierre.Estado] = [
		_estado(CLASE.CAJA, HABITACION.LOCAL), _estado(CLASE.CAJA, HABITACION.LOCAL)
	]
	assert_array(_clases(dos)).is_equal([CLASE.CAJA])


func test_un_util_en_el_deposito_informa_solo_utiles() -> void:  # AC-CLN-072
	var estados: Array[ReglasDelCierre.Estado] = [
		_estado(CLASE.UTIL_DE_LIMPIEZA, HABITACION.DEPOSITO)
	]
	assert_array(_clases(estados)).is_equal([CLASE.UTIL_DE_LIMPIEZA])


func test_las_tres_clases_salen_en_el_orden_de_la_ficha() -> void:  # AC-CLN-072
	var estados: Array[ReglasDelCierre.Estado] = [
		_estado(CLASE.UTIL_DE_LIMPIEZA, HABITACION.BANO),
		_estado(CLASE.CAJA, HABITACION.LOCAL),
		_estado(CLASE.CAJA, HABITACION.LOCAL),
		_estado(CLASE.UNIDAD_SUELTA, HABITACION.DEPOSITO),
	]
	var esperadas := [CLASE.UNIDAD_SUELTA, CLASE.CAJA, CLASE.UTIL_DE_LIMPIEZA]
	assert_array(_clases(estados)).is_equal(esperadas)
	estados.reverse()
	assert_array(_clases(estados)).is_equal(esperadas)


func test_una_unidad_y_un_util_no_informan_cajas() -> void:  # AC-CLN-072
	var estados: Array[ReglasDelCierre.Estado] = [
		_estado(CLASE.UNIDAD_SUELTA, HABITACION.LOCAL),
		_estado(CLASE.UTIL_DE_LIMPIEZA, HABITACION.LOCAL),
		_estado(CLASE.CAJA, HABITACION.LOCAL),
	]
	assert_array(_clases(estados)).is_equal([CLASE.UNIDAD_SUELTA, CLASE.UTIL_DE_LIMPIEZA])


func test_lo_sostenido_lo_tirado_y_las_bolsas_no_suman_clase() -> void:  # AC-CLN-072
	var en_orden: Array[ReglasDelCierre.Estado] = []
	assert_array(_clases(en_orden)).is_empty()
	var excluido: Array[ReglasDelCierre.Estado] = [
		_estado(CLASE.UNIDAD_SUELTA, HABITACION.LOCAL, true),
		_estado(CLASE.UTIL_DE_LIMPIEZA, HABITACION.BANO, true),
		_estado(CLASE.CAJA, HABITACION.BANO, true),
		_estado(CLASE.UNIDAD_SUELTA, HABITACION.AFUERA),
		_estado(CLASE.CAJA, HABITACION.AFUERA),
		_estado(CLASE.UTIL_DE_LIMPIEZA, HABITACION.AFUERA),
		_estado(CLASE.BOLSA, HABITACION.LOCAL),
		_estado(CLASE.BOLSA, HABITACION.CUARTITO),
	]
	assert_array(_clases(excluido)).is_empty()
	assert_bool(ReglasDelCierre.hay_desorden(excluido, JORNADA_COMUN)).is_false()


func test_hay_desorden_si_y_solo_si_hay_una_clase() -> void:  # AC-CLN-072
	var habitaciones: Array = HABITACION.values()
	for clase: ReglasDelCierre.Clase in CLASE.values():
		for habitacion: ReglasDelCierre.Habitacion in habitaciones:
			for en_mano: bool in [false, true]:
				var estados: Array[ReglasDelCierre.Estado] = [_estado(clase, habitacion, en_mano)]
				assert_bool(ReglasDelCierre.hay_desorden(estados, JORNADA_COMUN)).is_equal(
					not _clases(estados).is_empty()
				)


func test_poetico_suelto_solo_suma_unidades_sueltas_fuera_de_su_jornada() -> void:  # AC-CLN-072
	var estados: Array[ReglasDelCierre.Estado] = [
		ReglasDelCierre.Estado.new(
			CLASE.UNIDAD_SUELTA, HABITACION.LOCAL, false, AnomaliasDeLaJornada.id_de_poetico()
		)
	]
	assert_array(_clases(estados, JORNADA_DE_POETICO)).is_empty()
	assert_array(_clases(estados, JORNADA_DE_POETICO + 1)).is_equal([CLASE.UNIDAD_SUELTA])
