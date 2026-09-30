## Un producto, un lugar: cada producto se repone en una sola tanda de dos filas, al alcance de
## quien está parado en el pasillo, y lo que se repite en otro estante es fijo.
##
## La forma de cada tanda sale del recurso y la prueba `disposicion_de_la_gondola_test.gd`. Acá
## va lo que sólo se ve con el local armado: qué se dibuja al abrir, adónde va lo repuesto y si
## la mira llega.
extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.tscn")
const ReposicionManual := preload("res://src/escenas/puestos/reposicion_manual.gd")
const AperturaConLugar := preload("res://test/escenas/apertura_con_lugar.gd")

## Hasta dónde se busca, delante de una unidad, un lugar donde el jugador entre parado, en
## metros. Un estante achicado queda hundido entre los laterales del mueble, y el cuerpo del
## jugador no pasa del contorno: el lugar aparece a un metro y algo, y antes de cruzar el pasillo.
const HASTA_EL_PASILLO := 1.5

## De a cuánto se avanza buscando ese lugar, en metros.
const PASO_HACIA_EL_PASILLO := 0.05

## Cuánto se levanta el cuerpo al tantear el lugar, en metros: apoyado justo en el piso, lo
## toca, y tocarlo no es chocar.
const HOLGURA_DEL_PISO := 0.02


func _almacen() -> Node3D:
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	almacen.get("_jugador").set_physics_process(false)
	return almacen


func _disposicion(almacen: Node3D) -> DisposicionDeLaGondola:
	return almacen.get("_reposicion_manual").get("disposicion")


func _cupo(almacen: Node3D, producto: Producto) -> int:
	return (almacen.get("_repositor") as Repositor).estante().cupo(producto)


## Lo que la jornada 1 hace faltar de ese producto, que es con lo que abre el local armado.
func _faltante(producto: Producto) -> int:
	return Apertura.faltantes_de_la_jornada(ReglasDeLaPartida.PRIMERA_JORNADA).get(producto.id, 0)


## La caja que ocupa una copia del bloque principal, en el mundo.
func _caja_de_la_copia(almacen: Node3D, producto: Producto, indice: int) -> AABB:
	var presentacion: Node3D = almacen.get("_reposicion_manual")
	var grupo: MultiMeshInstance3D = presentacion.get_node("ProductosDe" + producto.nombre)
	var bloque := _disposicion(almacen).principales[producto.id]
	var copia := presentacion.global_transform * DisposicionDeLaGondola.copia(bloque, indice)
	return copia * grupo.multimesh.mesh.get_aabb()


## El centro de una fila del bloque principal, en el mundo.
func _centro_de_la_fila(almacen: Node3D, producto: Producto, adelante: bool) -> Vector3:
	var fila := _disposicion(almacen).filas_de_adelante[producto.id]
	var centro := Vector3.ZERO
	for columna in fila:
		var caja := _caja_de_la_copia(almacen, producto, columna + (fila if adelante else 0))
		centro += caja.get_center() / fila
	return centro


func _frente(almacen: Node3D, producto: Producto) -> Vector3:
	var disposicion := _disposicion(almacen)
	return DisposicionDeLaGondola.frente(
		disposicion.principales[producto.id], disposicion.filas_de_adelante[producto.id]
	)


func _golpe(almacen: Node3D, desde: Vector3, hasta: Vector3) -> Dictionary:
	var consulta := PhysicsRayQueryParameters3D.create(desde, hasta, 1)
	return almacen.get_world_3d().direct_space_state.intersect_ray(consulta)


