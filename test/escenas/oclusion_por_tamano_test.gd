extends GdUnitTestSuite

const Oclusion := preload("res://addons/hornear/oclusion.gd")

const TOPE := 1.0
const PROPORCION := 0.5
const RAYOS := 64
## Lo que se separa de la cosa chocada el punto de prueba: dentro del radio de un panel grande y
## fuera del de una barra fina.
const DISTANCIA := 0.1


func test_una_barra_fina_oscurece_menos_lejos_que_un_panel_grande_a_la_misma_distancia() -> void:
	var barra := _factor_junto_a(_caja(Vector3(0.0, 0.5, 0.0), Vector3(0.02, 1.0, 0.02)))
	var panel := _factor_junto_a(_caja(Vector3(0.0, 0.5, 0.0), Vector3(0.01, 1.0, 1.0)))
	assert_float(barra).is_greater(panel)
	assert_float(panel).is_less(1.0)


func test_un_choque_fuera_del_radio_de_lo_chocado_no_cuenta() -> void:
	var barra := _factor_junto_a(_caja(Vector3(0.0, 0.5, 0.0), Vector3(0.02, 1.0, 0.02)))
	assert_float(barra).is_equal(1.0)


func test_una_barra_fina_no_tapa_lo_que_tiene_detras() -> void:
	var pared := _pared_en(-0.5)
	var sola := _factor(Oclusion.oclusores_de([pared], TOPE, PROPORCION), Vector3(0.3, 0.5, 0.0))
	var barra := _caja(Vector3(0.0, 0.5, 0.0), Vector3(0.02, 1.0, 0.02))
	var con_barra := _factor(
		Oclusion.oclusores_de([pared, barra], TOPE, PROPORCION), Vector3(0.3, 0.5, 0.0)
	)
	assert_float(sola).is_less(1.0)
	assert_float(con_barra).is_equal_approx(sola, 0.0001)


func test_el_radio_es_proporcional_al_tamano_y_no_pasa_del_tope() -> void:
	var radios := Oclusion.radios_de(_caja(Vector3.ZERO, Vector3(0.2, 0.2, 5.0)), TOPE, PROPORCION)
	for radio: float in radios:
		assert_float(radio).is_equal_approx(0.2 * PROPORCION, 0.0001)
	var grande := Oclusion.radios_de(_caja(Vector3.ZERO, Vector3(8.0, 8.0, 8.0)), TOPE, PROPORCION)
	for radio: float in grande:
		assert_float(radio).is_equal(TOPE)


func test_dos_partes_sueltas_de_una_misma_malla_tienen_cada_una_su_tamano() -> void:
	var pata := _caja(Vector3(0.0, 0.2, 0.0), Vector3(0.03, 0.4, 0.03))
	var asiento := _caja(Vector3(1.0, 0.45, 0.0), Vector3(0.4, 0.05, 0.4))
	var radios := Oclusion.radios_de(pata + asiento, TOPE, PROPORCION)
	var triangulos_de_la_pata := pata.size() / 3
	assert_float(radios[0]).is_less(radios[triangulos_de_la_pata])


func test_una_parte_con_vertices_repetidos_en_su_costura_cuenta_como_una_sola() -> void:
	# Una UV2 parte los vértices de una arista: la misma posición aparece dos veces.
	var caja := _caja(Vector3.ZERO, Vector3(0.4, 0.4, 0.4))
	var radios := Oclusion.radios_de(caja, TOPE, PROPORCION)
	for radio: float in radios:
		assert_float(radio).is_equal_approx(radios[0], 0.0001)


func test_cada_malla_se_mide_por_separado_aunque_se_toquen() -> void:
	# Las dos cajas comparten la esquina (0, 0, 0): soldadas, la chica tomaría el tamaño de la grande.
	var grande := _caja(Vector3(4.0, 4.0, 4.0), Vector3(8.0, 8.0, 8.0))
	var chica := _caja(Vector3(-0.015, -0.015, -0.015), Vector3(0.03, 0.03, 0.03))
	var oclusores := Oclusion.oclusores_de([grande, chica], TOPE, PROPORCION)
	assert_float(oclusores.radios[grande.size() / 3]).is_equal_approx(0.015, 0.0001)


func _factor_junto_a(cuerpo: PackedVector3Array) -> float:
	var oclusores := Oclusion.oclusores_de([cuerpo], TOPE, PROPORCION)
	return _factor(oclusores, Vector3(DISTANCIA + 0.01, 0.5, 0.0))


## Un punto que mira hacia el -x, a `x` de distancia.
func _factor(oclusores: Oclusion.Oclusores, punto: Vector3) -> float:
	return Oclusion.factor_en(oclusores, punto, Vector3.LEFT, Oclusion.direcciones(RAYOS), 0.0)


## Una pared grande en el plano x = `x`, con la cara hacia +x.
func _pared_en(x: float) -> PackedVector3Array:
	return _caja(Vector3(x, 0.5, 0.0), Vector3(0.01, 4.0, 4.0))


## Una caja de 12 triángulos con sus 8 esquinas compartidas por posición.
func _caja(centro: Vector3, tamano: Vector3) -> PackedVector3Array:
	var m := tamano / 2.0
	var v: Array[Vector3] = []
	for i: int in 8:
		v.append(
			(
				centro
				+ Vector3(
					m.x * (1 if i & 1 else -1),
					m.y * (1 if i & 2 else -1),
					m.z * (1 if i & 4 else -1)
				)
			)
		)
	var caras := [
		[0, 1, 3, 2], [4, 6, 7, 5], [0, 2, 6, 4], [1, 5, 7, 3], [0, 4, 5, 1], [2, 3, 7, 6]
	]
	var salida := PackedVector3Array()
	for cara: Array in caras:
		salida.append_array(
			[v[cara[0]], v[cara[1]], v[cara[2]], v[cara[0]], v[cara[2]], v[cara[3]]]
		)
	return salida
