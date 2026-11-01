## El sobre del guardado, saneado sin tocar disco.
extends GdUnitTestSuite

const JORNADA := "jornada"
const MEDIOS := "medios"
const VERSION := "version"


func _completo() -> Dictionary:
	return {
		VERSION: PartidaSerializada.VERSION,
		JORNADA: ReglasDeLaPartida.PRIMERA_JORNADA + 2,
		MEDIOS: Reglas.APERCIBIMIENTOS_POR_AVISO * Reglas.MEDIOS_POR_APERCIBIMIENTO,
		"fallas": {"REPONER": 2},
		"llamados": {"PAPEL_EN_EL_INODORO": 1},
		"noches_sin_sumar": 1,
		"devoluciones": ["Buen día!", "Hola"],
		"mopa_secada": true,
		"expediente": ["2B"],
		"notas": [{"texto": "Nota", "identidad": "NOTA_2B_TEXTO", "jornada": 2, "orden": 1}],
		"cierre_pendiente": 2,
		"elecciones": {2: "2B"},
		"noches_de_prueba": {1: {"mal_atendidos": 1, "sin_cumplir": ["REGISTRAR"]}},
		"apercibimientos_de_la_prueba": 3,
		"ultima_de_la_prueba_completa": true,
		"semilla": 1234,
		"poses_de_las_cajas":
		{Producto.Id.MAROLINI: Transform3D(Basis.IDENTITY, Vector3(1.5, 2.0, 3.25))},
	}


func test_cada_campo_tiene_su_clave() -> void:
	assert_str(PartidaSerializada.clave(PartidaSerializada.Campo.JORNADA)).is_equal(JORNADA)
	assert_str(PartidaSerializada.clave(PartidaSerializada.Campo.MEDIOS)).is_equal(MEDIOS)
	assert_str(PartidaSerializada.clave(PartidaSerializada.Campo.FALLAS)).is_equal("fallas")
	assert_str(PartidaSerializada.clave(PartidaSerializada.Campo.LLAMADOS)).is_equal("llamados")
	assert_str(PartidaSerializada.clave(PartidaSerializada.Campo.NOCHES_SIN_SUMAR)).is_equal(
		"noches_sin_sumar"
	)
	assert_str(PartidaSerializada.clave(PartidaSerializada.Campo.DEVOLUCIONES)).is_equal(
		"devoluciones"
	)


func test_un_guardado_completo_vuelve_igual() -> void:  # AC-SAV-006
	var saneado := PartidaSerializada.sanear(_completo())
	assert_dict(saneado).is_equal(_completo())
	for clave: String in saneado:
		assert_int(typeof(saneado[clave])).is_equal(typeof(_completo()[clave]))


func test_el_campo_que_falta_vuelve_con_su_defecto() -> void:  # AC-SAV-007
	var saneado := PartidaSerializada.sanear({})
	assert_dict(saneado).contains_keys([VERSION, JORNADA, MEDIOS])
	assert_int(saneado[JORNADA]).is_equal(ReglasDeLaPartida.PRIMERA_JORNADA)
	assert_int(saneado[MEDIOS]).is_equal(Legajo.new().medios())
	var sin_jornada := _completo()
	sin_jornada.erase(JORNADA)
	saneado = PartidaSerializada.sanear(sin_jornada)
	assert_int(saneado[JORNADA]).is_equal(ReglasDeLaPartida.PRIMERA_JORNADA)
	assert_int(saneado[MEDIOS]).is_equal(
		Reglas.APERCIBIMIENTOS_POR_AVISO * Reglas.MEDIOS_POR_APERCIBIMIENTO
	)


func test_el_tipo_equivocado_vuelve_con_su_defecto() -> void:  # AC-SAV-008
	var mal_tipado := _completo()
	mal_tipado[JORNADA] = "3"
	mal_tipado[MEDIOS] = 2.5
	var saneado := PartidaSerializada.sanear(mal_tipado)
	assert_int(saneado[JORNADA]).is_equal(ReglasDeLaPartida.PRIMERA_JORNADA)
	assert_int(typeof(saneado[JORNADA])).is_equal(TYPE_INT)
	assert_int(saneado[MEDIOS]).is_equal(Legajo.new().medios())
	assert_int(typeof(saneado[MEDIOS])).is_equal(TYPE_INT)


