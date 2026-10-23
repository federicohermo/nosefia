extends GdUnitTestSuite

const TERCERA := ReglasDeLaPartida.PRIMERA_JORNADA + 2
const CUARTA := ReglasDeLaPartida.PRIMERA_JORNADA + 3
const QUINTA := ReglasDeLaPartida.PRIMERA_JORNADA + 4
const PERSONAJE := DialogosDeCompradores.Personaje
const SEMILLAS := 40

## `jornada → [[nombre, personaje, llega, se va]]`, cada hora como `Vector2i(hora, minuto)`.
const AGENDAS := {
	TERCERA:
	[
		["Cami", PERSONAJE.CAMI, Vector2i(20, 3), Vector2i(22, 33)],
		["Tin", PERSONAJE.TIN, Vector2i(1, 30), Vector2i(4, 0)],
	],
	CUARTA:
	[
		["Tia", PERSONAJE.TIA, Vector2i(22, 0), Vector2i(1, 0)],
		["Fede", PERSONAJE.FEDE, Vector2i(4, 0), Vector2i(7, 0)],
	],
	QUINTA:
	[
		["Cami", PERSONAJE.CAMI, Vector2i(20, 30), Vector2i(23, 30)],
		["Mía", PERSONAJE.MIA, Vector2i(5, 0), Vector2i(8, 0)],
	],
}


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


func test_cada_jornada_trae_sus_dos_compradores_con_figura_y_horario() -> void:  # AC-CTR-069
	for jornada: int in AGENDAS:
		var compradores := Compradores.de_la_jornada(jornada, 1)
		assert_array(compradores).has_size(2)
		for indice in compradores.size():
			var esperado: Array = AGENDAS[jornada][indice]
			assert_str(compradores[indice].nombre()).is_equal(esperado[0])
			assert_int(compradores[indice].personaje).is_equal(esperado[1])
			assert_bool(compradores[indice].tiene_horario()).is_true()
			assert_that(compradores[indice].horario).is_equal(
				Vector2(_segundos(esperado[2]), _segundos(esperado[3]))
			)


func test_el_padron_no_activa_en_las_jornadas_3_a_5() -> void:  # AC-CTR-070
	var del_padron: Array[String] = []
	for comprador in Compradores.padron():
		del_padron.append(comprador.nombre())
	for jornada: int in AGENDAS:
		for comprador in Compradores.de_la_jornada(jornada, 1):
			assert_array(del_padron).not_contains([comprador.nombre()])


func test_las_fronteras_de_cada_horario_cruzan_una_sola_vez() -> void:  # AC-CTR-069
	for jornada: int in AGENDAS:
		var compradores := Compradores.de_la_jornada(jornada, 1)
		var agenda := AgendaDeCompradores.new(compradores)
		for comprador in compradores:
			var ventana := comprador.horario
			assert_int(agenda.avanzar(ventana.x - 1.0).size()).is_zero()
			var llegada := agenda.avanzar(ventana.x)
			assert_int(llegada.size()).is_equal(1)
			assert_int(llegada[0].tipo).is_equal(AgendaDeCompradores.Tipo.LLEGO)
			assert_object(llegada[0].comprador).is_same(comprador)
			assert_int(agenda.avanzar(ventana.x).size()).is_zero()
			assert_int(agenda.avanzar(ventana.y - 1.0).size()).is_zero()
			var salida := agenda.avanzar(ventana.y)
			assert_int(salida.size()).is_equal(1)
			assert_int(salida[0].tipo).is_equal(AgendaDeCompradores.Tipo.VENCIO)
			assert_int(agenda.avanzar(ventana.y).size()).is_zero()


