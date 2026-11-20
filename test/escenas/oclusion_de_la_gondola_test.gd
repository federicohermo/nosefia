## La oclusión de contacto de los productos acomodados en la góndola: base oscurecida en el shader
## y mancha en un `MultiMesh` por bloque, sincronizada con cada unidad que se saca o se repone.
extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.tscn")
const AperturaConLugar := preload("res://test/escenas/apertura_con_lugar.gd")
const OclusionDeContacto := preload("res://src/escenas/objetos/oclusion_de_contacto.gd")
const OclusionDeLaGondola := preload("res://src/escenas/puestos/oclusion_de_la_gondola.gd")

## La rampa de cabecera del plan: sube 14 cm en 60 cm.
const SUBIDA_DE_RAMPA := 0.14
const LARGO_DE_RAMPA := 0.60
const GROSOR_DE_RAMPA := 0.04


func _almacen_completo(jornada := ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA + 1) -> Node3D:
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	almacen.set("_partida", Partida.desde({"jornada": jornada, "medios": 0}))
	add_child(almacen)
	almacen.get("_jugador").set_physics_process(false)
	return almacen


func _oclusion_gondola(almacen: Node3D) -> Node3D:
	for nodo in get_tree().get_nodes_in_group(OclusionDeLaGondola.GRUPO):
		if almacen.is_ancestor_of(nodo):
			return nodo
	return null


func _materiales_del_grupo(grupo: MultiMeshInstance3D) -> Array[ShaderMaterial]:
	var lista: Array[ShaderMaterial] = []
	var malla := grupo.multimesh.mesh
	for superficie in malla.get_surface_count():
		var material := malla.surface_get_material(superficie) as ShaderMaterial
		if material != null:
			lista.append(material)
	return lista


func _transform_de_mancha(mm: MultiMesh, indice: int) -> Transform3D:
	var valores := mm.buffer
	var inicio := indice * OclusionDeLaGondola.FLOTANTES_POR_MANCHA
	return Transform3D(
		Basis(
			Vector3(valores[inicio], valores[inicio + 4], valores[inicio + 8]),
			Vector3(valores[inicio + 1], valores[inicio + 5], valores[inicio + 9]),
			Vector3(valores[inicio + 2], valores[inicio + 6], valores[inicio + 10])
		),
		Vector3(valores[inicio + 3], valores[inicio + 7], valores[inicio + 11])
	)


func _recorte_de_mancha(mm: MultiMesh, indice: int) -> Color:
	var valores := mm.buffer
	var inicio := indice * OclusionDeLaGondola.FLOTANTES_POR_MANCHA + 12
	return Color(valores[inicio], valores[inicio + 1], valores[inicio + 2], valores[inicio + 3])


func _posiciones_de_manchas(lote: MultiMeshInstance3D) -> Array[Vector3]:
	var lista: Array[Vector3] = []
	var mm := lote.multimesh
	for indice in mm.visible_instance_count:
		lista.append((lote.global_transform * _transform_de_mancha(mm, indice)).origin)
	return lista


func _hay_mancha_cerca(posiciones: Array[Vector3], punto: Vector3, tolerancia := 0.03) -> bool:
	for pos in posiciones:
		if (
			Vector2(pos.x - punto.x, pos.z - punto.z).length() <= tolerancia
			and absf(pos.y - punto.y) <= tolerancia
		):
			return true
	return false


