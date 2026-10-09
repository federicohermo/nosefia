# gdlint:ignore=max-public-methods
#
# **Esta suite es donde converge la pila entera**: casi todas las ramas apiladas le agregan
# casos al mismo archivo, y la unión cruzó el techo de 20 al mergear el 032 en el 033 —21
# públicos, medido—. El techo existe para cazar god-objects en `src/`, y una suite no es uno:
# los casos no comparten estado y cada uno se lee solo. Partirla es la salida de verdad, pero
# no desde acá: cinco ramas de la pila todavía le agregan casos, y partirla ahora las hace
# conflictar a las cinco. La directiva va en la línea 1 porque el chequeo se reporta ahí.
## El cableado del almacén: qué instancia, qué anclajes ofrece y que nada suyo cuelga de otra cosa.
##
## No dice «se ve bien»: dice que los anclajes que los specs 008, 009 y 013 van a buscar
## por nombre están, y que la escena raíz sigue siendo una escena de cableado. La geometría —las
## mallas del modelo y sus colisiones— la afirma `estructura_del_almacen_test.gd`, que es la
## suite de la escena que la declara; acá se afirma que la instancia no vino corrida.
##
## Los casos de jerarquía sólo instancian la escena. Los que necesitan física o señales
## entran el almacén completo al árbol para resolver los enlaces de sus puestos.
extends GdUnitTestSuite

const ESCENA_DEL_ALMACEN := "res://src/escenas/almacen.tscn"

## El cableado se lee como texto en un solo caso, el que afirma lo que **ya no** está: una
## ausencia no se puede instanciar.
const SCRIPT_DEL_ALMACEN := "res://src/escenas/almacen.gd"

## El label del reloj de mesa. Se cuenta sobre el texto del `.tscn` y no sobre el árbol
## instanciado porque lo que hay que afirmar es que se referencia **una sola vez**.
const ESCENA_DEL_RELOJ_DE_MESA := "res://src/escenas/puestos/reloj_de_mesa.tscn"
const SCRIPT_DEL_RELOJ_DE_MESA := preload("res://src/escenas/puestos/reloj_de_mesa.gd")

## Dónde cuelga: del reloj de mesa del modelo, al lado de la computadora.
const RUTA_DEL_RELOJ_DE_MESA := "Estructura/reloj/Hora"

## Los `@export` que este caso verifica. Se listan acá y no adentro del caso porque son el
## contrato del cableado: agregar uno sin asignarlo en la escena tiene que dar rojo.
const CABLEADOS_DE_LA_RAIZ := ["_hud", "_reloj", "_ciclo", "_manija_del_balde"]

## La malla que trae la cáscara del edificio. Los rayos de acá miran sólo contra ella.
const CASCARA_DEL_EDIFICIO := "almacen"

## Dónde estaba el hueco de la ventanilla en el blockout que el modelo reemplazó. Está acá para
## que el caso que ejerce la regla tenga un punto que **no** es un hueco, y que sea uno real en vez
## de inventado: el marcador estuvo cuatro commits en esta posición —aire en un pasillo entre las
## góndolas y los estantes— con las 23 suites en verde.
const PUNTO_DEL_MURO_SIN_HUECO := Vector3(0.8, 1.2, 6.28)

## Alcanza para arrancar afuera del edificio desde cualquier punto de adentro: la planta mide
## 21,72 × 22,74 m.
const DISTANCIA_DE_AFUERA := 20.0

## Cuánto por encima del antepecho se mira para ver el hueco, y cuánto por debajo para ver que el
## antepecho está. El hueco vigente va de 1,04 a 2,44 m: arriba del vidrio empieza el dintel.
## La lectura superior prueba el vano de la cáscara sin interpretar una abertura sobre el vidrio.
const SOBRE_EL_ANTEPECHO := 0.4
const BAJO_EL_ANTEPECHO := 0.3

## Segundos **reales** que agotan un turno entero de una sola llamada a `_process()`. Sale de
## las dos constantes y no de un número escrito: el turno se mide en segundos de ficción y el
## reloj recibe los del jugador, así que rebalancear cualquiera de los dos no deja este caso
## cerrando la noche a medias.
const SEGUNDOS_REALES_DE_UN_TURNO := (
	Reglas.DURACION_DEL_TURNO / Ritmo.SEGUNDOS_DE_TURNO_POR_SEGUNDO_REAL
)

