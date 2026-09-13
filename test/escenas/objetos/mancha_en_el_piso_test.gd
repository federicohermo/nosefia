## Las manchas que se ven: que no decidan nada, y que el recorrido exista en la escena.
##
## **El caso del recorrido es el que este spec no puede escribir en prosa.** Las posiciones se
## componen a mano subiendo por los padres y no con `global_position`: esta suite no entra la
## escena al árbol, y ahí el global aborta con `Condition "!is_inside_tree()" is true` devolviendo
## la identidad — o sea que el caso no fallaría por la geometría, pasaría siempre.
extends GdUnitTestSuite

const ESCENA := "res://src/escenas/objetos/mancha_en_el_piso.tscn"
const SCRIPT := "res://src/escenas/objetos/mancha_en_el_piso.gd"
const PUESTO := "res://src/escenas/puestos/limpieza_del_almacen.gd"
const ESCENA_DEL_ALMACEN := "res://src/escenas/almacen.tscn"
const TRAPEADOR := "res://src/dominio/almacen/trapeador.tres"

## El script del nodo se preloadea para poder tiparlo: los scripts de `escenas/` son cáscara y no
## declaran `class_name`.
const ManchaQueSeVe := preload("res://src/escenas/objetos/mancha_en_el_piso.gd")

## Lo que delataría una regla escrita en la mancha. Está medido que ahí los dos gates dan verde.
const PATRONES_DE_DECISION := "(?m)^\\s*(if|elif|match)\\b|var\\s+_pasadas|var\\s+_restantes"


func _mancha() -> ManchaQueSeVe:
	return auto_free(load(ESCENA).instantiate())


func _almacen() -> Node3D:
	return auto_free(load(ESCENA_DEL_ALMACEN).instantiate())


## La posición de un nodo respecto de la raíz que se le pase, componiendo los `transform` de los
## padres. Es lo que reemplaza a `global_position` en una escena que no entró al árbol.
static func _posicion_en(raiz: Node, nodo: Node3D) -> Vector3:
	var compuesta := Transform3D.IDENTITY
	var actual: Node = nodo
	while actual != null and actual != raiz:
		var tridimensional := actual as Node3D
		if tridimensional != null:
			compuesta = tridimensional.transform * compuesta
		actual = actual.get_parent()
	return compuesta.origin


## Todas las manchas del almacén instanciado.
static func _nodos_de_mancha(almacen: Node) -> Array[ManchaQueSeVe]:
	var manchas: Array[ManchaQueSeVe] = []
	for nodo in _descendientes(almacen):
		var mancha := nodo as ManchaQueSeVe
		if mancha == null:
			continue
		manchas.append(mancha)
	return manchas


## Todas las manchas del almacén instanciado, con su posición ya compuesta.
static func _manchas_de(almacen: Node) -> Array[Vector3]:
	var posiciones: Array[Vector3] = []
	for mancha in _nodos_de_mancha(almacen):
		posiciones.append(_posicion_en(almacen, mancha))
	return posiciones


static func _descendientes(nodo: Node) -> Array[Node3D]:
	var todos: Array[Node3D] = []
	for hijo in nodo.get_children():
		var tridimensional := hijo as Node3D
		if tridimensional == null:
			continue
		todos.append(tridimensional)
		todos.append_array(_descendientes(tridimensional))
	return todos


func test_la_mancha_no_decide_ni_lleva_contador() -> void:  # 014-AC9
	# Está medido que un contador de pasadas o un `if` sobre si el piso está limpio, escritos en
	# `src/escenas/`, dan cero hallazgos en `capas` **y** en `tdd`. Por eso el criterio los ata
	# con una búsqueda sobre el archivo, que es lo único ejecutable que hay.
	var texto := FileAccess.get_file_as_string(SCRIPT)
	assert_str(texto).is_not_empty()
	var decide := RegEx.create_from_string(PATRONES_DE_DECISION).search_all(texto)
	(
		assert_array(decide)
		. override_failure_message("`mancha_en_el_piso.gd` decide o lleva contador")
		. is_empty()
	)


