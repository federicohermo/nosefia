## La bandeja de chats: qué conversaciones hay y cuáles ya se leyeron.
##
## **Lo leído vive acá y no en el `.tres`**, y es la decisión más cara de este spec: está medido
## que dos `load()` del mismo recurso devuelven **la misma instancia**, así que una marca adentro
## del guión sobreviviría a la partida entera — el jugador empezaría la noche dos con todo leído.
##
## **Y la bandeja es una sola instancia, dueña de un sistema y no de la pantalla.** Si la
## construyera la app de chats, cambiar de app tiraría lo leído sin un solo error y con los seis
## nodos en verde: `ui/` no lleva test obligatorio.
##
## Lleva un `bool` por interlocutor y no un contador global: con uno solo, leer al jefe apagaría
## el aviso de los otros dos y el jugador no volvería a mirarlos.
class_name Bandeja
extends RefCounted

## En el orden en que llegaron, que es el orden en que se listan las pestañas.
var _conversaciones: Array[Conversacion] = []

## `Interlocutor` → `bool`. Sólo tiene fila el que está en la bandeja: preguntar por uno que no
## está contesta cero no leídos, que es lo que corresponde.
var _leidas: Dictionary = {}


func _init(conversaciones: Array[Conversacion]) -> void:
	for conversacion in conversaciones:
		if conversacion == null or _leidas.has(conversacion.interlocutor):
			continue
		_conversaciones.append(conversacion)
		_leidas[conversacion.interlocutor] = false


## Las conversaciones, **como copia**: quien la recorra para dibujarla no puede vaciarla.
func conversaciones() -> Array[Conversacion]:
	return _conversaciones.duplicate()


## La conversación de ese interlocutor, o `null` si no está en la bandeja.
func conversacion_de(quien: Conversacion.Interlocutor) -> Conversacion:
	for conversacion in _conversaciones:
		if conversacion.interlocutor == quien:
			return conversacion
	return null


func esta_leida(quien: Conversacion.Interlocutor) -> bool:
	return _leidas.get(quien, false)


## Cuántos mensajes sin leer tiene ese interlocutor.
##
## Una conversación leída contesta 0 y no «los mismos menos uno»: leer un chat es leerlo entero,
## que es lo que el jugador hace cuando abre la pestaña.
func no_leidos(quien: Conversacion.Interlocutor) -> int:
	if esta_leida(quien):
		return 0
	var conversacion := conversacion_de(quien)
	if conversacion == null:
		return 0
	return conversacion.mensajes.size()


## Cuántos mensajes sin leer hay en toda la bandeja. Es el número del aviso de los chats.
func no_leidos_totales() -> int:
	var sin_leer := 0
	for conversacion in _conversaciones:
		sin_leer += no_leidos(conversacion.interlocutor)
	return sin_leer


## Marca esa conversación como leída, y devuelve `true` **sólo si la marcó ahora**.
##
## De ese `false` se agarra el sistema para no volver a publicar el número de no leídos en cada
## clic sobre la misma pestaña.
func marcar_leida(quien: Conversacion.Interlocutor) -> bool:
	if not _leidas.has(quien) or esta_leida(quien):
		return false
	_leidas[quien] = true
	return true
