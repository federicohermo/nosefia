## Dónde quedó un vencido al cerrar: dentro del local o afuera. Lo lee la Tarea 5 de la devolución.
extends GdUnitTestSuite

const ReglasDelCierre := preload("res://src/dominio/almacen/reglas_del_cierre.gd")
const CLASE := ReglasDelCierre.Clase
const HABITACION := ReglasDelCierre.Habitacion


func _estado(
	lugar: ReglasDelCierre.Habitacion, en_mano: bool, vencido: bool
) -> ReglasDelCierre.Estado:
	return ReglasDelCierre.Estado.new(
		CLASE.UNIDAD_SUELTA, lugar, en_mano, ObjetoDelAlmacen.SIN_ID, vencido, vencido
	)


func _foto(estado: ReglasDelCierre.Estado) -> Array[ReglasDelCierre.Estado]:
	var estados: Array[ReglasDelCierre.Estado] = [estado]
	return estados


func test_sin_vencidos_no_queda_ninguno_en_el_local_ni_afuera() -> void:  # AC-EMP-100
	var vacia: Array[ReglasDelCierre.Estado] = []
	assert_bool(ReglasDelCierre.hay_vencido_en_el_local(vacia, 0)).is_false()
	assert_bool(ReglasDelCierre.hay_vencido_afuera(vacia)).is_false()
	var sana := _foto(_estado(HABITACION.AFUERA, false, false))
	assert_bool(ReglasDelCierre.hay_vencido_en_el_local(sana, 0)).is_false()
	assert_bool(ReglasDelCierre.hay_vencido_afuera(sana)).is_false()


func test_un_vencido_en_la_gondola_queda_en_el_local() -> void:  # AC-EMP-100
	var vacia: Array[ReglasDelCierre.Estado] = []
	assert_bool(ReglasDelCierre.hay_vencido_en_el_local(vacia, 1)).is_true()
	assert_bool(ReglasDelCierre.hay_vencido_afuera(vacia)).is_false()


func test_un_vencido_suelto_en_cualquier_cuarto_queda_en_el_local() -> void:  # AC-EMP-100
	for cuarto: ReglasDelCierre.Habitacion in [
		HABITACION.LOCAL, HABITACION.DEPOSITO, HABITACION.BANO, HABITACION.CUARTITO
	]:
		var suelto := _foto(_estado(cuarto, false, true))
		assert_bool(ReglasDelCierre.hay_vencido_en_el_local(suelto, 0)).is_true()
		assert_bool(ReglasDelCierre.hay_vencido_afuera(suelto)).is_false()


func test_un_vencido_en_la_mano_queda_en_el_local_estando_afuera() -> void:  # AC-EMP-100
	for lugar: ReglasDelCierre.Habitacion in [HABITACION.LOCAL, HABITACION.AFUERA]:
		var en_mano := _foto(_estado(lugar, true, true))
		assert_bool(ReglasDelCierre.hay_vencido_en_el_local(en_mano, 0)).is_true()
		assert_bool(ReglasDelCierre.hay_vencido_afuera(en_mano)).is_false()


func test_un_vencido_tirado_por_la_ventana_queda_afuera() -> void:  # AC-EMP-100
	var afuera := _foto(_estado(HABITACION.AFUERA, false, true))
	assert_bool(ReglasDelCierre.hay_vencido_afuera(afuera)).is_true()
	assert_bool(ReglasDelCierre.hay_vencido_en_el_local(afuera, 0)).is_false()
