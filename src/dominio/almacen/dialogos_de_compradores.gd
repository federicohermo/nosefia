## El contenido compartido es inmutable; cada atención crea su propio cursor de diálogo.
class_name DialogosDeCompradores
extends Resource

enum Personaje { NINGUNO, TIN, TIA, FEDE, MIA }

@export var tin := PackedStringArray()
@export var tia := PackedStringArray()
@export var fede := PackedStringArray()
@export var mia := PackedStringArray()
@export var despedida_tin := PackedStringArray()
@export var despedida_tia := PackedStringArray()
@export var despedida_fede := PackedStringArray()
@export var despedida_mia := PackedStringArray()
@export var recordatorio_tin: String = ""
@export var recordatorio_tia: String = ""


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


func recordatorio(
	personaje: int, rechazo: bool = false, pedido: Venta = null, productos_completos: bool = false
) -> Dialogo:
	var texto := ""
	match personaje:
		Personaje.TIN:
			texto = recordatorio_tin
		Personaje.TIA:
			texto = recordatorio_tia
		Personaje.FEDE, Personaje.MIA:
			texto = (
				"Gracias. Me das el recibo, ¿por favor?"
				if productos_completos
				else _texto_del_pedido(pedido)
			)
	var prefijo := "Yo no pedí esto. " if rechazo else ""
	return Dialogo.new(PackedStringArray([prefijo + texto]))


func _texto_del_pedido(pedido: Venta) -> String:
	if pedido == null:
		return ""
	var marcadores: PackedStringArray = []
	for producto in pedido.productos():
		var cantidad := pedido.unidades_de(producto)
		var texto := SubtitulosAlExaminar.de_producto(producto.id).trim_suffix(".")
		texto = texto.left(1).to_lower() + texto.substr(1)
		if cantidad > 1:
			texto = ("dos" if cantidad == 2 else "tres") + " " + producto.nombre
		marcadores.append("[color=#e4f850]" + texto + "[/color]")
	if marcadores.size() == 1:
		return "Quiero " + marcadores[0] + "."
	if marcadores.size() == 2:
		return "Quiero " + marcadores[0] + " y " + marcadores[1] + "."
	return "Quiero " + marcadores[0] + ", " + marcadores[1] + " y " + marcadores[2] + "."
