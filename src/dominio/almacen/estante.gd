## La góndola del local: qué productos acepta, cuántos le entran, en qué casillero va cada
## unidad y qué pasa con la que se coloca o se agarra.
##
## **No guarda una sola unidad.** Cuántas hay y dónde están lo lleva `Inventario`, y este estante
## le pregunta cada vez: un contador propio acá contestaría el número viejo apenas alguien venda
## por la ventanilla, y ningún error lo diría. Es lo mismo que hace que el estante que se ve sea
## un reflejo del inventario y no su fuente.
##
## **Tampoco las que salieron de su caja.** El estante las anota afuera y las quita, pero la lista
## es del inventario: la venta las tiene que ver para no llevárselas, y la ventanilla no conoce el
## estante.
##
## **Lo que sí lleva es en qué casilleros están**, que el inventario no sabe: el orden en que se
## ocupan los de cada fila. Cuántos de ese orden están ocupados sigue saliendo de la góndola del
## inventario, así que el orden no puede contradecir a la cuenta: sólo dice cuáles.
##
## **El cupo de cada producto son los casilleros de su fila de adelante**, y el estante se los
## pregunta al inventario: se los pasó quien armó el local, que los mide del modelo. Un número
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
## `bool` más un motivo que hay que ir a buscar aparte. El casillero ocupado va al final del
## `enum` y no en su lugar del orden: el orden de los rechazos lo decide `colocar()`, y los
## valores que ya existían no cambian de número.
enum Rechazo {
	NINGUNO,
	PRODUCTO_NO_ACEPTADO,
	ESTANTE_LLENO,
	SIN_UNIDADES_EN_DEPOSITO,
	CASILLERO_OCUPADO,
}

## Lo que hace el clic sobre un casillero según lo que haya en la mano. Es el mismo reparto que
## el de la caja: con nada, agarrar la unidad puesta; con una unidad, colocarla; con cualquier
## otra cosa, nada. Si el casillero la recibe lo contestan `agarrar()` y `colocar_unidad()`.
enum Gesto { COLOCAR, AGARRAR, NADA }

## «El primer casillero vacío de la fila», para quien coloca sin elegir dónde: la apertura de una
## noche de prueba y los casos que miden aritmética. El jugador siempre elige.
const PRIMERO_VACIO := -1

var _inventario: Inventario

## En el orden en que llegaron, y sin `id` repetido: la identidad es el `id` y nunca la
## instancia, porque `Catalogo.de()` construye un producto nuevo en cada llamada.
var _aceptados: Array[Producto] = []

## `id` → los casilleros de su fila, con los ocupados primero. Arranca en el orden de la fila, así
## que la góndola que llenó la apertura ocupa los primeros y lo que falta queda al final.
var _orden: Dictionary[Producto.Id, PackedInt32Array] = {}


func _init(inventario: Inventario, aceptados: Array[Producto]) -> void:
	_inventario = inventario
	for producto in aceptados:
		if producto == null or _aceptado_con_el_id_de(producto) != null:
			continue
		_aceptados.append(producto)


## Si este estante es el lugar de ese producto.
##
## Compara por `id` y no por instancia, y no es un detalle: dos objetos distintos con el mismo
## `id` contestarían «eso no va acá», y el jugador no tendría cómo enterarse de por qué.
func acepta(producto: Producto) -> bool:
	return _aceptado_con_el_id_de(producto) != null


## Cuántas unidades pide la góndola de ese producto: los casilleros de su fila de adelante, o
## `0` si el estante no lo acepta.
##
## Sale del inventario por el `id` **del producto que el estante declaró aceptar**, así que dos
## instancias del mismo producto contestan lo mismo, y una que el estante no acepta, cero.
func cupo(producto: Producto) -> int:
	var aceptado := _aceptado_con_el_id_de(producto)
	if aceptado == null:
		return 0
	return _inventario.casilleros(aceptado)


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


## Los casilleros de la fila de ese producto que tienen una unidad, de menor a mayor. Ninguno si
## el estante no lo acepta.
func casilleros_ocupados(producto: Producto) -> Array[int]:
	var orden := _orden_de(producto)
	return _ordenados(orden.slice(0, _ocupados_en_la_fila(producto)))


## Los casilleros de la fila de ese producto que esperan una unidad, de menor a mayor. Son los
## que lo hacen faltante.
func casilleros_vacios(producto: Producto) -> Array[int]:
	var orden := _orden_de(producto)
	return _ordenados(orden.slice(_ocupados_en_la_fila(producto)))


