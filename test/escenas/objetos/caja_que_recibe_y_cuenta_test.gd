## La caja del depósito en el local: el clic derecho le devuelve la unidad de su producto, y la E
## muestra cuántas tiene.
##
## Lo que la caja decide tiene sus casos en `dominio/`. Acá se afirma el cableado: que el clic y
## la E de verdad lleguen a esa decisión, que el cuerpo devuelto deje de verse y que el subtítulo
## se pinte y se borre con el examen.
extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.tscn")
const AperturaConLugar := preload("res://test/escenas/apertura_con_lugar.gd")


## Le pone el foco al objetivo y le manda la acción, que es lo que hace el clic de verdad.
func _accion(jugador: Node3D, objetivo: Node3D, accion: StringName) -> void:
	jugador.set("_enfocado", objetivo)
	var evento := InputEventAction.new()
	evento.action = accion
	evento.pressed = true
	jugador.call("_unhandled_input", evento)


func _almacen_con_jugador_quieto() -> Node3D:
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	await get_tree().physics_frame
	almacen.get("_jugador").set_physics_process(false)
	return almacen


func _caja(almacen: Node3D, id: Producto.Id) -> Node3D:
	return almacen.get("_cajas_de_productos")[id]


func _contenido(almacen: Node3D, id: Producto.Id) -> ContenidoDeLaCaja:
	var repositor: Repositor = almacen.get("_repositor")
	return repositor.caja(id)


func _subtitulo(almacen: Node3D) -> Label:
	return almacen.get("_hud").get("_subtitulo")


func test_el_clic_con_su_unidad_en_la_mano_la_devuelve_a_la_caja() -> void:  # AC-STK-039
	var almacen: Node3D = await _almacen_con_jugador_quieto()
	var jugador: Node3D = almacen.get("_jugador")
	var agarre: Agarre = almacen.get("_agarre")
	var estante: Estante = almacen.get("_repositor").estante()
	var caja := _caja(almacen, Producto.Id.ACTRONCITO)
	var contenido := _contenido(almacen, Producto.Id.ACTRONCITO)
	var producto := contenido.producto
	var lleno := ReglasDelEstante.UNIDADES_POR_CAJA
	var disponibles := estante.disponibles_para_retirar(producto)
	var deposito := estante.unidades_en_deposito(producto)
	var gondola := estante.unidades_en_gondola(producto)
	_accion(jugador, caja, ReglasDelJugador.ACCION_USAR)
	assert_object(agarre.manos().sostenido() as UnidadDeProducto).is_not_null()
	assert_int(agarre.punto_de_producto.get_child_count()).is_equal(1)
	if agarre.punto_de_producto.get_child_count() == 0:
		return
	var cuerpo: Node3D = agarre.punto_de_producto.get_child(0)
	assert_bool(cuerpo.is_visible_in_tree()).is_true()
	assert_int(contenido.unidades()).is_equal(lleno - 1)
	_accion(jugador, caja, ReglasDelJugador.ACCION_USAR)
	assert_object(agarre.manos().sostenido()).is_null()
	assert_int(agarre.punto_de_producto.get_child_count()).is_zero()
	assert_bool(cuerpo.is_visible_in_tree()).is_false()
	assert_int(contenido.unidades()).is_equal(lleno)
	assert_int(estante.disponibles_para_retirar(producto)).is_equal(disponibles)
	assert_int(estante.unidades_en_deposito(producto)).is_equal(deposito)
	assert_int(estante.unidades_en_gondola(producto)).is_equal(gondola)
	# Y se vuelve a sacar: la caja pasa por 7, 8 y 7.
	_accion(jugador, caja, ReglasDelJugador.ACCION_USAR)
	assert_object(agarre.manos().sostenido() as UnidadDeProducto).is_not_null()
	assert_int(contenido.unidades()).is_equal(lleno - 1)


