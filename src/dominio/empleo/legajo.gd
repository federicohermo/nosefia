## El legajo del empleado: lo único que cruza de una jornada a la siguiente.
##
## Es una pieza aparte del turno a propósito. El turno es de **una** noche y no sabe que hubo
## otras; metiendo los apercibimientos adentro, cada test de esta regla tendría que construir
## turnos completos con sus tareas — y la regla no tiene nada que ver con el tiempo.
##
## No se llama «racha», y el nombre viejo era el problema: una racha cuenta jornadas
## consecutivas, y esto es un puntaje que sube según cuál haya sido la banda del cierre.
##
## Ningún número de balance está escrito acá: el umbral del despido y los dos pesos salen de
## `reglas.gd`, y el corte entre las bandas ni siquiera se lee — se pide la banda ya decidida.
class_name Legajo
extends RefCounted

var _medios: int = 0
var _apercibimientos_de_la_prueba: int = 0
var _ultima_de_la_prueba_completa := false


## Restaura la deuda exacta, incluida la mitad de un apercibimiento.
static func con_medios(medios: int) -> Legajo:
	var legajo := Legajo.new()
	legajo._medios = medios
	return legajo


## Restaura el resultado de una prueba ya cerrada, que viene de un guardado.
func restaurar_la_prueba(apercibimientos: int, completa: bool) -> void:
	_apercibimientos_de_la_prueba = apercibimientos
	_ultima_de_la_prueba_completa = completa


func medios() -> int:
	return _medios


## Cuántos apercibimientos sumó la prueba al cerrar su última noche, antes de que las jornadas
## completas arranquen de nuevo. Vale cero hasta ese cierre.
func apercibimientos_de_la_prueba() -> int:
	return _apercibimientos_de_la_prueba


## Si esa última noche cerró con todas sus obligatorias cumplidas.
func ultima_de_la_prueba_completa() -> bool:
	return _ultima_de_la_prueba_completa


## Anota el cierre de una jornada.
##
## La banda se la **pide** a `Consecuencias` en lugar de recalcularla. Un corte propio acá
## pasaría todos los tests de este archivo y dejaría el criterio escrito en dos lugares: el día
## que el aviso se moviera un escalón para abajo, `consecuencia.gd` cambiaría y el legajo
## seguiría cortando donde cortaba, sin que ningún gate lo note.
func registrar(cumplidas: int, obligatorias: int, llamados: int = 0) -> void:
	var puntos: int = 0
	match Consecuencias.consecuencia_de(cumplidas, obligatorias):
		Consecuencias.Banda.NINGUNA:
			pass
		Consecuencias.Banda.AVISO:
			puntos = Reglas.APERCIBIMIENTOS_POR_AVISO
		Consecuencias.Banda.GRAVE:
			puntos = Reglas.APERCIBIMIENTOS_POR_BANDA_GRAVE
	_medios += puntos * Reglas.MEDIOS_POR_APERCIBIMIENTO + llamados * Reglas.MEDIOS_POR_LLAMADO


## Anota una noche de la prueba: cada falla suma lo mismo, sin bandas y sin llamados.
func registrar_prueba(fallas: int) -> void:
	_medios += (
		fallas * Reglas.APERCIBIMIENTOS_POR_FALLA_DE_LA_PRUEBA * Reglas.MEDIOS_POR_APERCIBIMIENTO
	)


## Anota cómo terminó la prueba. Lo llama la partida al cerrar su última noche, con lo que se
## debe a esa altura.
func cerrar_la_prueba(completa: bool) -> void:
	_apercibimientos_de_la_prueba = apercibimientos()
	_ultima_de_la_prueba_completa = completa


## Se pierde llegando al umbral sin haber cumplido entera la última noche. Vale desde que la
## prueba está cerrada.
func perdio_la_prueba() -> bool:
	return _excede_la_prueba() and not _ultima_de_la_prueba_completa


## Lo que se debe se pone a cero, salvo el apercibimiento de quien terminó la prueba excedida.
func empezar_las_jornadas_completas() -> void:
	var arrastre := Reglas.APERCIBIMIENTOS_TRAS_UNA_PRUEBA_EXCEDIDA if _excede_la_prueba() else 0
	_medios = arrastre * Reglas.MEDIOS_POR_APERCIBIMIENTO


@warning_ignore("integer_division")
func apercibimientos() -> int:
	return _medios / Reglas.MEDIOS_POR_APERCIBIMIENTO


## Con `>=` y no con `==`: una jornada grave sube de a dos apercibimientos, así que el contador
## puede pasar de largo el umbral sin pisarlo. Un `==` deja despedir sólo a quien cae justo.
##
## Es el umbral de las jornadas completas: en la prueba el contador lo cruza sin despedir a
## nadie, y quien decide es la partida.
func despedido() -> bool:
	return _medios >= Reglas.APERCIBIMIENTOS_HASTA_EL_DESPIDO * Reglas.MEDIOS_POR_APERCIBIMIENTO


func _excede_la_prueba() -> bool:
	return _apercibimientos_de_la_prueba >= Reglas.APERCIBIMIENTOS_QUE_PIERDEN_LA_PRUEBA
