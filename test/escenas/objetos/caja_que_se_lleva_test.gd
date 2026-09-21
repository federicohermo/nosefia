## Llevar la caja del depósito: qué la levanta, qué le saca una unidad y dónde queda al soltarla.
extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.tscn")

## El estante vacío del depósito: el único donde una caja entra sin apilarse sobre otra.
const ESTANTE_DEL_DEPOSITO := "Estructura/gondola_deposito01/StaticBody3D"

## La góndola del pasillo, que tiene paneles a los costados de cada estante. Es la forma difícil:
## el hueco entre dos paneles es de los pocos lugares donde la caja entra de canto.
const GONDOLA_DEL_PASILLO := "Estructura/gondolanueva/StaticBody3D"

## Media caja grande, en metros: lo que separa el centro de una caja apoyada de lo que la
## sostiene. **Hay dos tamaños**: los productos que entran en poco volumen llevan una chica, que
## es la única que cabe en las bandejas de abajo del depósito. Los casos de acá apilan y sueltan
## sólo las grandes, que es donde este número vale.
const MEDIA_CAJA := 0.3037

## Desde dónde se camina hacia la pared del depósito.
const RINCON_CERRADO := Vector2(10.4, -4.0)

## Cuadros de física caminando. A 60 Hz son cuatro segundos, de sobra para cruzar el depósito.
const CUADROS_CAMINANDO := 240

## Desde dónde se arranca a caminar hacia un estante, en metros de su frente.
const CARRERA_HASTA_EL_ESTANTE := 1.5

## Cuadros de física retrocediendo: pegado al estante no hay piso libre donde apoyar la caja.
const CUADROS_ATRAS := 20

## Cuánto puede separarse una esquina de su apoyo y seguir apoyada, en metros.
const HOLGURA_DEL_APOYO := 0.02

## Cuadros de física empujando. Arrastrando una caja se camina a un tercio de la velocidad.
const CUADROS_EMPUJANDO := 150

## Los dos gestos de soltar, en grados de la vista.
const MIRANDO_ARRIBA := 10.0
const MIRANDO_ABAJO := -40.0

## Los ángulos de la vista que se barren al contrastar dónde queda la caja, en grados. Cubren de
## la pared del fondo al piso a los pies, que es todo lo que el cursor puede señalar de pie.
const ANGULOS_DE_LA_VISTA: Array[float] = [
	20.0, 15.0, 10.0, 5.0, 0.0, -5.0, -10.0, -15.0, -20.0, -30.0, -45.0, -60.0
]

## Hasta qué distancia del eje del jugador cuenta como «al lado», en metros. El puesto la deja a
## su radio más media caja, que son 0,93; lo de más allá es un lugar que la mira eligió.
const AL_LADO_DEL_JUGADOR := 1.3

## Desde dónde se mira un charco para soltarle la caja encima, en metros de su centro.
const PARADO_DEL_CHARCO := 1.8

## Piso libre del depósito, lejos de los estantes: donde se arma una pila sin que estorbe nada.
const PISO_LIBRE_DEL_DEPOSITO := Vector3(4.49, 0.102, -10.0)

## Cuadros de física sin que nadie toque la pila. Una que se acomoda sola es peor que una que no
## se cae: el caso mide las dos cosas, y ésta primero.
const CUADROS_QUIETOS := 20

## Cuadros de física para que una caja sin apoyo caiga, aterrice y se vuelva a dormir. Cayendo
## una caja y media tarda menos de treinta; el resto es el margen del reposo.
const CUADROS_CAYENDO := 150

## De cuántos pisos es la pila que se arma. **Cinco y no tres, y ésa es la medición del caso.**
## Despertar un solo piso alcanza para dos —la de encima cae, y la siguiente se entera de
## refilón—, así que con tres pisos el caso pasaba en verde sin cascada. Con cinco, la cuarta se
## quedaba flotando a 0,93 m de cualquier apoyo con la quinta prolijamente encima.
const PISOS_DE_LA_PILA := 5

## Cuánto puede separarse del apoyo una caja que se cayó, en metros. Es más flojo que
## `HOLGURA_DEL_APOYO` porque una pila de cinco se acomoda con unos milímetros de deriva: medido,
## el hueco queda entre 0,294 y 0,303 contra los 0,3037 de media caja.
const HOLGURA_DE_LA_CAIDA := 0.02

## Hasta dónde se busca el apoyo de una caja, en metros. Alcanza para cruzar el local entero de
## arriba abajo, así que una que flota igual encuentra el piso y el mensaje dice a cuánto quedó.
const HASTA_EL_PISO := 4.0

## Cuánto puede quedar la base de la caja por debajo del punto apuntado, en metros.
##
## Sale de la caja y no de un ajuste: el puesto busca la tapa hasta **la altura de la caja** por
## debajo de lo apuntado, y arranca **media caja** más atrás sobre la línea de la vista, que
## mirando para arriba baja otro tanto. Son 0,607 + 0,526. Medido a 0,9 m del estante del
## depósito, el peor caso real da 0,78; el frente de la madera, que es lo que no debe pasar, da
## 1,46.
const CAIDA_DESDE_LO_APUNTADO := 1.14


