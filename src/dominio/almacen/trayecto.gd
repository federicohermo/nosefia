## La aritmética del trayecto: cuántos viajes hacen falta, cuánto se tarda en el mejor caso y si
## un punto cae adentro de una zona.
##
## **La posición entra como parámetro**, igual que el tiempo en el 001. El dominio no puede saber
## de física —no tiene árbol, no tiene `Node3D`, no puede preguntar dónde está nada—, así que
## recibe la distancia ya medida y contesta. Quien mide es la escena, que es la única con árbol
## vivo; el `Area3D` del descarte es un **reflejo** del radio y no su fuente.
##
## Los tres métodos son `static` y no leen un solo campo: se ejercen sin una escena y sin una
## jornada. Lo único que este archivo no recibe es cuántas manos hay —`segundos_minimos()` se lo
## pide a `ReglasDeLosObjetos`, que es de al lado—, y eso vale la pena decirlo porque es lo que
## hace que ese método no se pueda ejercer con números del todo inventados.
class_name Trayecto
extends RefCounted


## Cuántos viajes hacen falta para mover `bolsas` con `manos` manos.
##
## Redondea para arriba: con cuatro bolsas y tres manos son dos viajes, no uno y pico. Cero manos
## contesta cero viajes en vez de dividir por cero — no es un caso del juego, es el que evita que
## un balance mal escrito se lleve puesta la corrida entera.
static func viajes(bolsas: int, manos: int) -> int:
	if manos <= 0 or bolsas <= 0:
		return 0
	return ceili(float(bolsas) / float(manos))


## Cuántos segundos **reales** lleva la tarea en el mejor caso posible.
##
## Es la ida y la vuelta de cada viaje, en línea recta y a velocidad constante: un piso, no una
## estimación. El camino real es más largo porque nadie camina en línea recta por un local a
## oscuras que no conoce, y por eso el cruce contra `Reglas.SEGUNDOS_DE_TRAYECTO_ESTIMADOS` es un
## `>=` y no una igualdad.
##
## La velocidad entra por parámetro y no se le pide a `ReglasDelJugador`. Las manos no: salen de
## `ReglasDeLosObjetos.MANOS_DISPONIBLES`, porque cuántas manos tiene el empleado es del empleado
## y no del viaje. **La consecuencia es que el resultado de este método se mueve si el balance
## cambia esa constante**, aunque los tres argumentos sean inventados.
static func segundos_minimos(distancia: float, velocidad: float, bolsas: int) -> float:
	if velocidad <= 0.0:
		return 0.0
	return 2.0 * distancia * viajes(bolsas, ReglasDeLosObjetos.MANOS_DISPONIBLES) / velocidad


## Si un punto a esa distancia del centro cae adentro de la zona.
##
## **El borde entra**: es un `<=`. Con un `<` la bolsa apoyada justo en el límite no contaría, y
## el jugador no tendría cómo distinguir eso de haberla dejado mal.
static func dentro_del_descarte(distancia: float, radio: float) -> bool:
	return distancia <= radio
