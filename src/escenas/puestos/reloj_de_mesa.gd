## El display del reloj de pared: pregunta y pinta.
##
## **No decide qué hora es**: es una regla del juego y vive en `dominio/`, donde tiene test.
## Acá queda el label sobre el vidrio del reloj del modelo, que es «cómo se ve».
##
## La jornada llega por `declarar_jornada()` y no se cuenta acá: quien lleva la cuenta es la
## partida, y una segunda cuenta en la escena sería la misma regla en dos lugares.
extends Label3D

var _jornada: int = RelojDeMesa.JORNADA_SIN_DECLARAR


## Qué noche es. Se declara al abrir la jornada y el reloj la guarda: es lo que decide si es
## la noche del corte.
func declarar_jornada(jornada: int) -> void:
	_jornada = jornada


func mostrar_tiempo(restante: float) -> void:
	text = RelojDeMesa.lectura(_jornada, restante)
