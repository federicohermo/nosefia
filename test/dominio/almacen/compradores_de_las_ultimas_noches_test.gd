extends GdUnitTestSuite

const CORTE := ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA + 3
const ULTIMA := ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA + 4
const NOCHES: Array[int] = [CORTE, ULTIMA]
const PERSONAJE := DialogosDeCompradores.Personaje
const SEMILLAS := 60
const CASILLEROS := 8

const AGENDAS := {
	CORTE:
	[
		["Tin", PERSONAJE.TIN, Vector2i(0, 0), Vector2i(2, 30)],
		["Tia", PERSONAJE.TIA, Vector2i(2, 31), Vector2i(5, 1)],
	],
	ULTIMA:
	[
		["Fede", PERSONAJE.FEDE, Vector2i(23, 0), Vector2i(1, 30)],
		["Mía", PERSONAJE.MIA, Vector2i(5, 30), Vector2i(8, 0)],
	],
}


class Noche:
	extends RefCounted
	var compradores: Array[Comprador]
	var inventario: Inventario
	var estante: Estante
	var tarea: TareaDeAtender


func _segundos(hora: Vector2i) -> float:
	var horas := posmod(hora.x - Reglas.HORA_DE_APERTURA, Marcador.HORAS_POR_DIA)
	return float((horas * Marcador.MINUTOS_POR_HORA + hora.y) * Marcador.SEGUNDOS_POR_MINUTO)


func _firma(compradores: Array[Comprador]) -> Array:
	var firma: Array = []
	for comprador in compradores:
		var ids: Array = []
		for producto in comprador.pedido().productos():
			ids.append(producto.id)
		firma.append(ids)
	return firma


func _ids_de(comprador: Comprador) -> Array[Producto.Id]:
	var ids: Array[Producto.Id] = []
	for producto in comprador.pedido().productos():
		ids.append(producto.id)
	return ids


func _noche(jornada: int) -> Noche:
	var noche := Noche.new()
	var productos := Catalogo.de_la_jornada(jornada)
	var casilleros: Dictionary[Producto.Id, int] = {}
	for producto in productos:
		casilleros[producto.id] = CASILLEROS
	noche.compradores = Compradores.de_la_jornada(jornada, 5)
	noche.inventario = Apertura.inventario_con_faltantes({}, casilleros, productos)
	noche.estante = Estante.new(noche.inventario, productos)
	noche.tarea = TareaDeAtender.new(noche.compradores, noche.inventario)
	return noche


func _llegar(noche: Noche, indice: int) -> Atencion:
	noche.tarea.avanzar(noche.compradores[indice].horario.x)
	var atencion := noche.tarea.atencion()
	atencion.interactuar(null)
	while not atencion.puede_abandonar():
		atencion.interactuar(null)
	return atencion


func _vender(noche: Noche, indice: int) -> void:
	var atencion := _llegar(noche, indice)
	var pedido := atencion.comprador().pedido()
	for producto in pedido.productos():
		atencion.interactuar(noche.estante.retirar(producto))
	assert_int(atencion.interactuar(Ticket.new(pedido.productos()))).is_equal(
		RecepcionDeCompra.Resultado.COMPLETA
	)
	assert_bool(atencion.vendida()).is_true()


func test_las_agendas_caen_en_el_corte_y_en_la_ultima() -> void:  # AC-CTR-126, AC-CTR-127
	assert_int(CORTE).is_equal(AnomaliasDeLaJornada.JORNADA_DEL_CORTE)
	assert_int(ULTIMA).is_equal(AnomaliasDeLaJornada.JORNADA_DE_LAS_CAJAS)


func test_cada_noche_trae_sus_dos_con_figura_y_horario() -> void:  # AC-CTR-126, AC-CTR-127
	for jornada: int in NOCHES:
		var compradores := Compradores.de_la_jornada(jornada, 1)
		assert_array(compradores).has_size(2)
		for indice in compradores.size():
			var esperado: Array = AGENDAS[jornada][indice]
			assert_str(compradores[indice].nombre()).is_equal(esperado[0])
			assert_int(compradores[indice].personaje).is_equal(esperado[1])
			assert_that(compradores[indice].horario).is_equal(
				Vector2(_segundos(esperado[2]), _segundos(esperado[3]))
			)
			assert_object(compradores[indice].llega_tras).is_null()


func test_mia_se_va_al_cerrar_el_turno() -> void:  # AC-CTR-127
	var mia := Compradores.de_la_jornada(ULTIMA, 1)[1]
	assert_float(mia.horario.y).is_equal(Reglas.DURACION_DEL_TURNO)


