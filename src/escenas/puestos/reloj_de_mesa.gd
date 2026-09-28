## El display del reloj de mesa: pregunta y pinta.
##
## **No decide cuándo se ve la hora ni qué hora es**: las dos son reglas del juego y viven en
## `dominio/`, donde tienen test. Acá queda el label sobre el vidrio del reloj del modelo, que
## es «cómo se ve». Sin texto, el vidrio se ve oscuro: ése es el reloj apagado.
##
## La jornada llega por `declarar_jornada()` y no se cuenta acá: quien lleva la cuenta es la
## partida, y una segunda cuenta en la escena sería la misma regla en dos lugares.
extends Label3D

var _jornada: int = RelojDeMesa.JORNADA_SIN_DECLARAR


## Qué noche es. Se declara al abrir la jornada y el reloj la guarda: es lo que decide si a esta
## altura de la partida el display todavía anda.
func declarar_jornada(jornada: int) -> void:
	_jornada = jornada


func mostrar_tiempo(restante: float) -> void:
	text = RelojDeMesa.lectura(_jornada, restante)
