## Las manchas de cada noche se pueden enfocar y limpiar desde el piso sin quedar tapadas por
## muebles, y las de otra noche no se ven.
extends GdUnitTestSuite

const SCRIPT := "res://src/escenas/objetos/mancha_en_el_piso.gd"
const PUESTO := "res://src/escenas/puestos/limpieza_del_almacen.gd"

## El script del nodo se preloadea para poder tiparlo: los scripts de `escenas/` son cáscara y no
## declaran `class_name`.
const ManchaQueSeVe := preload("res://src/escenas/objetos/mancha_en_el_piso.gd")
const ESCENA := preload("res://src/escenas/objetos/mancha_en_el_piso.tscn")
const ALMACEN := preload("res://src/escenas/almacen.tscn")

## Lo alto que llega el jugador. Una mancha tapada por encima de esto no le estorba la mopa.
const ALTO_DEL_JUGADOR := 1.8

## Lo que delataría una regla escrita en la mancha. Está medido que ahí los dos gates dan verde.
const PATRONES_DE_DECISION := "(?m)^\\s*(if|elif|match)\\b|var\\s+_(limpia|tipo|jabon|agua)\\b"

## Lo más claro que puede ser un marrón.
const LO_MAS_CLARO_DEL_MARRON := 0.5

## Las dos noches que la ficha decide; de la tercera a la quinta arrancan como la primera.
const JORNADAS: Array[int] = [1, 2]

## Dónde quedan los pies del jugador parado en el piso del almacén.
const ALTURA_DEL_JUGADOR := 0.112

## Lo más claro que puede ser el negro o gris del polvo.
const LO_MAS_CLARO_DEL_POLVO := 0.25

## A qué distancias del piso se prueba enfocar una mancha, en horizontal: de la más cómoda a la
## más estirada que todavía deja la mira dentro de su alcance.
const DISTANCIAS_DE_MIRA: Array[float] = [1.0, 0.7, 1.3, 1.6]


func _almacen() -> Node3D:
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	await get_tree().physics_frame
	return almacen


func _manchas(almacen: Node3D) -> Array:
	return almacen.get("_limpieza").call("manchas")


## La mancha del almacén que está en ese lugar.
func _mancha_de(almacen: Node3D, lugar: PisoDelLocal.Lugar) -> ManchaQueSeVe:
	for mancha: ManchaQueSeVe in _manchas(almacen):
		if mancha.lugar_de_la_mancha() == lugar:
			return mancha
	return null


func _piso(almacen: Node3D) -> PisoDelLocal:
	return (almacen.get("_limpiador") as Limpiador).piso()


## Abre esa jornada, si no es la que está abierta, y abre las puertas de los cubículos: lo que
## está adentro se alcanza como en la partida, con la hoja abierta.
func _abrir(almacen: Node3D, jornada: int) -> void:
	if (almacen.get("_partida") as Partida).jornada() != jornada:
		almacen.call("_al_abrir_la_jornada", jornada)
	for numero: int in [1, 2]:
		almacen.get_node("Estructura/bano_puerta_%d/CuerpoDeLaHoja" % numero).call("alternar")
	for cuadro in 60:
		await get_tree().physics_frame


## Los puntos del piso desde donde se prueba mirar una mancha: delante de su cara si está en una
## pared, y alrededor si está en el piso o en el techo.
static func _puntos_de_mira(mancha: Node3D) -> Array[Vector3]:
	var cara := _cara(mancha)
	var direcciones: Array[Vector3] = []
	if absf(cara.y) < 0.5:
		var frente := Vector3(cara.x, 0.0, cara.z).normalized()
		var costado := frente.cross(Vector3.UP)
		direcciones = [
			frente, (frente + costado * 0.5).normalized(), (frente - costado * 0.5).normalized()
		]
	else:
		for paso in 8:
			direcciones.append(Vector3.BACK.rotated(Vector3.UP, TAU * paso / 8.0))
	var puntos: Array[Vector3] = []
	for distancia in DISTANCIAS_DE_MIRA:
		for direccion in direcciones:
			var punto := mancha.global_position + direccion * distancia
			punto.y = ALTURA_DEL_JUGADOR
			puntos.append(punto)
	return puntos


