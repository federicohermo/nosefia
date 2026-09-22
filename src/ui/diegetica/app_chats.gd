## La app de chats: la lista de conversaciones y lo que dice la abierta.
##
## **No sabe con quiénes chatea el empleado.** Los nombres viven en los `.tres` y quiénes existen
## lo dice el `enum` del dominio: escritos acá se cambiarían en dos lados, y el día que se agregue
## uno la pantalla lo dejaría afuera sin que nada se ponga en rojo. Hay un caso que lo verifica
## sobre el texto de este archivo.
##
## Va en `diegetica/` porque leer chats cuesta minutos del turno: es el lado «investigación» de la
## resta, y está a un clic de la caja a propósito.
class_name AppChats
extends Control

signal lectura_pedida(quien: Conversacion.Interlocutor)

const TEXTO_DEL_TITULO := "Chats"
const TEXTO_DE_LA_PESTANA := "%s (%d sin leer)"
const TEXTO_DE_LA_PESTANA_LEIDA := "%s"
const TEXTO_DEL_MENSAJE := "%s: %s"
const TEXTO_SIN_ABRIR := "Elegí una conversación."

@export var _titulo: Label
@export var _pestanas: VBoxContainer
@export var _mensajes: VBoxContainer
@export var _vacio: Label


func _ready() -> void:
	_titulo.text = TEXTO_DEL_TITULO
	_vacio.text = TEXTO_SIN_ABRIR


## Repinta la lista de conversaciones con su cuenta de mensajes sin leer.
func mostrar(bandeja: Bandeja) -> void:
	_limpiar(_pestanas)
	for conversacion in bandeja.conversaciones():
		_pestanas.add_child(_pestana_de(conversacion, bandeja.no_leidos(conversacion.interlocutor)))


## Pinta los mensajes de una conversación. Un `null` deja el cartel de que no hay ninguna abierta.
##
## El corte no es adorno: sin él, `null` no deja el cartel — revienta al pedirle los mensajes a
## nada, y con el cartel escrito al lado en un método que nadie llamaba.
func mostrar_conversacion(conversacion: Conversacion) -> void:
	if conversacion == null:
		mostrar_sin_conversacion()
		return
	_limpiar(_mensajes)
	for mensaje in conversacion.mensajes:
		var etiqueta := Label.new()
		etiqueta.text = TEXTO_DEL_MENSAJE % [mensaje.de_quien, mensaje.texto]
		etiqueta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_mensajes.add_child(etiqueta)
	_vacio.visible = false


func mostrar_sin_conversacion() -> void:
	_limpiar(_mensajes)
	_vacio.visible = true


func _pestana_de(conversacion: Conversacion, sin_leer: int) -> Button:
	var boton := Button.new()
	if sin_leer > 0:
		boton.text = TEXTO_DE_LA_PESTANA % [conversacion.nombre, sin_leer]
	else:
		boton.text = TEXTO_DE_LA_PESTANA_LEIDA % conversacion.nombre
	var quien := conversacion.interlocutor
	boton.pressed.connect(func() -> void: lectura_pedida.emit(quien))
	return boton


## Se sacan del árbol **antes** de liberarlos: `queue_free()` no los desprende hasta el final del
## cuadro, así que sin el `remove_child` la conversación siguiente quedaría apilada sobre la
## anterior.
func _limpiar(contenedor: Node) -> void:
	for viejo in contenedor.get_children():
		contenedor.remove_child(viejo)
		viejo.queue_free()
