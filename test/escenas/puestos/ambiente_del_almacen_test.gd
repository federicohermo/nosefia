## El rig de luz del almacén: un turno nocturno se ilumina con las luminarias del techo.
##
## La altura de las luminarias se afirma **contra el techo del modelo y no en metros absolutos**,
## porque el modelo se mueve. Medido el 2026-09-15: las paredes llegan a 7,09 m en el `.glb` que
## había y a 4,58 m en el que hay, y las tiras bajaron con ellas. Lo que se conservó en las dos
## versiones es la distancia entre una cosa y la otra —0,26 m y 0,25 m—, así que ése es el
## invariante que se puede afirmar sin que caduque en la próxima exportación.
extends GdUnitTestSuite

const AMBIENTE := preload("res://src/escenas/puestos/ambiente_del_almacen.tscn")
const MODELO := preload("res://assets/SEPT_JUEGOS_PROTOTIPO.glb")
const RUTA_DEL_AMBIENTE := "res://src/escenas/puestos/ambiente_del_almacen.tscn"

## Los cuatro efectos que el motor rechaza bajo `gl_compatibility`. Medido el 2026-09-15 con un
## `SceneTree` que los prende todos: contesta una advertencia por cada uno, «is only available
## when using the Forward+ renderer». Dejarlos prendidos es ruido que no ilumina.
const SOLO_DE_FORWARD_PLUS := [
	"sdfgi_enabled", "ssr_enabled", "ssil_enabled", "volumetric_fog_enabled"
]


## Va montado en el árbol a propósito: `global_position` sobre un nodo suelto depende de por dónde
## quedó colgado, y lo que se mide acá es una altura.
func _ambiente() -> Node3D:
	var nodo: Node3D = auto_free(AMBIENTE.instantiate())
	add_child(nodo)
	return nodo


func _entorno() -> Environment:
	var nodo: WorldEnvironment = _ambiente().get_node("Entorno")
	return nodo.environment


## El punto más alto del almacén, que es contra lo que se mide la altura de las luminarias.
func _techo() -> float:
	var modelo: Node3D = auto_free(MODELO.instantiate())
	add_child(modelo)
	var malla: MeshInstance3D = modelo.get_node("almacen")
	return (malla.global_transform * malla.mesh.get_aabb()).end.y


func _descendientes(nodo: Node, encontrados: Array[Node] = []) -> Array[Node]:
	for hijo in nodo.get_children():
		encontrados.append(hijo)
		_descendientes(hijo, encontrados)
	return encontrados


func _gd_y_tscn_de(ruta: String, encontrados: PackedStringArray = []) -> PackedStringArray:
	var directorio := DirAccess.open(ruta)
	for carpeta in directorio.get_directories():
		_gd_y_tscn_de(ruta.path_join(carpeta), encontrados)
	for archivo in directorio.get_files():
		if archivo.get_extension() in ["gd", "tscn"]:
			encontrados.append(ruta.path_join(archivo))
	return encontrados


func test_el_rig_de_exterior_no_esta_mas() -> void:  # 048-AC1
	# Los tres eran lo que había: un `DirectionalLight3D` llamado `Sol`, un cielo procedural y el
	# fondo en `BG_SKY`. Adentro de un almacén de noche, las ventanas daban a un mediodía.
	var ambiente := _ambiente()
	for nodo in _descendientes(ambiente):
		assert_object(nodo).is_not_instanceof(DirectionalLight3D)
	assert_int(_entorno().background_mode).is_equal(Environment.BG_COLOR)
	var texto := FileAccess.get_file_as_string(RUTA_DEL_AMBIENTE)
	assert_str(texto).not_contains("ProceduralSkyMaterial")


func test_las_luminarias_son_tres_y_cuelgan_del_techo() -> void:  # 048-AC2
	var luminarias: Node3D = _ambiente().get_node("Luminarias")
	var luces: Array[Node] = []
	for hijo in luminarias.get_children():
		if hijo is Light3D:
			luces.append(hijo)
	assert_int(luces.size()).is_equal(Iluminacion.LUMINARIAS)
	var techo := _techo()
	for luz: Light3D in luces:
		var caida := techo - luz.global_position.y
		(
			assert_float(caida)
			. override_failure_message(
				"%s cuelga a %.3f m del techo (%.3f m)" % [luz.name, caida, techo]
			)
			. is_between(0.15, 0.40)
		)


func test_el_entorno_no_pide_efectos_que_este_renderizador_no_hace() -> void:  # 048-AC5
	var entorno := _entorno()
	assert_bool(entorno.glow_enabled).is_true()
	for ajuste: String in SOLO_DE_FORWARD_PLUS:
		(
			assert_bool(entorno.get(ajuste))
			. override_failure_message("%s está prendido y este renderizador lo ignora" % ajuste)
			. is_false()
		)


func test_ninguna_escena_ni_script_de_src_declara_una_luz_direccional() -> void:  # 048-AC6
	# El barrido corrido antes de escribir esta lista devuelve una sola línea, la de la escena
	# del ambiente. No hay excepciones que enumerar, y por eso la afirmación es que no hay ninguna.
	var culpables := PackedStringArray()
	for ruta in _gd_y_tscn_de("res://src"):
		if FileAccess.get_file_as_string(ruta).contains("DirectionalLight3D"):
			culpables.append(ruta)
	assert_array(culpables).is_empty()
