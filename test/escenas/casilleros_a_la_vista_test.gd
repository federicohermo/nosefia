## Los casilleros de la góndola con el local armado: cuál se le ofrece a la mira, cuál se dibuja,
## en cuál coloca el clic y cuál agarra la mano vacía.
##
## Qué casillero espera la unidad y cuál se agarra lo decide el estante, y lo prueban los casos de
## `dominio/`. Acá va lo que sólo se ve con la escena: el contorno donde va la unidad, la mira que
## lo encuentra, y la copia de la góndola que se prende o se apaga.
##
## **Ningún caso escribe cuántos casilleros tiene una fila ni dónde está uno**: los dos los mide el
## modelo, y salen de la disposición, del estante de la noche o del casillero mismo.
extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.tscn")
const AperturaConLugar := preload("res://test/escenas/apertura_con_lugar.gd")
const CONTORNO := preload("res://src/sistemas/marco/contorno.gdshader")
const SIN_SUPERFICIE := "res://src/escenas/puestos/casillero_sin_superficie.gdshader"

## Hasta dónde se busca, delante de un casillero, un lugar donde el jugador entre parado, en
## metros, y de a cuánto se avanza. Los mismos que el caso de un lugar por producto.
const HASTA_EL_PASILLO := 1.5
const PASO_HACIA_EL_PASILLO := 0.05

## Cuánto se levanta el cuerpo al tantear el lugar: apoyado justo en el piso, lo toca.
const HOLGURA_DEL_PISO := 0.02

## A cuántos metros del casillero, del lado del pasillo, se para la mira que lo apunta: dentro
## del alcance y lejos del mueble.
const DISTANCIA_PARA_APUNTAR := 0.9

## Cuánto más alta que el casillero va la vista que lo apunta, en metros: la que tendría alguien
## parado frente al estante.
const ALTURA_PARA_APUNTAR := 0.25

## Cuánto más allá del alcance de la mira se buscan candidatos, en metros: la mira mide hasta la
## cara de un casillero, y acá se filtra por su centro.
const MARGEN_DEL_CAMPO := 0.3


func _almacen() -> Node3D:
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	almacen.get("_jugador").set_physics_process(false)
	return almacen


func _puesto(almacen: Node3D) -> Node3D:
	return almacen.get("_reposicion_manual")


func _estante(almacen: Node3D) -> Estante:
	return (almacen.get("_repositor") as Repositor).estante()


func _agarre(almacen: Node3D) -> Agarre:
	return almacen.get("_agarre")


func _casilleros(almacen: Node3D, producto: Producto) -> Array[Node]:
	return _puesto(almacen).get_node("ZonaDe" + producto.nombre).get_children()


func _frente(almacen: Node3D, producto: Producto) -> Vector3:
	var disposicion: DisposicionDeLaGondola = _puesto(almacen).get("disposicion")
	return DisposicionDeLaGondola.frente(
		disposicion.principales[producto.id], disposicion.filas_de_adelante[producto.id]
	)


## Pone la vista en `ojo`, mirando a `punto`, sin mover el cuerpo del jugador del mundo.
func _vista_en(almacen: Node3D, ojo: Vector3, punto: Vector3) -> void:
	var jugador: Node3D = almacen.get("_jugador")
	var camara: Camera3D = jugador.get_node("Giro/Camara")
	camara.position = Vector3.UP * ReglasDelJugador.ALTURA_DE_LA_CAMARA
	jugador.global_position = ojo - camara.position
	camara.look_at(punto)


## La vista con el foco real: el campo de la mira necesita pasos de física para ver lo que tiene
## adelante.
func _mirar_foco(almacen: Node3D, ojo: Vector3, punto: Vector3) -> void:
	_vista_en(almacen, ojo, punto)
	for cuadro in 4:
		await get_tree().physics_frame
	almacen.get("_jugador").call("_leer_la_mira")