## Dónde se para el jugador frente a un punto de un estante: el primer lugar, avanzando desde
## ahí hacia el pasillo, donde su cuerpo entra sin chocar con nada de lo que lo frena —los
## muebles, su contorno, las paredes—. Sin ninguno antes de `HASTA_EL_PASILLO`, `Vector3.INF`.
func _lugar_en_el_pasillo(almacen: Node3D, delante: Vector3, frente: Vector3) -> Vector3:
	var jugador: CharacterBody3D = almacen.get("_jugador")
	var cuerpo: CollisionShape3D = jugador.get_node("Cuerpo")
	var consulta := PhysicsShapeQueryParameters3D.new()
	consulta.shape = cuerpo.shape
	consulta.collision_mask = jugador.collision_mask
	consulta.exclude = [jugador.get_rid()]
	var espacio := almacen.get_world_3d().direct_space_state
	var distancia := 0.0
	while distancia <= HASTA_EL_PASILLO:
		var punto := Vector3(delante.x, 0.0, delante.z) + frente * distancia
		# El piso del local no está en cero: se lo busca debajo de cada lugar.
		var piso := espacio.intersect_ray(
			PhysicsRayQueryParameters3D.create(punto + Vector3.UP, punto + Vector3.DOWN, 1)
		)
		distancia += PASO_HACIA_EL_PASILLO
		if piso.is_empty():
			continue
		var pie: Vector3 = piso["position"]
		consulta.transform = Transform3D(
			Basis.IDENTITY, pie + cuerpo.position + Vector3.UP * HOLGURA_DEL_PISO
		)
		if espacio.intersect_shape(consulta, 1).is_empty():
			return pie
	return Vector3.INF


## La cámara mira desde +Z: el giro de la mano lleva allá el frente de la tanda, sea cual sea
## de las cuatro caras de un mueble.
func test_la_mano_gira_el_frente_de_la_tanda_hacia_la_camara() -> void:
	for frente: Vector3 in [Vector3.LEFT, Vector3.RIGHT, Vector3.BACK, Vector3.FORWARD]:
		var giro := ReposicionManual.giro_hacia_la_camara(frente)
		assert_vector(Basis(Vector3.UP, deg_to_rad(giro)) * frente).is_equal_approx(
			Vector3.BACK, Vector3.ONE * 1e-5
		)


## Al abrir, de cada producto falta sólo lo que su jornada pide, y los casilleros son las
## últimas copias de su tanda: las guías que lo repiten en otros estantes se dibujan enteras y no
## se reponen nunca. Reponer lo que falta prende exactamente esas copias, y ninguna otra.
func test_cada_producto_se_repone_en_una_sola_tanda_y_lo_repetido_es_fijo() -> void:  # AC-STK-028
	var almacen := _almacen()
	var presentacion: Node3D = almacen.get("_reposicion_manual")
	var disposicion := _disposicion(almacen)
	for producto in Catalogo.todos():
		var nombre := producto.nombre
		var cupo := _cupo(almacen, producto)
		(
			assert_int(presentacion.find_children("ZonaDe" + nombre, "", false, false).size())
			. override_failure_message("%s no tiene un solo casillero" % nombre)
			. is_equal(1)
		)
		var grupo: MultiMeshInstance3D = presentacion.get_node("ProductosDe" + nombre)
		var copias := grupo.multimesh
		(
			assert_int(copias.instance_count - copias.visible_instance_count)
			. override_failure_message("%s: al abrir no falta sólo lo de la jornada" % nombre)
			. is_equal(_faltante(producto))
		)
		var bloque := disposicion.principales[producto.id]
		var principales := DisposicionDeLaGondola.copias(bloque)
		for indice in cupo:
			var dibujada := _copia_del_dibujo(copias, copias.instance_count - cupo + indice)
			var de_la_tanda := DisposicionDeLaGondola.copia(bloque, principales - cupo + indice)
			(
				assert_vector(dibujada.origin)
				. override_failure_message(
					"%s: el casillero %d no es de su tanda" % [nombre, indice]
				)
				. is_equal_approx(de_la_tanda.origin, Vector3.ONE * 1e-4)
			)
		for indice in _faltante(producto):
			presentacion.retirar(producto.id)
			presentacion.pedir_colocar(producto.id)
		assert_int(copias.visible_instance_count).is_equal(copias.instance_count)


