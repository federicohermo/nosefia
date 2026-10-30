## Lo que el jugador suelta apuntando a una heladera no baja al hueco de su fondo.
extends GdUnitTestSuite

const AperturaConLugar := preload("res://test/escenas/apertura_con_lugar.gd")
const ALMACEN := preload("res://src/escenas/almacen.tscn")
const MUEBLES: Array[String] = ["heladeranueva", "heladeranueva_001", "heladera_fuera_de_servicio"]

## Qué se suelta, con el clic de verdad.
const PRODUCTO_QUE_SE_SUELTA := Producto.Id.MALBARDO

## A qué fracción del zócalo, contando desde el piso, se apunta.
const ALTOS_DEL_ZOCALO: Array[float] = [0.15, 0.5, 0.95]

## Cuántos metros adentro del borde de adelante del estante más bajo con colisión se apunta.
const ADENTRO_DEL_ESTANTE: Array[float] = [0.0, 0.03, 0.08, 0.2]

## A cuántos metros del frente se para el jugador.
const PARADOS: Array[float] = [0.6, 1.0]

## Cuánto se sube la mira sobre la tapa del estante, y cuántos cuadros de física se espera a que
## lo soltado se asiente.
const SOBRE_EL_ESTANTE := 0.02
const CUADROS_DE_REPOSO := 60

## Cuánto puede entrar al volumen lo que queda afuera, en metros.
const TOLERANCIA := 0.01

## Cuánto sobresale el volumen de una unidad por debajo de lo que la sostiene, en metros.
const MARGEN_DE_LA_FORMA := 0.03


func _almacen() -> Node3D:
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	AperturaConLugar.abrir_con_todo_el_lugar(almacen)
	await get_tree().physics_frame
	await get_tree().physics_frame
	return almacen


func _mueble(almacen: Node3D, numero: int) -> MeshInstance3D:
	return almacen.get_node("Estructura/%s" % MUEBLES[numero])


func _hoja(almacen: Node3D, numero: int) -> MeshInstance3D:
	return _mueble(almacen, numero).get_node("puerta_heladera_%d" % numero)


func _abrir(almacen: Node3D, numero: int) -> void:
	_hoja(almacen, numero).get_node("CuerpoDeLaHoja").call("alternar")
	for cuadro in CUADROS_DE_REPOSO:
		await get_tree().physics_frame


## El frente de la heladera, medido en la escena con la hoja cerrada: hacia dónde mira, dónde
## queda su plano y entre qué alturas queda abierto, del piso al borde de abajo de la hoja.
func _frente_de(almacen: Node3D, numero: int) -> Dictionary:
	var mueble := _mueble(almacen, numero)
	var cuerpo := mueble.global_transform * mueble.get_aabb()
	var hoja := _hoja(almacen, numero)
	var de_la_hoja := hoja.global_transform * hoja.get_aabb()
	var direccion := mueble.global_basis.x.normalized()
	var hacia_la_hoja := (de_la_hoja.get_center() - cuerpo.get_center()) * Vector3(1.0, 0.0, 1.0)
	var suelo: CollisionShape3D = almacen.get_node("Estructura/SueloSolido/Local")
	var frente := {
		"direccion": direccion,
		"plano":
		(mueble.global_transform * Vector3(mueble.get_aabb().end.x, 0.0, 0.0)).dot(direccion),
		"centro": cuerpo.get_center(),
		"piso": suelo.global_position.y + (suelo.shape as BoxShape3D).size.y / 2.0,
		"base_de_la_hoja": de_la_hoja.position.y,
	}
	# La premisa: el frente que se mide es el de la hoja, y debajo de ella hay lugar.
	assert_float(direccion.dot(hacia_la_hoja.normalized())).is_greater(0.9)
	assert_float(frente["base_de_la_hoja"] - frente["piso"]).is_greater(0.0)
	return frente


