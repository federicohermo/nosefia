# Constitución

Principios no negociables. Cambiar uno pide un ADR en [`decisions/`](./decisions/).

## El contrato manda

Un cambio de comportamiento cambia su spec en el mismo PR. Cada criterio de aceptación tiene un
test que lo nombra. Si el código no cumple un criterio, se corrige el código. El spec nunca se
ajusta para que coincida con el código.

## Una sola dirección de dependencia

`dominio/` ← `sistemas/` ← `ui/` ← `escenas/`. Una capa referencia a las anteriores y a ninguna
otra. Nombrar un `class_name` de otra capa cuenta como referencia.

## El dominio es puro

`dominio/` no extiende `Node`, no levanta una escena, no lee el reloj del motor y no escribe al
disco. Lo que no se puede ejercer sin una escena no es una regla del juego: es presentación.

## El tiempo y el azar entran por parámetro

Ninguna regla lee el reloj del motor ni sortea adentro. Un dominio que lo hace no se puede
probar, y un prototipo cuya tensión es aritmética esconde justo lo que hay que mirar.

## Un valor fijo vive una sola vez

En un archivo de `src/dominio/`. Dos copias de un número no son dos números: son un bug esperando
a que alguien cambie una.

## Un conjunto cerrado es un `enum`

Nunca un `String` suelto. `"limpar"` no rompe nada: el `if` no entra nunca y el motor no dice una
palabra.

## El veredicto sale del código de salida

Nunca de un grep de la salida. Y un nodo salteado no es un nodo verde: cada salteo declara qué no
miró y hasta cuándo vale.

## Una corrida no deja trabajo escrito para después

Lo que encuentra, lo descarga. Un issue registra el plan de una entrega, nunca el resto de una
corrida. La doctrina entera está en `.claude/skills/to-spec/sin-deuda.md`.