func test_la_mancha_esta_en_el_grupo_que_la_mira_puede_enfocar() -> void:  # 014-AC9
	var mancha := _mancha()
	assert_bool(mancha.is_in_group(ReglasDelJugador.GRUPO_INTERACTUABLE)).is_true()
	assert_bool(mancha.has_method(ReglasDeLosObjetos.METODO_INTERACTUAR)).is_true()
	# De una mancha no se levanta nada: pasarle el trapeador es otro gesto.
	assert_object(mancha.call(ReglasDeLosObjetos.METODO_INTERACTUAR)).is_null()


func test_la_mancha_limpia_deja_de_estorbar_y_de_enfocarse() -> void:  # 014-AC9
	# Esconder un nodo **no apaga su cuerpo**: con el cuerpo prendido, una mancha ya limpia sigue
	# frenando el rayo de la mira y sigue siendo un tope invisible en medio del pasillo, con la
	# escena cargando sin un solo error.
	var mancha := _mancha()
	var cuerpo := mancha.get_node("Cuerpo") as CollisionShape3D
	var totales := ReglasDeLaLimpieza.PASADAS_POR_MANCHA
	mancha.mostrar(0, totales)
	assert_bool(mancha.visible).is_false()
	(
		assert_bool(cuerpo.disabled)
		. override_failure_message("la mancha limpia sigue chocando y sigue enfocándose")
		. is_true()
	)
	# Y vuelve a estorbar cuando el piso vuelve a estar sucio: el cableado repinta cada jornada.
	mancha.mostrar(totales, totales)
	assert_bool(mancha.visible).is_true()
	assert_bool(cuerpo.disabled).is_false()


func test_la_pasada_entra_por_el_clic_derecho_y_sin_accion_nueva() -> void:  # 014-AC9
	# El evento crudo y no una acción del `InputMap`: el AC8 del 015 prohíbe agregarlas, y quién
	# consolida los tres usos del gesto es el spec 034.
	var texto := FileAccess.get_file_as_string(PUESTO)
	assert_str(texto).is_not_empty()
	(
		assert_bool(texto.contains("MOUSE_BUTTON_RIGHT"))
		. override_failure_message("la pasada no entra por el clic derecho")
		. is_true()
	)
	var acciones := 0
	for accion in InputMap.get_actions():
		if not String(accion).begins_with("ui_"):
			acciones += 1
	(
		assert_int(acciones)
		. override_failure_message("el `InputMap` tiene %d acciones propias" % acciones)
		. is_equal(6)
	)


func test_el_trapeador_carga_y_responde_el_id_de_la_constante() -> void:  # 014-AC9
	# Un `id` que no coincide no rompe nada: el piso simplemente no se limpia nunca. Es la única
	# forma de que ese par no se separe en silencio.
	var trapeador := load(TRAPEADOR) as ObjetoDelAlmacen
	(
		assert_object(trapeador)
		. override_failure_message("`trapeador.tres` no carga o no es un objeto del almacén")
		. is_not_null()
	)
	assert_str(trapeador.id).is_equal(ReglasDeLaLimpieza.ID_DEL_TRAPEADOR)
	assert_bool(trapeador.es_levantable()).is_true()


func test_el_almacen_trae_una_mancha_por_zona() -> void:  # 014-AC10
	# **Contarlas no alcanza, hay que mirar qué zona declara cada una.** Con dos manchas
	# repitiendo la misma `zona` en el `.tscn` el conteo sigue dando cuatro, la zona que falta no
	# se puede limpiar nunca y la obligatoria queda inalcanzable — que es exactamente el bug que
	# este spec vino a cerrar, y ningún gate lo ve porque la zona la declara una escena.
	var manchas := _nodos_de_mancha(_almacen())
	assert_int(manchas.size()).is_equal(PisoDelLocal.Zona.size())
	var declaradas := {}
	for mancha in manchas:
		declaradas[mancha.zona_de_la_mancha()] = true
	for zona: PisoDelLocal.Zona in PisoDelLocal.Zona.values():
		(
			assert_bool(declaradas.has(zona))
			. override_failure_message("ninguna mancha del almacén declara la zona %d" % zona)
			. is_true()
		)


