## El pedido que el jugador le hace a Hernán por el chat del celular: qué marcó en la lista, qué
## envió y con qué wifi, qué le contestó el proveedor y si lo enviado cumple la tarea.
##
## **Lee el wifi al enviar y no lo vuelve a mirar** (BR-INV-125): lo que ya salió en rojo no se
## arregla cuando vuelve la conexión. Qué hora marca el reloj y cuánto tiempo pasó también entran
## como parámetro, y nada de acá abre una pantalla.
##
## **La tarea cuenta el último pedido enviado con wifi** (BR-SHF-032): uno sin wifi no cuenta ni
## pisa al anterior.
class_name PedidoAlProveedor
extends RefCounted

const SALUDO := "Hola, ¿cómo estás? Te hablo de la estación de servicio. Necesito estos productos:"
const ERROR_DE_RED := "Error en la red"
const NOMBRE_DEL_PROVEEDOR := "Hernán"

## Cuánto tarda en llegar cada respuesta, contado desde que se envió el pedido (BR-INV-125): la
## primera a los tres segundos, y la segunda un segundo después de la primera.
const SEGUNDOS_HASTA_LA_PRIMERA := 3.0
const SEGUNDOS_ENTRE_RESPUESTAS := 1.0
const FRASE_DE_LA_PISTA := "Qué lindo no tener que hablar directamente con Enrique"
const TRAMO_DE_LA_PISTA := "proveedor"
const PISTA := "6A"
const RESPUESTAS: Array[String] = [
	"Hola, buenas noches! " + FRASE_DE_LA_PISTA,
	"Dale, te preparo los productos para mañana. Estaré pasando por allá antes del mediodía",
]

## Los mensajes de la jornada van después de los del guión, que nunca llegan a este orden.
const ORDEN_BASE := 1000

var _jornada: int
var _pistas_activas: PackedStringArray
var _lista_abierta: bool = false
var _marcados: Array[Producto.Id] = []
var _enviados: Array[Array] = []
var _ultimo_con_wifi: Array[Producto.Id] = []
var _hubo_con_wifi: bool = false
var _mensajes_creados: int = 0
var _pendientes: Array[Dictionary] = []


## `pistas_activas` son las de la noche: la frase de la primera respuesta sólo es una pista si 6A
## está entre ellas.
func _init(jornada: int, pistas_activas: PackedStringArray = PackedStringArray()) -> void:
	_jornada = jornada
	_pistas_activas = pistas_activas


## Los treinta y nueve que ofrece la lista, con casilla cada uno.
func productos_de_la_lista() -> Array[Producto]:
	return Catalogo.pedibles()


func lista_abierta() -> bool:
	return _lista_abierta


## Abrir la lista la deja sin ningún producto marcado.
func abrir_lista() -> void:
	_lista_abierta = true
	_marcados.clear()


## Cerrar sin enviar no deja ningún mensaje.
func cerrar_lista() -> void:
	_lista_abierta = false
	_marcados.clear()


## Con la lista cerrada, o con un producto que el catálogo no conoce, no marca nada.
func marcar(id: Producto.Id) -> void:
	if not _lista_abierta or Catalogo.de(id) == null or _marcados.has(id):
		return
	_marcados.append(id)


func desmarcar(id: Producto.Id) -> void:
	_marcados.erase(id)


func esta_marcado(id: Producto.Id) -> bool:
	return _marcados.has(id)


## En el orden del enum, que es el de la lista.
func marcados() -> Array[Producto.Id]:
	var ordenados: Array[Producto.Id] = _marcados.duplicate()
	ordenados.sort()
	return ordenados


## «Enviar» está habilitado sólo con la lista abierta y algo marcado.
func puede_enviar() -> bool:
	return _lista_abierta and not _marcados.is_empty()


