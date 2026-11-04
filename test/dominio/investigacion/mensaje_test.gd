## Un mensaje de un chat: quién lo mandó y qué dice.
##
## Existe como archivo propio y no como clase interna de `Conversacion`, y es una medición y no
## un gusto: con el `Resource` declarado adentro de otra clase, el `.tres` guarda una referencia
## a un script que no se puede resolver y leerle un campo contesta `<null>`.
extends GdUnitTestSuite


func test_la_foto_sola_es_contenido_y_el_mensaje_llega_en_la_primera() -> void:  # AC-INV-031
	var mensaje := Mensaje.new()
	assert_int(mensaje.jornada).is_equal(1)
	mensaje.foto = GradientTexture2D.new()
	assert_bool(mensaje.dice_algo()).is_true()


func test_un_mensaje_con_texto_dice_algo() -> void:
	var mensaje := Mensaje.new()
	mensaje.de_quien = "El jefe"
	mensaje.texto = "Mañana pasás por el depósito."
	assert_bool(mensaje.dice_algo()).is_true()


func test_un_mensaje_vacio_no_dice_nada() -> void:
	assert_bool(Mensaje.new().dice_algo()).is_false()


func test_un_mensaje_de_puros_espacios_tampoco_dice_nada() -> void:
	# Sin el recorte, un renglón de espacios pasaría por contenido y la conversación parecería
	# tener algo para leer donde no hay nada.
	var mensaje := Mensaje.new()
	mensaje.texto = "   \n\t "
	assert_bool(mensaje.dice_algo()).is_false()


func _con_hora(jornada: int, momento: Mensaje.Momento, hora: String) -> Mensaje:
	var mensaje := Mensaje.new()
	mensaje.jornada = jornada
	mensaje.momento = momento
	mensaje.hora = hora
	return mensaje


func test_la_hora_cruza_el_guardado() -> void:  # AC-INV-106
	var nota := Mensaje.new()
	nota.identidad = "NOTA_2A_TEXTO"
	nota.texto = "Una nota"
	nota.jornada = 4
	nota.hora = "21:00"
	var cargada := Mensaje.desde_datos(str_to_var(var_to_str(nota.a_datos())))
	assert_object(cargada).is_not_null()
	assert_str(cargada.hora).is_equal("21:00")


func test_un_dato_guardado_sin_hora_carga_sin_hora() -> void:  # AC-INV-106
	var viejo := {"texto": "Una nota", "identidad": "NOTA_2A_TEXTO", "jornada": 4, "orden": 0}
	var cargada := Mensaje.desde_datos(viejo)
	assert_object(cargada).is_not_null()
	assert_str(cargada.hora).is_empty()
	assert_str(cargada.texto).is_equal("Una nota")


func test_la_tanda_corta_en_el_mediodia() -> void:  # AC-INV-107
	var antes := _con_hora(4, Mensaje.Momento.APERTURA, "11:59")
	var despues := _con_hora(4, Mensaje.Momento.APERTURA, "12:00")
	var tambien := _con_hora(4, Mensaje.Momento.APERTURA, "19:31")
	assert_int(antes.tanda()).is_not_equal(despues.tanda())
	assert_int(despues.tanda()).is_equal(tambien.tanda())
	assert_int(_con_hora(5, Mensaje.Momento.APERTURA, "12:00").tanda()).is_not_equal(
		despues.tanda()
	)


func test_la_devolucion_de_la_manana_es_del_dia_de_la_jornada_siguiente() -> void:  # AC-INV-107
	var devolucion := _con_hora(3, Mensaje.Momento.CIERRE, "8:26")
	var yasmin := _con_hora(4, Mensaje.Momento.APERTURA, "17:34")
	assert_int(devolucion.dia()).is_equal(yasmin.dia())
	assert_int(devolucion.tanda()).is_not_equal(yasmin.tanda())
	assert_int(_con_hora(3, Mensaje.Momento.APERTURA, "19:41").dia()).is_equal(3)


func test_sin_hora_y_sin_fecha_no_inventan_tanda() -> void:  # AC-INV-108
	var sin_hora := _con_hora(4, Mensaje.Momento.CIERRE, "")
	assert_str(sin_hora.hora).is_empty()
	assert_int(sin_hora.dia()).is_equal(4)
	assert_int(sin_hora.tanda()).is_equal(_con_hora(4, Mensaje.Momento.APERTURA, "19:00").tanda())
	var legado := Mensaje.desde_datos("Texto sin fecha")
	assert_str(legado.hora).is_empty()
	assert_int(legado.tanda()).is_less(0)
