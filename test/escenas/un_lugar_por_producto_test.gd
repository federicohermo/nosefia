## Un producto, un lugar: cada producto se repone en una tanda de una o dos filas, al alcance de
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
## metros. El cuerpo del jugador no pasa del contorno del mueble, y un zócalo hondo asoma por
## delante de lo de arriba: el lugar aparece antes de cruzar el pasillo.
const FALTANTES_DE_PRUEBA: Dictionary[Producto.Id, int] = {
	Producto.Id.ACTRONCITO: 4,
	Producto.Id.PURA_COLA: 5,
	Producto.Id.MAROLINI: 2,
	Producto.Id.PROGRES: 8,
	Producto.Id.LAYSNNT: 4
}

const HASTA_EL_PASILLO := 1.5

## De a cuánto se avanza buscando ese lugar, en metros.
const PASO_HACIA_EL_PASILLO := 0.05

## Cuánto se levanta el cuerpo al tantear el lugar, en metros: apoyado justo en el piso, lo
## toca, y tocarlo no es chocar.
const HOLGURA_DEL_PISO := 0.02


func _almacen() -> Node3D:
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	AperturaConLugar.abrir_con_semilla(almacen)
	AperturaConLugar.abrir_con_faltantes(almacen, FALTANTES_DE_PRUEBA)
	almacen.get("_jugador").set_physics_process(false)
	return almacen


func _disposicion(almacen: Node3D) -> DisposicionDeLaGondola:
	return almacen.get("_reposicion_manual").get("disposicion")


func _cupo(almacen: Node3D, producto: Producto) -> int:
	return (almacen.get("_repositor") as Repositor).estante().cupo(producto)


## Lo que la jornada 1 hace faltar de ese producto, que es con lo que abre el local armado.
func _faltante(almacen: Node3D, producto: Producto) -> int:
	return mini(FALTANTES_DE_PRUEBA.get(producto.id, 0), _cupo(almacen, producto))


## Una copia del bloque principal, en el mundo.
func _copia_en_el_mundo(almacen: Node3D, producto: Producto, indice: int) -> Transform3D:
	var presentacion: Node3D = almacen.get("_reposicion_manual")
	var bloque := _disposicion(almacen).principales[producto.id]
	return presentacion.global_transform * DisposicionDeLaGondola.copia(bloque, indice)


## La caja que ocupa una copia del bloque principal, en el mundo.
func _caja_de_la_copia(almacen: Node3D, producto: Producto, indice: int) -> AABB:
	var presentacion: Node3D = almacen.get("_reposicion_manual")
	var grupo: MultiMeshInstance3D = presentacion.get_node("ProductosDe" + producto.nombre)
	return _copia_en_el_mundo(almacen, producto, indice) * grupo.multimesh.mesh.get_aabb()


## El centro de una fila del bloque principal, en el mundo.
func _centro_de_la_fila(almacen: Node3D, producto: Producto, adelante: bool) -> Vector3:
	var fila := _disposicion(almacen).filas_de_adelante[producto.id]
	var total := DisposicionDeLaGondola.copias(_disposicion(almacen).principales[producto.id])
	var centro := Vector3.ZERO
	for columna in fila:
		var caja := _caja_de_la_copia(
			almacen, producto, columna + (total - fila if adelante else 0)
		)
		centro += caja.get_center() / fila
	return centro


func _frente(almacen: Node3D, producto: Producto) -> Vector3:
	var disposicion := _disposicion(almacen)
	if disposicion.principales[producto.id].is_empty():
		var contenido: Node3D = almacen.get("_reposicion_manual").get("contenido")
		var modelo := contenido.get_child(producto.id) as Node3D
		var local: Vector3 = modelo.get_meta("frente_del_modelo")
		var frente := modelo.basis * local
		frente.y = 0.0
		return frente.normalized()
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
	var lateral := frente.cross(Vector3.UP).normalized()
	var distancia := 0.0
	while distancia <= HASTA_EL_PASILLO:
		# Una hoja abierta ocupa el borde del pasillo; se puede apuntar desde un costado.
		for costado: float in [0.0, -0.2, 0.2, -0.4, 0.4]:
			var punto := Vector3(delante.x, 0.0, delante.z) + frente * distancia
			punto += lateral * costado
			var piso := espacio.intersect_ray(
				PhysicsRayQueryParameters3D.create(punto + Vector3.UP, punto + Vector3.DOWN, 1)
			)
			if piso.is_empty():
				continue
			var pie: Vector3 = piso["position"]
			consulta.transform = Transform3D(
				Basis.IDENTITY, pie + cuerpo.position + Vector3.UP * HOLGURA_DEL_PISO
			)
			if espacio.intersect_shape(consulta, 1).is_empty():
				var ojos := pie + Vector3.UP * ReglasDelJugador.ALTURA_DE_LA_CAMARA
				var vista := PhysicsRayQueryParameters3D.create(ojos, delante, 1)
				vista.exclude = [jugador.get_rid()]
				if espacio.intersect_ray(vista).is_empty():
					return pie
		distancia += PASO_HACIA_EL_PASILLO
	return Vector3.INF


