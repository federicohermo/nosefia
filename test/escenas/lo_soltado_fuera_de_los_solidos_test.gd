## Lo que se suelta o se empuja no queda adentro de un sólido fijo.
##
## **«Adentro» se mide contra la malla visible, no contra la colisión.** La colisión de un mueble
## es justo lo que se arregla: medir contra ella daría verde sin mirar nada el día que sus caras
## dejen de contestar.
extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.tscn")

const MOSTRADOR := "Estructura/EscritorioComputadora"

## Cuánto se meten hacia adentro los puntos del volumen del objeto antes de preguntar, en metros.
## Apoyado, un objeto toca la cara: sin descontar nada, el contacto exacto contaría como adentro.
const EPSILON := 0.001

## Hacia dónde se tiran los rayos del oráculo. Levemente torcidos, para que ninguno pase justo
## por una arista, donde el cruce se cuenta dos veces o ninguna.
const DIRECCIONES: Array[Vector3] = [
	Vector3(1.0, 0.0013, 0.0007),
	Vector3(-1.0, 0.0011, -0.0017),
	Vector3(0.0019, 1.0, 0.0003),
	Vector3(-0.0007, -1.0, 0.0023),
	Vector3(0.0005, -0.0021, 1.0),
	Vector3(-0.0017, 0.0009, -1.0),
]

## Cuánto se mete la caja grande en el mostrador para quedar entera adentro, en metros: su lado,
## más un centímetro. El brazo del mostrador mide 0,9 de fondo.
const CAJA_ENTERA := 0.62

## Desde dónde arranca el jugador, en metros del frente del mueble.
const CARRERA := 1.5

## Cuadros de física caminando contra la caja. A 60 Hz son cuatro segundos.
const CUADROS_CAMINANDO := 240

## Cuadros de física que el jugador sigue caminando después de quedar bloqueado contra la caja.
##
## **Ningún N reproducía el síntoma.** Medido el 2026-09-26 con la escena de ese día, de 60 a 1200
## pasos: la caja pegada no entraba. Queda como regresión, y la prueba del error es el caso de la
## caja a medias.
const PASOS_DESPUES_DE_BLOQUEARSE := 60

## Hasta cuántos cuadros se espera a que el jugador quede bloqueado.
const CUADROS_HASTA_BLOQUEARSE := 600

## Cuánto tiene que avanzar el jugador en un cuadro para no contar como bloqueado, en metros.
const AVANCE_MINIMO := 0.0001

## Media caja grande, en metros. Las cajas chicas no se usan acá.
const MEDIA_CAJA := 0.3037

## Los cuatro giros de la mira al soltar, en grados, y los tres del cuerpo.
##
## **El gemelo de estos gestos está en `caja_que_se_lleva_test.gd`.** Si uno cambia sus ángulos
## y el otro no, las dos suites dejan de medir lo mismo.
const ALTOS_DE_LA_MIRA: Array[float] = [-40.0, 0.0, 10.0, 30.0]
const GIROS_DEL_CUERPO: Array[float] = [-20.0, 0.0, 20.0]

## A cuántos metros de la cara del sólido se para el jugador para soltar. Con la caja en la mano
## no llega tan cerca: la caja ocupa lugar delante del cuerpo.
const PARADO_DEL_SOLIDO := 1.0
const PARADO_CON_LA_CAJA := 1.4

## Cuadros de física para que lo soltado caiga y se duerma. Cae desde la mano en menos de medio
## segundo; el resto es el margen del reposo.
const CUADROS_DE_REPOSO := 90

## A qué distancias de lo soltado se busca un lugar libre para mirarlo, en metros.
const RADIOS_DEL_LUGAR_LIBRE: Array[float] = [0.9, 1.3, 1.7, 2.1]
const LADOS_DEL_LUGAR_LIBRE := 12

## El producto que se suelta: uno cualquiera con unidades en la góndola.
const PRODUCTO_QUE_SE_SUELTA := Producto.Id.MALBARDO

## Cuánto deja el motor que un cuerpo apoyado se hunda en lo que lo sostiene.
const PENETRACION_TOLERADA := "physics/jolt_physics_3d/simulation/penetration_slop"

## Los sólidos de la matriz.
const CARA_DE_AFUERA_DEL_MOSTRADOR := "afuera del mostrador"
const CARA_DE_ADENTRO_DE_LA_L := "adentro de la L"
const PARED_DE_LA_FACHADA := "la pared de la fachada"
const GONDOLA_DEL_DEPOSITO := "la góndola del depósito"

## Un tramo libre de la pared de la fachada, lejos de la ventanilla y de las góndolas.
const PARED_LIBRE := Vector2(-3.0, 7.871)


func _almacen() -> Node3D:
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	await get_tree().physics_frame
	return almacen


