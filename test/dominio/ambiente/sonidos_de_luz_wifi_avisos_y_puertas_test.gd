## Los ocho sonidos que llegaron de la rama `Sonidos`: qué fila de la tabla pide cada evento.
extends GdUnitTestSuite


func _fila(evento: EntradaSonora.Evento) -> EntradaSonora:
	var tabla := TablaDeSonidos.desde_disco()
	assert_object(tabla).is_not_null()
	var fila := tabla.de(evento)
	assert_object(fila).is_not_null()
	return fila


func _audio(evento: EntradaSonora.Evento) -> String:
	var fila := _fila(evento)
	if fila == null or fila.stream == null:
		return ""
	return fila.stream.resource_path.get_file().get_basename()


func test_se_corta_la_luz_y_suena_el_corte() -> void:
	assert_str(_audio(EntradaSonora.Evento.LUZ_CORTADA)).is_equal("SFX_EVENTO_CorteLuz")
	assert_str(_fila(EntradaSonora.Evento.LUZ_CORTADA).senal).is_equal("luz_cortada")


func test_vuelve_la_luz_y_suena_la_vuelta() -> void:
	assert_str(_audio(EntradaSonora.Evento.LUZ_VUELTA)).is_equal("SFX_EVENTO_VuelveLuz")
	assert_str(_fila(EntradaSonora.Evento.LUZ_VUELTA).senal).is_equal("luz_vuelta")


func test_apagar_el_router_suena_su_audio() -> void:
	assert_str(_audio(EntradaSonora.Evento.WIFI_APAGADO)).is_equal("SFX_NOLEV_Wifi_Apagar")
	assert_str(_fila(EntradaSonora.Evento.WIFI_APAGADO).senal).is_equal("router_apagado")


func test_prender_el_router_suena_su_audio() -> void:
	assert_str(_audio(EntradaSonora.Evento.WIFI_PRENDIDO)).is_equal("SFX_NOLEV_Wifi_Prender")
	assert_str(_fila(EntradaSonora.Evento.WIFI_PRENDIDO).senal).is_equal("router_prendido")


func test_entra_y_sale_un_cartel_y_suena_cada_uno() -> void:
	var entra := _fila(EntradaSonora.Evento.NOTIFICACION_ENTRADA)
	var sale := _fila(EntradaSonora.Evento.NOTIFICACION_SALIDA)
	assert_str(_audio(EntradaSonora.Evento.NOTIFICACION_ENTRADA)).is_equal(
		"SFX_EVENTO_NotificacionEntra"
	)
	assert_str(_audio(EntradaSonora.Evento.NOTIFICACION_SALIDA)).is_equal(
		"SFX_EVENTO_NotificacionSale"
	)
	assert_str(entra.senal).is_equal("cartel_entrado")
	assert_str(sale.senal).is_equal("cartel_salido")
	assert_str(entra.bus).is_equal(EntradaSonora.BUS_DE_INTERFAZ)
	assert_str(sale.bus).is_equal(EntradaSonora.BUS_DE_INTERFAZ)


func test_forzar_la_puerta_con_la_llave_suena_su_audio() -> void:
	var evento := EntradaSonora.Evento.PUERTA_FORZADA_CON_LLAVE
	assert_str(_audio(evento)).is_equal("SFX_NOLEV_Puerta_AbrirLlave")
	assert_str(_fila(evento).senal).is_equal("puerta_forzada_con_llave")


func test_forzar_la_puerta_con_la_palanca_suena_su_audio() -> void:
	var evento := EntradaSonora.Evento.PUERTA_FORZADA_CON_PALANCA
	assert_str(_audio(evento)).is_equal("SFX_NOLEV_Puerta_AbrirPalanca")
	assert_str(_fila(evento).senal).is_equal("puerta_forzada_con_palanca")


func test_los_eventos_nuevos_van_al_final_sin_mover_a_los_anteriores() -> void:
	assert_int(EntradaSonora.Evento.NOTA_ANOTADA).is_less(EntradaSonora.Evento.LUZ_CORTADA)
	assert_int(EntradaSonora.Evento.PUERTA_ABIERTA).is_less(EntradaSonora.Evento.LUZ_CORTADA)


func test_el_router_suena_desde_el_router_y_la_luz_suena_plana() -> void:
	for evento: EntradaSonora.Evento in [
		EntradaSonora.Evento.WIFI_APAGADO, EntradaSonora.Evento.WIFI_PRENDIDO
	]:
		var fila := _fila(evento)
		assert_bool(fila.posicional).is_true()
		assert_str(fila.emisor).is_equal(&"Router")
	for evento: EntradaSonora.Evento in [
		EntradaSonora.Evento.LUZ_CORTADA, EntradaSonora.Evento.LUZ_VUELTA
	]:
		assert_bool(_fila(evento).posicional).is_false()


func test_forzar_la_puerta_suena_desde_la_puerta() -> void:
	for evento: EntradaSonora.Evento in [
		EntradaSonora.Evento.PUERTA_FORZADA_CON_LLAVE,
		EntradaSonora.Evento.PUERTA_FORZADA_CON_PALANCA
	]:
		assert_bool(_fila(evento).posicional).is_true()
