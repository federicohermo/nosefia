## Los valores fijos de reponer: cuánto trae la caja de cada producto.
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