## Las cajas del tamaño grande.
##
## **Se filtra por la escala y no por una lista de productos.** Cuál lleva cuál sale de medir la
## unidad en el modelo, así que una lista acá quedaría vieja el día que un envase cambie de
## tamaño, y el síntoma sería una pila de cajas desparejas que se acomoda sola.
func _las_grandes(cajas: Array) -> Array[Node3D]:
	var grandes: Array[Node3D] = []
	for caja: Node3D in cajas:
		if (caja.get_node("Cuerpo") as Node3D).scale.x >= MEDIA_CAJA:
			grandes.append(caja)
	return grandes


## Le pone el foco al objetivo y le manda la acción, que es lo que hace el clic de verdad.
func _accion(jugador: Node3D, objetivo: Node3D, accion: StringName) -> void:
	jugador.set("_enfocado", objetivo)
	var evento := InputEventAction.new()
	evento.action = accion
	evento.pressed = true
	jugador.call("_unhandled_input", evento)


func _almacen_con_jugador_quieto() -> Node3D:
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	await get_tree().physics_frame
	almacen.get("_jugador").set_physics_process(false)
	return almacen


func test_la_caja_entrega_apoyada_en_el_estante_y_no_mientras_se_la_lleva() -> void:
	# Apoyada entrega en cualquier superficie, y el estante del depósito es la más alta que hay.
	# En la mano no: llevarla es lo que cuesta, y sacarle una unidad pide apoyarla primero.
	var almacen: Node3D = await _almacen_con_jugador_quieto()
	var jugador: Node3D = almacen.get("_jugador")
	var agarre: Agarre = almacen.get("_agarre")
	var repositor: Repositor = almacen.get("_repositor")
	var producto := Catalogo.de(Producto.Id.ACTRONCITO)
	var caja: Node3D = almacen.get("_cajas_de_productos")[producto.id]
	var antes := repositor.estante().disponibles_para_retirar(producto)
	_accion(jugador, caja, ReglasDelJugador.ACCION_USAR)
	var unidad := agarre.manos().sostenido() as UnidadDeProducto
	assert_object(unidad).is_not_null()
	if unidad == null:
		return
	assert_int(unidad.producto.id).is_equal(producto.id)
	assert_int(repositor.estante().disponibles_para_retirar(producto)).is_equal(antes - 1)
	almacen.get("_reposicion_manual").pedir_colocar(producto.id)
	assert_object(agarre.manos().sostenido()).is_null()
	_accion(jugador, caja, ReglasDeLosObjetos.ACCION_AGARRAR)
	assert_object(caja.get_parent()).is_same(jugador.get_node("PuntoDeCaja"))
	var con_la_caja := repositor.estante().disponibles_para_retirar(producto)
	almacen.get("_reposicion_manual").retirar_de_la_caja(caja)
	assert_int(repositor.estante().disponibles_para_retirar(producto)).is_equal(con_la_caja)


func test_el_clic_izquierdo_levanta_la_caja_y_no_entrega_producto() -> void:
	var almacen: Node3D = await _almacen_con_jugador_quieto()
	var jugador: Node3D = almacen.get("_jugador")
	var agarre: Agarre = almacen.get("_agarre")
	var repositor: Repositor = almacen.get("_repositor")
	var producto := Catalogo.de(Producto.Id.LAYSNTT)
	var caja: Node3D = almacen.get("_cajas_de_productos")[producto.id]
	var antes := repositor.estante().disponibles_para_retirar(producto)
	_accion(jugador, caja, ReglasDeLosObjetos.ACCION_AGARRAR)
	assert_object(agarre.manos().sostenido()).is_same(caja.datos)
	assert_bool(agarre.manos().sostenido() is UnidadDeProducto).is_false()
	assert_int(repositor.estante().disponibles_para_retirar(producto)).is_equal(antes)
	assert_object(caja.get_parent()).is_same(jugador.get_node("PuntoDeCaja"))
	_accion(jugador, caja, ReglasDeLosObjetos.ACCION_AGARRAR)
	assert_object(agarre.manos().sostenido()).is_null()


func test_la_caja_llevada_no_tapa_la_mira_ni_atraviesa_la_pared() -> void:
	# **Camina de verdad contra la pared.** Teleportar al jugador contra ella probaría otra cosa:
	# lo que tiene que impedir que la caja entre en la madera es que el cuerpo no llegue, y eso
	# sólo se ejerce con `move_and_slide` corriendo.
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	await get_tree().physics_frame
	var jugador: CharacterBody3D = almacen.get("_jugador")
	var caja: Node3D = almacen.get("_cajas_de_productos")[Producto.Id.LAYSNTT]
	_accion(jugador, caja, ReglasDeLosObjetos.ACCION_AGARRAR)
	# De frente y no de costado: un producto se mira girado en la mano, una caja se lleva con
	# las dos manos y muestra su cara rotulada.
	(
		assert_float(caja.global_basis.x.dot(jugador.global_basis.z))
		. override_failure_message("la caja va de costado en la mano")
		. is_equal_approx(1.0, 0.001)
	)
	jugador.global_position = Vector3(RINCON_CERRADO.x, jugador.global_position.y, RINCON_CERRADO.y)
	Input.action_press(ReglasDelJugador.ACCION_ADELANTE)
	for cuadro in CUADROS_CAMINANDO:
		await get_tree().physics_frame
	Input.action_release(ReglasDelJugador.ACCION_ADELANTE)
	await get_tree().physics_frame
	(
		assert_bool(jugador.test_move(jugador.global_transform, -jugador.global_basis.z))
		. override_failure_message("el jugador no llegó a chocar: el caso no ejerce nada")
		. is_true()
	)
	_comprobar_la_mira_libre(jugador, caja, "contra la pared")
	_comprobar_que_no_atraviesa_nada(jugador, caja, "contra la pared")


