## Atender a un comprador: cuánto marca la caja, cuánto pagó, qué no se puede vender y cómo se
## despacha.
##
## **La caja no vuelve a sumar.** El total sale de `Venta.total()`, que ya es donde vive esa
## cuenta: una segunda suma acá daría el mismo resultado hasta el día que el catálogo cambie, y
## ahí las dos ventanas dirían distinto sin un solo error. Por eso este archivo no nombra el dato
## con el que se sumaría, y hay un caso que lo verifica sobre el texto.
##
## **La diferencia tiene signo**: `paga() - total_de_la_caja()`. Un `abs()` en el camino dejaría
## al comprador que paga de menos indistinguible del que paga de más, que es exactamente la cosa
## que este spec vino a poner delante del jugador.
##
## **En las jornadas posteriores se puede despachar sin vender**: un pedido puede superar los
## vendibles, y
## exigir la venta dejaría a ese comprador sin forma de irse.
##
## Es la mitad de atender que se ejerce sin levantar una escena: acá no hay un solo `Node`.
class_name Atencion
extends RefCounted

## Cómo terminó un intento de cobro. Es un conjunto cerrado y por eso es un `enum`: un `String`
## suelto dejaría a la pantalla con un cartel que no se muestra nunca.
enum Resultado { COBRADA, SIN_STOCK, YA_DESPACHADA }

## Los textos que se leen en la ventanilla viven acá y no en el panel, por el mismo motivo que
## los de `ParteDeCierre`: en `ui/` una regla nace sin test y ningún gate lo dice.
const TEXTO_DE_LA_LINEA := "%d × %s"
const TEXTO_DEL_TOTAL := "Total: $%d"
const TEXTO_DE_LO_QUE_PAGA := "Paga: $%d"
const TEXTO_DE_LA_DIFERENCIA := "Diferencia: %+d"
const TEXTO_DE_LOS_FALTANTES := "No hay para vender: %s"

var _comprador: Comprador
var _inventario: Inventario
var _despachada: bool = false
var _vendida: bool = false
var _recepcion: RecepcionDeCompra = null
var _dialogo: Dialogo = null
var _presentado: bool = false
var _inicial_terminada: bool = false


func interactuar(objeto: ObjetoDelAlmacen) -> RecepcionDeCompra.Resultado:
	if not fisica() or _despachada:
		return RecepcionDeCompra.Resultado.BLOQUEADA
	if (
		_dialogo != null
		and not _dialogo.terminado()
		and (not _inicial_terminada or _vendida or objeto == null)
	):
		_dialogo.avanzar()
		if _dialogo.terminado():
			_inicial_terminada = true
			_despachada = _vendida
		return RecepcionDeCompra.Resultado.DIALOGO
	if not _presentado:
		_presentado = true
		_dialogo = _comprador.dialogos.inicial(_comprador.personaje)
		return RecepcionDeCompra.Resultado.DIALOGO
	if objeto == null:
		_dialogo = _comprador.dialogos.recordatorio(_comprador.personaje)
		return RecepcionDeCompra.Resultado.DIALOGO
	var resultado := RecepcionDeCompra.Resultado.RECHAZADA
	if not objeto is UnidadDeProducto or _inventario.esta_afuera(objeto as UnidadDeProducto):
		resultado = _recepcion.recibir(objeto, _inicial_terminada)
	if resultado == RecepcionDeCompra.Resultado.RECHAZADA:
		_dialogo = _comprador.dialogos.recordatorio(_comprador.personaje, true)
	elif resultado == RecepcionDeCompra.Resultado.ACEPTADA:
		_dialogo = null
	elif resultado == RecepcionDeCompra.Resultado.COMPLETA:
		_vendida = _inventario.vender_unidades(_recepcion.unidades())
		_dialogo = _comprador.dialogos.despedida(_comprador.personaje)
	return resultado


func dialogo() -> Dialogo:
	return _dialogo


func puede_abandonar() -> bool:
	return _dialogo == null or _dialogo.puede_abandonar()


