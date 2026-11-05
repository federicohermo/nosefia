## Los siete productos que sólo se piden por el chat (BR-STK-054): están en el catálogo con su
## caja y su sonido, y no entran a la góndola, a la venta ni al pedido de un comprador.
extends GdUnitTestSuite

const COMPLETA := ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA
const ULTIMA := ReglasDeLaPartida.PRIMERA_JORNADA + ReglasDeLaPartida.JORNADAS_DE_LA_PARTIDA - 1
const SEMILLAS := 20

const NOMBRES: Array[String] = [
	"Sei Tuqui", "La Monteloca", "Frigordo", "Gringo", "Masticul", "Cofloco", "Chocolocas"
]
const EN_CAJA_CHICA: Array[String] = ["Sei Tuqui", "La Monteloca", "Masticul", "Cofloco"]
const CON_ENVOLTORIO: Array[String] = ["Sei Tuqui", "La Monteloca", "Masticul", "Cofloco"]


func _nombres(productos: Array[Producto]) -> Array[String]:
	var nombres: Array[String] = []
	for producto in productos:
		nombres.append(producto.nombre)
	return nombres


func test_los_siete_tienen_su_fila_su_caja_y_su_sonoridad() -> void:  # AC-STK-124
	assert_array(_nombres(Catalogo.solo_cajas())).contains_exactly(NOMBRES)
	for producto in Catalogo.solo_cajas():
		assert_int(producto.precio).is_greater(0)
		var chica := EN_CAJA_CHICA.has(producto.nombre)
		var esperada := Catalogo.TamanoDeCaja.CHICA if chica else Catalogo.TamanoDeCaja.GRANDE
		(
			assert_int(Catalogo.caja_de(producto.id))
			. override_failure_message(producto.nombre)
			. is_equal(esperada)
		)
		var envoltorio := CON_ENVOLTORIO.has(producto.nombre)
		var sonoridad := (
			EntradaSonora.Sonoridad.ENVOLTORIO_PLASTICO
			if envoltorio
			else EntradaSonora.Sonoridad.CAJA
		)
		(
			assert_int(Catalogo.sonoridad_de(producto.id))
			. override_failure_message(producto.nombre)
			. is_equal(sonoridad)
		)


func test_los_siete_no_entran_a_la_venta_ni_a_la_gondola() -> void:  # AC-STK-124
	for nombre in _nombres(Catalogo.todos()):
		assert_bool(NOMBRES.has(nombre)).override_failure_message(nombre).is_false()
	for jornada in range(ReglasDeLaPartida.PRIMERA_JORNADA, ULTIMA + 1):
		for nombre in _nombres(Catalogo.de_la_jornada(jornada)):
			assert_bool(NOMBRES.has(nombre)).override_failure_message(nombre).is_false()


func test_el_pedido_ofrece_los_siete_junto_a_los_demas() -> void:  # AC-STK-124
	var ofrecidos := _nombres(Catalogo.pedibles())
	assert_int(ofrecidos.size()).is_equal(Producto.Id.size())
	for nombre in NOMBRES:
		assert_bool(ofrecidos.has(nombre)).override_failure_message(nombre).is_true()


func test_ninguna_noche_los_deja_con_unidades_ni_faltantes() -> void:  # AC-STK-124
	for jornada in range(ReglasDeLaPartida.PRIMERA_JORNADA, ULTIMA + 1):
		var inventario := Apertura.inventario_con_faltantes({}, {}, Catalogo.de_la_jornada(jornada))
		var faltan := _nombres(inventario.faltantes())
		for producto in Catalogo.solo_cajas():
			for ubicacion: Inventario.Ubicacion in Inventario.Ubicacion.values():
				assert_int(inventario.unidades(producto, ubicacion)).is_zero()
			assert_bool(faltan.has(producto.nombre)).is_false()


func test_los_compradores_nunca_piden_los_siete() -> void:  # AC-STK-125
	for jornada in range(ReglasDeLaPartida.PRIMERA_JORNADA, ULTIMA + 1):
		for semilla in SEMILLAS:
			for comprador in Compradores.de_la_jornada(jornada, semilla + 1):
				for producto in comprador.pedido().productos():
					(
						assert_bool(Catalogo.SOLO_CAJAS.has(producto.id))
						. override_failure_message(
							"jornada %d, semilla %d: %s" % [jornada, semilla, producto.nombre]
						)
						. is_false()
					)