## Cuadros de física antes de mirar al jugador. Arranca en el aire y cae; 30 a 60 Hz son medio
## segundo, de sobra para medio metro.
const CUADROS_DE_FISICA := 30


## Los labels de la escena que pintan la hora: los que llevan el script del reloj de mesa.
## Se recorre el árbol entero, y no un nombre: una segunda copia del label en otro puesto es
## exactamente lo que este recorrido tiene que encontrar.
static func _lecturas_de_la_hora(nodo: Node) -> Array[Label3D]:
	var encontradas: Array[Label3D] = []
	for hijo in nodo.get_children():
		if hijo is Label3D and hijo.get_script() == SCRIPT_DEL_RELOJ_DE_MESA:
			encontradas.append(hijo)
		encontradas.append_array(_lecturas_de_la_hora(hijo))
	return encontradas


## Devuelve los nodos que rompen la regla de cableado, ya redactados con su padre.
##
## Sale a una función en vez de afirmar adentro del caso porque es lo único que la vuelve
## ejercible: una recorrida que sólo pasa por un árbol que ya cumple pasaría igual si no mirara
## nada, y el caso siguiente le pasa un árbol que sí la viola.
##
## **El discriminador es el `owner` y no la profundidad.** Un recorrido que contara niveles diría
## que la cámara del jugador viola la regla, y no la viola: le llega instanciada de `jugador.tscn`.
## En una sub-escena instanciada el `owner` de cada hijo es la raíz de la sub-escena, no la de
## afuera —está medido—, así que `owner == raiz` distingue exactamente los nodos que la
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
	for rumbo: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
		var desde: Vector3 = punto + rumbo * DISTANCIA_DE_AFUERA
		if espacio.intersect_ray(PhysicsRayQueryParameters3D.create(desde, punto)).is_empty():
			return true
	return false


func after_test() -> void:
	get_tree().paused = false


func _almacen() -> Node3D:
	return auto_free(load(ESCENA_DEL_ALMACEN).instantiate())


func test_el_almacen_carga_y_su_raiz_es_un_nodo_tridimensional() -> void:
	assert_object(_almacen()).is_instanceof(Node3D)


func test_los_muebles_y_el_anclaje_de_la_ventanilla_estan_por_nombre() -> void:
	# El cableado debe conservar estos destinos aunque cambien sus posiciones.
	var almacen := _almacen()
	assert_bool(almacen.has_node("Estructura/gondolanueva")).is_true()
	assert_bool(almacen.has_node("Estructura/base compu")).is_true()
	assert_bool(almacen.has_node("Estructura/HuecoDeLaVentanilla")).is_true()


func test_el_almacen_instancia_al_jugador_en_vez_de_duplicar_el_cuerpo() -> void:
	assert_bool(_almacen().has_node("Jugador")).is_true()


func test_la_escena_trae_luz_propia() -> void:
	# Una escena sin luces sale NEGRA, y el síntoma no nombra la causa. Por eso el entorno y las
	# luces se afirman en vez de dejarlos librados a que alguien mire la escena.
	#
	# **Se afirma que hay luz, no cuál.** Antes se exigía un `Sol` direccional por su nombre, y
	# eso ataba el test a una decisión de arte: cambiar el sol por luminarias de techo lo ponía
	# en rojo sin que nada estuviera mal. Lo que no puede pasar es que no haya ninguna.
	var almacen := _almacen()
	assert_bool(almacen.has_node("Ambiente/Entorno")).is_true()
	var entorno: Node = almacen.get_node("Ambiente/Entorno")
	assert_object(entorno).is_instanceof(WorldEnvironment)
	assert_object(entorno.environment).is_not_null()
	var luces := almacen.get_node("Ambiente").find_children("*", "Light3D", true, false)
	assert_int(luces.size()).is_greater(0)


func test_la_estructura_entra_instanciada_y_no_vino_corrida() -> void:
	# La sub-escena puede estar bien y la instancia venir corrida: el transform del nodo
	# instanciado se guarda acá, no en `estructura_del_almacen.tscn`. Es `transform` y no
	# `global_transform` porque esta suite no entra la escena al árbol y ahí el global aborta con
	# `Condition "!is_inside_tree()" is true` devolviendo la identidad, o sea que no fallaría por
	# la geometría: fallaría siempre.
	#
	# Ya no recorre cuerpo por cuerpo contra una tabla de posiciones: desde que la estructura es
	# el modelo, dónde va cada mueble lo decide Blender, y una tabla acá sería un rojo por cada
	# cosa que el modelador mueve. Lo que queda es lo único que se edita de este lado.
	var estructura: Node3D = _almacen().get_node("Estructura")
	assert_that(estructura.transform).is_equal(Transform3D.IDENTITY)


