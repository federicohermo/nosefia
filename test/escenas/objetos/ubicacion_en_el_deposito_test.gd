## Dónde arranca la noche cada cosa suelta: las cajas de reposición en el depósito y las bolsas
## de basura también en el depósito.
##
## Las dos habitaciones las abre el 043, y antes de él no se podía poner nada adentro: la puerta
## las dejaba inalcanzables.
extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.tscn")

## Punto libre del depósito desde donde se comprueba el acceso a las bolsas.
const ENTRADA_DEL_DEPOSITO := Vector3(5.5, 1.05, -8.7)

## Adonde se corre una caja para probar que la apertura la devuelve. Es el aire en el medio del
## local, lejos del depósito y de cualquier apoyo.
const LEJOS_DE_SU_LUGAR := Vector3(0.0, 2.0, 0.0)

## Distancias desde la cara rotulada que se prueban dentro del alcance real de la mira.
const DISTANCIAS_EN_EL_PASILLO: Array[float] = [0.8, 1.3, 2.0]


## Cuánto separa el centro de una caja apoyada de la superficie que la sostiene: la escala que
## el `.tscn` le pone a un cubo de dos.
##
## **Sale de cada caja y no de una constante, porque hay dos tamaños.** Los productos que entran
## en poco volumen llevan una caja chica; con un solo número, once cajas darían «flotando»
## estando apoyadas.
func _media_caja(caja: Node3D) -> float:
	return (caja.get_node("Cuerpo") as Node3D).scale.x


func test_las_cajas_de_reposicion_estan_apoyadas_en_el_deposito() -> void:
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	await get_tree().physics_frame
	var espacio := almacen.get_world_3d().direct_space_state
	var cajas: Array = almacen.get("_cajas_de_productos")
	assert_int(cajas.size()).is_equal(Catalogo.todos().size())
	for caja: Node3D in cajas:
		var cuerpo := caja as PhysicsBody3D
		var consulta := PhysicsRayQueryParameters3D.create(
			cuerpo.global_position, cuerpo.global_position + Vector3.DOWN
		)
		consulta.exclude = [cuerpo.get_rid()]
		var golpe := espacio.intersect_ray(consulta)
		(
			assert_bool(golpe.has("position"))
			. override_failure_message("`%s` no se apoya en nada" % caja.name)
			. is_true()
		)
		var media := _media_caja(caja)
		var hueco: float = cuerpo.global_position.y - (golpe["position"] as Vector3).y
		(
			assert_float(hueco)
			. override_failure_message(
				"`%s` está a %.4f m de su apoyo y media caja es %.4f" % [caja.name, hueco, media]
			)
			. is_equal_approx(media, 0.001)
		)
		var apoyo: String = str(almacen.get_path_to(golpe["collider"]))
		(
			assert_bool(
				apoyo.contains("deposito_pallet_") and not apoyo.contains("deposito_pallet_piso")
			)
			. override_failure_message("`%s` se apoya en `%s`" % [caja.name, apoyo])
			. is_true()
		)
		assert_array(_lo_que_pisa(almacen, cuerpo, apoyo, media)).is_empty()