## Las caras de la malla visible, en coordenadas del mundo.
static func _caras_de(malla: MeshInstance3D) -> PackedVector3Array:
	var caras := malla.mesh.get_faces()
	var transformada := malla.global_transform
	for indice in caras.size():
		caras[indice] = transformada * caras[indice]
	return caras


## Cuántas aristas no comparten exactamente dos caras. Con cero la malla está cerrada y soldada.
static func _aristas_sueltas(caras: PackedVector3Array) -> int:
	var usos := {}
	for indice in range(0, caras.size(), 3):
		for lado in 3:
			var desde := Vector3i((caras[indice + lado] * 10000.0).round())
			var hasta := Vector3i((caras[indice + (lado + 1) % 3] * 10000.0).round())
			var arista := [desde, hasta] if str(desde) < str(hasta) else [hasta, desde]
			usos[arista] = usos.get(arista, 0) + 1
	var sueltas := 0
	for arista: Array in usos:
		if usos[arista] != 2:
			sueltas += 1
	return sueltas


## Si el punto está adentro de la malla: la primera cara que cruza algún rayo la ve de espaldas.
##
## En este motor `(b - a) × (c - a)` apunta hacia adentro de una malla importada.
static func _punto_adentro(caras: PackedVector3Array, punto: Vector3) -> bool:
	for direccion in DIRECCIONES:
		var mas_cerca := INF
		var de_espaldas := false
		for indice in range(0, caras.size(), 3):
			var a := caras[indice]
			var b := caras[indice + 1]
			var c := caras[indice + 2]
			var cruce: Variant = Geometry3D.ray_intersects_triangle(punto, direccion, a, b, c)
			if cruce == null:
				continue
			var distancia := punto.distance_to(cruce)
			if distancia < mas_cerca:
				mas_cerca = distancia
				de_espaldas = (b - a).cross(c - a).dot(direccion) < 0.0
		if de_espaldas:
			return true
	return false


## Los puntos del volumen del objeto: las esquinas de cada forma, metidas `EPSILON` hacia su centro.
static func _puntos_del_volumen(objeto: Node3D) -> PackedVector3Array:
	var puntos := PackedVector3Array()
	for forma: CollisionShape3D in objeto.find_children("*", "CollisionShape3D", true, false):
		var malla := forma.shape.get_debug_mesh()
		var centro := forma.global_transform * malla.get_aabb().get_center()
		for vertice in malla.get_faces():
			var punto := forma.global_transform * vertice
			puntos.append(punto + (centro - punto).normalized() * EPSILON)
	return puntos


static func _adentro(objeto: Node3D, caras: PackedVector3Array) -> bool:
	for punto in _puntos_del_volumen(objeto):
		if _punto_adentro(caras, punto):
			return true
	return false


## El oráculo se verifica antes de medir: si la malla no está cerrada, «afuera» no significa nada.
func _comprobar_la_malla(caras: PackedVector3Array, nombre: String) -> void:
	assert_int(caras.size()).override_failure_message("`%s` no tiene caras" % nombre).is_greater(0)
	(
		assert_int(_aristas_sueltas(caras))
		. override_failure_message("`%s` no está cerrada ni soldada entera" % nombre)
		. is_equal(0)
	)


func test_el_oraculo_distingue_adentro_de_afuera_de_una_placa() -> void:
	var placa := BoxMesh.new()
	placa.size = Vector3(1.0, 0.01, 1.0)
	var caras := placa.get_faces()
	assert_int(_aristas_sueltas(caras)).is_equal(0)
	assert_bool(_punto_adentro(caras, Vector3.ZERO)).is_true()
	assert_bool(_punto_adentro(caras, Vector3(0.0, 0.02, 0.0))).is_false()
	assert_bool(_punto_adentro(caras, Vector3(0.0, -0.02, 0.0))).is_false()


## Una caja grande, apoyada y quieta en el piso, con su cara de adelante a `metida` metros del
## frente del mostrador hacia adentro. Devuelve el frente, que es donde empieza el mueble.
func _caja_contra_el_mostrador(almacen: Node3D, caja: Node3D, metida: float) -> Vector3:
	var mostrador: MeshInstance3D = almacen.get_node(MOSTRADOR)
	var limites := mostrador.global_transform * mostrador.get_aabb()
	var suelo: CollisionShape3D = almacen.get_node("Estructura/SueloSolido/Local")
	var piso := suelo.global_position.y + (suelo.shape as BoxShape3D).size.y / 2.0
	var frente := Vector3(limites.get_center().x + limites.size.x / 4.0, piso, limites.position.z)
	caja.global_basis = Basis.IDENTITY
	caja.global_position = frente + Vector3(0.0, MEDIA_CAJA, metida - MEDIA_CAJA)
	caja.call("quedarse_quieta")
	return frente