## Espera a que el servidor registre los cuerpos; antes el rayo podría pasar sin colisionar.
func _espacio_de_la_estructura(almacen: Node3D) -> PhysicsDirectSpaceState3D:
	var estructura: Node3D = almacen.get_node("Estructura")
	# Los muebles tienen funciones; sus enlaces se resuelven desde la escena completa.
	add_child(almacen)
	_apagar_todo_menos_la_cascara(estructura)
	await get_tree().physics_frame
	await get_tree().physics_frame
	return estructura.get_world_3d().direct_space_state


func test_el_hueco_de_la_ventanilla_cae_en_la_ventanilla_del_modelo() -> void:
	# El marcador es el contrato con la ventanilla, y durante un tiempo lo único que se afirmaba
	# de él era que existía. Con eso alcanzó para que estuviera cuatro commits adentro de un pasillo.
	var almacen := _almacen()
	var punto: Vector3 = (almacen.get_node("Estructura/HuecoDeLaVentanilla") as Node3D).position
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


func test_la_regla_del_hueco_rechaza_un_punto_del_muro() -> void:
	# El caso de arriba corre sobre un marcador que ya está bien, así que pasaría igual con una
	# regla rota. Éste le pasa el punto que el marcador tuvo de verdad y afirma que lo rechaza.
	var espacio: PhysicsDirectSpaceState3D = await _espacio_de_la_estructura(_almacen())
	var punto := PUNTO_DEL_MURO_SIN_HUECO + Vector3.UP * SOBRE_EL_ANTEPECHO
	(
		assert_bool(_se_llega_desde_afuera(espacio, punto))
		. override_failure_message(
			"la regla dice que %s cae en un hueco, y ahí la cáscara es maciza" % punto
		)
		. is_false()
	)


func test_el_jugador_arranca_adentro_del_almacen_y_apoyado_en_el_piso() -> void:
	# **Éste es uno de los dos casos de la suite que entran `almacen.tscn` entera al árbol, y es
	# a propósito**: la única forma de saber que el escenario es caminable es correr la física del
	# `CharacterBody3D`, y para eso hace falta un árbol. El precio es que corren los `_ready()` de
	# la escena —el reloj arranca, el HUD se pinta—, y se paga sólo donde hace falta.
	#
	# Lo que NO afirma es que el arranque sea el bueno para empezar el turno: afirma que es válido.
	# Elegir dónde empieza la jornada es diseño.
	var almacen: Node3D = auto_free(load(ESCENA_DEL_ALMACEN).instantiate())
	add_child(almacen)
	for _cuadro in range(CUADROS_DE_FISICA):
		await get_tree().physics_frame
	var jugador: CharacterBody3D = almacen.get_node("Jugador")
	var arranque: Transform3D = almacen.get("_arranque")
	var corrimiento := jugador.global_position - arranque.origin
	(
		assert_float(Vector2(corrimiento.x, corrimiento.z).length())
		. override_failure_message("el jugador no arrancó en el punto de arranque")
		. is_less(0.05)
	)
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
	# rota. Éste le arma el defecto —un puesto con sus hijos escritos
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


func test_el_cableado_dejo_de_armar_el_turno_y_de_llevar_el_puntaje() -> void:
	# Las dos cosas se fueron a `Partida`, y mientras siguieran acá la regla del despido no se
	# podía alcanzar jugando: el puntaje moría con la escena. El caso mira el texto del archivo
	# porque es la única forma de afirmar una ausencia.
	var texto := FileAccess.get_file_as_string(SCRIPT_DEL_ALMACEN)
	assert_str(texto).not_contains("Legajo")
	assert_str(texto).not_contains("Turno.new(")
	(
		assert_int(texto.count("Partida.desde("))
		. override_failure_message(
			(
				"`almacen.gd` arma %d partidas: el parte y el ciclo deben leer la misma"
				% texto.count("Partida.desde(")
			)
		)
		. is_equal(1)
	)