## Dónde apunta la vista a un casillero: del lado del pasillo, un poco más arriba.
func _ojo_para(almacen: Node3D, casillero: Node3D) -> Vector3:
	var producto := Catalogo.de(casillero.get("producto"))
	return (
		casillero.global_position
		+ _frente(almacen, producto) * DISTANCIA_PARA_APUNTAR
		+ Vector3.UP * ALTURA_PARA_APUNTAR
	)


func _clic_real(almacen: Node3D) -> void:
	var clic := InputEventAction.new()
	clic.action = ReglasDeLosObjetos.ACCION_AGARRAR
	clic.pressed = true
	almacen.get("_jugador").call("_unhandled_input", clic)


## Los lugares de las copias que la góndola dibuja de ese producto, en el mundo.
func _dibujadas(almacen: Node3D, producto: Producto) -> Array[Vector3]:
	var grupo: MultiMeshInstance3D = _puesto(almacen).get_node("ProductosDe" + producto.nombre)
	var copias := grupo.multimesh
	var lugares: Array[Vector3] = []
	for indice in copias.visible_instance_count:
		var inicio := indice * DisposicionDeLaGondola.FLOTANTES_POR_COPIA
		var copia := DisposicionDeLaGondola.copia(
			copias.buffer.slice(inicio, inicio + DisposicionDeLaGondola.FLOTANTES_POR_COPIA), 0
		)
		lugares.append(grupo.global_transform * copia.origin)
	return lugares


## Dónde dibuja la góndola la unidad de un casillero: el lugar de su envase.
func _lugar_de(casillero: Node3D) -> Vector3:
	var vista: MeshInstance3D = casillero.get("vista")
	return vista.global_transform.origin


func _contiene(lugares: Array[Vector3], lugar: Vector3) -> bool:
	for otro in lugares:
		if otro.is_equal_approx(lugar):
			return true
	return false


## Si esa malla lleva encima el contorno del foco, con su color y su grosor.
func _lleva_el_contorno(vista: MeshInstance3D) -> bool:
	var encima := vista.material_overlay as ShaderMaterial
	return (
		encima != null
		and encima.shader == CONTORNO
		and encima.get_shader_parameter("color") == IndicacionDelFoco.COLOR
		and is_equal_approx(encima.get_shader_parameter("grosor"), IndicacionDelFoco.GROSOR)
	)


## Si esa malla se dibuja sin su superficie: con el material que no escribe ningún color.
func _sin_superficie(vista: MeshInstance3D) -> bool:
	var reemplazo := vista.material_override as ShaderMaterial
	return reemplazo != null and reemplazo.shader.resource_path == SIN_SUPERFICIE


## Pone la vista frente a ese casillero, a su alcance y sin enfocarlo, y le ofrece a la mira lo
## que tiene adelante.
func _pararse_frente_a(almacen: Node3D, casillero: Node3D) -> void:
	var ojo := _ojo_para(almacen, casillero)
	_vista_en(almacen, ojo, casillero.global_position)
	assert_float(ojo.distance_to(casillero.global_position)).is_less(
		ReglasDelJugador.ALCANCE_DE_LA_MIRA
	)
	assert_object(almacen.get("_jugador").get("_enfocado")).is_null()
	_puesto(almacen).call("_ofrecer_a_la_mira")


func _ninguno_dibujado(almacen: Node3D) -> void:
	for producto in Catalogo.todos():
		for casillero: Node3D in _casilleros(almacen, producto):
			var vista: MeshInstance3D = casillero.get("vista")
			(
				assert_bool(vista.visible)
				. override_failure_message("%s: %s se dibuja" % [producto.nombre, casillero.name])
				. is_false()
			)


## Los casilleros que la mira puede enfocar ahora: los que el puesto le ofrece.
func _ofrecidos(almacen: Node3D) -> Array[Node3D]:
	var ofrecidos: Array[Node3D] = []
	for producto in Catalogo.todos():
		for casillero: Node3D in _casilleros(almacen, producto):
			if casillero.get("collision_layer") != 0:
				ofrecidos.append(casillero)
	return ofrecidos


