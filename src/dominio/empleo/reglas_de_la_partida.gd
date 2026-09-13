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

## Cinco noches, del GDD.
##
## Es también lo que vuelve alcanzable la regla más cara del juego: el camino más corto al
## despido encadena bandas graves, que suben de a dos, así que una partida más corta que esa
## cuenta dejaría al despido escrito y muerto en la build. La desigualdad se afirma contra las
## constantes del 002 en `reglas_de_la_partida_test.gd`, nunca contra este número.
const JORNADAS_DE_LA_PARTIDA := 5

## La primera noche se numera desde uno y no desde cero porque es el número que el jugador lee:
## la pantalla del 017 dice «jornada 1 de 5». Un índice desde cero obligaría a sumar uno en cada
## lugar que lo muestre, que es la copia que este archivo existe para evitar.
const PRIMERA_JORNADA := 1