## Si la mira enfoca la mancha con el jugador parado en algún punto libre del piso, mirándola
## sin pasar el tope del cuello. Lo libre se mide con el cuerpo del jugador contra lo que lo frena.
func _enfocar(almacen: Node3D, mancha: Node3D) -> bool:
	var jugador: CharacterBody3D = almacen.get("_jugador")
	var camara: Camera3D = jugador.get_node("Giro/Camara")
	var cuerpo := jugador.get_node("Cuerpo") as CollisionShape3D
	var espacio := almacen.get_world_3d().direct_space_state
	camara.position = Vector3.UP * ReglasDelJugador.ALTURA_DE_LA_CAMARA
	var blanco := mancha.global_position + _cara(mancha) * 0.03
	for punto in _puntos_de_mira(mancha):
		jugador.global_position = punto
		var consulta := PhysicsShapeQueryParameters3D.new()
		consulta.shape = cuerpo.shape
		consulta.transform = cuerpo.global_transform
		consulta.collision_mask = jugador.collision_mask
		consulta.exclude = [jugador.get_rid()]
		if not espacio.intersect_shape(consulta, 1).is_empty():
			continue
		var hacia := blanco - camara.global_position
		var inclinacion := atan2(absf(hacia.y), Vector2(hacia.x, hacia.z).length())
		if inclinacion > ReglasDelJugador.PITCH_MAXIMO:
			continue
		camara.look_at(blanco)
		for cuadro in 4:
			await get_tree().physics_frame
		jugador.call("_leer_la_mira")
		if jugador.get("_enfocado") == mancha:
			return true
	return false


## Hacia dónde mira la cara de la mancha: el arriba del disco.
static func _cara(mancha: Node3D) -> Vector3:
	return mancha.global_basis.y.normalized()


func test_la_mancha_no_decide_nada() -> void:
	# Está medido que un contador o un `if` sobre si la mancha se borró, escritos en
	# `src/escenas/`, dan cero hallazgos en `capas` **y** en `tdd`. Por eso el criterio los ata
	# con una búsqueda sobre el archivo, que es lo único ejecutable que hay.
	var texto := FileAccess.get_file_as_string(SCRIPT)
	assert_str(texto).is_not_empty()
	var decide := RegEx.create_from_string(PATRONES_DE_DECISION).search_all(texto)
	(
		assert_array(decide)
		. override_failure_message("`mancha_en_el_piso.gd` decide o lleva estado del juego")
		. is_empty()
	)


func test_la_mancha_esta_en_el_grupo_que_la_mira_puede_enfocar() -> void:
	# Las dos mitades del contrato se separan acá, y no son la misma cosa: **el grupo dice que la
	# mira la puede enfocar; `interactuar()` dice que el clic izquierdo es suyo.** De una mancha
	# no se levanta nada —la mopa entra por el otro botón—, así que le corresponde el grupo y no
	# el método.
	var mancha: ManchaQueSeVe = auto_free(ESCENA.instantiate())
	assert_bool(mancha.is_in_group(ReglasDelJugador.GRUPO_INTERACTUABLE)).is_true()
	(
		assert_bool(mancha.has_method(ReglasDeLosObjetos.METODO_INTERACTUAR))
		. override_failure_message("la mancha declara el clic izquierdo como propio y no lo usa")
		. is_false()
	)


func test_la_mancha_borrada_deja_de_verse_y_de_enfocarse() -> void:
	# Esconder un nodo **no apaga su cuerpo**: con el cuerpo prendido, una mancha ya borrada sigue
	# frenando el rayo de la mira y se sigue enfocando, con la escena cargando sin un solo error.
	var mancha: ManchaQueSeVe = auto_free(ESCENA.instantiate())
	# Volver a mostrarla perturba el agua según su orientación en el mundo.
	add_child(mancha)
	assert_bool(mancha.is_inside_tree()).is_true()
	var cuerpo := mancha.get_node("Cuerpo") as CollisionShape3D
	mancha.mostrar(false, Color.GREEN)
	assert_bool(mancha.visible).is_false()
	(
		assert_bool(cuerpo.disabled)
		. override_failure_message("la mancha borrada sigue enfocándose")
		. is_true()
	)
	# Y vuelve cuando la jornada la trae sucia otra vez: el cableado repinta cada apertura.
	mancha.mostrar(true, Color.GREEN)
	assert_bool(mancha.visible).is_true()
	assert_bool(cuerpo.disabled).is_false()


