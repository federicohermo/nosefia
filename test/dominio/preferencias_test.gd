## Las preferencias como regla: defectos, topes, pasos y saneamiento, sin levantar una escena.
extends GdUnitTestSuite

const C := Preferencias.Campo
const TOLERANCIA := 1e-6


func _recorrido_con_mas(campo: Preferencias.Campo) -> Array[float]:
	var preferencias := Preferencias.new()
	preferencias.poner(campo, Preferencias.minimo(campo))
	var valores: Array[float] = [preferencias.valor(campo)]
	while preferencias.sumar(campo):
		valores.append(preferencias.valor(campo))
	return valores


func test_sin_ajustar_cada_preferencia_esta_en_su_defecto() -> void:  # AC-CFG-002
	var preferencias := Preferencias.new()
	assert_float(preferencias.valor(C.EFECTOS)).is_equal_approx(100.0, TOLERANCIA)
	assert_float(preferencias.valor(C.MUSICA)).is_equal_approx(100.0, TOLERANCIA)
	assert_float(preferencias.valor(C.BRILLO)).is_equal_approx(100.0, TOLERANCIA)
	assert_float(preferencias.valor(C.SENSIBILIDAD)).is_equal_approx(1.0, TOLERANCIA)
	assert_float(preferencias.valor(C.TEXTOS)).is_equal_approx(1.0, TOLERANCIA)


func test_recorrer_con_mas_pasa_por_cada_valor_hasta_el_maximo() -> void:  # AC-CFG-002
	var esperado: Dictionary[Preferencias.Campo, Array] = {
		C.EFECTOS: [11, 100.0],
		C.MUSICA: [11, 100.0],
		C.BRILLO: [11, 150.0],
		C.SENSIBILIDAD: [8, 2.0],
		C.TEXTOS: [8, 1.5],
	}
	for campo: Preferencias.Campo in esperado:
		var valores := _recorrido_con_mas(campo)
		assert_int(valores.size()).is_equal(esperado[campo][0])
		assert_float(valores.back()).is_equal_approx(esperado[campo][1], TOLERANCIA)


func test_mas_en_el_maximo_y_menos_en_el_minimo_no_cambian_nada() -> void:  # AC-CFG-003
	var preferencias := Preferencias.new()
	assert_bool(preferencias.sumar(C.EFECTOS)).is_false()
	assert_float(preferencias.valor(C.EFECTOS)).is_equal_approx(100.0, TOLERANCIA)
	preferencias.poner(C.MUSICA, 0.0)
	assert_bool(preferencias.restar(C.MUSICA)).is_false()
	assert_float(preferencias.valor(C.MUSICA)).is_equal_approx(0.0, TOLERANCIA)


func test_textos_de_uno_coma_cuatro_llega_a_uno_coma_cinco_y_ahi_se_queda() -> void:  # AC-CFG-003
	var preferencias := Preferencias.new()
	preferencias.poner(C.TEXTOS, 1.4)
	assert_bool(preferencias.sumar(C.TEXTOS)).is_true()
	assert_float(preferencias.valor(C.TEXTOS)).is_equal_approx(1.5, TOLERANCIA)
	assert_bool(preferencias.sumar(C.TEXTOS)).is_false()
	assert_float(preferencias.valor(C.TEXTOS)).is_equal_approx(1.5, TOLERANCIA)


func test_sensibilidad_de_medio_baja_a_un_cuarto_y_ahi_se_queda() -> void:  # AC-CFG-003
	var preferencias := Preferencias.new()
	preferencias.poner(C.SENSIBILIDAD, 0.5)
	assert_bool(preferencias.restar(C.SENSIBILIDAD)).is_true()
	assert_float(preferencias.valor(C.SENSIBILIDAD)).is_equal_approx(0.25, TOLERANCIA)
	assert_bool(preferencias.restar(C.SENSIBILIDAD)).is_false()
	assert_float(preferencias.valor(C.SENSIBILIDAD)).is_equal_approx(0.25, TOLERANCIA)


func test_arrastrar_el_brillo_a_123_da_lo_mismo_que_dos_mas() -> void:  # AC-CFG-004
	var arrastrado := Preferencias.new()
	assert_float(arrastrado.poner(C.BRILLO, 123.0)).is_equal_approx(120.0, TOLERANCIA)
	var con_botones := Preferencias.new()
	con_botones.sumar(C.BRILLO)
	con_botones.sumar(C.BRILLO)
	assert_float(arrastrado.valor(C.BRILLO)).is_equal(con_botones.valor(C.BRILLO))


func test_arrastrar_la_sensibilidad_cae_en_el_paso_mas_cercano() -> void:  # AC-CFG-004
	var preferencias := Preferencias.new()
	assert_float(preferencias.poner(C.SENSIBILIDAD, 1.1)).is_equal_approx(1.0, TOLERANCIA)
	assert_float(preferencias.poner(C.SENSIBILIDAD, 1.2)).is_equal_approx(1.25, TOLERANCIA)


