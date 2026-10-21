## Cómo se abre una jornada: qué tareas trae, con cuánto tiempo nace y con qué mercadería.
##
## La tabla de particulares decide la lista; el enum conserva las identidades de cada tarea.
extends GdUnitTestSuite


func test_cada_jornada_declara_sus_fijas_y_su_particular() -> void:  # AC-SHF-005
	var introduccion: Array[Tarea.Tipo] = [
		Tarea.Tipo.CAJA, Tarea.Tipo.REGISTRAR, Tarea.Tipo.REPONER
	]
	var fijas: Array[Tarea.Tipo] = [
		Tarea.Tipo.CAJA, Tarea.Tipo.REGISTRAR, Tarea.Tipo.LIMPIAR, Tarea.Tipo.REPONER
	]
	var tabla := {
		1: [Tarea.Tipo.CAJA, Tarea.Tipo.REGISTRAR],
		2: introduccion,
		3: fijas,
		4: fijas + [Tarea.Tipo.ORDENAR_LAS_CAJAS],
		5: fijas + [Tarea.Tipo.SACAR_LA_BASURA],
		6: fijas,
		7: fijas,
		8: fijas,
	}
	for jornada: int in tabla:
		var tipos: Array = []
		for tarea in Apertura.obligatorias(jornada):
			tipos.append(tarea.tipo())
		var esperadas: Array = tabla[jornada]
		assert_array(tipos).override_failure_message("jornada %d" % jornada).contains_exactly(
			esperadas
		)
		assert_int(Apertura.cantidad_de_obligatorias(jornada)).is_equal(esperadas.size())
		assert_bool(Apertura.pide(jornada, Tarea.Tipo.REPONER)).is_equal(jornada != 1)
		assert_bool(Apertura.cajas_apiladas(jornada)).is_equal(jornada == 4)


func test_el_turno_de_la_jornada_nace_con_el_presupuesto_entero() -> void:  # AC-SHF-001
	var turno := Apertura.turno_de_la_jornada(Apertura.obligatorias(1))
	assert_float(turno.tiempo_restante()).is_equal(Reglas.DURACION_DEL_TURNO)


func test_el_turno_de_la_jornada_nace_sin_ninguna_tarea_cumplida() -> void:  # AC-SHF-005
	var turno := Apertura.turno_de_la_jornada(Apertura.obligatorias(1))
	assert_int(turno.tareas_cumplidas()).is_equal(0)
	assert_bool(turno.todas_cumplidas()).is_false()


func test_dos_aperturas_no_comparten_instancias_ni_cumplidas() -> void:  # AC-SHF-005
	for jornada in _jornadas():
		var primera := Apertura.obligatorias(jornada)
		for tarea in primera:
			tarea.completar()
		var segunda := Apertura.obligatorias(jornada)
		for tarea in segunda:
			assert_bool(primera.has(tarea)).is_false()
			assert_bool(tarea.completada()).is_false()


func test_el_turno_cuenta_contra_la_lista_que_recibe_y_no_contra_una_copia() -> void:
	# Es lo que hace posible que el reloj entregue la misma instancia por la que el 008 va a
	# preguntar: completar una copia devolvería `true` sin subir el contador del turno.
	var obligatorias := Apertura.obligatorias(1)
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
		var inventario := Apertura.inventario_de_la_jornada(
			jornada,
			Compradores.de_la_jornada(jornada),
			_casilleros(),
			_casilleros(),
			RandomNumberGenerator.new()
		)
		for producto in Catalogo.de_la_jornada(jornada):
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
		var inventario := Apertura.inventario_con_faltantes(faltantes, casilleros, Catalogo.todos())
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
	var inventario := Apertura.inventario_con_faltantes(faltantes, casilleros, Catalogo.todos())
	var aceptados: Array[Producto] = [burbaloo]
	var estante := Estante.new(inventario, aceptados)
	for unidad in ReglasDelEstante.UNIDADES_POR_CAJA:
		assert_int(estante.colocar(burbaloo)).is_equal(Estante.Rechazo.NINGUNO)
	assert_int(inventario.unidades(burbaloo, Inventario.Ubicacion.GONDOLA)).is_equal(12)
	assert_int(inventario.unidades(burbaloo, Inventario.Ubicacion.DEPOSITO)).is_zero()
	assert_array(inventario.faltantes()).is_empty()
	assert_bool(estante.completada()).is_true()


## Un faltante más grande que su fila es un error de los datos y no se acomoda: la góndola
## arranca vacía, y no en un número negativo que `faltantes()` leería como cualquier otro.
func test_un_faltante_mas_grande_que_su_fila_deja_la_gondola_en_cero() -> void:
	var burbaloo := Catalogo.de(Producto.Id.BURBALOO)
	var faltantes: Dictionary[Producto.Id, int] = {Producto.Id.BURBALOO: 5}
	var casilleros: Dictionary[Producto.Id, int] = {Producto.Id.BURBALOO: 3}
	var inventario := Apertura.inventario_con_faltantes(faltantes, casilleros, Catalogo.todos())
	assert_int(inventario.unidades(burbaloo, Inventario.Ubicacion.GONDOLA)).is_zero()
	assert_int(inventario.unidades(burbaloo, Inventario.Ubicacion.DEPOSITO)).is_equal(
		ReglasDelEstante.UNIDADES_POR_CAJA
	)
	assert_bool(_falta(inventario, burbaloo)).is_true()


