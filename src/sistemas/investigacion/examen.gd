## Acerca a la cara lo que se lleva o lo que se mira, deja girarlo, y avisa qué reveló.
##
## Va en `investigacion/` porque es el lado de la tensión que consume tiempo del turno y no
## cumple ninguna obligatoria: cada segundo mirando una lata es un segundo que no se repuso nada.
## Ése es el criterio de la carpeta, y es el mismo que deja a `Agarre` en `marco/`.
##
## **No conoce al jugador.** Que examinar clave la cámara y la caminata es real y necesario —sin
## eso, mirar un objeto lo rota Y gira la cámara al mismo tiempo, y no da rojo en ningún lado—,
## pero suspender es cosa de quien tiene al jugador adelante: acá sale `examen_iniciado` y la
## cáscara lo traduce a `suspender()`. Al revés, este sistema tendría que nombrar un nodo de
## `escenas/` y el gate de capas lo cazaría.
class_name Examen
extends Node

signal examen_iniciado(nodo: Node3D)
signal examen_terminado
signal objeto_revelado(datos: ObjetoDelAlmacen, es_nuevo: bool)

## `Agarre` es de la misma capa, y entra por `@export` en vez de buscarse con `get_node()` hacia
## arriba: una escena que se reacomoda rompería la ruta sin que nada avise hasta correrla.
@export var agarre: Agarre
@export var punto_de_examen: Node3D

var _hallazgos := Hallazgos.new()
var _examinando: Node3D = null


func hallazgos() -> Hallazgos:
	return _hallazgos


func esta_examinando() -> bool:
	return _examinando != null


## Arranca el examen y devuelve si arrancó.
##
## Tres caminos, y el orden entre ellos es la decisión: **lo que se lleva le gana a lo enfocado**.
## Al revés no habría forma de mirar lo que se acaba de levantar sin soltarlo primero, que es lo
## que el jugador quiere hacer justo después de levantarlo.
##
## `enfocado` es lo que la mira tiene adelante y `nodo_enfocado` su cuerpo. Un levantable se
## acerca a la cara sin agarrarlo. La E sobre algo fijo —una puerta, la ventanilla— revela lo que
## se nota mirándolo **sin suspender a nadie**, porque no hay nada que rotar. Es un pensamiento,
## no un examen, y por eso devuelve `false`: no arrancó ningún examen que después haya que
## terminar.
func iniciar(enfocado: ObjetoDelAlmacen = null, nodo_enfocado: Node3D = null) -> bool:
	if _examinando != null or agarre == null:
		return false
	var datos := agarre.manos().sostenido()
	var del_mundo := (
		datos == null and enfocado != null and enfocado.es_levantable() and nodo_enfocado != null
	)
	if datos == null and not del_mundo:
		if enfocado != null and not enfocado.es_levantable():
			objeto_revelado.emit(enfocado, _hallazgos.registrar(enfocado))
		return false
	# Un punto sin cablear es un `.tscn` mal armado y no «no hay nada que examinar», y por eso
	# corta acá en vez de caer al pensamiento: sin el corte, la E con una lata en la mano revelaba
	# la puerta que se estaba mirando —lo contrario del orden que este método decide— y lo hacía
	# sin un solo error. Es el gemelo del punto de carga en `Agarre`.
	if punto_de_examen == null:
		push_error("Examen sin punto de examen cableado: revisar jugador.tscn")
		return false
	var nodo: Node3D = null
	if del_mundo:
		datos = enfocado
		nodo = agarre.acercar_del_mundo(nodo_enfocado, punto_de_examen)
	else:
		nodo = agarre.mover_lo_sostenido(punto_de_examen)
	if nodo == null:
		return false
	# Una distancia fija dejaba la caja grande con las esquinas afuera del cuadro, y al girarla
	# le metía una esquina adentro de la cámara.
	var distancia := ReglasDeLosObjetos.distancia_de_examen(_radio(nodo))
	punto_de_examen.position = Vector3.FORWARD * distancia
	_examinando = nodo
	examen_iniciado.emit(nodo)
	objeto_revelado.emit(datos, _hallazgos.registrar(datos))
	return true