func test_el_almacen_arranca_desde_el_guardado() -> void:  # AC-SAV-017
	# El conteo de arriba no dice de dónde sale la partida: `Partida.desde({})` también lo pasa.
	var nueva: Partida = _almacen().get("_partida")
	assert_int(nueva.jornada()).is_equal(ReglasDeLaPartida.PRIMERA_JORNADA)
	assert_int(nueva.apercibimientos()).is_equal(0)
	var guardada := {
		PartidaSerializada.clave(PartidaSerializada.Campo.JORNADA):
		ReglasDeLaPartida.PRIMERA_JORNADA + 2,
		PartidaSerializada.clave(PartidaSerializada.Campo.MEDIOS):
		Reglas.APERCIBIMIENTOS_POR_AVISO * Reglas.MEDIOS_POR_APERCIBIMIENTO,
	}
	assert_bool(Guardado.new().escribir(guardada)).is_true()
	var retomada: Partida = _almacen().get("_partida")
	assert_int(retomada.jornada()).is_equal(ReglasDeLaPartida.PRIMERA_JORNADA + 2)
	assert_int(retomada.apercibimientos()).is_equal(Reglas.APERCIBIMIENTOS_POR_AVISO)


func test_la_escena_trae_el_ciclo_de_jornadas_en_servicios() -> void:
	# Sin el nodo, el `@export` del cableado llega nulo y el juego muere en el primer cuadro con
	# un error que no nombra a `almacen.tscn`.
	var almacen := _almacen()
	assert_bool(almacen.has_node("Servicios/CicloDeJornadas")).is_true()
	assert_object(almacen.get_node("Servicios/CicloDeJornadas")).is_instanceof(CicloDeJornadas)


func test_los_cableados_de_la_raiz_llegan_asignados() -> void:
	# **Un `@export` sin asignar en el `.tscn` deja la escena cargando sin un solo error**, los
	# nodos de `verificar.py` en verde, y el juego muerto en el primer cuadro con un
	# `Nonexistent function ... in base 'Nil'` que no nombra ni a `almacen.tscn` ni al export que
	# falta. El caso de arriba mira que el nodo exista; éste, que el cableado lo alcance — que
	# son dos cosas distintas: el nodo puede estar y el `node_paths` de la raíz no nombrarlo.
	var almacen := _almacen()
	for cableado: String in CABLEADOS_DE_LA_RAIZ:
		(
			assert_object(almacen.get(cableado))
			. override_failure_message(
				(
					"`almacen.tscn` no le asignó `%s` a la raíz: el juego muere en el primer cuadro"
					% cableado
				)
			)
			. is_not_null()
		)


func test_el_cableado_arma_el_parte_una_sola_vez() -> void:
	# Dos partes por jornada sería la placa pintada dos veces con dos objetos distintos, y la
	# segunda tapando a la primera. Las decisiones se ejercen en sus suites funcionales.
	var texto := FileAccess.get_file_as_string(SCRIPT_DEL_ALMACEN)
	(
		assert_int(texto.count("ParteDeCierre.new("))
		. override_failure_message(
			"`almacen.gd` arma %d partes por jornada" % texto.count("ParteDeCierre.new(")
		)
		. is_equal(1)
	)


func test_la_escena_instancia_la_pantalla_de_cierre() -> void:
	var almacen := _almacen()
	assert_bool(almacen.has_node("Interfaz/PantallaDeCierre")).is_true()
	assert_object(almacen.get_node("Interfaz/PantallaDeCierre")).is_instanceof(PantallaDeCierre)


func test_despachar_la_placa_abre_la_noche_siguiente_sin_tareas_cumplidas() -> void:
	# **El segundo caso de la suite que entra `almacen.tscn` entera al árbol.** El lazo que este
	# spec cierra —la noche termina, la placa aparece, el jugador la despacha y la siguiente
	# abre— vive entero en señales conectadas: leído como texto no dice si funciona, y es lo
	# único que vuelve alcanzable la jornada 2 jugando.
	var almacen: Node3D = auto_free(load(ESCENA_DEL_ALMACEN).instantiate())
	add_child(almacen)
	await get_tree().process_frame
	var reloj: RelojDelTurno = almacen.get_node("Servicios/RelojDelTurno")
	var ciclo: CicloDeJornadas = almacen.get_node("Servicios/CicloDeJornadas")
	var pantalla: PantallaDeCierre = almacen.get_node("Interfaz/PantallaDeCierre")
	var tareas: Label = almacen.get_node("Interfaz/Hud/Tareas")
	assert_bool(reloj.obligatoria(Tarea.Tipo.REGISTRAR).completada()).is_false()

	# Una obligatoria adicional distingue el marcador del cierre del de la apertura siguiente.
	assert_bool(reloj.completar(reloj.obligatoria(Tarea.Tipo.CAJA))).is_true()
	reloj.avanzar(SEGUNDOS_REALES_DE_UN_TURNO)
	(
		assert_bool(pantalla.visible)
		. override_failure_message("la noche cerró y la placa no apareció")
		. is_true()
	)

	var boton: Button = pantalla.get_node("Fondo/Panel/Continuar")
	boton.pressed.emit()
	assert_bool(pantalla.visible).is_false()
	(
		assert_int(ciclo.partida().jornada())
		. override_failure_message("despachada la placa, la partida no pasó a la noche siguiente")
		. is_equal(ReglasDeLaPartida.PRIMERA_JORNADA + 1)
	)
	(
		assert_str(tareas.text)
		. override_failure_message("el HUD arrastró el marcador de la noche anterior")
		. is_equal(
			Hud.TEXTO_DE_LAS_TAREAS % Marcador.tareas(0, Apertura.cantidad_de_obligatorias())
		)
	)
	for tipo: Tarea.Tipo in Tarea.Tipo.values():
		assert_bool(reloj.obligatoria(tipo).completada()).is_false()