## El estante más bajo con colisión, en coordenadas del mundo: el primero que queda sobre la hoja.
func _estante_mas_bajo(almacen: Node3D, numero: int, frente: Dictionary) -> AABB:
	var estante := AABB()
	for forma: CollisionShape3D in _mueble(almacen, numero).get_node("StaticBody3D").get_children():
		if forma.disabled:
			continue
		var caja := forma.global_transform * forma.shape.get_debug_mesh().get_aabb()
		var es_estante := caja.size.y < 0.1 and caja.size.x > 0.4 and caja.size.z > 0.4
		if es_estante and caja.position.y > (frente["base_de_la_hoja"] as float):
			if estante.size == Vector3.ZERO or caja.position.y < estante.position.y:
				estante = caja
	assert_float(estante.size.x).is_greater(0.4)
	return estante


## Las cajas del volumen de `objeto`, en coordenadas del mundo.
static func _limites_del_volumen(objeto: Node3D) -> AABB:
	var limites := AABB()
	var primero := true
	for forma: CollisionShape3D in objeto.find_children("*", "CollisionShape3D", true, false):
		var suyo := forma.global_transform * forma.shape.get_debug_mesh().get_aabb()
		limites = suyo if primero else limites.merge(suyo)
		primero = false
	return limites


## Cuánto entró al volumen de la heladera, en metros: lo que su volumen pasó del plano del frente.
static func _entro_al_volumen(objeto: Node3D, frente: Dictionary) -> float:
	var direccion: Vector3 = frente["direccion"]
	var limites := _limites_del_volumen(objeto)
	var minimo := INF
	for esquina in 8:
		minimo = minf(minimo, limites.get_endpoint(esquina).dot(direccion))
	return (frente["plano"] as float) - minimo


static func _lado_de(caja: Node3D) -> float:
	return (caja.get_node("Cuerpo") as Node3D).scale.x


## Lo que el jugador suelta: una unidad sacada de una caja, y la caja grande.
func _que_se_suelta(almacen: Node3D) -> Array[Node3D]:
	var caja: Node3D = null
	for propia: Node3D in almacen.get("_cajas_de_productos"):
		if caja == null or _lado_de(propia) > _lado_de(caja):
			caja = propia
	var agarre: Agarre = almacen.get("_agarre")
	almacen.get("_reposicion_manual").call("retirar", PRODUCTO_QUE_SE_SUELTA)
	var unidad := agarre.cuerpo_sostenido()
	assert_object(unidad).is_not_null()
	assert_object(caja).is_not_null()
	agarre.vaciar_las_manos()
	return [unidad, caja]


## Le pone el foco al objetivo y le manda la acción, que es lo que hace el clic de verdad.
func _accion(jugador: Node3D, objetivo: Node3D, accion: StringName) -> void:
	jugador.set("_enfocado", objetivo)
	var evento := InputEventAction.new()
	evento.action = accion
	evento.pressed = true
	jugador.call("_unhandled_input", evento)


## Gira la vista como lo haría el mouse, a un yaw y un pitch absolutos en radianes.
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


func _apuntar(jugador: Node3D, punto: Vector3) -> void:
	var camara: Camera3D = jugador.get_node("Giro/Camara")
	var hacia := punto - camara.global_position
	_mirar(jugador, atan2(-hacia.x, -hacia.z), atan2(hacia.y, Vector2(hacia.x, hacia.z).length()))


## Adónde apunta el jugador: la rejilla de abajo del frente y, con la puerta abierta, la tapa del
## estante más bajo.
func _puntos_de_mira(frente: Dictionary, estante: AABB, abierta: bool) -> Array[Vector3]:
	var direccion: Vector3 = frente["direccion"]
	var centro: Vector3 = frente["centro"]
	var plano: float = frente["plano"]
	var puntos: Array[Vector3] = []
	for alto in ALTOS_DEL_ZOCALO:
		var altura := lerpf(frente["piso"] as float, frente["base_de_la_hoja"] as float, alto)
		puntos.append(
			Vector3(centro.x, altura, centro.z) + direccion * (plano - centro.dot(direccion))
		)
	if abierta:
		for adentro in ADENTRO_DEL_ESTANTE:
			var punto := estante.get_center()
			punto += direccion * (plano - punto.dot(direccion) - adentro)
			punto.y = estante.end.y + SOBRE_EL_ESTANTE
			puntos.append(punto)
	return puntos