func test_ningun_casillero_vacio_se_dibuja_sin_la_mira_encima() -> void:  # AC-PLY-045
	var almacen := _almacen()
	var actroncito := Catalogo.de(Producto.Id.ACTRONCITO)
	var durextra := Catalogo.de(Producto.Id.DUREXTRA)
	var faltantes: Dictionary[Producto.Id, int] = {actroncito.id: 2, durextra.id: 2}
	AperturaConLugar.abrir_con_faltantes(almacen, faltantes)
	_puesto(almacen).call("retirar", actroncito.id)
	assert_object(_agarre(almacen).manos().sostenido()).is_not_null()
	var vacios: Array[Node3D] = []
	for producto: Producto in [actroncito, durextra]:
		var indices := _estante(almacen).casilleros_vacios(producto)
		assert_int(indices.size()).is_equal(2)
		for indice in indices:
			vacios.append(_puesto(almacen).call("casillero", producto.id, indice))
	# Con la unidad en la mano, parado frente a cada vacío: la mira puede enfocar los de su
	# producto y ningún otro, ni vacío ni ocupado, y ninguno se dibuja.
	for vacio in vacios:
		_pararse_frente_a(almacen, vacio)
		var ofrecidos := _ofrecidos(almacen)
		assert_bool(ofrecidos.has(vacio)).is_equal(vacio.get("producto") == actroncito.id)
		for ofrecido in ofrecidos:
			assert_int(ofrecido.get("producto")).is_equal(actroncito.id)
			assert_array(vacios).contains([ofrecido])
		_ninguno_dibujado(almacen)
	# Con la mano vacía la mira sólo puede enfocar lo ocupado, y con una caja o con una unidad de
	# una fila completa, nada. Ninguno se dibuja.
	_agarre(almacen).vaciar_las_manos()
	for vacio in vacios:
		_pararse_frente_a(almacen, vacio)
		for ofrecido in _ofrecidos(almacen):
			assert_array(vacios).not_contains([ofrecido])
		_ninguno_dibujado(almacen)
	var caja: Node3D = almacen.get("_cajas_de_productos")[actroncito.id]
	assert_bool(_agarre(almacen).pedir_agarrar(caja.get("datos"), caja)).is_true()
	_sin_casilleros_para_la_mira(almacen, vacios)
	_agarre(almacen).vaciar_las_manos()
	var burbaloo := Catalogo.de(Producto.Id.BURBALOO)
	assert_array(_estante(almacen).casilleros_vacios(burbaloo)).is_empty()
	var cuerpo: RigidBody3D = auto_free(RigidBody3D.new())
	add_child(cuerpo)
	assert_bool(_agarre(almacen).pedir_agarrar(UnidadDeProducto.new(burbaloo), cuerpo)).is_true()
	_sin_casilleros_para_la_mira(almacen, vacios)


func _sin_casilleros_para_la_mira(almacen: Node3D, vacios: Array[Node3D]) -> void:
	for vacio in vacios:
		_pararse_frente_a(almacen, vacio)
		assert_array(_ofrecidos(almacen)).is_empty()
		_ninguno_dibujado(almacen)


## Sin la mira encima, cada casillero guarda la superficie que no se ve y el contorno, apagados:
## el calentamiento de shaders dibuja una vez lo oculto con los materiales que lleva puestos, y
## así el primer casillero apuntado no compila ninguno.
func test_el_casillero_apagado_lleva_los_dos_materiales_del_apuntado() -> void:
	var almacen := _almacen()
	for producto in Catalogo.todos():
		for casillero: Node3D in _casilleros(almacen, producto):
			var vista: MeshInstance3D = casillero.get("vista")
			var nombre := "%s: %s" % [producto.nombre, casillero.name]
			assert_bool(vista.visible).override_failure_message(nombre).is_false()
			assert_bool(_sin_superficie(vista)).override_failure_message(nombre).is_true()
			assert_bool(_lleva_el_contorno(vista)).override_failure_message(nombre).is_true()


