extends GdUnitTestSuite


func test_el_constructor_no_registra_combinaciones() -> void:
	var uso := Uso.new()
	assert_int(uso.cantidad()).is_zero()
	assert_int(uso.resolver(&"a", &"b")).is_equal(Uso.Efecto.NINGUNO)
	assert_int(uso.resolver(ReglasDeLaLimpieza.ID_DE_LA_MOPA, Uso.MANCHA)).is_equal(
		Uso.Efecto.NINGUNO
	)


func test_registrar_habilita_solo_el_par_en_ese_orden() -> void:
	var uso := Uso.new()
	assert_bool(uso.registrar(&"a", &"b", Uso.Efecto.LIMPIAR)).is_true()
	assert_int(uso.cantidad()).is_equal(1)
	assert_int(uso.resolver(&"a", &"b")).is_equal(Uso.Efecto.LIMPIAR)
	assert_int(uso.resolver(&"b", &"a")).is_equal(Uso.Efecto.NINGUNO)


func test_los_pares_distintos_no_se_confunden() -> void:  # AC-PLY-014
	var uso := Uso.new()
	assert_bool(uso.registrar(&"a:b", &"c", Uso.Efecto.LIMPIAR)).is_true()
	assert_int(uso.resolver(&"a", &"b:c")).is_equal(Uso.Efecto.NINGUNO)
	assert_bool(uso.registrar(&"a", &"b:c", Uso.Efecto.LIMPIAR)).is_true()
	assert_int(uso.cantidad()).is_equal(2)
	assert_int(uso.resolver(&"a:b", &"c")).is_equal(Uso.Efecto.LIMPIAR)
	assert_int(uso.resolver(&"a", &"b:c")).is_equal(Uso.Efecto.LIMPIAR)


func test_un_duplicado_no_altera_la_tabla() -> void:
	var uso := Uso.new()
	assert_bool(uso.registrar(&"a", &"b", Uso.Efecto.LIMPIAR)).is_true()
	assert_bool(uso.registrar(&"a", &"b", Uso.Efecto.LIMPIAR)).is_false()
	assert_int(uso.cantidad()).is_equal(1)
	assert_int(uso.resolver(&"a", &"b")).is_equal(Uso.Efecto.LIMPIAR)


func test_ninguno_no_se_registra_ni_borra_un_efecto() -> void:
	var uso := Uso.new()
	assert_bool(uso.registrar(&"a", &"b", Uso.Efecto.NINGUNO)).is_false()
	assert_int(uso.cantidad()).is_zero()
	assert_bool(uso.registrar(&"a", &"b", Uso.Efecto.LIMPIAR)).is_true()
	assert_bool(uso.registrar(&"a", &"b", Uso.Efecto.NINGUNO)).is_false()
	assert_int(uso.cantidad()).is_equal(1)
	assert_int(uso.resolver(&"a", &"b")).is_equal(Uso.Efecto.LIMPIAR)


func test_la_mano_vacia_no_produce_un_efecto_aunque_este_registrada() -> void:  # AC-PLY-014
	var uso := Uso.new()
	assert_bool(uso.registrar(ObjetoDelAlmacen.SIN_ID, Uso.MANCHA, Uso.Efecto.LIMPIAR)).is_true()
	assert_int(uso.cantidad()).is_equal(1)
	assert_int(uso.resolver(ObjetoDelAlmacen.SIN_ID, Uso.MANCHA)).is_equal(Uso.Efecto.NINGUNO)


func test_el_almacen_declara_los_cinco_gestos_de_limpiar() -> void:  # AC-PLY-014
	# Uno por cada paso de la ficha. Un par de más haría que algo limpie sin pasar por el baño; uno
	# de menos, que un paso no se pueda dar nunca y la obligatoria quede inalcanzable.
	var uso := Uso.para_el_almacen()
	var mopa := ReglasDeLaLimpieza.ID_DE_LA_MOPA
	var balde := ReglasDeLaLimpieza.ID_DEL_BALDE
	var declarados: Array[Array] = [
		[mopa, Uso.MANCHA, Uso.Efecto.LIMPIAR],
		[balde, ReglasDeLaLimpieza.ID_DEL_LAVATORIO, Uso.Efecto.LLENAR],
		[mopa, balde, Uso.Efecto.MOJAR],
		[balde, ReglasDeLaLimpieza.ID_DEL_INODORO, Uso.Efecto.VACIAR],
	]
	for jabon: StringName in ReglasDeLaLimpieza.JABONES:
		declarados.append([jabon, balde, Uso.Efecto.TENIR])
	assert_int(uso.cantidad()).is_equal(declarados.size())
	for par in declarados:
		(
			assert_int(uso.resolver(par[0], par[1]))
			. override_failure_message("%s sobre %s no hace lo declarado" % [par[0], par[1]])
			. is_equal(par[2])
		)
		(
			assert_int(uso.resolver(par[1], par[0]))
			. override_failure_message("%s sobre %s hace algo" % [par[1], par[0]])
			. is_equal(Uso.Efecto.NINGUNO)
		)
	assert_int(uso.resolver(&"bolsa_de_basura_1", Uso.MANCHA)).is_equal(Uso.Efecto.NINGUNO)
	assert_int(uso.resolver(balde, balde)).is_equal(Uso.Efecto.NINGUNO)
	for objetivo: StringName in [Uso.MANCHA, balde, ReglasDeLaLimpieza.ID_DEL_LAVATORIO]:
		assert_int(uso.resolver(ObjetoDelAlmacen.SIN_ID, objetivo)).is_equal(Uso.Efecto.NINGUNO)
