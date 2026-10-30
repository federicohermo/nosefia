extends GdUnitTestSuite

const TERCERA := ReglasDeLaPartida.PRIMERA_JORNADA + 2
const CUARTA := ReglasDeLaPartida.PRIMERA_JORNADA + 3
const QUINTA := ReglasDeLaPartida.PRIMERA_JORNADA + 4
const PERSONAJE := DialogosDeCompradores.Personaje
const SEMILLAS := 40

const AGENDAS := {
	TERCERA:
	[
		["Cami", PERSONAJE.CAMI, Vector2i(20, 3), Vector2i(22, 33)],
		["Tin", PERSONAJE.TIN, Vector2i(1, 30), Vector2i(4, 0)],
	],
	CUARTA:
	[
		["Tia", PERSONAJE.TIA, Vector2i(22, 0), Vector2i(0, 30)],
		["Fede", PERSONAJE.FEDE, Vector2i(4, 0), Vector2i(6, 30)],
	],
	QUINTA:
	[
		["Cami", PERSONAJE.CAMI, Vector2i(20, 30), Vector2i(23, 0)],
		["Mía", PERSONAJE.MIA, Vector2i(5, 0), Vector2i(7, 30)],
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


func test_las_ventanas_de_la_cuarta_y_la_quinta_duran_dos_horas_y_media() -> void:  # AC-CTR-109
	var casos := [
		[CUARTA, 0, Vector2i(22, 0), Vector2i(0, 30)],
		[CUARTA, 1, Vector2i(4, 0), Vector2i(6, 30)],
		[QUINTA, 0, Vector2i(20, 30), Vector2i(23, 0)],
		[QUINTA, 1, Vector2i(5, 0), Vector2i(7, 30)],
	]
	for caso: Array in casos:
		var compradores := Compradores.de_la_jornada(caso[0], 1)
		var agenda := AgendaDeCompradores.new(compradores)
		var llegada := _segundos(caso[2])
		var limite := _segundos(caso[3])
		if caso[1] == 1:
			agenda.avanzar(compradores[0].horario.y)
		assert_array(agenda.avanzar(llegada - 1.0)).is_empty()
		var llego := agenda.avanzar(llegada)
		assert_array(llego).has_size(1)
		assert_object(llego[0].comprador).is_same(compradores[caso[1]])
		assert_array(agenda.avanzar(limite - 1.0)).is_empty()
		var vencio := agenda.avanzar(limite)
		assert_array(vencio).has_size(1)
		assert_int(vencio[0].tipo).is_equal(AgendaDeCompradores.Tipo.VENCIO)


func test_una_compra_completa_no_vence() -> void:  # AC-CTR-069
	for jornada: int in AGENDAS:
		var compradores := Compradores.de_la_jornada(jornada, 1)
		var agenda := AgendaDeCompradores.new(compradores)
		agenda.avanzar(compradores[0].horario.x)
		assert_int(agenda.avanzar(compradores[0].horario.y, [compradores[0]]).size()).is_zero()


func test_cada_pedido_son_dos_o_tres_tipos_de_su_grupo_y_de_lo_que_se_vende() -> void:  # AC-CTR-071
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
					assert_array(Compradores.GRUPOS[comprador.personaje]).contains([producto.id])
				assert_int(ids.size()).is_between(2, 3)


func test_la_tercera_pide_de_la_interseccion_de_su_grupo_con_la_prueba() -> void:  # AC-CTR-107
	var candidatos := {
		"Cami":
		[Producto.Id.ZUCARACHAS, Producto.Id.JORGILLO, Producto.Id.PEPITO, Producto.Id.PETISAS],
		"Tin":
		[
			Producto.Id.MAROLINI,
			Producto.Id.PURA_COLA,
			Producto.Id.MALBARDO,
			Producto.Id.MAYONCHIS,
			Producto.Id.ARVECOR,
			Producto.Id.DON_SATURADOS,
		],
	}
	var pedidos: Dictionary = {"Cami": {}, "Tin": {}}
	for semilla in range(1, SEMILLAS + 1):
		for comprador in Compradores.de_la_jornada(TERCERA, semilla):
			for producto in comprador.pedido().productos():
				assert_array(candidatos[comprador.nombre()]).contains([producto.id])
				pedidos[comprador.nombre()][producto.id] = true
	for nombre: String in candidatos:
		assert_array(pedidos[nombre].keys()).contains_exactly_in_any_order(candidatos[nombre])


func test_fede_nunca_pide_durextra() -> void:  # AC-CTR-107
	for semilla in range(1, SEMILLAS + 1):
		for comprador in Compradores.de_la_jornada(CUARTA, semilla):
			for producto in comprador.pedido().productos():
				assert_int(producto.id).is_not_equal(Producto.Id.DUREXTRA)


func test_los_pedidos_son_de_dos_y_de_tres_con_frecuencias_parecidas() -> void:  # AC-CTR-108
	var por_cantidad := {2: 0, 3: 0}
	for jornada: int in AGENDAS:
		for semilla in range(1, SEMILLAS + 1):
			for comprador in Compradores.de_la_jornada(jornada, semilla):
				por_cantidad[comprador.pedido().productos().size()] += 1
	var total: int = por_cantidad[2] + por_cantidad[3]
	assert_int(total).is_equal(AGENDAS.size() * 2 * SEMILLAS)
	assert_int(por_cantidad[2]).is_greater(total / 4)
	assert_int(por_cantidad[3]).is_greater(total / 4)


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
