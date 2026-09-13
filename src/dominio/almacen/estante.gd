## La góndola del local: qué productos acepta, cuántos le entran y qué pasa con la unidad que se
## coloca.
##
## **No guarda una sola unidad.** Cuántas hay y dónde están lo lleva `Inventario`, y este estante
## le pregunta cada vez: un contador propio acá contestaría el número viejo apenas alguien venda
## por la ventanilla, y ningún error lo diría. Es lo mismo que hace que el estante que se ve sea
## un reflejo del inventario y no su fuente.
##
## **El cupo de cada producto es su `umbral`**, el que el 005 le puso en el `Catalogo`. Un número
## propio acá sería el mismo valor escrito dos veces, y `Inventario.faltantes()` —que es de donde
## sale `completada()`— seguiría midiendo contra el otro.
##
## Es la mitad de reponer que se ejerce sin levantar una escena: acá no hay un solo `Node3D`.
## Colocar la unidad con la mano, dibujar el hueco que se llenó y cobrar el tiempo son las tres
## cosas que quedan afuera.
class_name Estante
extends RefCounted

## Por qué no se pudo colocar. Es un conjunto cerrado y por eso es un `enum`: un `String` suelto
## dejaría a la escena con un cartel que no se muestra nunca, sin que el motor diga una palabra.
##
## `NINGUNO` es «se colocó», y existe para que `colocar()` conteste una sola cosa en vez de un
## `bool` más un motivo que hay que ir a buscar aparte.
enum Rechazo { NINGUNO, PRODUCTO_NO_ACEPTADO, ESTANTE_LLENO, SIN_UNIDADES_EN_DEPOSITO }

var _inventario: Inventario

## En el orden en que llegaron, y sin `id` repetido: la identidad es el `id` y nunca la
## instancia, porque `Catalogo.de()` construye un producto nuevo en cada llamada.
var _aceptados: Array[Producto] = []


func _init(inventario: Inventario, aceptados: Array[Producto]) -> void:
	_inventario = inventario
	for producto in aceptados:
		if producto == null or _aceptado_con_el_id_de(producto) != null:
			continue
		_aceptados.append(producto)


## Si este estante es el lugar de ese producto.
##
## Compara por `id` y no por instancia, y no es un detalle: reponer la yerba que salió del
## catálogo sobre un estante armado con otra yerba contestaría «eso no va acá» —dos objetos
## distintos con el mismo `id`— y el jugador no tendría cómo enterarse de por qué.
func acepta(producto: Producto) -> bool:
	return _aceptado_con_el_id_de(producto) != null


## Cuántas unidades pide la góndola de ese producto, o `0` si el estante no lo acepta.
##
## Sale del `umbral` del producto **que el estante declaró aceptar** y no del que le pasan: así
## un producto armado a mano con otro umbral no cambia cuánto le entra a esta góndola.
func cupo(producto: Producto) -> int:
	var aceptado := _aceptado_con_el_id_de(producto)
	if aceptado == null:
		return 0
	return aceptado.umbral


## Cuántas hay en la góndola ahora mismo, preguntándole al inventario.
func unidades_en_gondola(producto: Producto) -> int:
	if producto == null:
		return 0
	return _inventario.unidades(producto, Inventario.Ubicacion.GONDOLA)


## Cuántas quedan en el depósito ahora mismo, preguntándole al inventario.
func unidades_en_deposito(producto: Producto) -> int:
	if producto == null:
		return 0
	return _inventario.unidades(producto, Inventario.Ubicacion.DEPOSITO)


## Cuántos de los productos aceptados ya llegaron a su cupo.
##
## Existe para que el estante que se ve pinte contra un número del dominio en vez de contar sus
## propios hijos: un hueco lleno por producto repuesto. No reemplaza a `completada()`, que es la
## pregunta de si son **todos**.
func productos_completos() -> int:
	var completos := 0
	for producto in _aceptados:
		if unidades_en_gondola(producto) >= cupo(producto):
			completos += 1
	return completos


## Cuántos productos acepta este estante, que es cuántos huecos tiene que dibujar la escena.
func productos_aceptados() -> int:
	return _aceptados.size()


## Mueve **una** unidad del depósito a la góndola, y devuelve por qué no pudo.
##
## Los tres rechazos no mueven nada, y el orden importa: «eso no va acá» es una propiedad del
## producto y vale siempre, «no entra más» se resuelve vendiendo, y «no queda en el depósito» es
## el único que depende de cuánta mercadería trajo la noche.
func colocar(producto: Producto) -> Rechazo:
	if not acepta(producto):
		return Rechazo.PRODUCTO_NO_ACEPTADO
	if unidades_en_gondola(producto) >= cupo(producto):
		return Rechazo.ESTANTE_LLENO
	var movidas := _inventario.mover(
		producto, Inventario.Ubicacion.DEPOSITO, Inventario.Ubicacion.GONDOLA, 1
	)
	if movidas == 0:
		return Rechazo.SIN_UNIDADES_EN_DEPOSITO
	return Rechazo.NINGUNO


## Si ningún producto aceptado está por debajo de su umbral.
##
## Sale de `Inventario.faltantes()` y no de una comparación propia: es exactamente la misma
## pregunta —«qué le falta a la góndola»— y escribirla dos veces daría dos respuestas el día
## que el 005 cambie de criterio. Se filtra por lo aceptado porque un estante puede no ser el
## lugar de todo el catálogo.
##
## Un estante que no acepta nada está completo por vacuidad, que es lo que corresponde: no quedó
## nada sin reponer.
func completada() -> bool:
	for producto in _inventario.faltantes():
		if acepta(producto):
			return false
	return true


## El producto declarado que tiene ese `id`, o `null`.
##
## Un `producto` nulo contesta `null` en vez de reventar, y es el camino por el que llega un `id`
## sin fila en el catálogo: `Catalogo.de()` devuelve `null`, medido. Sin este camino el rechazo
## sería un error del motor, que gdUnit4 cuenta como *error* y no como *failure* — el archivo
## sigue diciendo `PASSED` y la aserción nunca llega a correr.
func _aceptado_con_el_id_de(producto: Producto) -> Producto:
	if producto == null:
		return null
	for aceptado in _aceptados:
		if aceptado.id == producto.id:
			return aceptado
	return null
