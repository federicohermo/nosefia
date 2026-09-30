## Los valores fijos de reponer: cuánto trae la caja de cada producto, y cómo se ven los
## casilleros que esperan una unidad.
##
## Es un archivo aparte de `reglas.gd` y de `reglas_de_los_objetos.gd` por el mismo criterio que
## separa a esos dos: no es de qué trata el número, es quién lo toca y probando qué. `reglas.gd`
## se toca discutiendo el balance de la noche; esto, probando si reponer se puede terminar antes
## de que se acabe la mercadería.
##
## **El cupo del estante NO vive acá**, y es la decisión que evita el mismo número escrito dos
## veces: cuántas unidades pide la góndola de cada producto son los casilleros de su fila de
## adelante, que la escena mide del modelo y le pasa al `Inventario`. Un `CUPO` acá sería una
## copia que se desincroniza sin que ningún gate lo diga. **Lo que falta en cada jornada
## tampoco**: es un dato de la jornada, y vive en `Apertura`.
class_name ReglasDelEstante
extends RefCounted

## Cuántas unidades trae la caja del depósito de cada producto: la ficha «8. Tarea: Reposición»
## dice que una caja contiene hasta 8, y que cada jornada vuelve a tener 8.
##
## Es a la vez con cuánto arranca el depósito de cada producto y el tope de lo que a un producto
## le puede faltar en una jornada: un faltante más grande que la caja deja una noche en la que
## reponer no se puede terminar, y eso lo afirma el test contra cada jornada. Es también el
## tope de lo que entra en una caja, el mismo número y no otro.
##
## Lo que se vende sale de la misma caja: lo que queda después de reponer es lo que hay para
## atender, así que bajar este número aprieta las dos cosas a la vez.
const UNIDADES_POR_CAJA := 8

## **Cómo se ven los casilleros vacíos con una unidad en la mano** (BR-PLY-022, BR-PLY-023). Son
## primeros valores y se ajustan jugando (OQ-PLY-002): viven acá, juntos, y la escena y su shader
## los leen de acá. Una copia en el shader sería el mismo número en dos lugares, y el que se
## ajusta jugando es el que no manda.

## La opacidad del casillero vacío quieto, el envase en blanco y negro. Es también el piso del
## titileo del que apunta la mira: el apuntado nunca se ve menos que los demás.
const OPACIDAD_DEL_CASILLERO := 0.25

## La opacidad del techo del titileo del casillero apuntado: la entera, el envase como si ya
## estuviera puesto.
const OPACIDAD_DEL_APUNTADO := 1.0

## Cuánto tarda un ciclo del titileo, en segundos. Más rápido se lee como un parpadeo roto, y más
## lento no alcanza a verse mientras el jugador pasea la mira por el estante.
const PERIODO_DEL_TITILEO := 1.2

## Cuánto brilla de más el casillero apuntado, sobre su propio color: con cero, en su punto más
## opaco se confunde con la unidad de al lado, que ya está puesta.
const EMISION_DEL_CASILLERO := 0.6

## Hasta qué distancia de la vista se ven los casilleros vacíos, en metros. **El primer valor es
## el alcance de la mira**, escrito como referencia y no como copia: un casillero que se ve es uno
## que la mira puede enfocar. Si jugando se lo separa, se lo separa acá.
const ALCANCE_DE_LOS_CASILLEROS := ReglasDelJugador.ALCANCE_DE_LA_MIRA


## Si un casillero a esa distancia de la vista se ve. El borde es de adentro, como el de la mira.
static func al_alcance(distancia: float) -> bool:
	return distancia <= ALCANCE_DE_LOS_CASILLEROS
