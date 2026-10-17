## El contenido compartido es inmutable; cada atención crea su propio cursor de diálogo.
class_name DialogosDeCompradores
extends Resource

enum Personaje { NINGUNO, TIN, TIA, FEDE, MIA }

const GRACIAS := "Gracias."
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
	var productos: Array[Producto] = []
	var cantidades: Array[int] = []
	for producto in pedido.productos():
		var cantidad := pedido.unidades_de(producto) if rechazo else recepcion.pendientes(producto)
		if cantidad > 0:
			productos.append(producto)
			cantidades.append(cantidad)
	if rechazo:
		return una(RECHAZO + _quiero(productos, cantidades))
	if productos.is_empty():
		return una(PIDE_EL_RECIBO)
	return una(_quiero(productos, cantidades))


static func una(texto: String) -> Dialogo:
	return Dialogo.new(PackedStringArray([texto]))


static func _quiero(productos: Array[Producto], cantidades: Array[int]) -> String:
	var marcadores: PackedStringArray = []
	for indice in productos.size():
		var producto := productos[indice]
		var texto := SubtitulosAlExaminar.de_producto(producto.id).trim_suffix(".")
		texto = texto.left(1).to_lower() + texto.substr(1)
		if cantidades[indice] > 1:
			texto = ("dos" if cantidades[indice] == 2 else "tres") + " " + producto.nombre
		marcadores.append("[color=#e4f850]" + texto + "[/color]")
	if marcadores.size() == 1:
		return "Quiero " + marcadores[0] + "."
	if marcadores.size() == 2:
		return "Quiero " + marcadores[0] + " y " + marcadores[1] + "."
	return "Quiero " + marcadores[0] + ", " + marcadores[1] + " y " + marcadores[2] + "."