func test_la_caja_soltada_queda_apoyada_en_el_piso_sin_caer() -> void:
	var almacen: Node3D = await _almacen_con_jugador_quieto()
	var jugador: Node3D = almacen.get("_jugador")
	var caja: Node3D = almacen.get("_cajas_de_productos")[Producto.Id.LAYSNTT]
	_accion(jugador, caja, ReglasDeLosObjetos.ACCION_AGARRAR)
	_accion(jugador, caja, ReglasDeLosObjetos.ACCION_AGARRAR)
	# Sin un solo cuadro de física de por medio: la caja no cae, se apoya.
	var consulta := PhysicsRayQueryParameters3D.create(
		caja.global_position, caja.global_position + Vector3.DOWN
	)
	consulta.exclude = [(caja as CollisionObject3D).get_rid()]
	var golpe := jugador.get_world_3d().direct_space_state.intersect_ray(consulta)
	assert_bool(golpe.has("position")).is_true()
	if not golpe.has("position"):
		return
	var hueco: float = caja.global_position.y - (golpe["position"] as Vector3).y
	(
		assert_float(hueco)
		. override_failure_message(
			"la caja quedó a %.4f m de su apoyo y media caja es %.4f" % [hueco, MEDIA_CAJA]
		)
		. is_equal_approx(MEDIA_CAJA, 0.001)
	)


## Que la caja llevada no se cruce delante de la mira.
func _comprobar_la_mira_libre(jugador: Node3D, caja: Node3D, donde: String) -> void:
	var camara: Camera3D = jugador.get_node("Camara")
	var limites := _limites_de(caja)
	(
		assert_bool(limites.intersects_ray(camara.global_position, -camara.global_basis.z) == null)
		. override_failure_message("%s, la caja se cruza delante de la mira" % donde)
		. is_true()
	)


## Que la caja no se meta adentro de nada. Se pregunta con la forma apenas encogida: apoyada en
## el piso el contacto es exacto, y a tamaño real eso contaría como atravesarlo.
func _comprobar_que_no_atraviesa_nada(jugador: Node3D, caja: Node3D, donde: String) -> void:
	var forma: CollisionShape3D = caja.get_node("Cuerpo")
	var apenas_menor := BoxShape3D.new()
	apenas_menor.size = (
		(forma.shape as BoxShape3D).size * forma.scale - Vector3.ONE * ReglasDeLosObjetos.ROCE
	)
	var consulta := PhysicsShapeQueryParameters3D.new()
	consulta.shape = apenas_menor
	consulta.transform = Transform3D(caja.global_basis, caja.global_position)
	# Por la máscara de la caja y no por todas las capas: en la 2 están la mancha del piso y el
	# casillero de la góndola, que existen para la mira y no son cosas que se atraviesen. Una
	# caja apoyada sobre una mancha queda adentro de su cilindro de 6 cm y no atraviesa nada.
	consulta.collision_mask = (caja as CollisionObject3D).collision_mask
	consulta.exclude = [jugador.get_rid(), (caja as CollisionObject3D).get_rid()]
	var pisados: Array[String] = []
	for choque in jugador.get_world_3d().direct_space_state.intersect_shape(consulta, 4):
		pisados.append(str(jugador.get_parent().get_path_to(choque["collider"])))
	(
		assert_array(pisados)
		. override_failure_message("%s, la caja atraviesa %s" % [donde, ", ".join(pisados)])
		. is_empty()
	)


## Lo que ocupa un cuerpo, en coordenadas del mundo.
func _limites_de(cuerpo: Node3D) -> AABB:
	var limites := AABB(cuerpo.global_position, Vector3.ZERO)
	for forma: CollisionShape3D in cuerpo.find_children("*", "CollisionShape3D", true, false):
		limites = limites.merge(forma.global_transform * forma.shape.get_debug_mesh().get_aabb())
	return limites


## Gira la vista como lo haría el mouse, a un yaw y un pitch absolutos en radianes.
func _mirar(jugador: Node3D, giro: float, alto: float) -> void:
	var camara: Camera3D = jugador.get_node("Camara")
	var evento := InputEventMouseMotion.new()
	evento.relative = (
		Vector2(jugador.rotation.y - giro, camara.rotation.x - alto)
		/ ReglasDelJugador.SENSIBILIDAD_DEL_MOUSE
	)
	jugador.call("_unhandled_input", evento)


## Pone la mira sobre la tapa de un cuerpo.
func _apuntar_a(jugador: Node3D, objetivo: Node3D) -> void:
	var camara: Camera3D = jugador.get_node("Camara")
	var blanco := _limites_de(objetivo)
	var hacia := (
		Vector3(blanco.get_center().x, blanco.end.y, blanco.get_center().z) - camara.global_position
	)
	_mirar(jugador, atan2(-hacia.x, -hacia.z), atan2(hacia.y, Vector2(hacia.x, hacia.z).length()))


