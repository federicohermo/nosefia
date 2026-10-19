extends GdUnitTestSuite

const ALMACEN := "res://src/escenas/almacen.tscn"
const AperturaConLugar := preload("res://test/escenas/apertura_con_lugar.gd")


func _almacen() -> Node3D:
	var almacen: Node3D = auto_free(load(ALMACEN).instantiate())
	almacen.set("_partida", Partida.desde({"jornada": 5, "medios": 0}))
	add_child(almacen)
	almacen.get("_reloj").set_process(false)
	almacen.get("_jugador").set_physics_process(false)
	return almacen


func _puesto(almacen: Node3D) -> Node3D:
	return almacen.get("_reposicion_manual")


func _inventario(almacen: Node3D) -> Inventario:
	var repositor: Repositor = almacen.get("_repositor")
	return repositor.estante().get("_inventario")


func _destinos() -> Dictionary:
	return {
		"gondolanueva":
		{
			Vector3.LEFT:
			[Producto.Id.MAROLINI, Producto.Id.ARVECOR, Producto.Id.UAKALAS, Producto.Id.MARRANOS],
			Vector3.RIGHT:
			[
				Producto.Id.MACUMBAS,
				Producto.Id.PEPITO,
				Producto.Id.ZUCARACHAS,
				Producto.Id.FROT_LUPS
			],
			Vector3.BACK: [Producto.Id.MALBARDO, Producto.Id.AMARGADITO],
			Vector3.FORWARD: [Producto.Id.FERNET_GOD, Producto.Id.TERMINATOR],
		},
		"gondolanueva2":
		{
			Vector3.RIGHT:
			[
				Producto.Id.OREMOS,
				Producto.Id.PETISAS,
				Producto.Id.DON_SATURADOS,
				Producto.Id.FEEL_RICKY_FORT
			],
			Vector3.LEFT:
			[Producto.Id.SALADICK, Producto.Id.PROGRES, Producto.Id.CHISITOS, Producto.Id.LAYSNNT],
			Vector3.BACK: [Producto.Id.COSA_DE_MANI, Producto.Id.FLIM_POF],
			Vector3.FORWARD: [Producto.Id.JORGILLO, Producto.Id.BURBALOO],
		},
		"gondolanueva_001":
		{
			Vector3.BACK:
			[Producto.Id.ACTRONCITO, Producto.Id.DUREXTRA, Producto.Id.POETICO, Producto.Id.DURONGA]
		},
		"heladeranueva": {Vector3.BACK: [Producto.Id.PURA_COLA, Producto.Id.OAAAA]},
		"heladeranueva_001": {Vector3.BACK: [Producto.Id.CINDOLOR, Producto.Id.MAYONCHIS]},
	}


func _comprobar_tanda(
	almacen: Node3D,
	mueble: Node3D,
	id: Producto.Id,
	bloque: PackedFloat32Array,
	fila: int,
	frente: Vector3
) -> void:
	assert_vector(DisposicionDeLaGondola.frente(bloque, fila)).is_equal_approx(
		frente, Vector3.ONE * 0.002
	)
	var malla: Mesh = _puesto(almacen).get("_modelos")[id]
	for indice in DisposicionDeLaGondola.copias(bloque):
		var caja := DisposicionDeLaGondola.copia(bloque, indice) * malla.get_aabb()
		var centro := caja.get_center()
		var rayo := PhysicsRayQueryParameters3D.create(centro, centro + Vector3.DOWN * 2.0, 1)
		var golpe := almacen.get_world_3d().direct_space_state.intersect_ray(rayo)
		assert_dict(golpe).override_failure_message(Catalogo.de(id).nombre).is_not_empty()
		if not golpe.is_empty():
			(
				assert_bool(mueble.is_ancestor_of(golpe["collider"]))
				. override_failure_message(
					"%s no se apoya en %s" % [Catalogo.de(id).nombre, mueble.name]
				)
				. is_true()
			)