func test_el_arranque_esta_frente_a_la_entrada_del_lado_de_adentro() -> void:
	var almacen := _almacen()
	add_child(almacen)
	var arranque: Transform3D = almacen.get("_arranque")
	var entrada: Node3D = almacen.get_node("Estructura/puertaentrada")
	var hacia_la_puerta := entrada.global_position - arranque.origin
	hacia_la_puerta.y = 0.0
	assert_float(hacia_la_puerta.length()).is_less(1.5)
	# Mira al local: la puerta le queda a la espalda.
	var frente := -arranque.basis.z
	assert_float(frente.dot(hacia_la_puerta.normalized())).is_less(-0.9)
	var cascara: MeshInstance3D = almacen.get_node("Estructura/" + CASCARA_DEL_EDIFICIO)
	var caja: AABB = cascara.global_transform * cascara.get_aabb()
	assert_bool(caja.has_point(arranque.origin + Vector3.UP)).is_true()


func test_abrir_la_jornada_deja_al_jugador_en_el_arranque() -> void:  # AC-PLY-044
	var almacen: Node3D = auto_free(load(ESCENA_DEL_ALMACEN).instantiate())
	add_child(almacen)
	await get_tree().process_frame
	var jugador: CharacterBody3D = almacen.get_node("Jugador")
	var control: ControlDelJugador = jugador.get("_control")
	var arranque: Transform3D = almacen.get("_arranque")
	var reloj: RelojDelTurno = almacen.get_node("Servicios/RelojDelTurno")
	var pantalla: PantallaDeCierre = almacen.get_node("Interfaz/PantallaDeCierre")
	jugador.global_position = Vector3(5.0, 0.2, -3.0)
	jugador.velocity = Vector3(2.0, 0.0, 1.0)
	control.girar(Vector2(170.0, -90.0))
	reloj.avanzar(SEGUNDOS_REALES_DE_UN_TURNO)
	(pantalla.get_node("Fondo/Panel/Continuar") as Button).pressed.emit()
	assert_vector(jugador.global_position).is_equal_approx(arranque.origin, Vector3.ONE * 1e-4)
	assert_vector(jugador.velocity).is_equal(Vector3.ZERO)
	assert_float(control.yaw()).is_equal_approx(arranque.basis.get_euler().y, 1e-4)
	assert_float(control.pitch()).is_equal(0.0)
	var camara: Camera3D = jugador.get_node("Giro/Camara")
	assert_float(camara.rotation.x).is_equal(0.0)
	var frente: Vector3 = jugador.call("frente")
	assert_vector(frente).is_equal_approx(-arranque.basis.z, Vector3.ONE * 1e-4)


