## El piso de una jornada: sus manchas, el balde y la mopa, y lo que contesta cada uso.
##
## Es la mitad de limpiar que se ejerce sin levantar una escena: acá se prueban las reglas de la
## ficha sin poner una sola mancha en el almacén.
extends GdUnitTestSuite

const MOPA := ReglasDeLaLimpieza.ID_DE_LA_MOPA
const BALDE := ReglasDeLaLimpieza.ID_DEL_BALDE
const LAVATORIO := ReglasDeLaLimpieza.ID_DEL_LAVATORIO
const INODORO := ReglasDeLaLimpieza.ID_DEL_INODORO
const JABON_AZUL := &"jabon_azul"
const JABON_ROSA := &"jabon_rosa"
const JABON_AMARILLO := &"jabon_amarillo"


func _piso() -> PisoDelLocal:
	return PisoDelLocal.de_la_jornada(ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA)


## El jabón que borra ese tipo de mancha, sacado de las reglas y no copiado.
static func _jabon_de(
	tipo: ReglasDeLaLimpieza.TipoDeMancha, jornada: int = ReglasDeLaPartida.PRIMERA_JORNADA
) -> StringName:
	if jornada == 2 and tipo == ReglasDeLaLimpieza.TipoDeMancha.MOHO:
		return AnomaliasDeLaJornada.id_de_poetico()
	for jabon: StringName in ReglasDeLaLimpieza.JABONES:
		if ReglasDeLaLimpieza.JABONES[jabon] == ReglasDeLaLimpieza.AGUA_QUE_BORRA[tipo]:
			return jabon
	return &""


## Borra todas las manchas de la noche, cada una con su jabón.
func _borrar_todas(piso: PisoDelLocal) -> void:
	for lugar: PisoDelLocal.Lugar in piso.lugares():
		piso.usar(BALDE, INODORO)
		_preparar(piso, _jabon_de(piso.mancha_de(lugar).tipo(), piso.jornada()))
		assert_int(piso.pasar(MOPA, lugar)).is_equal(ReglasDeLaLimpieza.Resultado.MANCHA_BORRADA)


## Cuántas manchas de cada tipo trae el piso: `[polvo, moho, caca]`.
static func _por_tipo(piso: PisoDelLocal) -> Array[int]:
	var cuenta: Array[int] = [0, 0, 0]
	var orden := [
		ReglasDeLaLimpieza.TipoDeMancha.POLVO,
		ReglasDeLaLimpieza.TipoDeMancha.MOHO,
		ReglasDeLaLimpieza.TipoDeMancha.CACA,
	]
	for lugar: PisoDelLocal.Lugar in piso.lugares():
		cuenta[orden.find(piso.mancha_de(lugar).tipo())] += 1
	return cuenta


## Llena el balde, lo tiñe con ese jabón y moja la mopa: lo que se hace en el baño antes de salir.
func _preparar(piso: PisoDelLocal, jabon: StringName) -> void:
	assert_int(piso.usar(BALDE, LAVATORIO)).is_equal(ReglasDeLaLimpieza.Resultado.BALDE_LLENADO)
	assert_int(piso.usar(jabon, BALDE)).is_equal(ReglasDeLaLimpieza.Resultado.BALDE_TENIDO)
	assert_int(piso.usar(MOPA, BALDE)).is_equal(ReglasDeLaLimpieza.Resultado.MOPA_MOJADA)


## Lo que hay que borrar, de un vistazo: cada lugar sucio.
func _sucias(piso: PisoDelLocal) -> Array:
	var sucias := []
	for lugar: PisoDelLocal.Lugar in piso.lugares():
		if not piso.mancha_de(lugar).esta_limpia():
			sucias.append(lugar)
	return sucias


func test_cada_jornada_trae_sus_manchas_por_tipo_y_todas_sucias() -> void:  # AC-CLN-016
	# `[polvo, moho, caca]`.
	var esperadas := {
		3: [3, 2, 2], 4: [3, 2, 2], 5: [4, 3, 1], 6: [3, 2, 2], 7: [3, 2, 2], 8: [3, 2, 2]
	}
	for jornada: int in esperadas:
		var piso := PisoDelLocal.de_la_jornada(jornada)
		(
			assert_array(_por_tipo(piso))
			. override_failure_message("la jornada %d no trae lo que pide la ficha" % jornada)
			. is_equal(esperadas[jornada])
		)
		assert_int(_sucias(piso).size()).is_equal(piso.lugares().size())


