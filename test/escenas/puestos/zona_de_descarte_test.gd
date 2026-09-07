## La zona del fondo: que no lleve reglas, que su esfera sea la de la constante, y que el
## trayecto exista en la escena.
##
## **El caso del trayecto es el que este spec no puede cerrar mirando.** Las posiciones se
## componen subiendo por los padres y no con `global_position`: esta suite no entra la escena al
## árbol, y ahí el global aborta con `Condition "!is_inside_tree()" is true` devolviendo la
## identidad — o sea que el caso no fallaría por la geometría, pasaría siempre.
extends GdUnitTestSuite

const ESCENA := "res://src/escenas/puestos/zona_de_descarte.tscn"
const SCRIPT := "res://src/escenas/puestos/zona_de_descarte.gd"
const ESCENA_DEL_ALMACEN := "res://src/escenas/almacen.tscn"
const ESCENA_AGARRABLE := "res://src/escenas/objetos/objeto_agarrable.tscn"

## El script del puesto se preloadea para poder tiparlo: los scripts de `escenas/` son cáscara y
## no declaran `class_name` — y éste **no puede** declararlo, ver el caso de abajo.
const ZonaQueSeVe := preload("res://src/escenas/puestos/zona_de_descarte.gd")

## Los anclajes de las otras cuatro obligatorias en `almacen.tscn`. El descarte tiene que estar
## lejos de todos: es lo que hace que ninguna otra tarea visite el fondo.
const ANCLAJES_DE_LAS_OTRAS_TAREAS := [
	"Estante", "CajaDeProductos", "CajaDeTraslado", "Ventanilla", "Escritorio"
]

const NOMBRES_DE_LAS_BOLSAS := ["BolsaDeBasura1", "BolsaDeBasura2", "BolsaDeBasura3"]

## Lo que delataría una regla del juego escrita en la zona. Está medido que ahí los dos gates dan
## verde, así que el criterio la ata con una búsqueda sobre el archivo.
const PATRONES_DE_REGLA := "BOLSAS_DE_LA_JORNADA|depositadas|completada|class_name"


func _almacen() -> Node3D:
	return auto_free(load(ESCENA_DEL_ALMACEN).instantiate())


## La posición de un nodo respecto de la raíz, componiendo los `transform` de los padres.
static func _posicion_en(raiz: Node, nodo: Node3D) -> Vector3:
	var compuesta := Transform3D.IDENTITY
	var actual: Node = nodo
	while actual != null and actual != raiz:
		var tridimensional := actual as Node3D
		if tridimensional != null:
			compuesta = tridimensional.transform * compuesta
		actual = actual.get_parent()
	return compuesta.origin


static func _descendientes(nodo: Node) -> Array[Node3D]:
	var todos: Array[Node3D] = []
	for hijo in nodo.get_children():
		var tridimensional := hijo as Node3D
		if tridimensional == null:
			continue
		todos.append(tridimensional)
		todos.append_array(_descendientes(tridimensional))
	return todos


## Todo lo que el descarte tiene que tener lejos: los anclajes de las otras tareas, las manchas
## del 014 y las tres bolsas.
static func _puntos_a_medir(almacen: Node3D) -> Dictionary:
	var puntos := {}
	for nombre: String in ANCLAJES_DE_LAS_OTRAS_TAREAS + NOMBRES_DE_LAS_BOLSAS:
		var nodo := almacen.get_node_or_null(nombre) as Node3D
		if nodo == null:
			continue
		puntos[nombre] = _posicion_en(almacen, nodo)
	for nodo in _descendientes(almacen):
		if nodo.name.begins_with("Mancha"):
			puntos[nodo.name] = _posicion_en(almacen, nodo)
	return puntos


func test_la_zona_no_lleva_una_sola_regla_ni_un_nombre_global() -> void:  # 015-AC6
	# Sin `class_name` a propósito: nadie la nombra desde abajo, y no tenerlo cierra la única
	# puerta que el gate de capas sí caza — que `sistemas/` nombre un tipo de `escenas/`.
	var texto := FileAccess.get_file_as_string(SCRIPT)
	assert_str(texto).is_not_empty()
	var reglas := RegEx.create_from_string(PATRONES_DE_REGLA).search_all(texto)
	(
		assert_array(reglas)
		. override_failure_message("`zona_de_descarte.gd` lleva una regla o un nombre global")
		. is_empty()
	)