func _caja_grande(almacen: Node3D) -> Node3D:
	for caja: Node3D in almacen.get("_cajas_de_productos"):
		if (caja.get_node("Cuerpo") as Node3D).scale.x >= MEDIA_CAJA:
			return caja
	return null


## Gira la vista como lo haría el mouse, a un yaw y un pitch absolutos en radianes.
func _mirar(jugador: Node3D, giro: float, alto: float) -> void:
	var camara: Camera3D = jugador.get_node("Giro/Camara")
	var evento := InputEventMouseMotion.new()
	evento.relative = (
		Vector2(jugador.get_node("Giro").rotation.y - giro, camara.rotation.x - alto)
		/ ReglasDelJugador.SENSIBILIDAD_DEL_MOUSE
	)
	jugador.call("_unhandled_input", evento)


## Para al jugador a `CARRERA` del frente, mirando hacia el mueble, y lo hace caminar.
func _caminar_hacia(jugador: CharacterBody3D, frente: Vector3) -> void:
	jugador.global_position = Vector3(frente.x, jugador.global_position.y, frente.z - CARRERA)
	_mirar(jugador, PI, 0.0)
	Input.action_press(ReglasDelJugador.ACCION_ADELANTE)


func _comprobar_que_no_entro(almacen: Node3D, caja: Node3D, frente: Vector3, donde: String) -> void:
	var caras := _caras_de(almacen.get_node(MOSTRADOR))
	_comprobar_la_malla(caras, "el mostrador")
	(
		assert_bool(_adentro(caja, caras))
		. override_failure_message("%s, la caja quedó adentro del mostrador" % donde)
		. is_false()
	)
	(
		assert_float(caja.global_position.z + MEDIA_CAJA)
		. override_failure_message(
			(
				"%s, la caja no salió del lado de afuera: su cara quedó en z = %.3f y el frente es %.3f"
				% [donde, caja.global_position.z + MEDIA_CAJA, frente.z]
			)
		)
		. is_less_equal(frente.z + EPSILON)
	)


## **El error de fondo: una forma cóncava es hueca.** Con la caja entera adentro del mostrador,
## la pregunta con que el puesto decide si una caja entra contestaba que sí: la caja no tocaba
## ninguna cara. Medido el 2026-09-26 con la escena de ese día. La caja a medias, en cambio, salía
## igual al empujarla: la cara del mueble la sacaba hacia afuera.
func test_la_caja_entera_adentro_del_mostrador_no_entra_ahi() -> void:  # AC-PLY-017
	var almacen: Node3D = await _almacen()
	var caja := _caja_grande(almacen)
	var mostrador: MeshInstance3D = almacen.get_node(MOSTRADOR)
	# Lo más adentro que entra: la caja apoyada en el piso, con su cara de atrás contra el fondo
	# del brazo del mostrador.
	var frente := _caja_contra_el_mostrador(almacen, caja, CAJA_ENTERA)
	await get_tree().physics_frame
	_comprobar_la_malla(_caras_de(mostrador), "el mostrador")
	(
		assert_bool(_adentro(caja, _caras_de(mostrador)))
		. override_failure_message("el caso no ejerce nada: la caja no quedó adentro del mueble")
		. is_true()
	)
	var puesto: Node3D = almacen.get("_reposicion_manual")
	(
		assert_bool(puesto.call("_entra_entera", caja))
		. override_failure_message(
			"el puesto dice que la caja entra entera en %v, adentro del mostrador" % frente
		)
		. is_false()
	)


func test_la_caja_soltada_pegada_no_entra_al_empujarla() -> void:  # AC-PLY-018
	var almacen: Node3D = await _almacen()
	var jugador: CharacterBody3D = almacen.get("_jugador")
	var caja := _caja_grande(almacen)
	var frente := _caja_contra_el_mostrador(almacen, caja, 0.0)
	_caminar_hacia(jugador, frente)
	var antes := jugador.global_position.z
	for cuadro in CUADROS_HASTA_BLOQUEARSE:
		await get_tree().physics_frame
		if jugador.global_position.z - antes < AVANCE_MINIMO and cuadro > 10:
			break
		antes = jugador.global_position.z
	for paso in PASOS_DESPUES_DE_BLOQUEARSE:
		await get_tree().physics_frame
	Input.action_release(ReglasDelJugador.ACCION_ADELANTE)
	await get_tree().physics_frame
	assert_float(caja.global_position.y).is_equal_approx(frente.y + MEDIA_CAJA, 0.005)
	_comprobar_que_no_entro(almacen, caja, frente, "pegada y empujada")


# --- La matriz: lo soltado y lo empujado contra cada sólido -----------------------------------