func test_los_cuatro_lugares_de_hoy_siguen_en_la_primera_jornada() -> void:  # AC-CLN-016
	# La escena guarda cada disco con el número de su lugar: los cuatro de antes conservan el suyo
	# y su mancha, y los nuevos van después.
	var piso := _piso()
	var esperados := {
		PisoDelLocal.Lugar.ENTRADA: ReglasDeLaLimpieza.TipoDeMancha.POLVO,
		PisoDelLocal.Lugar.GONDOLAS: ReglasDeLaLimpieza.TipoDeMancha.POLVO,
		PisoDelLocal.Lugar.DEPOSITO: ReglasDeLaLimpieza.TipoDeMancha.MOHO,
		PisoDelLocal.Lugar.BANO: ReglasDeLaLimpieza.TipoDeMancha.CACA,
	}
	var numero := 0
	for lugar: PisoDelLocal.Lugar in esperados:
		assert_int(lugar).is_equal(numero)
		assert_int(piso.mancha_de(lugar).tipo()).is_equal(esperados[lugar])
		numero += 1


func test_cada_jornada_arranca_sucia_aunque_la_anterior_quedo_limpia() -> void:  # AC-CLN-016
	# Instancias nuevas y no las mismas: con un piso compartido, lo limpiado anoche llegaría
	# limpio esta noche, y el balde teñido de anoche ahorraría el primer viaje a la canilla.
	for jornada: int in [4, 5]:
		var anoche := PisoDelLocal.de_la_jornada(jornada)
		_borrar_todas(anoche)
		assert_bool(anoche.esta_limpio()).is_true()
		var hoy := PisoDelLocal.de_la_jornada(jornada + 1)
		assert_int(hoy.lugares().size()).is_equal(8 if jornada + 1 == 5 else 7)
		assert_int(_sucias(hoy).size()).is_equal(hoy.lugares().size())
		assert_bool(hoy.balde().tiene_agua()).is_false()
		assert_bool(hoy.mopa().esta_mojada()).is_false()


func test_el_piso_queda_limpio_recien_con_la_ultima_mancha() -> void:  # AC-CLN-012
	var piso := _piso()
	var lugares := piso.lugares()
	for indice in lugares.size():
		piso.usar(BALDE, INODORO)
		_preparar(piso, _jabon_de(piso.mancha_de(lugares[indice]).tipo()))
		assert_bool(piso.esta_limpio()).is_false()
		assert_int(piso.pasar(MOPA, lugares[indice])).is_equal(
			ReglasDeLaLimpieza.Resultado.MANCHA_BORRADA
		)
	assert_bool(piso.esta_limpio()).is_true()


func test_cambiar_de_jabon_es_vaciar_el_balde_y_volver_a_llenarlo() -> void:  # AC-CLN-021
	var piso := _piso()
	_preparar(piso, JABON_AMARILLO)
	assert_int(piso.pasar(MOPA, PisoDelLocal.Lugar.DEPOSITO)).is_equal(
		ReglasDeLaLimpieza.Resultado.JABON_EQUIVOCADO
	)
	assert_int(piso.usar(JABON_AZUL, BALDE)).is_equal(ReglasDeLaLimpieza.Resultado.BALDE_YA_TENIDO)
	assert_int(piso.usar(BALDE, LAVATORIO)).is_equal(ReglasDeLaLimpieza.Resultado.BALDE_YA_LLENO)
	assert_int(piso.usar(BALDE, INODORO)).is_equal(ReglasDeLaLimpieza.Resultado.BALDE_VACIADO)
	_preparar(piso, JABON_AZUL)
	assert_int(piso.pasar(MOPA, PisoDelLocal.Lugar.DEPOSITO)).is_equal(
		ReglasDeLaLimpieza.Resultado.MANCHA_BORRADA
	)