## Camina —caminando, no teleportando— hasta chocar contra la cara de `limites` que mira al
## jugador. Teleportar probaría otra cosa: lo que decide dónde frena es `move_and_slide`.
func _caminar_hasta(almacen: Node3D, limites: AABB, direccion: Vector3) -> void:
	var jugador: CharacterBody3D = almacen.get("_jugador")
	var fondo: float = (limites.size * direccion.abs()).length() / 2.0
	var arranque := limites.get_center() - direccion * (fondo + CARRERA_HASTA_EL_ESTANTE)
	jugador.global_position = Vector3(arranque.x, jugador.global_position.y, arranque.z)
	_mirar(jugador, atan2(-direccion.x, -direccion.z), 0.0)
	Input.action_press(ReglasDelJugador.ACCION_ADELANTE)
	for cuadro in CUADROS_CAMINANDO:
		await get_tree().physics_frame
	Input.action_release(ReglasDelJugador.ACCION_ADELANTE)
	await get_tree().physics_frame


## Sobre qué cuerpo quedó apoyada la caja.
func _apoyo_de(almacen: Node3D, caja: Node3D) -> Node3D:
	var consulta := PhysicsRayQueryParameters3D.create(
		caja.global_position, caja.global_position + Vector3.DOWN * 3.0
	)
	consulta.exclude = [(caja as CollisionObject3D).get_rid()]
	var golpe := almacen.get_world_3d().direct_space_state.intersect_ray(consulta)
	return golpe.get("collider")


func test_la_caja_soltada_se_acomoda_adentro_de_su_apoyo() -> void:
	# Mirando la tapa de otra caja queda centrada sobre ella, que es el caso donde el apoyo mide
	# lo mismo que la caja y las dos cuentas del margen se cruzan.
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	await get_tree().physics_frame
	var jugador: CharacterBody3D = almacen.get("_jugador")
	var caja: Node3D = almacen.get("_cajas_de_productos")[Producto.Id.LAYSNTT]
	# **Las dos son del tamaño grande.** El caso mide que una caja quede centrada en la tapa de
	# otra, y una grande sobre una chica cuelga de las cuatro esquinas: lo que se pondría en rojo
	# sería el enunciado, no el puesto.
	var debajo: Node3D = almacen.get("_cajas_de_productos")[Producto.Id.SALADIK]
	_accion(jugador, caja, ReglasDeLosObjetos.ACCION_AGARRAR)
	# Las cajas del piso están contra la pared: se llega a ellas desde el pasillo, o sea -x.
	await _caminar_hasta(almacen, _limites_de(debajo), Vector3.LEFT)
	_apuntar_a(jugador, debajo)
	_accion(jugador, caja, ReglasDeLosObjetos.ACCION_AGARRAR)
	assert_float(caja.global_position.x).is_equal_approx(debajo.global_position.x, 0.005)
	assert_float(caja.global_position.z).is_equal_approx(debajo.global_position.z, 0.005)
	(
		assert_float(caja.global_position.y)
		. override_failure_message("la caja no quedó arriba de la otra")
		. is_greater(debajo.global_position.y)
	)
	_comprobar_apoyo_entero(almacen, caja, "sobre otra caja")


func test_la_caja_vuelta_a_su_lugar_apoya_entera() -> void:
	# El caso de arriba mide un apoyo del tamaño de la caja; éste mide los apoyos de verdad de
	# todas las cajas del catálogo, que son el estante del depósito y el suelo.
	var almacen: Node3D = await _almacen_con_jugador_quieto()
	var cajas: Array = almacen.get("_cajas_de_productos")
	assert_int(cajas.size()).is_equal(Catalogo.todos().size())
	for caja: Node3D in cajas:
		_comprobar_apoyo_entero(almacen, caja, caja.name)


## Que la caja tenga algo justo debajo, a media caja de su centro.
##
## Es lo que se le pide a una que **cayó**, y no las cuatro esquinas calzadas: una pila que se
## desarma se acomoda con unos milímetros de deriva lateral, así que exigir el calce perfecto
## sería exigirle al motor lo que no da. Lo que importa acá es que no haya quedado en el aire.
func _comprobar_que_no_flota(almacen: Node3D, caja: Node3D, donde: String) -> void:
	var consulta := PhysicsRayQueryParameters3D.create(
		caja.global_position, caja.global_position + Vector3.DOWN * HASTA_EL_PISO
	)
	consulta.exclude = [(caja as CollisionObject3D).get_rid()]
	var golpe := almacen.get_world_3d().direct_space_state.intersect_ray(consulta)
	(
		assert_bool(golpe.has("position"))
		. override_failure_message("%s: `%s` no tiene nada debajo" % [donde, caja.name])
		. is_true()
	)
	if not golpe.has("position"):
		return
	var hueco: float = caja.global_position.y - (golpe["position"] as Vector3).y
	(
		assert_float(hueco)
		. override_failure_message(
			(
				"%s: `%s` quedó a %.3f m de lo que tiene debajo, y media caja es %.3f"
				% [donde, caja.name, hueco, MEDIA_CAJA]
			)
		)
		. is_equal_approx(MEDIA_CAJA, HOLGURA_DE_LA_CAIDA)
	)