## Suelta `objeto` como lo hace el jugador: parado frente a la heladera, con la mira en `punto` y el
## mismo clic que lo agarró. Devuelve si quedó suelto: lo que no encuentra lugar vuelve a la mano, y
## eso también es correcto.
func _soltar_apuntando_a(
	almacen: Node3D, objeto: Node3D, frente: Dictionary, punto: Vector3, parado: float
) -> bool:
	var jugador: CharacterBody3D = almacen.get("_jugador")
	var agarre: Agarre = almacen.get("_agarre")
	var direccion: Vector3 = frente["direccion"]
	var sobre_el_plano := punto + direccion * ((frente["plano"] as float) - punto.dot(direccion))
	jugador.global_position = (
		Vector3(sobre_el_plano.x, jugador.global_position.y, sobre_el_plano.z) + direccion * parado
	)
	agarre.vaciar_las_manos()
	_accion(jugador, objeto, ReglasDeLosObjetos.ACCION_AGARRAR)
	await get_tree().physics_frame
	_apuntar(jugador, punto)
	_accion(jugador, objeto, ReglasDeLosObjetos.ACCION_AGARRAR)
	for cuadro in CUADROS_DE_REPOSO:
		await get_tree().physics_frame
	return agarre.manos().sostenido() == null


## Lo soltado queda afuera del volumen de la heladera o apoyado en su estante de abajo, que es el
## borde de la hoja: nunca más abajo, en el hueco del fondo. Devuelve cuántas quedaron sueltas.
func _soltar_y_comprobar(almacen: Node3D, numero: int, abierta: bool) -> int:
	var frente := _frente_de(almacen, numero)
	var base: float = frente["base_de_la_hoja"]
	var estante := _estante_mas_bajo(almacen, numero, frente)
	var objetos := _que_se_suelta(almacen)
	if abierta:
		await _abrir(almacen, numero)
	var soltados := 0
	for objeto in objetos:
		for punto in _puntos_de_mira(frente, estante, abierta):
			for parado in PARADOS:
				if not await _soltar_apuntando_a(almacen, objeto, frente, punto, parado):
					continue
				soltados += 1
				var entro := _entro_al_volumen(objeto, frente)
				var debajo := base - _limites_del_volumen(objeto).position.y
				var donde := (
					"`%s`, `%s` apuntado a %v desde %.1f m"
					% [MUEBLES[numero], objeto.name, punto, parado]
				)
				(
					assert_bool(entro < TOLERANCIA or debajo < MARGEN_DE_LA_FORMA)
					. override_failure_message(
						(
							"%s bajó al hueco: entró %.3f m y apoya %.3f m abajo de la hoja"
							% [donde, entro, debajo]
						)
					)
					. is_true()
				)
	return soltados


func test_lo_soltado_apuntando_a_la_base_con_la_puerta_cerrada_no_queda_adentro() -> void:
	var almacen := await _almacen()
	var soltados := 0
	for numero in MUEBLES.size():
		soltados += await _soltar_y_comprobar(almacen, numero, false)
	# La premisa: el gesto suelta de verdad, y no sólo devuelve todo a la mano.
	assert_int(soltados).is_greater(0)


func test_lo_soltado_apuntando_a_la_heladera_abierta_no_baja_del_borde_de_la_hoja() -> void:
	var almacen := await _almacen()
	var soltados := 0
	# La heladera fuera de servicio tiene la puerta trabada: no abre.
	for numero in 2:
		soltados += await _soltar_y_comprobar(almacen, numero, true)
	assert_int(soltados).is_greater(0)
