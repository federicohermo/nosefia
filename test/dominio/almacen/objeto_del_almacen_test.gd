## Qué muestra un objeto antes y después de examinarlo, y que los `.tres` del almacén cumplen
## las dos mitades.
##
## Los `.tres` se recorren con `DirAccess` en vez de nombrarlos uno por uno: una lista escrita a
## mano deja afuera al objeto que alguien agregue mañana, y ese objeto es justamente el que puede
## nacer sin revelación o con la revelación ya visible sin examinar — que es el bug que borra la
## mitad investigativa de la tensión sin romper nada.
extends GdUnitTestSuite

const ObjetoDelAlmacen := preload("res://src/dominio/almacen/objeto_del_almacen.gd")
const Revelacion := preload("res://src/dominio/investigacion/revelacion.gd")
const CARPETA_DE_LOS_OBJETOS := "res://src/dominio/almacen"


func _objetos_del_almacen() -> Array[Resource]:
	var cargados: Array[Resource] = []
	for archivo in DirAccess.get_files_at(CARPETA_DE_LOS_OBJETOS):
		if archivo.ends_with(".tres"):
			cargados.append(load("%s/%s" % [CARPETA_DE_LOS_OBJETOS, archivo]))
	return cargados


func test_un_objeto_sin_revelacion_muestra_lo_mismo_examinado_que_sin_examinar() -> void:
	# Es el caso del cajón y de la puerta: se pueden mirar y no hay nada abajo. Que las dos
	# respuestas sean iguales es lo que permite escribir la vista sin un `if` propio.
	var objeto := ObjetoDelAlmacen.new()
	objeto.nombre = "Cajón vacío"
	assert_str(objeto.texto_visible(true)).is_equal(objeto.texto_visible(false))
	assert_bool(objeto.tiene_revelacion()).is_false()


func test_lo_fijo_no_se_levanta_y_lo_demas_si() -> void:
	var lata := ObjetoDelAlmacen.new()
	assert_bool(lata.es_levantable()).is_true()
	var puerta := ObjetoDelAlmacen.new()
	puerta.levantable = false
	assert_bool(puerta.es_levantable()).is_false()


func test_los_objetos_del_almacen_cargan_y_todos_tienen_algo_que_revelar() -> void:  # 006-AC4
	var objetos := _objetos_del_almacen()
	(
		assert_int(objetos.size())
		. override_failure_message(
			"no hay un solo .tres en %s, o sea que examinar no revela nada" % CARPETA_DE_LOS_OBJETOS
		)
		. is_greater(0)
	)
	for objeto in objetos:
		assert_object(objeto).is_instanceof(ObjetoDelAlmacen)
		assert_str(String(objeto.id)).is_not_empty()
		assert_bool(objeto.tiene_revelacion()).is_true()
		assert_object(objeto.revelacion).is_instanceof(Revelacion)


func test_la_revelacion_solo_se_ve_despues_de_examinar() -> void:  # 006-AC4
	# Las dos mitades del mismo mordisco: si el texto ya se viera sin examinar, examinar no
	# costaría tiempo y la tensión aritmética del turno se afloja sin que nadie lo decida.
	for objeto in _objetos_del_almacen():
		var oculto: String = objeto.texto_visible(false)
		var revelado: String = objeto.texto_visible(true)
		var secreto: String = objeto.revelacion.texto
		assert_str(oculto).not_contains(secreto)
		assert_str(revelado).contains(secreto)
