## Las siete zonas de reposición: a qué zona pertenece cada producto y cada punto del piso, y
## cuándo una zona tiene faltante.
##
## Ni un `Node3D` en la suite: la decisión «hay que reponer por acá» se ejerce con un estante y un
## punto. Los puntos salen de los límites de cada zona y no de coordenadas copiadas, así que mover
## una línea del mapa no obliga a reescribir un caso.
extends GdUnitTestSuite

const ZONA_CENTRAL := 4
const ZONA_DEL_COSTADO := 3
const ZONA_DE_LA_PUNTA := 6
const ZONA_DE_LA_ESTANTERIA := 2
const ZONA_DEL_BORDE_ESTE := 5
const CASILLEROS := 2
const EN_DEPOSITO := 8

## El primer producto de la zona central y el segundo, para el caso de dos faltantes en la zona.
const CENTRAL_A := 0
const CENTRAL_B := 1


func _jornada_con_reposicion() -> int:
	return ReglasDeLaPartida.PRIMERA_JORNADA + 1


func _centro(zona: int) -> Vector3:
	var limites := ZonasDeReposicion.LIMITES[zona]
	return Vector3((limites.x + limites.z) / 2.0, 0.0, (limites.y + limites.w) / 2.0)


## Un estante de la jornada con todas las góndolas llenas y el depósito cargado.
func _estante(jornada: int) -> Estante:
	var productos := Catalogo.de_la_jornada(jornada)
	var casilleros: Dictionary[Producto.Id, int] = {}
	for producto in productos:
		casilleros[producto.id] = CASILLEROS
	var inventario := Inventario.new(productos, casilleros)
	for producto in productos:
		inventario.ingresar(producto, Inventario.Ubicacion.GONDOLA, CASILLEROS)
		inventario.ingresar(producto, Inventario.Ubicacion.DEPOSITO, EN_DEPOSITO)
	return Estante.new(inventario, productos)


func _de_la_zona(zonas: ZonasDeReposicion, zona: int) -> Array[Producto]:
	var productos: Array[Producto] = []
	for id in zonas.productos_de(zona):
		productos.append(Catalogo.de(id))
	return productos


func _vaciar_un_casillero(estante: Estante, producto: Producto) -> void:
	var ocupados := estante.casilleros_ocupados(producto)
	assert_array(ocupados).is_not_empty()
	assert_object(estante.agarrar(producto, ocupados[0])).is_not_null()


func test_cada_producto_presente_cae_en_una_sola_zona_en_las_dos_etapas() -> void:  # AC-STK-114
	for jornada: int in [
		ReglasDeLaPartida.PRIMERA_JORNADA, ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA
	]:
		var zonas := ZonasDeReposicion.new(jornada)
		var vistos: Array[Producto.Id] = []
		for zona in range(1, ZonasDeReposicion.CANTIDAD + 1):
			vistos.append_array(zonas.productos_de(zona))
		var presentes: Array[Producto.Id] = []
		for producto in Catalogo.de_la_jornada(jornada):
			presentes.append(producto.id)
			assert_int(zonas.zona_de_producto(producto.id)).is_between(
				1, ZonasDeReposicion.CANTIDAD
			)
		assert_array(vistos).has_size(presentes.size())
		assert_array(vistos).contains_exactly_in_any_order(presentes)


func test_un_producto_ausente_de_la_etapa_no_pertenece_a_ninguna_zona() -> void:  # AC-STK-114
	var zonas := ZonasDeReposicion.new(ReglasDeLaPartida.PRIMERA_JORNADA)
	var ausentes := 0
	var presentes: Array[Producto.Id] = []
	for producto in Catalogo.de_la_jornada(ReglasDeLaPartida.PRIMERA_JORNADA):
		presentes.append(producto.id)
	for producto in Catalogo.todos():
		if presentes.has(producto.id):
			continue
		ausentes += 1
		assert_int(zonas.zona_de_producto(producto.id)).is_equal(ZonasDeReposicion.SIN_ZONA)
	assert_int(ausentes).is_greater(0)


func test_duronga_cae_con_la_estanteria_y_las_heladeras_en_la_zona_uno() -> void:  # AC-STK-114
	for jornada: int in [
		ReglasDeLaPartida.PRIMERA_JORNADA, ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA
	]:
		var zonas := ZonasDeReposicion.new(jornada)
		assert_int(zonas.zona_de_producto(Producto.Id.DURONGA)).is_equal(ZONA_DE_LA_ESTANTERIA)
		assert_int(zonas.zona_de_producto(Producto.Id.ACTRONCITO)).is_equal(ZONA_DE_LA_ESTANTERIA)
		assert_int(zonas.zona_de_producto(Producto.Id.PURA_COLA)).is_equal(
			zonas.zona_de_producto(Producto.Id.MAYONCHIS)
		)