func test_solo_la_version_actual_es_legible() -> void:  # AC-SAV-009
	var anterior := _completo()
	anterior[VERSION] = PartidaSerializada.VERSION - 1
	var sin_version := _completo()
	sin_version.erase(VERSION)
	var posterior := _completo()
	posterior[VERSION] = PartidaSerializada.VERSION + 1
	assert_bool(PartidaSerializada.legible(_completo())).is_true()
	assert_bool(PartidaSerializada.legible(anterior)).is_false()
	assert_bool(PartidaSerializada.legible(sin_version)).is_false()
	assert_bool(PartidaSerializada.legible(posterior)).is_false()


func test_un_guardado_sin_cuentas_retoma_limpio() -> void:  # AC-SAV-025
	var datos := {
		PartidaSerializada.clave(PartidaSerializada.Campo.JORNADA): 3,
		PartidaSerializada.clave(PartidaSerializada.Campo.MEDIOS): 3,
	}
	var partida := Partida.desde(datos)
	assert_int(partida.jornada()).is_equal(3)
	assert_int(partida.medios()).is_equal(3)
	assert_bool(partida.antecedentes().hubo_llamados()).is_false()
	assert_int(partida.antecedentes().noches_sin_sumar()).is_zero()
	assert_int(partida.antecedentes().fallas(Tarea.Tipo.REPONER)).is_zero()
	assert_array(partida.mensajes_del_jefe()).is_empty()
	datos[PartidaSerializada.clave(PartidaSerializada.Campo.FALLAS)] = ["no", "es", "diccionario"]
	datos[PartidaSerializada.clave(PartidaSerializada.Campo.DEVOLUCIONES)] = 7
	partida = Partida.desde(datos)
	assert_int(partida.antecedentes().fallas(Tarea.Tipo.REPONER)).is_zero()
	assert_array(partida.mensajes_del_jefe()).is_empty()
	datos[PartidaSerializada.clave(PartidaSerializada.Campo.FALLAS)] = {"VOLAR": 2, "REPONER": 1}
	partida = Partida.desde(datos)
	assert_int(partida.antecedentes().fallas(Tarea.Tipo.REPONER)).is_equal(1)


func test_las_poses_se_restauran_y_lo_que_no_es_una_pose_se_ignora() -> void:  # AC-SAV-034
	var clave := PartidaSerializada.clave(PartidaSerializada.Campo.POSES_DE_LAS_CAJAS)
	var pose := Transform3D(Basis(Vector3.UP, 0.5), Vector3(1.0, 2.0, 3.0))
	var partida := (
		Partida
		. desde(
			{
				JORNADA: 3,
				clave:
				{
					Producto.Id.MAROLINI: pose,
					Producto.Id.UAKALAS: "texto",
					9999: pose,
					"MAROLINI": pose,
				},
			}
		)
	)
	assert_int(partida.jornada()).is_equal(3)
	assert_array(partida.poses_de_las_cajas.keys()).contains_exactly([Producto.Id.MAROLINI])
	assert_bool(partida.poses_de_las_cajas[Producto.Id.MAROLINI].is_equal_approx(pose)).is_true()


func test_sin_el_campo_o_con_otro_tipo_ninguna_caja_trae_pose() -> void:  # AC-SAV-034
	var clave := PartidaSerializada.clave(PartidaSerializada.Campo.POSES_DE_LAS_CAJAS)
	assert_dict(PartidaSerializada.sanear({})[clave]).is_empty()
	for crudo: Variant in [7, "poses", [Transform3D.IDENTITY]]:
		var partida := Partida.desde({JORNADA: 3, clave: crudo})
		assert_int(partida.jornada()).is_equal(3)
		assert_dict(partida.poses_de_las_cajas).is_empty()
	assert_dict(Partida.nueva().poses_de_las_cajas).is_empty()
