## Las manchas se pueden enfocar y limpiar sin quedar tapadas por muebles.
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
	# Con el material compartido entre las instancias, pintar el moho de verde pintaría las cuatro.
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
	# repitiendo el mismo lugar en el `.tscn` el conteo sigue dando cuatro, el lugar que falta no se
	# puede borrar nunca y la obligatoria queda inalcanzable, y ningún gate lo ve.
	var almacen: Node3D = await _almacen()
	var manchas := _manchas(almacen)
	assert_int(manchas.size()).is_equal(PisoDelLocal.Lugar.size())
	var declarados := {}
	for mancha: ManchaQueSeVe in manchas:
		declarados[mancha.lugar_de_la_mancha()] = true
	for lugar: PisoDelLocal.Lugar in PisoDelLocal.Lugar.values():
		(
			assert_bool(declarados.has(lugar))
			. override_failure_message("ninguna mancha del almacén está en el lugar %d" % lugar)
			. is_true()
		)


## Ninguna mancha arranca debajo de un mueble, ni tapada.
##
## **La mopa no atraviesa la góndola**, así que una mancha tapada es una tarea que no se puede
## terminar. Y no se ve venir: el `.tscn` de la limpieza declara las posiciones, el del local
## declara dónde están los muebles, y mover un mueble no toca el otro archivo. Pasó el 2026-09-20
## con la góndola del pasillo corrida noventa centímetros.
##
## Se mide sobre la cara de cada mancha, hacia el cuarto: para las del piso es hacia arriba, y para
## la de la pared, hacia adelante.
func test_ninguna_mancha_arranca_debajo_de_un_mueble() -> void:  # AC-CLN-017
	var almacen: Node3D = await _almacen()
	var espacio := almacen.get_world_3d().direct_space_state
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
		consulta.exclude = [(mancha as CollisionObject3D).get_rid()]
		var encima: Array[String] = []
		for choque in espacio.intersect_shape(consulta, 8):
			var quien: String = str(almacen.get_path_to(choque["collider"]))
			if quien.contains("Suelo") or quien.contains("Jugador"):
				continue
			encima.append(quien)
		(
			assert_array(encima)
			. override_failure_message(
				"`%s` arranca en %v, tapada por %s" % [mancha.name, mancha.global_position, encima]
			)
			. is_empty()
		)


func test_la_mira_enfoca_cada_mancha() -> void:  # AC-CLN-017
	# Se para al jugador delante de la cara de cada mancha, a un metro, y se le deja leer la mira
	# como en el juego.
	var almacen: Node3D = await _almacen()
	var jugador: Node3D = almacen.get("_jugador")
	jugador.set_physics_process(false)
	var camara: Camera3D = jugador.get_node("Giro/Camara")
	camara.position = Vector3.UP * ReglasDelJugador.ALTURA_DE_LA_CAMARA
	for mancha: ManchaQueSeVe in _manchas(almacen):
		var cara := _cara(mancha)
		var enfocada := false
		for lado: Vector3 in [Vector3.BACK, Vector3.FORWARD, Vector3.LEFT, Vector3.RIGHT]:
			var frente := lado if absf(cara.y) > 0.5 else cara
			jugador.global_position = mancha.global_position + frente
			jugador.global_position.y = 0.112
			camara.look_at(mancha.global_position + cara * 0.03)
			for cuadro in 4:
				await get_tree().physics_frame
			jugador.call("_leer_la_mira")
			if jugador.get("_enfocado") == mancha:
				enfocada = true
				break
		assert_bool(enfocada).override_failure_message("`%s` no se enfoca" % mancha.name).is_true()


func test_cada_mancha_se_ve_del_color_de_su_tipo() -> void:  # AC-CLN-015
	var almacen: Node3D = await _almacen()
	var moho := _mancha_de(almacen, PisoDelLocal.Lugar.DEPOSITO).color()
	assert_float(moho.g).is_greater(moho.r)
	assert_float(moho.g).is_greater(moho.b)
	var caca := _mancha_de(almacen, PisoDelLocal.Lugar.BANO).color()
	assert_float(caca.r).is_greater(caca.g)
	assert_float(caca.g).is_greater(caca.b)
	assert_float(caca.v).is_less(LO_MAS_CLARO_DEL_MARRON)
	# Y es el color que declara el dominio para el tipo de mancha que hay en ese lugar.
	var piso: PisoDelLocal = (almacen.get("_limpiador") as Limpiador).piso()
	for mancha: ManchaQueSeVe in _manchas(almacen):
		var declarado := piso.mancha_de(mancha.lugar_de_la_mancha()).color()
		assert_bool(Color(mancha.color(), 1.0).is_equal_approx(Color(declarado, 1.0))).is_true()


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
