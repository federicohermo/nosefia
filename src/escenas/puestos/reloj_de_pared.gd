## El reloj de pared del local: pregunta y pinta.
##
## **No decide cuándo se ve la hora ni cuándo empieza la franja de aviso**: las dos son reglas
## del juego y viven en `dominio/`, donde tienen test. Acá quedan la esfera y los dos colores,
## que son «cómo se ve».
##
## Los colores se mudaron del HUD y no se copiaron: con la hora fuera de la pantalla, este nodo
## es su único cliente. Viven acá por el mismo criterio que vivían allá — el tono es de la
## presentación, y cuándo empieza la franja lo contesta `Marcador`.
##
## La jornada llega por `declarar_jornada()` y no se cuenta acá: quien lleva la cuenta es la
## partida, y una segunda cuenta en la escena sería la misma regla en dos lugares.
extends Label3D

## El tono de siempre y el de la franja final.
const COLOR_TRANQUILO := Color.WHITE
const COLOR_DE_AVISO := Color.RED

var _jornada: int = RelojDePared.JORNADA_SIN_DECLARAR


## Qué noche es. Se declara al abrir la jornada y el reloj la guarda: es lo que decide si a esta
## altura de la partida la esfera todavía anda.
func declarar_jornada(jornada: int) -> void:
	_jornada = jornada


func mostrar_tiempo(restante: float) -> void:
	text = RelojDePared.lectura(_jornada, restante)
	modulate = COLOR_DE_AVISO if Marcador.en_aviso(restante) else COLOR_TRANQUILO
