## Cada bolsa cuenta una vez; una noche nueva recibe una tarea nueva.
extends GdUnitTestSuite

const ID_AJENO := &"caja_de_fideos"


func _tarea() -> TareaDeLaBasura:
	return TareaDeLaBasura.de_la_jornada(2)


func _ids() -> Array[StringName]:
	return ReglasDeLaBasura.ids_de_las_bolsas()


func test_la_jornada_arranca_con_las_bolsas_del_balance_y_ninguna_depositada() -> void:
	var tarea := _tarea()
	assert_int(tarea.bolsas()).is_equal(ReglasDeLaBasura.BOLSAS_DE_LA_JORNADA)
	assert_int(tarea.depositadas()).is_equal(0)
	assert_bool(tarea.completada()).is_false()


func test_la_misma_bolsa_dos_veces_no_cuenta_dos() -> void:  # AC-CLN-011
	# Con `id` repetidos contando de a dos, la tarea se cerraría llevando una sola bolsa al
	# fondo y volviendo a soltarla — o sea, sin los tres viajes.
	var tarea := _tarea()
	var bolsa := _ids()[0]
	assert_int(tarea.depositar(bolsa)).is_equal(TareaDeLaBasura.Resultado.DEPOSITADA)
	assert_int(tarea.depositar(bolsa)).is_equal(TareaDeLaBasura.Resultado.YA_DEPOSITADA)
	assert_int(tarea.depositadas()).is_equal(1)


func test_un_objeto_ajeno_no_es_basura() -> void:  # AC-CLN-011
	var tarea := _tarea()
	assert_int(tarea.depositar(ID_AJENO)).is_equal(TareaDeLaBasura.Resultado.NO_ES_BASURA)
	assert_int(tarea.depositar(ObjetoDelAlmacen.SIN_ID)).is_equal(
		TareaDeLaBasura.Resultado.NO_ES_BASURA
	)
	assert_int(tarea.depositadas()).is_equal(0)


func test_la_tarea_se_completa_recien_con_la_ultima_bolsa() -> void:  # AC-CLN-012
	var tarea := _tarea()
	var ids := _ids()
	for indice in range(ids.size() - 1):
		tarea.depositar(ids[indice])
		(
			assert_bool(tarea.completada())
			. override_failure_message(
				"la tarea se completó con %d de %d bolsas" % [indice + 1, ids.size()]
			)
			. is_false()
		)
	tarea.depositar(ids[-1])
	assert_bool(tarea.completada()).is_true()


func test_cada_jornada_arranca_con_la_basura_adentro() -> void:
	# Instancias nuevas y no las mismas: con una compartida, lo depositado anoche llegaría
	# depositado esta noche y la obligatoria se cumpliría sola a partir de la segunda.
	var una := _tarea()
	una.depositar(_ids()[0])
	assert_int(_tarea().depositadas()).is_equal(0)


func test_un_id_repetido_en_la_lista_no_agranda_la_tarea() -> void:
	# Con el mismo `id` dos veces, la tarea pediría dos bolsas y se cerraría con una: el jugador
	# haría un viaje menos sin que nada lo diga.
	var repetida := TareaDeLaBasura.new([&"bolsa", &"bolsa"] as Array[StringName])
	assert_int(repetida.bolsas()).is_equal(1)


func test_solo_la_jornada_que_declara_basura_tiene_tachos_llenos() -> void:  # AC-CLN-007
	for jornada in range(1, 6):
		var tarea := TareaDeLaBasura.de_la_jornada(jornada)
		assert_int(tarea.bolsas()).is_equal(3 if jornada == 2 else 0)
		for tacho: TareaDeLaBasura.Tacho in TareaDeLaBasura.Tacho.values():
			assert_bool(tarea.tiene_bolsa(tacho)).is_equal(jornada == 2)
		assert_int(tarea.depositadas()).is_zero()


func test_sacar_agota_solo_el_tacho_sin_depositar_y_repetir_no_duplica() -> void:  # AC-CLN-053
	var tarea := _tarea()
	for tacho: TareaDeLaBasura.Tacho in TareaDeLaBasura.Tacho.values():
		var id := tarea.sacar(tacho, true)
		assert_str(id).is_equal(ReglasDeLaBasura.id_de_la_bolsa(tacho + 1))
		assert_bool(tarea.tiene_bolsa(tacho)).is_false()
		assert_str(tarea.sacar(tacho, true)).is_equal(ObjetoDelAlmacen.SIN_ID)
		assert_int(tarea.depositadas()).is_zero()
	assert_bool(tarea.completada()).is_false()


func test_mano_ocupada_y_tacho_vacio_no_cambian_nada() -> void:  # AC-CLN-053 AC-CLN-055
	var tarea := _tarea()
	for tacho: TareaDeLaBasura.Tacho in TareaDeLaBasura.Tacho.values():
		assert_str(tarea.sacar(tacho, false)).is_equal(ObjetoDelAlmacen.SIN_ID)
		assert_bool(tarea.tiene_bolsa(tacho)).is_true()
	for jornada: int in [1, 3, 4, 5]:
		var vacia := TareaDeLaBasura.de_la_jornada(jornada)
		for tacho: TareaDeLaBasura.Tacho in TareaDeLaBasura.Tacho.values():
			assert_str(vacia.sacar(tacho, true)).is_equal(ObjetoDelAlmacen.SIN_ID)
		assert_int(vacia.depositadas()).is_zero()