## Envía lo marcado: devuelve el mensaje del jugador, o `null` si no se podía enviar.
##
## Con wifi, deja programadas las dos respuestas de Hernán. Sin wifi, el mensaje sale en rojo y no
## llega ninguna.
func enviar(hay_wifi: bool, hora: String) -> Mensaje:
	if not puede_enviar():
		return null
	var productos := marcados()
	_enviados.append(productos)
	var mensaje := _mensaje_del_jugador(productos, hay_wifi, hora)
	if hay_wifi:
		_hubo_con_wifi = true
		_ultimo_con_wifi = productos
		for indice in RESPUESTAS.size():
			(
				_pendientes
				. append(
					{
						"falta": SEGUNDOS_HASTA_LA_PRIMERA + SEGUNDOS_ENTRE_RESPUESTAS * indice,
						"mensaje": _respuesta(indice),
					}
				)
			)
	cerrar_lista()
	return mensaje


## Pasan `segundos` de juego: devuelve las respuestas que llegan ahora, con la hora de su llegada.
## Un tiempo que no es positivo no hace llegar nada.
func avanzar(segundos: float, hora: String) -> Array[Mensaje]:
	var llegadas: Array[Mensaje] = []
	if segundos <= 0.0:
		return llegadas
	var siguen: Array[Dictionary] = []
	for pendiente: Dictionary in _pendientes:
		pendiente["falta"] = float(pendiente["falta"]) - segundos
		if float(pendiente["falta"]) <= 0.0:
			var mensaje: Mensaje = pendiente["mensaje"]
			mensaje.hora = hora
			llegadas.append(mensaje)
		else:
			siguen.append(pendiente)
	_pendientes = siguen
	return llegadas


## Cuántos pedidos se enviaron, con o sin wifi.
func cantidad_de_enviados() -> int:
	return _enviados.size()


func hubo_pedido_con_wifi() -> bool:
	return _hubo_con_wifi


## Los productos del último pedido enviado con wifi, o nada si no hubo.
func ultimo_con_wifi() -> Array[Producto.Id]:
	return _ultimo_con_wifi.duplicate()


## Si el último pedido enviado con wifi tiene exactamente los productos de las cajas vacías: ni uno
## más ni uno menos, en cualquier orden.
func cumplido(vacias: Array[Producto.Id]) -> bool:
	if not _hubo_con_wifi:
		return false
	var esperadas: Array[Producto.Id] = vacias.duplicate()
	esperadas.sort()
	return _ultimo_con_wifi == esperadas


## Si salió algún pedido con wifi y el último no es el de las cajas vacías.
func equivocado(vacias: Array[Producto.Id]) -> bool:
	return _hubo_con_wifi and not cumplido(vacias)


func _mensaje_del_jugador(productos: Array[Producto.Id], hay_wifi: bool, hora: String) -> Mensaje:
	var lineas: Array[String] = [SALUDO]
	for id in productos:
		lineas.append("- " + Catalogo.de(id).nombre)
	var mensaje := _mensaje("PEDIDO_%d" % _enviados.size(), "\n".join(lineas), hora)
	mensaje.propio = true
	mensaje.con_error = not hay_wifi
	return mensaje


func _respuesta(indice: int) -> Mensaje:
	var mensaje := _mensaje(
		"RESPUESTA_%d_%d" % [_enviados.size(), indice + 1], RESPUESTAS[indice], ""
	)
	mensaje.de_quien = NOMBRE_DEL_PROVEEDOR
	if indice == 0 and _pistas_activas.has(PISTA):
		mensaje.tramo_de_pista = TRAMO_DE_LA_PISTA
		mensaje.texto_del_tramo = FRASE_DE_LA_PISTA
		mensaje.pista = PISTA
	return mensaje


func _mensaje(identidad: String, texto: String, hora: String) -> Mensaje:
	var mensaje := Mensaje.new()
	mensaje.identidad = identidad
	mensaje.texto = texto
	mensaje.hora = hora
	mensaje.jornada = _jornada
	mensaje.momento = Mensaje.Momento.APERTURA
	mensaje.de_la_noche = true
	mensaje.orden = ORDEN_BASE + _mensajes_creados
	_mensajes_creados += 1
	return mensaje