func test_cada_mancha_lleva_su_propia_pintura() -> void:
	# Con el material compartido entre las instancias, pintar el moho de verde pintaría todas.
	var una: ManchaQueSeVe = auto_free(ESCENA.instantiate())
	var otra: ManchaQueSeVe = auto_free(ESCENA.instantiate())
	add_child(una)
	add_child(otra)
	una.mostrar(true, Color.GREEN)
	otra.mostrar(true, Color.RED)
	assert_that(Color(una.color(), 1.0)).is_equal(Color.GREEN)
	assert_that(Color(otra.color(), 1.0)).is_equal(Color.RED)


func test_el_uso_entra_por_el_pedido_del_jugador() -> void:
	var texto := FileAccess.get_file_as_string(PUESTO)
	assert_bool(texto.contains("jugador.uso_pedido.connect")).is_true()
	assert_bool(texto.contains("func _unhandled_input(")).is_false()


func test_el_almacen_trae_una_mancha_por_lugar() -> void:  # AC-CLN-016
	# **Contarlas no alcanza, hay que mirar qué lugar declara cada una.** Con dos manchas
	# repitiendo el mismo lugar en el `.tscn` el conteo sigue dando lo mismo, el lugar que falta no
	# se puede borrar nunca y la obligatoria queda inalcanzable, y ningún gate lo ve.
	var almacen: Node3D = await _almacen()
	var discos: Array = almacen.get("_limpieza").call("_todas_las_manchas")
	assert_int(discos.size()).is_equal(PisoDelLocal.Lugar.size())
	var declarados := {}
	for mancha: ManchaQueSeVe in discos:
		declarados[mancha.lugar_de_la_mancha()] = true
	for lugar: PisoDelLocal.Lugar in PisoDelLocal.Lugar.values():
		(
			assert_bool(declarados.has(lugar))
			. override_failure_message("ninguna mancha del almacén está en el lugar %d" % lugar)
			. is_true()
		)
	# Y las de la noche son exactamente las que el piso de la jornada declara.
	for jornada: int in JORNADAS:
		await _abrir(almacen, jornada)
		var de_la_noche := []
		for mancha: ManchaQueSeVe in _manchas(almacen):
			de_la_noche.append(mancha.lugar_de_la_mancha())
		assert_array(de_la_noche).contains_exactly_in_any_order(_piso(almacen).lugares())


## Ninguna mancha de la noche arranca debajo de un mueble, ni tapada.
##
## **La mopa no atraviesa la góndola**, así que una mancha tapada es una tarea que no se puede
## terminar. Y no se ve venir: el `.tscn` de la limpieza declara las posiciones, el del local
## declara dónde están los muebles, y mover un mueble no toca el otro archivo. Pasó el 2026-09-20
## con la góndola del pasillo corrida noventa centímetros.
##
## Se mide sobre la cara de cada mancha, hacia el cuarto: para las del piso es hacia arriba, para
## las de pared hacia adelante y para la del techo hacia abajo. **Una puerta no es un mueble**: se
## abre, y la caca de debajo de la del cubículo se enfoca con la hoja abierta.
func test_ninguna_mancha_arranca_debajo_de_un_mueble() -> void:  # AC-CLN-017
	var almacen: Node3D = await _almacen()
	var espacio := almacen.get_world_3d().direct_space_state
	var puertas: Array[RID] = []
	for puerta: CollisionObject3D in almacen.get("_puertas"):
		puertas.append(puerta.get_rid())
	for jornada: int in JORNADAS:
		await _abrir(almacen, jornada)
		for mancha: ManchaQueSeVe in _manchas(almacen):
			var cilindro := (mancha.get_node("Cuerpo") as CollisionShape3D).shape as CylinderShape3D
			var forma := CylinderShape3D.new()
			forma.radius = cilindro.radius
			forma.height = ALTO_DEL_JUGADOR
			var consulta := PhysicsShapeQueryParameters3D.new()
			consulta.shape = forma
			consulta.transform = Transform3D(
				mancha.global_basis.orthonormalized(),
				mancha.global_position + _cara(mancha) * (ALTO_DEL_JUGADOR * 0.5 + 0.01)
			)
			consulta.exclude = puertas + [(mancha as CollisionObject3D).get_rid()]
			var encima: Array[String] = []
			for choque in espacio.intersect_shape(consulta, 8):
				var quien: String = str(almacen.get_path_to(choque["collider"]))
				if quien.contains("Suelo") or quien.contains("Jugador"):
					continue
				encima.append(quien)
			(
				assert_array(encima)
				. override_failure_message(
					(
						"`%s` arranca en %v, tapada por %s"
						% [mancha.name, mancha.global_position, encima]
					)
				)
				. is_empty()
			)