## Que las cuatro esquinas de la caja tengan apoyo: ni flotando ni con media caja afuera.
func _comprobar_apoyo_entero(almacen: Node3D, caja: Node3D, donde: String) -> void:
	var forma: CollisionShape3D = caja.get_node("Cuerpo")
	var media: Vector3 = (forma.shape as BoxShape3D).size * forma.scale / 2.0
	var espacio := almacen.get_world_3d().direct_space_state
	var sueltas: Array[String] = []
	for dx: float in [-media.x, media.x]:
		for dz: float in [-media.z, media.z]:
			var esquina := caja.global_position + Vector3(dx * 0.98, -media.y, dz * 0.98)
			var consulta := PhysicsRayQueryParameters3D.create(
				esquina + Vector3.UP * HOLGURA_DEL_APOYO, esquina + Vector3.DOWN * HOLGURA_DEL_APOYO
			)
			consulta.exclude = [(caja as CollisionObject3D).get_rid()]
			if espacio.intersect_ray(consulta).is_empty():
				sueltas.append("%+.2f %+.2f" % [dx, dz])
	(
		assert_array(sueltas)
		. override_failure_message(
			(
				"%s: la caja en %v tiene esquinas en el aire: %s"
				% [donde, caja.global_position, ", ".join(sueltas)]
			)
		)
		. is_empty()
	)


func test_la_caja_va_donde_apunta_la_mira() -> void:
	# **El lugar lo decide el cursor y no el gesto de la vista.** Antes no: contra la pared del
	# fondo del depósito, la mira a +20, +10 y 0 grados daba tres puntos distintos y la caja caía
	# siempre en el mismo estante, porque lo que la ubicaba era un rayo hacia abajo desde lo
	# apuntado y no lo apuntado. Mirar más arriba o más abajo movía el resultado; apuntar, no.
	#
	# Por eso el caso no fija un ángulo y su resultado: barre diez y contrasta cada uno contra lo
	# que la mira toca. Desde dos lugares, que es lo que trae las dos clases de apoyo: pegado al
	# estante la mira llega a la madera, y un paso atrás ya no, así que el apoyo es el piso.
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	await get_tree().physics_frame
	var jugador: CharacterBody3D = almacen.get("_jugador")
	var estante: Node3D = almacen.get_node(ESTANTE_DEL_DEPOSITO)
	var caja: Node3D = almacen.get("_cajas_de_productos")[Producto.Id.LAYSNTT]
	_accion(jugador, caja, ReglasDeLosObjetos.ACCION_AGARRAR)
	await _caminar_hasta(almacen, _limites_de(estante), Vector3.FORWARD)
	var contadas := _contrastar_la_mira(almacen, caja, "pegado al estante")
	# Pegado al estante no hay piso libre donde dejarla: entre el cuerpo y la madera no entra
	# una caja. Se retrocede un paso, que es lo que haría cualquiera.
	Input.action_press(ReglasDelJugador.ACCION_ATRAS)
	for cuadro in CUADROS_ATRAS:
		await get_tree().physics_frame
	Input.action_release(ReglasDelJugador.ACCION_ATRAS)
	await get_tree().physics_frame
	var atras := _contrastar_la_mira(almacen, caja, "un paso atrás")
	(
		assert_int(contadas[0] + atras[0])
		. override_failure_message("ningún ángulo apoyó la caja sobre lo apuntado: no ejerce nada")
		. is_greater(1)
	)
	(
		assert_int(contadas[1] + atras[1])
		. override_failure_message("ningún ángulo cayó al lado del jugador: no ejerce el respaldo")
		. is_greater(0)
	)


## Suelta la caja en cada ángulo de la vista y la contrasta contra lo que la mira toca.
##
## Devuelve los dos conteos —las que fueron a lo apuntado y las que cayeron al lado del jugador—,
## para que el caso no pueda pasar en verde sin haber ejercido ninguna de las dos mitades de la
## regla. La mira sobre el aire no entra en la primera: ahí no señala una superficie equivocada,
## no señala ninguna, y la caja va al piso que haya debajo del cursor.
func _contrastar_la_mira(almacen: Node3D, caja: Node3D, donde: String) -> Array[int]:
	var jugador: CharacterBody3D = almacen.get("_jugador")
	var mano: Node3D = jugador.get_node("PuntoDeCaja")
	var contrastadas := 0
	var al_lado := 0
	for alto: float in ANGULOS_DE_LA_VISTA:
		if caja.get_parent() != mano:
			_accion(jugador, caja, ReglasDeLosObjetos.ACCION_AGARRAR)
		_mirar(jugador, jugador.rotation.y, deg_to_rad(alto))
		var apuntado := _lo_apuntado(almacen, jugador, caja)
		_accion(jugador, caja, ReglasDeLosObjetos.ACCION_AGARRAR)
		# Quedarse en la mano es el último recurso: sólo si tampoco hay lugar al lado.
		if caja.get_parent() == mano:
			continue
		var gesto := "%s, mirando %.0f grados" % [donde, alto]
		# Apoya en sus cuatro esquinas vaya donde vaya: el respaldo no es una excepción a eso.
		_comprobar_apoyo_entero(almacen, caja, gesto)
		var plano := Vector2(
			caja.global_position.x - jugador.global_position.x,
			caja.global_position.z - jugador.global_position.z
		)
		if plano.length() <= AL_LADO_DEL_JUGADOR:
			# La mira no señalaba un lugar donde entrara, así que se la dejó al lado. Soltar
			# suelta: lo que no puede pasar es que el clic no haga nada.
			al_lado += 1
			continue
		if apuntado.is_empty():
			continue
		# **No se exige que la caja quede sobre el cuerpo que la mira tocó, y es a propósito.** El
		# hueco de un estante es aire: el rayo lo cruza y pega en el panel del fondo, así que
		# apuntar al medio del estante da el panel, y la caja va a la tapa que ese hueco tiene
		# abajo, que es lo que el jugador estaba mirando. Lo que sí se exige es que esa tapa esté
		# ahí nomás: lo que no puede pasar es que la caja termine un estante más abajo.
		contrastadas += 1
		var base := caja.global_position.y - MEDIA_CAJA
		var mirado: float = (apuntado["position"] as Vector3).y
		(
			assert_float(base)
			. override_failure_message(
				(
					"%s la caja apoya a %.3f y la mira daba a %.3f, %.3f m más arriba"
					% [gesto, base, mirado, mirado - base]
				)
			)
			. is_between(mirado - CAIDA_DESDE_LO_APUNTADO, mirado + HOLGURA_DEL_APOYO)
		)
	return [contrastadas, al_lado]


