## Publica la lectura y la impresión que contesta el programa.
class_name CajaRegistradora
extends Node

signal producto_leido
signal lectura_rechazada(motivo: GeneradorDeTickets.Resultado)
signal renglones_cambiados
signal ticket_impreso(ticket: Ticket)

var _generador: GeneradorDeTickets


func arrancar(generador_de_la_jornada: GeneradorDeTickets) -> void:
	_generador = generador_de_la_jornada
	renglones_cambiados.emit()


func generador() -> GeneradorDeTickets:
	return _generador


func pedir_anotar(objeto: ObjetoDelAlmacen) -> void:
	if _sin_cablear():
		return
	var resultado := _generador.anotar(objeto)
	if resultado != GeneradorDeTickets.Resultado.ANOTADO:
		lectura_rechazada.emit(resultado)
		return
	producto_leido.emit()
	renglones_cambiados.emit()


func pedir_borrar() -> void:
	if _sin_cablear():
		return
	_generador.borrar()
	renglones_cambiados.emit()


func pedir_imprimir() -> void:
	if _sin_cablear():
		return
	var ticket := _generador.imprimir()
	if ticket != null:
		ticket_impreso.emit(ticket)


func _sin_cablear() -> bool:
	if _generador != null:
		return false
	push_error("Caja registradora sin generador: revisar almacen.gd")
	return true