func test_con_otro_producto_en_la_mano_el_clic_no_hace_nada() -> void:  # AC-STK-038
	var almacen: Node3D = await _almacen_con_jugador_quieto()
	AperturaConLugar.abrir_con_todo_el_lugar(almacen)
	var jugador: Node3D = almacen.get("_jugador")
	var agarre: Agarre = almacen.get("_agarre")
	_accion(jugador, _caja(almacen, Producto.Id.MALBARDO), ReglasDelJugador.ACCION_USAR)
	var malbardo := agarre.manos().sostenido() as UnidadDeProducto
	assert_object(malbardo).is_not_null()
	var actroncito := _contenido(almacen, Producto.Id.ACTRONCITO)
	var antes := actroncito.unidades()
	_accion(jugador, _caja(almacen, Producto.Id.ACTRONCITO), ReglasDelJugador.ACCION_USAR)
	assert_object(agarre.manos().sostenido()).is_same(malbardo)
	assert_int(agarre.punto_de_producto.get_child_count()).is_equal(1)
	assert_int(actroncito.unidades()).is_equal(antes)
	assert_int(_contenido(almacen, Producto.Id.MALBARDO).unidades()).is_equal(
		ReglasDelEstante.UNIDADES_POR_CAJA - 1
	)


func test_con_una_caja_en_la_mano_el_clic_sobre_otra_no_hace_nada() -> void:  # AC-STK-038
	var almacen: Node3D = await _almacen_con_jugador_quieto()
	var jugador: Node3D = almacen.get("_jugador")
	var agarre: Agarre = almacen.get("_agarre")
	var llevada := _caja(almacen, Producto.Id.LAYSNTT)
	_accion(jugador, llevada, ReglasDeLosObjetos.ACCION_AGARRAR)
	assert_object(agarre.manos().sostenido()).is_same(llevada.get("datos"))
	var actroncito := _contenido(almacen, Producto.Id.ACTRONCITO)
	var estante: Estante = almacen.get("_repositor").estante()
	var disponibles := estante.disponibles_para_retirar(actroncito.producto)
	_accion(jugador, _caja(almacen, Producto.Id.ACTRONCITO), ReglasDelJugador.ACCION_USAR)
	assert_object(agarre.manos().sostenido()).is_same(llevada.get("datos"))
	assert_int(actroncito.unidades()).is_equal(ReglasDelEstante.UNIDADES_POR_CAJA)
	assert_int(estante.disponibles_para_retirar(actroncito.producto)).is_equal(disponibles)
	assert_int(agarre.punto_de_producto.get_child_count()).is_zero()


func test_con_la_caja_llena_la_unidad_sigue_en_la_mano() -> void:  # AC-STK-040
	# Una noche con nueve Coracola en el depósito: sacada una, la caja sigue con las de una caja
	# entera. Es lo que pasa al agarrar una unidad de la góndola con la caja llena (BR-STK-034).
	var almacen: Node3D = await _almacen_con_jugador_quieto()
	var puesto: Node3D = almacen.get("_reposicion_manual")
	var casilleros: Dictionary[Producto.Id, int] = puesto.call("casilleros")
	var inventario := Apertura.inventario_de_la_jornada(
		ReglasDeLaPartida.PRIMERA_JORNADA, casilleros
	)
	var coracola := Catalogo.de(Producto.Id.CORACOLA)
	inventario.ingresar(coracola, Inventario.Ubicacion.DEPOSITO, 1)
	var repositor: Repositor = almacen.get("_repositor")
	repositor.arrancar(Estante.new(inventario, Catalogo.todos()))
	puesto.call("limpiar")
	var jugador: Node3D = almacen.get("_jugador")
	var agarre: Agarre = almacen.get("_agarre")
	var caja := _caja(almacen, Producto.Id.CORACOLA)
	_accion(jugador, caja, ReglasDelJugador.ACCION_USAR)
	var unidad := agarre.manos().sostenido() as UnidadDeProducto
	assert_object(unidad).is_not_null()
	assert_int(repositor.caja(coracola.id).unidades()).is_equal(ReglasDelEstante.UNIDADES_POR_CAJA)
	_accion(jugador, caja, ReglasDelJugador.ACCION_USAR)
	assert_object(agarre.manos().sostenido()).is_same(unidad)
	assert_int(agarre.punto_de_producto.get_child_count()).is_equal(1)
	assert_int(repositor.caja(coracola.id).unidades()).is_equal(ReglasDelEstante.UNIDADES_POR_CAJA)


