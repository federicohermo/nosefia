## La navegación conserva la bandeja; cerrar una pantalla nunca borra lo leído.
class_name Celular
extends RefCounted

enum Pantalla { MENU, CHAT, FOTO }
const ACCION := &"celular"

var _bandeja: Bandeja
var _habilitado: bool = false
var _abierto: bool = false
var _pantalla: Pantalla = Pantalla.MENU
var _chat: Conversacion.Interlocutor = Conversacion.Interlocutor.values()[0]
var _foto: int = -1
var _fijo: bool = false


func _init(bandeja: Bandeja) -> void:
	_bandeja = bandeja


func bandeja() -> Bandeja:
	return _bandeja


func habilitar(en_jornada: bool) -> void:
	_habilitado = en_jornada
	if not en_jornada:
		_cerrar()


func abierto() -> bool:
	return _abierto


func pantalla() -> Pantalla:
	return _pantalla


func chat() -> Conversacion.Interlocutor:
	return _chat


func foto() -> int:
	return _foto


func fijo() -> bool:
	return _fijo


func alternar(control_tomado: bool) -> bool:
	if _abierto:
		if _fijo:
			return false
		_cerrar()
		return true
	if not _habilitado or control_tomado:
		return false
	_abierto = true
	_pantalla = Pantalla.MENU
	return true


func abrir_chat(quien: Conversacion.Interlocutor) -> bool:
	var conversacion := _bandeja.conversacion_de(quien)
	if (
		not _abierto
		or _pantalla != Pantalla.MENU
		or not _bandeja.conversaciones().has(conversacion)
	):
		return false
	_chat = quien
	_pantalla = Pantalla.CHAT
	_bandeja.marcar_leida(quien)
	return true


func volver_al_menu() -> bool:
	if not _abierto or _fijo or _pantalla != Pantalla.CHAT:
		return false
	_pantalla = Pantalla.MENU
	return true


func ampliar(indice: int) -> bool:
	var mensajes := _bandeja.mensajes_de(_chat)
	if not _abierto or _pantalla != Pantalla.CHAT or indice < 0 or indice >= mensajes.size():
		return false
	if mensajes[indice].foto == null:
		return false
	_foto = indice
	_pantalla = Pantalla.FOTO
	return true


func cerrar_foto() -> bool:
	if not _abierto or _pantalla != Pantalla.FOTO:
		return false
	_pantalla = Pantalla.CHAT
	_foto = -1
	return true


func fijar_en(quien: Conversacion.Interlocutor) -> bool:
	if _bandeja.conversacion_de(quien) == null:
		return false
	if _abierto and _fijo and _chat == quien and _pantalla == Pantalla.CHAT:
		return false
	_abierto = true
	_fijo = true
	_chat = quien
	_foto = -1
	_pantalla = Pantalla.CHAT
	_bandeja.marcar_leida(quien)
	return true


func soltar() -> bool:
	if not _fijo:
		return false
	_cerrar()
	return true


func _cerrar() -> void:
	_abierto = false
	_fijo = false
	_foto = -1
	_pantalla = Pantalla.MENU
