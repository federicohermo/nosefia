## Por qué camino entra el jugador al almacén: con la copia que se calentó debajo del menú, con un
## almacén nuevo que no se vuelve a calentar, o calentando uno.
extends GdUnitTestSuite


func test_sin_copia_se_calienta_un_almacen() -> void:
	var camino := EntradaAlAlmacen.de(false, true, false, false)
	assert_int(camino).is_equal(EntradaAlAlmacen.Camino.CALENTAR_UN_ALMACEN)


func test_con_otras_preferencias_la_copia_no_vale_y_se_calienta_otro() -> void:
	for nuevo_juego: bool in [false, true]:
		var camino := EntradaAlAlmacen.de(true, false, nuevo_juego, false)
		assert_int(camino).is_equal(EntradaAlAlmacen.Camino.CALENTAR_UN_ALMACEN)


func test_continuar_entra_con_la_copia_calentada() -> void:
	for leyo_un_guardado: bool in [false, true]:
		var camino := EntradaAlAlmacen.de(true, true, false, leyo_un_guardado)
		assert_int(camino).is_equal(EntradaAlAlmacen.Camino.LA_COPIA)


func test_nuevo_juego_sobre_una_copia_sin_guardado_entra_con_ella() -> void:
	var camino := EntradaAlAlmacen.de(true, true, true, false)
	assert_int(camino).is_equal(EntradaAlAlmacen.Camino.LA_COPIA)


## La copia leyó la partida vieja: no se la usa, pero sus shaders ya están compilados y no se
## calienta otra vez.
func test_nuevo_juego_sobre_la_copia_de_un_guardado_entra_a_un_almacen_nuevo() -> void:
	var camino := EntradaAlAlmacen.de(true, true, true, true)
	assert_int(camino).is_equal(EntradaAlAlmacen.Camino.UN_ALMACEN_NUEVO)
