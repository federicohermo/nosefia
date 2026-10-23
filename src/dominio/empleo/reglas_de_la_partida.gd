## Los dos números de la partida: cuántas noches dura y por cuál se empieza.
##
## **No van en `reglas.gd`**, que es el libro de **una** noche y lo lee el dominio entero: meter
## ahí cuántas jornadas hay le pondría al `Turno` adelante un número que tiene prohibido usar, y
## nada lo impediría. Acá el archivo lo lee sólo quien cuenta jornadas.
##
## Las constantes de apercibimientos sí se quedan donde las puso el 002: ésas las lee el legajo,
## que es de la misma familia que ellas.
class_name ReglasDeLaPartida
extends RefCounted

## Tres noches de introducción y las cinco del GDD.
##
## Es también lo que vuelve alcanzable la regla más cara del juego: el camino más corto al
## despido encadena bandas graves, que suben de a dos, así que una partida más corta que esa
## cuenta dejaría al despido escrito y muerto en la build. La desigualdad se afirma contra las
## constantes del despido en `reglas_de_la_partida_test.gd`, nunca contra este número.
const JORNADAS_DE_LA_PARTIDA := 8

## La primera noche se numera desde uno y no desde cero porque es el número que el jugador lee:
## la pantalla de cierre lo muestra. Un índice desde cero obligaría a sumar uno en cada
## lugar que lo muestre, que es la copia que este archivo existe para evitar.
const PRIMERA_JORNADA := 1

## La primera noche con todas las tareas. Lo que la ficha ata a un número de jornada se cuenta
## desde acá, para que alargar o acortar la introducción no obligue a renumerar cada regla.
const PRIMERA_JORNADA_COMPLETA := 4