func test_con_una_mojada_de_amarillo_se_borran_todas_las_de_polvo() -> void:  # AC-CLN-023
	var piso := _piso()
	_preparar(piso, JABON_AMARILLO)
	var otras := []
	for lugar: PisoDelLocal.Lugar in piso.lugares():
		if piso.mancha_de(lugar).tipo() != ReglasDeLaLimpieza.TipoDeMancha.POLVO:
			otras.append(lugar)
			continue
		assert_int(piso.pasar(MOPA, lugar)).is_equal(ReglasDeLaLimpieza.Resultado.MANCHA_BORRADA)
	assert_array(_sucias(piso)).contains_exactly_in_any_order(otras)


func test_lo_que_no_es_un_gesto_de_limpiar_no_hace_nada() -> void:  # AC-CLN-024
	var piso := _piso()
	_preparar(piso, JABON_AZUL)
	var ajenos: Array[StringName] = [ObjetoDelAlmacen.SIN_ID, &"bolsa_de_basura_1"]
	for en_la_mano in ajenos:
		for objetivo: StringName in [BALDE, LAVATORIO, INODORO]:
			assert_int(piso.usar(en_la_mano, objetivo)).is_equal(
				ReglasDeLaLimpieza.Resultado.SIN_EFECTO
			)
		for lugar: PisoDelLocal.Lugar in piso.lugares():
			assert_int(piso.pasar(en_la_mano, lugar)).is_equal(
				ReglasDeLaLimpieza.Resultado.SIN_EFECTO
			)
	assert_int(piso.balde().agua()).is_equal(ReglasDeLaLimpieza.Agua.AZUL)
	assert_int(piso.mopa().agua()).is_equal(ReglasDeLaLimpieza.Agua.AZUL)
	assert_int(_sucias(piso).size()).is_equal(piso.lugares().size())


func test_los_gestos_al_reves_o_cruzados_no_hacen_nada() -> void:  # AC-CLN-024
	var piso := _piso()
	var pares: Array[Array] = [
		[LAVATORIO, BALDE],
		[BALDE, BALDE],
		[JABON_AZUL, LAVATORIO],
		[MOPA, LAVATORIO],
		[BALDE, Uso.MANCHA],
		[MOPA, Uso.MANCHA],
	]
	for par in pares:
		(
			assert_int(piso.usar(par[0], par[1]))
			. override_failure_message("%s sobre %s hizo algo" % par)
			. is_equal(ReglasDeLaLimpieza.Resultado.SIN_EFECTO)
		)
	assert_int(piso.pasar(BALDE, PisoDelLocal.Lugar.BANO)).is_equal(
		ReglasDeLaLimpieza.Resultado.SIN_EFECTO
	)
	assert_bool(piso.balde().tiene_agua()).is_false()


func test_el_uso_necesita_un_efecto_declarado() -> void:
	# El despacho es la única puerta: sin el par declarado, la mopa mojada del jabón justo no
	# borra nada aunque la mancha y la mopa estén listas.
	var piso := _piso()
	_preparar(piso, JABON_AMARILLO)
	piso.set("_uso", Uso.new())
	assert_int(piso.pasar(MOPA, PisoDelLocal.Lugar.ENTRADA)).is_equal(
		ReglasDeLaLimpieza.Resultado.SIN_EFECTO
	)
	assert_int(_sucias(piso).size()).is_equal(piso.lugares().size())


func test_la_mezcla_espera_mientras_se_hace_otra_cosa() -> void:  # AC-CLN-025
	var piso := _piso()
	_preparar(piso, JABON_AZUL)
	piso.pasar(MOPA, PisoDelLocal.Lugar.DEPOSITO)
	piso.pasar(MOPA, PisoDelLocal.Lugar.ENTRADA)
	piso.usar(&"lata_de_tomate", BALDE)
	piso.usar(ObjetoDelAlmacen.SIN_ID, INODORO)
	assert_int(piso.balde().agua()).is_equal(ReglasDeLaLimpieza.Agua.AZUL)
	assert_int(piso.mopa().agua()).is_equal(ReglasDeLaLimpieza.Agua.AZUL)
	assert_bool(piso.mancha_de(PisoDelLocal.Lugar.DEPOSITO).esta_limpia()).is_true()


