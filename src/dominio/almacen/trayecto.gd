## La aritmética del trayecto: cuántos viajes hacen falta y si un punto cae adentro de una zona.
##
## **La posición entra como parámetro**, igual que el tiempo en el 001. El dominio no puede saber
## de física —no tiene árbol, no tiene `Node3D`, no puede preguntar dónde está nada—, así que
## recibe la distancia ya medida y contesta. Quien mide es la escena, que es la única con árbol
## vivo; el `Area3D` del descarte es un **reflejo** del radio y no su fuente.
##
## Los dos métodos son `static` y no leen un solo campo: se ejercen sin una escena y sin una
## jornada.
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


## Si un punto a esa distancia del centro cae adentro de la zona.
##
## **El borde entra**: es un `<=`. Con un `<` la bolsa apoyada justo en el límite no contaría, y
## el jugador no tendría cómo distinguir eso de haberla dejado mal.
static func dentro_del_descarte(distancia: float, radio: float) -> bool:
	return distancia <= radio
