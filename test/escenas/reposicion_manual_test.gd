extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.tscn")
const AperturaConLugar := preload("res://test/escenas/apertura_con_lugar.gd")


func test_vender_no_cambia_lo_que_la_gondola_dibuja() -> void:  # AC-CTR-015
	# La venta sale del depósito. Un dibujo que bajara al vender mostraría un estante que el
	# inventario da por lleno, y el jugador repondría lo que no falta.
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	# El cobro automático continúa en las jornadas posteriores a la primera.
	almacen.call("_al_abrir_la_jornada", 2)
	almacen.get("_jugador").set_physics_process(false)
	var presentacion: Node3D = almacen.get("_reposicion_manual")
	var repositor: Repositor = almacen.get("_repositor")
	var cupo_total := 0
	for producto in Catalogo.todos():
		cupo_total += repositor.estante().cupo(producto)
		var falta := (
			repositor.estante().cupo(producto) - repositor.estante().unidades_en_gondola(producto)
		)
		for indice in falta:
			presentacion.retirar(producto.id)
			presentacion.pedir_colocar(producto.id)
	var atenciones: Ventanilla = almacen.get("_atenciones")
	atenciones.pedir_abrir()
	atenciones.pedir_cobrar()
	await get_tree().process_frame
	assert_bool(atenciones.atencion().vendida()).is_true()
	var posiciones: Array[Vector3] = []
	for producto in Catalogo.todos():
		var grupo: MultiMeshInstance3D = presentacion.get_node("ProductosDe" + producto.nombre)
		assert_int(grupo.multimesh.visible_instance_count).is_equal(grupo.multimesh.instance_count)
		for indice in repositor.estante().cupo(producto):
			var posicion := (
				(
					grupo.global_transform
					* _transformacion_de_copia(grupo.multimesh, _guia(almacen, producto) + indice)
				)
				. origin
			)
			assert_array(posiciones).not_contains(posicion)
			posiciones.append(posicion)
	assert_int(posiciones.size()).is_equal(cupo_total)


func test_recoger_del_grupo_del_piso_conserva_foco_identidad_y_reposicion() -> void:
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	AperturaConLugar.abrir_con_todo_el_lugar(almacen)
	almacen.get("_jugador").set_physics_process(false)
	var presentacion: Node3D = almacen.get("_reposicion_manual")
	var agarre: Agarre = almacen.get("_agarre")
	var producto := Catalogo.de(Producto.Id.LAYSNTT)
	var grupo: MultiMeshInstance3D = presentacion.get_node_or_null("SueltosDe" + producto.nombre)
	assert_object(grupo).is_not_null()
	if grupo == null:
		return
	var cuerpos: Array[RigidBody3D] = []
	for indice in 3:
		presentacion.call("retirar", producto.id)
		var cuerpo: RigidBody3D = agarre.soltar(true)
		cuerpo.global_position = Vector3(indice * 0.5, 2, -6)
		cuerpos.append(cuerpo)
	for cuadro in 120:
		await get_tree().physics_frame
	assert_int(grupo.multimesh.visible_instance_count).is_equal(3)
	for cuerpo in cuerpos:
		assert_float(cuerpo.global_position.y).is_greater(0.0)
		assert_bool(cuerpo.get_node("Malla").visible).is_false()
	var marco: MarcoDelObjetivo = auto_free(MarcoDelObjetivo.new())
	add_child(marco)
	marco.enfocar(cuerpos[1])
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_bool(cuerpos[1].get_node("Malla").visible).is_true()
	assert_bool(cuerpos[0].get_node("Malla").visible).is_false()
	var identidad: UnidadDeProducto = cuerpos[1].datos
	assert_bool(agarre.pedir_agarrar(identidad, cuerpos[1])).is_true()
	assert_object(agarre.manos().sostenido()).is_same(identidad)
	assert_int(grupo.multimesh.visible_instance_count).is_equal(2)
	assert_bool(cuerpos[1].get_node("Malla").visible).is_true()
	marco.apagar()
	presentacion.call("pedir_colocar", producto.id)
	assert_int(almacen.get("_repositor").estante().unidades_en_gondola(producto)).is_equal(1)
	presentacion.call("retirar", Producto.Id.BURBALOO)
	assert_object(agarre.punto_de_producto.get_child(0)).is_same(cuerpos[1])
	agarre.soltar(true)
	assert_int(grupo.multimesh.visible_instance_count).is_equal(2)
	almacen.call("_al_abrir_la_jornada", 2)
	await get_tree().process_frame
	assert_int(grupo.multimesh.visible_instance_count).is_zero()
	for cuerpo in cuerpos:
		assert_bool(is_instance_valid(cuerpo)).is_false()


func test_laysntt_no_atraviesa_el_suelo_al_caer_plana_y_recibir_otras_cajas() -> void:
	for giro: float in [0.8, 1.6, 5.6]:
		var almacen: Node3D = auto_free(ALMACEN.instantiate())
		add_child(almacen)
		AperturaConLugar.abrir_con_todo_el_lugar(almacen)
		almacen.get("_jugador").set_physics_process(false)
		var agarre: Agarre = almacen.get("_agarre")
		var bolsas: Array[RigidBody3D] = []
		for turno in 9:
			var id := Producto.Id.LAYSNTT if turno < 3 else Producto.Id.BURBALOO
			almacen.get("_reposicion_manual").retirar(id)
			var cuerpo: RigidBody3D = agarre.soltar(true)
			cuerpo.global_position = Vector3(0.6, 1.7, -5.7)
			cuerpo.rotation = Vector3(PI / 2, giro, 0)
			if turno < 3:
				bolsas.append(cuerpo)
			for cuadro in 120:
				await get_tree().physics_frame
				for bolsa in bolsas:
					assert_float(bolsa.global_position.y).is_greater(0.0)
					if bolsa.global_position.y <= 0.0:
						return
		for bolsa in bolsas:
			assert_float(bolsa.global_position.y).is_greater(0.1)
			assert_bool(bolsa.is_visible_in_tree()).is_true()
			assert_bool(agarre.pedir_agarrar(bolsa.datos, bolsa)).is_true()
			almacen.get("_reposicion_manual").pedir_colocar(Producto.Id.LAYSNTT)
		(
			assert_int(
				almacen.get("_repositor").estante().unidades_en_gondola(
					Catalogo.de(Producto.Id.LAYSNTT)
				)
			)
			. is_equal(3)
		)
		almacen.queue_free()
		await get_tree().process_frame