func test_un_lugar_sin_mancha_no_se_borra() -> void:
	# No es un caso del juego: es el borde de la firma, y un `null` acá mataría el cuadro.
	var solo_el_bano: Dictionary[PisoDelLocal.Lugar, Mancha] = {
		PisoDelLocal.Lugar.BANO: Mancha.new(ReglasDeLaLimpieza.TipoDeMancha.CACA)
	}
	var piso := PisoDelLocal.new(solo_el_bano)
	_preparar(piso, JABON_ROSA)
	assert_int(piso.pasar(MOPA, PisoDelLocal.Lugar.ENTRADA)).is_equal(
		ReglasDeLaLimpieza.Resultado.SIN_EFECTO
	)
	assert_object(piso.mancha_de(PisoDelLocal.Lugar.ENTRADA)).is_null()


func test_enjuagar_en_inodoro_quita_jabon_recarga_y_preserva_el_local() -> void:  # AC-CLN-029
	for jabon: StringName in ReglasDeLaLimpieza.JABONES:
		var piso := _piso()
		_preparar(piso, jabon)
		piso.pasar(MOPA, PisoDelLocal.Lugar.DEPOSITO)
		var sucias := _sucias(piso)
		piso.mopa().desgastar(2.0, 1.0)
		assert_int(piso.usar(MOPA, INODORO)).is_equal(ReglasDeLaLimpieza.Resultado.MOPA_MOJADA)
		assert_int(piso.mopa().agua()).is_equal(ReglasDeLaLimpieza.Agua.LIMPIA)
		assert_float(piso.mopa().carga_restante()).is_equal(1.0)
		assert_that(piso.mopa().color()).is_equal(
			ReglasDeLaLimpieza.COLOR_DEL_AGUA[ReglasDeLaLimpieza.Agua.LIMPIA]
		)
		assert_int(piso.balde().agua()).is_equal(ReglasDeLaLimpieza.JABONES[jabon])
		assert_array(_sucias(piso)).is_equal(sucias)


func test_enjuagar_mopa_seca_en_inodoro_equivale_a_balde_limpio() -> void:  # AC-CLN-029
	var inodoro := _piso()
	var balde := _piso()
	balde.usar(BALDE, LAVATORIO)
	assert_int(inodoro.usar(MOPA, INODORO)).is_equal(balde.usar(MOPA, BALDE))
	assert_int(inodoro.mopa().agua()).is_equal(balde.mopa().agua())
	assert_float(inodoro.mopa().carga_restante()).is_equal(balde.mopa().carga_restante())
	assert_bool(inodoro.balde().tiene_agua()).is_false()
	assert_int(balde.balde().agua()).is_equal(ReglasDeLaLimpieza.Agua.LIMPIA)


func test_agua_limpia_deja_charco_sin_cambiar_carga_balde_ni_manchas() -> void:  # AC-CLN-030
	var piso := _piso()
	piso.usar(BALDE, LAVATORIO)
	piso.usar(MOPA, BALDE)
	piso.mopa().desgastar(1.0, 0.5)
	var carga := piso.mopa().carga_restante()
	var sucias := _sucias(piso)
	assert_int(piso.humedecer_piso(MOPA, true)).is_equal(ReglasDeLaLimpieza.Resultado.CHARCO_DEJADO)
	assert_float(piso.mopa().carga_restante()).is_equal(carga)
	assert_int(piso.balde().agua()).is_equal(ReglasDeLaLimpieza.Agua.LIMPIA)
	assert_array(_sucias(piso)).is_equal(sucias)
	assert_bool(piso.esta_limpio()).is_false()


func test_seca_y_cada_jabon_rechazan_charcos_sin_gastar_carga() -> void:  # AC-CLN-030
	var piso := _piso()
	assert_int(piso.humedecer_piso(MOPA, true)).is_equal(ReglasDeLaLimpieza.Resultado.MOPA_SECA)
	for jabon: StringName in ReglasDeLaLimpieza.JABONES:
		piso.usar(BALDE, INODORO)
		_preparar(piso, jabon)
		piso.mopa().desgastar(1.0, 0.5)
		var carga := piso.mopa().carga_restante()
		assert_int(piso.humedecer_piso(MOPA, true)).is_equal(
			ReglasDeLaLimpieza.Resultado.SIN_EFECTO
		)
		assert_float(piso.mopa().carga_restante()).is_equal(carga)
		assert_int(piso.mopa().agua()).is_equal(ReglasDeLaLimpieza.JABONES[jabon])
	assert_int(_sucias(piso).size()).is_equal(piso.lugares().size())


