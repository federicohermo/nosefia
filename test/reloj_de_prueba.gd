## Avanza el reloj del turno en tiempo de ficción, con el ritmo que el reloj recibió al arrancar.
##
## Un test que avanza en segundos reales se rompe cuando cambia el ritmo de una jornada, aunque no
## hable de ese ritmo. El ritmo se lee del reloj y no de la jornada, para seguir al que puso
## `CicloDeJornadas`.
extends RefCounted


## Con cero entrega un cuadro sin consumir tiempo, como el `avanzar(0.0)` del reloj.
static func avanzar_turno(reloj: RelojDelTurno, segundos_de_turno: float) -> void:
	if segundos_de_turno < 0.0:
		return
	reloj.avanzar(segundos_de_turno / float(reloj.get("_ritmo")))


## La hora se cuenta desde la apertura: una anterior a `Reglas.HORA_DE_APERTURA` cae en la
## madrugada. Una hora que ya pasó no retrocede el reloj.
static func avanzar_hasta(reloj: RelojDelTurno, hora: Vector2i) -> void:
	var turno: Turno = reloj.get("_turno")
	var transcurrido := Reglas.DURACION_DEL_TURNO - turno.tiempo_restante()
	avanzar_turno(reloj, desde_la_apertura(hora) - transcurrido)


static func desde_la_apertura(hora: Vector2i) -> float:
	var horas := posmod(hora.x - Reglas.HORA_DE_APERTURA, Marcador.HORAS_POR_DIA)
	return float((horas * Marcador.MINUTOS_POR_HORA + hora.y) * Marcador.SEGUNDOS_POR_MINUTO)