## El pie del jugador parado frente a una cara, y hacia dónde mira. El `y` es el del jugador.
func _frente_a(almacen: Node3D, cara: String, parado: float) -> Array:
	var jugador: Node3D = almacen.get("_jugador")
	var alto: float = jugador.global_position.y
	var mostrador: MeshInstance3D = almacen.get_node(MOSTRADOR)
	var limites := mostrador.global_transform * mostrador.get_aabb()
	match cara:
		CARA_DE_AFUERA_DEL_MOSTRADOR:
			var x := limites.get_center().x + limites.size.x / 4.0
			return [Vector3(x, alto, limites.position.z - parado), Vector3.BACK]
		CARA_DE_ADENTRO_DE_LA_L:
			var brazo: CollisionShape3D = almacen.get_node(MOSTRADOR + "/StaticBody3D/Volumen")
			var fondo: float = brazo.global_position.z + (brazo.shape as BoxShape3D).size.z / 2.0
			return [Vector3(limites.end.x - 0.6, alto, fondo + parado), Vector3.FORWARD]
		PARED_DE_LA_FACHADA:
			return [Vector3(PARED_LIBRE.x, alto, PARED_LIBRE.y - parado), Vector3.BACK]
	var gondola: MeshInstance3D = almacen.get_node("Estructura/gondola_deposito01")
	var suya := gondola.global_transform * gondola.get_aabb()
	return [Vector3(suya.get_center().x, alto, suya.end.z + parado), Vector3.FORWARD]


func _parar_frente_a(almacen: Node3D, cara: String, parado: float) -> float:
	var jugador: CharacterBody3D = almacen.get("_jugador")
	var pie_y_frente := _frente_a(almacen, cara, parado)
	jugador.global_position = pie_y_frente[0]
	jugador.velocity = Vector3.ZERO
	var hacia: Vector3 = pie_y_frente[1]
	var giro := atan2(-hacia.x, -hacia.z)
	_mirar(jugador, giro, 0.0)
	return giro


func _parado_con(objeto: Node3D) -> float:
	if objeto.has_method(ReglasDeLosObjetos.METODO_EMPUJAR):
		return PARADO_CON_LA_CAJA
	return PARADO_DEL_SOLIDO


## Suelta `objeto` en los gestos pedidos contra `cara`, y afirma cada vez. Devuelve cuántos se
## soltaron de verdad: el que no encuentra lugar vuelve a la mano, y eso también es correcto.
func _soltar_en_gestos(
	almacen: Node3D, objeto: Node3D, cara: String, giros: Array[float], altos: Array[float]
) -> int:
	var jugador: CharacterBody3D = almacen.get("_jugador")
	var agarre: Agarre = almacen.get("_agarre")
	var soltados := 0
	for giro in giros:
		for alto in altos:
			var derecho := _parar_frente_a(almacen, cara, _parado_con(objeto))
			if agarre.manos().sostenido() == null:
				_accion(jugador, objeto, ReglasDeLosObjetos.ACCION_AGARRAR)
			await get_tree().physics_frame
			_mirar(jugador, derecho + deg_to_rad(giro), deg_to_rad(alto))
			_accion(jugador, objeto, ReglasDeLosObjetos.ACCION_AGARRAR)
			if agarre.manos().sostenido() != null:
				continue
			soltados += 1
			for cuadro in CUADROS_DE_REPOSO:
				await get_tree().physics_frame
			var donde := (
				"`%s` contra %s, girado %.0f y mirando %.0f" % [objeto.name, cara, giro, alto]
			)
			_comprobar_libre_y_enfocable(almacen, objeto, donde)
	return soltados


## Le pone el foco al objetivo y le manda la acción, que es lo que hace el clic de verdad.
func _accion(jugador: Node3D, objetivo: Node3D, accion: StringName) -> void:
	jugador.set("_enfocado", objetivo)
	var evento := InputEventAction.new()
	evento.action = accion
	evento.pressed = true
	jugador.call("_unhandled_input", evento)


## Los sólidos fijos con los que se superpone: lo estático, no otro objeto ni el jugador.
##
## **Lo pregunta el motor, con un movimiento nulo del propio cuerpo**, que mide cuánto se hunde.
## Un cuerpo vivo apoyado se hunde un poco en lo que lo sostiene, y el motor lo tolera hasta su
## margen de penetración; uno congelado queda donde se lo puso.
static func _solidos_pisados(objeto: PhysicsBody3D) -> Array[String]:
	var tolerado := ReglasDeLosObjetos.ROCE
	if objeto is RigidBody3D and not (objeto as RigidBody3D).freeze:
		tolerado += ProjectSettings.get_setting(PENETRACION_TOLERADA)
	var consulta := PhysicsTestMotionParameters3D.new()
	consulta.from = objeto.global_transform
	consulta.max_collisions = 8
	var resultado := PhysicsTestMotionResult3D.new()
	PhysicsServer3D.body_test_motion(objeto.get_rid(), consulta, resultado)
	var pisados: Array[String] = []
	for indice in resultado.get_collision_count():
		var solido := resultado.get_collider(indice) as Node
		if solido is StaticBody3D and resultado.get_collision_depth(indice) > tolerado:
			pisados.append(
				"%s (%.3f m)" % [solido.get_parent().name, resultado.get_collision_depth(indice)]
			)
	return pisados


