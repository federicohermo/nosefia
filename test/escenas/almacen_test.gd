## El cableado del almacén: qué instancia, qué anclajes ofrece y que nada suyo cuelga de otra cosa.
##
## No dice «se ve bien»: dice que los anclajes que los specs 008, 009 y 013 van a buscar
## por nombre están, y que la escena raíz sigue siendo una escena de cableado. La geometría del
## blockout —los cuerpos y sus formas— la afirma `estructura_del_almacen_test.gd`, que es la
## suite de la escena que la declara; acá se afirma que la instancia no vino corrida.
##
## **ESTA SUITE INSTANCIA LA ESCENA Y NO LA ENTRA AL ÁRBOL, y es deliberado.** `instantiate()`
## alcanza para leer la jerarquía y las propiedades —medido en headless—, mientras que
## `add_child()` haría correr los `_ready()` de todo lo que cuelgue de la escena. Hoy eso sería
## el `_ready()` del jugador; en cuanto el spec 007 le cuelgue un script a la raíz y un nodo con
## el reloj del turno, sería también código que esta suite no escribió. Un test que entra la
## escena al árbol le hereda al 007 un rojo que no es suyo; uno que la instancia y nada más
## queda estable. **Si algún día hace falta entrarla, es una decisión que se toma a propósito y
## se escribe acá.**
extends GdUnitTestSuite

const ESCENA_DEL_ALMACEN := "res://src/escenas/almacen.tscn"

## La tabla de transformadas del blockout vive una sola vez, en la suite de la escena que declara
## la geometría. Acá se la lee para la otra mitad de la medición: la sub-escena puede estar bien
## y el nodo que la instancia venir corrido, y eso sólo se ve desde afuera.
const SUITE_DE_LA_ESTRUCTURA := preload("res://test/escenas/puestos/estructura_del_almacen_test.gd")


## Devuelve los nodos que rompen la regla de cableado, ya redactados con su padre.
##
## Sale a una función en vez de afirmar adentro del caso porque es lo único que la vuelve
## ejercible: una recorrida que sólo pasa por un árbol que ya cumple pasaría igual si no mirara
## nada, y el caso siguiente le pasa un árbol que sí la viola.
##
## **El discriminador es el `owner` y no la profundidad.** Un recorrido que contara niveles diría
## que `Jugador/Camara` viola la regla, y no la viola: le llega instanciado de `jugador.tscn`. En
## una sub-escena instanciada el `owner` de cada hijo es la raíz de la sub-escena, no la de
## afuera —medido en el spec 023—, así que `owner == raiz` distingue exactamente los nodos que la
## escena declara ella misma.
static func _violaciones_de_cableado(raiz: Node) -> Array[String]:
	var violaciones: Array[String] = []
	for nodo in _descendientes(raiz):
		if nodo.owner == raiz and nodo.get_parent() != raiz:
			violaciones.append("`%s` cuelga de `%s`" % [nodo.name, nodo.get_parent().name])
	return violaciones


static func _descendientes(nodo: Node) -> Array[Node]:
	var todos: Array[Node] = []
	for hijo in nodo.get_children():
		todos.append(hijo)
		todos.append_array(_descendientes(hijo))
	return todos


func _almacen() -> Node3D:
	return auto_free(load(ESCENA_DEL_ALMACEN).instantiate())


func test_el_almacen_carga_y_su_raiz_es_un_nodo_tridimensional() -> void:
	assert_object(_almacen()).is_instanceof(Node3D)


func test_los_tres_anclajes_que_buscan_los_specs_siguientes_estan_por_nombre() -> void:
	# Se buscan por nombre y no por posición para que mover una caja no rompa nada de lo que
	# viene después. Los tres son anclajes de transform, NO muebles definitivos: el 008 reemplaza
	# `Estanteria` por su `estante.tscn` y el 009 `EscritorioDeLaComputadora` por su
	# `escritorio.tscn`, y este caso deja de aplicar en cuanto lo hagan.
	var almacen := _almacen()
	assert_bool(almacen.has_node("Estructura/Estanteria")).is_true()
	assert_bool(almacen.has_node("Estructura/EscritorioDeLaComputadora")).is_true()
	assert_bool(almacen.has_node("HuecoDeLaVentanilla")).is_true()


