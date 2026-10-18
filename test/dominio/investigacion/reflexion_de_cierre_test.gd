extends GdUnitTestSuite

const E := ReflexionDeCierre.Etapa


func _expediente() -> Expediente:
	return Expediente.new(CasoDeInvestigacion.de_la_partida())


func _empezada(jornada: int, expediente: Expediente) -> ReflexionDeCierre:
	var reflexion := ReflexionDeCierre.para(jornada, expediente)
	reflexion.empezar()
	return reflexion


func _textos(expediente: Expediente) -> Array[String]:
	var textos: Array[String] = []
	for mensaje: Mensaje in expediente.mensajes_de_notas():
		textos.append(mensaje.texto)
	return textos


func test_tres_textos_tres_notas() -> void:  # AC-INV-059
	var expediente := _expediente()
	var reflexion := _empezada(1, expediente)
	var textos := ReflexionDeCierre.TEXTOS_DE_LA_PRIMERA
	assert_str(reflexion.encabezado()).is_equal(ReflexionDeCierre.ENCABEZADOS[1])
	assert_str(reflexion.texto_actual()).is_equal(textos[0])
	var primero := reflexion.identidad_del_texto()
	assert_bool(reflexion.continuar(primero)).is_true()
	assert_array(_textos(expediente)).is_equal([textos[0]])
	assert_str(reflexion.texto_actual()).is_equal(textos[1])
	assert_int(reflexion.etapa()).is_equal(E.TEXTOS)
	assert_bool(reflexion.continuar(primero)).is_false()
	assert_array(_textos(expediente)).is_equal([textos[0]])
	assert_str(reflexion.texto_actual()).is_equal(textos[1])
	assert_bool(reflexion.continuar(reflexion.identidad_del_texto())).is_true()
	assert_bool(reflexion.continuar(reflexion.identidad_del_texto())).is_true()
	assert_array(_textos(expediente)).is_equal(Array(textos))
	assert_int(reflexion.etapa()).is_equal(E.TERMINADA)
	assert_bool(reflexion.continuar(reflexion.identidad_del_texto())).is_false()
	assert_int(expediente.mensajes_de_notas().size()).is_equal(textos.size())
	assert_array(Array(expediente.identidades())).is_empty()
	assert_str(expediente.eleccion(1)).is_empty()
	assert_str(expediente.eleccion(2)).is_empty()


func test_cada_texto_tiene_identidad_propia_y_va_a_la_primera_noche() -> void:  # AC-INV-059
	var expediente := _expediente()
	var reflexion := _empezada(1, expediente)
	while reflexion.etapa() == E.TEXTOS:
		reflexion.continuar(reflexion.identidad_del_texto())
	var identidades := PackedStringArray()
	for mensaje: Mensaje in expediente.mensajes_de_notas():
		assert_int(mensaje.jornada).is_equal(1)
		assert_bool(identidades.has(mensaje.identidad)).is_false()
		identidades.append(mensaje.identidad)
	assert_int(identidades.size()).is_equal(ReflexionDeCierre.TEXTOS_DE_LA_PRIMERA.size())


func test_antes_de_empezar_no_avanza_ni_elige() -> void:  # AC-INV-061
	var expediente := _expediente()
	var primera := ReflexionDeCierre.para(1, expediente)
	assert_bool(primera.continuar(primera.identidad_del_texto())).is_false()
	assert_int(primera.elegir("2P")).is_equal(ReflexionDeCierre.Eleccion.FUERA_DE_ETAPA)
	var segunda := ReflexionDeCierre.para(2, expediente)
	assert_int(segunda.elegir("2P")).is_equal(ReflexionDeCierre.Eleccion.FUERA_DE_ETAPA)
	assert_array(expediente.mensajes_de_notas()).is_empty()
	assert_str(expediente.eleccion(2)).is_empty()


func test_la_reflexion_retoma_desde_lo_anotado() -> void:  # AC-INV-059
	var expediente := _expediente()
	var reflexion := _empezada(1, expediente)
	reflexion.continuar(reflexion.identidad_del_texto())
	reflexion.continuar(reflexion.identidad_del_texto())
	var retomada := _empezada(1, expediente)
	assert_str(retomada.texto_actual()).is_equal(ReflexionDeCierre.TEXTOS_DE_LA_PRIMERA[2])
	retomada.continuar(retomada.identidad_del_texto())
	assert_object(ReflexionDeCierre.para(1, expediente)).is_null()


func test_solo_las_dos_primeras_jornadas_reflexionan() -> void:  # AC-INV-058
	for jornada: int in [0, 3, 4, 5]:
		assert_object(ReflexionDeCierre.para(jornada, _expediente())).is_null()


func test_la_espera_retiene_la_tercera_noche() -> void:  # AC-INV-062
	var reflexion := _empezada(2, _expediente())
	assert_bool(reflexion.avanzar(10.0)).is_false()
	assert_int(reflexion.elegir("2P")).is_equal(ReflexionDeCierre.Eleccion.ACEPTADA)
	assert_int(reflexion.etapa()).is_equal(E.ESPERA)
	var cuadro := 1.0 / 60.0
	assert_bool(reflexion.avanzar(ReflexionDeCierre.ESPERA_ANTES_DE_LA_NOCHE - cuadro)).is_false()
	assert_int(reflexion.etapa()).is_equal(E.ESPERA)
	assert_float(reflexion.restante()).is_equal_approx(cuadro, 0.0001)
	assert_bool(reflexion.avanzar(0.0)).is_false()
	assert_bool(reflexion.avanzar(cuadro)).is_true()
	assert_int(reflexion.etapa()).is_equal(E.TERMINADA)
	assert_bool(reflexion.avanzar(cuadro)).is_false()


func test_un_cuadro_largo_termina_la_espera_una_sola_vez() -> void:  # AC-INV-062
	var reflexion := _empezada(2, _expediente())
	reflexion.elegir("2P")
	assert_bool(reflexion.avanzar(10.0)).is_true()
	assert_bool(reflexion.avanzar(10.0)).is_false()


func test_durante_la_espera_navegar_y_elegir_no_cambian_nada() -> void:  # AC-INV-062
	var expediente := _expediente()
	expediente.registrar("2A")
	expediente.registrar("2B")
	var reflexion := _empezada(2, expediente)
	reflexion.elegir("2A")
	var notas := expediente.mensajes_de_notas().size()
	var mostrada := reflexion.mostrada()
	assert_bool(reflexion.siguiente()).is_false()
	assert_bool(reflexion.anterior()).is_false()
	assert_object(reflexion.mostrada()).is_same(mostrada)
	assert_int(reflexion.elegir("2B")).is_equal(ReflexionDeCierre.Eleccion.REPETIDA)
	assert_int(expediente.mensajes_de_notas().size()).is_equal(notas)
	assert_str(expediente.eleccion(2)).is_equal("2A")


func test_sin_elegir_no_hay_limite_de_tiempo() -> void:  # AC-INV-061
	var primera := _empezada(1, _expediente())
	primera.continuar(primera.identidad_del_texto())
	var segunda := _empezada(2, _expediente())
	for reflexion: ReflexionDeCierre in [primera, segunda]:
		var etapa := reflexion.etapa()
		assert_bool(reflexion.avanzar(600.0)).is_false()
		assert_int(reflexion.etapa()).is_equal(etapa)
	assert_str(primera.texto_actual()).is_equal(ReflexionDeCierre.TEXTOS_DE_LA_PRIMERA[1])