func test_arrastrar_mas_alla_de_un_tope_queda_en_el_tope() -> void:  # AC-CFG-004
	var preferencias := Preferencias.new()
	assert_float(preferencias.poner(C.EFECTOS, 140.0)).is_equal_approx(100.0, TOLERANCIA)
	assert_float(preferencias.poner(C.BRILLO, 10.0)).is_equal_approx(50.0, TOLERANCIA)


func test_el_volumen_es_proporcional_a_la_amplitud() -> void:  # AC-CFG-005
	var preferencias := Preferencias.new()
	assert_float(preferencias.decibelios(C.EFECTOS)).is_equal_approx(0.0, TOLERANCIA)
	assert_bool(preferencias.en_silencio(C.EFECTOS)).is_false()
	preferencias.poner(C.EFECTOS, 50.0)
	assert_float(preferencias.decibelios(C.EFECTOS)).is_equal_approx(-6.0206, 1e-3)
	preferencias.poner(C.EFECTOS, 10.0)
	assert_float(preferencias.decibelios(C.EFECTOS)).is_equal_approx(-20.0, 1e-4)
	preferencias.poner(C.EFECTOS, 0.0)
	assert_bool(preferencias.en_silencio(C.EFECTOS)).is_true()
	assert_bool(preferencias.en_silencio(C.MUSICA)).is_false()
	assert_float(preferencias.decibelios(C.MUSICA)).is_equal_approx(0.0, TOLERANCIA)


func test_un_volumen_de_150_en_los_datos_vuelve_a_100() -> void:  # AC-CFG-005
	var preferencias := Preferencias.desde({"efectos": 150.0})
	assert_float(preferencias.valor(C.EFECTOS)).is_equal_approx(100.0, TOLERANCIA)
	assert_float(preferencias.decibelios(C.EFECTOS)).is_less_equal(0.0)


func test_los_datos_vuelven_con_los_cinco_valores_y_su_tipo() -> void:  # AC-CFG-012
	var preferencias := Preferencias.new()
	preferencias.poner(C.MUSICA, 30.0)
	preferencias.poner(C.BRILLO, 130.0)
	preferencias.poner(C.SENSIBILIDAD, 1.75)
	preferencias.poner(C.TEXTOS, 0.9)
	var datos := preferencias.datos()
	assert_int(datos.size()).is_equal(5)
	for clave: String in datos:
		assert_int(typeof(datos[clave])).is_equal(TYPE_FLOAT)
	var leidas := Preferencias.desde(datos)
	for campo: Preferencias.Campo in Preferencias.CAMPOS:
		assert_float(leidas.valor(campo)).is_equal_approx(preferencias.valor(campo), TOLERANCIA)


func test_un_campo_faltante_vuelve_a_su_defecto_y_conserva_los_demas() -> void:  # AC-CFG-014
	var preferencias := Preferencias.desde({"musica": 30.0})
	assert_float(preferencias.valor(C.TEXTOS)).is_equal_approx(1.0, TOLERANCIA)
	assert_float(preferencias.valor(C.MUSICA)).is_equal_approx(30.0, TOLERANCIA)


func test_un_campo_de_otro_tipo_vuelve_a_su_defecto() -> void:  # AC-CFG-014
	var preferencias := Preferencias.desde({"efectos": "fuerte", "musica": true, "brillo": 70})
	assert_float(preferencias.valor(C.EFECTOS)).is_equal_approx(100.0, TOLERANCIA)
	assert_float(preferencias.valor(C.MUSICA)).is_equal_approx(100.0, TOLERANCIA)
	# Un entero sigue siendo un número: un archivo escrito a mano puede traerlo así.
	assert_float(preferencias.valor(C.BRILLO)).is_equal_approx(70.0, TOLERANCIA)


func test_un_valor_fuera_de_rango_vuelve_a_su_defecto() -> void:  # AC-CFG-014
	assert_float(Preferencias.desde({"sensibilidad": 0.0}).valor(C.SENSIBILIDAD)).is_equal(1.0)
	assert_float(Preferencias.desde({"sensibilidad": 2.5}).valor(C.SENSIBILIDAD)).is_equal(1.0)
	assert_float(Preferencias.desde({"brillo": 40.0}).valor(C.BRILLO)).is_equal_approx(
		100.0, TOLERANCIA
	)
	assert_float(Preferencias.desde({"textos": NAN}).valor(C.TEXTOS)).is_equal(1.0)


func test_sin_datos_todas_quedan_en_su_defecto() -> void:  # AC-CFG-014
	var preferencias := Preferencias.desde({})
	var defecto := Preferencias.new()
	for campo: Preferencias.Campo in Preferencias.CAMPOS:
		assert_float(preferencias.valor(campo)).is_equal(defecto.valor(campo))


func test_una_copia_no_comparte_los_valores() -> void:
	var original := Preferencias.new()
	var copia := original.copia()
	copia.poner(C.MUSICA, 0.0)
	assert_float(original.valor(C.MUSICA)).is_equal_approx(100.0, TOLERANCIA)
