extends GdUnitTestSuite

const JEFE := Conversacion.Interlocutor.JEFE
const FOTO := "J5_CINDOLOR_FOTO"
const TEXTO := "J5_CINDOLOR_TEXTO"
const TEXTO_DE_LA_CUARTA := "J2_CONTENEDOR_TEXTO"


func _bandeja_en(jornada: int) -> Bandeja:
	var bandeja := Bandeja.new(Conversacion.desde_disco())
	bandeja.abrir_jornada(jornada)
	return bandeja


func _identidades(mensajes: Array[Mensaje]) -> PackedStringArray:
	var identidades := PackedStringArray()
	for mensaje: Mensaje in mensajes:
		identidades.append(mensaje.identidad)
	return identidades


func test_la_cuarta_conserva_las_identidades_de_su_foto_y_su_texto() -> void:  # AC-INV-100
	var identidades := _identidades(_bandeja_en(4).mensajes_de(JEFE))
	assert_int(identidades.size()).is_greater(2)
	assert_str(identidades[-2]).is_equal("J2_CONTENEDOR_FOTO")
	assert_str(identidades[-1]).is_equal(TEXTO_DE_LA_CUARTA)
	var texto := _bandeja_en(4).mensajes_de(JEFE)[-1]
	assert_bool(texto.dice_algo()).is_true()
	assert_object(texto.foto).is_null()


func test_la_quinta_suma_exactamente_una_foto_y_un_texto_a_continuacion() -> void:  # AC-INV-101
	var de_la_cuarta := _bandeja_en(4).mensajes_de(JEFE)
	var mensajes := _bandeja_en(5).mensajes_de(JEFE)
	assert_int(mensajes.size()).is_equal(de_la_cuarta.size() + 2)
	assert_str(mensajes[-3].identidad).is_equal(TEXTO_DE_LA_CUARTA)
	assert_str(mensajes[-2].identidad).is_equal(FOTO)
	assert_object(mensajes[-2].foto).is_not_null()
	assert_str(mensajes[-1].identidad).is_equal(TEXTO)
	assert_bool(mensajes[-1].dice_algo()).is_true()
	assert_object(mensajes[-1].foto).is_null()


func test_la_foto_de_la_quinta_se_amplia_con_su_texto() -> void:  # AC-INV-101
	var bandeja := _bandeja_en(5)
	var mensajes := bandeja.mensajes_de(JEFE)
	assert_object(bandeja.adjunto_de(JEFE, mensajes.size() - 2)).is_same(mensajes[-1])


func test_la_quinta_llega_despues_de_la_devolucion_de_la_cuarta() -> void:  # AC-INV-101
	var bandeja := _bandeja_en(4)
	var devolucion := Mensaje.new()
	devolucion.identidad = "DEVOLUCION_J4_0"
	devolucion.texto = "Devolución"
	devolucion.jornada = 4
	devolucion.momento = Mensaje.Momento.CIERRE
	assert_bool(bandeja.recibir(JEFE, devolucion)).is_true()
	bandeja.abrir_jornada(5)
	var identidades := _identidades(bandeja.mensajes_de(JEFE))
	assert_array(identidades.slice(-4)).is_equal(
		PackedStringArray([TEXTO_DE_LA_CUARTA, "DEVOLUCION_J4_0", FOTO, TEXTO])
	)


func test_repetir_la_apertura_cinco_no_duplica_los_mensajes() -> void:  # AC-INV-101
	var bandeja := _bandeja_en(5)
	var antes := bandeja.mensajes_de(JEFE)
	bandeja.abrir_jornada(5)
	assert_array(bandeja.mensajes_de(JEFE)).is_equal(antes)
	assert_int(_identidades(antes).count(FOTO)).is_equal(1)
	assert_int(_identidades(antes).count(TEXTO)).is_equal(1)


func test_antes_de_la_quinta_los_mensajes_no_existen() -> void:  # AC-INV-102
	for jornada: int in range(ReglasDeLaPartida.PRIMERA_JORNADA, 5):
		var identidades := _identidades(_bandeja_en(jornada).mensajes_de(JEFE))
		assert_bool(identidades.has(FOTO)).is_false()
		assert_bool(identidades.has(TEXTO)).is_false()


func test_retomar_en_la_quinta_los_cuenta_una_sola_vez_como_nuevos() -> void:  # AC-INV-102
	var bandeja := Bandeja.new(Conversacion.desde_disco())
	bandeja.abrir_jornada(4)
	bandeja.marcar_leida(JEFE)
	assert_int(bandeja.no_leidos(JEFE)).is_zero()
	bandeja.abrir_jornada(5)
	assert_int(bandeja.no_leidos(JEFE)).is_equal(2)
	bandeja.abrir_jornada(5)
	assert_int(bandeja.no_leidos(JEFE)).is_equal(2)
	var retomada := _bandeja_en(5)
	assert_int(retomada.no_leidos(JEFE)).is_equal(retomada.mensajes_de(JEFE).size())
