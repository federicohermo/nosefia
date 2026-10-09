## Publica la lectura y la impresión que contesta el programa.
class_name CajaRegistradora
extends Node

signal programa_arrancado(manual: bool)

signal producto_leido
signal lectura_rechazada(motivo: GeneradorDeTickets.Resultado)
signal renglones_cambiados
signal ticket_impreso(ticket: Ticket)
signal ticket_desechado

var _generador: GeneradorDeTickets


func arrancar(generador_de_la_jornada: GeneradorDeTickets) -> void:
	_generador = generador_de_la_jornada
	programa_arrancado.emit(_generador.es_manual())
	renglones_cambiados.emit()


func generador() -> GeneradorDeTickets:
	return _generador


func pedir_anotar(objeto: ObjetoDelAlmacen) -> void:
	if _sin_cablear():
		return
	var resultado := _generador.anotar(objeto)
	if resultado == GeneradorDeTickets.Resultado.SIN_LECTOR:
		return
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


func pedir_elegir(renglon: int, producto: Producto) -> void:
	if _sin_cablear():
		return
	if _generador.elegir(renglon, producto):
		renglones_cambiados.emit()


func pedir_desechar(objeto: ObjetoDelAlmacen, destino: StringName) -> bool:
	if not Ticket.se_desecha_en(objeto, destino):
		return false
	ticket_desechado.emit()
	return true
