extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.tscn")

## Cuánto puede separarse una unidad horneada de la copia sobre la que está parada, en metros.
const TOLERANCIA := 0.002


func test_solo_las_mallas_reemplazadas_son_geometria_de_referencia() -> void:
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	var estructura := almacen.get_node("Estructura")
	var puesto: Node3D = almacen.get("_reposicion_manual")
	var disposicion: DisposicionDeLaGondola = puesto.get("disposicion")
	var lugares := PackedVector3Array()
	for bloque: PackedFloat32Array in disposicion.principales + disposicion.guias:
		for indice: int in DisposicionDeLaGondola.copias(bloque):
			lugares.append(
				puesto.global_transform * DisposicionDeLaGondola.copia(bloque, indice).origin
			)
	var utiles: Array[String] = []
	for util: Node in almacen.get("_utiles_de_limpieza"):
		utiles.append(String(util.get("nodo_del_modelo")))
	var esperados: Array[String] = []
	for malla: MeshInstance3D in estructura.find_children("*", "MeshInstance3D", true, false):
		var reemplazada := String(estructura.get_path_to(malla)) in utiles
		for lugar: Vector3 in lugares:
			reemplazada = reemplazada or malla.global_position.distance_to(lugar) < TOLERANCIA
		if not reemplazada:
			continue
		esperados.append(String(almacen.get_path_to(malla)))
		assert_bool(malla.visible).is_false()
		for cuerpo: PhysicsBody3D in malla.find_children("*", "PhysicsBody3D", true, false):
			for forma: CollisionShape3D in cuerpo.find_children(
				"*", "CollisionShape3D", true, false
			):
				assert_bool(forma.disabled or cuerpo.collision_layer == 0).is_true()
	# La premisa no usa visible=false: identifica el surtido reemplazado por su disposición
	# y los cinco útiles por el modelo que declaran sus instancias de producción.
	assert_int(esperados.size()).is_equal(Catalogo.todos().size() + utiles.size())
	var marcados: Array[String] = []
	for geometria: GeometryInstance3D in almacen.find_children(
		"*", "GeometryInstance3D", true, false
	):
		if geometria.is_in_group(&"geometria_de_referencia"):
			marcados.append(String(almacen.get_path_to(geometria)))
	esperados.sort()
	marcados.sort()
	assert_array(marcados).is_equal(esperados)


func test_la_raiz_agrupa_por_rol_y_conserva_sus_enlaces() -> void:
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	assert_int(almacen.get_child_count()).is_less(10)
	for propiedad in almacen.get_property_list():
		if propiedad.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and propiedad.name.begins_with("_"):
			var valor: Variant = almacen.get(propiedad.name)
			assert_bool(valor != null).override_failure_message(propiedad.name).is_true()
	assert_int(almacen.get("_cajas_de_productos").size()).is_equal(Catalogo.todos().size())
	assert_int(almacen.get("_bolsas").size()).is_equal(3)


func test_los_puestos_reemplazados_usan_mallas_del_modelo() -> void:
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	for ruta: String in [
		"Estructura/base compu/StaticBody3D", "Estructura/gondolanueva/StaticBody3D"
	]:
		var cuerpo := almacen.get_node_or_null(ruta)
		assert_object(cuerpo).is_not_null()
		assert_bool(cuerpo.is_in_group("interactuable")).is_true()
		assert_bool(cuerpo.has_method("interactuar")).is_true()
		var mallas: Variant = cuerpo.get("mallas")
		assert_bool(mallas is Array and not mallas.is_empty()).is_true()
	assert_bool(almacen.has_node("Escritorio")).is_false()
	assert_bool(almacen.has_node("Estante")).is_false()


func test_la_computadora_tiene_apoyo_y_no_queda_tapada_por_otro_cuerpo() -> void:
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var cuerpo: StaticBody3D = almacen.get_node("Estructura/base compu/StaticBody3D")
	var apoyo: Node3D = almacen.get_node(cuerpo.get_meta("apoyo"))
	assert_object(apoyo).is_same(almacen.get_node("Estructura/EscritorioComputadora"))
	var espacio := almacen.get_world_3d().direct_space_state
	# **El rayo arranca un poco arriba del cuerpo, no en su origen.** El origen de `base compu`
	# cae exactamente sobre la tapa del escritorio, y un rayo que empieza en el plano de contacto
	# lo cruza sin registrarlo: medido el 2026-09-18, contestaba el piso del local, 0,82 m más
	# abajo.
	var consulta := PhysicsRayQueryParameters3D.create(
		cuerpo.global_position + Vector3.UP * 0.05, cuerpo.global_position + Vector3.DOWN * 0.05
	)
	consulta.exclude = [cuerpo.get_rid()]
	var golpe := espacio.intersect_ray(consulta)
	assert_dict(golpe).is_not_empty()
	assert_object(golpe.get("collider")).is_same(apoyo.get_node("StaticBody3D"))
	consulta = PhysicsRayQueryParameters3D.create(
		cuerpo.global_position + Vector3(0, 1, 1), cuerpo.global_position
	)
	golpe = espacio.intersect_ray(consulta)
	assert_object(golpe.get("collider")).is_same(cuerpo)


## Recorre el modelo entero y no una lista: una lista prueba sólo sus nodos, y no ve un nodo
## apagado de más.
func test_el_surtido_fijo_no_muestra_stock_que_el_dominio_no_tiene() -> void:
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	var puesto: Node3D = almacen.get_node("ReposicionManual")
	var disposicion: DisposicionDeLaGondola = puesto.get("disposicion")
	var lugares := PackedVector3Array()
	for bloque in disposicion.principales + disposicion.guias:
		for indice in DisposicionDeLaGondola.copias(bloque):
			lugares.append(
				puesto.global_transform * DisposicionDeLaGondola.copia(bloque, indice).origin
			)
	var estructura := almacen.get_node("Estructura")
	var contenido: Node3D = puesto.get("contenido")
	# La copia fija de cada útil de limpieza la dibuja el útil que se levanta: está apagada a
	# propósito, y eso lo cobra `utiles_de_limpieza_test.gd`.
	var de_los_utiles: Array[String] = []
	for util: Node in almacen.get("_utiles_de_limpieza"):
		de_los_utiles.append(String(util.get("nodo_del_modelo")))
	assert_int(de_los_utiles.size()).is_equal(5)
	for malla: MeshInstance3D in estructura.find_children("*", "MeshInstance3D", true, false):
		if contenido.is_ancestor_of(malla):
			continue
		var ruta := str(estructura.get_path_to(malla))
		if ruta in de_los_utiles:
			continue
		var oculta := false
		for lugar in lugares:
			oculta = oculta or malla.global_position.distance_to(lugar) < TOLERANCIA
		var falla := "se ve" if oculta else "está oculta fuera de la disposición"
		(
			assert_bool(malla.is_visible_in_tree())
			. override_failure_message("%s %s" % [ruta, falla])
			. is_equal(not oculta)
		)
		if oculta:
			for cuerpo: PhysicsBody3D in malla.find_children("*", "PhysicsBody3D", true, false):
				(
					assert_int(cuerpo.collision_layer)
					. override_failure_message("%s tiene colisión" % ruta)
					. is_zero()
				)
	for ruta: String in ["base compu", "gondolanueva"]:
		var malla: MeshInstance3D = estructura.get_node(ruta)
		assert_object(malla.mesh).is_instanceof(ArrayMesh)