## La cámara mira desde +Z: el giro de la mano lleva allá el frente de la tanda, sea cual sea
## de las cuatro caras de un mueble.
func test_la_mano_gira_el_frente_de_la_tanda_hacia_la_camara() -> void:
	for frente: Vector3 in [Vector3.LEFT, Vector3.RIGHT, Vector3.BACK, Vector3.FORWARD]:
		var giro := ReposicionManual.giro_hacia_la_camara(frente)
		assert_vector(Basis(Vector3.UP, deg_to_rad(giro)) * frente).is_equal_approx(
			Vector3.BACK, Vector3.ONE * 1e-5
		)


## El envase va derecho y de frente en la mano, cualquiera sea el mueble del que sale.
## La orientación se mide sobre el envase, sin exigir que el arte conserve estantes inclinados.
func test_cada_producto_retirado_va_derecho_y_de_frente_en_la_mano() -> void:
	var almacen := _almacen()
	# Cada producto tiene que poder volver a la góndola: si no, la unidad se queda en la mano
	# y el retiro del siguiente se rechaza, y se mide la de antes.
	AperturaConLugar.abrir_con_todo_el_lugar(almacen)
	var agarre: Agarre = almacen.get("_agarre")
	var presentacion: Node3D = almacen.get("_reposicion_manual")
	var contenido: Node3D = presentacion.get("contenido")
	var arriba_de_referencia := Vector3.ZERO
	var frente_de_referencia := Vector3.ZERO
	for producto in Catalogo.todos():
		var modelo := (contenido.get_child(producto.id) as Node3D).global_basis
		var arriba := _eje(modelo, Vector3.UP)
		var pasillo := presentacion.global_basis * _frente(almacen, producto)
		var frente := (pasillo - arriba * pasillo.dot(arriba)).normalized()
		presentacion.call("retirar", producto.id)
		var en_la_mano := _sin_la_pose(presentacion, producto.id, agarre)
		if arriba_de_referencia == Vector3.ZERO:
			arriba_de_referencia = en_la_mano * arriba
			frente_de_referencia = en_la_mano * frente
		(
			assert_float(rad_to_deg((en_la_mano * arriba).angle_to(arriba_de_referencia)))
			. override_failure_message("%s no va derecho en la mano" % producto.nombre)
			. is_less(1.0)
		)
		(
			assert_float(rad_to_deg((en_la_mano * frente).angle_to(frente_de_referencia)))
			. override_failure_message("%s no muestra el frente como los demás" % producto.nombre)
			. is_less(1.0)
		)
		if _cupo(almacen, producto) == 0:
			presentacion.call("devolver", producto.id)
		else:
			presentacion.call("pedir_colocar", producto.id)


## El eje de un giro que más se parece a `hacia`, dado vuelta si apunta al revés.
static func _eje(giro: Basis, hacia: Vector3) -> Vector3:
	var mejor := Vector3.ZERO
	for columna in 3:
		var eje := giro[columna].normalized()
		if absf(eje.dot(hacia)) > absf(mejor.dot(hacia)):
			mejor = eje
	return mejor if mejor.dot(hacia) > 0.0 else -mejor