## La malla del modelo lleva la etiqueta en dos caras opuestas: la que la mano pone de frente a la
## cámara y su contraria. Las cajas no giran solas, así que lo que ve el cuarto lo decide el giro
## de cada una en la escena. Al menos una de sus dos caras rotuladas se ve desde los ojos de un
## jugador parado delante: si no, el jugador ve el costado de las flechas.
##
## **La vista baja desde los ojos, y no va derecha.** Una caja chica delante de una grande no le
## tapa la etiqueta a quien la mira desde arriba: es la esquina del portón.
func test_cada_caja_le_muestra_su_etiqueta_al_cuarto() -> void:
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	await get_tree().physics_frame
	var espacio := almacen.get_world_3d().direct_space_state
	var cajas: Array = almacen.get("_cajas_de_productos")
	assert_int(cajas.size()).is_equal(Catalogo.todos().size())
	# La altura de los ojos sale del piso real, independientemente de los apoyos de las cajas.
	var piso: CollisionShape3D = almacen.get_node("Estructura/SueloSolido/Fondo")
	var forma: BoxShape3D = piso.shape
	var suelo := (piso.global_transform * (Vector3.UP * forma.size.y / 2.0)).y
	var jugador: CharacterBody3D = almacen.get("_jugador")
	var cuerpo: CollisionShape3D = jugador.get_node("Cuerpo")
	for caja: Node3D in cajas:
		var orientacion: Basis = caja.get("orientacion_en_mano")
		var rotulada := orientacion.inverse() * Vector3.BACK
		var vistas: Array[Vector3] = []
		for cara: Vector3 in [rotulada, -rotulada]:
			var normal := (caja.global_basis * cara).normalized()
			var etiqueta := caja.global_position + normal * (_media_caja(caja) + 0.01)
			for distancia in DISTANCIAS_EN_EL_PASILLO:
				var pies := etiqueta + normal * distancia
				pies.y = suelo + 0.01
				var al_piso := PhysicsRayQueryParameters3D.create(
					Vector3(pies.x, 3.0, pies.z), Vector3(pies.x, -1.0, pies.z)
				)
				al_piso.collision_mask = jugador.collision_mask
				al_piso.exclude = [jugador.get_rid()]
				var apoyo := espacio.intersect_ray(al_piso)
				if apoyo.is_empty() or apoyo["collider"] != piso.get_parent():
					continue
				var capsula := PhysicsShapeQueryParameters3D.new()
				capsula.shape = cuerpo.shape
				capsula.transform = Transform3D(Basis.IDENTITY, pies) * cuerpo.transform
				capsula.collision_mask = jugador.collision_mask
				capsula.exclude = [jugador.get_rid()]
				capsula.margin = 0.0
				if not espacio.intersect_shape(capsula, 8).is_empty():
					continue
				var ojos := pies + Vector3.UP * ReglasDelJugador.ALTURA_DE_LA_CAMARA
				if ojos.distance_to(etiqueta) > ReglasDelJugador.ALCANCE_DE_LA_MIRA:
					continue
				var consulta := PhysicsRayQueryParameters3D.create(etiqueta, ojos)
				consulta.exclude = [(caja as PhysicsBody3D).get_rid(), jugador.get_rid()]
				if espacio.intersect_ray(consulta).is_empty():
					vistas.append(normal)
					break
		(
			assert_array(vistas)
			. override_failure_message(
				"`%s` le muestra al cuarto el costado de las flechas" % caja.name
			)
			. is_not_empty()
		)


func test_las_tres_bolsas_arrancan_en_el_deposito_y_lejos_del_contenedor() -> void:
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	await get_tree().physics_frame
	var contenedor: Node3D = almacen.get_node(
		"Estructura/deposito_contenedor_soporte/deposito_contenedor_cuerpo/StaticBody3D"
	)
	var piso := almacen.get_node("Estructura/SueloSolido/Fondo") as CollisionShape3D
	var tamano := (piso.shape as BoxShape3D).size
	var limites := piso.global_transform * AABB(-tamano / 2.0, tamano)
	var bolsas: Array = almacen.get("_bolsas")
	assert_int(bolsas.size()).is_equal(ReglasDeLaBasura.BOLSAS_DE_LA_JORNADA)
	var sin_las_bolsas: Array[RID] = []
	for cuerpo: PhysicsBody3D in bolsas:
		sin_las_bolsas.append(cuerpo.get_rid())
	for bolsa: Node3D in bolsas:
		var lugar := bolsa.global_position
		assert_bool(limites.has_point(Vector3(lugar.x, piso.global_position.y, lugar.z))).is_true()
		(
			assert_float(_camino_desde_la_puerta(almacen, lugar, sin_las_bolsas))
			. override_failure_message(
				"`%s` no se alcanza desde la puerta del depósito" % bolsa.name
			)
			. is_equal(1.0)
		)
		var distancia := lugar.distance_to(contenedor.global_position)
		(
			assert_float(distancia)
			. override_failure_message(
				"`%s` está a %.2f m del contenedor" % [bolsa.name, distancia]
			)
			. is_greater(ReglasDeLaBasura.DISTANCIA_MINIMA_AL_CONTENEDOR)
		)


## El recorrido rodea la góndola central por su extremo posterior.
##
## Las tres bolsas se excluyen para que no se tapen entre sí: se levantan de a una.
func _camino_desde_la_puerta(almacen: Node3D, hasta: Vector3, excluidas: Array[RID]) -> float:
	var forma := CapsuleShape3D.new()
	forma.radius = 0.4
	forma.height = 1.8
	var consulta := PhysicsShapeQueryParameters3D.new()
	consulta.shape = forma
	consulta.transform = Transform3D(Basis(), ENTRADA_DEL_DEPOSITO)
	consulta.exclude = excluidas
	var espacio := almacen.get_world_3d().direct_space_state
	assert_array(espacio.intersect_shape(consulta, 4)).is_empty()
	var pallet: MeshInstance3D = almacen.get_node(
		"Estructura/deposito_pallet_central_izquierdo_0_1"
	)
	var limites := pallet.global_transform * pallet.get_aabb()
	var atras := limites.position.z - forma.radius - 0.125
	var izquierdo := limites.position.x - forma.radius - 0.125
	var puntos: Array[Vector3] = [
		Vector3(4.3, ENTRADA_DEL_DEPOSITO.y, atras),
		Vector3(izquierdo, ENTRADA_DEL_DEPOSITO.y, atras),
		Vector3(hasta.x, ENTRADA_DEL_DEPOSITO.y, hasta.z),
	]
	var libre := 1.0
	for punto in puntos:
		consulta.motion = punto - consulta.transform.origin
		libre = minf(libre, espacio.cast_motion(consulta)[1])
		consulta.transform.origin = punto
	return libre


