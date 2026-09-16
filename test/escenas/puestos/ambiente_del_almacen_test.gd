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

## Y los que este renderizador sí hace, que son con los que se reemplazan: `LightmapGI` por SDFGI,
## `ReflectionProbe` por SSR, SSAO por SSIL y niebla de profundidad por la volumétrica.
const LO_QUE_COMPATIBILITY_SI_HACE := ["glow_enabled", "ssao_enabled", "fog_enabled"]


## Va montado en el árbol a propósito: `global_position` sobre un nodo suelto depende de por dónde
## quedó colgado, y lo que se mide acá es una altura.
func _ambiente() -> Node3D:
	var nodo: Node3D = auto_free(AMBIENTE.instantiate())
	add_child(nodo)
	return nodo


func _entorno() -> Environment:
	var nodo: WorldEnvironment = _ambiente().get_node("Entorno")
	return nodo.environment


## Todos los focos de todas las luminarias, que es lo que miden varios criterios.
func _focos(ambiente: Node3D) -> Array[Light3D]:
	var encontrados: Array[Light3D] = []
	for tira in ambiente.get_node("Luminarias").get_children():
		for hijo in tira.get_children():
			if hijo is Light3D:
				encontrados.append(hijo)
	return encontrados


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
	var ambiente := _ambiente()
	var tiras := ambiente.get_node("Luminarias").get_children()
	assert_int(tiras.size()).is_equal(Iluminacion.LUMINARIAS)
	var techo := _techo()
	for foco in _focos(ambiente):
		var caida := techo - foco.global_position.y
		(
			assert_float(caida)
			. override_failure_message(
				"%s cuelga a %.3f m del techo (%.3f m)" % [foco.name, caida, techo]
			)
			. is_between(0.15, 0.40)
		)


func test_cada_luminaria_trae_por_lo_menos_un_foco() -> void:  # 048-AC2
	# Sin esto, tres `Node3D` vacíos pasan el criterio de arriba: no queda un foco que medir y el
	# bucle de la altura no entra nunca.
	assert_int(_focos(_ambiente()).size()).is_greater_equal(Iluminacion.LUMINARIAS)


func test_ningun_foco_alumbra_hacia_arriba() -> void:  # 048-AC7
	# El defecto que este criterio cierra: las luminarias del modelo cuelgan 20 cm bajo el techo,
	# así que una luz puntual ahí le tira al techo cientos de veces más que al piso. En el rig
	# anterior el techo salía blanco y el objetivo lo quiere casi negro.
	#
	# La dirección se lee del `global_transform` y no del archivo: los nueve flotantes de un
	# `Transform3D` en un `.tscn` son las **filas** de la base y no sus ejes, así que leerlos al
	# revés da la luz dada vuelta sin que ningún número se vea raro.
	for foco in _focos(_ambiente()):
		var direccion := -foco.global_transform.basis.z
		(
			assert_float(direccion.y)
			. override_failure_message("%s alumbra hacia %v" % [foco.name, direccion])
			. is_less_equal(-0.9)
		)


func test_el_entorno_no_pide_efectos_que_este_renderizador_no_hace() -> void:  # 048-AC5
	var entorno := _entorno()
	for ajuste: String in LO_QUE_COMPATIBILITY_SI_HACE:
		(
			assert_bool(entorno.get(ajuste))
			. override_failure_message("%s está apagado y este renderizador sí lo hace" % ajuste)
			. is_true()
		)
	for ajuste: String in SOLO_DE_FORWARD_PLUS:
		(
			assert_bool(entorno.get(ajuste))
			. override_failure_message("%s está prendido y este renderizador lo ignora" % ajuste)
			. is_false()
		)


func test_los_reflejos_del_piso_salen_de_una_sonda_y_no_de_la_pantalla() -> void:  # 048-AC5
	# Compatibility no hace reflexiones en espacio de pantalla, así que los reflejos alargados de
	# las luminarias sobre el damero tienen que venir de una `ReflectionProbe`. `interior` le saca
	# el cielo, que en un almacén cerrado no existe, y `box_projection` endereza el reflejo en una
	# sala rectangular.
	var sonda: ReflectionProbe = _ambiente().get_node("Reflejos")
	assert_bool(sonda.interior).is_true()
	assert_bool(sonda.box_projection).is_true()