func test_las_principales_y_referencias_ocupan_los_sectores_de_jornada_dos() -> void:  # AC-STK-086
	var almacen := _almacen()
	await get_tree().physics_frame
	await get_tree().physics_frame
	var disposicion: DisposicionDeLaGondola = _puesto(almacen).get("disposicion")
	var encontrados: Array[int] = []
	for nombre: String in _destinos():
		var mueble: Node3D = almacen.get_node("Estructura/" + nombre)
		var caras: Dictionary = _destinos()[nombre]
		for frente: Vector3 in caras:
			for id: Producto.Id in caras[frente]:
				assert_array(encontrados).not_contains(id)
				encontrados.append(id)
				_comprobar_tanda(
					almacen,
					mueble,
					id,
					disposicion.principales[id],
					disposicion.filas_de_adelante[id],
					frente
				)
				for indice in disposicion.guias.size():
					if disposicion.productos_de_las_guias[indice] == id:
						_comprobar_tanda(
							almacen,
							mueble,
							id,
							disposicion.guias[indice],
							disposicion.filas_de_adelante_de_las_guias[indice],
							frente
						)
	assert_int(encontrados.size()).is_equal(Catalogo.todos().size())
	assert_array(encontrados).contains(Producto.Id.DURONGA)


func _altura(disposicion: DisposicionDeLaGondola, id: Producto.Id) -> float:
	return DisposicionDeLaGondola.copia(disposicion.principales[id], 0).origin.y


func test_las_mitades_verticales_separan_los_frios() -> void:  # AC-STK-087
	var almacen := _almacen()
	var disposicion: DisposicionDeLaGondola = _puesto(almacen).get("disposicion")
	assert_float(_altura(disposicion, Producto.Id.PURA_COLA)).is_greater(
		_altura(disposicion, Producto.Id.OAAAA)
	)
	assert_float(_altura(disposicion, Producto.Id.CINDOLOR)).is_greater(
		_altura(disposicion, Producto.Id.MAYONCHIS)
	)
	var vacia: Node3D = almacen.get_node("Estructura/heladera_fuera_de_servicio")
	assert_object(vacia).is_not_null()
	var puntos: Array[Vector3] = []
	for bloque in disposicion.principales + disposicion.guias:
		for indice in DisposicionDeLaGondola.copias(bloque):
			puntos.append(DisposicionDeLaGondola.copia(bloque, indice).origin)
	var caja := (
		(vacia as MeshInstance3D).global_transform * (vacia as MeshInstance3D).mesh.get_aabb()
	)
	for punto in puntos:
		assert_bool(caja.has_point(punto)).is_false()


