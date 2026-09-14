## Las dos puertas cableadas en el almacén: que se las pueda tocar, que giren sobre su borde y
## que recién abiertas dejen pasar al jugador.
extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.tscn")

## Las dos hojas, con el tramo de 3 m que cruza su vano. La altura evita que la cápsula nazca
## tocando el piso: ahí `cast_motion` devuelve la fracción segura y el número deja de hablar de
## la puerta.
const VANOS := {
	"Estructura/puerta": [Vector3(5.49, 1.05, -6.5), Vector3(5.49, 1.05, -9.5)],
	"Estructura/puerta_001": [Vector3(6.5, 1.05, -4.66), Vector3(9.5, 1.05, -4.66)],
}


func test_las_dos_puertas_cumplen_el_contrato_de_interaccion() -> void:  # 043-AC5
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	for hoja: String in VANOS:
		var cuerpo: StaticBody3D = almacen.get_node(hoja + "/StaticBody3D")
		assert_bool(cuerpo.is_in_group(ReglasDelJugador.GRUPO_INTERACTUABLE)).is_true()
		assert_bool(cuerpo.has_method("interactuar")).is_true()
		var mallas: Variant = cuerpo.get("mallas")
		assert_bool(mallas is Array and not mallas.is_empty()).is_true()


func test_interactuar_abre_la_puerta_y_no_se_la_lleva_en_la_mano() -> void:  # 043-AC6
	# Devolver un `ObjetoDelAlmacen` dejaría al clic del 006 cargándose la hoja entera.
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	for hoja: String in VANOS:
		var cuerpo: StaticBody3D = almacen.get_node(hoja + "/StaticBody3D")
		assert_object(cuerpo.call("interactuar")).is_null()
		assert_bool(cuerpo.call("puerta").abierta()).is_true()


func test_el_vano_se_cruza_solo_con_la_puerta_abierta() -> void:  # 043-AC7
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	await get_tree().physics_frame
	for hoja: String in VANOS:
		assert_float(await _avance(almacen, hoja)).is_less(0.5)
	for hoja: String in VANOS:
		almacen.get_node(hoja + "/StaticBody3D").call("interactuar")
	await _esperar_el_giro(almacen)
	for hoja: String in VANOS:
		assert_float(await _avance(almacen, hoja)).is_equal(1.0)


func test_la_hoja_gira_sobre_su_borde_y_no_sobre_su_centro() -> void:  # 043-AC8
	# Girando sobre el centro la hoja se mete media hoja en cada pared, y el vano queda tapado
	# por el canto en vez de libre.
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	await get_tree().physics_frame
	var antes := {}
	for hoja: String in VANOS:
		antes[hoja] = _bordes(almacen.get_node(hoja))
		almacen.get_node(hoja + "/StaticBody3D").call("interactuar")
	await _esperar_el_giro(almacen)
	for hoja: String in VANOS:
		var despues := _bordes(almacen.get_node(hoja))
		var quietos := 0
		var movidos := 0
		for indice in range(2):
			var corrimiento: float = antes[hoja][indice].distance_to(despues[indice])
			if corrimiento < 0.001:
				quietos += 1
			elif corrimiento > 1.0:
				movidos += 1
		assert_int(quietos).override_failure_message(hoja).is_equal(1)
		assert_int(movidos).override_failure_message(hoja).is_equal(1)


func test_la_hoja_abierta_no_se_mete_en_la_pared() -> void:  # 043-AC9
	# Es el caso que elige de qué lado cuelga cada hoja: el vano queda libre con las cuatro
	# combinaciones de bisagra y sentido, y tres de las cuatro dejan la hoja adentro del muro.
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	await get_tree().physics_frame
	for hoja: String in VANOS:
		almacen.get_node(hoja + "/StaticBody3D").call("interactuar")
	await _esperar_el_giro(almacen)
	var muro: StaticBody3D = almacen.get_node("Estructura/almacen/StaticBody3D")
	for hoja: String in VANOS:
		var bordes := _bordes(almacen.get_node(hoja), 0.6)
		var consulta := PhysicsRayQueryParameters3D.create(bordes[0], bordes[1])
		consulta.exclude = [almacen.get_node(hoja + "/StaticBody3D").get_rid()]
		var golpe := almacen.get_world_3d().direct_space_state.intersect_ray(consulta)
		assert_object(golpe.get("collider")).override_failure_message(hoja).is_not_same(muro)


## Los dos bordes verticales de la hoja, en coordenadas del mundo.
func _bordes(hoja: MeshInstance3D, altura := 0.0) -> Array[Vector3]:
	var caja := hoja.get_aabb()
	return [
		hoja.global_transform * Vector3(caja.position.x, altura, 0.0),
		hoja.global_transform * Vector3(caja.position.x + caja.size.x, altura, 0.0),
	]


## Qué fracción del tramo recorre una cápsula del tamaño del jugador antes de chocar.
func _avance(almacen: Node3D, hoja: String) -> float:
	await get_tree().physics_frame
	var tramo: Array = VANOS[hoja]
	var forma := CapsuleShape3D.new()
	forma.radius = 0.4
	forma.height = 1.8
	var consulta := PhysicsShapeQueryParameters3D.new()
	consulta.shape = forma
	consulta.transform = Transform3D(Basis(), tramo[0])
	consulta.motion = tramo[1] - tramo[0]
	return almacen.get_world_3d().direct_space_state.cast_motion(consulta)[1]


## Corre cuadros de física hasta que las dos hojas llegaron al tope, o se rinde.
func _esperar_el_giro(almacen: Node3D) -> void:
	for _cuadro in range(120):
		await get_tree().physics_frame
		var listas := 0
		for hoja: String in VANOS:
			var puerta: Puerta = almacen.get_node(hoja + "/StaticBody3D").call("puerta")
			if is_equal_approx(puerta.angulo(), Puerta.ANGULO_ABIERTA):
				listas += 1
		if listas == VANOS.size():
			return
