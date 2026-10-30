## Lo que se suelta contra la base de una heladera, entre el piso y la hoja, no entra al volumen.
extends GdUnitTestSuite

const AperturaConLugar := preload("res://test/escenas/apertura_con_lugar.gd")
const ALMACEN := preload("res://src/escenas/almacen.tscn")
const OBJETO_SUELTO := preload("res://src/escenas/objetos/objeto_agarrable.tscn")
const MUEBLES: Array[String] = ["heladeranueva", "heladeranueva_001", "heladera_fuera_de_servicio"]

## A qué fracción del zócalo, contando desde el piso, se tira cada rayo. La losa del fondo ya
## cierra lo más bajo del frente: los rayos pasan por encima de ella.
const ALTOS_DEL_ZOCALO: Array[float] = [0.15, 0.5, 0.95]

## Dónde se tira cada rayo a lo ancho, como fracción de la mitad del frente.
const LADOS_DEL_FRENTE: Array[float] = [-0.8, 0.0, 0.8]

## De qué lado del frente arranca cada rayo, y cuánto entra, en metros.
const ANTES_DEL_FRENTE := 0.5
const LARGO_DEL_RAYO := 1.2

## A cuántos metros del frente se pone lo que se empuja, y cuánto se lo empuja.
const CERCA := 0.02
const EMPUJON := 0.3

## Cuánto puede entrar lo empujado y contar igual como frenado, en metros.
const TOLERANCIA := 0.01

## Cuánto queda por debajo de la hoja lo que se apoya en su borde, en metros.
const DEBAJO_DE_LA_HOJA := 0.002

const CAPAS_TODAS := 0xFFFFFFFF


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


func _piso(almacen: Node3D) -> float:
	var suelo: CollisionShape3D = almacen.get_node("Estructura/SueloSolido/Local")
	return suelo.global_position.y + (suelo.shape as BoxShape3D).size.y / 2.0


func _abrir(almacen: Node3D, numero: int) -> void:
	_hoja(almacen, numero).get_node("CuerpoDeLaHoja").call("alternar")
	for cuadro in 60:
		await get_tree().physics_frame


## El frente de la heladera, medido en la escena: hacia dónde mira, dónde queda su plano y entre
## qué alturas queda abierto, del piso al borde de abajo de la hoja.
func _frente_de(almacen: Node3D, numero: int) -> Dictionary:
	var mueble := _mueble(almacen, numero)
	var cuerpo := mueble.global_transform * mueble.get_aabb()
	var hoja := _hoja(almacen, numero)
	var de_la_hoja := hoja.global_transform * hoja.get_aabb()
	var direccion := mueble.global_basis.x.normalized()
	var hacia_la_hoja := (de_la_hoja.get_center() - cuerpo.get_center()) * Vector3(1.0, 0.0, 1.0)
	var lado := direccion.cross(Vector3.UP)
	var frente := {
		"direccion": direccion,
		"lado": lado,
		"plano":
		(mueble.global_transform * Vector3(mueble.get_aabb().end.x, 0.0, 0.0)).dot(direccion),
		"centro": cuerpo.get_center(),
		"semiancho": absf(lado.dot(cuerpo.size)) / 2.0,
		"piso": _piso(almacen),
		"base_de_la_hoja": de_la_hoja.position.y,
	}
	# La premisa: el frente que se mide es el de la hoja, y debajo de ella hay lugar.
	assert_float(direccion.dot(hacia_la_hoja.normalized())).is_greater(0.9)
	assert_float(frente["base_de_la_hoja"] - frente["piso"]).is_greater(0.0)
	return frente


func _comprobar_que_el_frente_frena_los_rayos(almacen: Node3D, numero: int, estado: String) -> void:
	var frente := _frente_de(almacen, numero)
	var direccion: Vector3 = frente["direccion"]
	var lado: Vector3 = frente["lado"]
	var centro: Vector3 = frente["centro"]
	var plano: float = frente["plano"]
	var piso: float = frente["piso"]
	var base: float = frente["base_de_la_hoja"]
	var cuerpo := _mueble(almacen, numero).get_node("StaticBody3D")
	var espacio := almacen.get_world_3d().direct_space_state
	for alto in ALTOS_DEL_ZOCALO:
		for costado in LADOS_DEL_FRENTE:
			var sobre_el_plano := (
				Vector3(centro.x, lerpf(piso, base, alto), centro.z)
				+ direccion * (plano - centro.dot(direccion))
				+ lado * (frente["semiancho"] as float) * costado
			)
			var desde := sobre_el_plano + direccion * ANTES_DEL_FRENTE
			var consulta := PhysicsRayQueryParameters3D.create(
				desde, desde - direccion * LARGO_DEL_RAYO, CAPAS_TODAS
			)
			var golpe := espacio.intersect_ray(consulta)
			var donde := (
				"`%s` %s, a %.0f%% del zócalo y %.1f del ancho"
				% [MUEBLES[numero], estado, alto * 100.0, costado]
			)
			(
				assert_object(golpe.get("collider"))
				. override_failure_message(
					"%s, el rayo no encontró el cuerpo de la heladera" % donde
				)
				. is_same(cuerpo)
			)
			if golpe.is_empty():
				continue
			var entro: float = plano - (golpe["position"] as Vector3).dot(direccion)
			(
				assert_float(entro)
				. override_failure_message("%s, el rayo entró %.3f m al volumen" % [donde, entro])
				. is_less(TOLERANCIA)
			)


