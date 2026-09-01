## El cableado de la noche: arma el turno, se lo da al reloj y ata sus señales al HUD.
##
## **No decide nada, y eso se puede verificar sin leerlo**: no tiene una sola línea que empiece
## con una condición, y el spec lo cobra con un `rg`. Cuáles son las obligatorias, cuánto dura el
## turno, cuántos apercibimientos suma cada banda y cómo se lee un tiempo son todas preguntas de
## `dominio/`, que es donde tienen test.
##
## La lista de obligatorias se pide **una sola vez** y se reparte: cada llamada a `Apertura`
## devuelve tareas nuevas, y con dos listas el turno contaría contra unas mientras el resto del
## juego completa las otras — devolviendo `true`, sin error y sin rojo.
extends Node3D

@export var _hud: Hud
@export var _reloj: RelojDelTurno

## Vive en la escena y muere con ella. Persistirlo entre jornadas es de `sistemas/` y está fuera
## de alcance acá: en esta build el puntaje sólo puede leer lo que sumó esta noche.
var _legajo := Legajo.new()

var _obligatorias := Apertura.cantidad_de_obligatorias()


## Los tres carteles se pintan acá antes de conectar nada, y no con un `text` escrito en
## `hud.tscn`: una copia del texto en la escena es una copia de los números que lleva adentro
## —cuántas obligatorias hay y a cuántos apercibimientos echan—, y el de apercibimientos se
## quedaría en pantalla la jornada entera, porque hasta el cierre nadie lo vuelve a escribir.
func _ready() -> void:
	var obligatorias := Apertura.obligatorias()
	var turno := Apertura.turno_de_la_jornada(obligatorias)
	_hud.declarar_obligatorias(_obligatorias)
	_hud.mostrar_tiempo(turno.tiempo_restante())
	_hud.mostrar_apercibimientos(_legajo.apercibimientos())
	_reloj.tiempo_consumido.connect(_hud.mostrar_tiempo)
	_reloj.tarea_completada.connect(_hud.mostrar_tareas)
	_reloj.turno_cerrado.connect(_al_cerrar_el_turno)
	_reloj.arrancar(turno, obligatorias)


## La jornada cerrada se anota en el legajo, que es quien traduce las tareas cumplidas a la banda
## y la banda a apercibimientos. Acá sólo se le pasa el número resultante a la pantalla.
func _al_cerrar_el_turno(cumplidas: int) -> void:
	_legajo.registrar(cumplidas, _obligatorias)
	_hud.mostrar_tareas(cumplidas)
	_hud.mostrar_apercibimientos(_legajo.apercibimientos())
