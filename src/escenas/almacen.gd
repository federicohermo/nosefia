## El cableado de la noche: le da la partida al ciclo y ata sus señales al HUD.
##
## **No decide nada, y eso se puede verificar sin leerlo**: no tiene una sola línea que empiece
## con una condición. Cuáles son las obligatorias, cuánto dura el turno, cuántas noches dura la
## partida, cuántos apercibimientos suma cada banda y cómo se lee un tiempo son todas preguntas
## de `dominio/`, que es donde tienen test.
##
## **Y perdió responsabilidades en vez de ganarlas.** Antes armaba el turno y llevaba el puntaje
## del empleado adentro de la escena, o sea que los dos morían al cerrarla y la regla del
## despido no se alcanzaba jugando. Las dos cosas se fueron a `Partida`, que se ejerce sin
## levantar nada. Acá quedó lo único que necesita la escena delante: conectar y pintar.
extends Node3D

@export var _hud: Hud
@export var _reloj: RelojDelTurno
@export var _ciclo: CicloDeJornadas
@export var _pantalla: PantallaDeCierre

## La partida es de la escena y no del ciclo porque también la mira el HUD: el ciclo publica lo
## que pasó, y quien quiera un número lo pide acá.
var _partida := Partida.nueva()


## Los tres carteles se pintan acá antes de conectar nada, y no con un `text` escrito en
## `hud.tscn`: una copia del texto en la escena es una copia de los números que lleva adentro
## —cuántas obligatorias hay y a cuántos apercibimientos echan—, y el de apercibimientos se
## quedaría en pantalla la jornada entera, porque hasta el cierre nadie lo vuelve a escribir.
func _ready() -> void:
	_hud.declarar_obligatorias(Apertura.cantidad_de_obligatorias())
	_hud.mostrar_tiempo(Reglas.DURACION_DEL_TURNO)
	_hud.mostrar_apercibimientos(_partida.apercibimientos())
	_reloj.tiempo_consumido.connect(_hud.mostrar_tiempo)
	_reloj.tarea_completada.connect(_hud.mostrar_tareas)
	_ciclo.jornada_cerrada.connect(_al_cerrar_la_jornada)
	# La placa es quien abre la noche siguiente, y por eso el ciclo no reabre solo: entre una
	# jornada y la otra hay algo que leer. Se conecta derecho porque acá no hay nada que decidir.
	_pantalla.cierre_despachado.connect(_ciclo.abrir_la_jornada)
	_ciclo.arrancar(_partida, _reloj)


## La jornada cerrada ya quedó anotada en la partida cuando esta señal llega: acá sólo se le
## pasan a la pantalla los números que la partida contesta.
##
## Las obligatorias salen de la partida y no de una lista propia: son **las mismas instancias**
## que el turno estuvo contando toda la noche, así que el parte lee el estado de verdad y no una
## copia que nadie completó.
func _al_cerrar_la_jornada(jornada: int, cumplidas: int) -> void:
	_hud.mostrar_tareas(cumplidas)
	_hud.mostrar_apercibimientos(_partida.apercibimientos())
	_pantalla.mostrar(
		ParteDeCierre.new(jornada, _partida.obligatorias(), _partida.apercibimientos())
	)