func test_el_frente_de_la_base_frena_lo_que_viene_de_afuera_con_la_puerta_cerrada() -> void:
	var almacen := await _almacen()
	for numero in MUEBLES.size():
		_comprobar_que_el_frente_frena_los_rayos(almacen, numero, "con la puerta cerrada")


func test_el_frente_de_la_base_frena_lo_que_viene_de_afuera_con_la_puerta_abierta() -> void:
	var almacen := await _almacen()
	# La heladera fuera de servicio tiene la puerta trabada: no abre.
	for numero in 2:
		await _abrir(almacen, numero)
		(
			assert_bool(_hoja(almacen, numero).get_node("CuerpoDeLaHoja").call("puerta").abierta())
			. is_true()
		)
		_comprobar_que_el_frente_frena_los_rayos(almacen, numero, "con la puerta abierta")


## Las cajas del volumen de `objeto`, en coordenadas del mundo.
static func _limites_del_volumen(objeto: Node3D) -> AABB:
	var limites := AABB()
	var primero := true
	for forma: CollisionShape3D in objeto.find_children("*", "CollisionShape3D", true, false):
		var suyo := forma.global_transform * forma.shape.get_debug_mesh().get_aabb()
		limites = suyo if primero else limites.merge(suyo)
		primero = false
	return limites


static func _minimo_sobre(limites: AABB, eje: Vector3) -> float:
	var minimo := INF
	for esquina in 8:
		minimo = minf(minimo, limites.get_endpoint(esquina).dot(eje))
	return minimo


## Pone a `objeto` quieto, a `CERCA` del frente de la heladera, centrado a lo ancho y con la base de
## su volumen a la altura pedida; después lo empuja hacia adentro. Devuelve cuánto avanzó.
func _empujar_contra_la_base(
	almacen: Node3D, objeto: PhysicsBody3D, numero: int, bajo_la_hoja: bool
) -> float:
	var frente := _frente_de(almacen, numero)
	var direccion: Vector3 = frente["direccion"]
	var lado: Vector3 = frente["lado"]
	var centro: Vector3 = frente["centro"]
	objeto.global_basis = Basis.IDENTITY
	if objeto.has_method("quedarse_quieta"):
		objeto.call("quedarse_quieta")
	else:
		(objeto as RigidBody3D).freeze = true
	var limites := _limites_del_volumen(objeto)
	var piso: float = frente["piso"]
	var base: float = frente["base_de_la_hoja"]
	# Pegado a la hoja es el borde: la parte de arriba del volumen toca su canto de abajo.
	var fondo := (
		base - DEBAJO_DE_LA_HOJA - limites.size.y if bajo_la_hoja else lerpf(piso, base, 0.15)
	)
	objeto.global_position += (
		direccion * ((frente["plano"] as float) + CERCA - _minimo_sobre(limites, direccion))
		+ lado * (centro.dot(lado) - limites.get_center().dot(lado))
		+ Vector3.UP * (fondo - limites.position.y)
	)
	await get_tree().physics_frame
	var consulta := PhysicsTestMotionParameters3D.new()
	consulta.from = objeto.global_transform
	consulta.motion = -direccion * EMPUJON
	var resultado := PhysicsTestMotionResult3D.new()
	if not PhysicsServer3D.body_test_motion(objeto.get_rid(), consulta, resultado):
		return EMPUJON
	return resultado.get_travel().length()


func test_una_unidad_empujada_contra_la_base_no_entra() -> void:
	var almacen := await _almacen()
	for numero in MUEBLES.size():
		for bajo_la_hoja: bool in [false, true]:
			var unidad: RigidBody3D = OBJETO_SUELTO.instantiate()
			almacen.add_child(unidad)
			var avance: float = await _empujar_contra_la_base(almacen, unidad, numero, bajo_la_hoja)
			(
				assert_float(avance)
				. override_failure_message(
					"`%s`, la unidad entró %.3f m al volumen" % [MUEBLES[numero], avance - CERCA]
				)
				. is_less(CERCA + TOLERANCIA)
			)
			unidad.queue_free()


static func _lado_de(caja: Node3D) -> float:
	return (caja.get_node("Cuerpo") as Node3D).scale.x


func test_una_caja_empujada_contra_la_base_no_entra_con_la_puerta_abierta() -> void:
	var almacen := await _almacen()
	var caja: Node3D = null
	for propia: Node3D in almacen.get("_cajas_de_productos"):
		if caja == null or _lado_de(propia) > _lado_de(caja):
			caja = propia
	assert_object(caja).is_not_null()
	# La caja grande es más alta que el zócalo: con la hoja cerrada la frenaría ella y no la base.
	for numero in 2:
		await _abrir(almacen, numero)
		var avance: float = await _empujar_contra_la_base(almacen, caja, numero, false)
		(
			assert_float(avance)
			. override_failure_message(
				"`%s`, la caja entró %.3f m al volumen" % [MUEBLES[numero], avance - CERCA]
			)
			. is_less(CERCA + TOLERANCIA)
		)