func test_las_fronteras_de_cada_horario_cruzan_una_sola_vez() -> void:  # AC-CTR-126, AC-CTR-127
	for jornada: int in NOCHES:
		var compradores := Compradores.de_la_jornada(jornada, 1)
		for indice in compradores.size():
			var comprador := compradores[indice]
			var agenda := AgendaDeCompradores.new(compradores)
			if indice == 1:
				agenda.avanzar(compradores[0].horario.y)
			var ventana := comprador.horario
			assert_array(agenda.avanzar(ventana.x - 1.0)).is_empty()
			var llegada := agenda.avanzar(ventana.x)
			assert_array(llegada).has_size(1)
			assert_int(llegada[0].tipo).is_equal(AgendaDeCompradores.Tipo.LLEGO)
			assert_object(llegada[0].comprador).is_same(comprador)
			assert_array(agenda.avanzar(ventana.x)).is_empty()
			assert_array(agenda.avanzar(ventana.y - 1.0)).is_empty()
			var salida := agenda.avanzar(ventana.y)
			assert_array(salida).has_size(1)
			assert_int(salida[0].tipo).is_equal(AgendaDeCompradores.Tipo.VENCIO)
			assert_array(agenda.avanzar(ventana.y)).is_empty()


func test_tia_llega_a_su_hora_aunque_tin_se_haya_ido_antes() -> void:  # AC-CTR-126
	var compradores := Compradores.de_la_jornada(CORTE, 1)
	var tin := compradores[0]
	var tia := compradores[1]
	var agenda := AgendaDeCompradores.new(compradores)
	agenda.avanzar(tin.horario.x)
	assert_array(agenda.avanzar(tin.horario.x + 600.0, [tin])).is_empty()
	assert_array(agenda.avanzar(tia.horario.x - 1.0)).is_empty()
	var llegada := agenda.avanzar(tia.horario.x)
	assert_array(llegada).has_size(1)
	assert_object(llegada[0].comprador).is_same(tia)


func test_saltar_al_cierre_entrega_los_cruces_en_orden() -> void:  # AC-CTR-126, AC-CTR-127
	for jornada: int in NOCHES:
		var compradores := Compradores.de_la_jornada(jornada, 1)
		var eventos := AgendaDeCompradores.new(compradores).avanzar(Reglas.DURACION_DEL_TURNO)
		assert_array(eventos).has_size(4)
		for indice in 4:
			assert_object(eventos[indice].comprador).is_same(compradores[indice / 2])
			assert_int(eventos[indice].tipo).is_equal(
				[AgendaDeCompradores.Tipo.LLEGO, AgendaDeCompradores.Tipo.VENCIO][indice % 2]
			)


func test_ninguna_noche_activa_el_padron_ni_los_guiones_de_las_primeras() -> void:  # AC-CTR-128
	var del_padron: Array[String] = []
	for comprador in Compradores.padron():
		del_padron.append(comprador.nombre())
	for jornada: int in NOCHES:
		for comprador in Compradores.de_la_jornada(jornada, 1):
			assert_array(del_padron).not_contains([comprador.nombre()])
			assert_object(comprador.dialogos).is_null()


func test_cada_pedido_es_de_dos_o_tres_tipos_de_su_grupo() -> void:  # AC-CTR-129
	var por_cantidad := {2: 0, 3: 0}
	for jornada: int in NOCHES:
		for semilla in range(1, SEMILLAS + 1):
			for comprador in Compradores.de_la_jornada(jornada, semilla):
				var ids := _ids_de(comprador)
				var del_grupo: Array = Compradores.GRUPOS[comprador.personaje].duplicate()
				if jornada == ULTIMA and comprador.personaje == PERSONAJE.FEDE:
					del_grupo.append(Producto.Id.DUREXTRA)
				for id in ids:
					assert_array(del_grupo).contains([id])
				var pedido := comprador.pedido()
				for producto in pedido.productos():
					assert_int(pedido.unidades_de(producto)).is_equal(1)
				assert_int(ids.size()).is_between(2, 3)
				por_cantidad[ids.size()] += 1
	var total: int = por_cantidad[2] + por_cantidad[3]
	assert_int(por_cantidad[2]).is_greater(total / 4)
	assert_int(por_cantidad[3]).is_greater(total / 4)