func test_cada_mancha_esta_en_su_habitacion_y_su_superficie() -> void:  # AC-CLN-017
	var almacen: Node3D = await _almacen()
	var habitaciones: Node3D = almacen.get("_habitaciones")
	for jornada: int in JORNADAS:
		await _abrir(almacen, jornada)
		for mancha: ManchaQueSeVe in _manchas(almacen):
			var lugar := mancha.lugar_de_la_mancha()
			(
				assert_int(habitaciones.call("de", mancha.global_position))
				. override_failure_message("`%s` no está en su habitación" % mancha.name)
				. is_equal(PisoDelLocal.habitacion_de(lugar))
			)
			var cara := _cara(mancha)
			match PisoDelLocal.superficie_de(lugar):
				PisoDelLocal.Superficie.PISO:
					assert_float(cara.y).is_greater(0.99)
				PisoDelLocal.Superficie.PARED:
					assert_float(absf(cara.y)).is_less(0.01)
				PisoDelLocal.Superficie.TECHO:
					assert_float(cara.y).is_less(-0.99)


func test_la_mira_enfoca_cada_mancha_desde_el_piso() -> void:  # AC-CLN-017
	var almacen: Node3D = await _almacen()
	var jugador: Node3D = almacen.get("_jugador")
	jugador.set_physics_process(false)
	for jornada: int in JORNADAS:
		await _abrir(almacen, jornada)
		for mancha: ManchaQueSeVe in _manchas(almacen):
			(
				assert_bool(await _enfocar(almacen, mancha))
				. override_failure_message(
					"`%s` no se enfoca desde el piso en la jornada %d" % [mancha.name, jornada]
				)
				. is_true()
			)


func test_las_manchas_de_otra_noche_no_se_ven_ni_se_enfocan() -> void:  # AC-CLN-017
	var almacen: Node3D = await _almacen()
	var jugador: Node3D = almacen.get("_jugador")
	jugador.set_physics_process(false)
	for jornada: int in JORNADAS:
		await _abrir(almacen, jornada)
		var ajenas := 0
		for mancha: ManchaQueSeVe in almacen.get("_limpieza").call("_todas_las_manchas"):
			if _piso(almacen).mancha_de(mancha.lugar_de_la_mancha()) != null:
				continue
			ajenas += 1
			assert_bool(mancha.visible).override_failure_message(mancha.name).is_false()
			var cuerpo := mancha.get_node("Cuerpo") as CollisionShape3D
			assert_bool(cuerpo.disabled).override_failure_message(mancha.name).is_true()
			(
				assert_bool(await _enfocar(almacen, mancha))
				. override_failure_message("`%s` se enfoca en otra noche" % mancha.name)
				. is_false()
			)
		assert_int(ajenas).is_equal(PisoDelLocal.Lugar.size() - _piso(almacen).lugares().size())