func vencer() -> void:
	if not _vendida:
		for unidad in _recepcion.unidades():
			_inventario.desechar(unidad)
		_despachada = true
		_dialogo = null


func fisica() -> bool:
	return _recepcion != null


func _init(comprador: Comprador, inventario: Inventario) -> void:
	_comprador = comprador
	_inventario = inventario
	if comprador.tiene_horario():
		_recepcion = RecepcionDeCompra.new(comprador.pedido())


func comprador() -> Comprador:
	return _comprador


## Lo que marca la caja por este pedido.
func total_de_la_caja() -> int:
	return _comprador.pedido().total()


## Lo que sobra o lo que falta, con signo: positivo si pagó de más, negativo si pagó de menos.
func diferencia() -> int:
	return _comprador.paga() - total_de_la_caja()


## Los productos del pedido que superan sus vendibles, en el orden del pedido.
##
## Mira `Inventario.vendibles()` y no la góndola: es la misma frontera que usa
## `Inventario.cobrar()`, y por eso esta lista explica exactamente por qué ese cobro va a fallar.
func faltantes_del_pedido() -> Array[Producto]:
	var faltan: Array[Producto] = []
	var pedido := _comprador.pedido()
	for producto in pedido.productos():
		if pedido.unidades_de(producto) > _inventario.vendibles(producto):
			faltan.append(producto)
	return faltan


func despachada() -> bool:
	return _despachada


## Si se le vendió de verdad. Lo usa la cuenta de la caja: al que se despachó sin vender no se le
## cobró nada, así que su diferencia no es plata que falte.
func vendida() -> bool:
	return _vendida


## Cobra el pedido y despacha, o dice por qué no pudo.
##
## Descuenta por `Inventario.cobrar()`, que es **todo o nada**: si una línea supera sus
## vendibles no se mueve una sola unidad. Descontar lo que se pueda dejaría un estado que el
## jugador no puede distinguir de una venta completa.
func cobrar() -> Resultado:
	if _despachada or fisica():
		return Resultado.YA_DESPACHADA
	if not _inventario.cobrar(_comprador.pedido()):
		return Resultado.SIN_STOCK
	_despachada = true
	_vendida = true
	return Resultado.COBRADA


## Lo despacha sin cobrarle nada, y devuelve `true` **sólo si lo despachó ahora**.
##
## No toca el inventario: el comprador se va con las manos vacías y la caja no registra nada. Es
## lo que hace que la obligatoria se pueda cumplir con un pedido que supera los vendibles.
func despachar_sin_vender() -> bool:
	if _despachada or fisica():
		return false
	_despachada = true
	return true


## Lo que se lee en la ventanilla: el pedido, el total, lo que puso y la diferencia.
##
## Las líneas no llevan cuánto sale cada cosa a propósito: el número que importa es el total, y
## repartirlo por renglón le daría al jugador la cuenta hecha justo donde el juego puede mentir.
func renglones() -> Array[String]:
	var lineas: Array[String] = []
	var pedido := _comprador.pedido()
	for producto in pedido.productos():
		lineas.append(TEXTO_DE_LA_LINEA % [pedido.unidades_de(producto), producto.nombre])
	lineas.append(TEXTO_DEL_TOTAL % total_de_la_caja())
	lineas.append(TEXTO_DE_LO_QUE_PAGA % _comprador.paga())
	lineas.append(TEXTO_DE_LA_DIFERENCIA % diferencia())
	return lineas


## El cartel de lo que no se puede vender, o vacío si está todo.
##
## Vacío y no un `null`: quien lo pinta no tiene que distinguir dos formas de la misma respuesta.
func aviso() -> String:
	var faltan := faltantes_del_pedido()
	if faltan.is_empty():
		return ""
	var nombres: Array[String] = []
	for producto in faltan:
		nombres.append(producto.nombre)
	return TEXTO_DE_LOS_FALTANTES % ", ".join(nombres)