func test_ningun_par_de_manchas_esta_al_alcance_de_la_mira() -> void:  # 014-AC10
	# **El recorrido existe en la escena, no sólo en la prosa.** Si dos manchas estuvieran cerca,
	# desde una se enfocaría la otra y un tramo de caminata desaparecería sin que nada lo dijera.
	var posiciones := _manchas_de(_almacen())
	for una in range(posiciones.size()):
		for otra in range(una + 1, posiciones.size()):
			var distancia := posiciones[una].distance_to(posiciones[otra])
			(
				assert_float(distancia)
				. override_failure_message(
					(
						"dos manchas están a %.2f m y el mínimo es %.2f m"
						% [distancia, ReglasDeLaLimpieza.DISTANCIA_MINIMA_ENTRE_MANCHAS]
					)
				)
				. is_greater_equal(ReglasDeLaLimpieza.DISTANCIA_MINIMA_ENTRE_MANCHAS)
			)


func test_el_trapeador_tampoco_esta_al_lado_de_ninguna_mancha() -> void:  # 014-AC10
	# El primer tramo también cuenta: con el trapeador encima de una mancha, la primera zona
	# saldría gratis.
	var almacen := _almacen()
	var trapeador: Node3D = almacen.get_node("Objetos/Trapeador")
	var desde := _posicion_en(almacen, trapeador)
	for posicion in _manchas_de(almacen):
		var distancia := desde.distance_to(posicion)
		(
			assert_float(distancia)
			. override_failure_message("el trapeador está a %.2f m de una mancha" % distancia)
			. is_greater_equal(ReglasDeLaLimpieza.DISTANCIA_MINIMA_ENTRE_MANCHAS)
		)


func test_con_el_trapeador_en_la_mano_no_se_puede_agarrar_nada_mas() -> void:  # 014-AC10
	# **Limpiar es la tarea que no se puede intercalar**, y no hay que escribirlo: sale de reusar
	# el 006, donde `MANOS_DISPONIBLES` vale 1.
	var manos := Manos.new()
	var trapeador := load(TRAPEADOR) as ObjetoDelAlmacen
	assert_bool(manos.agarrar(trapeador)).is_true()
	var otro := load("res://src/dominio/almacen/caja_de_fideos.tres") as ObjetoDelAlmacen
	assert_object(otro).is_not_null()
	assert_int(manos.motivo_de_rechazo(otro)).is_equal(Manos.Rechazo.MANOS_LLENAS)


func test_los_cuatro_espejos_estan_y_el_almacen_no_decide_nada() -> void:  # 014-AC11
	# Las dos mitades falsables del criterio de terminado. La del `almacen.gd` es la que el 007
	# dejó puesta: la escena raíz cablea y no decide, y eso se verifica sin leerla.
	for ruta: String in [
		"res://src/dominio/almacen/reglas_de_la_limpieza.gd",
		"res://src/dominio/almacen/mancha.gd",
		"res://src/dominio/almacen/piso_del_local.gd",
		"res://src/sistemas/tareas/limpiador.gd",
	]:
		var espejo := ruta.replace("res://src/", "res://test/").replace(".gd", "_test.gd")
		(
			assert_bool(FileAccess.file_exists(espejo))
			. override_failure_message("falta el espejo `%s`" % espejo)
			. is_true()
		)
	var almacen := FileAccess.get_file_as_string("res://src/escenas/almacen.gd")
	assert_str(almacen).is_not_empty()
	var ramas := RegEx.create_from_string("(?m)^\\s*(if|elif|match)\\b").search_all(almacen)
	(
		assert_array(ramas)
		. override_failure_message("`almacen.gd` tiene una condición adentro")
		. is_empty()
	)
