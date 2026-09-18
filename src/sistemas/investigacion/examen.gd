## Acerca a la cara lo que se lleva, deja girarlo, y avisa qué reveló.
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
## `enfocado` es lo que la mira tiene adelante, y sólo se usa en el tercer camino: la E sobre algo
## fijo —una puerta, la ventanilla— revela lo que se nota mirándolo **sin agarrarlo ni suspender
## a nadie**, porque no hay nada que rotar. Es un pensamiento, no un examen, y por eso devuelve
## `false`: no arrancó ningún examen que después haya que terminar.
func iniciar(enfocado: ObjetoDelAlmacen = null) -> bool:
	if _examinando != null or agarre == null:
		return false
	var datos := agarre.manos().sostenido()
	if datos != null:
		# Un punto sin cablear es un `.tscn` mal armado y no «no hay nada que examinar», y por eso
		# corta acá en vez de caer al camino de abajo: sin el corte, la E con una lata en la mano
		# revelaba la puerta que se estaba mirando —lo contrario del orden que este método
		# decide— y lo hacía sin un solo error. Es el gemelo del punto de carga en `Agarre`.
		if punto_de_examen == null:
			push_error("Examen sin punto de examen cableado: revisar jugador.tscn")
			return false
		var nodo := agarre.mover_lo_sostenido(punto_de_examen)
		if nodo == null:
			return false
		_examinando = nodo
		examen_iniciado.emit(nodo)
		objeto_revelado.emit(datos, _hallazgos.registrar(datos))
		return true
	if enfocado != null and not enfocado.es_levantable():
		objeto_revelado.emit(enfocado, _hallazgos.registrar(enfocado))
	return false


## Devuelve el objeto a la mano y avisa que se terminó. Con nada en examen no hace nada: la
## tecla se puede apretar dos veces, y la segunda no puede emitir un aviso vacío.
func terminar() -> void:
	if _examinando == null:
		return
	_examinando = null
	if agarre != null:
		agarre.devolver_a_la_mano()
	examen_terminado.emit()


## Devuelve si el examen se comió el clic de agarrar.
##
## Mientras hay algo pegado a la cara, el clic lo devuelve a la mano en vez de soltarlo: soltarlo
## desde ahí lo dejaría caer contra la cámara, y este sistema se quedaría apuntando a un nodo que
## ya no está en la mano — o sea, rotando algo que se cayó al piso. Que la escena pregunte esto
## antes de pasarle el clic a `Agarre` es ruteo; qué hace el clic lo decide acá, que es donde
## está el estado y donde hay test.
func atajar_el_clic() -> bool:
	if _examinando == null:
		return false
	terminar()
	return true


## La misma tecla abre y cierra, y ese `if` sobre el estado del examen vive acá: en la escena
## sería una regla del juego sin test, y los dos gates darían verde sobre ella.
func alternar(enfocado: ObjetoDelAlmacen = null) -> void:
	if _examinando == null:
		iniciar(enfocado)
	else:
		terminar()


## Gira lo que se está examinando, que es lo que permite leer la etiqueta de atrás.
##
## Reusa la sensibilidad de la mirada en vez de declarar una propia: es la misma unidad —radianes
## por píxel— y el mismo gesto, y dos números para lo mismo se separan el día que alguien ajuste
## uno solo. Sin nada en examen no hace nada: el mouse se mueve todo el tiempo, también caminando.
func rotar(relativo: Vector2) -> void:
	if _examinando == null:
		return
	# El giro va en el espacio del jugador y no en el del objeto —`rotate_y` y no
	# `rotate_object_local`—: si fuera local, después del primer giro el eje vertical del objeto
	# ya no es el vertical de la pantalla y el mouse deja de hacer lo que se ve.
	_examinando.rotate_y(-relativo.x * ReglasDelJugador.SENSIBILIDAD_DEL_MOUSE)
	_examinando.rotate_x(-relativo.y * ReglasDelJugador.SENSIBILIDAD_DEL_MOUSE)
