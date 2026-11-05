## El contenido compartido es inmutable; cada atención crea su propio cursor de diálogo.
class_name DialogosDeCompradores
extends Resource

enum Personaje { NINGUNO, TIN, TIA, FEDE, MIA, CAMI }

const FALTA := "Gracias. Falta que me des "
const YA_ENTREGADO := "Gracias, pero ya me habías dado esto."
const PEDIDO_DEL_TICKET := "Me das el ticket, ¿por favor?"
const PIDE_EL_TICKET := "Gracias. " + PEDIDO_DEL_TICKET
const RECHAZO := "Yo no pedí esto. "
const SALUDO := "Buenas noches. "
const DESPEDIDA := "Muchas gracias."

@export var tin := PackedStringArray()
@export var tia := PackedStringArray()
@export var fede := PackedStringArray()
@export var mia := PackedStringArray()
@export var cami := PackedStringArray()
@export var despedida_tin := PackedStringArray()
@export var despedida_tia := PackedStringArray()
@export var despedida_fede := PackedStringArray()
@export var despedida_mia := PackedStringArray()
@export var despedida_cami := PackedStringArray()


## Con el pedido, las entradas pueden escribir `{pedido}` y `{producto1}`, `{producto2}`, etc.
func inicial(personaje: int, pedido: Venta = null) -> Dialogo:
	return _crear_dialogo(_entradas_de(personaje, false), pedido)


func despedida(personaje: int, pedido: Venta = null) -> Dialogo:
	return _crear_dialogo(_entradas_de(personaje, true), pedido)


func tiene_guion(personaje: int) -> bool:
	return not _entradas_de(personaje, false).is_empty()


func _entradas_de(personaje: int, de_despedida: bool) -> PackedStringArray:
	match personaje:
		Personaje.TIN:
			return despedida_tin if de_despedida else tin
		Personaje.TIA:
			return despedida_tia if de_despedida else tia
		Personaje.FEDE:
			return despedida_fede if de_despedida else fede
		Personaje.MIA:
			return despedida_mia if de_despedida else mia
		Personaje.CAMI:
			return despedida_cami if de_despedida else cami
	return PackedStringArray()


## Las referencias a un producto fijo guardan el número de Producto.Id para sobrevivir a cualquier
## renombre.
static func _crear_dialogo(entradas: PackedStringArray, pedido: Venta) -> Dialogo:
	var nombres: Dictionary[String, String] = {}
	for producto: Producto in Catalogo.todos():
		nombres[str(producto.id)] = producto.nombre
	if pedido != null:
		nombres["pedido"] = _enumeracion(pedido, pedido.unidades_de)
		var numero := 1
		for producto: Producto in pedido.productos():
			nombres["producto%d" % numero] = _presentado(producto, pedido.unidades_de(producto))
			numero += 1
	var resueltas := PackedStringArray()
	for entrada: String in entradas:
		resueltas.append(entrada.format(nombres))
	return Dialogo.new(resueltas)


## Lo que dice cualquier comprador al hablarle: lo que todavía le falta, o el ticket si sólo falta
## él. Al rechazar, antepone el rechazo a lo que todavía le falta.
static func recordatorio(
	pedido: Venta, recepcion: RecepcionDeCompra, rechazo: bool = false
) -> Dialogo:
	var faltan := _enumeracion(pedido, recepcion.pendientes)
	if rechazo:
		return una(RECHAZO + (PEDIDO_DEL_TICKET if faltan.is_empty() else "Quiero " + faltan + "."))
	return una(PIDE_EL_TICKET if faltan.is_empty() else "Quiero " + faltan + ".")


## Lo que dice al recibir un producto: agradece y nombra lo que falta, o pide el ticket.
static func agradecimiento(pedido: Venta, recepcion: RecepcionDeCompra) -> Dialogo:
	var faltan := _enumeracion(pedido, recepcion.pendientes)
	return una(PIDE_EL_TICKET if faltan.is_empty() else FALTA + faltan + ".")


## Lo que dice al atenderlo quien no trae guion propio: saluda y nombra su pedido entero.
static func apertura_predeterminada(pedido: Venta) -> Dialogo:
	return una(SALUDO + "Quiero " + _enumeracion(pedido, pedido.unidades_de) + ".")


static func despedida_predeterminada() -> Dialogo:
	return una(DESPEDIDA)


static func una(texto: String) -> Dialogo:
	return Dialogo.new(PackedStringArray([texto]))


## Los productos del pedido con cantidad positiva, en su orden: «a», «a y b» o «a, b y c». Vacío
## si no queda ninguno.
static func _enumeracion(pedido: Venta, cantidad: Callable) -> String:
	var marcadores: PackedStringArray = []
	for producto in pedido.productos():
		var cuantas: int = cantidad.call(producto)
		if cuantas > 0:
			marcadores.append(_presentado(producto, cuantas))
	if marcadores.size() < 2:
		return "".join(marcadores)
	return ", ".join(marcadores.slice(0, -1)) + " y " + marcadores[-1]


## Un producto como lo nombra el pedido, con sólo su nombre en amarillo.
static func _presentado(producto: Producto, cuantas: int) -> String:
	var nombre := "[color=#e4f850]" + producto.nombre + "[/color]"
	if cuantas > 1:
		return ("dos" if cuantas == 2 else "tres") + " " + nombre
	var texto := SubtitulosAlExaminar.de_producto(producto.id).trim_suffix(".")
	texto = texto.left(1).to_lower() + texto.substr(1)
	return texto.replace(producto.nombre, nombre)
