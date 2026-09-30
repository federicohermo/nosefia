## Lo que se suelta o se empuja no queda adentro de un sólido fijo.
extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.tscn")
const AperturaConLugar := preload("res://test/escenas/apertura_con_lugar.gd")

const MOSTRADOR := "Estructura/EscritorioComputadora"
const MOUSE := "Estructura/mouse"
const TECLADO := "Estructura/teclado"

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
## pasos: la caja pegada no entraba. Queda como regresión.
const PASOS_DESPUES_DE_BLOQUEARSE := 60

## Hasta cuántos cuadros se espera a que el jugador quede bloqueado.
const CUADROS_HASTA_BLOQUEARSE := 600

## Cuánto tiene que avanzar el jugador en un cuadro para no contar como bloqueado, en metros.
const AVANCE_MINIMO := 0.0001

## Media caja grande, en metros. Las cajas chicas no se usan acá.
const MEDIA_CAJA := 0.3037

## Cuánto se mete la caja en el mouse al rozarlo, y al meterse de verdad, en metros.
const ROCE_CON_EL_MOUSE := 0.001
const CAJA_EN_EL_MOUSE := 0.03

## Cuánto se mete la esquina de la caja en la del teclado, en metros: más de lo que se tolera.
const ESQUINA_EN_EL_TECLADO := 0.005

## Dos cuadros sin reporte entre cada reporte: así llega un mouse más lento que la pantalla.
const REPORTES_DE_UN_MOUSE_LENTO := 10
const CUADRO_SIN_MOUSE := SuavizadoDelGiro.PAUSA / 4.0

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

## Un tramo libre de la pared de la fachada, lejos de la ventanilla, de las góndolas y de la puerta
## de entrada.
const PARED_LIBRE := Vector2(-5.0, 7.871)

## Hacia dónde mira quien suelta algo contra una pared, en grados: 40° abajo inclina lo que se
## lleva, y eso le da fondo.
const MIRANDO_ABAJO := -40.0

## De 0,5 a 1,1 m de una pared: lo más cerca que se para el jugador y lo más lejos que lo soltado
## todavía la toca.
const CERCA_DE_LA_PARED: Array[float] = [0.5, 0.7, 0.8, 0.9, 1.0, 1.1]

## Desde cuántos metros de la pared la bolsa, la mopa, el balde y la unidad soltados ya no tocan el
## cuerpo: caen adelante, donde apunta la mira. Medido el 2026-09-30.
const SIN_TOCAR_EL_CUERPO := 1.0

## Cuánto puede quedar inclinado lo que cae derecho, en grados. Inclinado por la mira eran 40.
const DERECHO := 3.0

## A cuánto del jugador queda lo que cae a su lado, como mucho, en metros: el cuerpo mide 0,4 de
## radio y el bidón 0,46 de ancho.
const AL_LADO := 1.0


func _almacen() -> Node3D:
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	# La noche abre con la góndola llena, y una caja llena no entrega: estos casos sacan
	# unidades para usarlas de objeto, así que abren con lugar para reponer.
	AperturaConLugar.abrir_con_todo_el_lugar(almacen)
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
##
## El suavizado del giro atrasa la cámara según cuántos cuadros hubo, y eso cambia con la máquina:
## sin terminar el dibujo acá, el gesto suelta con otra vista.
func _mirar(jugador: Node3D, giro: float, alto: float) -> void:
	var camara: Camera3D = jugador.get_node("Giro/Camara")
	var evento := InputEventMouseMotion.new()
	evento.relative = (
		Vector2(jugador.get_node("Giro").rotation.y - giro, camara.rotation.x - alto)
		/ ReglasDelJugador.SENSIBILIDAD_DEL_MOUSE
	)
	jugador.call("_unhandled_input", evento)
	(jugador.get("_control") as ControlDelJugador).avanzar_el_dibujo(SuavizadoDelGiro.VENTANA)
	jugador.call("_aplicar_la_rotacion")


