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
	var reflexion := _empezada(3, expediente)
	var textos := ReflexionDeCierre.TEXTOS_DE_LA_PRIMERA
	assert_str(reflexion.encabezado()).is_equal(ReflexionDeCierre.ENCABEZADOS[3])
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
	assert_str(reflexion.texto_actual()).is_equal(textos[2])
	assert_int(reflexion.etapa()).is_equal(E.TEXTOS)
	assert_bool(reflexion.continuar(reflexion.identidad_del_texto())).is_true()
	assert_array(_textos(expediente)).is_equal(Array(textos))
	assert_int(reflexion.etapa()).is_equal(E.ESPERA)
	assert_bool(reflexion.avanzar(reflexion.restante())).is_true()
	assert_int(reflexion.etapa()).is_equal(E.TERMINADA)
	assert_bool(reflexion.continuar(reflexion.identidad_del_texto())).is_false()
	assert_int(expediente.mensajes_de_notas().size()).is_equal(textos.size())
	assert_array(Array(expediente.identidades())).is_empty()
	assert_str(expediente.eleccion(3)).is_empty()
	assert_str(expediente.eleccion(4)).is_empty()


func test_cada_texto_tiene_identidad_propia_y_va_a_su_noche() -> void:  # AC-INV-059
	var expediente := _expediente()
	var reflexion := _empezada(3, expediente)
	while reflexion.etapa() == E.TEXTOS:
		reflexion.continuar(reflexion.identidad_del_texto())
	reflexion.avanzar(reflexion.restante())
	var identidades := PackedStringArray()
	for mensaje: Mensaje in expediente.mensajes_de_notas():
		assert_int(mensaje.jornada).is_equal(3)
		assert_bool(identidades.has(mensaje.identidad)).is_false()
		identidades.append(mensaje.identidad)
	assert_int(identidades.size()).is_equal(ReflexionDeCierre.TEXTOS_DE_LA_PRIMERA.size())


func test_antes_de_empezar_no_avanza_ni_elige() -> void:  # AC-INV-061
	var expediente := _expediente()
	var primera := ReflexionDeCierre.para(3, expediente)
	assert_bool(primera.continuar(primera.identidad_del_texto())).is_false()
	assert_int(primera.elegir("2P")).is_equal(ReflexionDeCierre.Eleccion.FUERA_DE_ETAPA)
	var segunda := ReflexionDeCierre.para(4, expediente)
	assert_int(segunda.elegir("2P")).is_equal(ReflexionDeCierre.Eleccion.FUERA_DE_ETAPA)
	assert_array(expediente.mensajes_de_notas()).is_empty()
	assert_str(expediente.eleccion(4)).is_empty()


func test_la_reflexion_retoma_desde_lo_anotado() -> void:  # AC-INV-059
	var expediente := _expediente()
	var reflexion := _empezada(3, expediente)
	reflexion.continuar(reflexion.identidad_del_texto())
	reflexion.continuar(reflexion.identidad_del_texto())
	var retomada := _empezada(3, expediente)
	assert_str(retomada.texto_actual()).is_equal(ReflexionDeCierre.TEXTOS_DE_LA_PRIMERA[2])
	retomada.continuar(retomada.identidad_del_texto())
	assert_object(ReflexionDeCierre.para(3, expediente)).is_null()


func _con_el_tercer_texto_recibido(expediente: Expediente) -> ReflexionDeCierre:
	var reflexion := _empezada(3, expediente)
	while reflexion.etapa() == E.TEXTOS:
		reflexion.continuar(reflexion.identidad_del_texto())
	return reflexion


func test_la_placa_espera_despues_del_tercer_texto() -> void:  # AC-INV-059
	var reflexion := _con_el_tercer_texto_recibido(_expediente())
	var cuadro := 1.0 / 60.0
	assert_int(reflexion.etapa()).is_equal(E.ESPERA)
	assert_float(reflexion.restante()).is_equal(ReflexionDeCierre.ESPERA_DESPUES_DE_LOS_TEXTOS)
	(
		assert_bool(reflexion.avanzar(ReflexionDeCierre.ESPERA_DESPUES_DE_LOS_TEXTOS - cuadro))
		. is_false()
	)
	assert_int(reflexion.etapa()).is_equal(E.ESPERA)
	assert_float(reflexion.restante()).is_equal_approx(cuadro, 0.0001)
	assert_bool(reflexion.avanzar(cuadro)).is_true()
	assert_int(reflexion.etapa()).is_equal(E.TERMINADA)
	assert_bool(reflexion.avanzar(cuadro)).is_false()


