extends GdUnitTestSuite

const BALDE := ReglasDeLaLimpieza.ID_DEL_BALDE
const MOPA := ReglasDeLaLimpieza.ID_DE_LA_MOPA
const LAVATORIO := ReglasDeLaLimpieza.ID_DEL_LAVATORIO
const INODORO := ReglasDeLaLimpieza.ID_DEL_INODORO


func test_poetico_y_los_pares_comparten_el_permiso_de_la_jornada() -> void:  # AC-CLN-061
	var unidad := UnidadDeProducto.new(Catalogo.de(Producto.Id.POETICO))
	for jornada in range(1, 6):
		var piso := PisoDelLocal.de_la_jornada(jornada)
		var pares := Uso.para_el_almacen(jornada)
		assert_int(piso.usar(BALDE, LAVATORIO)).is_equal(ReglasDeLaLimpieza.Resultado.BALDE_LLENADO)
		assert_int(pares.resolver(unidad.id, BALDE)).is_equal(
			Uso.Efecto.TENIR if jornada == 2 else Uso.Efecto.NINGUNO
		)
		assert_int(piso.usar(unidad.id, BALDE)).is_equal(
			(
				ReglasDeLaLimpieza.Resultado.BALDE_TENIDO
				if jornada == 2
				else ReglasDeLaLimpieza.Resultado.SIN_EFECTO
			)
		)
		assert_int(piso.balde().agua()).is_equal(
			ReglasDeLaLimpieza.Agua.AZUL if jornada == 2 else ReglasDeLaLimpieza.Agua.LIMPIA
		)


func test_los_rechazos_no_cambian_agua_mopa_ni_manchas() -> void:  # AC-CLN-062
	var unidad := UnidadDeProducto.new(Catalogo.de(Producto.Id.POETICO))
	for agua: ReglasDeLaLimpieza.Agua in [
		ReglasDeLaLimpieza.Agua.NINGUNA,
		ReglasDeLaLimpieza.Agua.AZUL,
		ReglasDeLaLimpieza.Agua.ROSA,
		ReglasDeLaLimpieza.Agua.AMARILLO
	]:
		var piso := PisoDelLocal.de_la_jornada(2)
		if agua != ReglasDeLaLimpieza.Agua.NINGUNA:
			piso.balde().llenar()
			piso.balde().tenir(agua)
		var cantidad := piso.lugares().size()
		var pares := Uso.para_el_almacen(2)
		assert_int(pares.resolver(unidad.id, BALDE)).is_equal(Uso.Efecto.TENIR)
		assert_int(piso.balde().agua()).is_equal(agua)
		assert_int(piso.usar(unidad.id, BALDE)).is_equal(
			(
				ReglasDeLaLimpieza.Resultado.BALDE_VACIO
				if agua == ReglasDeLaLimpieza.Agua.NINGUNA
				else ReglasDeLaLimpieza.Resultado.BALDE_YA_TENIDO
			)
		)
		assert_int(piso.balde().agua()).is_equal(agua)
		assert_bool(piso.mopa().esta_mojada()).is_false()
		assert_int(piso.lugares().size()).is_equal(cantidad)
		for lugar: PisoDelLocal.Lugar in piso.lugares():
			assert_bool(piso.mancha_de(lugar).esta_limpia()).is_false()


func test_la_mezcla_sustituta_borra_solo_moho_con_la_carga_vigente() -> void:  # AC-CLN-063
	var unidad := UnidadDeProducto.new(Catalogo.de(Producto.Id.POETICO))
	var piso := PisoDelLocal.de_la_jornada(2)
	piso.usar(BALDE, LAVATORIO)
	assert_int(piso.usar(unidad.id, BALDE)).is_equal(ReglasDeLaLimpieza.Resultado.BALDE_TENIDO)
	assert_int(piso.usar(MOPA, BALDE)).is_equal(ReglasDeLaLimpieza.Resultado.MOPA_MOJADA)
	assert_int(piso.mopa().agua()).is_equal(ReglasDeLaLimpieza.Agua.AZUL)
	assert_that(piso.mopa().color()).is_equal(
		ReglasDeLaLimpieza.COLOR_DEL_AGUA[ReglasDeLaLimpieza.Agua.AZUL]
	)
	assert_float(piso.mopa().carga_restante()).is_equal(1.0)
	for lugar: PisoDelLocal.Lugar in piso.lugares():
		assert_int(piso.pasar(MOPA, lugar)).is_equal(
			(
				ReglasDeLaLimpieza.Resultado.MANCHA_BORRADA
				if piso.mancha_de(lugar).tipo() == ReglasDeLaLimpieza.TipoDeMancha.MOHO
				else ReglasDeLaLimpieza.Resultado.JABON_EQUIVOCADO
			)
		)
	assert_bool(piso.desgastar_mopa(MOPA, ReglasDeLaLimpieza.DURACION_DE_LA_CARGA, 0.0)).is_true()
	assert_bool(piso.mopa().esta_mojada()).is_false()
	piso.usar(MOPA, BALDE)
	assert_bool(piso.desgastar_mopa(MOPA, 0.0, ReglasDeLaLimpieza.RECORRIDO_DE_LA_CARGA)).is_true()
	assert_int(piso.lugares().size()).is_equal(8)


func test_dos_mezclas_conservan_la_unidad_y_no_habilitan_otros_destinos() -> void:  # AC-CLN-064
	var unidad := UnidadDeProducto.new(Catalogo.de(Producto.Id.POETICO))
	var piso := PisoDelLocal.de_la_jornada(2)
	for repeticion in range(2):
		piso.usar(BALDE, LAVATORIO)
		assert_int(piso.usar(unidad.id, BALDE)).is_equal(ReglasDeLaLimpieza.Resultado.BALDE_TENIDO)
		assert_int(piso.usar(BALDE, INODORO)).is_equal(ReglasDeLaLimpieza.Resultado.BALDE_VACIADO)
		assert_int(unidad.producto.id).is_equal(Producto.Id.POETICO)
	for destino: StringName in [LAVATORIO, INODORO, Uso.MANCHA]:
		assert_int(piso.usar(unidad.id, destino)).is_equal(ReglasDeLaLimpieza.Resultado.SIN_EFECTO)
	var otro := UnidadDeProducto.new(Catalogo.de(Producto.Id.DURONGA))
	otro.nombre = unidad.nombre
	piso.usar(BALDE, LAVATORIO)
	assert_int(piso.usar(otro.id, BALDE)).is_equal(ReglasDeLaLimpieza.Resultado.SIN_EFECTO)