func test_fede_pide_siempre_duronga_y_durextra_en_la_ultima_noche() -> void:  # AC-CTR-130
	var terceros: Dictionary = {}
	var cantidades: Dictionary = {}
	for semilla in range(1, SEMILLAS + 1):
		var ids := _ids_de(Compradores.de_la_jornada(ULTIMA, semilla)[0])
		assert_array(ids).contains([Producto.Id.DURONGA, Producto.Id.DUREXTRA])
		cantidades[ids.size()] = true
		if ids.size() == 3:
			var resto: Array[Producto.Id] = ids.duplicate()
			resto.erase(Producto.Id.DURONGA)
			resto.erase(Producto.Id.DUREXTRA)
			var tercero := resto[0]
			assert_array(Compradores.GRUPOS[PERSONAJE.FEDE]).contains([tercero])
			terceros[tercero] = true
	assert_array(cantidades.keys()).contains_exactly_in_any_order([2, 3])
	var candidatos: Array = Compradores.GRUPOS[PERSONAJE.FEDE].filter(
		func(id: Producto.Id) -> bool: return id != Producto.Id.DURONGA
	)
	assert_array(terceros.keys()).contains_exactly_in_any_order(candidatos)


func test_nadie_mas_pide_durextra() -> void:  # AC-CTR-130
	var noches_al_azar: Array[int] = [
		ReglasDeLaPartida.PRIMERA_JORNADA + 2,
		ReglasDeLaPartida.PRIMERA_JORNADA + 3,
		ReglasDeLaPartida.PRIMERA_JORNADA + 4,
		CORTE,
		ULTIMA,
	]
	for jornada: int in noches_al_azar:
		for semilla in range(1, SEMILLAS + 1):
			for comprador in Compradores.de_la_jornada(jornada, semilla):
				if jornada == ULTIMA and comprador.personaje == PERSONAJE.FEDE:
					continue
				assert_array(_ids_de(comprador)).not_contains([Producto.Id.DUREXTRA])


func test_la_misma_semilla_repite_los_pedidos_con_estados_nuevos() -> void:  # AC-CTR-131
	for jornada: int in NOCHES:
		var una := Compradores.de_la_jornada(jornada, 7)
		var otra := Compradores.de_la_jornada(jornada, 7)
		assert_array(_firma(una)).is_equal(_firma(otra))
		for indice in una.size():
			assert_object(una[indice]).is_not_same(otra[indice])
			assert_object(una[indice].pedido()).is_not_same(otra[indice].pedido())
		var firmas: Dictionary = {}
		for semilla in range(1, SEMILLAS + 1):
			firmas[str(_firma(Compradores.de_la_jornada(jornada, semilla)))] = true
		assert_int(firmas.size()).is_greater(1)


func test_la_venta_se_registra_una_sola_vez_en_cada_noche() -> void:  # AC-CTR-132
	for jornada: int in NOCHES:
		var noche := _noche(jornada)
		_vender(noche, 0)
		var primero := noche.compradores[0].pedido().productos()[0]
		assert_int(noche.tarea.vendidas_de(primero)).is_equal(1)


func test_atencion_se_cumple_solo_con_las_dos_compras() -> void:  # AC-CTR-132
	for jornada: int in NOCHES:
		var ambas := _noche(jornada)
		_vender(ambas, 0)
		assert_bool(ambas.tarea.completada()).is_false()
		_vender(ambas, 1)
		assert_bool(ambas.tarea.completada()).is_true()
		var perdida_la_primera := _noche(jornada)
		_llegar(perdida_la_primera, 0)
		perdida_la_primera.tarea.avanzar(perdida_la_primera.compradores[0].horario.y)
		_vender(perdida_la_primera, 1)
		assert_bool(perdida_la_primera.tarea.completada()).is_false()


func test_una_compra_vencida_deja_las_unidades_afuera_sin_venta() -> void:  # AC-CTR-132
	for jornada: int in NOCHES:
		var noche := _noche(jornada)
		var atencion := _llegar(noche, 0)
		var productos := atencion.comprador().pedido().productos()
		var unidad := noche.estante.retirar(productos[0])
		atencion.interactuar(unidad)
		noche.tarea.avanzar(noche.compradores[0].horario.y)
		noche.tarea.avanzar(noche.compradores[0].horario.y)
		assert_bool(noche.inventario.esta_afuera(unidad)).is_true()
		assert_bool(atencion.vendida()).is_false()
		assert_int(noche.tarea.vendidas_de(productos[0])).is_zero()


func test_un_pedido_sin_unidades_vendibles_sigue_siendo_el_pedido() -> void:  # AC-CTR-132
	var productos := Catalogo.de_la_jornada(ULTIMA)
	var sin_casilleros: Dictionary[Producto.Id, int] = {}
	for producto in productos:
		sin_casilleros[producto.id] = 0
	var compradores := Compradores.de_la_jornada(ULTIMA, 5)
	var inventario := Apertura.inventario_con_faltantes({}, sin_casilleros, productos)
	var tarea := TareaDeAtender.new(compradores, inventario)
	tarea.avanzar(compradores[0].horario.x)
	assert_array(_ids_de(tarea.atencion().comprador())).contains(
		[Producto.Id.DURONGA, Producto.Id.DUREXTRA]
	)
