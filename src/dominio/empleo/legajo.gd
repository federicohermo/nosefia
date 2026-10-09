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


## Restaura la deuda exacta, incluida la mitad de un apercibimiento.
static func con_medios(medios: int) -> Legajo:
	var legajo := Legajo.new()
	legajo._medios = medios
	return legajo


func medios() -> int:
	return _medios


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


@warning_ignore("integer_division")
func apercibimientos() -> int:
	return _medios / Reglas.MEDIOS_POR_APERCIBIMIENTO


## Con `>=` y no con `==`: una jornada grave sube de a dos apercibimientos, así que el contador
## puede pasar de largo el umbral sin pisarlo. Un `==` deja despedir sólo a quien cae justo.
func despedido() -> bool:
	return _medios >= Reglas.APERCIBIMIENTOS_HASTA_EL_DESPIDO * Reglas.MEDIOS_POR_APERCIBIMIENTO
