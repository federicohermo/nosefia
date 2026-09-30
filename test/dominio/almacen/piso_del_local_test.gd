## El piso de una jornada: sus cuatro manchas, el balde y la mopa, y lo que contesta cada uso.
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
	return PisoDelLocal.de_la_jornada()


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


func test_la_jornada_trae_dos_de_polvo_una_de_moho_y_una_de_caca() -> void:  # AC-CLN-016
	var piso := _piso()
	var por_tipo := {}
	for lugar: PisoDelLocal.Lugar in piso.lugares():
		var mancha := piso.mancha_de(lugar)
		assert_bool(mancha.esta_limpia()).is_false()
		por_tipo[mancha.tipo()] = por_tipo.get(mancha.tipo(), 0) + 1
	assert_int(piso.lugares().size()).is_equal(4)
	assert_int(por_tipo.get(ReglasDeLaLimpieza.TipoDeMancha.POLVO, 0)).is_equal(2)
	assert_int(por_tipo.get(ReglasDeLaLimpieza.TipoDeMancha.MOHO, 0)).is_equal(1)
	assert_int(por_tipo.get(ReglasDeLaLimpieza.TipoDeMancha.CACA, 0)).is_equal(1)


func test_cada_lugar_lleva_la_mancha_de_la_ficha() -> void:  # AC-CLN-016
	var piso := _piso()
	var esperados := {
		PisoDelLocal.Lugar.ENTRADA: ReglasDeLaLimpieza.TipoDeMancha.POLVO,
		PisoDelLocal.Lugar.GONDOLAS: ReglasDeLaLimpieza.TipoDeMancha.POLVO,
		PisoDelLocal.Lugar.DEPOSITO: ReglasDeLaLimpieza.TipoDeMancha.MOHO,
		PisoDelLocal.Lugar.BANO: ReglasDeLaLimpieza.TipoDeMancha.CACA,
	}
	for lugar: PisoDelLocal.Lugar in esperados:
		assert_int(piso.mancha_de(lugar).tipo()).is_equal(esperados[lugar])


func test_cada_jornada_arranca_sucia_con_el_balde_vacio_y_la_mopa_seca() -> void:  # AC-CLN-016
	# Instancias nuevas y no las mismas: con un piso compartido, lo limpiado anoche llegaría
	# limpio esta noche, y el balde teñido de anoche ahorraría el primer viaje a la canilla.
	var anoche := _piso()
	_preparar(anoche, JABON_AMARILLO)
	anoche.pasar(MOPA, PisoDelLocal.Lugar.ENTRADA)
	var hoy := _piso()
	assert_int(_sucias(hoy).size()).is_equal(4)
	assert_bool(hoy.balde().tiene_agua()).is_false()
	assert_bool(hoy.mopa().esta_mojada()).is_false()


func test_el_piso_queda_limpio_recien_con_la_ultima_mancha() -> void:  # AC-CLN-012
	var piso := _piso()
	var pedidos := {
		PisoDelLocal.Lugar.ENTRADA: JABON_AMARILLO,
		PisoDelLocal.Lugar.GONDOLAS: JABON_AMARILLO,
		PisoDelLocal.Lugar.DEPOSITO: JABON_AZUL,
		PisoDelLocal.Lugar.BANO: JABON_ROSA,
	}
	var lugares := pedidos.keys()
	for indice in lugares.size():
		piso.usar(BALDE, INODORO)
		_preparar(piso, pedidos[lugares[indice]])
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


func test_con_una_mojada_de_amarillo_se_borran_las_dos_de_polvo() -> void:  # AC-CLN-023
	var piso := _piso()
	_preparar(piso, JABON_AMARILLO)
	for lugar: PisoDelLocal.Lugar in [PisoDelLocal.Lugar.ENTRADA, PisoDelLocal.Lugar.GONDOLAS]:
		assert_int(piso.pasar(MOPA, lugar)).is_equal(ReglasDeLaLimpieza.Resultado.MANCHA_BORRADA)
	assert_array(_sucias(piso)).contains_exactly_in_any_order(
		[PisoDelLocal.Lugar.DEPOSITO, PisoDelLocal.Lugar.BANO]
	)


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
	assert_int(_sucias(piso).size()).is_equal(4)


func test_los_gestos_al_reves_o_cruzados_no_hacen_nada() -> void:  # AC-CLN-024
	var piso := _piso()
	var pares: Array[Array] = [
		[LAVATORIO, BALDE],
		[BALDE, BALDE],
		[JABON_AZUL, LAVATORIO],
		[MOPA, LAVATORIO],
		[MOPA, INODORO],
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
	assert_int(_sucias(piso).size()).is_equal(4)


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
