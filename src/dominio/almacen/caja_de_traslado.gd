## La caja con la que se traslada la mercadería: cuánto entra, qué se acepta y por qué se
## rechaza.
##
## **Es lo que convierte reponer en una decisión.** Sin caja, reponer es un viaje por unidad. Con
## ocho casilleros el jugador elige cuánto carga, y cada viaje ahorrado es un minuto para
## investigar — el otro lado de la tensión central.
##
## **No sabe dónde está ni quién la lleva**, y por eso viaja llena: el contenido no depende de
## ninguna ubicación, así que no hay nada que actualizar cuando la caja cambia de lugar. Es lo
## mismo que la deja ejercerse sin que nadie la levante.
##
## **No toca el stock.** Cuántas unidades hay lo lleva otra pieza de esta misma carpeta, y
## llevarlas del depósito a la góndola es del 008: la caja es dónde viaja la mercadería, no
## cuánta hay.
##
## Lo que no es un producto llega como `null` —`Catalogo.de()` contesta `null` a un `id` sin
## fila, medido— y se rechaza acá: «sólo entran productos» es una regla del juego, y escrita en
## la escena nacería sin test.
class_name CajaDeTraslado
extends RefCounted

## Por qué no entró. Es un conjunto cerrado y por eso es un `enum`: un `String` suelto dejaría a
## la escena con un cartel que no se muestra nunca, sin que el motor diga una palabra.
##
## `NINGUNO` es el estado de una caja a la que todavía no le rechazaron nada, y existe para que
## `motivo_de_rechazo()` no tenga que devolver un nulo que después hay que guardar.
enum Motivo { NINGUNO, CAJA_LLENA, NO_ES_UN_PRODUCTO }

var _contenido: Array[Producto] = []
var _motivo: Motivo = Motivo.NINGUNO


func ocupados() -> int:
	return _contenido.size()


func libres() -> int:
	return Reglas.CASILLEROS_DE_LA_CAJA_DE_TRASLADO - ocupados()


func esta_llena() -> bool:
	return libres() <= 0


## Por qué falló el último `guardar()`.
##
## Sale de acá y no del valor de retorno porque los dos rechazos se leen distinto adelante de la
## caja: «no entra más» y «eso no se guarda» son dos carteles, no uno.
func motivo_de_rechazo() -> Motivo:
	return _motivo


## Mete un producto en el primer casillero libre, y devuelve si pudo.
##
## El orden de los dos rechazos importa: una caja llena a la que le ofrecen algo que no es un
## producto contesta que no es un producto, que es el problema más cerca de quien lo ofrece.
func guardar(producto: Producto) -> bool:
	if producto == null:
		_motivo = Motivo.NO_ES_UN_PRODUCTO
		return false
	if esta_llena():
		_motivo = Motivo.CAJA_LLENA
		return false
	_contenido.append(producto)
	_motivo = Motivo.NINGUNO
	return true


## Saca lo último que se guardó, o `null` si no hay nada.
##
## Se descarga por arriba, como una caja de verdad: lo último que entró es lo primero que sale,
## así el jugador no tiene que acordarse del orden en que la cargó. Vacía devuelve `null` en vez
## de romperse, que es la misma forma que `Catalogo.de()`.
func sacar() -> Producto:
	if _contenido.is_empty():
		return null
	return _contenido.pop_back()


## Lo que hay adentro, **como copia**.
##
## Medido en headless: un `Array` devuelto sin `duplicate()` es el mismo array, y un `clear()`
## afuera vacía el original. Sin la copia, quien mira la caja para dibujarla la puede vaciar.
func contenido() -> Array[Producto]:
	return _contenido.duplicate()