func test_el_burbaloo_del_piso_no_bloquea_al_jugador() -> void:
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	AperturaConLugar.abrir_con_todo_el_lugar(almacen)
	var jugador: CharacterBody3D = almacen.get("_jugador")
	jugador.set_physics_process(false)
	jugador.global_position = Vector3(0, 0.5, -5.8)
	var agarre: Agarre = almacen.get("_agarre")
	almacen.get("_reposicion_manual").retirar(Producto.Id.BURBALOO)
	var cuerpo: RigidBody3D = agarre.soltar(true)
	cuerpo.global_position = jugador.global_position + Vector3(1, 0.2, 0)
	await get_tree().physics_frame
	assert_bool(jugador.test_move(jugador.global_transform, Vector3(1.5, 0, 0))).is_false()
	cuerpo.remove_collision_exception_with(jugador)
	assert_bool(jugador.test_move(jugador.global_transform, Vector3(1.5, 0, 0))).is_true()
	cuerpo.add_collision_exception_with(jugador)
	assert_int(cuerpo.collision_mask).is_equal(1 | ReglasDeLosObjetos.CAPA_DEL_CONTORNO)
	assert_bool(agarre.pedir_agarrar(cuerpo.datos, cuerpo)).is_true()


func test_laysntt_y_jorgillo_quedan_sobre_el_suelo_al_mover_la_camara() -> void:
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	await get_tree().physics_frame
	var jugador: CharacterBody3D = almacen.get("_jugador")
	jugador.set_physics_process(false)
	var camara: Camera3D = jugador.get_node("Giro/Camara")
	var agarre: Agarre = almacen.get("_agarre")
	var sueltas: Array[RigidBody3D] = []
	AperturaConLugar.abrir_con_todo_el_lugar(almacen)
	var estante: Estante = almacen.get("_repositor").estante()
	# Tantas como casilleros vacíos: al final se colocan todas, y la caja da más que eso.
	for id: Producto.Id in [Producto.Id.LAYSNTT, Producto.Id.JORGILLO]:
		var producto := Catalogo.de(id)
		for indice in estante.cupo(producto) - estante.unidades_en_gondola(producto):
			almacen.get("_reposicion_manual").retirar(id)
			var cuerpo: RigidBody3D = agarre.soltar(true)
			cuerpo.global_position = Vector3(-1.2 + indice * 0.6, 1.5, -5.8 + (id % 2) * 0.5)
			sueltas.append(cuerpo)
	for cuadro in 300:
		camara.rotation = Vector3(sin(cuadro * 0.1), cuadro * 0.03, 0)
		jugador.position.x = sin(cuadro * 0.1)
		await get_tree().physics_frame
		for cuerpo in sueltas:
			assert_float(cuerpo.global_position.y).is_greater(0.0)
			assert_float(cuerpo.global_position.y).is_less(1.6)
	for cuerpo in sueltas:
		assert_float(cuerpo.linear_velocity.length()).is_less(0.1)
		assert_bool(cuerpo.is_visible_in_tree()).is_true()
		var vista: MeshInstance3D = cuerpo.get_node("Malla")
		var limites := vista.global_transform * vista.mesh.get_aabb()
		var mancha: MeshInstance3D = almacen.get_node(
			"LimpiezaDelAlmacen/ManchaEntreLasGondolas/Malla"
		)
		var limites_mancha := mancha.global_transform * mancha.mesh.get_aabb()
		assert_float(limites.end.y).is_greater(limites_mancha.end.y)
		assert_bool(agarre.pedir_agarrar(cuerpo.datos, cuerpo)).is_true()
		almacen.get("_reposicion_manual").pedir_colocar(cuerpo.datos.producto.id)


func test_los_estantes_agrupan_las_unidades_sin_cuerpos_por_producto() -> void:
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	var presentacion: Node3D = almacen.get("_reposicion_manual")
	var grupos := presentacion.find_children("ProductosDe*", "MultiMeshInstance3D", true, false)
	assert_int(grupos.size()).is_equal(Catalogo.todos().size())
	# Al abrir se ven la guía y lo que la góndola tiene puesto: la fila menos lo que falta.
	var al_abrir: Estante = almacen.get("_repositor").estante()
	for indice in grupos.size():
		var grupo: MultiMeshInstance3D = grupos[indice]
		var producto := Catalogo.todos()[indice]
		assert_int(grupo.multimesh.visible_instance_count).is_equal(
			_guia(almacen, producto) + al_abrir.unidades_en_gondola(producto)
		)
	AperturaConLugar.abrir_con_todo_el_lugar(almacen)
	var estante: Estante = almacen.get("_repositor").estante()
	var agarre: Agarre = almacen.get("_agarre")
	for producto in Catalogo.todos():
		var grupo: MultiMeshInstance3D = presentacion.get_node("ProductosDe" + producto.nombre)
		var antes := estante.unidades_en_gondola(producto)
		for indice in estante.cupo(producto) - antes:
			presentacion.call("retirar", producto.id)
			assert_object(agarre.manos().sostenido()).is_not_null()
			presentacion.call("pedir_colocar", producto.id)
			assert_int(grupo.multimesh.visible_instance_count).is_equal(
				_guia(almacen, producto) + antes + indice + 1
			)
		assert_int(grupo.get_child_count()).is_zero()
	assert_int(presentacion.find_children("*", "RigidBody3D", true, false).size()).is_equal(1)


func test_reutiliza_el_cuerpo_al_depositar_y_cambia_de_producto() -> void:
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	AperturaConLugar.abrir_con_todo_el_lugar(almacen)
	var presentacion: Node3D = almacen.get("_reposicion_manual")
	var agarre: Agarre = almacen.get("_agarre")
	presentacion.call("retirar", Producto.Id.ACTRONCITO)
	var cuerpo := agarre.punto_de_producto.get_child(0)
	var anterior: Resource = cuerpo.datos
	presentacion.call("pedir_colocar", Producto.Id.ACTRONCITO)
	assert_bool(cuerpo.is_visible_in_tree()).is_false()
	assert_int(cuerpo.collision_layer).is_zero()
	presentacion.call("retirar", Producto.Id.JORGILLO)
	assert_object(agarre.punto_de_producto.get_child(0)).is_same(cuerpo)
	assert_object(cuerpo.datos).is_not_same(anterior)
	assert_int(cuerpo.datos.producto.id).is_equal(Producto.Id.JORGILLO)
	var suelto: RigidBody3D = agarre.soltar(true)
	assert_bool(suelto.freeze).is_false()
	assert_int(suelto.collision_layer).is_equal(1)
	assert_int(suelto.collision_mask).is_equal(1 | ReglasDeLosObjetos.CAPA_DEL_CONTORNO)