func test_todos_los_bloques_oscurecen_su_base_y_dejan_mancha_sin_contorno_y_detras_del_vidrio(
) -> void:
	var almacen := _almacen_completo()
	var puesto: Node3D = almacen.get("_reposicion_manual")
	var estante: Estante = almacen.get("_repositor").estante()
	var oclusion := _oclusion_gondola(almacen)
	assert_object(oclusion).is_not_null()
	for producto in Catalogo.todos():
		var grupo: MultiMeshInstance3D = puesto.get_node("ProductosDe" + producto.nombre)
		for material in _materiales_del_grupo(grupo):
			(
				assert_bool(material.get_shader_parameter(OclusionDeContacto.LOCAL_DE_LA_MALLA))
				. is_true()
			)
			(
				assert_float(
					material.get_shader_parameter(OclusionDeContacto.PARAMETRO_DE_LA_MALLA)
				)
				. is_equal(oclusion.intensidad)
			)
			(
				assert_float(material.get_shader_parameter(OclusionDeContacto.ALCANCE_DE_LA_MALLA))
				. is_equal(oclusion.radio)
			)
		var sombras: MultiMeshInstance3D = oclusion.sombras_de(producto.id)
		assert_object(sombras).is_not_null()
		var ocupados := estante.casilleros_ocupados(producto).size()
		assert_int(sombras.multimesh.visible_instance_count).is_equal(ocupados)
		assert_bool(sombras.visible).is_equal(ocupados > 0)
		assert_bool(sombras.is_in_group(ReglasDeLosObjetos.GRUPO_SIN_CONTORNO)).is_true()
		var mat_sombra := sombras.material_override as ShaderMaterial
		assert_object(mat_sombra).is_not_null()
		assert_int(mat_sombra.render_priority).is_less(0)
	var vencidos: MultiMeshInstance3D = puesto.get_node("VencidosDeCindolor")
	for material in _materiales_del_grupo(vencidos):
		assert_bool(material.get_shader_parameter(OclusionDeContacto.LOCAL_DE_LA_MALLA)).is_true()
		(
			assert_float(material.get_shader_parameter(OclusionDeContacto.PARAMETRO_DE_LA_MALLA))
			. is_equal(oclusion.intensidad)
		)


func test_sacar_una_unidad_saca_su_mancha_reponerla_la_devuelve_y_los_huecos_no_tienen_mancha(
) -> void:
	var almacen := _almacen_completo()
	AperturaConLugar.abrir_con_faltantes(almacen, {Producto.Id.ACTRONCITO: 2})
	var puesto: Node3D = almacen.get("_reposicion_manual")
	var estante: Estante = almacen.get("_repositor").estante()
	var oclusion := _oclusion_gondola(almacen)
	var producto := Catalogo.de(Producto.Id.ACTRONCITO)
	var sombras: MultiMeshInstance3D = oclusion.sombras_de(producto.id)
	var vacios := estante.casilleros_vacios(producto)
	var ocupados := estante.casilleros_ocupados(producto)
	assert_int(vacios.size()).is_equal(2)
	assert_int(sombras.multimesh.visible_instance_count).is_equal(ocupados.size())
	var visibles_iniciales := _posiciones_de_manchas(sombras)
	for hueco: int in vacios:
		var pie_hueco: Vector3 = puesto.call("_apoyo", producto.id, hueco)
		assert_bool(_hay_mancha_cerca(visibles_iniciales, pie_hueco)).is_false()
	var sacado: int = ocupados[0]
	var pie_sacado: Vector3 = puesto.call("_apoyo", producto.id, sacado)
	assert_bool(_hay_mancha_cerca(visibles_iniciales, pie_sacado)).is_true()
	puesto.agarrar_de_la_gondola(producto.id, sacado)
	assert_int(sombras.multimesh.visible_instance_count).is_equal(ocupados.size() - 1)
	assert_bool(_hay_mancha_cerca(_posiciones_de_manchas(sombras), pie_sacado)).is_false()
	puesto.pedir_colocar(producto.id, sacado)
	assert_int(sombras.multimesh.visible_instance_count).is_equal(ocupados.size())
	assert_bool(_hay_mancha_cerca(_posiciones_de_manchas(sombras), pie_sacado)).is_true()


