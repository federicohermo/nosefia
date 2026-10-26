## Las puertas de heladera al cierre: cuántas cuentan y cuándo hay llamado, sin escena.
extends GdUnitTestSuite

const ReglasDelCierre := preload("res://src/dominio/almacen/reglas_del_cierre.gd")
const H := ReglasDelCierre.Heladera


func _puertas(
	abiertas: Array[ReglasDelCierre.Heladera]
) -> Dictionary[ReglasDelCierre.Heladera, Puerta]:
	var puertas: Dictionary[ReglasDelCierre.Heladera, Puerta] = {}
	for heladera: ReglasDelCierre.Heladera in H.values():
		puertas[heladera] = Puerta.new()
		if abiertas.has(heladera):
			puertas[heladera].alternar()
	return puertas


func test_con_las_dos_funcionales_cerradas_no_hay_llamado() -> void:  # AC-CLN-074
	assert_bool(ReglasDelCierre.hay_heladera_abierta(_puertas([]))).is_false()


func test_una_funcional_abierta_alcanza_y_las_dos_valen_lo_mismo() -> void:  # AC-CLN-074
	assert_bool(ReglasDelCierre.hay_heladera_abierta(_puertas([H.PRIMERA]))).is_true()
	assert_bool(ReglasDelCierre.hay_heladera_abierta(_puertas([H.SEGUNDA]))).is_true()
	assert_bool(ReglasDelCierre.hay_heladera_abierta(_puertas([H.PRIMERA, H.SEGUNDA]))).is_true()


func test_la_fuera_de_servicio_no_cuenta_ni_sola_ni_junto_a_una_funcional() -> void:  # AC-CLN-074
	assert_bool(ReglasDelCierre.hay_heladera_abierta(_puertas([H.FUERA_DE_SERVICIO]))).is_false()
	(
		assert_bool(
			ReglasDelCierre.hay_heladera_abierta(_puertas([H.FUERA_DE_SERVICIO, H.SEGUNDA]))
		)
		. is_true()
	)


func test_la_puerta_apenas_alternada_cuenta_aunque_la_hoja_no_haya_girado() -> void:  # AC-CLN-074
	var puertas := _puertas([H.PRIMERA])
	assert_float(puertas[H.PRIMERA].angulo()).is_zero()
	assert_bool(ReglasDelCierre.hay_heladera_abierta(puertas)).is_true()


func test_abierta_y_cerrada_antes_del_cierre_no_deja_llamado() -> void:  # AC-CLN-074
	var puertas := _puertas([H.PRIMERA])
	puertas[H.PRIMERA].alternar()
	assert_bool(ReglasDelCierre.hay_heladera_abierta(puertas)).is_false()


func test_sin_puertas_informadas_no_hay_llamado() -> void:  # AC-CLN-074
	var ninguna: Dictionary[ReglasDelCierre.Heladera, Puerta] = {}
	assert_bool(ReglasDelCierre.hay_heladera_abierta(ninguna)).is_false()
