## La red de seguridad en el almacén entero: adónde va lo que quedó adentro, y qué no cambia.
##
## **El lugar adentro de un sólido es el entretecho:** el volumen macizo entre el cielorraso del
## depósito y el techo. Mide casi tres metros de alto, así que ningún anillo alrededor de un objeto
## sale de él, y ningún piso queda debajo a menos de la caída que se busca.
extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.tscn")
const AperturaConLugar := preload("res://test/escenas/apertura_con_lugar.gd")

const ENTRETECHO := Vector3(2.0, 5.9, -11.0)

## Media caja grande, en metros.
const MEDIA_CAJA := 0.3037

## Un tramo opaco de la fachada, fuera de la ventanilla y del mostrador.
const PARED_LIBRE := Vector3(-1.9, 0.0, 6.28)
const METIDA_EN_LA_PARED := 0.05

## Dónde se arma la racha de empujones: piso libre del fondo.
const PISO_LIBRE := Vector3(4.49, 0.0, -10.0)


func _almacen() -> Node3D:
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	# Estos casos sacan unidades para usarlas de objeto. Abren con lugar para reponer, que es la
	# noche contra la que se midieron: sacar no lo pide (BR-STK-017).
	AperturaConLugar.abrir_con_todo_el_lugar(almacen)
	await get_tree().physics_frame
	almacen.get("_jugador").set_physics_process(false)
	return almacen


func _red(almacen: Node3D) -> RedDeSeguridad:
	return almacen.get_node("Servicios/RedDeSeguridad")


func _piso(almacen: Node3D) -> float:
	var suelo: CollisionShape3D = almacen.get_node("Estructura/SueloSolido/Local")
	return suelo.global_position.y + (suelo.shape as BoxShape3D).size.y / 2.0


func _caja(almacen: Node3D, id: Producto.Id) -> Node3D:
	return almacen.get("_cajas_de_productos")[id]


## Media caja, en metros: la escala del cubo de dos de su cuerpo, que sale del tamaño de la caja.
func _media(caja: Node3D) -> float:
	return (caja.get_node("Cuerpo") as Node3D).scale.x


## El estado de todas las tareas que un rescate podría tocar.
func _tareas(almacen: Node3D) -> Dictionary:
	var repositor: Repositor = almacen.get("_repositor")
	var gondola := {}
	for producto in Catalogo.todos():
		gondola[producto.id] = [
			repositor.estante().unidades_en_gondola(producto),
			repositor.estante().disponibles_para_retirar(producto),
		]
	var recolector: RecolectorDeBasura = almacen.get("_recolector")
	var piso: PisoDelLocal = (almacen.get("_limpiador") as Limpiador).piso()
	var manchas := {}
	for lugar: PisoDelLocal.Lugar in piso.lugares():
		manchas[lugar] = piso.mancha_de(lugar).esta_limpia()
	var hud: Node = almacen.get("_hud")
	return {
		"gondola": gondola,
		"bolsas": recolector.tarea().depositadas(),
		"manchas": manchas,
		"balde": piso.balde().agua(),
		"mopa": piso.mopa().agua(),
		"marcador": (hud.get("_tareas") as Label).text,
	}


func test_el_empujon_que_termino_adentro_se_deshace() -> void:  # AC-PLY-025
	var almacen: Node3D = await _almacen()
	var caja := _caja(almacen, Producto.Id.CHISITOS)
	caja.global_position = PISO_LIBRE + Vector3.UP * (_piso(almacen) + MEDIA_CAJA)
	caja.call("quedarse_quieta")
	var inicio := caja.global_position
	caja.emit_signal(ReglasDeLosObjetos.SENAL_EMPUJADA, caja)
	caja.global_position = ENTRETECHO
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_vector(caja.global_position).is_equal_approx(inicio, Vector3.ONE * 0.001)
	assert_int(_red(almacen).rescates.size()).is_equal(1)


