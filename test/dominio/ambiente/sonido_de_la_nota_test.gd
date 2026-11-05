extends GdUnitTestSuite


func test_anotar_una_pista_suena_enviado_y_el_mensaje_del_celular_recibido() -> void:  # AC-AMB-031
	var tabla := TablaDeSonidos.desde_disco()
	assert_object(tabla).is_not_null()
	if tabla == null:
		return
	var nota := tabla.de(EntradaSonora.Evento.NOTA_ANOTADA)
	var mensaje := tabla.de(EntradaSonora.Evento.MENSAJE_DEL_CELULAR)
	assert_object(nota).is_not_null()
	if nota == null:
		return
	assert_str(nota.senal).is_equal("pista_nueva")
	assert_str(nota.bus).is_equal(EntradaSonora.BUS_DE_INTERFAZ)
	assert_bool(nota.posicional).is_false()
	assert_int(nota.cantidad_de_variantes()).is_equal(1)
	assert_str(nota.variante(0).resource_path.get_file().get_basename()).is_equal(
		"SFX_INTERFAZ_Celular_Mensaje_Enviado"
	)
	assert_str(mensaje.variante(0).resource_path.get_file().get_basename()).is_equal(
		"SFX_INTERFAZ_Celular_Mensaje_Recibido"
	)
