## El contenido compartido es inmutable; cada atención crea su propio cursor de diálogo.
class_name DialogosDeCompradores
extends Resource

enum Personaje { NINGUNO, TIN, TIA, FEDE, MIA }

const FALTA := "Gracias. Falta que me des "
const YA_ENTREGADO := "Gracias, pero ya me habías dado esto."
const PIDE_EL_RECIBO := "Gracias. Me das el recibo, ¿por favor?"
const RECHAZO := "Yo no pedí esto. "

@export var tin := PackedStringArray()
@export var tia := PackedStringArray()
@export var fede := PackedStringArray()
@export var mia := PackedStringArray()
@export var despedida_tin := PackedStringArray()
@export var despedida_tia := PackedStringArray()
@export var despedida_fede := PackedStringArray()
@export var despedida_mia := PackedStringArray()


func inicial(personaje: int) -> Dialogo:
	match personaje:
		Personaje.TIN:
			return Dialogo.new(tin)
		Personaje.TIA:
			return Dialogo.new(tia)
		Personaje.FEDE:
			return Dialogo.new(fede)
		Personaje.MIA:
			return Dialogo.new(mia)
	return Dialogo.new()


func despedida(personaje: int) -> Dialogo:
	match personaje:
		Personaje.TIN:
			return Dialogo.new(despedida_tin)
		Personaje.TIA:
			return Dialogo.new(despedida_tia)
		Personaje.FEDE:
			return Dialogo.new(despedida_fede)
		Personaje.MIA:
			return Dialogo.new(despedida_mia)
	return Dialogo.new()


## Lo que dice cualquier comprador al hablarle: lo que todavía le falta, o el recibo si sólo falta
## el ticket. Al rechazar, antepone el rechazo al pedido entero.
static func recordatorio(
	pedido: Venta, recepcion: RecepcionDeCompra, rechazo: bool = false
) -> Dialogo:
	if rechazo:
		return una(RECHAZO + "Quiero " + _enumeracion(pedido, pedido.unidades_de) + ".")
	var faltan := _enumeracion(pedido, recepcion.pendientes)
	return una(PIDE_EL_RECIBO if faltan.is_empty() else "Quiero " + faltan + ".")


## Lo que dice al recibir un producto: agradece y nombra lo que falta, o pide el recibo.
static func agradecimiento(pedido: Venta, recepcion: RecepcionDeCompra) -> Dialogo:
	var faltan := _enumeracion(pedido, recepcion.pendientes)
	return una(PIDE_EL_RECIBO if faltan.is_empty() else FALTA + faltan + ".")


static func una(texto: String) -> Dialogo:
	return Dialogo.new(PackedStringArray([texto]))


## Los productos del pedido con cantidad positiva, en su orden: «a», «a y b» o «a, b y c». Vacío
## si no queda ninguno.
static func _enumeracion(pedido: Venta, cantidad: Callable) -> String:
	var marcadores: PackedStringArray = []
	for producto in pedido.productos():
		var cuantas: int = cantidad.call(producto)
		if cuantas <= 0:
			continue
		var texto := SubtitulosAlExaminar.de_producto(producto.id).trim_suffix(".")
		texto = texto.left(1).to_lower() + texto.substr(1)
		if cuantas > 1:
			texto = ("dos" if cuantas == 2 else "tres") + " " + producto.nombre
		marcadores.append("[color=#e4f850]" + texto + "[/color]")
	if marcadores.size() < 2:
		return "".join(marcadores)
	return ", ".join(marcadores.slice(0, -1)) + " y " + marcadores[-1]