func test_una_unidad_soltada_y_levantada_se_devuelve() -> void:  # AC-STK-039
	var almacen: Node3D = await _almacen_con_jugador_quieto()
	var jugador: Node3D = almacen.get("_jugador")
	var agarre: Agarre = almacen.get("_agarre")
	var caja := _caja(almacen, Producto.Id.ACTRONCITO)
	var contenido := _contenido(almacen, Producto.Id.ACTRONCITO)
	_accion(jugador, caja, ReglasDelJugador.ACCION_USAR)
	var cuerpo: RigidBody3D = agarre.soltar(true)
	assert_object(cuerpo).is_not_null()
	if cuerpo == null:
		return
	await get_tree().physics_frame
	# En el piso sigue afuera de la caja.
	assert_int(contenido.unidades()).is_equal(ReglasDelEstante.UNIDADES_POR_CAJA - 1)
	assert_bool(agarre.pedir_agarrar(cuerpo.get("datos"), cuerpo)).is_true()
	_accion(jugador, caja, ReglasDelJugador.ACCION_USAR)
	assert_object(agarre.manos().sostenido()).is_null()
	assert_bool(cuerpo.is_visible_in_tree()).is_false()
	assert_int(contenido.unidades()).is_equal(ReglasDelEstante.UNIDADES_POR_CAJA)


func test_la_caja_vacia_no_entrega_aunque_la_gondola_tenga_lugar() -> void:  # AC-STK-016
	# Una noche con dos Actroncito en el depósito y su fila vacía: salen las dos, y a la góndola
	# todavía le faltan 6. Los demás productos abren con la caja llena y la fila completa.
	var almacen: Node3D = await _almacen_con_jugador_quieto()
	var puesto: Node3D = almacen.get("_reposicion_manual")
	var casilleros: Dictionary[Producto.Id, int] = puesto.call("casilleros")
	var inventario := Inventario.new(Catalogo.todos(), casilleros)
	for producto in Catalogo.todos():
		var es_actroncito := producto.id == Producto.Id.ACTRONCITO
		inventario.ingresar(
			producto,
			Inventario.Ubicacion.DEPOSITO,
			2 if es_actroncito else ReglasDelEstante.UNIDADES_POR_CAJA
		)
		inventario.ingresar(
			producto, Inventario.Ubicacion.GONDOLA, 0 if es_actroncito else casilleros[producto.id]
		)
	var repositor: Repositor = almacen.get("_repositor")
	repositor.arrancar(Estante.new(inventario, Catalogo.todos()))
	puesto.call("limpiar")
	var jugador: Node3D = almacen.get("_jugador")
	var agarre: Agarre = almacen.get("_agarre")
	var caja := _caja(almacen, Producto.Id.ACTRONCITO)
	for vez in 2:
		_accion(jugador, caja, ReglasDelJugador.ACCION_USAR)
		assert_object(agarre.manos().sostenido() as UnidadDeProducto).is_not_null()
		puesto.call("pedir_colocar", Producto.Id.ACTRONCITO)
		assert_object(agarre.manos().sostenido()).is_null()
	var actroncito := Catalogo.de(Producto.Id.ACTRONCITO)
	var estante := repositor.estante()
	assert_int(repositor.caja(actroncito.id).unidades()).is_zero()
	# Cuánto lugar queda lo dice el modelo; el 6 exacto lo mide el caso de `dominio/`.
	assert_int(estante.cupo(actroncito) - estante.unidades_en_gondola(actroncito)).is_greater(0)
	_accion(jugador, caja, ReglasDelJugador.ACCION_USAR)
	assert_object(agarre.manos().sostenido()).is_null()
	assert_int(agarre.punto_de_producto.get_child_count()).is_zero()


## Deja la caja de Actroncito en 7 con las manos vacías: saca una y la coloca en la góndola.
func _una_colocada(almacen: Node3D) -> void:
	_accion(
		almacen.get("_jugador"),
		_caja(almacen, Producto.Id.ACTRONCITO),
		ReglasDelJugador.ACCION_USAR
	)
	almacen.get("_reposicion_manual").call("pedir_colocar", Producto.Id.ACTRONCITO)