func test_los_focos_quedan_en_el_modo_que_deja_apagar_una_luminaria_sola() -> void:  # 048-AC8
	# `DYNAMIC` hornea **sólo el indirecto** y deja el directo y sus sombras en tiempo real. Con
	# `STATIC` el directo también quedaría escrito en la textura, y apagar una luminaria no
	# apagaría nada de lo que el lightmap ya dibuja: el pasillo seguiría iluminado con la luz
	# apagada, que es justo lo que este spec necesita que se pueda hacer.
	for foco in _focos(_ambiente()):
		(
			assert_int(foco.light_bake_mode)
			. override_failure_message("%s no está en DYNAMIC" % foco.name)
			. is_equal(Light3D.BAKE_DYNAMIC)
		)


func test_el_ambiente_de_color_no_queda_anulado_por_un_cielo_que_no_existe() -> void:  # 048-AC5
	# Medido: con `ambient_light_sky_contribution` en su valor por defecto de 1,0 el ambiente de
	# color se mezcla **cien por ciento con el cielo**, y con `background_mode` en `BG_COLOR` no
	# hay cielo, así que el término ambiente sale en cero y todo lo que no toca un foco queda
	# negro puro. Con 0,0 aparece el azul profundo del objetivo. El síntoma no nombra al ajuste:
	# se ve como que la energía del ambiente no hace nada por más que se la suba.
	assert_float(_entorno().ambient_light_sky_contribution).is_equal_approx(0.0, 0.001)


func test_solo_el_cascaron_del_salon_se_importa_con_uv2() -> void:  # 048-AC8
	# Las dos mitades, y la segunda es la cara. Sin UV2 el `LightmapGI` no tiene dónde escribir,
	# así que el salón las necesita. Pero prender `meshes/light_baking=2` para todo el modelo
	# **suelda vértices**: medido, `almacen` pasa de 675 a 664 y los `.res` derivados de
	# `gondola01` dejan de coincidir, con `modelo_exportado_test.gd` en rojo en diez aserciones.
	# Por eso el desplegado va por malla, en el `_subresources` del `.import`, y sobre el nombre
	# del **recurso** —`SEPT_JUEGOS_PROTOTIPO_Plane_005`— y no el del nodo: con el del nodo el
	# importador no protesta y tampoco despliega nada.
	var modelo: Node3D = auto_free(MODELO.instantiate())
	var salon: MeshInstance3D = modelo.get_node("almacen")
	for indice in salon.mesh.get_surface_count():
		var uv2: Variant = salon.mesh.surface_get_arrays(indice)[Mesh.ARRAY_TEX_UV2]
		(
			assert_int(0 if uv2 == null else uv2.size())
			. override_failure_message("la superficie %d del salón no tiene UV2" % indice)
			. is_greater(0)
		)
	var gondola: MeshInstance3D = modelo.get_node("gondola01")
	for indice in gondola.mesh.get_surface_count():
		var uv2: Variant = gondola.mesh.surface_get_arrays(indice)[Mesh.ARRAY_TEX_UV2]
		(
			assert_int(0 if uv2 == null else uv2.size())
			. override_failure_message("la góndola se desplegó y eso mueve los `.res` derivados")
			. is_equal(0)
		)


func test_ninguna_escena_ni_script_de_src_declara_una_luz_direccional() -> void:  # 048-AC6
	# El barrido corrido antes de escribir esta lista devuelve una sola línea, la de la escena
	# del ambiente. No hay excepciones que enumerar, y por eso la afirmación es que no hay ninguna.
	var culpables := PackedStringArray()
	for ruta in _gd_y_tscn_de("res://src"):
		if FileAccess.get_file_as_string(ruta).contains("DirectionalLight3D"):
			culpables.append(ruta)
	assert_array(culpables).is_empty()