## Los casilleros de ese producto donde va lo que hay en la mano: con una unidad suya, los vacíos;
## con cualquier otra cosa o con nada, ninguno. Son los que se muestran (BR-PLY-022).
##
## Una unidad de otro producto no ve los casilleros de éste: la ficha no deja colocar un producto
## en el casillero de otro, y mostrarlo sería invitar al rechazo.
func casilleros_para_colocar(producto: Producto, sostenido: ObjetoDelAlmacen) -> Array[int]:
	var unidad := sostenido as UnidadDeProducto
	if unidad == null or unidad.producto == null or producto == null:
		return []
	if unidad.producto.id != producto.id:
		return []
	return casilleros_vacios(producto)


## Los casilleros de ese producto de los que se puede agarrar con lo que hay en la mano: con la
## mano vacía, los ocupados; con cualquier cosa, ninguno (BR-PLY-007, BR-PLY-024).
func casilleros_para_agarrar(producto: Producto, sostenido: ObjetoDelAlmacen) -> Array[int]:
	if sostenido != null:
		return []
	return casilleros_ocupados(producto)


## Qué hace el clic sobre un casillero con eso en la mano.
func uso(sostenido: ObjetoDelAlmacen) -> Gesto:
	if sostenido == null:
		return Gesto.AGARRAR
	if sostenido is UnidadDeProducto:
		return Gesto.COLOCAR
	return Gesto.NADA


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


## Mueve **una** unidad del depósito a ese casillero de la góndola, y devuelve por qué no pudo.
## Sin casillero, va al primero vacío.
##
## Los rechazos no mueven nada, y el orden importa: «eso no va acá» es una propiedad del producto
## y vale siempre; «no entra más» y «ese lugar ya tiene una» son el estado del estante, y la fila
## llena va primero porque es la respuesta para cualquier casillero; «no queda en el depósito»
## es el único que depende de cuánta mercadería trajo la noche.
func colocar(producto: Producto, casillero: int = PRIMERO_VACIO) -> Rechazo:
	var motivo := _motivo_del_casillero(producto, casillero)
	if motivo != Rechazo.NINGUNO:
		return motivo
	if disponibles_para_retirar(producto) <= 0:
		return Rechazo.SIN_UNIDADES_EN_DEPOSITO
	return _ocupar(producto, casillero)


## Cuántas se pueden sacar todavía: lo que queda en la caja, el depósito menos las que están
## afuera. Un producto que el estante no acepta no tiene caja acá, y contesta 0.
##
## **La góndola no pone tope** (BR-STK-017): con la fila completa la caja entrega igual. La unidad
## que no tiene casillero se rechaza al colocarla por estante lleno, y vuelve a la caja si se la
## devuelve. Cuántas se pueden vender es otra cuenta, y la lleva el inventario.
func disponibles_para_retirar(producto: Producto) -> int:
	if not acepta(producto):
		return 0
	return maxi(0, unidades_en_deposito(producto) - reservadas(producto))


func retirar(producto: Producto) -> UnidadDeProducto:
	if disponibles_para_retirar(producto) <= 0:
		return null
	var unidad := UnidadDeProducto.new(producto)
	_inventario.anotar_afuera(unidad)
	return unidad


## Saca de la góndola la unidad de ese casillero y la da para la mano, o devuelve `null` si el
## casillero no tiene una.
##
## **Queda contada como una que salió de su caja** (BR-STK-034): vuelve al depósito y queda
## afuera, igual que una sacada de la caja. Así la caja no cambia —su cuenta es el depósito menos
## lo que está afuera—, los vendibles tampoco —su casillero vacío la espera— y se la puede
## devolver a la caja o colocar como a cualquier otra. Contarla aparte sería un tercer lugar donde
## puede estar una unidad, y cada cuenta tendría que acordarse de él.
func agarrar(producto: Producto, casillero: int) -> UnidadDeProducto:
	if not casilleros_ocupados(producto).has(casillero):
		return null
	var ocupados := _ocupados_en_la_fila(producto)
	_inventario.mover(producto, Inventario.Ubicacion.GONDOLA, Inventario.Ubicacion.DEPOSITO, 1)
	_poner_en_el_orden(producto, casillero, ocupados - 1)
	var unidad := UnidadDeProducto.new(producto)
	_inventario.anotar_afuera(unidad)
	return unidad


## Cuántas unidades de ese producto salieron de su caja y todavía no se colocaron: en la mano o
## soltadas en el piso. Las cuenta el inventario, que es donde la venta las ve.
##
## **Siguen contadas en el depósito**, y por eso la caja se cuenta restándolas y no con un número
## propio: una venta que baja el depósito le resta a la caja sin que nadie se lo avise.
func reservadas(producto: Producto) -> int:
	return _inventario.afuera(producto)


