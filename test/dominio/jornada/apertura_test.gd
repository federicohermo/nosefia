## Cómo se arma el turno de una jornada: qué tareas trae y con cuánto tiempo nace.
##
## Ningún caso escribe a mano cuántas obligatorias hay. Se comparan contra `Tarea.Tipo`, que es
## la única fuente: el 001 ya declaró las cinco, y una sexta se agrega a ese `enum` sin que este
## archivo se toque.
extends GdUnitTestSuite


func test_hay_una_obligatoria_por_cada_tipo_de_tarea() -> void:
	assert_int(Apertura.obligatorias().size()).is_equal(Tarea.Tipo.size())


func test_ningun_tipo_de_tarea_aparece_dos_veces() -> void:
	# Un tipo repetido daría una lista del tamaño correcto con un tipo faltante, y el jugador
	# vería una obligatoria imposible de cumplir sin que nada se ponga en rojo.
	var vistos: Array[int] = []
	for tarea in Apertura.obligatorias():
		assert_bool(vistos.has(tarea.tipo())).is_false()
		vistos.append(tarea.tipo())
	assert_int(vistos.size()).is_equal(Tarea.Tipo.size())


func test_la_cantidad_declarada_coincide_con_la_lista_que_se_arma() -> void:
	# Son dos funciones y una sola verdad: si se separan, el HUD cuenta contra un número y el
	# turno contra otro.
	assert_int(Apertura.cantidad_de_obligatorias()).is_equal(Apertura.obligatorias().size())


func test_el_turno_de_la_jornada_nace_con_el_presupuesto_entero() -> void:
	var turno := Apertura.turno_de_la_jornada(Apertura.obligatorias())
	assert_float(turno.tiempo_restante()).is_equal(Reglas.DURACION_DEL_TURNO)


func test_el_turno_de_la_jornada_nace_sin_ninguna_tarea_cumplida() -> void:
	var turno := Apertura.turno_de_la_jornada(Apertura.obligatorias())
	assert_int(turno.tareas_cumplidas()).is_equal(0)
	assert_bool(turno.todas_cumplidas()).is_false()


func test_el_turno_cuenta_contra_la_lista_que_recibe_y_no_contra_una_copia() -> void:
	# Es lo que hace posible que el reloj entregue la misma instancia por la que el 008 va a
	# preguntar: completar una copia devolvería `true` sin subir el contador del turno.
	var obligatorias := Apertura.obligatorias()
	var turno := Apertura.turno_de_la_jornada(obligatorias)
	assert_bool(turno.completar(obligatorias[0])).is_true()
	assert_int(turno.tareas_cumplidas()).is_equal(1)


func test_el_inventario_de_la_jornada_trae_todo_el_catalogo() -> void:  # 008-AC9
	# Se cuenta contra `Catalogo.todos()` y no contra un número escrito acá: agregar un producto
	# es una fila en el catálogo, y un producto que no llega al inventario es uno que no se puede
	# reponer ni vender, sin un solo error.
	var inventario := Apertura.inventario_de_la_jornada()
	for producto in Catalogo.todos():
		(
			assert_int(inventario.unidades(producto, Inventario.Ubicacion.DEPOSITO))
			. override_failure_message("`%s` no llegó al depósito de la jornada" % producto.nombre)
			. is_equal(ReglasDelEstante.UNIDADES_INICIALES_EN_DEPOSITO)
		)


func test_la_gondola_arranca_vacia_y_por_eso_reponer_es_una_tarea() -> void:  # 008-AC9
	# Si la góndola arrancara con algo, la primera noche reponer estaría medio hecha y el jugador
	# no tendría por qué caminar hasta el depósito.
	var inventario := Apertura.inventario_de_la_jornada()
	for producto in Catalogo.todos():
		(
			assert_int(inventario.unidades(producto, Inventario.Ubicacion.GONDOLA))
			. override_failure_message("`%s` arrancó con góndola" % producto.nombre)
			. is_equal(0)
		)
	assert_int(inventario.faltantes().size()).is_equal(Catalogo.todos().size())


func test_cada_jornada_recibe_un_inventario_propio() -> void:  # 008-AC9
	# Instancias distintas y no la misma: con una sola compartida, lo repuesto anoche seguiría
	# en la góndola esta noche y reponer se cumpliría sola.
	var una := Apertura.inventario_de_la_jornada()
	var otra := Apertura.inventario_de_la_jornada()
	var yerba := Catalogo.de(Producto.Id.YERBA)
	una.mover(yerba, Inventario.Ubicacion.DEPOSITO, Inventario.Ubicacion.GONDOLA, 1)
	assert_int(una.unidades(yerba, Inventario.Ubicacion.GONDOLA)).is_equal(1)
	assert_int(otra.unidades(yerba, Inventario.Ubicacion.GONDOLA)).is_equal(0)