## Qué toca la mira del jugador, con las mismas exclusiones que usa el puesto para ubicarla.
func _lo_apuntado(almacen: Node3D, jugador: Node3D, caja: Node3D) -> Dictionary:
	var ojo: Transform3D = jugador.call("mira")
	var consulta := PhysicsRayQueryParameters3D.create(
		ojo.origin, ojo.origin - ojo.basis.z * ReglasDelJugador.ALCANCE_DE_LA_MIRA
	)
	consulta.exclude = [
		(caja as CollisionObject3D).get_rid(), (jugador as CollisionObject3D).get_rid()
	]
	return almacen.get_world_3d().direct_space_state.intersect_ray(consulta)


func test_la_caja_soltada_nunca_queda_adentro_de_nada() -> void:
	# El barrido que antes fallaba: parado de costado al estante, la caja terminaba metida en la
	# madera. Se prueban las dos vueltas y los cuatro ángulos, no sólo el tiro de frente.
	# Las que no encuentran lugar no se sueltan, y eso también es correcto.
	#
	# **Se mide un paso atrás del estante, y no pegado a él.** Pegado no entra en ningún lado:
	# los estantes tienen 0,477 m de aire y la caja mide 0,607, y el piso que la mira alcanza cae
	# debajo de la madera. Ahí las doce se quedan en la mano —correcto, pero no ejerce nada—.
	#
	# **Y se mide contra las dos góndolas, no contra una.** La del depósito está vacía y la del
	# pasillo tiene paneles a los costados de cada estante: ahí la caja entraba de canto entre
	# dos y el barrido decía que había llegado, porque `cast_motion` contesta que el movimiento
	# entero es seguro cuando la forma arranca ya tocando algo. De 256 soltadas alrededor de esa
	# góndola, 20 quedaban adentro de ella.
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	await get_tree().physics_frame
	var soltadas := 0
	for ruta_del_mueble: String in [ESTANTE_DEL_DEPOSITO, GONDOLA_DEL_PASILLO]:
		soltadas += await _soltar_en_los_doce_gestos(almacen, almacen.get_node(ruta_del_mueble))
	(
		assert_int(soltadas)
		. override_failure_message("casi ninguna se soltó: el caso no ejerce nada")
		. is_greater(6)
	)


## Camina hasta el mueble, retrocede un paso y suelta la caja en las doce vueltas y ángulos.
##
## Devuelve cuántas se soltaron de verdad, para que el caso no pueda pasar sin ejercer nada.
func _soltar_en_los_doce_gestos(almacen: Node3D, mueble: Node3D) -> int:
	var jugador: CharacterBody3D = almacen.get("_jugador")
	var caja: Node3D = almacen.get("_cajas_de_productos")[Producto.Id.LAYSNTT]
	var mano: Node3D = jugador.get_node("PuntoDeCaja")
	if caja.get_parent() != mano:
		_accion(jugador, caja, ReglasDeLosObjetos.ACCION_AGARRAR)
	await _caminar_hasta(almacen, _limites_de(mueble), Vector3.FORWARD)
	assert_object(caja.get_parent()).is_same(mano)
	Input.action_press(ReglasDelJugador.ACCION_ATRAS)
	for cuadro in CUADROS_ATRAS:
		await get_tree().physics_frame
	Input.action_release(ReglasDelJugador.ACCION_ATRAS)
	await get_tree().physics_frame
	var derecho := jugador.rotation.y
	var soltadas := 0
	for giro: float in [-20.0, 0.0, 20.0]:
		for alto: float in [MIRANDO_ABAJO, 0.0, MIRANDO_ARRIBA, 30.0]:
			if caja.get_parent() != mano:
				_accion(jugador, caja, ReglasDeLosObjetos.ACCION_AGARRAR)
			_mirar(jugador, derecho + deg_to_rad(giro), deg_to_rad(alto))
			_accion(jugador, caja, ReglasDeLosObjetos.ACCION_AGARRAR)
			# Quedarse en la mano es el último recurso: cuando la mira no encuentra lugar la
			# caja va al piso al lado del jugador, y ahí tampoco puede quedar adentro de nada.
			if caja.get_parent() == mano:
				continue
			soltadas += 1
			_comprobar_que_no_atraviesa_nada(
				jugador, caja, "en `%s`, girado %.0f y mirando %.0f" % [mueble.name, giro, alto]
			)
	return soltadas


