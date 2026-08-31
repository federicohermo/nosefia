## Los valores fijos del controlador del jugador.
##
## Es un archivo aparte de `reglas.gd` a propósito, y no una duplicación: aquél tiene el balance
## de la tensión aritmética del turno —cuánto dura, cuánto cuesta cada tarea— y se toca
## discutiendo diseño; éstos son el tacto del controlador y se tocan probando el movimiento.
## La convención del repo pide que un valor fijo viva una sola vez en *un* archivo de
## `dominio/`, no en *el* archivo. Entre los dos no hay una sola constante repetida.
class_name ReglasDelJugador
extends RefCounted

## Metros por segundo. Un almacén se cruza caminando, no corriendo: la tensión del juego es el
## tiempo del turno, y una velocidad alta la afloja sin que nadie lo decida.
const VELOCIDAD_DE_CAMINATA := 3.5

## Radianes por píxel. La unidad no es un detalle: es lo que permite afirmar «100 píxeles son
## un radián» sin una conversión escondida en el medio.
const SENSIBILIDAD_DEL_MOUSE := 0.003

## Metros, medidos desde el origen del `CharacterBody3D` que está apoyado en el piso.
const ALTURA_DE_LA_CAMARA := 1.7

## Radianes. Los dos encierran al cero y ninguno llega a PI/2: pasarse de ahí da vuelta la
## cámara, y eso no es un límite de gusto sino de diseño.
const PITCH_MINIMO := -1.4
const PITCH_MAXIMO := 1.4

## Metros de alcance del rayo de la mira. Mayor que 1,2 porque el spec 006 suelta lo que se
## lleva a esa distancia y afirma que se lo puede volver a mirar: un alcance menor deja al
## jugador soltando cosas que ya no puede agarrar.
const ALCANCE_DE_LA_MIRA := 2.5

## El contrato de «se puede interactuar con esto» ES este grupo de Godot, y vive acá por lo que
## permite: `dominio/` declara un `String` y no conoce a nadie, y un nodo de `escenas/` cumple
## el contrato agregándose al grupo en su `.tscn`, sin heredar nada. Las otras dos formas se
## descartaron midiendo, y está en el `research.md` del spec 004.
const GRUPO_INTERACTUABLE := "interactuable"

## Los nombres de las cuatro acciones del `InputMap`. Tienen que coincidir letra por letra con
## la sección `[input]` de `project.godot`, y el test de `jugador.tscn` afirma justamente eso:
## es la única forma de que ese par de `String` no se separe en silencio.
const ACCION_ADELANTE := "mover_adelante"
const ACCION_ATRAS := "mover_atras"
const ACCION_IZQUIERDA := "mover_izquierda"
const ACCION_DERECHA := "mover_derecha"
