## El checkpoint del cierre: la reflexión pendiente, el expediente, las notas y la elección cruzan
## la sesión por los datos del guardado, sin tocar disco.
extends GdUnitTestSuite

const C := PartidaSerializada.Campo


func _cerrada(jornada: int, medios: int, pistas: Array[String]) -> Partida:
	var partida := Partida.desde({"jornada": jornada, "medios": medios})
	partida.abrir_la_jornada()
	for pista: String in pistas:
		partida.expediente.registrar(pista)
	for tarea: Tarea in partida.obligatorias():
		tarea.completar()
	partida.cerrar_la_jornada(partida.obligatorias().size())
	return partida


func _por_disco(partida: Partida) -> Dictionary:
	return PartidaSerializada.sanear(str_to_var(var_to_str(PoliticaDeGuardado.datos(partida))))


func _clave(campo: C) -> String:
	return PartidaSerializada.clave(campo)


func _identidades(opciones: Array[Hipotesis]) -> Array[String]:
	var identidades: Array[String] = []
	for opcion: Hipotesis in opciones:
		identidades.append(opcion.identidad)
	return identidades


func test_salir_antes_de_elegir_conserva_la_eleccion_pendiente() -> void:  # AC-SAV-029
	var partida := _cerrada(2, 7, ["2A"])
	assert_object(partida.reflexion).is_not_null()
	var datos := _por_disco(partida)
	assert_int(datos[_clave(C.CIERRE_PENDIENTE)]).is_equal(2)
	var retomada := Partida.desde(datos)
	assert_int(retomada.jornada()).is_equal(3)
	assert_int(retomada.medios()).is_equal(7)
	var reflexion := retomada.reflexion
	assert_object(reflexion).is_not_null()
	if reflexion == null:
		return
	reflexion.empezar()
	assert_array(_identidades(reflexion.opciones())).is_equal(["2A"])
	assert_int(reflexion.elegir("2A")).is_equal(ReflexionDeCierre.Eleccion.ACEPTADA)
	var elegida := _por_disco(retomada)
	assert_int(elegida[_clave(C.CIERRE_PENDIENTE)]).is_zero()
	assert_dict(elegida[_clave(C.ELECCIONES)]).is_equal({2: "2A"})
	assert_int(elegida[_clave(C.MEDIOS)]).is_equal(7)


func test_retomar_despues_de_elegir_no_repite_eleccion_ni_nota() -> void:  # AC-SAV-030
	var partida := _cerrada(2, 0, ["2B"])
	partida.reflexion.empezar()
	partida.reflexion.elegir("2B")
	var retomada := Partida.desde(_por_disco(partida))
	assert_object(retomada.reflexion).is_null()
	assert_str(retomada.expediente.eleccion(2)).is_equal("2B")
	var hipotesis := 0
	for nota: Mensaje in retomada.expediente.mensajes_de_notas():
		if nota.texto == retomada.expediente.hipotesis_para(2)[0].texto:
			hipotesis += 1
	assert_int(hipotesis).is_equal(1)
	assert_int(retomada.expediente.mensajes_de_notas().size()).is_equal(3)


func test_retomar_a_mitad_de_la_primera_reflexion() -> void:  # AC-SAV-030
	var partida := _cerrada(1, 0, [])
	var reflexion := partida.reflexion
	reflexion.empezar()
	reflexion.continuar(reflexion.identidad_del_texto())
	reflexion.continuar(reflexion.identidad_del_texto())
	var datos := _por_disco(partida)
	assert_int(datos[_clave(C.CIERRE_PENDIENTE)]).is_equal(1)
	var retomada := Partida.desde(datos)
	var textos := ReflexionDeCierre.TEXTOS_DE_LA_PRIMERA
	assert_int(retomada.expediente.mensajes_de_notas().size()).is_equal(2)
	var pendiente := retomada.reflexion
	assert_object(pendiente).is_not_null()
	if pendiente == null:
		return
	pendiente.empezar()
	assert_str(pendiente.texto_actual()).is_equal(textos[2])
	assert_bool(pendiente.continuar(pendiente.identidad_del_texto())).is_true()
	var notas: Array[String] = []
	for nota: Mensaje in retomada.expediente.mensajes_de_notas():
		notas.append(nota.texto)
	assert_array(notas).is_equal(Array(textos))
	assert_int(_por_disco(retomada)[_clave(C.CIERRE_PENDIENTE)]).is_zero()