## Anula la reserva de una unidad que salió de la caja y no se colocó, y devuelve si la anuló.
##
## No mueve mercadería: la unidad nunca dejó el depósito. Una que no está afuera —porque ya se
## colocó, ya volvió o nunca salió— no anula nada, y así la misma unidad no vuelve dos veces.
## Cuánto le entra a la caja no se mira acá: es de la caja, que llama a esto.
func devolver(unidad: UnidadDeProducto) -> bool:
	return _inventario.quitar_de_afuera(unidad)


## Coloca en ese casillero de `destino` una unidad que salió y no se colocó. Sin casillero, va al
## primero vacío.
##
## Una unidad que no está afuera —ya colocada o devuelta— se rechaza como producto no aceptado:
## es la que no tiene lugar en ningún casillero, y es lo que hace que dos clics seguidos coloquen
## una sola.
func colocar_unidad(
	unidad: UnidadDeProducto, destino: Producto = null, casillero: int = PRIMERO_VACIO
) -> Rechazo:
	if not _inventario.esta_afuera(unidad):
		return Rechazo.PRODUCTO_NO_ACEPTADO
	if destino != null and destino.id != unidad.producto.id:
		return Rechazo.PRODUCTO_NO_ACEPTADO
	var motivo := _motivo_del_casillero(unidad.producto, casillero)
	if motivo == Rechazo.NINGUNO:
		motivo = _ocupar(unidad.producto, casillero)
	if motivo == Rechazo.NINGUNO:
		_inventario.quitar_de_afuera(unidad)
	return motivo


## Si ningún producto aceptado tiene un casillero vacío en su fila de adelante.
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


## Los tres primeros rechazos de colocar, en su orden: el producto —también un casillero que no es
## de su fila—, la fila llena y el casillero ocupado.
func _motivo_del_casillero(producto: Producto, casillero: int) -> Rechazo:
	if not acepta(producto):
		return Rechazo.PRODUCTO_NO_ACEPTADO
	if casillero != PRIMERO_VACIO and (casillero < 0 or casillero >= cupo(producto)):
		return Rechazo.PRODUCTO_NO_ACEPTADO
	if unidades_en_gondola(producto) >= cupo(producto):
		return Rechazo.ESTANTE_LLENO
	if casillero != PRIMERO_VACIO and not casilleros_vacios(producto).has(casillero):
		return Rechazo.CASILLERO_OCUPADO
	return Rechazo.NINGUNO


## Mueve una unidad del depósito a la góndola y la pone en ese casillero, que ya se sabe vacío.
func _ocupar(producto: Producto, casillero: int) -> Rechazo:
	var ocupados := _ocupados_en_la_fila(producto)
	var elegido := casillero
	if elegido == PRIMERO_VACIO:
		elegido = casilleros_vacios(producto)[0]
	var movidas := _inventario.mover(
		producto, Inventario.Ubicacion.DEPOSITO, Inventario.Ubicacion.GONDOLA, 1
	)
	if movidas == 0:
		return Rechazo.SIN_UNIDADES_EN_DEPOSITO
	_poner_en_el_orden(producto, elegido, ocupados)
	return Rechazo.NINGUNO


## Cuántos casilleros de la fila de ese producto están ocupados: lo que dice la góndola del
## inventario, sin pasar de la fila.
func _ocupados_en_la_fila(producto: Producto) -> int:
	return clampi(unidades_en_gondola(producto), 0, cupo(producto))


## El orden de ocupación de la fila de ese producto: los ocupados primero. Uno que el estante no
## acepta no tiene fila.
##
## Se arma la primera vez que se pregunta, y de nuevo si la fila cambió de largo: el largo lo dice
## el inventario, y un orden más corto dejaría casilleros sin lugar.
func _orden_de(producto: Producto) -> PackedInt32Array:
	var aceptado := _aceptado_con_el_id_de(producto)
	if aceptado == null:
		return PackedInt32Array()
	var largo := cupo(aceptado)
	var orden: PackedInt32Array = _orden.get(aceptado.id, PackedInt32Array())
	if orden.size() != largo:
		orden = PackedInt32Array(range(largo))
		_orden[aceptado.id] = orden
	return orden


## Lleva el casillero a esa posición del orden, corriendo a los que estaban entre las dos. Es lo
## único que ocupa o vacía un casillero: el borde entre ocupados y vacíos lo mueve la góndola.
func _poner_en_el_orden(producto: Producto, casillero: int, posicion: int) -> void:
	var orden := _orden_de(producto)
	var donde := orden.find(casillero)
	if donde < 0:
		return
	orden.remove_at(donde)
	orden.insert(posicion, casillero)
	_orden[producto.id] = orden


## Un tramo del orden como lista de casilleros, de menor a mayor.
func _ordenados(tramo: PackedInt32Array) -> Array[int]:
	var casilleros: Array[int] = []
	casilleros.assign(Array(tramo))
	casilleros.sort()
	return casilleros


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
