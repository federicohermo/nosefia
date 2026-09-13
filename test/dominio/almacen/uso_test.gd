extends GdUnitTestSuite


func test_el_constructor_no_registra_combinaciones() -> void:  # 034-AC3
	var uso := Uso.new()
	assert_int(uso.cantidad()).is_zero()
	assert_int(uso.resolver(&"a", &"b")).is_equal(Uso.Efecto.NINGUNO)
	assert_int(uso.resolver(ReglasDeLaLimpieza.ID_DEL_TRAPEADOR, Uso.MANCHA)).is_equal(
		Uso.Efecto.NINGUNO
	)


func test_registrar_habilita_solo_el_par_en_ese_orden() -> void:  # 034-AC4, 034-AC7
	var uso := Uso.new()
	assert_bool(uso.registrar(&"a", &"b", Uso.Efecto.LIMPIAR)).is_true()
	assert_int(uso.cantidad()).is_equal(1)
	assert_int(uso.resolver(&"a", &"b")).is_equal(Uso.Efecto.LIMPIAR)
	assert_int(uso.resolver(&"b", &"a")).is_equal(Uso.Efecto.NINGUNO)


func test_los_pares_distintos_no_se_confunden() -> void:  # 034-AC4
	var uso := Uso.new()
	assert_bool(uso.registrar(&"a:b", &"c", Uso.Efecto.LIMPIAR)).is_true()
	assert_int(uso.resolver(&"a", &"b:c")).is_equal(Uso.Efecto.NINGUNO)
	assert_bool(uso.registrar(&"a", &"b:c", Uso.Efecto.LIMPIAR)).is_true()
	assert_int(uso.cantidad()).is_equal(2)
	assert_int(uso.resolver(&"a:b", &"c")).is_equal(Uso.Efecto.LIMPIAR)
	assert_int(uso.resolver(&"a", &"b:c")).is_equal(Uso.Efecto.LIMPIAR)


func test_un_duplicado_no_altera_la_tabla() -> void:  # 034-AC5
	var uso := Uso.new()
	assert_bool(uso.registrar(&"a", &"b", Uso.Efecto.LIMPIAR)).is_true()
	assert_bool(uso.registrar(&"a", &"b", Uso.Efecto.LIMPIAR)).is_false()
	assert_int(uso.cantidad()).is_equal(1)
	assert_int(uso.resolver(&"a", &"b")).is_equal(Uso.Efecto.LIMPIAR)


func test_ninguno_no_se_registra_ni_borra_un_efecto() -> void:  # 034-AC5
	var uso := Uso.new()
	assert_bool(uso.registrar(&"a", &"b", Uso.Efecto.NINGUNO)).is_false()
	assert_int(uso.cantidad()).is_zero()
	assert_bool(uso.registrar(&"a", &"b", Uso.Efecto.LIMPIAR)).is_true()
	assert_bool(uso.registrar(&"a", &"b", Uso.Efecto.NINGUNO)).is_false()
	assert_int(uso.cantidad()).is_equal(1)
	assert_int(uso.resolver(&"a", &"b")).is_equal(Uso.Efecto.LIMPIAR)


func test_la_mano_vacia_no_produce_un_efecto_aunque_este_registrada() -> void:  # 034-AC6
	var uso := Uso.new()
	assert_bool(uso.registrar(ObjetoDelAlmacen.SIN_ID, Uso.MANCHA, Uso.Efecto.LIMPIAR)).is_true()
	assert_int(uso.cantidad()).is_equal(1)
	assert_int(uso.resolver(ObjetoDelAlmacen.SIN_ID, Uso.MANCHA)).is_equal(Uso.Efecto.NINGUNO)


func test_el_almacen_configura_solo_trapeador_sobre_mancha() -> void:  # 034-AC10
	var uso := Uso.para_el_almacen()
	assert_int(uso.cantidad()).is_equal(1)
	assert_int(uso.resolver(ReglasDeLaLimpieza.ID_DEL_TRAPEADOR, Uso.MANCHA)).is_equal(
		Uso.Efecto.LIMPIAR
	)
	assert_int(uso.resolver(Uso.MANCHA, ReglasDeLaLimpieza.ID_DEL_TRAPEADOR)).is_equal(
		Uso.Efecto.NINGUNO
	)
	assert_int(uso.resolver(&"bolsa", Uso.MANCHA)).is_equal(Uso.Efecto.NINGUNO)
	assert_int(uso.resolver(ObjetoDelAlmacen.SIN_ID, Uso.MANCHA)).is_equal(Uso.Efecto.NINGUNO)