## Un lugar del piso donde el jugador entra parado, cerca de lo que se mira.
##
## **Es del test y es provisorio.** La búsqueda de lugares libres al lado del jugador vive
## todavía en un puesto; cuando baje a `sistemas/`, este helper se reemplaza por ella.
func _lugar_libre_cerca(almacen: Node3D, objeto: Node3D) -> Variant:
	var jugador: CharacterBody3D = almacen.get("_jugador")
	var cuerpo: CollisionShape3D = jugador.get_node("Cuerpo")
	var espacio := almacen.get_world_3d().direct_space_state
	var alto := jugador.global_position.y
	for radio in RADIOS_DEL_LUGAR_LIBRE:
		for lado in LADOS_DEL_LUGAR_LIBRE:
			var hacia := Basis(Vector3.UP, TAU * lado / LADOS_DEL_LUGAR_LIBRE) * Vector3.FORWARD
			var pie := Vector3(objeto.global_position.x, alto, objeto.global_position.z)
			pie += hacia * radio
			var consulta := PhysicsShapeQueryParameters3D.new()
			consulta.shape = cuerpo.shape
			consulta.transform = Transform3D(cuerpo.global_basis, pie + cuerpo.position)
			consulta.collision_mask = jugador.collision_mask
			consulta.exclude = [jugador.get_rid()]
			if not espacio.intersect_shape(consulta, 1).is_empty():
				continue
			var rayo := PhysicsRayQueryParameters3D.create(pie, pie + Vector3.DOWN * alto * 2.0)
			rayo.exclude = [jugador.get_rid()]
			if espacio.intersect_ray(rayo).is_empty():
				continue
			return pie
	return null


## Que el objeto no se superponga con ningún sólido fijo y que la mira real lo enfoque desde un
## lugar libre del piso.
## Un lugar del piso donde el jugador entra parado, cerca de lo que se mira. Los lugares del piso
## los busca `sistemas/`, igual que para el puesto y la red; acá sólo se prueba que entre la
## cápsula.
func _lugar_para_mirar(almacen: Node3D, objeto: Node3D) -> Variant:
	var jugador: CharacterBody3D = almacen.get("_jugador")
	var cuerpo: CollisionShape3D = jugador.get_node("Cuerpo")
	var espacio := almacen.get_world_3d().direct_space_state
	var pie := Vector3(
		objeto.global_position.x, jugador.global_position.y, objeto.global_position.z
	)
	for radio in RADIOS_DEL_LUGAR_LIBRE:
		var lugares := LugaresDelPiso.alrededor(
			espacio,
			pie,
			Vector3.FORWARD,
			radio,
			cuerpo.position.y,
			cuerpo.position.y * 2.0,
			LADOS_DEL_LUGAR_LIBRE,
			jugador.collision_mask,
			[jugador.get_rid()] as Array[RID]
		)
		for punto in lugares:
			# Parado sobre el piso lo toca: se lo levanta el roce para que el contacto no cuente.
			var lugar := punto + Vector3.UP * ReglasDeLosObjetos.ROCE
			var consulta := PhysicsShapeQueryParameters3D.new()
			consulta.shape = cuerpo.shape
			consulta.transform = Transform3D(cuerpo.global_basis, lugar + cuerpo.position)
			consulta.collision_mask = jugador.collision_mask
			consulta.exclude = [jugador.get_rid()]
			if espacio.intersect_shape(consulta, 1).is_empty():
				return lugar
	return null


## Que la red no haya tenido que rescatar nada: un verde con rescates escondería una prevención
## rota detrás de la red.
func _comprobar_sin_rescates(almacen: Node3D, donde: String) -> void:
	var red: RedDeSeguridad = almacen.get_node("Servicios/RedDeSeguridad")
	(
		assert_array(red.rescates)
		. override_failure_message("%s, la red tuvo que rescatar: la prevención falló" % donde)
		. is_empty()
	)