func test_mirar_deja_la_vista_que_se_pide_con_un_mouse_lento() -> void:
	var almacen: Node3D = await _almacen()
	var jugador: CharacterBody3D = almacen.get("_jugador")
	var control: ControlDelJugador = jugador.get("_control")
	for reporte in REPORTES_DE_UN_MOUSE_LENTO:
		_mirar(jugador, reporte * 0.01, 0.0)
		control.avanzar_el_dibujo(CUADRO_SIN_MOUSE)
		control.avanzar_el_dibujo(CUADRO_SIN_MOUSE)
	_mirar(jugador, PI / 2.0, 0.3)
	assert_float(jugador.get_node("Giro").rotation.y).is_equal_approx(PI / 2.0, 0.001)
	assert_float(jugador.get_node("Giro/Camara").rotation.x).is_equal_approx(0.3, 0.001)


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


func test_la_caja_con_una_esquina_en_el_teclado_no_entra() -> void:
	var almacen: Node3D = await _almacen()
	var caja := _caja_grande(almacen)
	var teclado: MeshInstance3D = almacen.get_node(TECLADO)
	var suyo := teclado.global_transform * teclado.get_aabb()
	var mostrador: MeshInstance3D = almacen.get_node(MOSTRADOR)
	var tapa := (mostrador.global_transform * mostrador.get_aabb()).end.y
	caja.global_basis = Basis.IDENTITY
	caja.global_position = Vector3(
		suyo.position.x - MEDIA_CAJA + ESQUINA_EN_EL_TECLADO,
		tapa + MEDIA_CAJA,
		suyo.position.z - MEDIA_CAJA + ESQUINA_EN_EL_TECLADO
	)
	caja.call("quedarse_quieta")
	await get_tree().physics_frame
	var puesto: Node3D = almacen.get("_reposicion_manual")
	(
		assert_bool(puesto.call("_entra_entera", caja))
		. override_failure_message("la caja entra con una esquina adentro del teclado")
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
	_comprobar_libre_y_enfocable(almacen, caja, "pegada y empujada")


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
	var gondola: MeshInstance3D = almacen.get_node("Estructura/gondola_deposito03_001")
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
## Un cuerpo vivo apoyado se hunde un poco en lo que lo sostiene, y el motor lo tolera hasta su
## margen de penetración; uno congelado queda donde se lo puso.
##
## Lo que el motor saca antes de medir también estaba adentro. La distancia entre los pares de
## `collide_shape` no es lo hundido contra una malla de triángulos: rozar el mouse 1 mm daba 3 cm.
## Medido el 2026-09-26.
static func _solidos_pisados(objeto: PhysicsBody3D) -> Array[String]:
	var tolerado := ReglasDeLosObjetos.ROCE
	if objeto is RigidBody3D and not (objeto as RigidBody3D).freeze:
		tolerado += ProjectSettings.get_setting(PENETRACION_TOLERADA)
	var espacio := objeto.get_world_3d().direct_space_state
	var pisados: Array[String] = []
	for forma: CollisionShape3D in objeto.find_children("*", "CollisionShape3D", true, false):
		var consulta := PhysicsShapeQueryParameters3D.new()
		consulta.shape = forma.shape
		consulta.transform = forma.global_transform
		consulta.collision_mask = objeto.collision_mask
		consulta.exclude = [objeto.get_rid()]
		var golpes := espacio.intersect_shape(consulta, 16)
		for golpe in golpes:
			var solido := golpe["collider"] as Node
			if not solido is StaticBody3D:
				continue
			var otros: Array[RID] = []
			for otro in golpes:
				if otro["rid"] != golpe["rid"]:
					otros.append(otro["rid"])
			var prueba := PhysicsTestMotionParameters3D.new()
			prueba.from = objeto.global_transform
			prueba.max_collisions = 32
			prueba.recovery_as_collision = true
			prueba.exclude_bodies = otros
			var resultado := PhysicsTestMotionResult3D.new()
			PhysicsServer3D.body_test_motion(objeto.get_rid(), prueba, resultado)
			var hondo := 0.0
			for indice in resultado.get_collision_count():
				var sacado := resultado.get_travel().dot(resultado.get_collision_normal(indice))
				hondo = maxf(hondo, resultado.get_collision_depth(indice) + sacado)
			if hondo > tolerado:
				pisados.append("%s (%.3f m)" % [solido.get_parent().name, hondo])
	return pisados


## Apoya la caja en la tapa del mostrador, con un costado `metida` metros adentro del mouse.
func _caja_contra_el_mouse(almacen: Node3D, caja: Node3D, metida: float) -> void:
	var mouse: MeshInstance3D = almacen.get_node(MOUSE)
	var suyo := mouse.global_transform * mouse.get_aabb()
	var mostrador: MeshInstance3D = almacen.get_node(MOSTRADOR)
	var tapa := (mostrador.global_transform * mostrador.get_aabb()).end.y
	caja.global_basis = Basis.IDENTITY
	caja.global_position = Vector3(
		suyo.end.x + MEDIA_CAJA - metida, tapa + MEDIA_CAJA, suyo.get_center().z
	)
	caja.call("quedarse_quieta")
	await get_tree().physics_frame


func test_la_medida_distingue_rozar_el_mouse_de_meterse_en_el() -> void:
	var almacen: Node3D = await _almacen()
	var caja := _caja_grande(almacen)
	await _caja_contra_el_mouse(almacen, caja, ROCE_CON_EL_MOUSE)
	(
		assert_array(_solidos_pisados(caja))
		. override_failure_message("rozar el mouse contó como quedar adentro")
		. is_empty()
	)
	await _caja_contra_el_mouse(almacen, caja, CAJA_EN_EL_MOUSE)
	(
		assert_array(_solidos_pisados(caja))
		. override_failure_message("meterse en el mouse contó como quedar afuera")
		. is_not_empty()
	)


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
	for cara: String in [
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


func test_la_bolsa_y_los_utiles_soltados_contra_una_pared_no_quedan_adentro() -> void:
	# La mopa mide un metro y cuarto y la mano la lleva inclinada; el bidón es el más ancho.
	var almacen: Node3D = await _almacen()
	var objetos: Array[Node3D] = [almacen.get("_bolsas")[0]]
	for util: String in ["Mopa", "Balde", "JabonAzul"]:
		objetos.append(almacen.get_node("Objetos/" + util))
	var derecho: Array[float] = [0.0]
	var dos_alturas: Array[float] = [-40.0, 0.0]
	for objeto in objetos:
		var soltados := await _soltar_en_gestos(
			almacen, objeto, PARED_DE_LA_FACHADA, derecho, dos_alturas
		)
		assert_int(soltados).override_failure_message("`%s` no se soltó" % objeto.name).is_equal(2)


func test_lo_soltado_contra_una_pared_cae_sin_rozarla() -> void:  # AC-PLY-019
	# El barrido dejaba lo soltado pegado a la pared, y caía rozándola. Una unidad se enganchaba en
	# una arista del modelo, giraba y se hundía 3 cm en el rincón con el piso: la red la rescataba,
	# según qué suites hubieran corrido antes. Medido el 2026-09-30, con el cuerpo girado 20°.
	var almacen: Node3D = await _almacen()
	var jugador: CharacterBody3D = almacen.get("_jugador")
	var agarre: Agarre = almacen.get("_agarre")
	var unidad := _unidad_en_la_mano(almacen)
	assert_object(unidad).is_not_null()
	for giro in GIROS_DEL_CUERPO:
		var donde := "`%s` soltado mirando derecho, girado %.0f" % [unidad.name, giro]
		var derecho := _parar_frente_a(almacen, PARED_DE_LA_FACHADA, PARADO_DEL_SOLIDO)
		if agarre.manos().sostenido() == null:
			_accion(jugador, unidad, ReglasDeLosObjetos.ACCION_AGARRAR)
		await get_tree().physics_frame
		_mirar(jugador, derecho + deg_to_rad(giro), 0.0)
		_accion(jugador, unidad, ReglasDeLosObjetos.ACCION_AGARRAR)
		assert_object(agarre.manos().sostenido()).override_failure_message(donde).is_null()
		var separacion := _separacion_de_la_fachada(unidad)
		(
			assert_float(separacion)
			. override_failure_message(
				"%s, cae a %.4f m de la pared: la roza" % [donde, separacion]
			)
			. is_greater(ReglasDeLosObjetos.ROCE)
		)
		for cuadro in CUADROS_DE_REPOSO:
			await get_tree().physics_frame
		_comprobar_libre_y_enfocable(almacen, unidad, donde)


func test_el_bidon_encimado_con_el_cuerpo_cae_derecho_al_lado_del_jugador() -> void:
	# El bidón mide 0,70 × 0,46 m, y la mira lo inclina: tiene más fondo que el lugar entre el
	# cuerpo y la pared. La caída lo barría hasta tocarla sin contar el cuerpo, la física lo sacaba
	# del cuerpo a los empujones, y a 0,7-1,0 m lo metía 5 cm en la pared.
	var almacen: Node3D = await _almacen()
	var jugador: CharacterBody3D = almacen.get("_jugador")
	var bidon: Node3D = almacen.get_node("Objetos/JabonAzul")
	for parado in CERCA_DE_LA_PARED:
		var donde := "`%s` soltado a %.1f m de la pared" % [bidon.name, parado]
		await _soltar_contra_la_fachada(almacen, bidon, parado, donde)
		for cuadro in CUADROS_DE_REPOSO:
			await get_tree().physics_frame
		_comprobar_libre_y_enfocable(almacen, bidon, donde)
		var inclinado := rad_to_deg(bidon.global_basis.y.angle_to(Vector3.UP))
		(
			assert_float(inclinado)
			. override_failure_message("%s, quedó inclinado %.0f°" % [donde, inclinado])
			. is_less(DERECHO)
		)
		var lejos := _en_el_piso(bidon.global_position - jugador.global_position).length()
		(
			assert_float(lejos)
			. override_failure_message("%s, cayó a %.2f m del jugador" % [donde, lejos])
			. is_less(AL_LADO)
		)


func test_lo_que_no_toca_el_cuerpo_se_sigue_soltando_adelante() -> void:
	# Arreglar el bidón no mueve lo que ya caía bien: lo que no toca el cuerpo cae donde apunta la
	# mira, entre el jugador y la pared. Y más cerca, lo que lo toca cae al lado.
	var almacen: Node3D = await _almacen()
	var jugador: CharacterBody3D = almacen.get("_jugador")
	var cuerpo: CollisionShape3D = jugador.get_node("Cuerpo")
	var radio := (cuerpo.shape as CapsuleShape3D).radius
	var objetos: Array[Node3D] = [almacen.get("_bolsas")[0]]
	for util: String in ["Mopa", "Balde"]:
		objetos.append(almacen.get_node("Objetos/" + util))
	# La unidad va última y se saca recién ahí: sacarla es tenerla en la mano.
	objetos.append(null)
	for objeto in objetos:
		if objeto == null:
			objeto = _unidad_en_la_mano(almacen)
			assert_object(objeto).is_not_null()
		for parado in CERCA_DE_LA_PARED:
			var donde := "`%s` soltado a %.1f m de la pared" % [objeto.name, parado]
			await _soltar_contra_la_fachada(almacen, objeto, parado, donde)
			for cuadro in CUADROS_DE_REPOSO:
				await get_tree().physics_frame
			if parado >= SIN_TOCAR_EL_CUERPO:
				(
					assert_float(objeto.global_position.z - jugador.global_position.z)
					. override_failure_message("%s, no cayó adelante" % donde)
					. is_greater(radio)
				)
			_comprobar_libre_y_enfocable(almacen, objeto, donde)
		# Lo soltado se queda contra la pared: se lo devuelve para que no se cruce con el siguiente.
		if objeto.has_method(ReglasDeLosObjetos.METODO_LUGAR_DE_ORIGEN):
			objeto.global_transform = objeto.call(ReglasDeLosObjetos.METODO_LUGAR_DE_ORIGEN)


## Suelta `objeto` parado a `parado` metros de la pared de la fachada, mirando abajo, y afirma las
## dos cosas que se ven antes de que la física se mueva: que no quedó encimado con nada —ni con
## el cuerpo del jugador— y que después del primer paso de física no está adentro de la pared.
##
## La pared se mide antes que la red, que lo mira en ese mismo cuadro y lo puede mover: la medida
## se engancha antes de soltar, y la señal llama a los enganchados en orden.
func _soltar_contra_la_fachada(
	almacen: Node3D, objeto: Node3D, parado: float, donde: String
) -> void:
	var jugador: CharacterBody3D = almacen.get("_jugador")
	var agarre: Agarre = almacen.get("_agarre")
	var derecho := _parar_frente_a(almacen, PARED_DE_LA_FACHADA, parado)
	if agarre.manos().sostenido() == null:
		_accion(jugador, objeto, ReglasDeLosObjetos.ACCION_AGARRAR)
	await get_tree().physics_frame
	_mirar(jugador, derecho, deg_to_rad(MIRANDO_ABAJO))
	var separaciones: Array[float] = []
	var medir := func() -> void: separaciones.append(_separacion_de_la_fachada(objeto))
	get_tree().physics_frame.connect(medir, CONNECT_ONE_SHOT)
	_accion(jugador, objeto, ReglasDeLosObjetos.ACCION_AGARRAR)
	(
		assert_object(agarre.manos().sostenido())
		. override_failure_message("%s, no se soltó" % donde)
		. is_null()
	)
	var empujon := _empujon_para_sacarlo(objeto as PhysicsBody3D)
	(
		assert_float(empujon.length())
		. override_failure_message(
			"%s, quedó encimado: la física lo iba a sacar empujándolo %v" % [donde, empujon]
		)
		. is_less_equal(ReglasDeLosObjetos.ROCE)
	)
	await get_tree().physics_frame
	var separacion: float = separaciones[0] if not separaciones.is_empty() else -INF
	(
		assert_float(separacion)
		. override_failure_message(
			"%s, en el primer cuadro quedó %.3f m adentro de la pared" % [donde, -separacion]
		)
		. is_greater_equal(-_hundimiento_tolerado(objeto))
	)


## Cuánto tendría que mover el motor al cuerpo para sacarlo de todo lo que pisa, el jugador
## incluido. Cero es que quedó donde entra.
static func _empujon_para_sacarlo(cuerpo: PhysicsBody3D) -> Vector3:
	var consulta := PhysicsTestMotionParameters3D.new()
	consulta.from = cuerpo.global_transform
	consulta.max_collisions = 32
	var resultado := PhysicsTestMotionResult3D.new()
	PhysicsServer3D.body_test_motion(cuerpo.get_rid(), consulta, resultado)
	return resultado.get_travel()


## Cuánto separa el volumen del objeto de la cara de la pared de la fachada, en metros.
static func _separacion_de_la_fachada(objeto: Node3D) -> float:
	var frente := -INF
	for punto in _puntos_del_volumen(objeto):
		frente = maxf(frente, punto.z)
	return PARED_LIBRE.y - frente


## Cuánto puede hundirse un cuerpo vivo en lo que toca sin estar adentro: el roce y el margen del
## motor, lo mismo que tolera `_solidos_pisados()`.
static func _hundimiento_tolerado(objeto: Node3D) -> float:
	var tolerado := ReglasDeLosObjetos.ROCE
	if objeto is RigidBody3D and not (objeto as RigidBody3D).freeze:
		tolerado += ProjectSettings.get_setting(PENETRACION_TOLERADA)
	return tolerado


static func _en_el_piso(vector: Vector3) -> Vector2:
	return Vector2(vector.x, vector.z)


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


## **La tabla de abajo del estante del fondo arranca llena**: se corre al piso la caja del medio
## para dejarle lugar a la que se suelta.
func test_la_caja_se_sigue_apoyando_en_un_estante_del_deposito() -> void:  # AC-PLY-021
	var almacen: Node3D = await _almacen()
	var caja := _caja_grande(almacen)
	var tabla: Node3D = almacen.get("_cajas_de_productos")[Producto.Id.UAKAS]
	var lugar := tabla.global_position
	tabla.global_position = Vector3(lugar.x, lugar.y, lugar.z + 3.0)
	tabla.global_position.y = MEDIA_CAJA + _piso(almacen)
	tabla.call("quedarse_quieta")
	await _soltar_la_caja_sobre(
		almacen, caja, GONDOLA_DEL_DEPOSITO, lugar + Vector3.DOWN * MEDIA_CAJA
	)
	assert_str(_apoyo_de(almacen, caja)).contains("gondola_deposito03_001")
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
