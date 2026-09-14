## Las dos puertas cableadas en el almacén: que se las pueda tocar, que giren sobre su borde
## hacia adentro del cuarto, y que recién abiertas dejen pasar al jugador.
extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.tscn")

## Las dos hojas, con el tramo de 4,5 m que va desde piso libre del local hasta adentro del
## cuarto. La altura y el largo están medidos:
##
## **La cápsula no nace tocando el piso.** A 0,9 m `cast_motion` devolvía 0,37 aun con las hojas
## sin colisión: contaba el contacto con el suelo y el número dejaba de hablar de la puerta.
##
## **El tramo arranca lejos de la hoja a propósito.** Con 3 m arrancaba a 1,5 m de la puerta,
## justo donde estaba la fila de cajas de reposición, y el caso daba verde igual: `cast_motion`
## **ignora lo que ya está tocando la cápsula al partir**. Por eso `_avance()` afirma aparte que
## el arranque está libre.
const VANOS := {
	"Estructura/puerta": [Vector3(5.494, 1.05, -5.0), Vector3(5.494, 1.05, -9.5)],
	"Estructura/puerta_001": [Vector3(5.0, 1.05, -4.658), Vector3(9.5, 1.05, -4.658)],
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
		assert_float(await _avance(almacen, hoja)).is_less(0.7)
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


func test_la_hoja_abierta_entra_al_cuarto_y_no_al_local() -> void:
	# Es el caso que elige de qué lado gira cada hoja. Un rayo de borde a borde no lo puede
	# contestar: arranca pegado a la jamba y dice de qué lado nace la hoja, no dónde termina.
	# El muro tampoco elige: las cuatro combinaciones de bisagra y sentido dejan libre el
	# barrido de la hoja, que ya nace embutida en la jamba con el vano cerrado.
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	await get_tree().physics_frame
	for hoja: String in VANOS:
		almacen.get_node(hoja + "/StaticBody3D").call("interactuar")
	await _esperar_el_giro(almacen)
	for hoja: String in VANOS:
		# El tramo de `VANOS` va del local hacia adentro del cuarto: su dirección es la que la
		# hoja abierta tiene que seguir, y la hoja mide 1,72 m.
		var tramo: Array = VANOS[hoja]
		var bordes := _bordes(almacen.get_node(hoja))
		var adentro: float = (bordes[1] - bordes[0]).dot((tramo[1] - tramo[0]).normalized())
		assert_float(adentro).override_failure_message(hoja).is_greater(1.5)


## Los dos bordes verticales de la hoja, en coordenadas del mundo.
func _bordes(hoja: MeshInstance3D) -> Array[Vector3]:
	var caja := hoja.get_aabb()
	return [
		hoja.global_transform * Vector3(caja.position.x, 0.0, 0.0),
		hoja.global_transform * Vector3(caja.position.x + caja.size.x, 0.0, 0.0),
	]


## Qué fracción del tramo recorre una cápsula del tamaño del jugador antes de chocar.
##
## Afirma primero que el punto de partida está libre, y esa mitad no es de adorno: es la que
## `cast_motion` no mira. Ver el comentario de `VANOS`.
func _avance(almacen: Node3D, hoja: String) -> float:
	await get_tree().physics_frame
	var tramo: Array = VANOS[hoja]
	var forma := CapsuleShape3D.new()
	forma.radius = 0.4
	forma.height = 1.8
	var consulta := PhysicsShapeQueryParameters3D.new()
	consulta.shape = forma
	consulta.transform = Transform3D(Basis(), tramo[0])
	var espacio := almacen.get_world_3d().direct_space_state
	var estorbos: Array[String] = []
	for choque in espacio.intersect_shape(consulta, 8):
		estorbos.append(str(almacen.get_path_to(choque["collider"])))
	(
		assert_array(estorbos)
		. override_failure_message("%s: el tramo arranca contra %s" % [hoja, estorbos])
		. is_empty()
	)
	consulta.motion = tramo[1] - tramo[0]
	return espacio.cast_motion(consulta)[1]


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
