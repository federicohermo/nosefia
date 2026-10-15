## El papel impreso conserva los productos de ese momento.
class_name Ticket
extends ObjetoDelAlmacen

const ID := &"ticket"

const TEXTO_AL_EXAMINAR := "Un ticket de compra por %s"

var _renglones: Array[Producto] = []


func _init(productos: Array[Producto] = []) -> void:
	id = ID
	nombre = "Ticket"
	levantable = true
	sonoridad = EntradaSonora.Sonoridad.PAPEL
	_renglones.assign(productos)


func renglones() -> Array[Producto]:
	return _renglones.duplicate()


## Cada producto con su cantidad, en el orden en que aparece por primera vez, separados por
## «, » y el último por « y ».
func texto_al_examinar() -> String:
	var orden: Array[Producto] = []
	var cuantos := {}
	for producto in _renglones:
		if not cuantos.has(producto.id):
			orden.append(producto)
			cuantos[producto.id] = 0
		cuantos[producto.id] += 1
	var partes: Array[String] = []
	for producto in orden:
		partes.append("%d %s" % [cuantos[producto.id], producto.nombre])
	var lista: String = partes.back() if not partes.is_empty() else ""
	if partes.size() > 1:
		lista = ", ".join(partes.slice(0, -1)) + " y " + lista
	return TEXTO_AL_EXAMINAR % lista


static func se_desecha_en(objeto: ObjetoDelAlmacen, destino: StringName) -> bool:
	return objeto is Ticket and destino == ReglasDeLaLimpieza.ID_DEL_INODORO