## Devuelve el objeto a donde estaba y avisa que se terminó. Con nada en examen no hace nada:
## no puede emitir un aviso vacío.
func terminar() -> void:
	if _examinando == null:
		return
	_examinando = null
	if agarre != null and agarre.devolver_al_mundo() == null:
		agarre.devolver_a_la_mano()
	examen_terminado.emit()


## Devuelve si el examen se comió el clic de agarrar.
##
## Mientras hay algo pegado a la cara, el clic es para girarlo arrastrando: no agarra, no suelta,
## no coloca y no cierra. Soltar desde ahí lo dejaría caer contra la cámara, y este sistema se
## quedaría girando algo que se cayó al piso. Que la escena pregunte esto antes de pasarle el
## clic a `Agarre` es ruteo; qué hace el clic lo decide acá, que es donde está el estado.
func atajar_el_clic() -> bool:
	return _examinando != null


## La misma tecla abre y cierra, y ese `if` sobre el estado del examen vive acá: en la escena
## sería una regla del juego sin test, y los dos gates darían verde sobre ella.
func alternar(enfocado: ObjetoDelAlmacen = null, nodo_enfocado: Node3D = null) -> void:
	if _examinando == null:
		iniciar(enfocado, nodo_enfocado)
	else:
		terminar()


## Gira lo examinado con las teclas de movimiento. Cuánto, lo dice el dominio.
func girar(entrada: Vector2, segundos: float) -> void:
	var giro := ReglasDeLosObjetos.giro_del_examen(entrada, segundos)
	_rotar(-giro.x, giro.y)


## Gira lo examinado con el mouse, sólo mientras se arrastra con el clic apretado.
##
## Reusa la sensibilidad de la mirada en vez de declarar una propia: es la misma unidad —radianes
## por píxel— y el mismo gesto, y dos números para lo mismo se separan el día que alguien ajuste
## uno solo.
func arrastrar(relativo: Vector2, con_el_clic: bool) -> void:
	if not con_el_clic:
		return
	var giro := relativo * ReglasDelJugador.SENSIBILIDAD_DEL_MOUSE
	_rotar(-giro.x, -giro.y)


## Sin nada en examen no hace nada: el mouse y las teclas se usan todo el tiempo, también
## caminando.
func _rotar(sobre_el_vertical: float, sobre_el_horizontal: float) -> void:
	if _examinando == null:
		return
	# El giro va en el espacio del jugador y no en el del objeto —`rotate_y` y no
	# `rotate_object_local`—: si fuera local, después del primer giro el eje vertical del objeto
	# ya no es el vertical de la pantalla y el giro deja de hacer lo que se ve.
	_examinando.rotate_y(sobre_el_vertical)
	_examinando.rotate_x(sobre_el_horizontal)


## El radio de la esfera que envuelve lo que se ve del nodo, alrededor de su origen: es el punto
## sobre el que `_rotar()` lo gira.
##
## Se compone la transformación local de cada malla hasta el nodo, y no la global: fuera del
## árbol de escena la global devuelve la identidad, y el test mediría una caja sin escala.
static func _radio(nodo: Node3D) -> float:
	var radio := 0.0
	for visual: VisualInstance3D in nodo.find_children("*", "VisualInstance3D", true, false):
		var hasta_el_nodo := Transform3D.IDENTITY
		var actual: Node = visual
		while actual != nodo and actual is Node3D:
			hasta_el_nodo = (actual as Node3D).transform * hasta_el_nodo
			actual = actual.get_parent()
		var limites := visual.get_aabb()
		for indice in 8:
			radio = maxf(radio, (hasta_el_nodo * limites.get_endpoint(indice)).length())
	return radio
