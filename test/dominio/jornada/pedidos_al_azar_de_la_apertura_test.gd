extends GdUnitTestSuite

const TERCERA := ReglasDeLaPartida.PRIMERA_JORNADA + 2
const CUARTA := ReglasDeLaPartida.PRIMERA_JORNADA + 3
const QUINTA := ReglasDeLaPartida.PRIMERA_JORNADA + 4
const CORTE := ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA + 3
const ULTIMA := ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA + 4
const JORNADAS: Array[int] = [TERCERA, CUARTA, QUINTA, CORTE, ULTIMA]
const SEMILLAS := 60
const CASILLEROS := 8


func _cupos() -> Dictionary[Producto.Id, int]:
	var cupos: Dictionary[Producto.Id, int] = {}
	for producto in Catalogo.todos():
		cupos[producto.id] = CASILLEROS
	return cupos


func _azar(semilla: int) -> RandomNumberGenerator:
	var azar := RandomNumberGenerator.new()
	azar.seed = semilla
	return azar


func test_los_faltantes_respetan_los_pedidos_sorteados() -> void:  # AC-STK-107
	for jornada: int in JORNADAS:
		for semilla in range(1, SEMILLAS + 1):
			var compradores := Compradores.de_la_jornada(jornada, semilla)
			var pedidos := Apertura.pedidos_de(compradores)
			var inventario := Apertura.inventario_de_la_jornada(
				jornada, compradores, _cupos(), _cupos(), _azar(semilla)
			)
			for producto in Catalogo.de_la_jornada(jornada):
				var falta := (
					inventario.casilleros(producto)
					- inventario.unidades(producto, Inventario.Ubicacion.GONDOLA)
				)
				(
					assert_int(pedidos.get(producto.id, 0) + falta)
					. override_failure_message(
						(
							"jornada %d, semilla %d: `%s` pide más de lo que deja la caja"
							% [jornada, semilla, producto.nombre]
						)
					)
					. is_less_equal(ReglasDelEstante.UNIDADES_POR_CAJA)
				)


func test_los_pedidos_de_la_tercera_son_de_productos_presentes() -> void:  # AC-STK-107
	var presentes := Catalogo.de_la_jornada(TERCERA)
	var ids: Array[Producto.Id] = []
	for producto in presentes:
		ids.append(producto.id)
	for semilla in range(1, SEMILLAS + 1):
		for id in Apertura.pedidos_de(Compradores.de_la_jornada(TERCERA, semilla)):
			assert_array(ids).contains([id])


func test_faltantes_y_atencion_comparten_la_lista() -> void:  # AC-STK-107, AC-CTR-128
	for jornada: int in JORNADAS:
		for consultar_primero: bool in [true, false]:
			var compradores := Compradores.de_la_jornada(jornada, 3)
			var ventas: Array[Venta] = [compradores[0].pedido(), compradores[1].pedido()]
			var pedidos: Dictionary[Producto.Id, int]
			var inventario: Inventario
			var tarea: TareaDeAtender
			if consultar_primero:
				pedidos = Apertura.pedidos_de(compradores)
			inventario = Apertura.inventario_de_la_jornada(
				jornada, compradores, _cupos(), _cupos(), _azar(3)
			)
			tarea = TareaDeAtender.new(compradores, inventario)
			if not consultar_primero:
				pedidos = Apertura.pedidos_de(compradores)
			for _lectura in 3:
				assert_that(Apertura.pedidos_de(compradores)).is_equal(pedidos)
			for indice in 2:
				tarea.avanzar(compradores[indice].horario.x)
				assert_object(tarea.atencion().comprador()).is_same(compradores[indice])
				assert_object(tarea.atencion().comprador().pedido()).is_same(ventas[indice])
