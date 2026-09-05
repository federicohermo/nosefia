## El cableado del almacén: qué instancia, qué anclajes ofrece y que nada suyo cuelga de otra cosa.
##
## No dice «se ve bien»: dice que los anclajes que los specs 008, 009 y 013 van a buscar
## por nombre están, y que la escena raíz sigue siendo una escena de cableado. La geometría —las
## mallas del modelo y sus colisiones— la afirma `estructura_del_almacen_test.gd`, que es la
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
##
## **Y hizo falta, en dos casos y sólo en ésos** (spec 028). Los dos necesitan un espacio físico
## contra el que tirar un rayo, y sin árbol no hay `World3D`. El del hueco de la ventanilla entra
## **sólo el subárbol de la estructura**, que no tiene un script colgando; el del jugador entra la
## escena entera, porque lo que mide es que la física del `CharacterBody3D` lo deje parado. El
## resto sigue instanciando y nada más.
extends GdUnitTestSuite

const ESCENA_DEL_ALMACEN := "res://src/escenas/almacen.tscn"

## La malla que trae la cáscara del edificio. Los rayos de acá miran sólo contra ella.
const CASCARA_DEL_EDIFICIO := "almacen"

## Dónde estaba el hueco de la ventanilla en el blockout que el spec 028 reemplazó. Está acá para
## que el caso que ejerce la regla tenga un punto que **no** es un hueco, y que sea uno real en vez
## de inventado: el marcador estuvo cuatro commits en esta posición —aire en un pasillo entre las
## góndolas y los estantes— con las 23 suites en verde.
const PUNTO_DEL_HUECO_EN_EL_BLOCKOUT := Vector3(-5, 1.2, 0)

## Alcanza para arrancar afuera del edificio desde cualquier punto de adentro: la planta mide
## 21,72 × 22,74 m.
const DISTANCIA_DE_AFUERA := 20.0

## Cuánto por encima del antepecho se mira para ver el hueco, y cuánto por debajo para ver que el
## antepecho está. El hueco medido va de 1,04 a 2,84 m, así que los dos caen bien adentro.
const SOBRE_EL_ANTEPECHO := 0.4
const BAJO_EL_ANTEPECHO := 0.3

## Cuadros de física antes de mirar al jugador. Arranca en el aire y cae; 30 a 60 Hz son medio
## segundo, de sobra para medio metro.
const CUADROS_DE_FISICA := 30


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


## Deja colisionando **sólo la cáscara del edificio**. Los muebles taparían los huecos: un rayo
## que choca contra una góndola diría que la pared está cerrada, y el caso pasaría por el motivo
## equivocado.
static func _apagar_todo_menos_la_cascara(nodo: Node) -> void:
	if nodo is StaticBody3D and nodo.get_parent().name != CASCARA_DEL_EDIFICIO:
		(nodo as StaticBody3D).collision_layer = 0
	for hijo in nodo.get_children():
		_apagar_todo_menos_la_cascara(hijo)


## Devuelve si desde afuera del edificio se llega al punto en línea recta por alguno de los cuatro
## rumbos horizontales, que es exactamente lo que distingue un hueco de un pedazo de pared.
##
## Sale a una función porque es lo único que la vuelve ejercible: el caso que la usa corre sobre un
## marcador que ya está bien, y pasaría igual si no mirara nada. El caso siguiente le pasa el punto
## que usaba el blockout y afirma que lo rechaza.
##
## El criterio es que el rayo **no choque con nada**, sin tolerancia. Con una tolerancia de unos
## centímetros, el punto que está 30 cm debajo del antepecho daría «se llega»: ahí la pared está a
## 10 cm, y el caso se pondría verde afirmando lo contrario de lo que quiere decir.
static func _se_llega_desde_afuera(espacio: PhysicsDirectSpaceState3D, punto: Vector3) -> bool:
	for rumbo in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
		var desde: Vector3 = punto + rumbo * DISTANCIA_DE_AFUERA
		if espacio.intersect_ray(PhysicsRayQueryParameters3D.create(desde, punto)).is_empty():
			return true
	return false


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
	#
	# Ya no recorre cuerpo por cuerpo contra una tabla de posiciones: desde que la estructura es
	# el .blend, dónde va cada mueble lo decide Blender, y una tabla acá sería un rojo por cada
	# cosa que el modelador mueve. Lo que queda es lo único que se edita de este lado.
	var estructura: Node3D = _almacen().get_node("Estructura")
	assert_that(estructura.transform).is_equal(Transform3D.IDENTITY)


