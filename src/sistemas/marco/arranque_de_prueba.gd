## Lleva la partida de prueba de la URL al motor: escribe su guardado y prepara el turno de la
## jornada configurada.
##
## **Traduce, no decide.** Qué parámetros valen y qué guardado arman lo contesta `PartidaDePrueba`.
## Acá sólo se lee la página, se escribe el disco y se mueve el reloj. Fuera de la web la búsqueda
## es vacía y no cambia nada.
class_name ArranqueDePrueba
extends Node

## El guardado se escribe y el turno se prepara una sola vez por carga de la página: «Volver al
## menú» no los repite, y la partida avanza.
static var _guardado_escrito := false
static var _turno_preparado := false

var _sostenidas: Array[Tarea] = []
var _reloj: RelojDelTurno


## Lo que la página trae después del `?`, o vacío fuera de la web.
static func busqueda_de_la_pagina() -> String:
	if not OS.has_feature("web"):
		return ""
	return str(JavaScriptBridge.eval("window.location.search"))


## Los logros que muestra la pantalla: todos ganados si la búsqueda lo pide, y si no, los reales. Es
## una instancia aparte: lo que el jugador tiene en disco no se toca.
static func logros_a_mostrar(
	prueba: PartidaDePrueba, reales: Logros, caso: CasoDeInvestigacion
) -> Logros:
	if prueba != null and prueba.logros_completos:
		return Logros.completos(caso)
	return reales


## Escribe el guardado de la partida de prueba, una sola vez por carga. Devuelve si escribió. Sin
## `jornada` no hay guardado que armar y el del jugador queda como está.
static func escribir_el_guardado(prueba: PartidaDePrueba, guardado: Guardado) -> bool:
	if _guardado_escrito or prueba == null or prueba.jornada < 0:
		return false
	_guardado_escrito = true
	return guardado.escribir(prueba.guardado(CasoDeInvestigacion.de_la_partida()))


## Vuelve al estado de una página recién cargada.
static func olvidar_la_carga() -> void:
	_guardado_escrito = false
	_turno_preparado = false


## Si `jornada` es la configurada, cumple sus obligatorias y las sostiene cumplidas, y adelanta el
## reloj hasta que falten `segundos_al_cierre` segundos reales. El reloj no retrocede.
func aplicar(prueba: PartidaDePrueba, reloj: RelojDelTurno, jornada: int) -> void:
	if _turno_preparado or prueba == null or prueba.jornada != jornada:
		return
	_turno_preparado = true
	_reloj = reloj
	if prueba.completas:
		_cumplir_las_obligatorias()
		reloj.tarea_descumplida.connect(_volver_a_cumplir.unbind(1))
	if prueba.segundos_al_cierre >= 0.0:
		_adelantar_hasta(prueba.segundos_al_cierre)


func _cumplir_las_obligatorias() -> void:
	_sostenidas.clear()
	for tipo: Tarea.Tipo in Tarea.Tipo.values():
		var tarea := _reloj.obligatoria(tipo)
		if tarea != null:
			_sostenidas.append(tarea)
			_reloj.completar(tarea)


## Sólo las tareas de la jornada en curso: la siguiente se juega normal.
func _volver_a_cumplir() -> void:
	for tarea: Tarea in _sostenidas:
		if _reloj.obligatoria(tarea.tipo()) == tarea:
			_reloj.completar(tarea)


func _adelantar_hasta(segundos_al_cierre: float) -> void:
	_reloj.avanzar(_reloj.tiempo_restante() / _reloj.ritmo() - segundos_al_cierre)
	if segundos_al_cierre <= 0.0 and _reloj.corriendo():
		_reloj.terminar()
