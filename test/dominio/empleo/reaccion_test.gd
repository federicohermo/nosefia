## La reacción del jefe como dato: una clave, un texto, y que las dos sobrevivan al disco.
##
## El round-trip no es ceremonia. Un `@export` de `enum` se guarda como **un entero pelado**
## —medido en el research del spec—, así que si la clave no volviera del archivo, un `.tres`
## enganchado en la fila equivocada no daría ningún error: daría la reacción equivocada, en
## silencio. Este caso es el que verifica que la clave vuelve.
extends GdUnitTestSuite

## Se guarda en `user://` y no en `res://`: el proyecto exportado es de sólo lectura, y un test
## que escribe adentro del árbol deja basura que la corrida siguiente encuentra.
const DESTINO := "user://reaccion_round_trip.tres"


func after_test() -> void:
	DirAccess.remove_absolute(DESTINO)


func test_la_reaccion_vuelve_del_disco_con_su_clave_y_su_texto() -> void:  # 017-AC1
	var reaccion := Reaccion.new()
	reaccion.sobre = Reaccion.Sobre.APERCIBIMIENTOS
	reaccion.indice = Reglas.APERCIBIMIENTOS_HASTA_EL_DESPIDO
	reaccion.texto = "Estás despedido."
	assert_int(ResourceSaver.save(reaccion, DESTINO)).is_equal(OK)

	var vuelta: Reaccion = ResourceLoader.load(DESTINO, "", ResourceLoader.CACHE_MODE_IGNORE)
	assert_object(vuelta).is_not_null()
	assert_int(vuelta.sobre).is_equal(Reaccion.Sobre.APERCIBIMIENTOS)
	assert_int(vuelta.indice).is_equal(Reglas.APERCIBIMIENTOS_HASTA_EL_DESPIDO)
	assert_str(vuelta.texto).is_equal("Estás despedido.")


func test_las_tres_claves_posibles_estan_declaradas() -> void:  # 017-AC1
	# Una tarea cumplida, una sin cumplir y el comentario general: son las tres cosas que el
	# jefe comenta, y son un conjunto cerrado. Un cuarto valor sin fila en el catálogo se caza
	# en `catalogo_de_reacciones_test.gd`, que recorre el enum en vez de una lista a mano.
	assert_int(Reaccion.Sobre.size()).is_equal(3)
