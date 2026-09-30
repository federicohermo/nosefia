## El nodo que repone adentro del motor: reserva una unidad del depósito, la pone en la mano y se
## la ofrece al estante cuando el jugador la deposita.
##
## **Traduce, no decide.** No sabe cuánto le entra a la góndola, ni qué productos van ahí, ni
## cuánto cuesta reponer, ni qué recibe una caja: son preguntas de `dominio/`, que es donde
## tienen test. Los `if` de este archivo son el valor que devolvieron el estante o la caja, y el
## estado nulo del cableado.
##
## **La unidad viaja en la mano y no en el inventario.** `pedir_retirar()` la saca de su caja
## —el estante la anota afuera, y sigue contada en el depósito— y el stock recién se mueve cuando
## `pedir_colocar_de_la_mano()` la coloca en el casillero que se eligió. `pedir_devolver()` la
## mete de vuelta en su caja y anula esa salida, sin mover mercadería. Al revés, soltar la unidad
## en el piso dejaría la góndola contando mercadería que el jugador nunca apoyó.
## `pedir_agarrar_de_la_gondola()` es el camino de vuelta: la unidad de un casillero pasa a la
## mano, contada como una que salió de su caja.
##
## **No lleva un flag de «ya la conté».** Después de cada cambio de la góndola le pide al reloj que
## complete la tarea si el estante quedó lleno, y que la descumpla si no: el `Turno` ya sabe que
## la segunda vez no cuenta y que descumplir una sin cumplir no descuenta —devuelve `false` en los
## dos casos—. Un flag acá sería esa misma regla escrita en la capa que traduce, o sea una regla
## del juego sin test, y los dos gates darían verde sobre ella.
class_name Repositor
extends Node

signal producto_colocado(producto: Producto, completos: int)
signal colocacion_rechazada(motivo: Estante.Rechazo)
signal unidad_colocada(nodo: Node3D, producto: Producto, unidades: int)

## Los dos entran por `@export` y no como autoload ni por `get_node()` hacia arriba: está medido
## que `gate_de_capas.py` no ve un autoload nombrado por su nombre global, así que esa puerta
## cruzaría capas sin dejar rastro.
@export var reloj: RelojDelTurno
@export var agarre: Agarre

var _estante: Estante = null


## Le entrega al repositor el estante de la noche.
##
## La instancia se recibe y no se construye acá porque el estante necesita el inventario de la
## jornada, y quién abre una jornada es la escena. Es lo que permite que cada noche empiece con
## la góndola que dice su jornada sin que este nodo sepa qué es una jornada.
func arrancar(un_estante: Estante) -> void:
	if agarre != null and agarre.manos().sostenido() is UnidadDeProducto:
		agarre.entregar()
	_estante = un_estante


## El estante que se está reponiendo, para que quien dibuje pregunte en vez de copiar el estado.
func estante() -> Estante:
	return _estante


## La caja del depósito de ese producto, contada sobre el estante de esta noche.
##
## **Se arma en cada pregunta y no se guarda.** Lo que tiene sale del depósito del estante que
## recibió `arrancar()`, así que una guardada seguiría contando el de la noche anterior.
func caja(id: Producto.Id) -> ContenidoDeLaCaja:
	return ContenidoDeLaCaja.new(Catalogo.de(id), _estante)


## Saca una unidad de la caja de ese producto y la pone en la mano, colgada de `nodo`. Devuelve
## si la puso.
##
## La mano se pregunta antes que la caja: con la mano llena, sacar anotaría afuera una unidad
## que nadie lleva.
func pedir_retirar(id: Producto.Id, nodo: Node3D) -> bool:
	var candidato := UnidadDeProducto.new(Catalogo.de(id))
	if agarre.manos().motivo_de_rechazo(candidato) != Manos.Rechazo.NINGUNO:
		return false
	var unidad := caja(id).sacar()
	if unidad == null:
		return false
	nodo.set(ReglasDeLosObjetos.PROPIEDAD_DATOS, unidad)
	return agarre.pedir_agarrar(unidad, nodo)


## Mete en la caja de ese producto la unidad que hay en la mano, y devuelve el cuerpo que sacó de
## la mano, o `null` si la caja no la recibió.
##
## Si la caja no la recibe, la unidad sigue en la mano: sale de ella sólo cuando la caja ya la
## contó. Qué recibe la caja lo decide ella, y el cuerpo lo esconde quien lo dibuja.
func pedir_devolver(id: Producto.Id) -> Node3D:
	var unidad := agarre.manos().sostenido() as UnidadDeProducto
	if not caja(id).meter(unidad):
		return null
	return agarre.entregar()


## Coloca la unidad de la mano en ese casillero de `destino`, o en el primero vacío. Si el
## estante la rechaza, avisa el motivo y la unidad sigue en la mano.
func pedir_colocar_de_la_mano(
	destino: Producto = null, casillero: int = Estante.PRIMERO_VACIO
) -> void:
	var unidad := agarre.manos().sostenido() as UnidadDeProducto
	var motivo := _estante.colocar_unidad(unidad, destino, casillero)
	if motivo != Estante.Rechazo.NINGUNO:
		colocacion_rechazada.emit(motivo)
		return
	var nodo := agarre.entregar()
	unidad_colocada.emit(nodo, unidad.producto, _estante.unidades_en_gondola(unidad.producto))
	producto_colocado.emit(unidad.producto, _estante.productos_completos())
	_revisar_reponer()


## Saca de la góndola la unidad de ese casillero y la pone en la mano, colgada de `nodo`.
## Devuelve si la puso.
##
## La mano se pregunta antes que el estante, igual que al sacar de la caja: con la mano llena,
## el casillero quedaría vacío y la unidad afuera, sin nadie que la lleve.
func pedir_agarrar_de_la_gondola(id: Producto.Id, casillero: int, nodo: Node3D) -> bool:
	var producto := Catalogo.de(id)
	var candidato := UnidadDeProducto.new(producto)
	if agarre.manos().motivo_de_rechazo(candidato) != Manos.Rechazo.NINGUNO:
		return false
	var unidad := _estante.agarrar(producto, casillero)
	if unidad == null:
		return false
	nodo.set(ReglasDeLosObjetos.PROPIEDAD_DATOS, unidad)
	_revisar_reponer()
	return agarre.pedir_agarrar(unidad, nodo)


## Cumple reponer si la góndola quedó llena, y la descumple si no: una unidad agarrada de un
## estante completo lo deja con un casillero vacío (BR-STK-033).
func _revisar_reponer() -> void:
	var reponer := reloj.obligatoria(Tarea.Tipo.REPONER)
	if _estante.completada():
		reloj.completar(reponer)
	else:
		reloj.descumplir(reponer)
