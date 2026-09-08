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

## El jugador no declara un `class_name` —es cáscara, como este archivo—, así que el `@export`
## de abajo no lo puede nombrar sin traerlo por `preload`. Es la forma que el repo ya usa.
const Jugador := preload("res://src/escenas/jugador.gd")

@export var _hud: Hud
@export var _reloj: RelojDelTurno
@export var _ciclo: CicloDeJornadas
@export var _pantalla: PantallaDeCierre
@export var _jugador: Jugador

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
	# El marcador de obligatorias no se reinicia solo: `mostrar_tareas()` se vuelve a llamar
	# recién cuando el jugador completa una, así que sin esto la noche 2 arranca mostrando las
	# que se cumplieron en la 1 hasta que se cumpla la primera de la 2.
	_ciclo.jornada_abierta.connect(_al_abrir_la_jornada)
	# La placa es quien abre la noche siguiente, y por eso el ciclo no reabre solo: entre una
	# jornada y la otra hay algo que leer.
	_pantalla.cierre_despachado.connect(_al_despachar_la_placa)
	_ciclo.arrancar(_partida, _reloj)


## Cada noche arranca con el marcador en cero, y quien lo dice es la apertura de la jornada y no
## el cierre de la anterior: entre las dos hay una placa que el jugador tarda lo que quiera en
## despachar, y el conteo de ayer no puede quedar colgado ahí.
func _al_abrir_la_jornada(_jornada: int) -> void:
	_hud.declarar_obligatorias(Apertura.cantidad_de_obligatorias())


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
	# Sin esto la placa es inalcanzable jugando: el jugador clava el puntero en el centro cada
	# cuadro y el botón «Seguir» cae más abajo, así que no se puede clickear nunca y la jornada 2
	# no existe en la build. La suspensión suelta el cursor sola, porque el modo se recalcula a
	# partir del estado del control.
	_jugador.suspender()


## El orden importa y por eso hay un handler en vez de conectar la señal derecho al ciclo: si el
## jugador se reanudara después de abrir la jornada, el cuadro del medio correría con el control
## todavía suspendido. Acá no se decide nada — son dos llamadas, siempre las dos.
func _al_despachar_la_placa() -> void:
	_jugador.reanudar()
	_ciclo.abrir_la_jornada()