func test_un_guardado_sin_los_campos_del_cierre_abre_la_jornada() -> void:  # AC-SAV-031
	var retomada := Partida.desde(PartidaSerializada.sanear({"jornada": 3, "medios": 5}))
	assert_object(retomada.reflexion).is_null()
	assert_array(Array(retomada.expediente.identidades())).is_empty()
	assert_array(retomada.expediente.mensajes_de_notas()).is_empty()
	assert_dict(retomada.expediente.elecciones()).is_empty()
	var mal_tipado := (
		Partida
		. desde(
			(
				PartidaSerializada
				. sanear(
					{
						"jornada": 3,
						"medios": 5,
						_clave(C.CIERRE_PENDIENTE): "2",
						_clave(C.EXPEDIENTE): 5,
						_clave(C.NOTAS): "notas",
						_clave(C.ELECCIONES): ["2A"],
						_clave(C.DEVOLUCIONES): ["Hola"],
					}
				)
			)
		)
	)
	assert_object(mal_tipado.reflexion).is_null()
	assert_array(Array(mal_tipado.expediente.identidades())).is_empty()
	assert_array(mal_tipado.expediente.mensajes_de_notas()).is_empty()
	assert_int(mal_tipado.jornada()).is_equal(3)
	assert_int(mal_tipado.medios()).is_equal(5)
	assert_array(Array(mal_tipado.mensajes_del_jefe())).is_equal(["Hola"])


func test_lo_ajeno_del_expediente_se_descarta_y_se_vuelve_a_ofrecer() -> void:  # AC-SAV-031
	var retomada := (
		Partida
		. desde(
			(
				PartidaSerializada
				. sanear(
					{
						"jornada": 3,
						_clave(C.CIERRE_PENDIENTE): 2,
						_clave(C.EXPEDIENTE): ["2B", "desconocida", "2B", 7],
						_clave(C.ELECCIONES): {2: "2A"},
						_clave(C.NOTAS):
						[{"texto": "inventada", "identidad": "X", "jornada": 1, "orden": 0}],
					}
				)
			)
		)
	)
	assert_array(Array(retomada.expediente.identidades())).is_equal(["2B"])
	assert_str(retomada.expediente.eleccion(2)).is_empty()
	for nota: Mensaje in retomada.expediente.mensajes_de_notas():
		assert_str(nota.texto).is_not_equal("inventada")
	var reflexion := retomada.reflexion
	assert_object(reflexion).is_not_null()
	if reflexion == null:
		return
	reflexion.empezar()
	assert_array(_identidades(reflexion.opciones())).is_equal(["2B"])


func test_un_cierre_pendiente_de_otra_noche_no_se_ofrece() -> void:  # AC-SAV-031
	for pendiente: int in [1, 3, -1]:
		var datos := PartidaSerializada.sanear(
			{"jornada": 3, _clave(C.CIERRE_PENDIENTE): pendiente}
		)
		assert_object(Partida.desde(datos).reflexion).is_null()


func test_el_despido_gana_sobre_la_reflexion() -> void:  # AC-SAV-032, AC-INV-058
	var despedida := _cerrada(2, 8, ["2A"])
	assert_bool(despedida.terminada()).is_true()
	assert_object(despedida.reflexion).is_null()
	assert_int(PoliticaDeGuardado.accion(despedida)).is_equal(PoliticaDeGuardado.Accion.BORRAR)


func test_solo_las_dos_primeras_noches_dejan_reflexion() -> void:  # AC-INV-058
	assert_object(_cerrada(1, 0, []).reflexion).is_not_null()
	assert_object(_cerrada(2, 0, []).reflexion).is_not_null()
	assert_object(_cerrada(3, 0, []).reflexion).is_null()
	assert_object(_cerrada(4, 0, []).reflexion).is_null()