func test_las_unidades_sueltas_caen_y_se_recuperan_sin_perder_su_reserva() -> void:
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	almacen.get("_jugador").set_physics_process(false)
	AperturaConLugar.abrir_con_todo_el_lugar(almacen)
	var presentacion: Node3D = almacen.get("_reposicion_manual")
	var agarre: Agarre = almacen.get("_agarre")
	var estante: Estante = almacen.get("_repositor").estante()
	var producto := Catalogo.de(Producto.Id.MALBARDO)
	var antes := estante.unidades_en_gondola(producto)
	var sueltas: Array[RigidBody3D] = []
	for indice in estante.disponibles_para_retirar(producto):
		presentacion.call("retirar", producto.id)
		var cuerpo: RigidBody3D = agarre.soltar(true)
		cuerpo.global_position = Vector3(indice, 2, -6)
		sueltas.append(cuerpo)
		assert_bool(cuerpo.freeze).is_false()
		assert_int(cuerpo.collision_layer).is_equal(1)
	assert_object(sueltas[0]).is_not_same(sueltas[1])
	for cuadro in 12:
		await get_tree().physics_frame
	assert_float(sueltas[0].global_position.y).is_less(2.0)
	assert_float(sueltas[1].global_position.y).is_less(2.0)
	presentacion.call("retirar", producto.id)
	assert_object(agarre.manos().sostenido()).is_null()
	assert_int(estante.disponibles_para_retirar(producto)).is_zero()
	var identidad: UnidadDeProducto = sueltas[0].datos
	assert_bool(agarre.pedir_agarrar(identidad, sueltas[0])).is_true()
	assert_object(agarre.manos().sostenido()).is_same(identidad)
	presentacion.call("pedir_colocar", Producto.Id.ACTRONCITO)
	assert_object(agarre.manos().sostenido()).is_same(identidad)
	presentacion.call("pedir_colocar", producto.id)
	assert_int(estante.unidades_en_gondola(producto)).is_equal(antes + 1)
	assert_int(estante.disponibles_para_retirar(producto)).is_zero()
	# Se recorren las que quedan y no sólo la segunda: el cupo sale del modelo y se mueve.
	for indice in range(1, sueltas.size()):
		assert_bool(sueltas[indice].is_visible_in_tree()).is_true()
		assert_bool(sueltas[indice].freeze).is_false()
		assert_bool(agarre.pedir_agarrar(sueltas[indice].datos, sueltas[indice])).is_true()
		presentacion.call("pedir_colocar", producto.id)
	assert_int(estante.unidades_en_gondola(producto)).is_equal(estante.cupo(producto))
	# Salió la caja entera, aunque la fila tenga menos casilleros (BR-STK-017): las que no
	# entraron siguen afuera, y ninguna perdió su lugar en la cuenta.
	assert_int(estante.reservadas(producto)).is_equal(
		sueltas.size() - (estante.cupo(producto) - antes)
	)


func test_otra_jornada_vacia_grupos_mano_y_productos_sueltos() -> void:
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	AperturaConLugar.abrir_con_todo_el_lugar(almacen)
	var presentacion: Node3D = almacen.get("_reposicion_manual")
	var agarre: Agarre = almacen.get("_agarre")
	presentacion.call("retirar", Producto.Id.ACTRONCITO)
	presentacion.call("pedir_colocar", Producto.Id.ACTRONCITO)
	presentacion.call("retirar", Producto.Id.ACTRONCITO)
	var suelta := agarre.soltar(true)
	presentacion.call("retirar", Producto.Id.JORGILLO)
	var sostenida := agarre.punto_de_producto.get_child(0)
	almacen.call("_al_abrir_la_jornada", 2)
	await get_tree().process_frame
	assert_bool(is_instance_valid(suelta)).is_false()
	assert_bool(is_instance_valid(sostenida)).is_false()
	assert_object(agarre.manos().sostenido()).is_null()
	assert_int(agarre.punto_de_producto.get_child_count()).is_zero()
	# La noche nueva abre con lo que dice su jornada, no con lo que quedó de la anterior.
	var estante: Estante = almacen.get("_repositor").estante()
	for producto in Catalogo.todos():
		var grupo: MultiMeshInstance3D = presentacion.get_node("ProductosDe" + producto.nombre)
		assert_int(grupo.multimesh.visible_instance_count).is_equal(
			_guia(almacen, producto) + estante.unidades_en_gondola(producto)
		)
	for grupo: MultiMeshInstance3D in presentacion.find_children(
		"SueltosDe*", "MultiMeshInstance3D", true, false
	):
		assert_int(grupo.multimesh.visible_instance_count).is_zero()
	presentacion.call("retirar", Producto.Id.ACTRONCITO)
	assert_object(agarre.manos().sostenido()).is_not_null()