func test_los_vencidos_tienen_mancha_y_sacar_uno_la_quita() -> void:
	var almacen := _almacen_completo(ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA + 2)
	var puesto: Node3D = almacen.get("_reposicion_manual")
	var estante: Estante = almacen.get("_repositor").estante()
	var oclusion := _oclusion_gondola(almacen)
	var cindolor := Catalogo.de(Producto.Id.CINDOLOR)
	var vencidos := estante.vencidos.casilleros(cindolor)
	assert_array(vencidos).is_not_empty()
	var sombras: MultiMeshInstance3D = oclusion.sombras_de(cindolor.id)
	var ocupados_antes := estante.casilleros_ocupados(cindolor).size()
	assert_int(sombras.multimesh.visible_instance_count).is_equal(ocupados_antes)
	var casillero_vencido: int = vencidos[0]
	var pie_vencido: Vector3 = puesto.call("_apoyo", cindolor.id, casillero_vencido)
	assert_bool(_hay_mancha_cerca(_posiciones_de_manchas(sombras), pie_vencido)).is_true()
	puesto.agarrar_de_la_gondola(cindolor.id, casillero_vencido)
	assert_int(sombras.multimesh.visible_instance_count).is_equal(ocupados_antes - 1)
	assert_bool(_hay_mancha_cerca(_posiciones_de_manchas(sombras), pie_vencido)).is_false()


func test_cada_parte_se_prende_y_se_apaga_en_vivo_sin_afectar_a_la_otra() -> void:
	var almacen := _almacen_completo()
	var puesto: Node3D = almacen.get("_reposicion_manual")
	var oclusion := _oclusion_gondola(almacen)
	var grupo: MultiMeshInstance3D = puesto.get_node("ProductosDeActroncito")
	var sombras: MultiMeshInstance3D = oclusion.sombras_de(Producto.Id.ACTRONCITO)
	var mat_producto := _materiales_del_grupo(grupo)[0]
	var mat_sombra := sombras.material_override as ShaderMaterial
	oclusion.base_activa = false
	(
		assert_float(mat_producto.get_shader_parameter(OclusionDeContacto.PARAMETRO_DE_LA_MALLA))
		. is_zero()
	)
	assert_bool(sombras.visible).is_true()
	oclusion.base_activa = true
	(
		assert_float(mat_producto.get_shader_parameter(OclusionDeContacto.PARAMETRO_DE_LA_MALLA))
		. is_equal(oclusion.intensidad)
	)
	oclusion.manchas_activas = false
	assert_bool(sombras.visible).is_false()
	(
		assert_float(mat_producto.get_shader_parameter(OclusionDeContacto.PARAMETRO_DE_LA_MALLA))
		. is_equal(oclusion.intensidad)
	)
	oclusion.manchas_activas = true
	assert_bool(sombras.visible).is_true()
	var nuevo_radio := OclusionDeLaGondola.RADIO_POR_DEFECTO * 2.0
	var nueva_intensidad := OclusionDeLaGondola.INTENSIDAD_POR_DEFECTO / 2.0
	oclusion.radio = nuevo_radio
	oclusion.intensidad = nueva_intensidad
	(
		assert_float(mat_producto.get_shader_parameter(OclusionDeContacto.ALCANCE_DE_LA_MALLA))
		. is_equal(nuevo_radio)
	)
	(
		assert_float(mat_producto.get_shader_parameter(OclusionDeContacto.PARAMETRO_DE_LA_MALLA))
		. is_equal(nueva_intensidad)
	)
	assert_float(mat_sombra.get_shader_parameter(&"suavidad")).is_equal(nuevo_radio)
	assert_float(mat_sombra.get_shader_parameter(&"intensidad")).is_equal_approx(
		nueva_intensidad * OclusionDeContacto.OPACIDAD_MAXIMA, 0.001
	)