func test_lo_soltado_adentro_va_al_piso_al_lado_del_jugador() -> void:  # AC-PLY-026
	var almacen: Node3D = await _almacen()
	var jugador: Node3D = almacen.get("_jugador")
	var agarre: Agarre = almacen.get("_agarre")
	almacen.get("_reposicion_manual").call("retirar", Producto.Id.MALBARDO)
	var unidad: RigidBody3D = agarre.soltar(true)
	unidad.global_position = ENTRETECHO
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_int(_red(almacen).rescates.size()).is_equal(1)
	assert_int(_red(almacen).rescates[0]["clase"]).is_equal(Rescate.Clase.DESHACER)
	var al_lado := Vector2(unidad.global_position.x, unidad.global_position.z).distance_to(
		Vector2(jugador.global_position.x, jugador.global_position.z)
	)
	assert_float(al_lado).is_less(1.2)
	assert_float(unidad.global_position.y).is_less(_piso(almacen) + 0.3)


func test_encima_de_la_caja_que_ocupa_el_origen() -> void:  # AC-PLY-027
	var almacen: Node3D = await _almacen()
	var caja := _caja(almacen, Producto.Id.ARVEJAS) as RigidBody3D
	var ocupante := _caja(almacen, Producto.Id.CHISITOS) as RigidBody3D
	var red := _red(almacen)
	# Arvejas ahora nace en el estante inferior: una caja grande puesta en su centro se
	# hunde en el tablero, y el estante siguiente impide apilar. Este caso necesita piso
	# libre y un origen ocupado con espacio encima, independientemente de la distribucion.
	var origen := Transform3D(
		caja.global_basis, PISO_LIBRE + Vector3.UP * (_piso(almacen) + _media(caja))
	)
	caja.set("_origen_en_el_mundo", origen)
	caja.global_position = ENTRETECHO
	ocupante.global_position = PISO_LIBRE + Vector3.UP * (_piso(almacen) + _media(ocupante))
	ocupante.call("quedarse_quieta")
	await get_tree().physics_frame
	assert_float(red.call("_hundido", ocupante, ocupante.global_transform)).is_less_equal(
		ReglasDeLosObjetos.ROCE
	)
	assert_bool(red.call("_apoyado", ocupante, ocupante.global_transform)).is_true()
	var consulta := PhysicsRayQueryParameters3D.create(
		origen.origin + Vector3.UP, origen.origin, caja.collision_mask
	)
	consulta.exclude = [caja.get_rid()]
	var golpe := caja.get_world_3d().direct_space_state.intersect_ray(consulta)
	assert_dict(golpe).is_not_empty()
	assert_object(golpe.get("collider")).is_same(ocupante)
	# Media caja de cada una, que no son del mismo tamaño: Arvejas va en caja chica.
	var alto := _media(caja) + _media(ocupante)
	var encima := origen
	encima.origin.y = ocupante.global_position.y + alto + ReglasDeLosObjetos.ROCE
	assert_float(red.call("_hundido", caja, encima)).is_less_equal(ReglasDeLosObjetos.ROCE)
	assert_bool(red.call("_apoyado", caja, encima)).is_true()
	red.revisar(caja)
	assert_int(red.rescates.size()).is_equal(1)
	assert_int(red.rescates[0]["clase"]).is_equal(Rescate.Clase.ENCIMA_DEL_ORIGEN)
	assert_float(caja.global_position.y - ocupante.global_position.y).is_equal_approx(alto, 0.01)


func test_el_origen_es_el_ultimo_recurso() -> void:  # AC-PLY-028
	var almacen: Node3D = await _almacen()
	var caja := _caja(almacen, Producto.Id.ARVEJAS)
	var origen: Transform3D = caja.call(ReglasDeLosObjetos.METODO_LUGAR_DE_ORIGEN)
	caja.global_position = ENTRETECHO
	_red(almacen).revisar(caja)
	assert_int(_red(almacen).rescates[0]["clase"]).is_equal(Rescate.Clase.ORIGEN)
	assert_vector(caja.global_position).is_equal_approx(origen.origin, Vector3.ONE * 0.001)