func _comprobar_libre_y_enfocable(almacen: Node3D, objeto: Node3D, donde: String) -> void:
	_comprobar_sin_rescates(almacen, donde)
	var pisados := _solidos_pisados(objeto)
	(
		assert_array(pisados)
		. override_failure_message("%s, quedó adentro de %s" % [donde, ", ".join(pisados)])
		. is_empty()
	)
	var jugador: CharacterBody3D = almacen.get("_jugador")
	var lugar: Variant = _lugar_para_mirar(almacen, objeto)
	(
		assert_bool(lugar != null)
		. override_failure_message("%s, no hay piso libre desde donde mirarlo" % donde)
		. is_true()
	)
	if lugar == null:
		return
	jugador.global_position = lugar
	_apuntar(jugador, objeto.global_position)
	var candidato: CampoDeInteraccion.Candidato = jugador.call("_medir_candidato", objeto)
	var enfocable := (
		candidato.visible and candidato.distancia <= ReglasDelJugador.ALCANCE_DE_LA_MIRA
	)
	(
		assert_bool(enfocable)
		. override_failure_message(
			(
				"%s, la mira no lo enfoca desde %v: está en %v, a %.2f m"
				% [donde, lugar, objeto.global_position, candidato.distancia]
			)
		)
		. is_true()
	)


func _unidad_en_la_mano(almacen: Node3D) -> Node3D:
	var puesto: Node3D = almacen.get("_reposicion_manual")
	var agarre: Agarre = almacen.get("_agarre")
	puesto.call("retirar", PRODUCTO_QUE_SE_SUELTA)
	if agarre.manos().sostenido() == null:
		return null
	return agarre.punto_de_producto.get_child(0)


func test_la_caja_soltada_contra_cada_solido_no_queda_adentro() -> void:
	var almacen: Node3D = await _almacen()
	var caja := _caja_grande(almacen)
	var soltadas := 0
	for cara in [
		CARA_DE_AFUERA_DEL_MOSTRADOR,
		CARA_DE_ADENTRO_DE_LA_L,
		PARED_DE_LA_FACHADA,
		GONDOLA_DEL_DEPOSITO,
	]:
		soltadas += await _soltar_en_gestos(almacen, caja, cara, GIROS_DEL_CUERPO, ALTOS_DE_LA_MIRA)
	(
		assert_int(soltadas)
		. override_failure_message("casi ninguna se soltó: el caso no ejerce nada")
		. is_greater(12)
	)


func test_la_unidad_soltada_contra_una_pared_no_queda_adentro() -> void:  # AC-PLY-019
	var almacen: Node3D = await _almacen()
	var unidad := _unidad_en_la_mano(almacen)
	assert_object(unidad).is_not_null()
	var soltadas := await _soltar_en_gestos(
		almacen, unidad, PARED_DE_LA_FACHADA, GIROS_DEL_CUERPO, ALTOS_DE_LA_MIRA
	)
	assert_int(soltadas).override_failure_message("casi ninguna se soltó").is_greater(6)


func test_la_unidad_soltada_contra_el_mostrador_no_queda_adentro() -> void:  # AC-PLY-020
	var almacen: Node3D = await _almacen()
	var unidad := _unidad_en_la_mano(almacen)
	assert_object(unidad).is_not_null()
	var soltadas := await _soltar_en_gestos(
		almacen, unidad, CARA_DE_AFUERA_DEL_MOSTRADOR, GIROS_DEL_CUERPO, ALTOS_DE_LA_MIRA
	)
	assert_int(soltadas).override_failure_message("casi ninguna se soltó").is_greater(6)


func test_la_bolsa_y_el_trapeador_soltados_contra_una_pared_no_quedan_adentro() -> void:
	var almacen: Node3D = await _almacen()
	var objetos: Array[Node3D] = [almacen.get("_bolsas")[0], almacen.get_node("Objetos/Trapeador")]
	var derecho: Array[float] = [0.0]
	var dos_alturas: Array[float] = [-40.0, 0.0]
	for objeto in objetos:
		var soltados := await _soltar_en_gestos(
			almacen, objeto, PARED_DE_LA_FACHADA, derecho, dos_alturas
		)
		assert_int(soltados).override_failure_message("`%s` no se soltó" % objeto.name).is_equal(2)


func test_la_caja_soltada_pegada_a_una_pared_no_entra_al_empujarla() -> void:
	var almacen: Node3D = await _almacen()
	var jugador: CharacterBody3D = almacen.get("_jugador")
	var caja := _caja_grande(almacen)
	var suelo: CollisionShape3D = almacen.get_node("Estructura/SueloSolido/Local")
	var piso := suelo.global_position.y + (suelo.shape as BoxShape3D).size.y / 2.0
	var frente := Vector3(PARED_LIBRE.x, piso, PARED_LIBRE.y)
	caja.global_basis = Basis.IDENTITY
	caja.global_position = frente + Vector3(0.0, MEDIA_CAJA, -MEDIA_CAJA)
	caja.call("quedarse_quieta")
	_caminar_hacia(jugador, frente)
	for cuadro in CUADROS_CAMINANDO + PASOS_DESPUES_DE_BLOQUEARSE:
		await get_tree().physics_frame
	Input.action_release(ReglasDelJugador.ACCION_ADELANTE)
	await get_tree().physics_frame
	assert_float(caja.global_position.y).is_equal_approx(frente.y + MEDIA_CAJA, 0.005)
	_comprobar_libre_y_enfocable(almacen, caja, "la caja empujada contra la pared")