func test_el_frente_se_conserva_al_examinar_y_volver_a_agarrar() -> void:
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	AperturaConLugar.abrir_con_todo_el_lugar(almacen)
	var jugador: Node3D = almacen.get("_jugador")
	jugador.set_physics_process(false)
	var agarre: Agarre = almacen.get("_agarre")
	# Hacia dónde está horneado cada modelo: es la cara del mueble hacia la que su tanda
	# exhibe, medida del `.blend` con el eje del frente de cada producto —el de su etiqueta— y
	# no con las filas de su tanda, que es de donde el puesto saca el giro. Está acá para que la
	# mano tenga contra qué medirse. Lo que se afirma es que **la mano lo gira hasta la cámara**,
	# sea cual sea esa cara. Medido el 2026-10-07 después de girar los muebles del fondo,
	# con el eje de la etiqueta y la matriz del producto en Blender.
	#
	# Los doce estuvieron mal hasta el 2026-09-19: los de +X figuraban en -X y los de +Z en -Z,
	# o sea 180° girados. Con el giro de la mano también al revés, las dos mitades se cancelaban
	# y este caso pasaba en verde mientras el jugador agarraba los productos dados vuelta.
	var frentes := [
		Vector3(-1.0, -0.0, -0.0),  # Actroncito,
		Vector3(0.0, 0.190135, 0.981758),  # Durextra,
		Vector3(1.0, 0.0, -0.0),  # Burbaloo,
		Vector3(-1.0, 0.0, -0.0),  # Zucarachas,
		Vector3(0.0, 0.190135, -0.981758),  # Laysntt,
		Vector3(0.0, 0.190135, 0.981758),  # Malbardo,
		Vector3(-1.0, 0.0, -0.0),  # Prongles,
		Vector3(-0.0, 0.190135, -0.981758),  # Jorgillo,
		Vector3(0.0, 0.0, 1.0),  # Arvejas,
		Vector3(0.0, 0.190135, -0.981758),  # Chisitos,
		Vector3(-1.0, 0.0, 0.0),  # Oremos,
		Vector3(1.0, 0.0, -0.0),  # Pepitos,
		Vector3(1.0, 0.0, -0.0),  # Saladik,
		Vector3(1.0, 0.0, -0.0),  # Uakas,
		Vector3(-0.0, 0.0, 1.0),  # Coracola,
		Vector3(-1.0, 0.0, -0.0),  # Frotlups,
		Vector3(1.0, 0.0, -0.0),  # Marolini,
		Vector3(0.0, 0.0, 1.0),  # Amargadito,
		Vector3(-0.0, 0.190135, 0.981758),  # Cindolor,
		Vector3(0.0, 0.0, 1.0),  # Flinpuf,
		Vector3(-1.0, 0.0, -0.0),  # Donsaturados,
		Vector3(0.0, 0.0, 1.0),  # Petisas,
		Vector3(-0.0, 0.190135, 0.981758),  # Macumbas,
		Vector3(0.0, 0.0, 1.0),  # Cosa de Maní,
		Vector3(-0.0, 0.190135, -0.981758),  # Duronga,
		Vector3(0.0, 0.0, 1.0),  # Fernet God,
		Vector3(0.0, 0.0, 1.0),  # Mayonchis,
		Vector3(0.0, 0.0, 1.0),  # Oaaaa,
		Vector3(0.0, 0.0, 1.0),  # Terminator,
		Vector3(-0.0, 0.0, 1.0),  # Marranos,
		Vector3(1.0, 0.0, -0.0),  # Feel Ricky Fort
	]
	assert_int(frentes.size()).is_equal(Catalogo.todos().size())
	for producto in Catalogo.todos():
		_sacar_de_la_caja(jugador, almacen.get("_cajas_de_productos")[producto.id])
		var unidad: Node3D = agarre.punto_de_producto.get_child(0)
		var orientacion := unidad.basis
		assert_float((orientacion * frentes[producto.id]).dot(Vector3.BACK)).is_greater(0.8)
		assert_bool(orientacion.is_equal_approx(Basis.IDENTITY)).is_false()
		agarre.mover_lo_sostenido(almacen.get("_jugador").get_node("Giro/Camara/PuntoDeExamen"))
		unidad.rotate_y(0.7)
		agarre.devolver_a_la_mano()
		assert_bool(unidad.basis.is_equal_approx(orientacion)).is_true()
		agarre.soltar(true)
		assert_bool(agarre.pedir_agarrar(unidad.datos, unidad)).is_true()
		assert_bool(unidad.basis.is_equal_approx(orientacion)).is_true()
		almacen.get("_reposicion_manual").casillero(producto.id).interactuar()
		var grupo: MultiMeshInstance3D = almacen.get("_reposicion_manual").get_node(
			"ProductosDe" + producto.nombre
		)
		# La copia que se acaba de reponer es la ultima visible: el tramo reponible va al final
		# del bloque. **El estante la coloca sin deformarla**, y eso es lo que se afirma: su
		# vuelta sale del modelo y puede ser cualquiera, pero el volumen que ocupa es el de una
		# unidad. Un determinante distinto de uno seria una escala o un corte metidos por el
		# camino, que es el modo de falla que un `MultiMesh` no avisa.
		var repuesta := _transformacion_de_copia(
			grupo.multimesh, grupo.multimesh.visible_instance_count - 1
		)
		assert_float(repuesta.basis.determinant()).is_equal_approx(1.0, 0.001)


func test_actroncito_durextra_y_oremos_se_reponen_con_foco_y_clic_reales() -> void:
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	AperturaConLugar.abrir_con_todo_el_lugar(almacen)
	var jugador: Node3D = almacen.get("_jugador")
	jugador.set_physics_process(false)
	# Los tres viven en el mismo rack y en bandejas distintas: dos arriba en caja chica y uno
	# abajo en caja grande. Es el reparto que el depósito tiene desde que hay dos tamaños, y lo
	# que el caso ejerce es que ninguna de las dos alturas deje la caja fuera del alcance.
	for id: Producto.Id in [Producto.Id.ACTRONCITO, Producto.Id.DUREXTRA, Producto.Id.OREMOS]:
		var antes: int = almacen.get("_repositor").estante().unidades_en_gondola(Catalogo.de(id))
		var caja: Node3D = almacen.get("_cajas_de_productos")[id]
		var vista: MeshInstance3D = caja.get_node("Malla")
		var centro := vista.global_transform * vista.mesh.get_aabb().get_center()
		# Se mira desde +X y no desde +Z desde el 043: las tres cajas de este caso están contra
		# la pared izquierda del depósito, y desde +Z la góndola se interpone. El campo de
		# interacción pide un impacto real sobre el cuerpo, así que con la vista tapada la caja
		# deja de ser candidata.
		await _mirar_foco(jugador, centro + Vector3(1.3, 0.7, 0), centro)
		assert_object(jugador.get("_enfocado")).is_same(caja)
		_sacar_de_la_caja(jugador, caja)
		var unidad: UnidadDeProducto = almacen.get("_agarre").manos().sostenido()
		assert_object(unidad).is_not_null()
		if unidad == null:
			return
		assert_int(unidad.producto.id).is_equal(id)
		var zona: Node3D = almacen.get("_reposicion_manual").casillero(unidad.producto.id)
		# **Se prueban las cuatro caras y gana la que enfoca.** Cual exhibe cada producto lo
		# decide el modelo —hay bloques contra el panel del fondo y bloques de cabecera, y son
		# perpendiculares entre si—, asi que escribirlo aca lo deja caducando con el proximo
		# `.blend`. Parado en la cara equivocada la vista arranca adentro del mueble y no hay
		# que enfocar, y el sintoma es un `null` que no nombra ni al producto ni a la cara.
		for lado in 4:
			var frente := Basis(Vector3.UP, TAU * lado / 4.0) * Vector3.BACK
			var desde := frente * 1.2 + Vector3.UP * 0.3
			await _mirar_foco(jugador, zona.global_position + desde, zona.global_position)
			if jugador.get("_enfocado") == zona:
				break
		(
			assert_object(jugador.get("_enfocado"))
			. override_failure_message(unidad.producto.nombre)
			. is_same(zona)
		)
		_clic_real(jugador)
		assert_object(almacen.get("_agarre").manos().sostenido()).is_null()
		(
			assert_int(almacen.get("_repositor").estante().unidades_en_gondola(Catalogo.de(id)))
			. is_equal(antes + 1)
		)


func test_no_hay_productos_3d_iniciales_fuera_del_inventario() -> void:
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	# Lo expuesto al abrir se cuenta: la góndola del inventario es la fila menos lo que la jornada
	# hace faltar, y lo dibujado son esas mismas unidades y ninguna más.
	var estante: Estante = almacen.get("_repositor").estante()
	var faltantes := Apertura.faltantes_de_la_jornada(ReglasDeLaPartida.PRIMERA_JORNADA)
	for producto in Catalogo.todos():
		var puestas := estante.unidades_en_gondola(producto)
		assert_int(puestas).is_equal(estante.cupo(producto) - faltantes.get(producto.id, 0))
		var grupo: MultiMeshInstance3D = almacen.get("_reposicion_manual").get_node(
			"ProductosDe" + producto.nombre
		)
		assert_int(grupo.multimesh.visible_instance_count).is_equal(
			_guia(almacen, producto) + puestas
		)
	# Cada producto del catálogo tiene su malla en el contenido y en el mismo orden. Sin esto el
	# inventario habla de un producto y la góndola muestra otro, y los dos dan verde.
	var contenido: Node3D = almacen.get_node("Estructura/gondolanueva/StaticBody3D/Contenido")
	assert_int(contenido.get_child_count()).is_equal(Catalogo.todos().size())
	for producto in Catalogo.todos():
		assert_str(contenido.get_child(producto.id).name).is_equal(producto.nombre)


