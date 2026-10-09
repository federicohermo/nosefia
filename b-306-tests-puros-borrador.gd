## BORRADOR EXTERNO: no aplicado ni ejecutado. IDs AC pendientes de reserva de B.
## Destino propuesto: test/dominio/almacen/reglas_del_cierre_test.gd.
extends GdUnitTestSuite

const ReglasDelCierre := preload("res://src/dominio/almacen/reglas_del_cierre.gd")
const CLASE := ReglasDelCierre.Clase
const HABITACION := ReglasDelCierre.Habitacion


func test_una_lista_vacia_no_produce_motivos() -> void:
	var estados: Array[ReglasDelCierre.Estado] = []
	assert_bool(ReglasDelCierre.hay_desorden(estados)).is_false()
	assert_bool(ReglasDelCierre.hay_objetos_afuera(estados)).is_false()


func test_una_unidad_suelta_desordena_cualquier_habitacion() -> void:
	_afirmar_estado(CLASE.UNIDAD_SUELTA, HABITACION.LOCAL, true, false)
	_afirmar_estado(CLASE.UNIDAD_SUELTA, HABITACION.DEPOSITO, true, false)
	_afirmar_estado(CLASE.UNIDAD_SUELTA, HABITACION.BANO, true, false)
	_afirmar_estado(CLASE.UNIDAD_SUELTA, HABITACION.AFUERA, false, true)


func test_una_caja_solo_queda_ordenada_en_el_deposito() -> void:
	_afirmar_estado(CLASE.CAJA, HABITACION.LOCAL, true, false)
	_afirmar_estado(CLASE.CAJA, HABITACION.DEPOSITO, false, false)
	_afirmar_estado(CLASE.CAJA, HABITACION.BANO, true, false)
	_afirmar_estado(CLASE.CAJA, HABITACION.AFUERA, false, true)


func test_un_util_solo_queda_ordenado_en_el_bano() -> void:
	_afirmar_estado(CLASE.UTIL_DE_LIMPIEZA, HABITACION.LOCAL, true, false)
	_afirmar_estado(CLASE.UTIL_DE_LIMPIEZA, HABITACION.DEPOSITO, true, false)
	_afirmar_estado(CLASE.UTIL_DE_LIMPIEZA, HABITACION.BANO, false, false)
	_afirmar_estado(CLASE.UTIL_DE_LIMPIEZA, HABITACION.AFUERA, false, true)


func test_los_otros_objetos_adentro_no_producen_desorden() -> void:
	_afirmar_estado(CLASE.OTRO, HABITACION.LOCAL, false, false)
	_afirmar_estado(CLASE.OTRO, HABITACION.DEPOSITO, false, false)
	_afirmar_estado(CLASE.OTRO, HABITACION.BANO, false, false)
	_afirmar_estado(CLASE.OTRO, HABITACION.AFUERA, false, true)


func test_un_mismo_cierre_puede_tener_desorden_y_objetos_afuera() -> void:
	var estados: Array[ReglasDelCierre.Estado] = [
		ReglasDelCierre.Estado.new(CLASE.CAJA, HABITACION.LOCAL, false),
		ReglasDelCierre.Estado.new(CLASE.UNIDAD_SUELTA, HABITACION.AFUERA, false),
	]
	assert_bool(ReglasDelCierre.hay_desorden(estados)).is_true()
	assert_bool(ReglasDelCierre.hay_objetos_afuera(estados)).is_true()
	estados.reverse()
	assert_bool(ReglasDelCierre.hay_desorden(estados)).is_true()
	assert_bool(ReglasDelCierre.hay_objetos_afuera(estados)).is_true()


func test_la_pertenencia_sale_del_punto_y_de_las_tres_cajas() -> void:
	var local := AABB(Vector3.ZERO, Vector3(2, 3, 2))
	var deposito := AABB(Vector3(3, 0, 0), Vector3(2, 3, 2))
	var bano := AABB(Vector3(6, 0, 0), Vector3(2, 3, 2))
	assert_int(ReglasDelCierre.habitacion_de(Vector3(1, 1, 1), local, deposito, bano)).is_equal(
		HABITACION.LOCAL
	)
	assert_int(ReglasDelCierre.habitacion_de(Vector3(4, 1, 1), local, deposito, bano)).is_equal(
		HABITACION.DEPOSITO
	)
	assert_int(ReglasDelCierre.habitacion_de(Vector3(7, 1, 1), local, deposito, bano)).is_equal(
		HABITACION.BANO
	)
	for afuera: Vector3 in [Vector3(-1, 1, 1), Vector3(1, -1, 1), Vector3(1, 4, 1)]:
		assert_int(ReglasDelCierre.habitacion_de(afuera, local, deposito, bano)).is_equal(
			HABITACION.AFUERA
		)


## Cada fila se ejerce suelta y en mano: 4 clases x 4 habitaciones x 2 estados = 32.
## Los resultados sueltos estan escritos en cada caso; llevarlo excluye ambos motivos.
func _afirmar_estado(
	clase: ReglasDelCierre.Clase,
	habitacion: ReglasDelCierre.Habitacion,
	desorden_suelto: bool,
	afuera_suelto: bool
) -> void:
	for en_mano: bool in [false, true]:
		var estados: Array[ReglasDelCierre.Estado] = [
			ReglasDelCierre.Estado.new(clase, habitacion, en_mano)
		]
		assert_bool(ReglasDelCierre.hay_desorden(estados)).is_equal(desorden_suelto and not en_mano)
		assert_bool(ReglasDelCierre.hay_objetos_afuera(estados)).is_equal(
			afuera_suelto and not en_mano
		)