func test_una_unidad_suelta_y_una_acomodada_comparten_forma_y_la_gondola_usa_sus_valores() -> void:
	var almacen := _almacen_completo()
	var puesto: Node3D = almacen.get("_reposicion_manual")
	var agarre: Agarre = almacen.get("_agarre")
	var estante: Estante = almacen.get("_repositor").estante()
	var oclusion := _oclusion_gondola(almacen)
	var id := Producto.Id.ACTRONCITO
	var ocupados := estante.casilleros_ocupados(Catalogo.de(id))
	var casillero: int = ocupados[0]
	var copia: Transform3D = (
		puesto.global_transform * puesto.call("_copia_del_casillero", id, casillero)
	)
	var pie: Vector3 = puesto.call("_apoyo", id, casillero)
	puesto.agarrar_de_la_gondola(id, casillero)
	var suelta: RigidBody3D = agarre.soltar(true)
	await get_tree().physics_frame
	suelta.freeze = true
	var malla_suelta: MeshInstance3D = suelta.get_node("Malla")
	var aabb_suelta := malla_suelta.mesh.get_aabb()
	var centro_en_cuerpo: Vector3 = malla_suelta.position + aabb_suelta.get_center()
	var base_en_cuerpo: float = malla_suelta.position.y + aabb_suelta.position.y
	suelta.global_transform = Transform3D(
		copia.basis,
		pie - copia.basis * Vector3(centro_en_cuerpo.x, base_en_cuerpo, centro_en_cuerpo.z)
	)
	var oclusion_suelta: Node3D = suelta.get("oclusion")
	assert_object(oclusion_suelta).is_not_null()
	oclusion_suelta.actualizar()
	assert_bool(oclusion_suelta.sombra.visible).is_true()
	var mat_suelta := oclusion_suelta.sombra.material_override as ShaderMaterial
	var mat_gondola := oclusion.sombras_de(id).material_override as ShaderMaterial
	assert_float(mat_gondola.get_shader_parameter(&"esquinas")).is_equal_approx(
		mat_suelta.get_shader_parameter(&"esquinas"), 0.001
	)
	var huella_suelta: Vector2 = mat_suelta.get_shader_parameter(&"huella")
	var huella_gondola: Vector2 = mat_gondola.get_shader_parameter(&"huella")
	assert_vector(huella_gondola).is_equal_approx(huella_suelta, Vector2.ONE * 0.002)
	var radio_gondola: float = oclusion.radio
	var intensidad_gondola: float = oclusion.intensidad
	assert_float(radio_gondola).is_equal(OclusionDeLaGondola.RADIO_POR_DEFECTO)
	assert_float(intensidad_gondola).is_equal(OclusionDeLaGondola.INTENSIDAD_POR_DEFECTO)
	assert_float(oclusion_suelta.radio).is_equal(radio_gondola)
	assert_float(oclusion_suelta.intensidad).is_equal(intensidad_gondola)
	assert_float(mat_gondola.get_shader_parameter(&"suavidad")).is_equal(radio_gondola)
	assert_float(mat_suelta.get_shader_parameter(&"suavidad")).is_equal_approx(radio_gondola, 0.002)
	assert_float(mat_gondola.get_shader_parameter(&"intensidad")).is_equal_approx(
		intensidad_gondola * OclusionDeContacto.OPACIDAD_MAXIMA, 0.001
	)
	assert_float(mat_suelta.get_shader_parameter(&"intensidad")).is_equal_approx(
		mat_gondola.get_shader_parameter(&"intensidad"), 0.005
	)
	var tamano_esperado: Vector2 = huella_gondola * 2.0 + Vector2.ONE * (radio_gondola * 2.0)
	var tamano_gondola: Vector2 = mat_gondola.get_shader_parameter(&"tamano")
	assert_vector(tamano_gondola).is_equal_approx(tamano_esperado, Vector2.ONE * 0.001)