func test_el_clic_coloca_en_el_casillero_apuntado_y_no_en_otro() -> void:  # AC-PLY-048
	var almacen := _almacen()
	await get_tree().physics_frame
	var actroncito := Catalogo.de(Producto.Id.ACTRONCITO)
	var faltantes: Dictionary[Producto.Id, int] = {actroncito.id: 3}
	AperturaConLugar.abrir_con_faltantes(almacen, faltantes)
	var estante := _estante(almacen)
	var vacios := estante.casilleros_vacios(actroncito)
	var antes := estante.unidades_en_gondola(actroncito)
	_puesto(almacen).call("retirar", actroncito.id)
	# El del medio de los vacíos, que no es el primero: el clic no elige por el jugador.
	var elegido: Node3D = _puesto(almacen).call("casillero", actroncito.id, vacios[1])
	await _mirar_foco(almacen, _ojo_para(almacen, elegido), elegido.global_position)
	assert_object(almacen.get("_jugador").get("_enfocado")).is_same(elegido)
	_clic_real(almacen)
	assert_object(_agarre(almacen).manos().sostenido()).is_null()
	assert_array(estante.casilleros_ocupados(actroncito)).contains([vacios[1]])
	assert_array(estante.casilleros_vacios(actroncito)).is_equal([vacios[0], vacios[2]])
	assert_int(estante.unidades_en_gondola(actroncito)).is_equal(antes + 1)
	# Recién colocada y todavía enfocada, la dibuja su casillero con su material y el contorno
	# encima; sin el foco, la góndola.
	var vista: MeshInstance3D = elegido.get("vista")
	assert_bool(vista.visible).is_true()
	assert_object(vista.material_override).is_null()
	assert_bool(_lleva_el_contorno(vista)).is_true()
	almacen.get("_jugador").objetivo_perdido.emit()
	assert_bool(vista.visible).is_false()
	var dibujadas := _dibujadas(almacen, actroncito)
	assert_bool(_contiene(dibujadas, _lugar_de(elegido))).is_true()
	var primero: Node3D = _puesto(almacen).call("casillero", actroncito.id, vacios[0])
	assert_bool(_contiene(dibujadas, _lugar_de(primero))).is_false()
	# El segundo clic sobre el mismo casillero no coloca otra: con la mano vacía, agarra la que
	# acaba de colocar.
	_clic_real(almacen)
	assert_int(estante.unidades_en_gondola(actroncito)).is_equal(antes)
	assert_object(_agarre(almacen).manos().sostenido() as UnidadDeProducto).is_not_null()


