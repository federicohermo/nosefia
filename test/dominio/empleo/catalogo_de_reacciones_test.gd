## El catálogo: que estén todas las celdas, que cada archivo esté en la fila que dice ser, y que
## por encima del tope siga contestando.
##
## **El caso que más pesa es el que cruza la clave.** Un `.tres` colgado de la fila equivocada no
## da ningún error —la clave del `enum` se guarda como un entero pelado—, así que sin esa cruza
## el jugador leería la reacción de otra tarea y los seis nodos seguirían en verde.
extends GdUnitTestSuite

const CATALOGO := "res://src/dominio/empleo/catalogo_de_reacciones.gd"

## El estado de la tarea traducido a su clave, con el mismo orden que usa el catálogo: primero
## la que no se hizo. Se escribe como tabla y no como condición para que el test no reimplemente
## la decisión que está verificando.
const SOBRE_LA_TAREA := [Reaccion.Sobre.TAREA_SIN_CUMPLIR, Reaccion.Sobre.TAREA_CUMPLIDA]


func test_hay_una_reaccion_por_cada_tarea_en_sus_dos_estados() -> void:  # 017-AC2
	for tipo: Tarea.Tipo in Tarea.Tipo.values():
		for cumplida in [false, true]:
			var reaccion := CatalogoDeReacciones.de_la_tarea(tipo, cumplida)
			(
				assert_object(reaccion)
				. override_failure_message(
					"falta la reacción de la tarea %d con cumplida=%s" % [tipo, cumplida]
				)
				. is_not_null()
			)
			assert_str(reaccion.texto).is_not_empty()


func test_cada_reaccion_de_tarea_repite_adentro_la_fila_en_la_que_esta() -> void:  # 017-AC2
	# **Éste es el que caza el `.tres` mal enganchado.** El catálogo lo indexa por una clave y el
	# archivo la vuelve a decir adentro: si las dos no coinciden, alguien movió una fila.
	for tipo: Tarea.Tipo in Tarea.Tipo.values():
		for cumplida in [false, true]:
			var reaccion := CatalogoDeReacciones.de_la_tarea(tipo, cumplida)
			(
				assert_int(reaccion.indice)
				. override_failure_message(
					(
						"la reacción de la fila %d dice ser de la %d: el `.tres` está mal colgado"
						% [tipo, reaccion.indice]
					)
				)
				. is_equal(tipo)
			)
			assert_int(reaccion.sobre).is_equal(SOBRE_LA_TAREA[int(cumplida)])


func test_hay_un_comentario_por_cada_apercibimiento_hasta_el_tope() -> void:  # 017-AC2
	for cuantos in range(Reglas.APERCIBIMIENTOS_HASTA_EL_DESPIDO + 1):
		var reaccion := CatalogoDeReacciones.del_comentario(cuantos)
		(
			assert_object(reaccion)
			. override_failure_message("falta el comentario de %d apercibimientos" % cuantos)
			. is_not_null()
		)
		assert_int(reaccion.sobre).is_equal(Reaccion.Sobre.APERCIBIMIENTOS)
		assert_int(reaccion.indice).is_equal(cuantos)


func test_por_encima_del_tope_contesta_la_del_despido_y_no_un_nulo() -> void:  # 017-AC2
	# Una jornada grave sube de a dos, así que el contador pasa el tope sin pisarlo: con 3
	# encima, una noche mala deja 5. Sin saturar, la placa del despido saldría vacía justo el
	# día que importa.
	var tope := Reglas.APERCIBIMIENTOS_HASTA_EL_DESPIDO
	var despido := CatalogoDeReacciones.del_comentario(tope)
	for pasado in range(tope + 1, tope + Reglas.APERCIBIMIENTOS_POR_BANDA_GRAVE + 1):
		(
			assert_object(CatalogoDeReacciones.del_comentario(pasado))
			. override_failure_message("con %d apercibimientos el catálogo se quedó mudo" % pasado)
			. is_same(despido)
		)


func test_el_catalogo_no_decide_nada_porque_es_una_tabla() -> void:  # 017-AC3
	# Una decisión acá sería una regla del juego escrita en un lugar donde nadie la busca: el
	# catálogo indexa y nada más. El día que haga falta un `match`, lo que falta es una fila.
	#
	# Se afirma primero que el archivo se leyó: un archivo vacío no tiene condiciones, así que
	# sin esta línea una ruta equivocada dejaría el caso en verde sin haber mirado nada.
	assert_str(FileAccess.get_file_as_string(CATALOGO)).is_not_empty()
	(
		assert_array(condiciones_en(CATALOGO))
		. override_failure_message("`catalogo_de_reacciones.gd` decide en vez de indexar")
		. is_empty()
	)


## Las líneas de código de un archivo que abren una condición. Corta en el primer `#`, así que
## las palabras de los comentarios no cuentan, y busca por palabra entera: `verificar` no es un
## `if`.
static func condiciones_en(ruta: String) -> Array[String]:
	var abiertas: Array[String] = []
	var condicion := RegEx.create_from_string("\\b(if|elif|match)\\b")
	for linea in FileAccess.get_file_as_string(ruta).split("\n"):
		var codigo: String = linea.split("#")[0]
		if not condicion.search_all(codigo).is_empty():
			abiertas.append(linea.strip_edges())
	return abiertas
