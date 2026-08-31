## La pantalla del turno: lo que queda, cuántas obligatorias van y cuántos apercibimientos hay.
##
## **Recibe números ya decididos y los pinta.** No formatea nada —eso es `Marcador`—, no sabe qué
## es un umbral, y no conoce al nodo que le manda los números: se conecta por señal desde la
## escena, y por eso acá no aparece el reloj ni por su nombre. Lo verifican tres `rg` del spec,
## que miran el archivo entero y no distinguen código de comentario.
##
## Lo único propio de esta capa son las palabras y los colores. El veredicto del cierre **no** se
## dibuja acá: es de la pantalla de fin de jornada, y tenerlo en los dos lados sería la misma
## banda traducida a palabras en dos archivos que no llevan test obligatorio.
class_name Hud
extends CanvasLayer

const TEXTO_DEL_TIEMPO := "Te quedan %s"
const TEXTO_DE_LAS_TAREAS := "Tareas %s"
const TEXTO_DE_LOS_APERCIBIMIENTOS := "Apercibimientos %d de %d"

## El tono de siempre y el de la franja final. Son «cómo se ve» y por eso viven acá; cuándo
## empieza esa franja es «qué pasa», y eso lo contesta el dominio.
const COLOR_TRANQUILO := Color.WHITE
const COLOR_DE_AVISO := Color.RED

@export var _reloj: Label
@export var _tareas: Label
@export var _apercibimientos: Label

var _obligatorias: int = 0


## Cuántas obligatorias pide la jornada. Se declara una vez al abrir el turno y el HUD la guarda
## para no tener que recibirla en cada actualización.
func declarar_obligatorias(cuantas: int) -> void:
	_obligatorias = cuantas
	mostrar_tareas(0)


func mostrar_tiempo(restante: float) -> void:
	_reloj.text = TEXTO_DEL_TIEMPO % Marcador.reloj(restante)
	_reloj.modulate = COLOR_DE_AVISO if Marcador.en_aviso(restante) else COLOR_TRANQUILO


func mostrar_tareas(cumplidas: int) -> void:
	_tareas.text = TEXTO_DE_LAS_TAREAS % Marcador.tareas(cumplidas, _obligatorias)


## El puntaje del legajo contra el tope que despide.
##
## El tope se lee de `Reglas` y no se escribe acá: es un número de balance, y una copia en la
## pantalla se desincroniza el día que se rebalancee sin que ningún gate lo note.
func mostrar_apercibimientos(cuantos: int) -> void:
	var tope := Reglas.APERCIBIMIENTOS_HASTA_EL_DESPIDO
	_apercibimientos.text = TEXTO_DE_LOS_APERCIBIMIENTOS % [cuantos, tope]
