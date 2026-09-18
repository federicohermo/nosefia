## Un mensaje de un chat: quién lo mandó y qué dice.
##
## Existe como archivo propio y no como clase interna de `Conversacion`, y es una medición y no
## un gusto: con el `Resource` declarado adentro de otra clase, el `.tres` guarda una referencia
## a un script que no se puede resolver y leerle un campo contesta `<null>`.
extends GdUnitTestSuite


func test_un_mensaje_con_texto_dice_algo() -> void:  # 009-AC5
	var mensaje := Mensaje.new()
	mensaje.de_quien = "El jefe"
	mensaje.texto = "Mañana pasás por el depósito."
	assert_bool(mensaje.dice_algo()).is_true()


func test_un_mensaje_vacio_no_dice_nada() -> void:  # 009-AC5
	assert_bool(Mensaje.new().dice_algo()).is_false()


func test_un_mensaje_de_puros_espacios_tampoco_dice_nada() -> void:  # 009-AC5
	# Sin el recorte, un renglón de espacios pasaría por contenido y la conversación parecería
	# tener algo para leer donde no hay nada.
	var mensaje := Mensaje.new()
	mensaje.texto = "   \n\t "
	assert_bool(mensaje.dice_algo()).is_false()