func test_saltar_al_cierre_entrega_los_cruces_en_orden() -> void:  # AC-CTR-069
	for jornada: int in AGENDAS:
		var compradores := Compradores.de_la_jornada(jornada, 1)
		var eventos := AgendaDeCompradores.new(compradores).avanzar(Reglas.DURACION_DEL_TURNO)
		assert_int(eventos.size()).is_equal(4)
		for indice in 4:
			assert_object(eventos[indice].comprador).is_same(compradores[indice / 2])
			assert_int(eventos[indice].tipo).is_equal(
				[AgendaDeCompradores.Tipo.LLEGO, AgendaDeCompradores.Tipo.VENCIO][indice % 2]
			)


func test_el_limite_de_mia_es_el_cierre_del_turno() -> void:  # AC-CTR-069
	var mia := Compradores.de_la_jornada(QUINTA, 1)[1]
	assert_float(mia.horario.y).is_equal(Reglas.DURACION_DEL_TURNO)


func test_una_compra_completa_no_vence() -> void:  # AC-CTR-069
	for jornada: int in AGENDAS:
		var compradores := Compradores.de_la_jornada(jornada, 1)
		var agenda := AgendaDeCompradores.new(compradores)
		agenda.avanzar(compradores[0].horario.x)
		assert_int(agenda.avanzar(compradores[0].horario.y, [compradores[0]]).size()).is_zero()


func test_cada_pedido_son_tres_tipos_distintos_de_lo_que_se_vende() -> void:  # AC-CTR-071
	for jornada: int in AGENDAS:
		var vendibles: Array[Producto.Id] = []
		for producto in Catalogo.de_la_jornada(jornada):
			vendibles.append(producto.id)
		for semilla in range(1, SEMILLAS + 1):
			for comprador in Compradores.de_la_jornada(jornada, semilla):
				var pedido := comprador.pedido()
				var ids: Array[Producto.Id] = []
				for producto in pedido.productos():
					ids.append(producto.id)
					assert_int(pedido.unidades_de(producto)).is_equal(1)
					assert_array(vendibles).contains([producto.id])
				assert_array(ids).has_size(3)


func test_la_tercera_jornada_pide_solo_de_los_productos_de_prueba() -> void:  # AC-CTR-071
	for semilla in range(1, SEMILLAS + 1):
		for comprador in Compradores.de_la_jornada(TERCERA, semilla):
			for producto in comprador.pedido().productos():
				assert_array(Catalogo.PRODUCTOS_DE_PRUEBA).contains([producto.id])


func test_la_misma_semilla_repite_los_productos_con_estados_nuevos() -> void:  # AC-CTR-072
	for jornada: int in AGENDAS:
		var una := Compradores.de_la_jornada(jornada, 7)
		var otra := Compradores.de_la_jornada(jornada, 7)
		assert_array(_firma(una)).is_equal(_firma(otra))
		for indice in una.size():
			assert_object(una[indice]).is_not_same(otra[indice])
			assert_object(una[indice].pedido()).is_not_same(otra[indice].pedido())


func test_otra_semilla_cambia_los_pedidos() -> void:  # AC-CTR-072
	for jornada: int in AGENDAS:
		var firmas: Dictionary = {}
		for semilla in range(1, SEMILLAS + 1):
			firmas[str(_firma(Compradores.de_la_jornada(jornada, semilla)))] = true
		assert_int(firmas.size()).is_greater(1)


func test_cami_no_hereda_el_pedido_entre_jornadas() -> void:  # AC-CTR-072
	var en_tercera := Compradores.de_la_jornada(TERCERA, 7)[0]
	var en_quinta := Compradores.de_la_jornada(QUINTA, 7)[0]
	assert_str(en_quinta.nombre()).is_equal(en_tercera.nombre())
	assert_object(en_quinta).is_not_same(en_tercera)
	assert_object(en_quinta.pedido()).is_not_same(en_tercera.pedido())


func test_las_demas_jornadas_no_dependen_de_la_semilla() -> void:  # AC-CTR-001
	var jornada := ReglasDeLaPartida.JORNADAS_DE_LA_PARTIDA
	assert_array(_firma(Compradores.de_la_jornada(jornada, 1))).is_equal(
		_firma(Compradores.de_la_jornada(jornada, 2))
	)
