## Lo único que una revelación decide es si dice algo, y por eso es lo único que se prueba acá.
##
## Un texto en blanco no es una revelación vacía inofensiva: es un objeto que promete algo al
## examinarlo y contesta una línea en blanco. `dice_algo()` es lo que hace que ese objeto quede
## del lado de los que no revelan nada, y con eso `Hallazgos` no lo cuenta.
extends GdUnitTestSuite

const Revelacion := preload("res://src/dominio/investigacion/revelacion.gd")


func test_una_revelacion_recien_creada_no_dice_nada() -> void:
	assert_bool(Revelacion.new().dice_algo()).is_false()


func test_un_texto_de_puros_blancos_tampoco_dice_nada() -> void:
	# El caso que se cuela al escribir un `.tres` a mano: el campo quedó con un espacio o un
	# salto de línea, se ve «lleno» en el inspector y no revela nada.
	var revelacion := Revelacion.new()
	revelacion.texto = "   \n\t "
	assert_bool(revelacion.dice_algo()).is_false()


func test_con_texto_dice_algo() -> void:
	var revelacion := Revelacion.new()
	revelacion.texto = "La fecha de vencimiento está tachada con marcador."
	assert_bool(revelacion.dice_algo()).is_true()
	assert_str(revelacion.texto).is_not_empty()