func test_la_caja_se_suelta_con_la_mira_sobre_un_charco() -> void:
	# **Lo enfocado no es la caja, y eso es lo que este caso agrega.** Los demás le escriben
	# `_enfocado` a mano y le apuntan a la caja, así que ninguno podía ver esto: llevando una
	# caja y con la mira sobre una mancha, el clic no hacía nada. La mancha está en el grupo
	# `interactuable` y tenía `interactuar()`, y `jugador.gd` le daba el clic entero a cualquier
	# cosa enfocada que contestara `null` —que para una mancha es siempre—.
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	await get_tree().physics_frame
	almacen.get("_ciclo").abrir_la_jornada()
	await get_tree().physics_frame
	var jugador: CharacterBody3D = almacen.get("_jugador")
	var caja: Node3D = almacen.get("_cajas_de_productos")[Producto.Id.LAYSNTT]
	var mano: Node3D = jugador.get_node("PuntoDeCaja")
	var manchas: Array = almacen.get("_limpieza").call("manchas")
	assert_array(manchas).is_not_empty()
	var sueltas := 0
	for mancha: Node3D in manchas:
		if not mancha.visible:
			continue
		if caja.get_parent() != mano:
			_accion(jugador, caja, ReglasDeLosObjetos.ACCION_AGARRAR)
		var desde := jugador.global_position - mancha.global_position
		desde.y = 0.0
		jugador.global_position = (
			mancha.global_position + desde.normalized() * PARADO_DEL_CHARCO + Vector3.UP * 0.112
		)
		await get_tree().physics_frame
		_apuntar_a(jugador, mancha)
		# El clic con el foco que el juego calcula solo, que acá es la mancha y no la caja.
		_accion(jugador, mancha, ReglasDeLosObjetos.ACCION_AGARRAR)
		(
			assert_object(caja.get_parent())
			. override_failure_message(
				"con la mira sobre `%s` el clic no soltó la caja" % mancha.name
			)
			. is_not_same(mano)
		)
		sueltas += 1
		_comprobar_apoyo_entero(almacen, caja, "con la mira sobre `%s`" % mancha.name)
		_comprobar_que_no_atraviesa_nada(jugador, caja, "con la mira sobre `%s`" % mancha.name)
	(
		assert_int(sueltas)
		. override_failure_message("ninguna mancha estaba sucia: el caso no ejerce nada")
		. is_greater(0)
	)


func test_sacar_una_caja_de_la_pila_hace_caer_las_de_arriba() -> void:
	# **Las cajas apiladas se sostienen entre sí.** El cuerpo es rígido y arranca congelado, así
	# que apoyada se porta como algo estático; pierde el apoyo y cae. Se miden las dos mitades,
	# y la primera importa tanto como la segunda: una pila que se acomoda sola apenas carga la
	# escena sería peor que una que no se desarma nunca.
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	await get_tree().physics_frame
	var jugador: CharacterBody3D = almacen.get("_jugador")
	var grandes := _las_grandes(almacen.get("_cajas_de_productos"))
	assert_int(grandes.size()).is_greater_equal(PISOS_DE_LA_PILA)
	var pila: Array[Node3D] = []
	for piso in PISOS_DE_LA_PILA:
		pila.append(grandes[piso])
	for piso in pila.size():
		pila[piso].global_position = (
			PISO_LIBRE_DEL_DEPOSITO + Vector3.UP * MEDIA_CAJA * (1 + 2 * piso)
		)
		pila[piso].call("quedarse_quieta")
	jugador.global_position = PISO_LIBRE_DEL_DEPOSITO + Vector3(0.0, 0.01, 1.2)
	await get_tree().physics_frame
	var armada: Array[float] = []
	for caja in pila:
		armada.append(caja.global_position.y)
	for cuadro in CUADROS_QUIETOS:
		await get_tree().physics_frame
	for piso in pila.size():
		(
			assert_float(pila[piso].global_position.y)
			. override_failure_message(
				(
					"`%s` se movió sola: arrancó en %.3f y quedó en %.3f"
					% [pila[piso].name, armada[piso], pila[piso].global_position.y]
				)
			)
			. is_equal_approx(armada[piso], HOLGURA_DEL_APOYO)
		)
	# Se lleva la de abajo, que es lo que deja a las otras dos en el aire.
	_accion(jugador, pila[0], ReglasDeLosObjetos.ACCION_AGARRAR)
	for cuadro in CUADROS_CAYENDO:
		await get_tree().physics_frame
	for piso in range(1, PISOS_DE_LA_PILA):
		(
			assert_float(pila[piso].global_position.y)
			. override_failure_message(
				(
					"`%s`, el piso %d, quedó flotando a %.3f, donde la dejó la que ya no está"
					% [pila[piso].name, piso, pila[piso].global_position.y]
				)
			)
			. is_less(armada[piso] - MEDIA_CAJA)
		)
		_comprobar_que_no_flota(almacen, pila[piso], "después de sacarle la de abajo")
	# Y ahora una del medio de lo que quedó: las de arriba se quedan sin apoyo igual.
	var antes_de_la_ultima: float = pila[PISOS_DE_LA_PILA - 1].global_position.y
	# El mismo clic suelta o agarra, así que primero hay que dejar la que se lleva —y mirando
	# para el otro lado, o cae sobre la pila que este tramo quiere mover—.
	_mirar(jugador, PI, deg_to_rad(MIRANDO_ABAJO))
	_accion(jugador, pila[0], ReglasDeLosObjetos.ACCION_AGARRAR)
	await get_tree().physics_frame
	_accion(jugador, pila[1], ReglasDeLosObjetos.ACCION_AGARRAR)
	assert_object(pila[1].get_parent()).is_same(jugador.get_node("PuntoDeCaja"))
	for cuadro in CUADROS_CAYENDO:
		await get_tree().physics_frame
	var ultima: Node3D = pila[PISOS_DE_LA_PILA - 1]
	(
		assert_float(ultima.global_position.y)
		. override_failure_message(
			(
				"`%s`, la de más arriba, quedó flotando a %.3f al sacarle una de abajo"
				% [ultima.name, ultima.global_position.y]
			)
		)
		. is_less(antes_de_la_ultima - MEDIA_CAJA)
	)
	_comprobar_que_no_flota(almacen, ultima, "después de sacarle la del medio")


