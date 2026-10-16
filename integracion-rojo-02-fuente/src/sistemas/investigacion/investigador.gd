class_name Investigador
extends Node

signal pista_nueva(pista: Pista)
signal nota_agregada(mensaje: Mensaje)

var _expediente: Expediente = null


func usar(_recibido: Expediente) -> void:
	pass


func pedir_pista(
	_origen: StringName, _canal: Pista.Canal, _jornada: int, _permitido: bool
) -> Expediente.Resultado:
	return Expediente.Resultado.DESCONOCIDA
