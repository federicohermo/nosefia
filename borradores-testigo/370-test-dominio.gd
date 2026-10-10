

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
	for jornada in [1, 3, 4, 5]:
		var vacia := TareaDeLaBasura.de_la_jornada(jornada)
		for tacho: TareaDeLaBasura.Tacho in TareaDeLaBasura.Tacho.values():
			assert_str(vacia.sacar(tacho, true)).is_equal(ObjetoDelAlmacen.SIN_ID)
		assert_int(vacia.depositadas()).is_zero()