## Agarrar cada producto de su casillero conserva la orientación de la mano y su apoyo real.
func test_cada_producto_agarrado_va_derecho_y_de_frente_en_la_mano() -> void:
	var almacen := _almacen()
	await get_tree().physics_frame
	await get_tree().physics_frame
	# La góndola llena: cada casillero tiene su unidad para agarrar.
	var sin_faltantes: Dictionary[Producto.Id, int] = {}
	AperturaConLugar.abrir_con_faltantes(almacen, sin_faltantes)
	var agarre: Agarre = almacen.get("_agarre")
	var presentacion: Node3D = almacen.get("_reposicion_manual")
	var contenido: Node3D = presentacion.get("contenido")
	var estante := (almacen.get("_repositor") as Repositor).estante()
	var medidas: Dictionary[String, PackedVector3Array] = {}
	for producto in Catalogo.todos():
		var ocupados := estante.casilleros_ocupados(producto)
		assert_array(ocupados).is_not_empty()
		var indice := ocupados[ocupados.size() - 1]
		var bloque := _disposicion(almacen).principales[producto.id]
		var de_la_tanda := DisposicionDeLaGondola.copias(bloque) - _cupo(almacen, producto) + indice
		var unidad := _caja_de_la_copia(almacen, producto, de_la_tanda).get_center()
		var chapa := _golpe(almacen, unidad, unidad + Vector3.DOWN)
		var en_rampa := not chapa.is_empty() and _inclinado(chapa["normal"])
		var modelo := (contenido.get_child(producto.id) as Node3D).global_basis
		var arriba := _eje(modelo, Vector3.UP)
		var pasillo := presentacion.global_basis * _frente(almacen, producto)
		var frente := (pasillo - arriba * pasillo.dot(arriba)).normalized()
		var copia := _copia_en_el_mundo(almacen, producto, de_la_tanda)
		(
			assert_bool(_inclinado(copia.basis.orthonormalized() * arriba))
			. override_failure_message("%s no va echado como su chapa" % producto.nombre)
			. is_equal(en_rampa)
		)
		presentacion.call("agarrar_de_la_gondola", producto.id, indice)
		(
			assert_array(estante.casilleros_vacios(producto))
			. override_failure_message("%s no se agarró de su casillero" % producto.nombre)
			. contains_exactly([indice])
		)
		var en_la_mano := _sin_la_pose(presentacion, producto.id, agarre)
		var medida := PackedVector3Array([en_la_mano * arriba, en_la_mano * frente])
		medidas[producto.nombre] = medida
		presentacion.call("pedir_colocar", producto.id, indice)
	assert_int(medidas.size()).is_equal(Catalogo.todos().size())
	var referencia: PackedVector3Array = medidas[Catalogo.todos()[0].nombre]
	for nombre: String in medidas:
		var medida := medidas[nombre]
		(
			assert_float(rad_to_deg(medida[0].angle_to(referencia[0])))
			. override_failure_message("%s no va derecho en la mano" % nombre)
			. is_less(1.0)
		)
		(
			assert_float(rad_to_deg(medida[1].angle_to(referencia[1])))
			. override_failure_message("%s no muestra el frente como los demás" % nombre)
			. is_less(1.0)
		)


## Lo que hay en la mano, sin la pose que la mano le da según la forma del envase: sin ella, todos
## van derechos y con el frente hacia la cámara.
static func _sin_la_pose(presentacion: Node3D, id: Producto.Id, agarre: Agarre) -> Basis:
	var pose: Basis = presentacion.call("_inclinacion_en_la_mano", id)
	var en_la_mano := (agarre.punto_de_producto.get_child(0) as Node3D).basis.orthonormalized()
	return pose.inverse() * en_la_mano


## Si un eje se aparta de la vertical más de un grado.
static func _inclinado(eje: Vector3) -> bool:
	return eje.angle_to(Vector3.UP) > deg_to_rad(1.0)


## Al abrir, de cada producto falta sólo lo que su jornada pide, y los casilleros son las
## últimas copias de su tanda. Reponer lo que falta prende exactamente esas copias, y ninguna
## otra.
func test_la_fila_de_adelante_de_cada_tanda_es_de_casilleros() -> void:  # AC-STK-028
	var almacen := _almacen()
	var presentacion: Node3D = almacen.get("_reposicion_manual")
	var disposicion := _disposicion(almacen)
	for producto in Catalogo.todos():
		var nombre := producto.nombre
		var cupo := _cupo(almacen, producto)
		assert_int(cupo).is_equal(disposicion.casilleros_de(producto.id))
		(
			assert_int(presentacion.find_children("ZonaDe" + nombre, "", false, false).size())
			. override_failure_message("%s no tiene un solo casillero" % nombre)
			. is_equal(0 if cupo == 0 else 1)
		)
		var grupo: MultiMeshInstance3D = presentacion.get_node("ProductosDe" + nombre)
		var copias := grupo.multimesh
		(
			assert_int(copias.instance_count - copias.visible_instance_count)
			. override_failure_message("%s: al abrir no falta sólo lo de la jornada" % nombre)
			. is_equal(_faltante(almacen, producto))
		)
		var lugares := _casilleros_de_la_disposicion(disposicion, producto)
		assert_int(lugares.size()).is_equal(cupo)
		for indice in cupo:
			var dibujada := _copia_del_dibujo(copias, copias.instance_count - cupo + indice)
			var de_la_tanda := lugares[indice]
			(
				assert_vector(dibujada.origin)
				. override_failure_message(
					"%s: el casillero %d no es de su tanda" % [nombre, indice]
				)
				. is_equal_approx(de_la_tanda.origin, Vector3.ONE * 1e-4)
			)
		for indice in _faltante(almacen, producto):
			presentacion.retirar(producto.id)
			presentacion.pedir_colocar(producto.id)
		assert_int(copias.visible_instance_count).is_equal(copias.instance_count)


