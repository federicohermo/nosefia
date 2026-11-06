## El wifi del local: lo que el corte de luz le hace al router y lo que el jugador le devuelve.
##
## **El router sigue al corte y no decide cuándo se corta.** El corte llega de
## `AnomaliasDeLaJornada`; acá queda qué le pasa al router y qué muestran sus luces. Un corte
## restaurado no arregla el router: sólo apagarlo y prenderlo devuelve el wifi.
##
## **Vive sólo en la jornada en memoria.** Toda apertura lo deja con wifi, como el corte.
class_name WifiDelLocal
extends RefCounted

## Cada cambio de estado, y sólo cuando cambia.
signal estado_cambiado(estado: Estado)

## El jugador apagó el router descompuesto, o prendió el apagado. El corte y la apertura de la
## jornada cambian el estado pero no son un gesto suyo, y no avisan por acá.
signal router_apagado
signal router_prendido

## `SIN_ENERGIA` es el router con el corte cortado; `DESCOMPUESTO`, con la luz de vuelta y sin
## arreglar; `APAGADO`, el que el jugador apagó para arreglarlo.
enum Estado { CON_WIFI, SIN_ENERGIA, APAGADO, DESCOMPUESTO }
enum Luces { VERDES, APAGADAS, ROJAS }

var _estado: Estado = Estado.CON_WIFI


func estado() -> Estado:
	return _estado


func hay_wifi() -> bool:
	return _estado == Estado.CON_WIFI


func luces() -> Luces:
	match _estado:
		Estado.CON_WIFI:
			return Luces.VERDES
		Estado.DESCOMPUESTO:
			return Luces.ROJAS
	return Luces.APAGADAS


## Toda jornada abre con wifi.
func abrir_jornada() -> void:
	_poner(Estado.CON_WIFI)


## El corte que corresponde ahora. Repetirlo no cambia nada. Sólo un router sin energía se
## descompone al volver la luz: uno apagado o ya arreglado conserva lo que tiene.
func seguir_al_corte(corte: AnomaliasDeLaJornada.Corte) -> void:
	match corte:
		AnomaliasDeLaJornada.Corte.CORTADO:
			_poner(Estado.SIN_ENERGIA)
		AnomaliasDeLaJornada.Corte.RESTAURADO:
			if _estado == Estado.SIN_ENERGIA:
				_poner(Estado.DESCOMPUESTO)


## El clic izquierdo sobre el router: apaga el descompuesto y prende el apagado. En cualquier otro
## estado no hace nada.
func accionar() -> void:
	match _estado:
		Estado.DESCOMPUESTO:
			_poner(Estado.APAGADO)
			router_apagado.emit()
		Estado.APAGADO:
			_poner(Estado.CON_WIFI)
			router_prendido.emit()


func _poner(nuevo: Estado) -> void:
	if nuevo == _estado:
		return
	_estado = nuevo
	estado_cambiado.emit(nuevo)