## Parado en el pasillo frente a su casillero, con el producto en la mano, la mira lo encuentra
## y el clic lo coloca. Es el camino del jugador, entero, para cada producto: donde se para es
## donde su cuerpo entra, y no un punto elegido para que el caso pase. Cada producto arranca con
## un casillero vacío, que es lo que la noche le pide reponer.
func test_el_casillero_de_cada_producto_esta_al_alcance_desde_el_pasillo() -> void:  # AC-STK-029
	var almacen := _almacen()
	await get_tree().physics_frame
	await get_tree().physics_frame
	var jugador: Node3D = almacen.get("_jugador")
	var presentacion: Node3D = almacen.get("_reposicion_manual")
	var repositor: Repositor = almacen.get("_repositor")
	var uno_de_cada: Dictionary[Producto.Id, int] = {}
	for producto in Catalogo.todos():
		uno_de_cada[producto.id] = 1
	AperturaConLugar.abrir_con_faltantes(almacen, uno_de_cada)
	for producto in Catalogo.todos():
		presentacion.retirar(producto.id)
		var zona: Node3D = presentacion.casillero(producto.id)
		var pie := _lugar_en_el_pasillo(almacen, zona.global_position, _frente(almacen, producto))
		(
			assert_bool(pie.is_finite())
			. override_failure_message(
				"%s: no hay dónde pararse frente a su casillero" % producto.nombre
			)
			. is_true()
		)
		if not pie.is_finite():
			(almacen.get("_agarre") as Agarre).vaciar_las_manos()
			continue
		await _mirar_foco(
			jugador, pie + Vector3.UP * ReglasDelJugador.ALTURA_DE_LA_CAMARA, zona.global_position
		)
		(
			assert_object(jugador.get("_enfocado"))
			. override_failure_message("%s: la mira no llega a su casillero" % producto.nombre)
			. is_same(zona)
		)
		_clic_real(jugador)
		(
			assert_int(repositor.estante().unidades_en_gondola(producto))
			. override_failure_message("%s no se colocó" % producto.nombre)
			. is_equal(_cupo(almacen, producto))
		)
		(almacen.get("_agarre") as Agarre).vaciar_las_manos()


## Las dos filas de cada tanda, una detrás de la otra y de cara al pasillo: parado frente a
## cualquier unidad de la fila de adelante, el jugador la ve, porque nada del mueble se
## interpone; y entre cada unidad de la fila de atrás y la de adelante que tiene delante no hay
## nada del mueble. Una fila metida detrás del panel perforado —la chapa sigue detrás de él— es
## una fila que el jugador no ve, y desde el pasillo el estante parece vacío.
##
## **La de adelante se mira a cuatro alturas, y alcanza con que una se vea**: el portaprecio tapa
## el pie de una lata chata, y el borde del estante de arriba, la tapa de una caja alta. La de
## atrás no se mira desde el pasillo: en un estante hondo, bajo otro, queda debajo de él, como
## en cualquier góndola.
func test_las_dos_filas_dan_al_pasillo() -> void:  # AC-STK-030
	var almacen := _almacen()
	await get_tree().physics_frame
	await get_tree().physics_frame
	var disposicion := _disposicion(almacen)
	for producto in Catalogo.todos():
		var frente := _frente(almacen, producto)
		var fila := disposicion.filas_de_adelante[producto.id]
		(
			assert_int(_cupo(almacen, producto))
			. override_failure_message(
				"%s: su fila de adelante no es entera de casilleros" % producto.nombre
			)
			. is_equal(fila)
		)
		for columna in fila:
			var atras := _caja_de_la_copia(almacen, producto, columna).get_center()
			var delante := _caja_de_la_copia(almacen, producto, fila + columna)
			(
				assert_dict(_golpe(almacen, atras, delante.get_center()))
				. override_failure_message(
					(
						"%s: el mueble separa sus dos filas en la columna %d"
						% [producto.nombre, columna]
					)
				)
				. is_empty()
			)
			var pie := _lugar_en_el_pasillo(almacen, delante.get_center(), frente)
			if not pie.is_finite():
				fail("%s: no hay dónde pararse frente a su columna %d" % [producto.nombre, columna])
				continue
			var ojo := pie + Vector3.UP * ReglasDelJugador.ALTURA_DE_LA_CAMARA
			var tapada := true
			for altura: float in [0.25, 0.5, 0.75, 0.95]:
				var punto := delante.position + delante.size * Vector3(0.5, altura, 0.5)
				tapada = tapada and not _golpe(almacen, ojo, punto).is_empty()
			(
				assert_bool(tapada)
				. override_failure_message(
					"%s: el mueble tapa su columna %d desde el pasillo" % [producto.nombre, columna]
				)
				. is_false()
			)