func test_en_la_espera_del_tercer_texto_sigue_a_la_vista_y_no_responde() -> void:  # AC-INV-059
	var expediente := _expediente()
	var reflexion := _empezada(3, expediente)
	reflexion.continuar(reflexion.identidad_del_texto())
	reflexion.continuar(reflexion.identidad_del_texto())
	var tercero := reflexion.identidad_del_texto()
	reflexion.continuar(tercero)
	var notas := expediente.mensajes_de_notas().size()
	assert_str(reflexion.texto_actual()).is_equal(ReflexionDeCierre.TEXTOS_DE_LA_PRIMERA.back())
	assert_str(reflexion.identidad_del_texto()).is_empty()
	assert_bool(reflexion.continuar(reflexion.identidad_del_texto())).is_false()
	assert_bool(reflexion.continuar(tercero)).is_false()
	assert_int(reflexion.elegir("2P")).is_equal(ReflexionDeCierre.Eleccion.FUERA_DE_ETAPA)
	assert_int(expediente.mensajes_de_notas().size()).is_equal(notas)
	assert_int(reflexion.etapa()).is_equal(E.ESPERA)
	assert_bool(reflexion.pendiente()).is_false()


func test_un_cuadro_largo_tras_los_textos_termina_la_espera_una_sola_vez() -> void:  # AC-INV-059
	var reflexion := _con_el_tercer_texto_recibido(_expediente())
	assert_bool(reflexion.avanzar(10.0)).is_true()
	assert_bool(reflexion.avanzar(10.0)).is_false()


func test_los_textos_previos_al_tercero_se_reemplazan_sin_espera() -> void:  # AC-INV-059
	var reflexion := _empezada(3, _expediente())
	reflexion.continuar(reflexion.identidad_del_texto())
	assert_int(reflexion.etapa()).is_equal(E.TEXTOS)
	assert_float(reflexion.restante()).is_zero()
	assert_bool(reflexion.avanzar(10.0)).is_false()
	assert_int(reflexion.etapa()).is_equal(E.TEXTOS)


func test_las_dos_esperas_son_valores_distintos() -> void:  # AC-INV-059, AC-INV-062
	var tercera := _con_el_tercer_texto_recibido(_expediente())
	var cuarta := _empezada(4, _expediente())
	cuarta.elegir("2P")
	assert_float(tercera.restante()).is_equal(ReflexionDeCierre.ESPERA_DESPUES_DE_LOS_TEXTOS)
	assert_float(cuarta.restante()).is_equal(ReflexionDeCierre.ESPERA_ANTES_DE_LA_NOCHE)
	assert_float(tercera.restante()).is_not_equal(cuarta.restante())


func test_solo_de_la_tercera_a_la_sexta_reflexionan() -> void:  # AC-INV-058, AC-INV-113
	for jornada: int in [0, 1, 2, 7]:
		assert_object(ReflexionDeCierre.para(jornada, _expediente())).is_null()
	for jornada: int in [3, 4, 5, 6]:
		assert_object(ReflexionDeCierre.para(jornada, _expediente())).is_not_null()


func test_la_espera_retiene_la_quinta_noche() -> void:  # AC-INV-062
	var reflexion := _empezada(4, _expediente())
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
	var reflexion := _empezada(4, _expediente())
	reflexion.elegir("2P")
	assert_bool(reflexion.avanzar(10.0)).is_true()
	assert_bool(reflexion.avanzar(10.0)).is_false()


func test_durante_la_espera_navegar_y_elegir_no_cambian_nada() -> void:  # AC-INV-062
	var expediente := _expediente()
	expediente.registrar("2A")
	expediente.registrar("2B")
	var reflexion := _empezada(4, expediente)
	reflexion.elegir("2A")
	var notas := expediente.mensajes_de_notas().size()
	var mostrada := reflexion.mostrada()
	assert_bool(reflexion.siguiente()).is_false()
	assert_bool(reflexion.anterior()).is_false()
	assert_object(reflexion.mostrada()).is_same(mostrada)
	assert_int(reflexion.elegir("2B")).is_equal(ReflexionDeCierre.Eleccion.REPETIDA)
	assert_int(expediente.mensajes_de_notas().size()).is_equal(notas)
	assert_str(expediente.eleccion(4)).is_equal("2A")


func test_sin_elegir_no_hay_limite_de_tiempo() -> void:  # AC-INV-061
	var primera := _empezada(3, _expediente())
	primera.continuar(primera.identidad_del_texto())
	var segunda := _empezada(4, _expediente())
	for reflexion: ReflexionDeCierre in [primera, segunda]:
		var etapa := reflexion.etapa()
		assert_bool(reflexion.avanzar(600.0)).is_false()
		assert_int(reflexion.etapa()).is_equal(etapa)
	assert_str(primera.texto_actual()).is_equal(ReflexionDeCierre.TEXTOS_DE_LA_PRIMERA[1])