func test_duronga_exhibida_conserva_su_caja_y_fuente_utilizables() -> void:  # AC-STK-088
	var almacen := _almacen()
	var puesto := _puesto(almacen)
	var disposicion: DisposicionDeLaGondola = puesto.get("disposicion")
	var producto := Catalogo.de(Producto.Id.DURONGA)
	var sin_faltantes: Dictionary[Producto.Id, int] = {}
	AperturaConLugar.abrir_con_faltantes(almacen, sin_faltantes)
	var inventario := _inventario(almacen)
	var cupo := disposicion.casilleros_de(producto.id)
	var principal := disposicion.principales[producto.id]
	var fila := disposicion.filas_de_adelante[producto.id]
	assert_int(cupo).is_greater(0)
	assert_int(fila).is_greater(0)
	assert_int(disposicion.primera_reponible(producto.id, fila)).is_equal(
		DisposicionDeLaGondola.copias(principal) - fila
	)
	assert_array(Array(principal)).is_not_empty()
	assert_array(Array(disposicion.productos_de_las_guias)).contains(producto.id)
	assert_object(puesto.get_node_or_null("ZonaDeDuronga")).is_not_null()
	assert_object(puesto.call("casillero", producto.id, 0)).is_not_null()
	var zona: AABB = puesto.call("zona", producto.id, 0)
	assert_bool(zona.has_volume()).is_true()
	var grupo: MultiMeshInstance3D = puesto.get_node("ProductosDeDuronga")
	assert_int(grupo.multimesh.instance_count).is_greater(0)
	assert_bool(grupo.visible).is_true()
	assert_int(inventario.unidades(producto, Inventario.Ubicacion.GONDOLA)).is_equal(cupo)
	assert_int(inventario.vendibles(producto)).is_equal(ReglasDelEstante.UNIDADES_POR_CAJA)
	assert_array(inventario.faltantes()).not_contains(producto)
	var caja: Node3D = almacen.get("_cajas_de_productos")[producto.id]
	assert_str(puesto.call("texto_del_examen", caja)).contains(
		str(ReglasDelEstante.UNIDADES_POR_CAJA)
	)
	puesto.call("retirar", producto.id)
	assert_str(puesto.call("texto_del_examen", caja)).contains(
		str(ReglasDelEstante.UNIDADES_POR_CAJA - 1)
	)
	var agarre: Agarre = almacen.get("_agarre")
	var unidad := agarre.manos().sostenido() as UnidadDeProducto
	assert_object(unidad).is_not_null()
	assert_int(unidad.producto.id).is_equal(producto.id)
	var cuerpo := agarre.punto_de_producto.get_child(0) as ObjetoAgarrable
	assert_object(cuerpo.get_node("Malla").get("mesh")).is_not_null()
	var examen: Examen = almacen.get("_jugador").get("examen")
	assert_bool(examen.iniciar(unidad)).is_true()
	assert_object(cuerpo.datos).is_same(unidad)
	examen.terminar()
	puesto.call("devolver", producto.id)
	assert_int(inventario.vendibles(producto)).is_equal(ReglasDelEstante.UNIDADES_POR_CAJA)
	assert_bool((almacen.get("_repositor") as Repositor).caja(producto.id).meter(unidad)).is_false()
	puesto.call("retirar", producto.id)
	unidad = agarre.manos().sostenido() as UnidadDeProducto
	assert_bool(inventario.vender_unidades([unidad])).is_true()
	assert_bool(inventario.vender_unidades([unidad])).is_false()
	assert_int(inventario.unidades(producto, Inventario.Ubicacion.DEPOSITO)).is_equal(
		ReglasDelEstante.UNIDADES_POR_CAJA - 1
	)
	agarre.vaciar_las_manos()
	var venta := Venta.new()
	venta.agregar(producto, ReglasDelEstante.UNIDADES_POR_CAJA - 1)
	assert_bool(inventario.cobrar(venta)).is_true()
	puesto.call("retirar", producto.id)
	assert_object(agarre.manos().sostenido()).is_null()
	assert_bool(inventario.cobrar(venta)).is_false()
	assert_array(inventario.faltantes()).not_contains(producto)


func test_jornada_dos_puede_vender_reponer_y_cerrar_con_duronga_exhibida() -> void:  # AC-STK-089
	var almacen := _almacen()
	var puesto := _puesto(almacen)
	var repositor: Repositor = almacen.get("_repositor")
	var inventario := _inventario(almacen)
	var atenciones: Ventanilla = almacen.get("_atenciones")
	assert_object(atenciones.tarea().get("_inventario")).is_same(inventario)
	var cupos: Dictionary[Producto.Id, int] = puesto.call("casilleros")
	assert_int(cupos.size()).is_equal(Producto.Id.size())
	assert_int(cupos[Producto.Id.DURONGA]).is_greater(0)
	var disposicion: DisposicionDeLaGondola = puesto.get("disposicion")
	assert_int(disposicion.filas_de_adelante[Producto.Id.DURONGA]).is_greater(0)
	var pedidos := Venta.new()
	for comprador in Compradores.de_la_jornada(5):
		for producto in comprador.pedido().productos():
			pedidos.agregar(producto, comprador.pedido().unidades_de(producto))
	assert_bool(inventario.cobrar(pedidos)).is_true()
	for producto in Catalogo.todos():
		for indice in repositor.estante().casilleros_vacios(producto):
			puesto.call("retirar", producto.id)
			repositor.pedir_colocar_de_la_mano(producto, indice)
	assert_bool(repositor.estante().completada()).is_true()
	var reloj: RelojDelTurno = almacen.get("_reloj")
	var reponer := reloj.obligatoria(Tarea.Tipo.REPONER)
	assert_bool(reponer.completada()).is_true()
	reloj.avanzar(Reglas.DURACION_DEL_TURNO)
	assert_bool(reloj.corriendo()).is_false()
	assert_bool(reponer.completada()).is_true()
