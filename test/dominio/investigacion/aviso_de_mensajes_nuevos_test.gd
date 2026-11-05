## El aviso del ícono del HUD: qué número ve el jugador y cuándo vibra.
extends GdUnitTestSuite

const DURACION := 0.8


func _liberado() -> AvisoDeMensajesNuevos:
	var aviso := AvisoDeMensajesNuevos.new()
	aviso.soltar()
	return aviso


func test_el_numero_es_el_total_y_cero_no_se_ve() -> void:  # AC-INV-180
	var aviso := _liberado()
	aviso.cambiar(3)
	assert_int(aviso.numero()).is_equal(3)
	assert_bool(aviso.se_ve()).is_true()
	aviso.cambiar(1)
	assert_int(aviso.numero()).is_equal(1)
	aviso.cambiar(0)
	assert_bool(aviso.se_ve()).is_false()


func test_vibra_solo_cuando_el_total_sube() -> void:  # AC-INV-181
	var aviso := _liberado()
	assert_bool(aviso.cambiar(1)).is_true()
	assert_bool(aviso.cambiar(1)).is_false()
	assert_bool(aviso.cambiar(3)).is_true()
	assert_bool(aviso.cambiar(2)).is_false()
	assert_bool(aviso.cambiar(0)).is_false()
	assert_bool(aviso.cambiar(1)).is_true()


func test_la_vibracion_se_mueve_y_vuelve_exacta() -> void:  # AC-INV-181
	var vibrando := AvisoDeMensajesNuevos.desplazamiento(DURACION * 0.1, DURACION)
	assert_float(vibrando.length()).is_greater(0.0)
	assert_float(vibrando.length()).is_less_equal(AvisoDeMensajesNuevos.AMPLITUD_DE_LA_VIBRACION)
	assert_vector(AvisoDeMensajesNuevos.desplazamiento(DURACION, DURACION)).is_equal(Vector2.ZERO)
	assert_vector(AvisoDeMensajesNuevos.desplazamiento(DURACION * 3.0, DURACION)).is_equal(
		Vector2.ZERO
	)


func test_la_duracion_es_la_del_sonido_de_mensaje_recibido() -> void:  # AC-INV-181
	var tabla := TablaDeSonidos.desde_disco()
	var fila := tabla.alguna_de(EntradaSonora.Evento.MENSAJE_DEL_CELULAR)
	assert_float(AvisoDeMensajesNuevos.duracion_de_la_vibracion(tabla)).is_equal(
		fila.stream.get_length()
	)
	assert_float(AvisoDeMensajesNuevos.duracion_de_la_vibracion(TablaDeSonidos.new())).is_zero()


func test_con_la_persiana_baja_nada_se_pinta_ni_vibra() -> void:  # AC-INV-182
	var aviso := AvisoDeMensajesNuevos.new()
	assert_bool(aviso.cambiar(2)).is_false()
	assert_bool(aviso.cambiar(3)).is_false()
	assert_bool(aviso.se_ve()).is_false()
	assert_bool(aviso.soltar()).is_true()
	assert_int(aviso.numero()).is_equal(3)


func test_al_subir_la_persiana_vibra_solo_si_supera_lo_que_se_veia() -> void:  # AC-INV-182
	var aviso := _liberado()
	aviso.cambiar(2)
	aviso.retener()
	aviso.cambiar(2)
	assert_bool(aviso.soltar()).is_false()
	assert_int(aviso.numero()).is_equal(2)
	aviso.retener()
	aviso.cambiar(0)
	aviso.cambiar(1)
	assert_bool(aviso.soltar()).is_false()
	aviso.retener()
	aviso.cambiar(4)
	assert_bool(aviso.soltar()).is_true()
