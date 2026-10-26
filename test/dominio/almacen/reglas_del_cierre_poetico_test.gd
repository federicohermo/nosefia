extends GdUnitTestSuite

const ReglasDelCierre := preload("res://src/dominio/almacen/reglas_del_cierre.gd")
const CLASE := ReglasDelCierre.Clase
const HABITACION := ReglasDelCierre.Habitacion
const JORNADA_DE_POETICO := AnomaliasDeLaJornada.JORNADA_SIN_AZUL


func test_poetico_suelto_en_su_jornada_no_desordena_en_ninguna_habitacion() -> void:  # AC-CLN-071
	for habitacion: ReglasDelCierre.Habitacion in [
		HABITACION.LOCAL, HABITACION.DEPOSITO, HABITACION.BANO, HABITACION.CUARTITO
	]:
		var estados: Array[ReglasDelCierre.Estado] = [_poetico(habitacion), _poetico(habitacion)]
		assert_bool(ReglasDelCierre.hay_desorden(estados, JORNADA_DE_POETICO)).is_false()


func test_poetico_junto_a_otra_unidad_suelta_desordena_por_la_otra() -> void:  # AC-CLN-071
	var estados: Array[ReglasDelCierre.Estado] = [
		_poetico(HABITACION.LOCAL), _otra_unidad(HABITACION.BANO)
	]
	assert_bool(ReglasDelCierre.hay_desorden(estados, JORNADA_DE_POETICO)).is_true()
	estados.reverse()
	assert_bool(ReglasDelCierre.hay_desorden(estados, JORNADA_DE_POETICO)).is_true()


func test_poetico_afuera_no_desordena_pero_conserva_el_motivo_de_afuera() -> void:  # AC-CLN-071
	var estados: Array[ReglasDelCierre.Estado] = [_poetico(HABITACION.AFUERA)]
	assert_bool(ReglasDelCierre.hay_desorden(estados, JORNADA_DE_POETICO)).is_false()
	assert_bool(ReglasDelCierre.hay_objetos_afuera(estados)).is_true()


func test_poetico_no_tapa_el_desorden_de_dos_cajas_en_el_local() -> void:  # AC-CLN-071
	var estados: Array[ReglasDelCierre.Estado] = [
		_poetico(HABITACION.DEPOSITO),
		ReglasDelCierre.Estado.new(CLASE.CAJA, HABITACION.LOCAL, false),
		ReglasDelCierre.Estado.new(CLASE.CAJA, HABITACION.LOCAL, false),
	]
	assert_bool(ReglasDelCierre.hay_desorden(estados, JORNADA_DE_POETICO)).is_true()


func test_fuera_de_su_jornada_poetico_suelto_desordena_como_cualquiera() -> void:  # AC-CLN-071
	for jornada: int in [JORNADA_DE_POETICO - 1, JORNADA_DE_POETICO + 1]:
		var estados: Array[ReglasDelCierre.Estado] = [_poetico(HABITACION.LOCAL)]
		assert_bool(ReglasDelCierre.hay_desorden(estados, jornada)).is_true()


func test_poetico_sostenido_no_desordena_en_ninguna_jornada() -> void:  # AC-CLN-071
	for jornada: int in [JORNADA_DE_POETICO - 1, JORNADA_DE_POETICO, JORNADA_DE_POETICO + 1]:
		var estados: Array[ReglasDelCierre.Estado] = [_poetico(HABITACION.LOCAL, true)]
		assert_bool(ReglasDelCierre.hay_desorden(estados, jornada)).is_false()


func test_la_caja_de_poetico_en_el_bano_desordena_en_su_jornada() -> void:  # AC-CLN-071
	var estados: Array[ReglasDelCierre.Estado] = [
		ReglasDelCierre.Estado.new(
			CLASE.CAJA, HABITACION.BANO, false, AnomaliasDeLaJornada.id_de_poetico()
		)
	]
	assert_bool(ReglasDelCierre.hay_desorden(estados, JORNADA_DE_POETICO)).is_true()


func _poetico(
	habitacion: ReglasDelCierre.Habitacion, en_mano: bool = false
) -> ReglasDelCierre.Estado:
	return ReglasDelCierre.Estado.new(
		CLASE.UNIDAD_SUELTA, habitacion, en_mano, AnomaliasDeLaJornada.id_de_poetico()
	)


func _otra_unidad(habitacion: ReglasDelCierre.Habitacion) -> ReglasDelCierre.Estado:
	var otra := UnidadDeProducto.new(Catalogo.de(Producto.Id.PROGRES)).id
	return ReglasDelCierre.Estado.new(CLASE.UNIDAD_SUELTA, habitacion, false, otra)
