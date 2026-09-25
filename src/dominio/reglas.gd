## Los valores fijos del juego, en un solo lugar.
##
## Viven acá y no adentro de `turno.gd` porque son los números que se van a tocar todas las
## semanas balanceando, y un valor que vive al lado de la lógica que lo usa termina copiado en
## el segundo lugar que lo necesita. Dos copias de un número no son dos números: son un bug
## esperando a que alguien cambie una.
##
## Son un **primer valor**, no una medición: el GDD no dice cuánto dura un turno. Se ajustan
## jugando, y ajustarlos no debe obligar a tocar `turno.gd`.
class_name Reglas
extends RefCounted

## La noche entera, en segundos de ficción. El reloj de la escena escala esto a los minutos
## reales de sesión, así que cambiarlo cambia también cuánto dura jugar una noche.
const DURACION_DEL_TURNO := 43200.0

## A qué hora del día abre el turno. El reloj de mesa le suma lo transcurrido para leer la hora,
## así que la de cierre no se escribe: sale de la apertura más la duración.
const HORA_DE_APERTURA := 20

## A los cuatro apercibimientos lo echan, y se compara con `>=` y no con `==`: una jornada grave
## sube de a dos, así que el contador puede saltar de 3 a 5 sin pisar el 4.
##
## El 4 es una decisión de balance y no la lectura literal de la fuente: el GDD dice «más de dos
## días seguidos» y el formulario de la primera entrega dice «tres jornadas consecutivas», o sea
## que las dos piden **tres** jornadas graves. El prototipo elige **dos**, a propósito, porque
## con 4 los tres caminos al despido quedan a la misma distancia y la progresión se lee de un
## vistazo: dos jornadas graves despiden, una grave más dos avisos despiden, y cuatro avisos
## despiden. Queda escrito acá para que nadie lo «arregle» de vuelta.
const APERCIBIMIENTOS_HASTA_EL_DESPIDO := 4

const APERCIBIMIENTOS_POR_AVISO := 1

## En qué noche falla el reloj de mesa del local: desde la mitad de ese turno hasta su cierre, y
## la noche siguiente vuelve a andar.
##
## El GDD dice que deja de funcionar «a mitad de una de las jornadas» y no cuál: la tercera de
## cinco es una decisión de balance, la del medio de la partida. Cae adentro a propósito: una
## jornada posterior a la última dejaría la regla escrita y muerta, y eso lo caza
## `reglas_test.gd`.
##
## Vive acá y no en `reglas_de_la_partida.gd` porque no es cuánto dura la partida sino un número
## de balance más, del mismo tipo que los apercibimientos: `Reglas` ya cruza jornadas.
const JORNADA_EN_QUE_FALLA_EL_RELOJ := 3

## Vale el doble que un aviso, y eso es lo que hace que las tres bandas pesen distinto también
## sobre el despido: a la banda grave le alcanza con una jornada menos.
const APERCIBIMIENTOS_POR_BANDA_GRAVE := 2
