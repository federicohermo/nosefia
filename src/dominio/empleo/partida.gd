## Lo que dura más que una noche: qué jornada va, el legajo que se arrastra y cómo termina todo.
##
## **Es la pieza que hace jugable la regla del 002.** Hasta acá el legajo vivía adentro del
## script de la escena y moría con ella, así que `despedido()` no podía devolver `true` jugando:
## la regla estaba en verde en los tests y muerta en la build. Con la partida el mismo legajo
## cruza las cinco jornadas y el despido se alcanza.
##
## **Va en `dominio/` y no en un autoload**, y está medido por qué: el gate de tests no mira
## `escenas/`, así que «qué jornada va» escrito ahí nace sin test; y un autoload es peor, porque
## el gate de capas no puede verlo. Este spec no agrega el primero.
##
## Abre y cierra jornadas, pero **no las hace correr**: el tiempo lo trae `sistemas/` y entra
## por `cerrar_la_jornada()` ya convertido en cuántas tareas se cumplieron.
class_name Partida
extends RefCounted

## Los tres estados en los que puede estar una partida. Es un conjunto cerrado y por eso es un
## `enum`: un `String` suelto dejaría al `if` del menú sin entrar nunca, sin decir una palabra.
enum Final { EN_CURSO, CONTRATO_CUMPLIDO, DESPEDIDO }

var _legajo: Legajo
var _jornada: int = ReglasDeLaPartida.PRIMERA_JORNADA
var _obligatorias: Array[Tarea] = []
var _jornada_abierta: bool = false
var _final: Final = Final.EN_CURSO


## La partida del primer día: legajo limpio y la primera jornada por abrir.
##
## El constructor recibe el legajo en vez de armarlo para que el 019 pueda restaurar uno que
## viene de disco sin abrirle una segunda puerta a esta clase.
static func nueva() -> Partida:
	return Partida.new(Legajo.new())


func _init(legajo: Legajo) -> void:
	_legajo = legajo


## El legajo que la partida recibió, **la misma instancia** y no una copia. Con una copia, un
## legajo restaurado acumularía sobre otro objeto y la historia guardada no despediría a nadie.
func legajo() -> Legajo:
	return _legajo


## Cuántos apercibimientos lleva encima, para quien sólo quiera pintarlos.
##
## Existe para que el cableado de la escena no tenga que encadenar dos llamadas hasta el legajo:
## lo que la pantalla necesita es el número, no la pieza que lo lleva.
func apercibimientos() -> int:
	return _legajo.apercibimientos()


func jornada() -> int:
	return _jornada


func final() -> Final:
	return _final


func terminada() -> bool:
	return _final != Final.EN_CURSO


## Si la noche en curso es la última que el contrato pide.
##
## La cuenta sale de las dos constantes y nunca de un número escrito acá: la partida numera
## desde `PRIMERA_JORNADA`, así que la última es esa más las que faltan.
func es_la_ultima_jornada() -> bool:
	var ultima := ReglasDeLaPartida.PRIMERA_JORNADA + ReglasDeLaPartida.JORNADAS_DE_LA_PARTIDA - 1
	return _jornada == ultima


## Las obligatorias de la jornada abierta, para que quien la haga correr cuente contra las
## mismas instancias que el turno está contando.
func obligatorias() -> Array[Tarea]:
	return _obligatorias


## Abre la noche y entrega su turno.
##
## **Las obligatorias se piden de nuevo en cada jornada, y ésa es la razón de ser de esta
## función.** Reusar la lista de ayer arrancaría la noche siguiente con las tareas ya
## completadas: la jornada empezaría ganada, sin un solo error y sin un solo rojo.
##
## Sobre una partida terminada no abre y devuelve `null`, por el mismo motivo que el guard de
## `cerrar_la_jornada()`: la puerta es pública y el 017 la va a tocar desde una pantalla. Sin
## esto, una noche jugada después del despido le pasa una banda al legajo, y una impecable lo
## reinicia a cero: el contador de jornadas avanza sobre una partida que ya terminó y el final
## queda contradiciendo al legajo, sin un solo error.
func abrir_la_jornada() -> Turno:
	if terminada():
		return null
	_obligatorias = Apertura.obligatorias()
	_jornada_abierta = true
	return Apertura.turno_de_la_jornada(_obligatorias)


## Anota la noche y avanza, o termina la partida.
##
## El guard de `_jornada_abierta` es lo que hace que la puerta sea idempotente: es pública, y el
## 017 la va a tocar desde una pantalla. Sin él, un segundo cierre anota una jornada que nadie
## jugó, con la banda que le toque.
##
## **El despido se pregunta antes que el contrato cumplido**, y no es un detalle de orden: la
## última noche puede cerrar mal justo cuando el legajo llega al tope, y ahí felicitar a alguien
## recién echado sería la lectura equivocada de las dos condiciones a la vez.
func cerrar_la_jornada(cumplidas: int) -> void:
	if not _jornada_abierta:
		return
	_jornada_abierta = false
	_legajo.registrar(cumplidas, _obligatorias.size())
	if _legajo.despedido():
		_final = Final.DESPEDIDO
		return
	if es_la_ultima_jornada():
		_final = Final.CONTRATO_CUMPLIDO
		return
	_jornada += 1