func _mirar_foco(jugador: Node3D, ojo: Vector3, punto: Vector3) -> void:
	var camara: Camera3D = jugador.get_node("Giro/Camara")
	camara.position = Vector3.UP * ReglasDelJugador.ALTURA_DE_LA_CAMARA
	jugador.global_position = ojo - camara.position
	camara.look_at(punto)
	for cuadro in 4:
		await get_tree().physics_frame
	jugador.call("_leer_la_mira")


func _clic_real(jugador: Node3D) -> void:
	var clic := InputEventAction.new()
	clic.action = ReglasDeLosObjetos.ACCION_AGARRAR
	clic.pressed = true
	jugador.call("_unhandled_input", clic)


func test_cada_unidad_ocupa_un_lugar_distinto_y_la_marca_indica_su_base() -> void:
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	var jugador: Node3D = almacen.get("_jugador")
	jugador.set_physics_process(false)
	AperturaConLugar.abrir_con_todo_el_lugar(almacen)
	var estante: Estante = almacen.get("_repositor").estante()
	var presentacion: Node3D = almacen.get("_reposicion_manual")
	var ocupados: Array[AABB] = []
	for producto in Catalogo.todos():
		var antes := estante.unidades_en_gondola(producto)
		for indice in estante.cupo(producto) - antes:
			_sacar_de_la_caja(jugador, almacen.get("_cajas_de_productos")[producto.id])
			var unidad: Node3D = jugador.get_node("Giro/Camara/PuntoDeProducto").get_child(0)
			# **La marca es el fantasma del envase, no un rectángulo en el piso.** Lo que tiene
			# que coincidir con la unidad repuesta es su base: el fantasma se para donde la
			# unidad se va a parar, y por eso el apoyo sale de su caja y no de su origen. El
			# casillero es el primero vacío, que es donde coloca el clic sobre él.
			var zona: Node3D = presentacion.casillero(producto.id)
			var marca: MeshInstance3D = zona.vista
			var sombra: AABB = marca.global_transform * marca.mesh.get_aabb()
			var apoyo := Vector3(sombra.get_center().x, sombra.position.y, sombra.get_center().z)
			_accion(jugador, zona)
			var vista: MeshInstance3D = unidad.get_node("Malla")
			assert_bool(vista.scale.is_equal_approx(Vector3.ONE)).is_true()
			var grupo: MultiMeshInstance3D = presentacion.get_node("ProductosDe" + producto.nombre)
			var transformacion := (
				grupo.global_transform
				* _transformacion_de_copia(
					grupo.multimesh, _guia(almacen, producto) + antes + indice
				)
			)
			var limites := transformacion * grupo.multimesh.mesh.get_aabb()
			assert_float(limites.get_center().x).is_equal_approx(apoyo.x, 0.001)
			assert_float(limites.get_center().z).is_equal_approx(apoyo.z, 0.001)
			assert_float(limites.position.y).is_equal_approx(apoyo.y, 0.001)
			# **Se compara el centro y no el volumen.** Las unidades ya no las separa el juego:
			# las posiciona el modelo, y ahí están apoyadas una contra otra, así que sus cajas
			# se tocan. Lo que no puede repetirse es el lugar: dos unidades en el mismo punto
			# es una que se repuso encima de otra, y eso el jugador lo ve como stock que no
			# aparece.
			for ocupado in ocupados:
				assert_bool(limites.get_center().is_equal_approx(ocupado.get_center())).is_false()
			ocupados.append(limites)
		# Con la fila completa la caja da la que le quede, y vacía no da nada (BR-STK-017). La
		# que sale vuelve a la caja, y el producto siguiente arranca con las manos vacías.
		assert_int(estante.unidades_en_gondola(producto)).is_equal(estante.cupo(producto))
		var caja: Node3D = almacen.get("_cajas_de_productos")[producto.id]
		var le_quedan := estante.disponibles_para_retirar(producto)
		_sacar_de_la_caja(jugador, caja)
		assert_int(estante.disponibles_para_retirar(producto)).is_equal(maxi(0, le_quedan - 1))
		_sacar_de_la_caja(jugador, caja)
		assert_object(almacen.get("_agarre").manos().sostenido()).is_null()
		assert_int(estante.disponibles_para_retirar(producto)).is_equal(le_quedan)


func test_el_clic_saca_una_unidad_visible_y_el_estante_la_recibe() -> void:
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	AperturaConLugar.abrir_con_todo_el_lugar(almacen)
	await get_tree().physics_frame
	await get_tree().physics_frame
	almacen.get("_jugador").set_physics_process(false)
	var jugador: Node3D = almacen.get("_jugador")
	var agarre: Agarre = jugador.get("agarre")
	var caja: Node3D = almacen.get("_cajas_de_productos")[0]
	var estante: Node3D = almacen.get("_estante")
	var repositor: Repositor = almacen.get("_repositor")
	var antes := repositor.estante().unidades_en_gondola(Catalogo.todos()[0])
	_sacar_de_la_caja(jugador, caja)
	assert_object(agarre.manos().sostenido()).is_not_null()
	var punto := jugador.get_node_or_null("Giro/Camara/PuntoDeProducto")
	assert_object(punto).is_not_null()
	if punto == null or punto.get_child_count() == 0:
		return
	var unidad: Node3D = punto.get_child(0)
	assert_bool(unidad.is_visible_in_tree()).is_true()
	assert_int(unidad.collision_layer).is_zero()
	# **Abajo a la derecha, no sobre la mira.** El producto es lo más grande que se lleva. El
	# gesto siguiente es apuntar al casillero del estante.
	assert_float(punto.position.x).is_greater(0.0)
	assert_float(punto.position.y).is_less(0.0)
	# Con la mano ocupada no sale una segunda unidad. Se pide a la caja de otro producto: sobre la
	# misma caja, el clic le devolvería la que se lleva.
	_sacar_de_la_caja(jugador, almacen.get("_cajas_de_productos")[Producto.Id.DUREXTRA])
	assert_int(punto.get_child_count()).is_equal(1)
	assert_object(punto.get_child(0)).is_same(unidad)
	_apuntar(almacen, Producto.Id.ACTRONCITO)
	_accion(jugador, almacen.get("_reposicion_manual").casillero(Producto.Id.ACTRONCITO))
	assert_object(agarre.manos().sostenido()).is_null()
	assert_bool(unidad.is_visible_in_tree()).is_false()
	var grupo: MultiMeshInstance3D = almacen.get("_reposicion_manual").get_node(
		"ProductosDeActroncito"
	)
	assert_int(grupo.multimesh.visible_instance_count).is_equal(
		_guia(almacen, Catalogo.todos()[0]) + antes + 1
	)
	assert_int(repositor.estante().unidades_en_gondola(Catalogo.todos()[0])).is_equal(antes + 1)