func _con_la_cuarta_elegida(elegida: String) -> Expediente:
	var expediente := _expediente()
	expediente.registrar(elegida)
	expediente.elegir(4, elegida)
	return expediente


func _identidades(opciones: Array[Hipotesis]) -> Array[String]:
	var identidades: Array[String] = []
	for opcion: Hipotesis in opciones:
		identidades.append(opcion.identidad)
	return identidades


func test_la_quinta_tiene_su_encabezado_y_las_otras_no_cambian() -> void:  # AC-INV-110, AC-INV-113
	var encabezado := _empezada(5, _expediente()).encabezado()
	assert_str(encabezado).is_not_empty()
	assert_str(encabezado).is_not_equal(ReflexionDeCierre.ENCABEZADOS[3])
	assert_str(encabezado).is_not_equal(ReflexionDeCierre.ENCABEZADOS[4])
	assert_str(_empezada(3, _expediente()).encabezado()).is_equal(ReflexionDeCierre.ENCABEZADOS[3])
	assert_str(_empezada(4, _expediente()).encabezado()).is_equal(ReflexionDeCierre.ENCABEZADOS[4])


func test_sin_la_5b_la_quinta_ofrece_solo_la_5p_con_o_sin_antecedentes() -> void:  # AC-INV-110
	for expediente: Expediente in [
		_expediente(), _con_la_cuarta_elegida("2A"), _con_la_cuarta_elegida("2B")
	]:
		var reflexion := _empezada(5, expediente)
		assert_int(reflexion.etapa()).is_equal(E.ELEGIR)
		assert_array(_identidades(reflexion.opciones())).is_equal(["5P"])
		assert_str(reflexion.mostrada().titulo).is_equal("NO HAY PROBLEMA")
		assert_bool(reflexion.siguiente()).is_false()
		assert_bool(reflexion.anterior()).is_false()


func test_con_la_5b_la_quinta_ofrece_solo_la_5b() -> void:  # AC-INV-111
	var expediente := _con_la_cuarta_elegida("2A")
	assert_int(expediente.registrar("5B")).is_equal(Expediente.Resultado.ANOTADA)
	var reflexion := _empezada(5, expediente)
	assert_array(_identidades(reflexion.opciones())).is_equal(["5B"])
	assert_int(reflexion.elegir("5P")).is_equal(ReflexionDeCierre.Eleccion.NO_DISPONIBLE)
	assert_str(expediente.eleccion(5)).is_empty()
	assert_int(reflexion.etapa()).is_equal(E.ELEGIR)
	var sin_la_5b := _empezada(5, _con_la_cuarta_elegida("2A"))
	assert_int(sin_la_5b.elegir("5B")).is_equal(ReflexionDeCierre.Eleccion.NO_DISPONIBLE)


func test_elegir_en_la_quinta_anota_una_vez_y_la_espera_retiene_la_sexta() -> void:  # AC-INV-112
	var expediente := _con_la_cuarta_elegida("2A")
	var reflexion := _empezada(5, expediente)
	var texto := reflexion.mostrada().texto
	var notas := expediente.mensajes_de_notas().size()
	assert_bool(reflexion.avanzar(600.0)).is_false()
	assert_int(reflexion.etapa()).is_equal(E.ELEGIR)
	assert_int(reflexion.elegir("5P")).is_equal(ReflexionDeCierre.Eleccion.ACEPTADA)
	assert_str(expediente.eleccion(5)).is_equal("5P")
	assert_int(expediente.mensajes_de_notas().size()).is_equal(notas + 1)
	assert_str(expediente.mensajes_de_notas().back().texto).is_equal(texto)
	assert_int(reflexion.elegir("5P")).is_equal(ReflexionDeCierre.Eleccion.REPETIDA)
	assert_int(expediente.mensajes_de_notas().size()).is_equal(notas + 1)
	var cuadro := 1.0 / 60.0
	assert_bool(reflexion.avanzar(ReflexionDeCierre.ESPERA_ANTES_DE_LA_NOCHE - cuadro)).is_false()
	assert_bool(reflexion.avanzar(cuadro)).is_true()
	assert_int(reflexion.etapa()).is_equal(E.TERMINADA)
	assert_bool(reflexion.avanzar(10.0)).is_false()


func test_la_quinta_retomada_sin_elegir_vuelve_a_la_eleccion() -> void:  # AC-INV-112
	var expediente := _con_la_cuarta_elegida("2A")
	var antes := _empezada(5, expediente)
	assert_bool(antes.pendiente()).is_true()
	var retomada := _empezada(5, expediente)
	assert_int(retomada.etapa()).is_equal(E.ELEGIR)
	retomada.elegir("5P")
	assert_object(ReflexionDeCierre.para(5, expediente)).is_null()