func test_con_las_manos_vacias_se_agarra_la_del_medio() -> void:  # AC-PLY-049 AC-STK-044
	var almacen := _almacen()
	await get_tree().physics_frame
	var actroncito := Catalogo.de(Producto.Id.ACTRONCITO)
	var sin_faltantes: Dictionary[Producto.Id, int] = {}
	AperturaConLugar.abrir_con_faltantes(almacen, sin_faltantes)
	var estante := _estante(almacen)
	var ocupados := estante.casilleros_ocupados(actroncito)
	assert_int(ocupados.size()).is_equal(estante.cupo(actroncito))
	var medio := ocupados[ocupados.size() / 2]
	var elegido: Node3D = _puesto(almacen).call("casillero", actroncito.id, medio)
	var dibujadas_antes := _dibujadas(almacen, actroncito)
	await _mirar_foco(almacen, _ojo_para(almacen, elegido), elegido.global_position)
	assert_object(almacen.get("_jugador").get("_enfocado")).is_same(elegido)
	# Enfocada, la dibuja su casillero con su material y el contorno del foco encima, y la góndola
	# no: la unidad no se dibuja dos veces en el mismo lugar. Ninguna otra cambia.
	var vista: MeshInstance3D = elegido.get("vista")
	assert_bool(vista.visible).is_true()
	assert_object(vista.material_override).is_null()
	assert_bool(_lleva_el_contorno(vista)).is_true()
	for otro: Node3D in _casilleros(almacen, actroncito):
		if otro != elegido:
			assert_bool((otro.get("vista") as MeshInstance3D).visible).is_false()
	var enfocada := _dibujadas(almacen, actroncito)
	assert_int(enfocada.size()).is_equal(dibujadas_antes.size() - 1)
	assert_bool(_contiene(enfocada, _lugar_de(elegido))).is_false()
	_clic_real(almacen)
	var unidad := _agarre(almacen).manos().sostenido() as UnidadDeProducto
	assert_object(unidad).is_not_null()
	assert_int(unidad.producto.id).is_equal(actroncito.id)
	assert_array(estante.casilleros_vacios(actroncito)).is_equal([medio])
	var dibujadas := _dibujadas(almacen, actroncito)
	assert_int(dibujadas.size()).is_equal(dibujadas_antes.size() - 1)
	assert_bool(_contiene(dibujadas, _lugar_de(elegido))).is_false()
	for otra in dibujadas_antes:
		if not otra.is_equal_approx(_lugar_de(elegido)):
			assert_bool(_contiene(dibujadas, otra)).is_true()
	# Con la unidad en la mano y la mira todavía encima, el casillero que dejó espera la unidad:
	# queda sólo el contorno, sin la superficie de la unidad.
	assert_bool(vista.visible).is_true()
	assert_bool(_sin_superficie(vista)).is_true()
	assert_bool(_lleva_el_contorno(vista)).is_true()


func test_con_algo_en_la_mano_no_se_enfoca_ninguna_unidad_puesta() -> void:  # AC-PLY-049
	var almacen := _almacen()
	await get_tree().physics_frame
	var actroncito := Catalogo.de(Producto.Id.ACTRONCITO)
	var sin_faltantes: Dictionary[Producto.Id, int] = {}
	AperturaConLugar.abrir_con_faltantes(almacen, sin_faltantes)
	var caja: Node3D = almacen.get("_cajas_de_productos")[Producto.Id.DUREXTRA]
	assert_bool(_agarre(almacen).pedir_agarrar(caja.get("datos"), caja)).is_true()
	var elegido: Node3D = _puesto(almacen).call("casillero", actroncito.id, 0)
	await _mirar_foco(almacen, _ojo_para(almacen, elegido), elegido.global_position)
	var enfocado: Node3D = almacen.get("_jugador").get("_enfocado")
	assert_bool(enfocado != null and enfocado.get_parent().name.begins_with("ZonaDe")).is_false()
	for producto in Catalogo.todos():
		for casillero: Node3D in _casilleros(almacen, producto):
			assert_int(casillero.get("collision_layer")).is_zero()


func test_la_fila_de_atras_no_tiene_casilleros() -> void:  # AC-PLY-049
	# Cada casillero está donde va una unidad de la fila de adelante, y ninguno donde va una de
	# la de atrás: lo que la mira no encuentra, no se agarra.
	var almacen := _almacen()
	var disposicion: DisposicionDeLaGondola = _puesto(almacen).get("disposicion")
	for producto in Catalogo.todos():
		var bloque := disposicion.principales[producto.id]
		var fila := disposicion.filas_de_adelante[producto.id]
		var total := DisposicionDeLaGondola.copias(bloque)
		var casilleros := _casilleros(almacen, producto)
		assert_int(casilleros.size()).is_equal(fila)
		for casillero: Node3D in casilleros:
			var lugar := _lugar_de(casillero)
			var puesto_global: Transform3D = _puesto(almacen).global_transform
			var adelante := (
				puesto_global
				* DisposicionDeLaGondola.copia(bloque, total - fila + casillero.get("casillero"))
			)
			(
				assert_vector(lugar)
				. override_failure_message("%s: %s" % [producto.nombre, casillero.name])
				. is_equal_approx(adelante.origin, Vector3.ONE * 1e-4)
			)
			for atras in total - fila:
				var copia := puesto_global * DisposicionDeLaGondola.copia(bloque, atras)
				assert_bool(copia.origin.is_equal_approx(lugar)).is_false()