## Parado en el pasillo frente a su casillero, con el producto en la mano, la mira lo encuentra
## y el clic lo coloca. Es el camino del jugador, entero, para cada producto: donde se para es
## donde su cuerpo entra, y no un punto elegido para que el caso pase. Cada producto arranca con
## un casillero vacío, que es lo que la noche le pide reponer.
func test_el_casillero_de_cada_producto_esta_al_alcance_desde_el_pasillo() -> void:  # AC-STK-029
	var almacen := _almacen()
	await AperturaConLugar.abrir_heladeras(almacen)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var jugador: Node3D = almacen.get("_jugador")
	var presentacion: Node3D = almacen.get("_reposicion_manual")
	var repositor: Repositor = almacen.get("_repositor")
	var uno_de_cada: Dictionary[Producto.Id, int] = {}
	for producto in Catalogo.todos():
		if _cupo(almacen, producto) > 0:
			uno_de_cada[producto.id] = 1
	AperturaConLugar.abrir_con_faltantes(almacen, uno_de_cada)
	for producto in Catalogo.todos():
		if _cupo(almacen, producto) == 0:
			continue
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


## La fila de cada tanda, de cara al pasillo: parado frente a cualquier unidad suya, el jugador
## la ve, porque nada del mueble se interpone. Una fila metida detrás del panel perforado es una
## fila que el jugador no ve, y desde el pasillo el estante parece vacío.
##
## **Se mira a cuatro alturas, y alcanza con que una se vea**: el portaprecio tapa el pie de una
## lata chata, y el borde del estante de arriba, la tapa de una caja alta.
func test_la_fila_da_al_pasillo() -> void:  # AC-STK-030
	var almacen := _almacen()
	await AperturaConLugar.abrir_heladeras(almacen)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var disposicion := _disposicion(almacen)
	for producto in Catalogo.todos():
		var frente := _frente(almacen, producto)
		var fila := disposicion.filas_de_adelante[producto.id]
		var total := DisposicionDeLaGondola.copias(disposicion.principales[producto.id])
		(
			assert_int(_cupo(almacen, producto))
			. override_failure_message(
				"%s: su fila de adelante no es entera de casilleros" % producto.nombre
			)
			. is_equal(disposicion.casilleros_de(producto.id))
		)
		for columna in fila:
			var delante := _caja_de_la_copia(almacen, producto, total - fila + columna)
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


## La apertura deja los huecos pedidos hasta el cupo real que tiene cada fila del modelo.
func test_la_apertura_fija_dibuja_sus_faltantes() -> void:  # AC-STK-004
	var almacen := _almacen()
	var estante := (almacen.get("_repositor") as Repositor).estante()
	var disposicion := _disposicion(almacen)
	var faltan: Array[String] = []
	for producto in Catalogo.todos():
		var nombre := producto.nombre
		var fila := disposicion.casilleros_de(producto.id)
		(
			assert_int(estante.unidades_en_gondola(producto))
			. override_failure_message("%s no abrió con su fila menos lo que falta" % nombre)
			. is_equal(fila - _faltante(almacen, producto))
		)
		(
			assert_int(estante.unidades_en_deposito(producto))
			. override_failure_message("la caja de %s no abrió llena" % nombre)
			. is_equal(ReglasDelEstante.UNIDADES_POR_CAJA)
		)
		if estante.unidades_en_gondola(producto) < estante.cupo(producto):
			faltan.append(nombre)
	assert_array(faltan).contains_exactly(
		["Actroncito", "Laysnnt", "Progres", "Pura-Cola", "Marolini"]
	)
	# El cupo nuevo no cambia los faltantes de la ficha: las referencias abren llenas y
	# sólo la principal pierde esas unidades, aunque ahora conserve un resto ocupado.
	var coracola := Catalogo.de(Producto.Id.PURA_COLA)
	var principal := disposicion.filas_de_adelante[coracola.id]
	var fijas := estante.cupo(coracola) - principal
	var ocupados := estante.casilleros_ocupados(coracola)
	var resto_principal := principal - _faltante(almacen, coracola)
	assert_int(ocupados.size()).is_equal(fijas + resto_principal)
	for indice in fijas:
		assert_array(ocupados).contains(indice)
	for indice in estante.casilleros_vacios(coracola):
		assert_int(indice).is_greater_equal(fijas)
	assert_bool(estante.completada()).is_false()