# --- Lo que ya era legal lo sigue siendo -------------------------------------------------------


## Apunta la mira a un punto del mundo desde donde está parado el jugador.
func _apuntar(jugador: Node3D, punto: Vector3) -> void:
	var camara: Camera3D = jugador.get_node("Giro/Camara")
	var hacia := punto - camara.global_position
	_mirar(jugador, atan2(-hacia.x, -hacia.z), atan2(hacia.y, Vector2(hacia.x, hacia.z).length()))


## Sobre qué mueble quedó apoyado un cuerpo: el padre del sólido que tiene debajo.
func _apoyo_de(almacen: Node3D, cuerpo: Node3D) -> String:
	var consulta := PhysicsRayQueryParameters3D.create(
		cuerpo.global_position, cuerpo.global_position + Vector3.DOWN * 3.0
	)
	consulta.exclude = [(cuerpo as CollisionObject3D).get_rid()]
	var golpe := almacen.get_world_3d().direct_space_state.intersect_ray(consulta)
	var solido: Node = golpe.get("collider")
	return "" if solido == null else str(solido.get_parent().name)


## Suelta la caja apuntando a la tapa de un mueble, parado frente a él.
func _soltar_la_caja_sobre(almacen: Node3D, caja: Node3D, cara: String, tapa: Vector3) -> void:
	var jugador: CharacterBody3D = almacen.get("_jugador")
	_parar_frente_a(almacen, cara, PARADO_CON_LA_CAJA)
	_accion(jugador, caja, ReglasDeLosObjetos.ACCION_AGARRAR)
	await get_tree().physics_frame
	_apuntar(jugador, tapa)
	_accion(jugador, caja, ReglasDeLosObjetos.ACCION_AGARRAR)


## **La tabla de arriba arranca con dos cajas**, y en las de abajo una caja grande no entra: se
## corre una de las dos al piso para dejarle lugar a la que se suelta.
func test_la_caja_se_sigue_apoyando_en_un_estante_del_deposito() -> void:  # AC-PLY-021
	var almacen: Node3D = await _almacen()
	var caja := _caja_grande(almacen)
	var tabla: Node3D = almacen.get("_cajas_de_productos")[Producto.Id.CHISITOS]
	var lugar := tabla.global_position
	tabla.global_position = Vector3(lugar.x, lugar.y, lugar.z + 3.0)
	tabla.global_position.y = MEDIA_CAJA + _piso(almacen)
	tabla.call("quedarse_quieta")
	await _soltar_la_caja_sobre(
		almacen, caja, GONDOLA_DEL_DEPOSITO, lugar + Vector3.DOWN * MEDIA_CAJA
	)
	assert_str(_apoyo_de(almacen, caja)).contains("gondola_deposito01")
	assert_array(_solidos_pisados(caja)).is_empty()
	_comprobar_sin_rescates(almacen, "lo legal")


func _piso(almacen: Node3D) -> float:
	var suelo: CollisionShape3D = almacen.get_node("Estructura/SueloSolido/Local")
	return suelo.global_position.y + (suelo.shape as BoxShape3D).size.y / 2.0


func test_la_caja_se_sigue_apoyando_arriba_del_mostrador() -> void:  # AC-PLY-022
	var almacen: Node3D = await _almacen()
	var caja := _caja_grande(almacen)
	var mostrador: MeshInstance3D = almacen.get_node(MOSTRADOR)
	var limites := mostrador.global_transform * mostrador.get_aabb()
	var brazo: CollisionShape3D = almacen.get_node(MOSTRADOR + "/StaticBody3D/Volumen")
	var tapa := Vector3(
		limites.get_center().x + limites.size.x / 4.0, limites.end.y, brazo.global_position.z
	)
	await _soltar_la_caja_sobre(almacen, caja, CARA_DE_AFUERA_DEL_MOSTRADOR, tapa)
	assert_str(_apoyo_de(almacen, caja)).contains("EscritorioComputadora")
	assert_array(_solidos_pisados(caja)).is_empty()
	_comprobar_sin_rescates(almacen, "lo legal")