## Entra al árbol **sólo** el subárbol de la estructura, sacándolo del almacén instanciado, y
## devuelve el espacio físico ya listo para preguntarle.
##
## Se entra la estructura sola y no `almacen.tscn` a propósito: la estructura no tiene un solo
## script colgando, así que su `_ready()` no corre código que esta suite no escribió. Los dos
## cuadros de física son para que el servidor registre los cuerpos recién entrados; sin ellos el
## primer rayo no choca con nada y el caso pasa por vacuidad.
func _espacio_de_la_estructura(almacen: Node3D) -> PhysicsDirectSpaceState3D:
	var estructura: Node3D = almacen.get_node("Estructura")
	almacen.remove_child(estructura)
	add_child(auto_free(estructura))
	_apagar_todo_menos_la_cascara(estructura)
	await get_tree().physics_frame
	await get_tree().physics_frame
	return estructura.get_world_3d().direct_space_state


func test_el_hueco_de_la_ventanilla_cae_en_la_ventanilla_del_modelo() -> void:
	# El marcador es el contrato con el spec 013, y hasta el 028 lo único que se afirmaba de él era
	# que existía. Con eso alcanzó para que estuviera cuatro commits adentro de un pasillo.
	var almacen := _almacen()
	var punto: Vector3 = (almacen.get_node("HuecoDeLaVentanilla") as Node3D).position
	var espacio: PhysicsDirectSpaceState3D = await _espacio_de_la_estructura(almacen)
	(
		assert_bool(_se_llega_desde_afuera(espacio, punto + Vector3.UP * SOBRE_EL_ANTEPECHO))
		. override_failure_message(
			(
				"`HuecoDeLaVentanilla` está en %s y ahí la cáscara es maciza: no es la ventanilla"
				% punto
			)
		)
		. is_true()
	)
	(
		assert_bool(_se_llega_desde_afuera(espacio, punto - Vector3.UP * BAJO_EL_ANTEPECHO))
		. override_failure_message(
			"debajo de `HuecoDeLaVentanilla` no hay antepecho: el marcador no está a su ras"
		)
		. is_false()
	)


func test_la_regla_del_hueco_rechaza_la_posicion_que_tenia_en_el_blockout() -> void:
	# El caso de arriba corre sobre un marcador que ya está bien, así que pasaría igual con una
	# regla rota. Éste le pasa el punto que el marcador tuvo de verdad y afirma que lo rechaza.
	var espacio: PhysicsDirectSpaceState3D = await _espacio_de_la_estructura(_almacen())
	var punto := PUNTO_DEL_HUECO_EN_EL_BLOCKOUT + Vector3.UP * SOBRE_EL_ANTEPECHO
	(
		assert_bool(_se_llega_desde_afuera(espacio, punto))
		. override_failure_message(
			"la regla dice que %s cae en un hueco, y ahí la cáscara es maciza" % punto
		)
		. is_false()
	)


func test_el_jugador_arranca_adentro_del_almacen_y_apoyado_en_el_piso() -> void:
	# **Éste es el único caso de la suite que entra `almacen.tscn` entera al árbol, y es a
	# propósito**: la única forma de saber que el escenario es caminable es correr la física del
	# `CharacterBody3D`, y para eso hace falta un árbol. El precio es que corren los `_ready()` de
	# la escena —el reloj arranca, el HUD se pinta—, y se paga en un solo caso.
	#
	# Lo que NO afirma es que el arranque sea el bueno para empezar el turno: afirma que es válido.
	# Elegir dónde empieza la jornada es diseño.
	var almacen: Node3D = auto_free(load(ESCENA_DEL_ALMACEN).instantiate())
	add_child(almacen)
	for _cuadro in range(CUADROS_DE_FISICA):
		await get_tree().physics_frame
	var jugador: CharacterBody3D = almacen.get_node("Jugador")
	(
		assert_bool(jugador.is_on_floor())
		. override_failure_message(
			"el jugador quedó en %s sin llegar al piso" % jugador.global_position
		)
		. is_true()
	)
	var cascara: MeshInstance3D = almacen.get_node("Estructura/" + CASCARA_DEL_EDIFICIO)
	var caja: AABB = cascara.global_transform * cascara.get_aabb()
	(
		assert_bool(caja.has_point(jugador.global_position))
		. override_failure_message(
			"el jugador quedó en %s, afuera del edificio %s" % [jugador.global_position, caja]
		)
		. is_true()
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
