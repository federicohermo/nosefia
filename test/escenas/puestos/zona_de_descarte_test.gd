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

## Una caja por producto del catálogo, desde que reponer se puede terminar jugando. Antes era una
## sola llamada `CajaDeProductos`: el nombre viejo dejaba este caso midiendo de menos.
const CAJAS_DEL_DEPOSITO := [
	"Objetos/CajaDeYerba",
	"Objetos/CajaDeFideos",
	"Objetos/CajaDeGaseosa",
	"Objetos/CajaDeGalletitas",
	"Objetos/CajaDeArroz",
	"Objetos/CajaDeJabon",
]

## Los anclajes de las otras cuatro obligatorias en `almacen.tscn`. El descarte tiene que estar
## lejos de todos: es lo que hace que ninguna otra tarea visite el fondo.
const ANCLAJES_DE_LAS_OTRAS_TAREAS := (
	[
		"Estructura/gondola01/StaticBody3D",
		"Objetos/CajaDeTraslado",
		"Estructura/Ventanilla",
		"Estructura/compu/StaticBody3D"
	]
	+ CAJAS_DEL_DEPOSITO
)

const NOMBRES_DE_LAS_BOLSAS := [
	"Objetos/BolsaDeBasura1", "Objetos/BolsaDeBasura2", "Objetos/BolsaDeBasura3"
]

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
	assert_bool(almacen.has_node("Objetos/ZonaDeDescarte")).is_true()
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
	var descarte := _posicion_en(almacen, almacen.get_node("Objetos/ZonaDeDescarte"))
	var puntos := _puntos_a_medir(almacen)
	# Un nombre que no está se salteaba en silencio y el caso medía de menos: renombrar un
	# anclaje dejaba la mitad del local sin comparar contra el fondo, y esto seguía en verde.
	for nombre: String in ANCLAJES_DE_LAS_OTRAS_TAREAS + NOMBRES_DE_LAS_BOLSAS:
		(
			assert_bool(puntos.has(nombre))
			. override_failure_message("`%s` no está en el almacén: el caso lo salteaba" % nombre)
			. is_true()
		)
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


func test_el_cableado_de_la_basura_llega_entero_hasta_la_zona() -> void:  # 015-AC6
	# Un `@export` de tipo `Node` en una escena escrita a mano va declarado ADEMÁS en el
	# `node_paths` del tag del nodo, o queda en `null`: la escena carga sin un solo error, los
	# seis nodos dan verde, y el juego muere en el primer cuadro con un
	# `Nonexistent function … in base 'Nil'` que no nombra ni al `.tscn` ni al `@export`.
	#
	# Los cuatro niveles van juntos porque la trampa es la misma en los cuatro: la raíz, el nodo
	# suelto, el `@export` que la sub-escena instanciada apunta afuera de sí misma, y el que ya
	# traía adentro y que instanciarla podría borrar.
	var almacen := _almacen()
	(
		assert_object(almacen.get("_recolector"))
		. override_failure_message(
			"`_recolector` quedó en null: falta en el `node_paths` de la raíz"
		)
		. is_not_null()
	)
	var recolector: RecolectorDeBasura = almacen.get_node("Servicios/Recolector")
	(
		assert_object(recolector.reloj)
		. override_failure_message("el recolector nace sin reloj: no puede contar la obligatoria")
		. is_not_null()
	)
	var zona: ZonaQueSeVe = almacen.get_node("Objetos/ZonaDeDescarte")
	(
		assert_object(zona.recolector)
		. override_failure_message("la zona nace sin recolector: la primera bolsa mata al juego")
		. is_not_null()
	)
	(
		assert_object(zona.forma)
		. override_failure_message(
			"la zona nace sin forma: instanciarla borró su propio `node_paths`"
		)
		. is_not_null()
	)


func test_cada_bolsa_de_la_escena_lleva_el_id_que_espera_el_dominio() -> void:  # 015-AC8
	# **Un `id` que no coincide no rompe nada**: la bolsa entra al descarte, el dominio contesta
	# `NO_ES_BASURA` y la obligatoria queda imposible de cerrar toda la noche, sin un solo error y
	# con los seis nodos en verde. Contar los nodos por su nombre no lo ve — el nombre del nodo y
	# el `id` del `.tres` son dos cosas distintas.
	var almacen := _almacen()
	var encontrados: Array[StringName] = []
	for nombre: String in NOMBRES_DE_LAS_BOLSAS:
		var bolsa := almacen.get_node_or_null(nombre) as ObjetoAgarrable
		if bolsa == null:
			(
				assert_object(bolsa)
				. override_failure_message("`%s` no está o no es un agarrable del 006" % nombre)
				. is_not_null()
			)
			continue
		if bolsa.datos == null:
			(
				assert_object(bolsa.datos)
				. override_failure_message(
					"`%s` no trae su `.tres`: su `datos` llegó nulo" % nombre
				)
				. is_not_null()
			)
			continue
		encontrados.append(bolsa.datos.id)
	(
		assert_array(encontrados)
		. override_failure_message(
			(
				"las bolsas de la escena llevan %s y el dominio espera %s"
				% [encontrados, ReglasDeLaBasura.ids_de_las_bolsas()]
			)
		)
		. contains_exactly_in_any_order(ReglasDeLaBasura.ids_de_las_bolsas())
	)


func test_las_bolsas_son_del_agarre_del_006_y_no_de_un_segundo_sistema() -> void:  # 015-AC8
	var almacen := _almacen()
	for nombre: String in NOMBRES_DE_LAS_BOLSAS:
		var bolsa := almacen.get_node(nombre)
		assert_str(bolsa.scene_file_path).is_equal(ESCENA_AGARRABLE)


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
