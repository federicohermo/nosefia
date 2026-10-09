## Los motivos de una sola noche se suman a la banda y conservan medios exactos.
extends GdUnitTestSuite


func test_las_bandas_suman_medios_y_no_sustituyen_llamados() -> void:  # AC-EMP-017
	for cumplidas: int in [0, 3, 5]:
		var legajo := Legajo.new()
		legajo.registrar(cumplidas, 5, 2)
		var esperado: int = {0: 6, 3: 4, 5: 2}[cumplidas]
		assert_int(legajo.medios()).is_equal(esperado)


func test_motivos_repetidos_y_distintos_se_cuentan_por_noche() -> void:  # AC-EMP-017
	var partida := Partida.nueva()
	partida.abrir_la_jornada()
	partida.anotar_llamado(Partida.Llamado.LOCAL_DESORDENADO)
	partida.anotar_llamado(Partida.Llamado.LOCAL_DESORDENADO)
	partida.cerrar_la_jornada(5)
	assert_int(partida.medios()).is_equal(1)
	partida.abrir_la_jornada()
	partida.anotar_llamado(Partida.Llamado.LOCAL_DESORDENADO)
	partida.anotar_llamado(Partida.Llamado.OBJETO_AFUERA)
	partida.cerrar_la_jornada(5)
	assert_int(partida.medios()).is_equal(3)


func test_fuera_de_la_jornada_abierta_no_guarda_motivos() -> void:  # AC-EMP-018
	var partida := Partida.nueva()
	partida.anotar_llamado(Partida.Llamado.OBJETO_AFUERA)
	partida.abrir_la_jornada()
	partida.cerrar_la_jornada(5)
	assert_int(partida.medios()).is_zero()
	partida.anotar_llamado(Partida.Llamado.OBJETO_AFUERA)
	partida.abrir_la_jornada()
	partida.anotar_llamado(Partida.Llamado.LOCAL_DESORDENADO)
	partida.cerrar_la_jornada(5)
	partida.cerrar_la_jornada(0)
	assert_int(partida.medios()).is_equal(1)
	partida.abrir_la_jornada()
	partida.cerrar_la_jornada(5)
	assert_int(partida.medios()).is_equal(1)


func test_siete_medios_no_despiden_y_ocho_si() -> void:  # AC-EMP-019
	for inicial: int in [6, 7]:
		var legajo := Legajo.con_medios(inicial)
		legajo.registrar(5, 5, 1)
		assert_int(legajo.medios()).is_equal(inicial + 1)
		assert_bool(legajo.despedido()).is_equal(inicial == 7)


func test_restaurado_siete_con_impecable_conserva_siete() -> void:  # AC-EMP-020
	var legajo := Legajo.con_medios(7)
	legajo.registrar(5, 5)
	assert_int(legajo.medios()).is_equal(7)


func test_reanudar_sanea_medios_sin_migrar_la_clave_antigua() -> void:  # AC-EMP-020
	for crudo: Dictionary in [{}, {"medios": 7.0}, {"medios": 7}]:
		crudo["jornada"] = 3
		var partida := Partida.desde(crudo)
		assert_int(partida.jornada()).is_equal(3)
		assert_int(partida.medios()).is_equal(7 if typeof(crudo.get("medios")) == TYPE_INT else 0)


func test_la_lectura_entera_del_comentario_descarta_solo_el_medio() -> void:  # AC-EMP-021
	assert_int(Legajo.con_medios(7).apercibimientos()).is_equal(3)
	assert_int(Legajo.con_medios(6).apercibimientos()).is_equal(3)


func test_la_quinta_con_siete_cumple_y_con_un_motivo_despide() -> void:  # AC-EMP-022
	for llamado: bool in [false, true]:
		var partida := Partida.new(Legajo.con_medios(7))
		for noche: int in 5:
			partida.abrir_la_jornada()
			if noche == 4 and llamado:
				partida.anotar_llamado(Partida.Llamado.OBJETO_AFUERA)
			partida.cerrar_la_jornada(5)
		var final := Partida.Final.DESPEDIDO if llamado else Partida.Final.CONTRATO_CUMPLIDO
		assert_int(partida.final()).is_equal(final)
		assert_int(partida.medios()).is_equal(8 if llamado else 7)
		partida.anotar_llamado(Partida.Llamado.LOCAL_DESORDENADO)
		partida.cerrar_la_jornada(0)
		assert_object(partida.abrir_la_jornada()).is_null()
		assert_int(partida.medios()).is_equal(8 if llamado else 7)