func test_agarrar_la_caja_del_estante_no_mueve_al_jugador() -> void:
	# La caja llevada entra donde entra el cuerpo, así que darle su volumen no puede empujar a
	# nadie. Antes nacía 0,8 m adelante: agarrando de cerca el jugador se subía al estante.
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	await get_tree().physics_frame
	var jugador: CharacterBody3D = almacen.get("_jugador")
	var caja: Node3D = almacen.get("_cajas_de_productos")[Producto.Id.ACTRONCITO]
	# Desde adentro del depósito: el estante de esta caja está contra la pared del oeste. Llegando
	# por el otro lado el jugador arranca afuera del edificio, donde no hay piso.
	await _caminar_hasta(almacen, _limites_de(caja), Vector3.LEFT)
	var antes := jugador.global_position
	_accion(jugador, caja, ReglasDeLosObjetos.ACCION_AGARRAR)
	await get_tree().physics_frame
	assert_object(caja.get_parent()).is_same(jugador.get_node("PuntoDeCaja"))
	(
		assert_float(jugador.global_position.distance_to(antes))
		. override_failure_message(
			"agarrar la caja movió al jugador de %v a %v" % [antes, jugador.global_position]
		)
		. is_less(0.001)
	)


func test_la_caja_del_piso_se_arrastra_en_vez_de_tapar_el_paso() -> void:
	# Una caja olvidada en un pasillo no puede ser una pared. Se corre de un empujón, y sin
	# tumbarse ni levantarse del piso: se arrastra.
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	await get_tree().physics_frame
	var jugador: CharacterBody3D = almacen.get("_jugador")
	# **Se empuja en el piso libre del depósito y no delante de donde el jugador aparece.** Ahí
	# arranca pegado a la góndola del pasillo, así que el empujón termina contra el mueble y lo
	# que se mediría sería el choque y no el arrastre.
	var caja: Node3D = almacen.get("_cajas_de_productos")[Producto.Id.CHISITOS]
	jugador.global_position = PISO_LIBRE_DEL_DEPOSITO + Vector3(0.0, 0.01, 1.2)
	jugador.rotation.y = 0.0
	await get_tree().physics_frame
	var adelante := -jugador.global_basis.z
	caja.global_position = (
		PISO_LIBRE_DEL_DEPOSITO + Vector3.UP * (caja.global_position.y - PISO_LIBRE_DEL_DEPOSITO.y)
	)
	var partida := caja.global_position
	var giro := caja.global_basis
	Input.action_press(ReglasDelJugador.ACCION_ADELANTE)
	for cuadro in CUADROS_EMPUJANDO:
		await get_tree().physics_frame
	Input.action_release(ReglasDelJugador.ACCION_ADELANTE)
	await get_tree().physics_frame
	var corrida := (caja.global_position - partida).dot(adelante)
	(
		assert_float(corrida)
		. override_failure_message(
			"la caja no se movió: de %v a %v" % [partida, caja.global_position]
		)
		. is_greater(0.3)
	)
	(
		assert_float(caja.global_position.y)
		. override_failure_message("la caja se levantó o se hundió al empujarla")
		. is_equal_approx(partida.y, 0.001)
	)
	(
		assert_bool(caja.global_basis.is_equal_approx(giro))
		. override_failure_message("la caja se tumbó al empujarla")
		. is_true()
	)
	(
		assert_float((jugador.global_position - partida).dot(adelante))
		. override_failure_message("el jugador no pasó de donde estaba la caja")
		. is_greater(0.0)
	)
	_comprobar_que_no_atraviesa_nada(jugador, caja, "empujada")