func test_el_proyecto_abre_el_almacen_al_correr() -> void:
	# Sin esto, correr el proyecto no abre nada y el síntoma es una ventana vacía que no nombra
	# a `project.godot`.
	assert_str(ProjectSettings.get_setting("application/run/main_scene")).is_equal(
		ESCENA_DEL_ALMACEN
	)


func test_el_almacen_instancia_al_jugador_en_vez_de_duplicar_el_cuerpo() -> void:
	assert_bool(_almacen().has_node("Jugador")).is_true()


func test_la_escena_trae_luz_propia() -> void:
	# El renderer es `forward_plus`: una escena sin luces sale NEGRA, y el síntoma no nombra la
	# causa. Por eso el entorno y el sol se afirman por nombre y por tipo en vez de dejarlos
	# librados a que alguien mire la escena.
	var almacen := _almacen()
	assert_bool(almacen.has_node("Entorno")).is_true()
	var entorno: Node = almacen.get_node("Entorno")
	assert_object(entorno).is_instanceof(WorldEnvironment)
	assert_object(entorno.environment).is_not_null()
	assert_bool(almacen.has_node("Sol")).is_true()
	assert_object(almacen.get_node("Sol")).is_instanceof(DirectionalLight3D)


func test_la_estructura_entra_instanciada_y_no_vino_corrida() -> void:
	# La sub-escena puede estar bien y la instancia venir corrida: el transform del nodo
	# instanciado se guarda acá, no en `estructura_del_almacen.tscn`. Es `transform` y no
	# `global_transform` porque esta suite no entra la escena al árbol y ahí el global aborta con
	# `Condition "!is_inside_tree()" is true` devolviendo la identidad, o sea que no fallaría por
	# la geometría: fallaría siempre.
	var estructura: Node3D = _almacen().get_node("Estructura")
	assert_that(estructura.transform).is_equal(Transform3D.IDENTITY)
	for nombre in SUITE_DE_LA_ESTRUCTURA.POSICIONES:
		var cuerpo: Node3D = estructura.get_node(NodePath(nombre))
		var esperado := Transform3D(Basis.IDENTITY, SUITE_DE_LA_ESTRUCTURA.POSICIONES[nombre])
		(
			assert_that(cuerpo.transform)
			. override_failure_message(
				(
					"`Estructura/%s` quedó en %s y el almacén lo tenía en %s"
					% [nombre, cuerpo.transform, esperado]
				)
			)
			. is_equal(esperado)
		)


func test_todo_nodo_propio_del_almacen_cuelga_de_la_raiz() -> void:
	# La escena raíz cablea: lo que tiene estructura adentro entra instanciado. Sin esta regla el
	# archivo vuelve a engordar —los ocho specs que lo editan agregan tres líneas cada uno sobre
	# un blockout que ninguno escribió— y un `.tscn` grande no se mergea, se rompe.
	var violaciones := _violaciones_de_cableado(_almacen())
	(
		assert_array(violaciones)
		. override_failure_message(
			"`almacen.tscn` declara nodos que no cuelgan de su raíz: %s" % ", ".join(violaciones)
		)
		. is_empty()
	)


func test_la_regla_de_cableado_sabe_ver_un_nodo_colgado_de_otro() -> void:
	# El caso de arriba recorre un árbol que ya cumple, así que pasaría igual con una recorrida
	# rota. Éste le arma el defecto que el spec 014 planeaba —un puesto con sus hijos escritos
	# dentro de la escena raíz— y afirma que lo nombra. Queda en el archivo a propósito: meter el
	# nodo a mano en `almacen.tscn`, mirar el rojo y sacarlo no deja rastro y no lo repite nadie.
	var raiz: Node3D = auto_free(Node3D.new())
	raiz.name = "Almacen"
	var puesto := Node3D.new()
	puesto.name = "Limpieza"
	raiz.add_child(puesto)
	puesto.owner = raiz
	var mancha := Node3D.new()
	mancha.name = "Mancha1"
	puesto.add_child(mancha)
	mancha.owner = raiz
	var violaciones := _violaciones_de_cableado(raiz)
	assert_array(violaciones).has_size(1)
	assert_str(violaciones[0]).contains("Mancha1")
	assert_str(violaciones[0]).contains("Limpieza")
