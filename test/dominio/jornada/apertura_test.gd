## Cómo se abre una jornada: qué tareas trae, con cuánto tiempo nace y con qué mercadería.
##
## Ningún caso escribe a mano cuántas obligatorias hay. Se comparan contra `Tarea.Tipo`, que es
## la única fuente: el 001 ya declaró las cinco, y una sexta se agrega a ese `enum` sin que este
## archivo se toque.
extends GdUnitTestSuite


func test_hay_una_obligatoria_por_cada_tipo_de_tarea() -> void:  # AC-SHF-005
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


func test_el_turno_de_la_jornada_nace_con_el_presupuesto_entero() -> void:  # AC-SHF-001
	var turno := Apertura.turno_de_la_jornada(Apertura.obligatorias())
	assert_float(turno.tiempo_restante()).is_equal(Reglas.DURACION_DEL_TURNO)


func test_el_turno_de_la_jornada_nace_sin_ninguna_tarea_cumplida() -> void:  # AC-SHF-005
	var turno := Apertura.turno_de_la_jornada(Apertura.obligatorias())
	assert_int(turno.tareas_cumplidas()).is_equal(0)
	assert_bool(turno.todas_cumplidas()).is_false()


func test_la_segunda_jornada_trae_una_por_tipo_y_ninguna_cumplida() -> void:  # AC-SHF-005
	# Se cumple una de la primera: con instancias compartidas, la segunda la traería cumplida.
	var primera := Apertura.obligatorias()
	assert_bool(Apertura.turno_de_la_jornada(primera).completar(primera[0])).is_true()
	var segunda := Apertura.obligatorias()
	var tipos: Array[int] = []
	for tarea: Tarea in segunda:
		assert_bool(tarea.completada()).is_false()
		tipos.append(tarea.tipo())
	assert_int(tipos.size()).is_equal(Tarea.Tipo.size())
	for tipo: int in Tarea.Tipo.values():
		assert_int(tipos.count(tipo)).is_equal(1)


func test_el_turno_cuenta_contra_la_lista_que_recibe_y_no_contra_una_copia() -> void:
	# Es lo que hace posible que el reloj entregue la misma instancia por la que el 008 va a
	# preguntar: completar una copia devolvería `true` sin subir el contador del turno.
	var obligatorias := Apertura.obligatorias()
	var turno := Apertura.turno_de_la_jornada(obligatorias)
	assert_bool(turno.completar(obligatorias[0])).is_true()
	assert_int(turno.tareas_cumplidas()).is_equal(1)


## Ocho casilleros para cada producto: los faltantes de cualquier jornada entran en su fila, y
## lo que estos casos miden no depende de cómo quedó repartido el local. Cuántos tiene cada fila
## de verdad lo mide el modelo, y lo cruzan las suites de `escenas/`.
func _casilleros(cuantos: int = ReglasDelEstante.UNIDADES_POR_CAJA) -> Dictionary[Producto.Id, int]:
	var casilleros: Dictionary[Producto.Id, int] = {}
	for producto in Catalogo.todos():
		casilleros[producto.id] = cuantos
	return casilleros


## Las jornadas de la partida, de la primera a la última.
func _jornadas() -> Array[int]:
	var jornadas: Array[int] = []
	for numero in ReglasDeLaPartida.JORNADAS_DE_LA_PARTIDA:
		jornadas.append(ReglasDeLaPartida.PRIMERA_JORNADA + numero)
	return jornadas


## Si el inventario lista ese producto entre los faltantes. Compara por `id`: `faltantes()`
## devuelve las instancias que recibió el inventario, y no la que se le pregunta.
func _falta(inventario: Inventario, producto: Producto) -> bool:
	return inventario.faltantes().any(func(otro: Producto) -> bool: return otro.id == producto.id)


func test_cada_caja_del_deposito_arranca_con_ocho_en_todas_las_jornadas() -> void:  # AC-STK-004
	# Se cuenta contra `Catalogo.todos()` y no contra un número escrito acá: agregar un producto
	# es una fila en el catálogo, y un producto que no llega al inventario es uno que no se puede
	# reponer ni vender, sin un solo error.
	for jornada in _jornadas():
		var inventario := Apertura.inventario_de_la_jornada(jornada, _casilleros())
		for producto in Catalogo.todos():
			(
				assert_int(inventario.unidades(producto, Inventario.Ubicacion.DEPOSITO))
				. override_failure_message(
					"jornada %d: la caja de `%s` no arrancó llena" % [jornada, producto.nombre]
				)
				. is_equal(ReglasDelEstante.UNIDADES_POR_CAJA)
			)


