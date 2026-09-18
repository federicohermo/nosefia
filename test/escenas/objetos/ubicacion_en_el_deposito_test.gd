## Dónde arranca la noche cada cosa suelta: las cajas de reposición en el depósito y las bolsas
## de basura en el baño.
##
## Las dos habitaciones las abre el 043, y antes de él no se podía poner nada adentro: la puerta
## las dejaba inalcanzables.
extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.tscn")

## Media caja, en metros. Es lo que separa el centro de una caja apoyada de la superficie que la
## sostiene, y sale del `0.3037077` de escala que el `.tscn` de la caja le pone a un cubo de dos.
const MEDIA_CAJA := 0.3037

## Justo adentro de la puerta del baño, del lado del cuarto.
##
## **De acá sale el criterio de «está en el baño», y la primera versión lo tenía mal.** Medía si
## la bolsa caía adentro de la caja del piso que declara `estructura_del_almacen.tscn`, y esa
## caja **abarca dos cuartos separados por una pared**: las tres bolsas daban verde tiradas en el
## de arriba, que está tapiado y al que no se entra por ningún lado. Una caja de colisión dice
## dónde hay piso, no dónde hay cuarto. Lo que sí lo dice es si se llega caminando, y es lo que
## este caso mide.
const ENTRADA_DEL_BANO := Vector3(8.8, 1.05, -4.658)

## A cuánto del inodoro tienen que quedar, en metros. Ancla el cuarto sin escribir sus paredes.
const CERCA_DEL_INODORO := 4.0

## Adonde se corre una caja para probar que la apertura la devuelve. Es el aire en el medio del
## local, lejos del depósito y de cualquier apoyo.
const LEJOS_DE_SU_LUGAR := Vector3(0.0, 2.0, 0.0)


func test_las_ocho_cajas_de_reposicion_estan_apoyadas_en_el_deposito() -> void:  # 043-AC10
	# Entran cuatro en los estantes y cuatro en el piso: entre estantes hay 0,477 m y la caja
	# mide 0,607, así que sólo el estante de arriba tiene aire. Lo que el caso afirma no es el reparto
	# sino que ninguna quede flotando ni clavada adentro de otra cosa.
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
		var hueco: float = cuerpo.global_position.y - (golpe["position"] as Vector3).y
		(
			assert_float(hueco)
			. override_failure_message(
				(
					"`%s` está a %.4f m de su apoyo y media caja es %.4f"
					% [caja.name, hueco, MEDIA_CAJA]
				)
			)
			. is_equal_approx(MEDIA_CAJA, 0.001)
		)
		var apoyo: String = str(almacen.get_path_to(golpe["collider"]))
		(
			assert_bool(apoyo.contains("gondola_deposito") or apoyo.contains("Suelo"))
			. override_failure_message("`%s` se apoya en `%s`" % [caja.name, apoyo])
			. is_true()
		)
		assert_array(_lo_que_pisa(almacen, cuerpo, apoyo)).is_empty()


func test_las_tres_bolsas_arrancan_en_el_bano_y_lejos_del_descarte() -> void:  # 043-AC11
	# El baño es el otro cuarto que el 043 abre. Las bolsas estaban desparramadas por el local y
	# el pedido fue juntarlas ahí; el descarte sigue en el fondo, así que el viaje no se acorta.
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	await get_tree().physics_frame
	var descarte: Node3D = almacen.get_node("Objetos/ZonaDeDescarte")
	var inodoro: Node3D = almacen.get_node("Estructura/inodoro")
	var bolsas: Array = almacen.get("_bolsas")
	assert_int(bolsas.size()).is_equal(ReglasDeLaBasura.BOLSAS_DE_LA_JORNADA)
	var sin_las_bolsas: Array[RID] = []
	for cuerpo: PhysicsBody3D in bolsas:
		sin_las_bolsas.append(cuerpo.get_rid())
	for bolsa: Node3D in bolsas:
		var lugar := bolsa.global_position
		(
			assert_float(lugar.distance_to(inodoro.global_position))
			. override_failure_message(
				"`%s` arranca en %v, lejos del inodoro" % [bolsa.name, lugar]
			)
			. is_less(CERCA_DEL_INODORO)
		)
		(
			assert_float(_camino_desde_la_puerta(almacen, lugar, sin_las_bolsas))
			. override_failure_message("`%s` no se alcanza desde la puerta del baño" % bolsa.name)
			. is_equal(1.0)
		)
		var distancia := lugar.distance_to(descarte.global_position)
		(
			assert_float(distancia)
			. override_failure_message("`%s` está a %.2f m del descarte" % [bolsa.name, distancia])
			. is_greater(ReglasDeLaBasura.DISTANCIA_MINIMA_AL_DESCARTE)
		)


## Qué fracción del camino recto entre la puerta del baño y un punto recorre el jugador.
##
## Las tres bolsas se excluyen para que no se tapen entre sí: se levantan de a una.
func _camino_desde_la_puerta(almacen: Node3D, hasta: Vector3, excluidas: Array[RID]) -> float:
	var forma := CapsuleShape3D.new()
	forma.radius = 0.4
	forma.height = 1.8
	var consulta := PhysicsShapeQueryParameters3D.new()
	consulta.shape = forma
	consulta.transform = Transform3D(Basis(), ENTRADA_DEL_BANO)
	consulta.exclude = excluidas
	var espacio := almacen.get_world_3d().direct_space_state
	assert_array(espacio.intersect_shape(consulta, 4)).is_empty()
	consulta.motion = Vector3(hasta.x, ENTRADA_DEL_BANO.y, hasta.z) - ENTRADA_DEL_BANO
	return espacio.cast_motion(consulta)[1]


## Con qué se superpone un cuerpo, sin contar aquello sobre lo que se apoya.
func _lo_que_pisa(almacen: Node3D, cuerpo: PhysicsBody3D, apoyo: String) -> Array[String]:
	var forma := BoxShape3D.new()
	forma.size = Vector3.ONE * (MEDIA_CAJA * 2.0 - 0.01)
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


func test_abrir_la_jornada_devuelve_cada_caja_a_su_lugar() -> void:  # 047-AC8
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
	for caja: Node3D in cajas:
		lugares.append(caja.global_position)
	var mundo: Node3D = cajas[0].get_parent()
	# Una movida a mano y otra en la mano: la noche termina tantas veces cargando una caja como
	# habiéndola dejado tirada, y las dos tienen que volver al depósito.
	for caja: Node3D in cajas:
		caja.global_position = LEJOS_DE_SU_LUGAR
	var jugador: Node3D = almacen.get("_jugador")
	var en_brazos: Node3D = cajas[Producto.Id.ARROZ]
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


## El clic izquierdo sobre la caja, que es lo que se la lleva a la mano.
func _agarrar(jugador: Node3D, caja: Node3D) -> void:
	jugador.set("_enfocado", caja)
	var evento := InputEventAction.new()
	evento.action = ReglasDeLosObjetos.ACCION_AGARRAR
	evento.pressed = true
	jugador.call("_unhandled_input", evento)