func test_la_de_la_gondola_se_suelta_y_se_devuelve_una_sola_vez() -> void:  # AC-STK-046 AC-STK-047
	var almacen := _almacen()
	var actroncito := Catalogo.de(Producto.Id.ACTRONCITO)
	var faltantes: Dictionary[Producto.Id, int] = {actroncito.id: 2}
	AperturaConLugar.abrir_con_faltantes(almacen, faltantes)
	var repositor: Repositor = almacen.get("_repositor")
	var estante := _estante(almacen)
	var puesto := _puesto(almacen)
	var caja: Node3D = almacen.get("_cajas_de_productos")[actroncito.id]
	var inventario: Inventario = estante.get("_inventario")
	var en_gondola := estante.unidades_en_gondola(actroncito)
	var vendibles := inventario.vendibles(actroncito)
	# Con la caja llena, la unidad de la góndola no entra, y sigue en la mano.
	var puesta: int = estante.casilleros_ocupados(actroncito)[0]
	puesto.call("agarrar_de_la_gondola", actroncito.id, puesta)
	var unidad := _agarre(almacen).manos().sostenido()
	assert_object(unidad as UnidadDeProducto).is_not_null()
	assert_int(repositor.caja(actroncito.id).unidades()).is_equal(
		ReglasDelEstante.UNIDADES_POR_CAJA
	)
	puesto.call("usar_la_caja", caja)
	assert_object(_agarre(almacen).manos().sostenido()).is_same(unidad)
	assert_int(repositor.caja(actroncito.id).unidades()).is_equal(
		ReglasDelEstante.UNIDADES_POR_CAJA
	)
	# Soltada en el piso, no cambia nada de la cuenta.
	var cuerpo: RigidBody3D = _agarre(almacen).soltar(true)
	assert_object(cuerpo).is_not_null()
	assert_int(estante.unidades_en_gondola(actroncito)).is_equal(en_gondola - 1)
	assert_int(inventario.vendibles(actroncito)).is_equal(vendibles)
	assert_int(repositor.caja(actroncito.id).unidades()).is_equal(
		ReglasDelEstante.UNIDADES_POR_CAJA
	)
	# Levantada y colocada, todo vuelve a como estaba.
	assert_bool(_agarre(almacen).pedir_agarrar(cuerpo.get("datos"), cuerpo)).is_true()
	puesto.call("pedir_colocar", actroncito.id, puesta)
	assert_object(_agarre(almacen).manos().sostenido()).is_null()
	assert_int(estante.unidades_en_gondola(actroncito)).is_equal(en_gondola)
	assert_int(inventario.vendibles(actroncito)).is_equal(vendibles)
	# Con lugar en la caja, la de la góndola vuelve a ella y la góndola sigue con ese hueco.
	puesto.call("retirar", actroncito.id)
	puesto.call("pedir_colocar", actroncito.id)
	var en_la_caja := repositor.caja(actroncito.id).unidades()
	assert_int(en_la_caja).is_equal(ReglasDelEstante.UNIDADES_POR_CAJA - 1)
	puesto.call("agarrar_de_la_gondola", actroncito.id, puesta)
	puesto.call("usar_la_caja", caja)
	assert_object(_agarre(almacen).manos().sostenido()).is_null()
	assert_int(repositor.caja(actroncito.id).unidades()).is_equal(en_la_caja + 1)
	assert_bool(estante.casilleros_vacios(actroncito).has(puesta)).is_true()