## Cero, uno del medio y una caja entera: la góndola arranca con su fila menos lo que falta, y el
## depósito lleno en los tres. Sin faltantes el producto arranca completo y no falta.
##
## Los 8 casilleros son los del criterio y no los de una fila del modelo: el dominio no sabe
## cuántos lugares tiene cada fila, y el producto es uno cualquiera de un estante de lado.
func test_la_gondola_arranca_con_su_fila_menos_lo_que_falta() -> void:  # AC-STK-004
	var burbaloo := Catalogo.de(Producto.Id.BURBALOO)
	var casilleros: Dictionary[Producto.Id, int] = {Producto.Id.BURBALOO: 8}
	for fila: Array in [[0, 8], [5, 3], [8, 0]]:
		var faltantes: Dictionary[Producto.Id, int] = {}
		if fila[0] > 0:
			faltantes[Producto.Id.BURBALOO] = fila[0]
		var inventario := Apertura.inventario_con_faltantes(faltantes, casilleros)
		var mensaje := "faltan %d" % fila[0]
		(
			assert_int(inventario.unidades(burbaloo, Inventario.Ubicacion.GONDOLA))
			. override_failure_message(mensaje)
			. is_equal(fila[1])
		)
		(
			assert_int(inventario.unidades(burbaloo, Inventario.Ubicacion.DEPOSITO))
			. override_failure_message(mensaje)
			. is_equal(ReglasDelEstante.UNIDADES_POR_CAJA)
		)
		assert_bool(_falta(inventario, burbaloo)).override_failure_message(mensaje).is_equal(
			fila[0] > 0
		)


## El faltante más grande que la regla admite se repone con la caja entera, y no con una unidad
## de menos: por eso el tope es la caja y no algo más chico.
##
## Los 12 casilleros son los del criterio y no los de una fila del modelo: el dominio no sabe
## cuántos lugares tiene cada fila, y el producto es uno cualquiera de un estante de lado.
func test_un_faltante_de_una_caja_entera_se_repone_con_esa_caja() -> void:  # AC-STK-032
	var burbaloo := Catalogo.de(Producto.Id.BURBALOO)
	var faltantes: Dictionary[Producto.Id, int] = {
		Producto.Id.BURBALOO: ReglasDelEstante.UNIDADES_POR_CAJA
	}
	var casilleros: Dictionary[Producto.Id, int] = {Producto.Id.BURBALOO: 12}
	var inventario := Apertura.inventario_con_faltantes(faltantes, casilleros)
	var aceptados: Array[Producto] = [burbaloo]
	var estante := Estante.new(inventario, aceptados)
	for unidad in ReglasDelEstante.UNIDADES_POR_CAJA:
		assert_int(estante.colocar(burbaloo)).is_equal(Estante.Rechazo.NINGUNO)
	assert_int(inventario.unidades(burbaloo, Inventario.Ubicacion.GONDOLA)).is_equal(12)
	assert_int(inventario.unidades(burbaloo, Inventario.Ubicacion.DEPOSITO)).is_zero()
	assert_array(inventario.faltantes()).is_empty()
	assert_bool(estante.completada()).is_true()


## La ficha: en la jornada 1 faltan 5 Actroncito y 6 Coracola, y nada más.
func test_la_primera_jornada_hace_faltar_5_actroncito_y_6_coracola() -> void:  # AC-STK-034
	var faltantes := Apertura.faltantes_de_la_jornada(ReglasDeLaPartida.PRIMERA_JORNADA)
	assert_dict(faltantes).is_equal({Producto.Id.ACTRONCITO: 5, Producto.Id.CORACOLA: 6})
	var inventario := Apertura.inventario_de_la_jornada(
		ReglasDeLaPartida.PRIMERA_JORNADA, _casilleros()
	)
	var nombres: Array[String] = []
	for producto in inventario.faltantes():
		nombres.append(producto.nombre)
	assert_array(nombres).contains_exactly(["Actroncito", "Coracola"])
	for producto in Catalogo.todos():
		(
			assert_int(inventario.unidades(producto, Inventario.Ubicacion.GONDOLA))
			. override_failure_message("`%s` no arrancó con su fila" % producto.nombre)
			. is_equal(ReglasDelEstante.UNIDADES_POR_CAJA - faltantes.get(producto.id, 0))
		)