func test_superficie_deshabilitada_no_gasta_carga_aunque_mancha_este_limpia() -> void:  # AC-CLN-031
	var piso := _piso()
	_preparar(piso, JABON_AMARILLO)
	piso.pasar(MOPA, PisoDelLocal.Lugar.ENTRADA)
	piso.usar(BALDE, INODORO)
	piso.usar(BALDE, LAVATORIO)
	piso.usar(MOPA, BALDE)
	piso.mopa().desgastar(1.0, 0.5)
	var carga := piso.mopa().carga_restante()
	var sucias := _sucias(piso)
	assert_int(piso.humedecer_piso(MOPA, false)).is_equal(ReglasDeLaLimpieza.Resultado.SIN_EFECTO)
	assert_float(piso.mopa().carga_restante()).is_equal(carga)
	assert_array(_sucias(piso)).is_equal(sucias)
	assert_bool(piso.mancha_de(PisoDelLocal.Lugar.ENTRADA).esta_limpia()).is_true()


func test_agua_sola_sobre_mancha_sigue_sin_jabon() -> void:  # AC-CLN-031
	var piso := _piso()
	piso.usar(BALDE, LAVATORIO)
	piso.usar(MOPA, BALDE)
	assert_int(piso.pasar(MOPA, PisoDelLocal.Lugar.BANO)).is_equal(
		ReglasDeLaLimpieza.Resultado.SIN_JABON
	)
	assert_bool(piso.mancha_de(PisoDelLocal.Lugar.BANO).esta_limpia()).is_false()
	assert_float(piso.mopa().carga_restante()).is_equal(1.0)


func test_charco_necesita_mopa_en_mano_y_gesto_declarado() -> void:  # AC-CLN-030
	var piso := _piso()
	piso.usar(BALDE, LAVATORIO)
	piso.usar(MOPA, BALDE)
	for ajeno: StringName in [ObjetoDelAlmacen.SIN_ID, BALDE, JABON_AZUL, &"bolsa_de_basura_1"]:
		assert_int(piso.humedecer_piso(ajeno, true)).is_equal(
			ReglasDeLaLimpieza.Resultado.SIN_EFECTO
		)
	piso.set("_uso", Uso.new())
	assert_int(piso.humedecer_piso(MOPA, true)).is_equal(ReglasDeLaLimpieza.Resultado.SIN_EFECTO)
	assert_float(piso.mopa().carga_restante()).is_equal(1.0)
	assert_int(_sucias(piso).size()).is_equal(piso.lugares().size())


func test_carga_agotada_no_deja_charco_hasta_enjuagar() -> void:  # AC-CLN-030
	var piso := _piso()
	piso.usar(MOPA, INODORO)
	piso.mopa().desgastar(ReglasDeLaLimpieza.DURACION_DE_LA_CARGA, 0.0)
	assert_int(piso.humedecer_piso(MOPA, true)).is_equal(ReglasDeLaLimpieza.Resultado.MOPA_SECA)
	assert_float(piso.mopa().carga_restante()).is_zero()
	piso.usar(MOPA, INODORO)
	assert_int(piso.humedecer_piso(MOPA, true)).is_equal(ReglasDeLaLimpieza.Resultado.CHARCO_DEJADO)
	assert_float(piso.mopa().carga_restante()).is_equal(1.0)


func test_los_metros_solo_gastan_la_mopa_que_se_lleva_en_la_mano() -> void:  # AC-CLN-027
	var en_la_mano := _piso()
	var apoyada := _piso()
	var quieta := _piso()
	for piso: PisoDelLocal in [en_la_mano, apoyada, quieta]:
		_preparar(piso, JABON_AZUL)
	en_la_mano.desgastar_mopa(MOPA, 1.0, 2.0)
	for ajeno: StringName in [ObjetoDelAlmacen.SIN_ID, BALDE, JABON_AZUL]:
		apoyada.desgastar_mopa(ajeno, 0.0, 2.0)
	quieta.desgastar_mopa(MOPA, 1.0, 0.0)
	apoyada.desgastar_mopa(ObjetoDelAlmacen.SIN_ID, 1.0, 0.0)
	assert_float(apoyada.mopa().carga_restante()).is_equal(quieta.mopa().carga_restante())
	assert_float(en_la_mano.mopa().carga_restante()).is_less(quieta.mopa().carga_restante())