func test_con_el_estante_lleno_la_caja_entrega_y_la_gondola_la_rechaza() -> void:  # AC-STK-017
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	await get_tree().physics_frame
	await get_tree().physics_frame
	almacen.get("_jugador").set_physics_process(false)
	var jugador: Node3D = almacen.get("_jugador")
	var caja: Node3D = almacen.get("_cajas_de_productos")[0]
	var estante: Node3D = almacen.get("_estante")
	var agarre: Agarre = almacen.get("_agarre")
	var producto := Catalogo.todos()[0]
	var del_dominio: Estante = almacen.get("_repositor").estante()
	var motivos: Array[Estante.Rechazo] = []
	(almacen.get("_repositor") as Repositor).colocacion_rechazada.connect(
		func(motivo: Estante.Rechazo) -> void: motivos.append(motivo)
	)
	for _vez in del_dominio.cupo(producto) - del_dominio.unidades_en_gondola(producto):
		_sacar_de_la_caja(jugador, caja)
		_accion(jugador, estante)
	assert_int(del_dominio.unidades_en_gondola(producto)).is_equal(del_dominio.cupo(producto))
	var en_la_caja := del_dominio.disponibles_para_retirar(producto)
	assert_int(en_la_caja).is_greater(0)
	# Con la fila llena, la caja da otra (BR-STK-017), y la góndola la rechaza: sigue en la mano.
	# El clic sobre la góndola con la mano vacía ya no es «nada»: agarra la unidad puesta
	# (BR-PLY-024), y eso lo miden los casos de los casilleros.
	_sacar_de_la_caja(jugador, caja)
	var unidad := agarre.manos().sostenido() as UnidadDeProducto
	assert_object(unidad).is_not_null()
	assert_int(del_dominio.disponibles_para_retirar(producto)).is_equal(en_la_caja - 1)
	_accion(jugador, estante)
	assert_array(motivos).is_equal([Estante.Rechazo.ESTANTE_LLENO])
	assert_object(agarre.manos().sostenido()).is_same(unidad)
	assert_int(jugador.get_node("Giro/Camara/PuntoDeProducto").get_child_count()).is_equal(1)
	assert_int(del_dominio.unidades_en_gondola(producto)).is_equal(del_dominio.cupo(producto))
	# Devuelta a su caja, la caja la vuelve a contar.
	_sacar_de_la_caja(jugador, caja)
	assert_object(agarre.manos().sostenido()).is_null()
	assert_int(del_dominio.disponibles_para_retirar(producto)).is_equal(en_la_caja)


func test_examinar_no_retira_ni_deposita_y_devuelve_la_unidad_a_la_mira() -> void:
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	await get_tree().physics_frame
	await get_tree().physics_frame
	almacen.get("_jugador").set_physics_process(false)
	var jugador: Node3D = almacen.get("_jugador")
	var caja: Node3D = almacen.get("_cajas_de_productos")[0]
	var estante: Node3D = almacen.get("_estante")
	var agarre: Agarre = almacen.get("_agarre")
	var lugar: Transform3D = caja.global_transform
	_accion(jugador, caja, ReglasDeLosObjetos.ACCION_EXAMINAR)
	assert_bool(jugador.examen.esta_examinando()).is_false()
	assert_bool(jugador.get("_control").esta_suspendido()).is_false()
	assert_object(agarre.manos().sostenido()).is_null()
	assert_bool(caja.global_transform.is_equal_approx(lugar)).is_true()
	assert_bool(jugador.examen.hallazgos().ya_visto(caja.get("datos"))).is_false()
	_accion(jugador, caja, ReglasDeLosObjetos.ACCION_EXAMINAR)
	assert_bool(jugador.examen.esta_examinando()).is_false()
	_sacar_de_la_caja(jugador, caja)
	var sostenido := agarre.manos().sostenido()
	_accion(jugador, estante, ReglasDeLosObjetos.ACCION_EXAMINAR)
	assert_object(agarre.manos().sostenido()).is_same(sostenido)
	assert_int(jugador.get_node("Giro/Camara/PuntoDeExamen").get_child_count()).is_equal(1)
	# La unidad recién sacada de la caja se examina a la distancia de siempre.
	assert_float(jugador.get_node("Giro/Camara/PuntoDeExamen").position.length()).is_equal_approx(
		ReglasDeLosObjetos.DISTANCIA_DE_EXAMEN, 0.001
	)
	_accion(jugador, estante, ReglasDeLosObjetos.ACCION_EXAMINAR)
	assert_int(jugador.get_node("Giro/Camara/PuntoDeProducto").get_child_count()).is_equal(1)


func test_las_dos_cajas_se_examinan_enteras_y_vuelven_a_la_cintura() -> void:
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var jugador: Node3D = almacen.get("_jugador")
	jugador.set_physics_process(false)
	var agarre: Agarre = almacen.get("_agarre")
	var camara: Camera3D = jugador.get_node("Giro/Camara")
	var cara: Node3D = jugador.get_node("Giro/Camara/PuntoDeExamen")
	var cintura: Node3D = jugador.get_node("Giro/PuntoDeCaja")
	var volumen: CollisionShape3D = jugador.get_node("FormaDeLaCaja")
	# La chica primero y la grande después: el almacén usa dos tamaños y nada más.
	var cajas: Array = almacen.get("_cajas_de_productos").duplicate()
	cajas.sort_custom(func(a: Node3D, b: Node3D) -> bool: return _radio(a) < _radio(b))
	var chica: Node3D = cajas.front()
	var grande: Node3D = cajas.back()
	assert_float(_radio(grande)).is_greater(_radio(chica))
	var distancias: Array[float] = []
	for caja: Node3D in [chica, grande]:
		_accion(jugador, caja)
		assert_object(caja.get_parent()).is_same(cintura)
		var antes := caja.transform
		_accion(jugador, caja, ReglasDeLosObjetos.ACCION_EXAMINAR)
		assert_object(caja.get_parent()).is_same(cara)
		assert_bool(volumen.disabled).is_false()
		var distancia := cara.position.length()
		var radio := _radio(caja)
		# Ninguna rotación la hace cruzar el plano cercano, y la esfera cabe en el cuadro.
		assert_float(distancia - radio).is_greater(camara.near)
		assert_float(radio / distancia).is_less(sin(deg_to_rad(camara.fov / 2.0)))
		assert_float(distancia).is_less(camara.position.distance_to(cintura.position))
		assert_float(distancia).is_less(ReglasDelJugador.ALCANCE_DE_LA_MIRA)
		distancias.append(distancia)
		jugador.examen.arrastrar(Vector2(300.0, 200.0), true)
		# El clic no cierra el examen ni suelta la caja: la E es la única salida.
		_accion(jugador, caja)
		assert_object(caja.get_parent()).is_same(cara)
		_accion(jugador, caja, ReglasDeLosObjetos.ACCION_EXAMINAR)
		assert_object(caja.get_parent()).is_same(cintura)
		assert_bool(caja.transform.is_equal_approx(antes)).is_true()
		agarre.soltar(true)
		assert_object(agarre.manos().sostenido()).is_null()
		assert_object(caja.get_parent()).is_not_same(cintura)
		assert_bool(volumen.disabled).is_true()
	assert_float(distancias[1]).is_greater(distancias[0])


