## El presupuesto de la noche: cuánto queda, qué lo consume y cuántas obligatorias se cumplieron.
##
## Ningún turno de acá se arma contra una lista de cinco escrita a mano: los casos que necesitan
## las cinco las sacan recorriendo el enum, y hay uno que se arma con una sola. Eso no es pereza:
## es la prueba de que `Turno` no sabe que son cinco, y que la sexta va a ser un dato y no un
## cambio de código.
extends GdUnitTestSuite


func _turno_sin_obligatorias(presupuesto: float) -> Turno:
	var ninguna: Array[Tarea] = []
	return Turno.new(presupuesto, ninguna)


func test_un_turno_recien_abierto_tiene_todo_su_presupuesto() -> void:
	assert_float(_turno_sin_obligatorias(28800.0).tiempo_restante()).is_equal(28800.0)


func test_consumir_descuenta_del_restante() -> void:
	var turno := _turno_sin_obligatorias(3600.0)
	turno.consumir(600.0)
	assert_float(turno.tiempo_restante()).is_equal(3000.0)


func test_consumir_mas_de_lo_que_queda_deja_el_restante_en_cero_y_no_en_negativo() -> void:
	# Un restante negativo se propaga: el HUD mostraría un tiempo imposible y las consecuencias
	# se contarían contra un turno que ya no existe.
	var turno := _turno_sin_obligatorias(100.0)
	turno.consumir(500.0)
	assert_float(turno.tiempo_restante()).is_equal(0.0)


func test_consumir_un_valor_negativo_no_devuelve_tiempo() -> void:
	# El tiempo del turno sólo avanza. Devolverlo es la única forma de romper la tensión que
	# sostiene el juego: con tiempo negativo, investigar dejaría de costar.
	var turno := _turno_sin_obligatorias(100.0)
	turno.consumir(-50.0)
	assert_float(turno.tiempo_restante()).is_equal(100.0)


func test_un_turno_con_tiempo_todavia_no_esta_cerrado() -> void:
	assert_bool(_turno_sin_obligatorias(1.0).cerrado()).is_false()


func test_un_turno_sin_tiempo_esta_cerrado() -> void:
	var turno := _turno_sin_obligatorias(100.0)
	turno.consumir(100.0)
	assert_bool(turno.cerrado()).is_true()


func test_completar_una_tarea_descuenta_su_costo_exacto() -> void:
	var limpiar := Tarea.new(Tarea.Tipo.LIMPIAR)
	var obligatorias: Array[Tarea] = [limpiar]
	var turno := Turno.new(28800.0, obligatorias)
	assert_bool(turno.completar(limpiar)).is_true()
	assert_float(turno.tiempo_restante()).is_equal(28800.0 - Reglas.costo_de(Tarea.Tipo.LIMPIAR))


func test_completar_dos_veces_la_misma_tarea_no_la_cobra_ni_la_cuenta_dos_veces() -> void:
	var caja := Tarea.new(Tarea.Tipo.CAJA)
	var obligatorias: Array[Tarea] = [caja]
	var turno := Turno.new(28800.0, obligatorias)
	turno.completar(caja)
	var restante_tras_la_primera := turno.tiempo_restante()
	assert_bool(turno.completar(caja)).is_false()
	assert_float(turno.tiempo_restante()).is_equal(restante_tras_la_primera)
	assert_int(turno.tareas_cumplidas()).is_equal(1)


func test_una_tarea_que_no_entra_en_el_tiempo_que_queda_no_se_hace_a_medias() -> void:
	# La alternativa —dejar el presupuesto en cero y la tarea sin cumplir— es un estado que el
	# jugador no puede distinguir de haberla hecho.
	var reponer := Tarea.new(Tarea.Tipo.REPONER)
	var obligatorias: Array[Tarea] = [reponer]
	var apenas := Reglas.costo_de(Tarea.Tipo.REPONER) - 1.0
	var turno := Turno.new(apenas, obligatorias)
	assert_bool(turno.completar(reponer)).is_false()
	assert_float(turno.tiempo_restante()).is_equal(apenas)
	assert_bool(reponer.completada()).is_false()


func test_una_tarea_de_afuera_de_las_obligatorias_consume_pero_no_cuenta() -> void:
	# El jefe cuenta las que pidió. Algo que no estaba en la lista se paga igual —el tiempo se
	# fue— pero no acerca al turno completo, que es lo que hace que investigar tenga precio.
	var declarada := Tarea.new(Tarea.Tipo.CAJA)
	var obligatorias: Array[Tarea] = [declarada]
	var turno := Turno.new(Reglas.DURACION_DEL_TURNO, obligatorias)
	var de_afuera := Tarea.new(Tarea.Tipo.REPONER)
	assert_bool(turno.completar(de_afuera)).is_true()
	var esperado := Reglas.DURACION_DEL_TURNO - Reglas.costo_de(Tarea.Tipo.REPONER)
	assert_float(turno.tiempo_restante()).is_equal(esperado)
	assert_int(turno.tareas_cumplidas()).is_equal(0)
	assert_bool(turno.todas_cumplidas()).is_false()


func test_un_turno_sin_obligatorias_esta_completo_por_vacuidad() -> void:
	# No es un caso del juego: es el borde que hace que `todas_cumplidas()` no dependa de que la
	# lista tenga un tamaño mínimo. Con cero declaradas no quedó nada sin hacer.
	var turno := _turno_sin_obligatorias(Reglas.DURACION_DEL_TURNO)
	assert_int(turno.tareas_cumplidas()).is_equal(0)
	assert_bool(turno.todas_cumplidas()).is_true()


func _las_cinco_obligatorias() -> Array[Tarea]:
	var obligatorias: Array[Tarea] = []
	for tipo: Tarea.Tipo in Tarea.Tipo.values():
		obligatorias.append(Tarea.new(tipo))
	return obligatorias


func test_con_tres_de_cinco_cumplidas_el_turno_no_esta_completo() -> void:
	var obligatorias := _las_cinco_obligatorias()
	var turno := Turno.new(Reglas.DURACION_DEL_TURNO, obligatorias)
	for i in 3:
		turno.completar(obligatorias[i])
	assert_int(turno.tareas_cumplidas()).is_equal(3)
	assert_bool(turno.todas_cumplidas()).is_false()


func test_con_las_cinco_cumplidas_el_turno_esta_completo() -> void:
	var obligatorias := _las_cinco_obligatorias()
	var turno := Turno.new(Reglas.DURACION_DEL_TURNO, obligatorias)
	for tarea in obligatorias:
		turno.completar(tarea)
	assert_bool(turno.todas_cumplidas()).is_true()


func test_un_turno_de_una_sola_obligatoria_se_completa_con_esa_una() -> void:
	# La prueba de que el `5` no está escrito en el dominio: con una sola declarada, hacerla
	# alcanza. Una sexta tarea va a ser un dato y no un cambio de código.
	var basura := Tarea.new(Tarea.Tipo.SACAR_LA_BASURA)
	var obligatorias: Array[Tarea] = [basura]
	var turno := Turno.new(Reglas.DURACION_DEL_TURNO, obligatorias)
	turno.completar(basura)
	assert_bool(turno.todas_cumplidas()).is_true()