## La ficha dice «A definir» de la 2 a la 5: mientras tanto arrancan como la 1 (OQ-STK-005). El
## día que la ficha las decida, este caso se pone en rojo y el spec cambia con él.
func test_de_la_segunda_a_la_quinta_faltan_los_mismos_que_en_la_primera() -> void:  # AC-STK-034
	var primera := Apertura.faltantes_de_la_jornada(ReglasDeLaPartida.PRIMERA_JORNADA)
	for jornada in _jornadas():
		(
			assert_dict(Apertura.faltantes_de_la_jornada(jornada))
			. override_failure_message("jornada %d" % jornada)
			. is_equal(primera)
		)


## La cuenta es contra la fila y no contra el dato de la jornada: Malbardo arranca completo en la
## jornada 1, y en cuanto una unidad sale de su góndola vuelve a faltar.
func test_un_casillero_que_se_vacia_vuelve_a_faltar() -> void:  # AC-STK-007
	var malbardo := Catalogo.de(Producto.Id.MALBARDO)
	var inventario := Apertura.inventario_de_la_jornada(
		ReglasDeLaPartida.PRIMERA_JORNADA, _casilleros()
	)
	assert_bool(_falta(inventario, malbardo)).is_false()
	inventario.mover(malbardo, Inventario.Ubicacion.GONDOLA, Inventario.Ubicacion.DEPOSITO, 1)
	assert_bool(_falta(inventario, malbardo)).is_true()


## La venta y la reposición salen de la misma caja: los compradores de cada noche se cobran
## apenas abre, y todavía se puede reponer todo lo que falta. Es la cuenta que la ficha pide
## cuidar en cada jornada —«vender 2 y reponer 7 Malbardo sería imposible»—.
func test_los_pedidos_de_cada_jornada_entran_sin_quitarle_a_la_reposicion() -> void:  # AC-STK-035
	for jornada in _jornadas():
		var inventario := Apertura.inventario_de_la_jornada(jornada, _casilleros())
		for comprador in Compradores.de_la_jornada():
			(
				assert_bool(inventario.cobrar(comprador.pedido()))
				. override_failure_message(
					"jornada %d: el pedido de %s no entra" % [jornada, comprador.nombre()]
				)
				. is_true()
			)
		var estante := Estante.new(inventario, Catalogo.todos())
		for producto in inventario.faltantes():
			while estante.unidades_en_gondola(producto) < estante.cupo(producto):
				if estante.colocar(producto) != Estante.Rechazo.NINGUNO:
					break
		(
			assert_bool(estante.completada())
			. override_failure_message("jornada %d: vender dejó sin reponer" % jornada)
			. is_true()
		)


func test_cada_jornada_recibe_un_inventario_propio() -> void:
	# Instancias distintas y no la misma: con una sola compartida, lo repuesto anoche seguiría
	# en la góndola esta noche y reponer se cumpliría sola. Es también lo que hace que una
	# partida continuada arranque su noche desde el dato, como una nueva.
	var una := Apertura.inventario_de_la_jornada(ReglasDeLaPartida.PRIMERA_JORNADA, _casilleros())
	var otra := Apertura.inventario_de_la_jornada(ReglasDeLaPartida.PRIMERA_JORNADA, _casilleros())
	var actroncito := Catalogo.de(Producto.Id.ACTRONCITO)
	var al_abrir := otra.unidades(actroncito, Inventario.Ubicacion.GONDOLA)
	una.mover(actroncito, Inventario.Ubicacion.DEPOSITO, Inventario.Ubicacion.GONDOLA, 1)
	assert_int(una.unidades(actroncito, Inventario.Ubicacion.GONDOLA)).is_equal(al_abrir + 1)
	assert_int(otra.unidades(actroncito, Inventario.Ubicacion.GONDOLA)).is_equal(al_abrir)