## El radio de la esfera que envuelve lo que se ve de la caja, medido desde su origen: el punto
## alrededor del cual se la gira.
func _radio(caja: Node3D) -> float:
	var radio := 0.0
	for malla: MeshInstance3D in caja.find_children("*", "MeshInstance3D", true, false):
		var limites := malla.get_aabb()
		for indice in 8:
			radio = maxf(radio, (malla.transform * limites.get_endpoint(indice)).length())
	return radio


func _accion(
	jugador: Node3D, objetivo: Node3D, accion: StringName = ReglasDeLosObjetos.ACCION_AGARRAR
) -> void:
	if objetivo == jugador.get_parent().get("_estante"):
		_apuntar(jugador.get_parent(), Producto.Id.ACTRONCITO)
		objetivo = jugador.get_parent().get("_reposicion_manual").casillero(Producto.Id.ACTRONCITO)
	jugador.set("_enfocado", objetivo)
	var evento := InputEventAction.new()
	evento.action = accion
	evento.pressed = true
	jugador.call("_unhandled_input", evento)


## Baja la caja al suelo y le pide una unidad con el clic derecho. Las del estante no
## entregan desde ahí, y bajarlas es justamente lo que le cuesta al jugador.
func _sacar_de_la_caja(jugador: Node3D, caja: Node3D) -> void:
	_accion(jugador, caja, ReglasDelJugador.ACCION_USAR)


func _apuntar(almacen: Node3D, id: Producto.Id) -> void:
	var zona: AABB = almacen.get("_reposicion_manual").zona(id)
	var jugador: Node3D = almacen.get("_jugador")
	var camara: Camera3D = jugador.get_node("Giro/Camara")
	camara.global_position = zona.get_center() + Vector3(0, 0, 1.5)
	camara.look_at(zona.get_center())


## Cuantas copias de ese producto son guia: las que estan siempre y el jugador no repone.
##
## **Sale de restar y no de un numero escrito.** Cuantas se reponen lo dice el cupo del estante
## —los casilleros de la fila de adelante, que mide el modelo—, y cuantas hay en total lo dice el
## dibujo: entre los dos queda el tramo fijo.
func _guia(almacen: Node3D, producto: Producto) -> int:
	var grupo: MultiMeshInstance3D = almacen.get("_reposicion_manual").get_node(
		"ProductosDe" + producto.nombre
	)
	var estante: Estante = almacen.get("_repositor").estante()
	return grupo.multimesh.instance_count - estante.cupo(producto)


func _transformacion_de_copia(copias: MultiMesh, indice: int) -> Transform3D:
	# El renderizador dummy no implementa get_instance_transform; sí conserva el buffer.
	if DisplayServer.get_name() != "headless":
		return copias.get_instance_transform(indice)
	var valores := copias.buffer
	var inicio := indice * 12
	return Transform3D(
		Basis(
			Vector3(valores[inicio], valores[inicio + 4], valores[inicio + 8]),
			Vector3(valores[inicio + 1], valores[inicio + 5], valores[inicio + 9]),
			Vector3(valores[inicio + 2], valores[inicio + 6], valores[inicio + 10])
		),
		Vector3(valores[inicio + 3], valores[inicio + 7], valores[inicio + 11])
	)


func test_solo_la_zona_del_producto_recibe_el_foco_y_el_resto_del_mueble_no_coloca() -> void:
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	await get_tree().physics_frame
	var jugador: Node3D = almacen.get("_jugador")
	jugador.set_physics_process(false)
	var agarre: Agarre = almacen.get("_agarre")
	var estante: Node3D = almacen.get("_estante")
	_sacar_de_la_caja(jugador, almacen.get("_cajas_de_productos")[0])
	var sostenido := agarre.manos().sostenido()
	assert_bool(estante.is_in_group(ReglasDelJugador.GRUPO_INTERACTUABLE)).is_false()
	var presentacion: Node3D = almacen.get("_reposicion_manual")
	# Los casilleros vacíos de Actroncito esperan la unidad; los ocupados y los de cualquier otro
	# producto no tienen papel, y no están para la mira aunque la tengan enfrente.
	var actroncito := Catalogo.de(Producto.Id.ACTRONCITO)
	var vacios: Array[int] = almacen.get("_repositor").estante().casilleros_vacios(actroncito)
	assert_array(vacios).is_not_empty()
	for producto in Catalogo.todos():
		for zona: Node3D in presentacion.get_node("ZonaDe" + producto.nombre).get_children():
			var espera: bool = producto.id == actroncito.id and vacios.has(zona.get("casillero"))
			(
				assert_bool(zona.get("papel") != 0)
				. override_failure_message("%s: %s" % [producto.nombre, zona.name])
				. is_equal(espera)
			)
			if not espera:
				assert_int(zona.get("collision_layer")).is_zero()
	var mueble: MeshInstance3D = estante.get_parent()
	assert_object(mueble.material_overlay).is_null()
	estante.call("interactuar")
	assert_object(agarre.manos().sostenido()).is_same(sostenido)
	presentacion.casillero(Producto.Id.DUREXTRA).call("interactuar")
	assert_object(agarre.manos().sostenido()).is_same(sostenido)


