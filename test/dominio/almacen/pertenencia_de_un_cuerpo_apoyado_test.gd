## Un cuerpo apoyado en el piso de una habitación es de esa habitación, aunque su origen quede unos
## centímetros más abajo que la cara del piso: la forma de un objeto chato no arranca en su origen.
extends GdUnitTestSuite

const ReglasDelCierre := preload("res://src/dominio/almacen/reglas_del_cierre.gd")
const HABITACION := ReglasDelCierre.Habitacion

const PISO := 0.1


func _habitaciones() -> Dictionary[int, Array]:
	return {
		HABITACION.LOCAL: [AABB(Vector3(0, PISO, 0), Vector3(2, 3, 2))],
		HABITACION.DEPOSITO: [AABB(Vector3(3, PISO, 0), Vector3(2, 3, 2))],
		HABITACION.BANO: [AABB(Vector3(6, PISO, 0), Vector3(2, 3, 2))],
		HABITACION.CUARTITO: [AABB(Vector3(9, PISO, 0), Vector3(2, 3, 2))],
	}


func _habitacion_de(punto: Vector3) -> int:
	var partes := _habitaciones()
	var local: Array[AABB] = []
	var deposito: Array[AABB] = []
	var bano: Array[AABB] = []
	var cuartito: Array[AABB] = []
	local.assign(partes[HABITACION.LOCAL])
	deposito.assign(partes[HABITACION.DEPOSITO])
	bano.assign(partes[HABITACION.BANO])
	cuartito.assign(partes[HABITACION.CUARTITO])
	return ReglasDelCierre.habitacion_de(punto, local, deposito, bano, cuartito)


func test_un_origen_apenas_bajo_el_piso_sigue_en_su_habitacion() -> void:  # AC-CLN-040
	var hundido := ReglasDelCierre.HUNDIMIENTO_TOLERADO / 2.0
	for habitacion: int in _habitaciones():
		var parte: AABB = _habitaciones()[habitacion][0]
		var origen := parte.get_center()
		origen.y = PISO - hundido
		assert_bool(parte.has_point(origen)).is_false()
		assert_int(_habitacion_de(origen)).is_equal(habitacion)


func test_un_cuerpo_bien_hundido_bajo_el_piso_queda_afuera() -> void:  # AC-CLN-040
	var hundido := ReglasDelCierre.HUNDIMIENTO_TOLERADO * 2.0
	for habitacion: int in _habitaciones():
		var origen: Vector3 = (_habitaciones()[habitacion][0] as AABB).get_center()
		origen.y = PISO - hundido
		assert_int(_habitacion_de(origen)).is_equal(HABITACION.AFUERA)


func test_la_franja_bajo_el_piso_no_agranda_el_costado_de_la_habitacion() -> void:  # AC-CLN-040
	var parte: AABB = _habitaciones()[HABITACION.LOCAL][0]
	var junto_al_lateral := Vector3(parte.position.x - 0.01, PISO - 0.01, parte.get_center().z)
	assert_int(_habitacion_de(junto_al_lateral)).is_equal(HABITACION.AFUERA)


func test_la_franja_bajo_el_piso_no_baja_el_techo() -> void:  # AC-CLN-040
	var parte: AABB = _habitaciones()[HABITACION.LOCAL][0]
	var techo := parte.position.y + parte.size.y
	var sobre_el_techo := Vector3(parte.get_center().x, techo + 0.01, parte.get_center().z)
	assert_int(_habitacion_de(sobre_el_techo)).is_equal(HABITACION.AFUERA)