func test_la_esfera_de_la_escena_es_exactamente_la_de_la_constante() -> void:  # 015-AC6
	# Un `.tscn` no puede leer un `const`, así que el número está escrito dos veces. Sin este
	# caso, la esfera y la regla se separan y el jugador suelta la bolsa donde el juego dice que
	# no cuenta — sin un solo error.
	var zona: ZonaQueSeVe = auto_free(load(ESCENA).instantiate())
	(
		assert_float(zona.radio())
		. override_failure_message(
			(
				"la esfera mide %.2f y la constante dice %.2f"
				% [zona.radio(), ReglasDeLaBasura.RADIO_DEL_DESCARTE]
			)
		)
		. is_equal(ReglasDeLaBasura.RADIO_DEL_DESCARTE)
	)


func test_el_almacen_trae_el_descarte_y_una_bolsa_por_cada_una_del_balance() -> void:  # 015-AC7
	var almacen := _almacen()
	assert_bool(almacen.has_node("ZonaDeDescarte")).is_true()
	var bolsas := 0
	for nombre: String in NOMBRES_DE_LAS_BOLSAS:
		if almacen.has_node(nombre):
			bolsas += 1
	assert_int(bolsas).is_equal(ReglasDeLaBasura.BOLSAS_DE_LA_JORNADA)


func test_el_fondo_esta_lejos_de_todo_lo_demas() -> void:  # 015-AC7
	# **No se cierra mirando: se cierra con un número.** Si el descarte estuviera al lado de otra
	# tarea, la basura se sacaría de paso y el término de trayecto desaparecería sin que nada lo
	# dijera.
	var almacen := _almacen()
	var descarte := _posicion_en(almacen, almacen.get_node("ZonaDeDescarte"))
	var puntos := _puntos_a_medir(almacen)
	assert_int(puntos.size()).is_greater(0)
	for nombre: String in puntos:
		var distancia: float = descarte.distance_to(puntos[nombre])
		(
			assert_float(distancia)
			. override_failure_message(
				(
					"`%s` está a %.2f m del descarte y el mínimo es %.2f m"
					% [nombre, distancia, ReglasDeLaBasura.DISTANCIA_MINIMA_AL_DESCARTE]
				)
			)
			. is_greater_equal(ReglasDeLaBasura.DISTANCIA_MINIMA_AL_DESCARTE)
		)


func test_las_bolsas_son_del_agarre_del_006_y_no_de_un_segundo_sistema() -> void:  # 015-AC8
	# **No hay un segundo sistema de agarre**: las tres son instancias de la escena que el 006
	# entrega, con su `.tres` puesto. Un cuerpo propio acá sería un `Agarre` paralelo que el
	# jugador no puede usar.
	var texto := FileAccess.get_file_as_string(ESCENA_DEL_ALMACEN)
	assert_str(texto).is_not_empty()
	for nombre: String in NOMBRES_DE_LAS_BOLSAS:
		(
			assert_bool(texto.contains('[node name="%s" parent="." instance=' % nombre))
			. override_failure_message("`%s` no entra instanciada del 006" % nombre)
			. is_true()
		)
	assert_bool(texto.contains(ESCENA_AGARRABLE)).is_true()


func test_este_spec_no_agrega_ninguna_accion_al_input_map() -> void:  # 015-AC8
	# Se agarra y se suelta con las del 006. Una acción nueva sería una tecla más para una tarea
	# que ya se hace con el clic que el jugador aprendió.
	var acciones := 0
	for accion in InputMap.get_actions():
		if not String(accion).begins_with("ui_"):
			acciones += 1
	(
		assert_int(acciones)
		. override_failure_message("el `InputMap` tiene %d acciones propias" % acciones)
		. is_equal(6)
	)


func test_los_cuatro_espejos_estan_y_el_almacen_no_decide_nada() -> void:  # 015-AC9
	# Las dos mitades falsables del criterio de terminado.
	for ruta: String in [
		"res://src/dominio/almacen/reglas_de_la_basura.gd",
		"res://src/dominio/almacen/trayecto.gd",
		"res://src/dominio/almacen/tarea_de_la_basura.gd",
		"res://src/sistemas/tareas/recolector_de_basura.gd",
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
