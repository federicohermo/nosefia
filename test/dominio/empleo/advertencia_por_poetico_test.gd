extends GdUnitTestSuite

const T := Tarea.Tipo
const TENIDO := ReglasDeLaLimpieza.Resultado.BALDE_TENIDO
const VACIO := ReglasDeLaLimpieza.Resultado.BALDE_VACIO


func _cerrar(
	jornada: int, medios: int, sin_cumplir: Array[T], poetico: ReglasDeLaLimpieza.Resultado
) -> Partida:
	var partida := Partida.desde({"jornada": jornada, "medios": medios})
	partida.abrir_la_jornada()
	partida.anotar_uso_de_poetico(AnomaliasDeLaJornada.id_de_poetico(), poetico, true)
	var cumplidas := 0
	for tarea: Tarea in partida.obligatorias():
		if not sin_cumplir.has(tarea.tipo()):
			tarea.completar()
			cumplidas += 1
	partida.cerrar_la_jornada(cumplidas)
	return partida


func _cuantas(mensajes: PackedStringArray, texto: String) -> int:
	return Array(mensajes).count(texto)


func test_poetico_justo_debajo_del_despido_y_en_el_despido() -> void:  # AC-EMP-071
	var debajo := _cerrar(AnomaliasDeLaJornada.JORNADA_SIN_AZUL, 7, [], TENIDO).mensajes_del_jefe()
	assert_int(_cuantas(debajo, DevolucionDelJefe.POETICO)).is_equal(1)
	assert_int(_cuantas(debajo, DevolucionDelJefe.POETICO_EN_EL_DESPIDO)).is_zero()
	for texto: String in DevolucionDelJefe.TAREAS[T.LIMPIAR]:
		assert_int(_cuantas(debajo, texto)).is_zero()
	var en_el_despido := (
		_cerrar(AnomaliasDeLaJornada.JORNADA_SIN_AZUL, 8, [], TENIDO).mensajes_del_jefe()
	)
	assert_int(_cuantas(en_el_despido, DevolucionDelJefe.POETICO_EN_EL_DESPIDO)).is_equal(1)
	assert_int(_cuantas(en_el_despido, DevolucionDelJefe.POETICO)).is_zero()
	assert_str(en_el_despido[-1]).is_equal(DevolucionDelJefe.CIERRE_DEL_DESPIDO)


func test_la_advertencia_va_entre_la_tarea_4_y_la_tarea_5() -> void:  # AC-EMP-071
	var mensajes := (
		_cerrar(AnomaliasDeLaJornada.JORNADA_SIN_AZUL, 0, [T.LIMPIAR, T.SACAR_LA_BASURA], TENIDO)
		. mensajes_del_jefe()
	)
	var tarea_4: String = DevolucionDelJefe.TAREAS[T.LIMPIAR][0]
	var tarea_5: String = DevolucionDelJefe.PARTICULARES[AnomaliasDeLaJornada.JORNADA_SIN_AZUL]
	var advertencia := mensajes.find(DevolucionDelJefe.POETICO)
	assert_int(mensajes.find(tarea_4)).is_greater(0)
	assert_int(advertencia).is_equal(mensajes.find(tarea_4) + 1)
	assert_int(mensajes.find(tarea_5)).is_equal(advertencia + 1)
	for texto: String in [tarea_4, DevolucionDelJefe.POETICO, tarea_5]:
		assert_int(_cuantas(mensajes, texto)).is_equal(1)


func test_sin_uso_aceptado_o_en_otra_jornada_no_hay_advertencia() -> void:  # AC-EMP-071
	for partida: Partida in [
		_cerrar(AnomaliasDeLaJornada.JORNADA_SIN_AZUL, 0, [], VACIO),
		_cerrar(AnomaliasDeLaJornada.JORNADA_SIN_AZUL + 1, 0, [], TENIDO)
	]:
		var mensajes := partida.mensajes_del_jefe()
		assert_int(_cuantas(mensajes, DevolucionDelJefe.POETICO)).is_zero()
		assert_int(_cuantas(mensajes, DevolucionDelJefe.POETICO_EN_EL_DESPIDO)).is_zero()


func test_la_advertencia_no_cambia_medios_banda_ni_final() -> void:  # AC-EMP-071
	for medios: int in [0, 7, 8]:
		var con := _cerrar(AnomaliasDeLaJornada.JORNADA_SIN_AZUL, medios, [T.LIMPIAR], TENIDO)
		var sin := _cerrar(AnomaliasDeLaJornada.JORNADA_SIN_AZUL, medios, [T.LIMPIAR], VACIO)
		assert_int(con.medios()).is_equal(sin.medios())
		assert_int(con.final()).is_equal(sin.final())
		assert_int(con.jornada()).is_equal(sin.jornada())
		var sin_advertencia := Array(con.mensajes_del_jefe())
		sin_advertencia.erase(DevolucionDelJefe.POETICO)
		sin_advertencia.erase(DevolucionDelJefe.POETICO_EN_EL_DESPIDO)
		assert_int(sin_advertencia.size()).is_equal(con.mensajes_del_jefe().size() - 1)
		assert_array(sin_advertencia).is_equal(Array(sin.mensajes_del_jefe()))
