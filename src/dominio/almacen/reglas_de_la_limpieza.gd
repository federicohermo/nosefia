## Los valores fijos de limpiar el local: cuántas pasadas lleva una mancha, cuán lejos están una
## de otra y con qué se limpia.
##
## Es un archivo aparte de `reglas.gd` por el mismo criterio que separa a los otros `reglas_de_*`
## de esta carpeta: no es de qué trata el número, es quién lo toca y probando qué. `reglas.gd` se
## toca discutiendo cuánto dura la noche; esto, probando si limpiar obliga a recorrer.
class_name ReglasDeLaLimpieza
extends RefCounted

## Cuántas veces hay que pasar el trapeador por una mancha.
##
## **El piso es 2, y el invariante importa más que el número**: con una sola pasada la mancha se
## limpiaría en el instante en que el jugador llega, y limpiar volvería a ser un clic — que es
## exactamente lo que no compite contra investigar, porque no hay nada que repartir.
##
## Tres es un primer valor. Es un `int` que baja de a uno y **no una barra que se llena**: la
## barra pide mantener apretado, y mantener apretado no se puede dejar por la mitad y retomar.
const PASADAS_POR_MANCHA := 3

## A cuánto están las manchas una de otra, y del trapeador, en metros.
##
## **Tiene que ser estrictamente mayor que `ReglasDelJugador.ALCANCE_DE_LA_MIRA`**, y ahí está el
## término que esta tarea aporta a la resta del turno: si fuera menor, desde una mancha se podría
## enfocar la siguiente y los tres tramos de caminata dejarían de existir sin que nada lo dijera.
##
## Es un mínimo y no la distancia exacta: `almacen.tscn` las pone más lejos, y hay un caso que
## mide las posiciones de verdad para que el recorrido exista fuera de la prosa.
const DISTANCIA_MINIMA_ENTRE_MANCHAS := 4.0

## El `id` del objeto con el que se limpia. Es el mismo `StringName` que declara `trapeador.tres`,
## y hay un caso que afirma que coinciden: es la única forma de que ese par no se separe en
## silencio, porque un `id` que no coincide no rompe nada — el piso simplemente no se limpia
## nunca.
const ID_DEL_TRAPEADOR := &"trapeador"