func test_lo_soltado_queda_sobre_el_piso_o_la_tapa_que_se_mira() -> void:  # AC-PLY-033
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	await get_tree().physics_frame
	var jugador: Node3D = almacen.get("_jugador")
	jugador.set_physics_process(false)
	var camara: Camera3D = jugador.get_node("Giro/Camara")
	var bolsa: RigidBody3D = almacen.get_node("Objetos/BolsaDeBasura1")
	var piso: Vector3 = jugador.global_position + jugador.frente() * 1.2
	# Una caja del depósito llevada al piso de al lado, para mirarle la tapa.
	var caja: RigidBody3D = almacen.get("_cajas_de_productos")[0]
	var costado: Vector3 = jugador.global_position + jugador.frente().rotated(Vector3.UP, 0.6)
	caja.global_position = costado + Vector3.UP * _media_caja(caja).y
	await get_tree().physics_frame
	var tapa := caja.global_position + Vector3.UP * _media_caja(caja).y
	for punto: Vector3 in [piso, tapa]:
		camara.look_at(punto)
		var golpe := _golpe_de_la_mira(jugador, bolsa)
		assert_float(golpe["normal"].y).is_greater(ReglasDeLosObjetos.APOYO_HORIZONTAL)
		_soltar(almacen, bolsa)
		var toca: Vector3 = golpe["position"]
		assert_vector(Vector2(bolsa.global_position.x, bolsa.global_position.z)).is_equal_approx(
			Vector2(toca.x, toca.z), Vector2.ONE * 0.01
		)
		assert_float(_base(bolsa) - toca.y).is_between(0.0, 0.01)
		assert_bool(_encimado(bolsa)).is_false()


func test_sin_superficie_que_valga_se_suelta_como_siempre() -> void:  # AC-PLY-035
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	await get_tree().physics_frame
	var jugador: Node3D = almacen.get("_jugador")
	jugador.set_physics_process(false)
	var camara: Camera3D = jugador.get_node("Giro/Camara")
	var agarre: Agarre = almacen.get("_agarre")
	var bolsa: RigidBody3D = almacen.get_node("Objetos/BolsaDeBasura1")
	for punto: Vector3 in [
		camara.global_position + jugador.frente() * 10.0,
		camara.global_position + Vector3.UP * 10.0 + jugador.frente() * 0.1,
	]:
		camara.look_at(punto)
		var golpe := _golpe_de_la_mira(jugador, bolsa)
		if not golpe.is_empty():
			assert_float(golpe["normal"].y).is_less(ReglasDeLosObjetos.APOYO_HORIZONTAL)
		var sin_mira := agarre.punto_de_soltado.global_position
		_soltar(almacen, bolsa)
		assert_vector(bolsa.global_position).is_equal_approx(sin_mira, Vector3.ONE * 0.01)
	# El piso admite, pero la otra bolsa queda más cerca del rayo que media bolsa: se encimarían.
	var otra: RigidBody3D = almacen.get_node("Objetos/BolsaDeBasura2")
	var piso: Vector3 = jugador.global_position + jugador.frente() * 1.2
	camara.look_at(piso)
	var toca: Vector3 = _golpe_de_la_mira(jugador, bolsa)["position"]
	var media: Vector3 = (otra.get_node("Forma").shape as BoxShape3D).size / 2.0
	otra.global_position = toca + Vector3(media.x * 1.5, media.y, 0.0)
	await get_tree().physics_frame
	camara.look_at(piso)
	var al_costado := _golpe_de_la_mira(jugador, bolsa)
	assert_object(al_costado["collider"]).is_not_same(otra)
	assert_float(al_costado["normal"].y).is_greater(ReglasDeLosObjetos.APOYO_HORIZONTAL)
	var sin_mira_al_costado := agarre.punto_de_soltado.global_position
	_soltar(almacen, bolsa)
	assert_vector(bolsa.global_position).is_equal_approx(sin_mira_al_costado, Vector3.ONE * 0.01)
	# Un estante de la góndola es horizontal y la bolsa entra, pero queda adentro del mueble.
	var apoyo: Vector3 = almacen.get("_reposicion_manual").call("_apoyo", Producto.Id.UAKAS)
	# Detrás del casillero, sobre la misma chapa, y desde arriba: el casillero está a seis
	# centímetros del frente del estante, y un rayo tendido hacia él pega en el portaprecio, que
	# es inclinado. La cámara queda lo bastante afuera para que el punto de soltar sin mira caiga
	# en el pasillo y no adentro del contorno del mueble.
	var estante := apoyo + Vector3.LEFT * 0.12
	camara.global_position = estante + Vector3(2.0, 1.4, 0.0)
	camara.look_at(estante)
	# Sin el contorno que envuelve al mueble: si lo soltado choca con él, la mira pega en su cara
	# y no llega al estante.
	var en_el_estante := _golpe_de_la_mira(jugador, bolsa, true)
	assert_object(en_el_estante["collider"]).is_same(almacen.get("_estante"))
	assert_float(en_el_estante["normal"].y).is_greater(ReglasDeLosObjetos.APOYO_HORIZONTAL)
	var sin_mira_del_estante := agarre.punto_de_soltado.global_position
	_soltar(almacen, bolsa)
	assert_vector(bolsa.global_position).is_equal_approx(sin_mira_del_estante, Vector3.ONE * 0.01)


func _soltar(almacen: Node3D, cuerpo: RigidBody3D) -> void:
	var agarre: Agarre = almacen.get("_agarre")
	assert_bool(agarre.pedir_agarrar(cuerpo.get("datos"), cuerpo)).is_true()
	agarre.soltar(true)


## Lo que la mira toca, contra lo que el cuerpo choca.
func _golpe_de_la_mira(jugador: Node3D, cuerpo: RigidBody3D, sin_contorno := false) -> Dictionary:
	var mascara := cuerpo.collision_mask
	if sin_contorno:
		mascara &= ~ReglasDeLosObjetos.CAPA_DEL_CONTORNO
	var ojo: Transform3D = jugador.mira()
	var consulta := PhysicsRayQueryParameters3D.create(
		ojo.origin, ojo.origin - ojo.basis.z * ReglasDelJugador.ALCANCE_DE_LA_MIRA, mascara
	)
	consulta.exclude = [jugador.get_rid(), cuerpo.get_rid()]
	return jugador.get_world_3d().direct_space_state.intersect_ray(consulta)


func _formas(cuerpo: RigidBody3D) -> Array[CollisionShape3D]:
	var formas: Array[CollisionShape3D] = []
	formas.assign(cuerpo.find_children("*", "CollisionShape3D", false, false))
	return formas


func _base(cuerpo: RigidBody3D) -> float:
	var base := INF
	for forma in _formas(cuerpo):
		var limites := forma.global_transform * forma.shape.get_debug_mesh().get_aabb()
		base = minf(base, limites.position.y)
	return base


func _encimado(cuerpo: RigidBody3D) -> bool:
	for forma in _formas(cuerpo):
		var consulta := PhysicsShapeQueryParameters3D.new()
		consulta.shape = forma.shape
		consulta.transform = forma.global_transform
		consulta.collision_mask = cuerpo.collision_mask | ReglasDeLosObjetos.CAPA_DEL_CONTORNO
		consulta.exclude = [cuerpo.get_rid()]
		if not cuerpo.get_world_3d().direct_space_state.intersect_shape(consulta, 1).is_empty():
			return true
	return false


func _media_caja(caja: RigidBody3D) -> Vector3:
	var forma: CollisionShape3D = caja.get_node("Cuerpo")
	return (forma.shape as BoxShape3D).size * forma.scale / 2.0