## Al abrir la jornada la fila de atrás se ve entera, y la de adelante completa salvo lo que la
## jornada hace faltar. Reponer lo que falta completa la de adelante y no mueve nada de la de
## atrás.
func test_la_fila_de_atras_se_ve_entera_desde_que_abre() -> void:  # AC-STK-031
	var almacen := _almacen()
	var presentacion: Node3D = almacen.get("_reposicion_manual")
	var disposicion := _disposicion(almacen)
	for producto in Catalogo.todos():
		var nombre := producto.nombre
		var falta := _faltante(producto)
		var fila := disposicion.filas_de_adelante[producto.id]
		var copias := (
			(presentacion.get_node("ProductosDe" + nombre) as MultiMeshInstance3D).multimesh
		)
		var guias := copias.instance_count - 2 * fila
		(
			assert_int(copias.visible_instance_count - guias)
			. override_failure_message(
				"%s: al abrir no se ven su fila de atrás y su fila menos lo que falta" % nombre
			)
			. is_equal(fila + fila - falta)
		)
		var antes := copias.buffer
		for indice in falta:
			presentacion.retirar(producto.id)
			presentacion.pedir_colocar(producto.id)
		assert_int(copias.visible_instance_count - guias).is_equal(2 * fila)
		(
			assert_array(Array(copias.buffer.slice(0, (guias + fila) * 12)))
			. override_failure_message("%s: reponer movió la fila de atrás" % nombre)
			. is_equal(Array(antes.slice(0, (guias + fila) * 12)))
		)


## La jornada 1 abre con 5 Actroncito y 6 Coracola faltando, y todos los demás con su fila de
## adelante completa; cada caja del depósito, llena. Es la cuenta del inventario con los
## casilleros que mide el modelo, y no con unos inventados: Coracola tiene seis, así que su fila
## arranca vacía entera.
func test_la_jornada_1_abre_con_lo_que_dice_la_ficha() -> void:  # AC-STK-034 AC-STK-004
	var almacen := _almacen()
	var estante := (almacen.get("_repositor") as Repositor).estante()
	var disposicion := _disposicion(almacen)
	var faltan: Array[String] = []
	for producto in Catalogo.todos():
		var nombre := producto.nombre
		var fila := disposicion.filas_de_adelante[producto.id]
		(
			assert_int(estante.unidades_en_gondola(producto))
			. override_failure_message("%s no abrió con su fila menos lo que falta" % nombre)
			. is_equal(fila - _faltante(producto))
		)
		(
			assert_int(estante.unidades_en_deposito(producto))
			. override_failure_message("la caja de %s no abrió llena" % nombre)
			. is_equal(ReglasDelEstante.UNIDADES_POR_CAJA)
		)
		if estante.unidades_en_gondola(producto) < estante.cupo(producto):
			faltan.append(nombre)
	assert_array(faltan).contains_exactly(["Actroncito", "Coracola"])
	assert_int(estante.unidades_en_gondola(Catalogo.de(Producto.Id.CORACOLA))).is_zero()
	assert_bool(estante.completada()).is_false()


func _mirar_foco(jugador: Node3D, ojo: Vector3, punto: Vector3) -> void:
	var camara: Camera3D = jugador.get_node("Giro/Camara")
	camara.position = Vector3.UP * ReglasDelJugador.ALTURA_DE_LA_CAMARA
	jugador.global_position = ojo - camara.position
	camara.look_at(punto)
	for cuadro in 4:
		await get_tree().physics_frame
	jugador.call("_leer_la_mira")


func _clic_real(jugador: Node3D) -> void:
	var clic := InputEventAction.new()
	clic.action = ReglasDeLosObjetos.ACCION_AGARRAR
	clic.pressed = true
	jugador.call("_unhandled_input", clic)


## La copia de un `MultiMesh`, leída del `buffer`: el renderizador de las corridas sin pantalla
## no implementa `get_instance_transform`.
func _copia_del_dibujo(copias: MultiMesh, indice: int) -> Transform3D:
	var valores := copias.buffer
	var inicio := indice * DisposicionDeLaGondola.FLOTANTES_POR_COPIA
	return DisposicionDeLaGondola.copia(
		valores.slice(inicio, inicio + DisposicionDeLaGondola.FLOTANTES_POR_COPIA), 0
	)