func test_sin_ningun_candidato_la_red_no_devuelve_a_la_mano() -> void:  # AC-PLY-029
	var almacen: Node3D = await _almacen()
	var jugador: Node3D = almacen.get("_jugador")
	var agarre: Agarre = almacen.get("_agarre")
	almacen.get("_reposicion_manual").call("retirar", Producto.Id.MALBARDO)
	var unidad: RigidBody3D = agarre.soltar(true)
	unidad.freeze = true
	unidad.global_position = ENTRETECHO
	jugador.global_position = ENTRETECHO + Vector3.RIGHT * 2.0
	_red(almacen).revisar(unidad)
	assert_int(_red(almacen).rescates[0]["clase"]).is_equal(Rescate.NINGUNO)
	assert_vector(unidad.global_position).is_equal(ENTRETECHO)
	assert_object(agarre.manos().sostenido()).is_null()


func test_rescatar_una_caja_y_una_unidad_no_mueve_la_mercaderia() -> void:  # AC-PLY-042
	var almacen: Node3D = await _almacen()
	var antes := _tareas(almacen)
	var caja := _caja(almacen, Producto.Id.ARVEJAS)
	caja.global_position = ENTRETECHO
	_red(almacen).revisar(caja)
	assert_dict(_tareas(almacen)).is_equal(antes)
	var agarre: Agarre = almacen.get("_agarre")
	almacen.get("_reposicion_manual").call("retirar", Producto.Id.MALBARDO)
	var unidad: RigidBody3D = agarre.soltar(true)
	var con_la_unidad := _tareas(almacen)
	unidad.global_position = ENTRETECHO
	_red(almacen).revisar(unidad)
	assert_int(_red(almacen).rescates.size()).is_equal(2)
	assert_dict(_tareas(almacen)).is_equal(con_la_unidad)
	assert_dict(con_la_unidad["gondola"]).is_not_equal(antes["gondola"])


## El caso de la trampa: una bolsa ya contada que entra en una pared se rescata cerca de donde
## entró. Ni se descuenta ni vuelve al baño, donde quedaría a la vista con la tarea cumplida.
func test_rescatar_las_bolsas_no_las_cuenta_ni_las_descuenta() -> void:  # AC-PLY-043
	var almacen: Node3D = await _almacen()
	var recolector: RecolectorDeBasura = almacen.get("_recolector")
	var bolsas: Array = almacen.get("_bolsas")
	var contada: RigidBody3D = bolsas[0]
	var sin_contar: RigidBody3D = bolsas[1]
	recolector.pedir_depositar(contada.call(ReglasDeLosObjetos.METODO_INTERACTUAR).id, 0.0)
	var antes := _tareas(almacen)
	var descarte: Node3D = almacen.get_node("Objetos/ZonaDeDescarte")
	for bolsa: RigidBody3D in [contada, sin_contar]:
		var origen: Transform3D = bolsa.call(ReglasDeLosObjetos.METODO_LUGAR_DE_ORIGEN)
		bolsa.freeze = true
		bolsa.global_basis = Basis.IDENTITY
		bolsa.global_position = Vector3(
			PARED_LIBRE.x, _piso(almacen) + 0.1, PARED_LIBRE.z + METIDA_EN_LA_PARED
		)
		_red(almacen).revisar(bolsa)
		assert_int(_red(almacen).rescates[-1]["clase"]).is_equal(Rescate.Clase.ALREDEDOR)
		assert_float(bolsa.global_position.distance_to(origen.origin)).is_greater(1.0)
		assert_float(bolsa.global_position.distance_to(descarte.global_position)).is_greater(
			descarte.call("radio")
		)
	assert_dict(_tareas(almacen)).is_equal(antes)