## Dónde va cada casillero de un producto, en orden: la fila de adelante de cada tanda fija suya
## y, al final, la de su tanda reponible, que es donde quedan los vacíos al abrir.
func _casilleros_de_la_disposicion(
	disposicion: DisposicionDeLaGondola, producto: Producto
) -> Array[Transform3D]:
	var lugares: Array[Transform3D] = []
	var bloques: Array[PackedFloat32Array] = []
	var filas: Array[int] = []
	for indice in disposicion.guias.size():
		if disposicion.productos_de_las_guias[indice] == producto.id:
			bloques.append(disposicion.guias[indice])
			filas.append(disposicion.filas_de_adelante_de_las_guias[indice])
	bloques.append(disposicion.principales[producto.id])
	filas.append(disposicion.filas_de_adelante[producto.id])
	for orden in bloques.size():
		var total := DisposicionDeLaGondola.copias(bloques[orden])
		for columna in filas[orden]:
			lugares.append(
				DisposicionDeLaGondola.copia(bloques[orden], total - filas[orden] + columna)
			)
	return lugares


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


func test_se_enfoca_y_agarra_una_unidad_de_cada_producto_desde_el_pasillo() -> void:  # AC-STK-050
	var almacen := _almacen()
	await AperturaConLugar.abrir_heladeras(almacen)
	var completos: Dictionary[Producto.Id, int] = {}
	AperturaConLugar.abrir_con_faltantes(almacen, completos)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var jugador: Node3D = almacen.get("_jugador")
	var presentacion: Node3D = almacen.get("_reposicion_manual")
	var agarre: Agarre = almacen.get("_agarre")
	var estante := (almacen.get("_repositor") as Repositor).estante()
	for producto in Catalogo.todos():
		if _cupo(almacen, producto) == 0:
			continue
		# El último casillero es de la tanda reponible, que es la que está a la altura de la mano.
		var ultimo := _cupo(almacen, producto) - 1
		var zona: Node3D = presentacion.casillero(producto.id, ultimo)
		assert_bool(estante.casilleros_ocupados(producto).has(ultimo)).is_true()
		assert_object(agarre.manos().sostenido()).is_null()
		var pie := _lugar_en_el_pasillo(almacen, zona.global_position, _frente(almacen, producto))
		assert_bool(pie.is_finite()).override_failure_message(producto.nombre).is_true()
		if not pie.is_finite():
			continue
		await _mirar_foco(
			jugador, pie + Vector3.UP * ReglasDelJugador.ALTURA_DE_LA_CAMARA, zona.global_position
		)
		assert_object(jugador.get("_enfocado")).override_failure_message(producto.nombre).is_same(
			zona
		)
		_clic_real(jugador)
		(
			assert_object(agarre.manos().sostenido())
			. override_failure_message(producto.nombre)
			. is_not_null()
		)
		assert_bool(estante.casilleros_ocupados(producto).has(ultimo)).is_false()
		presentacion.pedir_colocar(producto.id, ultimo)
		assert_object(agarre.manos().sostenido()).is_null()


func test_una_tanda_vaciada_no_deja_unidades_a_la_vista() -> void:  # AC-STK-030
	var almacen := _almacen()
	var completos: Dictionary[Producto.Id, int] = {}
	AperturaConLugar.abrir_con_faltantes(almacen, completos)
	var presentacion: Node3D = almacen.get("_reposicion_manual")
	var agarre: Agarre = almacen.get("_agarre")
	var miradas := 0
	for producto in Catalogo.todos():
		if _cupo(almacen, producto) == 0:
			continue
		var id := producto.id
		miradas += 1
		for indice in _cupo(almacen, producto):
			presentacion.agarrar_de_la_gondola(id, indice)
			agarre.vaciar_las_manos()
		var dibujo := presentacion.get_node("ProductosDe" + producto.nombre) as MultiMeshInstance3D
		var copias := dibujo.multimesh
		(
			assert_int(copias.visible_instance_count)
			. override_failure_message(producto.nombre)
			. is_equal(0)
		)
	assert_int(miradas).is_greater(0)


## La copia de un `MultiMesh`, leída del `buffer`: el renderizador de las corridas sin pantalla
## no implementa `get_instance_transform`.
func _copia_del_dibujo(copias: MultiMesh, indice: int) -> Transform3D:
	var valores := copias.buffer
	var inicio := indice * DisposicionDeLaGondola.FLOTANTES_POR_COPIA
	return DisposicionDeLaGondola.copia(
		valores.slice(inicio, inicio + DisposicionDeLaGondola.FLOTANTES_POR_COPIA), 0
	)
