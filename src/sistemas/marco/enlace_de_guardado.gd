## El llamador del guardado: al cerrar cada jornada le pregunta a la política qué hacer y lo hace.
class_name EnlaceDeGuardado
extends Node

var _ciclo: CicloDeJornadas
var _guardado: Guardado


func _init(ciclo: CicloDeJornadas, guardado: Guardado) -> void:
	_ciclo = ciclo
	_guardado = guardado
	_ciclo.jornada_cerrada.connect(_al_cerrar_la_jornada)


func _al_cerrar_la_jornada(_jornada: int, _cumplidas: int) -> void:
	guardar()


func guardar() -> void:
	var partida := _ciclo.partida()
	match PoliticaDeGuardado.accion(partida):
		PoliticaDeGuardado.Accion.ESCRIBIR:
			_guardado.escribir(PoliticaDeGuardado.datos(partida))
		PoliticaDeGuardado.Accion.BORRAR:
			_guardado.borrar()