func test_una_zona_tiene_faltante_mientras_algun_producto_suyo_lo_tiene() -> void:  # AC-STK-115
	var jornada := _jornada_con_reposicion()
	var zonas := ZonasDeReposicion.new(jornada)
	var estante := _estante(jornada)
	var de_la_central := _de_la_zona(zonas, ZONA_CENTRAL)
	for zona in range(1, ZonasDeReposicion.CANTIDAD + 1):
		assert_bool(zonas.tiene_faltante(zona, estante)).is_false()
	_vaciar_un_casillero(estante, de_la_central[CENTRAL_A])
	for zona in range(1, ZonasDeReposicion.CANTIDAD + 1):
		assert_bool(zonas.tiene_faltante(zona, estante)).is_equal(zona == ZONA_CENTRAL)
	assert_int(estante.colocar(de_la_central[CENTRAL_A])).is_equal(Estante.Rechazo.NINGUNO)
	for zona in range(1, ZonasDeReposicion.CANTIDAD + 1):
		assert_bool(zonas.tiene_faltante(zona, estante)).is_false()


func test_con_dos_productos_faltantes_reponer_uno_deja_la_zona_con_faltante() -> void:  # AC-STK-115
	var jornada := _jornada_con_reposicion()
	var zonas := ZonasDeReposicion.new(jornada)
	var estante := _estante(jornada)
	var de_la_central := _de_la_zona(zonas, ZONA_CENTRAL)
	_vaciar_un_casillero(estante, de_la_central[CENTRAL_A])
	_vaciar_un_casillero(estante, de_la_central[CENTRAL_B])
	assert_int(estante.colocar(de_la_central[CENTRAL_A])).is_equal(Estante.Rechazo.NINGUNO)
	assert_bool(zonas.tiene_faltante(ZONA_CENTRAL, estante)).is_true()
	assert_int(estante.colocar(de_la_central[CENTRAL_B])).is_equal(Estante.Rechazo.NINGUNO)
	assert_bool(zonas.tiene_faltante(ZONA_CENTRAL, estante)).is_false()


func test_agarrar_de_una_gondola_completa_vuelve_a_dar_faltante_a_su_zona() -> void:  # AC-STK-115
	var jornada := _jornada_con_reposicion()
	var zonas := ZonasDeReposicion.new(jornada)
	var estante := _estante(jornada)
	var de_la_punta := _de_la_zona(zonas, ZONA_DE_LA_PUNTA)
	assert_bool(zonas.tiene_faltante(ZONA_DE_LA_PUNTA, estante)).is_false()
	_vaciar_un_casillero(estante, de_la_punta[0])
	assert_bool(zonas.tiene_faltante(ZONA_DE_LA_PUNTA, estante)).is_true()


func test_una_jornada_que_no_declara_reponer_no_tiene_zonas_con_faltante() -> void:  # AC-STK-115
	var jornada := ReglasDeLaPartida.PRIMERA_JORNADA
	var zonas := ZonasDeReposicion.new(jornada)
	var estante := _estante(jornada)
	for producto in Catalogo.de_la_jornada(jornada):
		while not estante.casilleros_ocupados(producto).is_empty():
			_vaciar_un_casillero(estante, producto)
	for zona in range(1, ZonasDeReposicion.CANTIDAD + 1):
		assert_bool(zonas.tiene_faltante(zona, estante)).is_false()


func test_un_punto_del_interior_de_cada_zona_contesta_esa_zona() -> void:  # AC-STK-116
	var zonas := ZonasDeReposicion.new(_jornada_con_reposicion())
	for zona in range(1, ZonasDeReposicion.CANTIDAD + 1):
		assert_int(zonas.zona_de(_centro(zona))).is_equal(zona)


func test_un_punto_del_limite_contesta_siempre_la_misma_zona() -> void:  # AC-STK-116
	var zonas := ZonasDeReposicion.new(_jornada_con_reposicion())
	for derecha: int in [ZONA_CENTRAL, ZONA_DEL_BORDE_ESTE]:
		var limites := ZonasDeReposicion.LIMITES[derecha]
		var altura := (limites.y + limites.w) / 2.0
		var sobre_el_limite := Vector3(limites.x, 0.0, altura)
		var respuesta := zonas.zona_de(sobre_el_limite)
		assert_int(respuesta).is_not_equal(ZonasDeReposicion.SIN_ZONA)
		for intento in 10:
			assert_int(zonas.zona_de(sobre_el_limite)).is_equal(respuesta)
		assert_int(zonas.zona_de(sobre_el_limite + Vector3.RIGHT * 0.001)).is_equal(respuesta)
		assert_int(zonas.zona_de(sobre_el_limite + Vector3.LEFT * 0.001)).is_not_equal(respuesta)


func test_un_punto_fuera_de_las_siete_zonas_no_contesta_ninguna() -> void:  # AC-STK-116
	var zonas := ZonasDeReposicion.new(_jornada_con_reposicion())
	var mas_al_norte := _centro(1) + Vector3.FORWARD * 20.0
	assert_int(zonas.zona_de(mas_al_norte)).is_equal(ZonasDeReposicion.SIN_ZONA)
	assert_int(zonas.zona_de(_centro(ZONA_DEL_COSTADO) + Vector3.LEFT * 20.0)).is_equal(
		ZonasDeReposicion.SIN_ZONA
	)
	assert_bool(zonas.hay_faltante_en(mas_al_norte, _estante(_jornada_con_reposicion()))).is_false()
