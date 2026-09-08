## Una fila de la tabla de sonidos: qué evento del juego suena, con qué señal se dispara, por qué
## bus sale y si va en bucle.
##
## **El `enum` de acá es el único lugar donde los eventos están enumerados.** Agregar un sonido es
## sumar un valor y una fila del `.tres`; ningún sistema lleva una lista propia, y por eso este
## spec no nombra una sola clase de los otros siete — el enlace es **por nombre de señal**, que
## también es dato.
##
## **Un bus mal escrito no da error: cae a `Master` en silencio.** Está medido con un reproductor
## del motor cuyo bus no existe — ningún aviso, el sonido sale por el canal equivocado y nada lo
## dice. Por eso `es_valida()` existe y por eso una fila inválida se rechaza en vez de sonar. El
## nombre de ese nodo no se escribe acá ni en un comentario: un caso verifica que el dominio no lo
## nombre, y no distingue código de prosa.
##
## Es un `Resource` y no un `RefCounted` porque la tabla se edita como archivo: cambiar qué suena
## no toca código.
class_name EntradaSonora
extends Resource

## Los eventos del juego que pueden sonar.
##
## **`tiempo_consumido` del 007 no está, y no es un olvido**: se emite en cada `_process`, así que
## engancharle un sonido sería pedir uno por cuadro. Es la razón por la que esto es un `enum`
## revisable y no «cualquier señal que exista».
enum Evento {
	TAREA_CUMPLIDA,
	TURNO_CERRADO,
	JORNADA_ABIERTA,
	JORNADA_CERRADA,
	OBJETO_AGARRADO,
	OBJETO_SOLTADO,
	AGARRE_RECHAZADO,
	PRODUCTO_COLOCADO,
	PRODUCTO_GUARDADO,
	PASADA_DADA,
	BOLSA_DEPOSITADA,
	COMPUTADORA_ABIERTA,
	TIMBRE_DEL_COMPRADOR,
	AMBIENTE_DEL_LOCAL,
}

## Los cuatro buses del local, **declarados una sola vez en todo el repo**. El layout de buses los
## escribe otra vez porque un `.tres` no puede leer una constante, y hay un caso que compara los
## dos: sin él, un bus renombrado deja su canal sonando por `Master` sin que nada avise.
const BUS_DE_AMBIENTE := "Ambiente"
const BUS_DE_EFECTOS := "Efectos"
const BUS_DE_INTERFAZ := "Interfaz"
const BUS_DE_MUSICA := "Musica"

## El bus al que cae todo lo demás. No es uno de los cuatro: es el destino de los cuatro.
const BUS_MAESTRO := "Master"

const BUSES := [BUS_DE_AMBIENTE, BUS_DE_EFECTOS, BUS_DE_INTERFAZ, BUS_DE_MUSICA]

@export var evento: Evento = Evento.TAREA_CUMPLIDA

## El nombre de la señal que dispara este sonido, o vacío si no lo dispara ninguna.
##
## Es un dato y no código, y ahí está el desacople: el enlazador no nombra una sola clase de los
## otros specs, y si la señal todavía no existe la fila queda sin fuente y se declara.
@export var senal: StringName = &""

@export var bus: String = BUS_DE_EFECTOS

## Si el sonido se repite mientras dura la noche. Los que van en bucle ocupan la voz de ambiente
## y no la ronda: una ronda con un bucle adentro se quedaría sin voces al quinto sonido.
@export var en_bucle: bool = false

## Vacío mientras no haya archivos de audio: elegirlos y mezclarlos está fuera de alcance. Que la
## fila exista igual es lo que permite que agregar el sonido no toque código.
@export var stream: AudioStream = null


func tiene_sonido() -> bool:
	return stream != null


## Si esta fila puede sonar por donde dice.
##
## Sólo mira el bus: un `stream` vacío es un estado normal —el sonido todavía no está elegido— y
## un bus inventado es un bug que no se ve.
func es_valida() -> bool:
	return BUSES.has(bus)


## Si alguna señal la dispara.
func tiene_fuente() -> bool:
	return senal != &""