func test_con_el_despido_la_placa_vuelve_al_menu_y_no_abre_otra_noche() -> void:  # AC-EMP-016
	var almacen: Node3D = auto_free(load(ESCENA_DEL_ALMACEN).instantiate())
	# Tres apercibimientos y una noche sin tareas: salta de 3 a 5 sin pisar el 4.
	almacen.set("_partida", Partida.new(Legajo.con_medios((3) * Reglas.MEDIOS_POR_APERCIBIMIENTO)))
	add_child(almacen)
	await get_tree().process_frame
	var menus := [0]
	almacen.set("_ir_al_menu", func() -> void: menus[0] += 1)
	var reloj: RelojDelTurno = almacen.get_node("Servicios/RelojDelTurno")
	var ciclo: CicloDeJornadas = almacen.get_node("Servicios/CicloDeJornadas")
	var pantalla: PantallaDeCierre = almacen.get_node("Interfaz/PantallaDeCierre")
	var aperturas := [0]
	ciclo.jornada_abierta.connect(func(_jornada: int) -> void: aperturas[0] += 1)
	reloj.avanzar(SEGUNDOS_REALES_DE_UN_TURNO)
	assert_int(ciclo.partida().final()).is_equal(Partida.Final.DESPEDIDO)
	assert_bool(pantalla.visible).is_true()
	assert_bool((pantalla.get_node("Fondo/Panel/Continuar") as Button).visible).is_false()
	var volver: Button = pantalla.get_node("Fondo/Panel/VolverAlMenu")
	assert_bool(volver.visible).is_true()
	volver.pressed.emit()
	volver.pressed.emit()
	assert_int(menus[0]).is_equal(1)
	assert_int(aperturas[0]).is_zero()
	assert_bool(reloj.corriendo()).is_false()


func test_con_la_partida_en_curso_volver_al_menu_no_abre_la_noche_siguiente() -> void:
	var almacen: Node3D = auto_free(load(ESCENA_DEL_ALMACEN).instantiate())
	add_child(almacen)
	await get_tree().process_frame
	var menus := [0]
	almacen.set("_ir_al_menu", func() -> void: menus[0] += 1)
	var reloj: RelojDelTurno = almacen.get_node("Servicios/RelojDelTurno")
	var ciclo: CicloDeJornadas = almacen.get_node("Servicios/CicloDeJornadas")
	var pantalla: PantallaDeCierre = almacen.get_node("Interfaz/PantallaDeCierre")
	reloj.avanzar(SEGUNDOS_REALES_DE_UN_TURNO)
	assert_bool(ciclo.partida().terminada()).is_false()
	(pantalla.get_node("Fondo/Panel/VolverAlMenu") as Button).pressed.emit()
	assert_int(menus[0]).is_equal(1)
	assert_int(ciclo.partida().jornada()).is_equal(ReglasDeLaPartida.PRIMERA_JORNADA + 1)
	assert_bool(reloj.corriendo()).is_false()


func test_volver_al_menu_desde_la_pausa_sale_de_la_pausa_y_va_al_menu() -> void:  # AC-SAV-020
	var almacen: Node3D = auto_free(load(ESCENA_DEL_ALMACEN).instantiate())
	add_child(almacen)
	await get_tree().process_frame
	var menus := [0]
	almacen.set("_ir_al_menu", func() -> void: menus[0] += 1)
	var pausa: ControlDePausa = almacen.get_node("Interfaz/ControlDePausa")
	var menu: MenuDePausa = almacen.get_node("Interfaz/MenuDePausa")
	pausa.pausar()
	assert_bool(menu.visible).is_true()
	(menu.get_node("Fondo/Panel/Opciones/VolverAlMenu") as Button).pressed.emit()
	(menu.get_node("Fondo/Panel/Opciones/VolverAlMenu") as Button).pressed.emit()
	assert_bool(get_tree().paused).is_false()
	assert_int(menus[0]).is_equal(1)
	assert_bool(Guardado.new().hay_guardado()).is_false()


func test_con_la_placa_en_pantalla_esc_no_pausa() -> void:  # AC-SAV-018
	var almacen: Node3D = auto_free(load(ESCENA_DEL_ALMACEN).instantiate())
	add_child(almacen)
	await get_tree().process_frame
	var reloj: RelojDelTurno = almacen.get_node("Servicios/RelojDelTurno")
	reloj.avanzar(SEGUNDOS_REALES_DE_UN_TURNO)
	var esc := InputEventAction.new()
	esc.action = &"ui_cancel"
	esc.pressed = true
	(almacen.get_node("Interfaz/ControlDePausa") as ControlDePausa)._input(esc)
	assert_bool(get_tree().paused).is_false()
	assert_bool((almacen.get_node("Interfaz/MenuDePausa") as MenuDePausa).visible).is_false()


func test_volver_al_menu_carga_el_menu_de_inicio() -> void:
	var texto := FileAccess.get_file_as_string(SCRIPT_DEL_ALMACEN)
	assert_str(texto).contains('"res://src/escenas/menu_de_inicio.tscn"')
	assert_str(texto).contains("change_scene_to_file(")


