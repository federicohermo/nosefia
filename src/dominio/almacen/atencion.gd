## Atender a un comprador: cuánto marca la caja, cuánto pagó, qué falta en góndola y cómo se
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
## **Se puede despachar sin vender**, y eso desencadena `CAJA` de `REPONER`: la góndola arranca
## vacía la primera noche, así que exigir la venta dejaría dos obligatorias encadenadas y la
## primera imposible.
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
const TEXTO_DE_LOS_FALTANTES := "No hay en góndola: %s"

var _comprador: Comprador
var _inventario: Inventario
var _despachada: bool = false
var _vendida: bool = false


func _init(comprador: Comprador, inventario: Inventario) -> void:
	_comprador = comprador
	_inventario = inventario


func comprador() -> Comprador:
	return _comprador


## Lo que marca la caja por este pedido.
func total_de_la_caja() -> int:
	return _comprador.pedido().total()


## Lo que sobra o lo que falta, con signo: positivo si pagó de más, negativo si pagó de menos.
func diferencia() -> int:
	return _comprador.paga() - total_de_la_caja()


## Los productos del pedido que la góndola no puede cubrir, en el orden del ticket.
##
## Mira **sólo la góndola**: lo que está en el depósito no se puede vender por la ventanilla, hay
## que reponerlo primero. Es la misma frontera que usa `Inventario.cobrar()`, y por eso esta
## lista explica exactamente por qué ese cobro va a fallar.
func faltantes_del_pedido() -> Array[Producto]:
	var faltan: Array[Producto] = []
	var pedido := _comprador.pedido()
	for producto in pedido.productos():
		if (
			pedido.unidades_de(producto)
			> _inventario.unidades(producto, Inventario.Ubicacion.GONDOLA)
		):
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
## Descuenta por `Inventario.cobrar()`, que es **todo o nada**: sin stock no se mueve una sola
## unidad. Descontar lo que se pueda dejaría un estado que el jugador no puede distinguir de una
## venta completa.
func cobrar() -> Resultado:
	if _despachada:
		return Resultado.YA_DESPACHADA
	if not _inventario.cobrar(_comprador.pedido()):
		return Resultado.SIN_STOCK
	_despachada = true
	_vendida = true
	return Resultado.COBRADA


## Lo despacha sin cobrarle nada, y devuelve `true` **sólo si lo despachó ahora**.
##
## No toca el inventario: el comprador se va con las manos vacías y la caja no registra nada. Es
## lo que hace que la obligatoria se pueda cumplir la primera noche.
func despachar_sin_vender() -> bool:
	if _despachada:
		return false
	_despachada = true
	return true


## Lo que se lee en la ventanilla: el ticket, el total, lo que puso y la diferencia.
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


## El cartel de lo que no hay en góndola, o vacío si está todo.
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