func test_la_caja_se_sigue_apilando_sobre_otra() -> void:  # AC-PLY-023
	var almacen: Node3D = await _almacen()
	var grandes: Array[Node3D] = []
	for caja: Node3D in almacen.get("_cajas_de_productos"):
		if (caja.get_node("Cuerpo") as Node3D).scale.x >= MEDIA_CAJA:
			grandes.append(caja)
	var abajo := grandes[0]
	var arriba := grandes[1]
	var jugador: CharacterBody3D = almacen.get("_jugador")
	var suelo: CollisionShape3D = almacen.get_node("Estructura/SueloSolido/Local")
	var piso := suelo.global_position.y + (suelo.shape as BoxShape3D).size.y / 2.0
	abajo.global_basis = Basis.IDENTITY
	abajo.global_position = Vector3(PARED_LIBRE.x, piso + MEDIA_CAJA, PARED_LIBRE.y - 2.0)
	abajo.call("quedarse_quieta")
	var alto := jugador.global_position.y
	jugador.global_position = abajo.global_position + Vector3(0.0, 0.0, -1.4)
	jugador.global_position.y = alto
	_mirar(jugador, PI, 0.0)
	_accion(jugador, arriba, ReglasDeLosObjetos.ACCION_AGARRAR)
	await get_tree().physics_frame
	_apuntar(jugador, abajo.global_position + Vector3.UP * MEDIA_CAJA)
	_accion(jugador, arriba, ReglasDeLosObjetos.ACCION_AGARRAR)
	(
		assert_float(arriba.global_position.y - abajo.global_position.y)
		. override_failure_message("la caja no quedó encima de la otra")
		. is_equal_approx(MEDIA_CAJA * 2.0, 0.01)
	)
	assert_array(_solidos_pisados(arriba)).is_empty()
	_comprobar_sin_rescates(almacen, "lo legal")


func test_la_unidad_se_sigue_dejando_adentro_de_la_heladera() -> void:  # AC-PLY-024
	var almacen: Node3D = await _almacen()
	var jugador: CharacterBody3D = almacen.get("_jugador")
	var heladera: MeshInstance3D = almacen.get_node("Estructura/heladeranueva")
	var limites := heladera.global_transform * heladera.get_aabb()
	var unidad := _unidad_en_la_mano(almacen)
	assert_object(unidad).is_not_null()
	if unidad == null:
		return
	jugador.global_position = Vector3(
		limites.end.x + PARADO_DEL_SOLIDO, jugador.global_position.y, limites.get_center().z
	)
	_mirar(jugador, -PI / 2.0, 0.0)
	await get_tree().physics_frame
	var estante: CollisionShape3D = heladera.get_node("StaticBody3D/Volumen12")
	_apuntar(jugador, estante.global_position + Vector3.UP * 0.1)
	_accion(jugador, unidad, ReglasDeLosObjetos.ACCION_AGARRAR)
	for cuadro in CUADROS_DE_REPOSO:
		await get_tree().physics_frame
	(
		assert_bool(limites.has_point(unidad.global_position))
		. override_failure_message(
			"la unidad no quedó adentro de la heladera: está en %v" % unidad.global_position
		)
		. is_true()
	)
	_comprobar_libre_y_enfocable(almacen, unidad, "la unidad en la heladera")


func test_un_objeto_dejado_arriba_del_inodoro_queda_quieto() -> void:
	var almacen: Node3D = await _almacen()
	var inodoro: MeshInstance3D = almacen.get_node("Estructura/inodoro")
	var tanque: CollisionShape3D = inodoro.get_node("StaticBody3D/Volumen3")
	var tapa := tanque.global_transform * tanque.shape.get_debug_mesh().get_aabb()
	var bolsa: RigidBody3D = almacen.get("_bolsas")[0]
	var forma: CollisionShape3D = bolsa.get_node("Forma")
	var media_altura := (forma.shape as BoxShape3D).size.y / 2.0
	bolsa.global_basis = Basis.IDENTITY
	bolsa.global_position = Vector3(
		tapa.get_center().x, tapa.end.y + media_altura + 0.01, tapa.get_center().z
	)
	bolsa.linear_velocity = Vector3.ZERO
	bolsa.angular_velocity = Vector3.ZERO
	var partida := bolsa.global_position
	for cuadro in CUADROS_DE_REPOSO * 2:
		await get_tree().physics_frame
	var corrida := Vector2(bolsa.global_position.x - partida.x, bolsa.global_position.z - partida.z)
	(
		assert_float(corrida.length())
		. override_failure_message(
			"la bolsa se deslizó de %v a %v" % [partida, bolsa.global_position]
		)
		. is_less(0.02)
	)
	assert_bool(bolsa.sleeping).override_failure_message("la bolsa no se durmió").is_true()