func test_la_hora_se_lee_en_un_solo_lugar_y_es_el_reloj_de_mesa() -> void:  # AC-SHF-017
	# Dos lecturas serían dos displays diciendo lo mismo y uno solo conectado, que es el modo de
	# falla silencioso: el jugador camina hasta el que no anda y no hay error en ningún lado.
	var texto := FileAccess.get_file_as_string(
		"res://src/escenas/puestos/estructura_del_almacen.tscn"
	)
	(
		assert_int(texto.count(ESCENA_DEL_RELOJ_DE_MESA))
		. override_failure_message(
			(
				"`estructura_del_almacen.tscn` referencia %d veces al reloj de mesa"
				% texto.count(ESCENA_DEL_RELOJ_DE_MESA)
			)
		)
		. is_equal(1)
	)
	var almacen := _almacen()
	var lecturas := _lecturas_de_la_hora(almacen)
	assert_array(lecturas).override_failure_message("lecturas: %s" % [lecturas]).has_size(1)
	# Cuelga de la malla del reloj de mesa del modelo, y no gira hacia la cámara: se lee cerca
	# del escritorio y no desde la góndola.
	var hora: Label3D = lecturas[0]
	assert_str(str(almacen.get_path_to(hora))).is_equal(RUTA_DEL_RELOJ_DE_MESA)
	assert_object(hora.get_parent()).is_instanceof(MeshInstance3D)
	assert_int(hora.billboard).is_equal(BaseMaterial3D.BILLBOARD_DISABLED)
	assert_array(_violaciones_de_cableado(almacen)).is_empty()
	# Y el `@export` de la raíz resuelto, que es lo que ninguna de las afirmaciones de arriba ve:
	# si `reloj_de_mesa.tscn` perdiera su `script`, el nodo instanciado sería un `Label3D`
	# pelado, el `@export` llegaría nulo **con el `node_paths` bien escrito**, y el juego moriría
	# en el primer cuadro con un error que no nombra a ninguno de los dos `.tscn`.
	(
		assert_object(almacen.get("_reloj_de_mesa"))
		. override_failure_message(
			"`_reloj_de_mesa` llegó nulo: la sub-escena perdió su `script` o su `node_paths`"
		)
		. is_not_null()
	)


func test_el_reloj_de_mesa_queda_sobre_el_vidrio_del_reloj_del_modelo() -> void:
	# Un label colgado de una malla con escala no uniforme hereda esa escala: si la base del
	# `.tscn` no la deshace, el texto sale aplastado. Se afirma sobre la transformación global,
	# que es lo que el jugador ve, y contra la caja de la malla, que es donde tiene que estar.
	var almacen: Node3D = auto_free(load(ESCENA_DEL_ALMACEN).instantiate())
	add_child(almacen)
	await get_tree().process_frame
	var hora: Label3D = almacen.get_node(RUTA_DEL_RELOJ_DE_MESA)
	var reloj: MeshInstance3D = hora.get_parent()
	var global := hora.global_transform.basis
	assert_bool(global.is_conformal()).is_true()
	assert_float(global.get_scale().x).is_equal_approx(1.0, 0.001)
	assert_float(global.get_scale().y).is_equal_approx(1.0, 0.001)
	# El frente del label —su `+Z`— mira al `-X` de la malla reflejada, que es la cara del display.
	var frente := global.z.normalized()
	var cara := -reloj.global_transform.basis.x.normalized()
	assert_float(frente.dot(cara)).is_equal_approx(1.0, 0.001)
	# Y está pegado al vidrio: adentro de la caja de la malla estirada dos centímetros, que es
	# lo que separa «sobre el display» de «flotando en el pasillo».
	var caja: AABB = (reloj.global_transform * reloj.get_aabb()).grow(0.02)
	(
		assert_bool(caja.has_point(hora.global_position))
		. override_failure_message(
			"el label quedó en %s, lejos del reloj %s" % [hora.global_position, caja]
		)
		. is_true()
	)


func test_el_cableado_le_da_la_hora_al_reloj_de_mesa_y_no_al_hud() -> void:
	# El contador de tareas sigue conectado al reloj de la jornada.
	var texto := FileAccess.get_file_as_string(SCRIPT_DEL_ALMACEN)
	assert_str(texto).is_not_empty()
	assert_str(texto).not_contains("_hud.mostrar_tiempo")
	assert_str(texto).contains("tiempo_consumido.connect(_reloj_de_mesa.mostrar_tiempo)")
	assert_str(texto).contains("tarea_completada.connect(_hud.mostrar_tareas)")


