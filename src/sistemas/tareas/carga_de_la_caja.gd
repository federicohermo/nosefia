## El nodo que carga la caja adentro del motor: recibe el pedido, se lo pasa al dominio y publica
## lo que el dominio contestó.
##
## **Traduce, no decide.** No sabe cuántos casilleros hay ni qué cuenta como producto: las dos
## son preguntas de `CajaDeTraslado`, que es donde tienen test. El único `if` de este archivo es
## el valor que devolvió el dominio.
##
## **No conoce la escena.** Emite hacia arriba y no pregunta nada: quien quiera dibujar el
## casillero nuevo se conecta a `producto_guardado`, y quien quiera mostrar el cartel del rechazo,
## a `guardado_rechazado`.
##
## El `id` entra por parámetro y el producto se pide al catálogo acá: es la puerta por la que un
## `id` sin fila llega al dominio como `null` y se rechaza con motivo, en vez de reventar.
class_name CargaDeLaCaja
extends Node

signal producto_guardado(producto: Producto)
signal guardado_rechazado(motivo: CajaDeTraslado.Motivo)

var _caja := CajaDeTraslado.new()


## La caja que este nodo está cargando.
##
## La expone porque quien dibuja necesita el contenido, y construir una segunda caja para
## mirarla daría un contenido que no es el que se está cargando: sin error y sin rojo.
func caja() -> CajaDeTraslado:
	return _caja


## Intenta guardar el producto de ese `id` y avisa cómo salió.
##
## Emite **una** de las dos señales y nunca las dos: emitirlas juntas dejaría a la escena
## pintando un casillero nuevo y un cartel de «no entra» al mismo tiempo.
func pedir_guardar(id: Producto.Id) -> void:
	var producto := Catalogo.de(id)
	if not _caja.guardar(producto):
		guardado_rechazado.emit(_caja.motivo_de_rechazo())
		return
	producto_guardado.emit(producto)