func test_en_una_rampa_inclinada_la_mancha_sigue_la_pendiente_y_se_corta_en_el_borde() -> void:
	var inclinacion := atan2(SUBIDA_DE_RAMPA, LARGO_DE_RAMPA)
	var normal := Vector3.UP.rotated(Vector3.RIGHT, inclinacion)
	var rampa: StaticBody3D = auto_free(StaticBody3D.new())
	var forma := CollisionShape3D.new()
	var caja := BoxShape3D.new()
	caja.size = Vector3(1.0, GROSOR_DE_RAMPA, LARGO_DE_RAMPA)
	forma.shape = caja
	rampa.add_child(forma)
	add_child(rampa)
	rampa.global_transform = Transform3D(
		Basis(Vector3.RIGHT, inclinacion), -normal * (GROSOR_DE_RAMPA / 2.0)
	)
	await get_tree().physics_frame
	var bloque_malla := BoxMesh.new()
	bloque_malla.size = Vector3(0.12, 0.16, 0.10)
	var malla_prod := ArrayMesh.new()
	malla_prod.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, bloque_malla.get_mesh_arrays())
	# Apoyado cerca del borde delantero de la rampa: la mancha no puede colgar más allá del canto.
	var borde_adelante := LARGO_DE_RAMPA / 2.0
	var distancia_al_borde := 0.01
	var desplazamiento_z := borde_adelante - bloque_malla.size.z / 2.0 - distancia_al_borde
	var eje_z := Vector3.RIGHT.cross(normal).normalized()
	var centro_en_rampa := eje_z * desplazamiento_z + normal * (bloque_malla.size.y / 2.0)
	var copia := Transform3D(Basis(Vector3.RIGHT, inclinacion), centro_en_rampa)
	var b := copia.basis
	var o := copia.origin
	var bloque := PackedFloat32Array(
		[b.x.x, b.y.x, b.z.x, o.x, b.x.y, b.y.y, b.z.y, o.y, b.x.z, b.y.z, b.z.z, o.z]
	)
	var oclusion: Node3D = auto_free(OclusionDeLaGondola.new())
	add_child(oclusion)
	var sin_materiales: Array[ShaderMaterial] = []
	oclusion.preparar_bloque(0, "Rampa", malla_prod, sin_materiales, Basis.IDENTITY, bloque)
	oclusion.sincronizar(0, [0], 1)
	var sombras: MultiMeshInstance3D = oclusion.sombras_de(0)
	assert_bool(sombras.visible).is_true()
	var t := sombras.global_transform * _transform_de_mancha(sombras.multimesh, 0)
	assert_vector(t.basis.y.normalized()).is_equal_approx(normal, Vector3.ONE * 0.005)
	var esperado := eje_z * desplazamiento_z + normal * OclusionDeContacto.ELEVACION
	assert_vector(t.origin).is_equal_approx(esperado, Vector3.ONE * 0.005)
	var recorte := _recorte_de_mancha(sombras.multimesh, 0)
	# Hacia adelante el estante termina a mitad del producto + 1 cm (mucho menos que mitad + radio).
	var tope_adelante := bloque_malla.size.z / 2.0 + distancia_al_borde
	assert_float(recorte.a).is_equal_approx(tope_adelante, 0.005)


func test_cambiar_de_jornada_rearma_las_manchas_sin_dejar_nodos_viejos() -> void:
	var almacen := _almacen_completo(ReglasDeLaPartida.PRIMERA_JORNADA)
	var oclusion := _oclusion_gondola(almacen)
	assert_object(oclusion).is_not_null()
	almacen.call("_al_abrir_la_jornada", ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA + 1)
	await get_tree().process_frame
	var estante: Estante = almacen.get("_repositor").estante()
	assert_int(oclusion.get_child_count()).is_equal(Catalogo.todos().size())
	for producto in Catalogo.todos():
		var sombras: MultiMeshInstance3D = oclusion.sombras_de(producto.id)
		assert_int(sombras.multimesh.visible_instance_count).is_equal(
			estante.casilleros_ocupados(producto).size()
		)