func test_el_cableado_de_reponer_llega_entero_hasta_los_huecos() -> void:
	# Un `@export` de tipo `Node` en una escena escrita a mano va declarado ADEMÁS en el
	# `node_paths` del tag del nodo, o queda en `null`: la escena carga sin un solo error, los
	# nodos dan verde, y el juego muere en el primer cuadro con un
	# `Nonexistent function … in base 'Nil'` que no nombra ni al `.tscn` ni al `@export`.
	#
	# Los tres niveles se afirman juntos y no en tres casos porque la trampa es la misma en los
	# tres: la raíz, el nodo instanciado que apunta afuera de su sub-escena, y el `@export` que
	# la sub-escena ya traía y que sobrescribir uno de sus hermanos podría borrar.
	var almacen := _almacen()
	for propiedad: String in ["_repositor", "_estante"]:
		(
			assert_object(almacen.get(propiedad))
			. override_failure_message(
				"`%s` quedó en null: falta su entrada en el `node_paths` de la raíz" % propiedad
			)
			. is_not_null()
		)
	# Las cajas van aparte porque son un `Array`: vacío **no es** null, así que el barrido de
	# arriba las daría por cableadas sin que haya una sola. Y se afirma que cubren el catálogo
	# entero sin repetir, que es el bug que este cableado cierra: con una sola caja, despachaba
	# siempre su `producto` por defecto y los demás quedaban en cero para siempre, o sea que
	# REPONER no se podía terminar jugando.
	var despachados: Array[int] = []
	for caja: Node3D in almacen.get("_cajas_de_productos"):
		(
			assert_object(caja)
			. override_failure_message("una entrada de `_cajas_de_productos` quedó en null")
			. is_not_null()
		)
		despachados.append(caja.producto)
	despachados.sort()
	var del_catalogo: Array[int] = []
	for producto in Catalogo.todos():
		del_catalogo.append(producto.id)
	del_catalogo.sort()
	(
		assert_array(despachados)
		. override_failure_message(
			"las cajas despachan %s y el catálogo tiene %s" % [despachados, del_catalogo]
		)
		. is_equal(del_catalogo)
	)
	var repositor: Repositor = almacen.get_node("Servicios/Repositor")
	assert_object(repositor.reloj).is_not_null()
	var estante: Node3D = almacen.get_node("Estructura/gondolanueva/StaticBody3D")
	assert_bool(estante.has_node("Contenido")).is_true()
	estante.mostrar(1)
	assert_bool((estante.get_node("Contenido").get_child(0) as Node3D).visible).is_true()


func test_el_marco_para_asomarse_coincide_con_los_bordes_del_hueco() -> void:  # AC-PLY-059
	var almacen := _almacen()
	var espacio: PhysicsDirectSpaceState3D = await _espacio_de_la_estructura(almacen)
	var ventanilla: Node3D = almacen.get_node("Estructura/Ventanilla")
	var borde: Marker3D = ventanilla.get("borde_superior")
	var antepecho: MeshInstance3D = ventanilla.get("antepecho")
	var soporte: AABB = (
		borde.global_transform.affine_inverse() * antepecho.global_transform * antepecho.get_aabb()
	)
	var altura := (borde.global_position - ventanilla.global_position).dot(borde.global_basis.y)
	var marco := Transform3D(
		borde.global_basis, ventanilla.global_position + borde.global_basis.y * altura / 2
	)
	var tamano := Vector2(soporte.size.x, altura)
	assert_object(borde).is_not_null()
	assert_float(tamano.x).is_greater(0.0)
	assert_float(tamano.y).is_greater(0.0)
	var normal := marco.basis.z.normalized()
	# Se cruza cada borde desde el centro, sin convertir la posición artística en constante.
	for lado: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		var extremo := Vector3(lado.x * tamano.x / 2.0, lado.y * tamano.y / 2.0, 0.0)
		for adentro: bool in [true, false]:
			var margen := -0.02 if adentro else 0.02
			var local := extremo + Vector3(lado.x, lado.y, 0.0) * margen
			var punto := marco * local
			var consulta := PhysicsRayQueryParameters3D.create(
				punto + normal * 0.5, punto - normal * 0.5
			)
			var golpe := espacio.intersect_ray(consulta)
			assert_bool(golpe.is_empty()).is_equal(adentro)
