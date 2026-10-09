## El papel impreso conserva los productos de ese momento.
class_name Ticket
extends ObjetoDelAlmacen

const ID := &"ticket"

var _renglones: Array[Producto] = []


func _init(productos: Array[Producto] = []) -> void:
	id = ID
	nombre = "Ticket"
	levantable = true
	sonoridad = EntradaSonora.Sonoridad.PAPEL
	_renglones.assign(productos)


func renglones() -> Array[Producto]:
	return _renglones.duplicate()


static func se_desecha_en(objeto: ObjetoDelAlmacen, destino: StringName) -> bool:
	return objeto is Ticket and destino == ReglasDeLaLimpieza.ID_DEL_INODORO