## En esta apertura fija no falta nada. Vaciar un casillero vuelve a hacer faltar su producto.
func test_un_casillero_que_se_vacia_vuelve_a_faltar() -> void:  # AC-STK-007
	var malbardo := Catalogo.de(Producto.Id.MALBARDO)
	var inventario := Apertura.inventario_con_faltantes({}, _casilleros(), Catalogo.todos())
	assert_bool(_falta(inventario, malbardo)).is_false()
	inventario.mover(malbardo, Inventario.Ubicacion.GONDOLA, Inventario.Ubicacion.DEPOSITO, 1)
	assert_bool(_falta(inventario, malbardo)).is_true()


func test_cada_jornada_recibe_un_inventario_propio() -> void:
	# Instancias distintas y no la misma: con una sola compartida, lo repuesto anoche seguiría
	# en la góndola esta noche y reponer se cumpliría sola. Es también lo que hace que una
	# partida continuada arranque su noche desde el dato, como una nueva.
	var azar := RandomNumberGenerator.new()
	azar.seed = 17
	var casilleros: Dictionary[Producto.Id, int] = {Producto.Id.ACTRONCITO: 8}
	var una := Apertura.inventario_de_la_jornada(2, [], casilleros, casilleros, azar)
	azar.seed = 17
	var otra := Apertura.inventario_de_la_jornada(2, [], casilleros, casilleros, azar)
	var actroncito := Catalogo.de(Producto.Id.ACTRONCITO)
	var al_abrir := otra.unidades(actroncito, Inventario.Ubicacion.GONDOLA)
	una.mover(actroncito, Inventario.Ubicacion.DEPOSITO, Inventario.Ubicacion.GONDOLA, 1)
	assert_int(una.unidades(actroncito, Inventario.Ubicacion.GONDOLA)).is_equal(al_abrir + 1)
	assert_int(otra.unidades(actroncito, Inventario.Ubicacion.GONDOLA)).is_equal(al_abrir)


func test_la_primera_jornada_abre_sin_faltantes_con_cualquier_semilla() -> void:  # AC-STK-094
	for semilla in range(20):
		var azar := RandomNumberGenerator.new()
		azar.seed = semilla
		var inventario := Apertura.inventario_de_la_jornada(
			1, Compradores.de_la_jornada(1), _casilleros(), _casilleros(), azar
		)
		assert_array(inventario.faltantes()).is_empty()
		for producto in Catalogo.de_la_jornada(1):
			assert_int(inventario.unidades(producto, Inventario.Ubicacion.DEPOSITO)).is_equal(
				ReglasDelEstante.UNIDADES_POR_CAJA
			)


func test_la_segunda_jornada_sortea_faltantes() -> void:  # AC-STK-094
	var azar := RandomNumberGenerator.new()
	azar.seed = 3
	var inventario := Apertura.inventario_de_la_jornada(
		2, Compradores.de_la_jornada(2), _casilleros(), _casilleros(), azar
	)
	assert_int(inventario.faltantes().size()).is_between(
		ReglasDelEstante.TIPOS_QUE_FALTAN.x, ReglasDelEstante.TIPOS_QUE_FALTAN.y
	)


func test_retomar_la_primera_y_abrir_la_segunda_no_hereda_huecos() -> void:  # AC-STK-094
	var casilleros := _casilleros(3)
	var compradores := Compradores.de_la_jornada(1)
	var azar := RandomNumberGenerator.new()
	azar.seed = 19
	var primera := Apertura.inventario_de_la_jornada(1, compradores, casilleros, casilleros, azar)
	var producto := Catalogo.de(Producto.Id.MAROLINI)
	(
		assert_int(
			primera.mover(producto, Inventario.Ubicacion.GONDOLA, Inventario.Ubicacion.DEPOSITO, 3)
		)
		. is_equal(3)
	)
	assert_int(primera.unidades(producto, Inventario.Ubicacion.GONDOLA)).is_zero()
	var retomada := Apertura.inventario_de_la_jornada(1, compradores, casilleros, casilleros, azar)
	assert_array(retomada.faltantes()).is_empty()
	assert_int(retomada.unidades(producto, Inventario.Ubicacion.GONDOLA)).is_equal(3)
	assert_bool(Apertura.pide(1, Tarea.Tipo.REPONER)).is_false()
	var siguientes := Compradores.de_la_jornada(2)
	azar.seed = 19
	var segunda := Apertura.inventario_de_la_jornada(2, siguientes, casilleros, casilleros, azar)
	azar.seed = 19
	var control := Apertura.inventario_de_la_jornada(2, siguientes, casilleros, casilleros, azar)
	assert_array(segunda.faltantes()).is_not_empty()
	for otro in Catalogo.de_la_jornada(2):
		assert_int(segunda.unidades(otro, Inventario.Ubicacion.GONDOLA)).is_equal(
			control.unidades(otro, Inventario.Ubicacion.GONDOLA)
		)
		assert_int(segunda.unidades(otro, Inventario.Ubicacion.DEPOSITO)).is_equal(
			ReglasDelEstante.UNIDADES_POR_CAJA
		)
	assert_int(primera.unidades(producto, Inventario.Ubicacion.GONDOLA)).is_zero()
	assert_bool(Apertura.pide(2, Tarea.Tipo.REPONER)).is_true()