## Con qué se superpone un cuerpo, sin contar aquello sobre lo que se apoya.
func _lo_que_pisa(
	almacen: Node3D, cuerpo: PhysicsBody3D, apoyo: String, media: float
) -> Array[String]:
	var forma := BoxShape3D.new()
	forma.size = Vector3.ONE * (media * 2.0 - 0.01)
	var consulta := PhysicsShapeQueryParameters3D.new()
	consulta.shape = forma
	consulta.transform = Transform3D(Basis(), cuerpo.global_position)
	consulta.exclude = [cuerpo.get_rid()]
	var pisados: Array[String] = []
	for choque in almacen.get_world_3d().direct_space_state.intersect_shape(consulta, 8):
		var quien: String = str(almacen.get_path_to(choque["collider"]))
		if quien != apoyo:
			pisados.append("%s pisa %s" % [cuerpo.name, quien])
	return pisados


func test_abrir_la_jornada_devuelve_cada_caja_a_su_lugar() -> void:
	# Desde el 047 las cajas se trasladan, así que quedan donde el jugador las dejó. El dominio
	# se resetea y los nodos no: sin esta vuelta, la noche 2 arranca con la mercadería al lado
	# de la góndola y el viaje al depósito —que es lo que reponer cuesta— ya está pago.
	# **Se mide en global y no en `position`.** Una caja que quedó colgada del jugador tiene la
	# `position` correcta respecto de la mano y está flotando en el medio del local: comparar la
	# local da verde sobre el caso que más importa.
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	await get_tree().physics_frame
	var cajas: Array = almacen.get("_cajas_de_productos")
	var lugares: Array[Vector3] = []
	var giros: Array[Basis] = []
	for caja: Node3D in cajas:
		lugares.append(caja.global_position)
		giros.append(caja.global_basis)
	var mundo: Node3D = cajas[0].get_parent()
	# Una movida a mano y otra en la mano: la noche termina tantas veces cargando una caja como
	# habiéndola dejado tirada, y las dos tienen que volver al depósito. La movida queda además
	# girada: el jugador suelta cada caja mirando para cualquier lado.
	for caja: Node3D in cajas:
		caja.global_transform = Transform3D(Basis(Vector3.UP, 0.5), LEJOS_DE_SU_LUGAR)
	var jugador: Node3D = almacen.get("_jugador")
	var en_brazos: Node3D = cajas[Producto.Id.LAYSNTT]
	_agarrar(jugador, en_brazos)
	assert_object(en_brazos.get_parent()).is_not_same(mundo)
	almacen.get("_ciclo").abrir_la_jornada()
	assert_object(almacen.get("_agarre").manos().sostenido()).is_null()
	for indice in lugares.size():
		var caja: Node3D = cajas[indice]
		(
			assert_object(caja.get_parent())
			. override_failure_message("`%s` abrió la jornada colgada del jugador" % caja.name)
			. is_same(mundo)
		)
		(
			assert_vector(caja.global_position)
			. override_failure_message(
				(
					"`%s` abrió la jornada en %v y arrancó en %v"
					% [caja.name, caja.global_position, lugares[indice]]
				)
			)
			. is_equal_approx(lugares[indice], Vector3.ONE * 0.001)
		)
		# Vuelve también con su giro: la mano la cuelga derecha, y una caja de la fila del fondo
		# que volviera sin girar le mostraría al cuarto el costado de las flechas.
		(
			assert_bool(caja.global_basis.is_equal_approx(giros[indice]))
			. override_failure_message("`%s` abrió la jornada con otro giro" % caja.name)
			. is_true()
		)


## El clic izquierdo sobre la caja, que es lo que se la lleva a la mano.
func _agarrar(jugador: Node3D, caja: Node3D) -> void:
	jugador.set("_enfocado", caja)
	var evento := InputEventAction.new()
	evento.action = ReglasDeLosObjetos.ACCION_AGARRAR
	evento.pressed = true
	jugador.call("_unhandled_input", evento)