## Parado en el pasillo frente a cada casillero, y mirándolo, la mira lo elige a él entre todos
## los que tiene al alcance: ninguno queda escondido detrás del mueble ni tapado por el de al
## lado. Se mide con los rayos de la mira sobre todos los casilleros, sin pasos de física: el
## campo de la mira es la esfera de su alcance.
func test_cada_casillero_se_enfoca_desde_el_pasillo() -> void:  # AC-STK-029
	var almacen := _almacen()
	var sin_faltantes: Dictionary[Producto.Id, int] = {}
	AperturaConLugar.abrir_con_faltantes(almacen, sin_faltantes)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var jugador: Node3D = almacen.get("_jugador")
	var todos: Array[Node3D] = []
	for producto in Catalogo.todos():
		for casillero: Node3D in _casilleros(almacen, producto):
			todos.append(casillero)
	var perdidos: Array[String] = []
	for casillero in todos:
		var producto := Catalogo.de(casillero.get("producto"))
		var pie := _lugar_en_el_pasillo(
			almacen, casillero.global_position, _frente(almacen, producto)
		)
		if not pie.is_finite():
			perdidos.append("%s %s: sin lugar en el pasillo" % [producto.nombre, casillero.name])
			continue
		var ojo := pie + Vector3.UP * ReglasDelJugador.ALTURA_DE_LA_CAMARA
		_vista_en(almacen, ojo, casillero.global_position)
		# Lo que el puesto le ofrece a la mira es lo único que su campo encuentra.
		_puesto(almacen).call("_ofrecer_a_la_mira")
		var candidatos: Array[CampoDeInteraccion.Candidato] = []
		for otro in todos:
			if otro.get("collision_layer") == 0:
				continue
			if (
				otro.global_position.distance_to(ojo)
				> ReglasDelJugador.ALCANCE_DE_LA_MIRA + MARGEN_DEL_CAMPO
			):
				continue
			candidatos.append(jugador.call("_medir_candidato", otro))
		var elegido := CampoDeInteraccion.elegir(candidatos)
		if elegido != casillero.get_instance_id():
			perdidos.append("%s %s" % [producto.nombre, casillero.name])
	assert_array(perdidos).is_empty()


## Dónde se para el jugador frente a un punto de un estante: el primer lugar, avanzando desde
## ahí hacia el pasillo, donde su cuerpo entra sin chocar con nada de lo que lo frena. Sin
## ninguno antes de `HASTA_EL_PASILLO`, `Vector3.INF`.
func _lugar_en_el_pasillo(almacen: Node3D, delante: Vector3, frente: Vector3) -> Vector3:
	var jugador: CharacterBody3D = almacen.get("_jugador")
	var cuerpo: CollisionShape3D = jugador.get_node("Cuerpo")
	var consulta := PhysicsShapeQueryParameters3D.new()
	consulta.shape = cuerpo.shape
	consulta.collision_mask = jugador.collision_mask
	consulta.exclude = [jugador.get_rid()]
	var espacio := almacen.get_world_3d().direct_space_state
	var distancia := 0.0
	while distancia <= HASTA_EL_PASILLO:
		var punto := Vector3(delante.x, 0.0, delante.z) + frente * distancia
		var piso := espacio.intersect_ray(
			PhysicsRayQueryParameters3D.create(punto + Vector3.UP, punto + Vector3.DOWN, 1)
		)
		distancia += PASO_HACIA_EL_PASILLO
		if piso.is_empty():
			continue
		var pie: Vector3 = piso["position"]
		consulta.transform = Transform3D(
			Basis.IDENTITY, pie + cuerpo.position + Vector3.UP * HOLGURA_DEL_PISO
		)
		if espacio.intersect_shape(consulta, 1).is_empty():
			return pie
	return Vector3.INF