func test_la_caja_en_la_mano_muestra_su_cuenta_hasta_terminar_el_examen() -> void:  # AC-STK-042
	var almacen: Node3D = await _almacen_con_jugador_quieto()
	var jugador: Node3D = almacen.get("_jugador")
	var examen: Examen = jugador.get("examen")
	var caja := _caja(almacen, Producto.Id.ACTRONCITO)
	var contenido := _contenido(almacen, Producto.Id.ACTRONCITO)
	_una_colocada(almacen)
	assert_object(almacen.get("_agarre").manos().sostenido()).is_null()
	assert_int(contenido.unidades()).is_equal(ReglasDelEstante.UNIDADES_POR_CAJA - 1)
	_accion(jugador, caja, ReglasDeLosObjetos.ACCION_AGARRAR)
	_accion(jugador, caja, ReglasDeLosObjetos.ACCION_EXAMINAR)
	assert_bool(examen.esta_examinando()).is_true()
	assert_str(_subtitulo(almacen).text).is_equal(
		"Una caja con 7 cajitas de Actroncito. Entra 1 más."
	)
	var pista: String = (caja.get("datos") as ObjetoDelAlmacen).revelacion.texto
	assert_str(pista).is_not_empty()
	assert_str(_subtitulo(almacen).text).not_contains(pista)
	assert_bool(examen.hallazgos().ya_visto(caja.get("datos"))).is_true()
	_accion(jugador, caja, ReglasDeLosObjetos.ACCION_EXAMINAR)
	assert_bool(examen.esta_examinando()).is_false()
	assert_str(_subtitulo(almacen).text).is_empty()
	assert_int(contenido.unidades()).is_equal(ReglasDelEstante.UNIDADES_POR_CAJA - 1)


func test_manos_vacias_no_examinan_ni_muestran_la_caja() -> void:  # AC-STK-042, AC-INV-020
	var almacen: Node3D = await _almacen_con_jugador_quieto()
	var jugador: Node3D = almacen.get("_jugador")
	var agarre: Agarre = almacen.get("_agarre")
	var caja := _caja(almacen, Producto.Id.ACTRONCITO)
	_una_colocada(almacen)
	var lugar: Transform3D = caja.global_transform
	var contenido := _contenido(almacen, Producto.Id.ACTRONCITO)
	var unidades := contenido.unidades()
	for intento in 2:
		_accion(jugador, caja, ReglasDeLosObjetos.ACCION_EXAMINAR)
		assert_str(_subtitulo(almacen).text).is_empty()
		assert_bool(jugador.get("examen").esta_examinando()).is_false()
		assert_bool(jugador.get("_control").esta_suspendido()).is_false()
		assert_object(agarre.manos().sostenido()).is_null()
		assert_bool(caja.global_transform.is_equal_approx(lugar)).is_true()
		assert_int(contenido.unidades()).is_equal(unidades)
		assert_bool(jugador.get("examen").hallazgos().ya_visto(caja.get("datos"))).is_false()


func test_examinar_lo_que_no_es_una_caja_no_dice_nada() -> void:
	# El subtítulo es sólo de las cajas: la unidad en la mano se examina en silencio, como antes.
	var almacen: Node3D = await _almacen_con_jugador_quieto()
	var jugador: Node3D = almacen.get("_jugador")
	var caja := _caja(almacen, Producto.Id.ACTRONCITO)
	_accion(jugador, caja, ReglasDelJugador.ACCION_USAR)
	assert_object(almacen.get("_agarre").manos().sostenido() as UnidadDeProducto).is_not_null()
	_accion(jugador, caja, ReglasDeLosObjetos.ACCION_EXAMINAR)
	assert_bool(jugador.get("examen").esta_examinando()).is_true()
	assert_str(_subtitulo(almacen).text).is_empty()


func test_la_noche_nueva_borra_el_subtitulo_del_examen_en_curso() -> void:
	# Abrir la jornada termina el examen, y con él se va el texto.
	var almacen: Node3D = await _almacen_con_jugador_quieto()
	var jugador: Node3D = almacen.get("_jugador")
	var caja := _caja(almacen, Producto.Id.ACTRONCITO)
	_accion(jugador, caja, ReglasDeLosObjetos.ACCION_AGARRAR)
	_accion(jugador, caja, ReglasDeLosObjetos.ACCION_EXAMINAR)
	assert_str(_subtitulo(almacen).text).is_equal("Una caja con 8 cajitas de Actroncito.")
	almacen.call("_al_abrir_la_jornada", ReglasDeLaPartida.PRIMERA_JORNADA + 1)
	assert_str(_subtitulo(almacen).text).is_empty()