func test_el_paso_toca_solo_las_manchas_del_piso() -> void:  # AC-CLN-058
	var almacen: Node3D = await _almacen()
	var jugador: Node3D = almacen.get("_jugador")
	jugador.set_physics_process(false)
	for jornada: int in JORNADAS:
		await _abrir(almacen, jornada)
		for mancha: ManchaQueSeVe in _manchas(almacen):
			var lugar := mancha.lugar_de_la_mancha()
			var cara := _cara(mancha)
			# Al lado de la del piso o de la pared, y justo debajo de la del techo.
			var al_lado := Vector3(cara.x, 0.0, cara.z) * 0.5
			if absf(cara.y) > 0.5:
				al_lado = Vector3.RIGHT * 0.5 if cara.y > 0.0 else Vector3.ZERO
			jugador.global_position = mancha.global_position + al_lado
			jugador.global_position.y = ALTURA_DEL_JUGADOR
			var malla := mancha.get_node("Malla")
			malla.set("_onda", 0.0)
			jugador.emit_signal("paso_dado")
			var del_piso := PisoDelLocal.superficie_de(lugar) == PisoDelLocal.Superficie.PISO
			(
				assert_bool(malla.get("_onda") > 0.0)
				. override_failure_message(
					"`%s` y el paso, en la jornada %d" % [mancha.name, jornada]
				)
				. is_equal(del_piso)
			)


func test_cada_mancha_se_ve_del_color_de_su_tipo() -> void:  # AC-CLN-015
	var almacen: Node3D = await _almacen()
	for jornada: int in JORNADAS:
		await _abrir(almacen, jornada)
		var piso := _piso(almacen)
		for mancha: ManchaQueSeVe in _manchas(almacen):
			var color := mancha.color()
			match piso.mancha_de(mancha.lugar_de_la_mancha()).tipo():
				ReglasDeLaLimpieza.TipoDeMancha.MOHO:
					assert_float(color.g).is_greater(color.r)
					assert_float(color.g).is_greater(color.b)
				ReglasDeLaLimpieza.TipoDeMancha.CACA:
					assert_float(color.r).is_greater(color.g)
					assert_float(color.g).is_greater(color.b)
					assert_float(color.v).is_less(LO_MAS_CLARO_DEL_MARRON)
				ReglasDeLaLimpieza.TipoDeMancha.POLVO:
					# Negro o gris: oscuro y sin un canal que domine.
					assert_float(color.v).is_less(LO_MAS_CLARO_DEL_POLVO)
					(
						assert_float(
							(
								maxf(color.r, maxf(color.g, color.b))
								- minf(color.r, minf(color.g, color.b))
							)
						)
						. is_less(0.05)
					)
			# Y es el color que declara el dominio para el tipo de mancha que hay en ese lugar.
			var declarado := piso.mancha_de(mancha.lugar_de_la_mancha()).color()
			assert_bool(Color(color, 1.0).is_equal_approx(Color(declarado, 1.0))).is_true()


func test_con_el_balde_en_la_mano_no_se_agarra_un_jabon() -> void:
	# **Limpiar se paga en gestos**, y no hay que escribirlo: sale de reusar una sola mano. Teñir
	# el balde pide soltarlo, agarrar el jabón y apuntarle al balde.
	var manos := Manos.new()
	var balde := load("res://src/dominio/almacen/balde.tres") as ObjetoDelAlmacen
	var jabon := load("res://src/dominio/almacen/jabon_azul.tres") as ObjetoDelAlmacen
	assert_bool(manos.agarrar(balde)).is_true()
	assert_int(manos.motivo_de_rechazo(jabon)).is_equal(Manos.Rechazo.MANOS_LLENAS)


func test_las_reglas_de_limpieza_tienen_sus_espejos() -> void:
	# Cada regla y sistema de limpieza conserva su suite propia.
	for ruta: String in [
		"res://src/dominio/almacen/reglas_de_la_limpieza.gd",
		"res://src/dominio/almacen/mancha.gd",
		"res://src/dominio/almacen/balde.gd",
		"res://src/dominio/almacen/mopa.gd",
		"res://src/dominio/almacen/piso_del_local.gd",
		"res://src/sistemas/tareas/limpiador.gd",
	]:
		var espejo := ruta.replace("res://src/", "res://test/").replace(".gd", "_test.gd")
		(
			assert_bool(FileAccess.file_exists(espejo))
			. override_failure_message("falta el espejo `%s`" % espejo)
			. is_true()
		)
