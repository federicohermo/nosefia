## Qué casilleros de la góndola tienen una unidad vencida.
##
## La marca es del casillero mientras la unidad está puesta, y viaja con la unidad cuando se la
## agarra: quien la agarra la `desmarca()` y quien la vuelve a poner la `marca()` (BR-STK-052).
class_name VencidosDeLaGondola
extends RefCounted

## `id` → los casilleros de su fila que tienen una unidad vencida.
var _casilleros: Dictionary[Producto.Id, Array] = {}


func _init(de_apertura: Dictionary[Producto.Id, Array] = {}) -> void:
	for id: Producto.Id in de_apertura:
		_casilleros[id] = de_apertura[id].duplicate()


## Los casilleros de ese producto con una unidad vencida, de menor a mayor.
func casilleros(producto: Producto) -> Array[int]:
	var marcados: Array[int] = []
	if producto != null:
		marcados.assign(_casilleros.get(producto.id, []))
	marcados.sort()
	return marcados


## Cuántas unidades vencidas hay puestas, de cualquier producto.
func cuantos() -> int:
	var total := 0
	for id: Producto.Id in _casilleros:
		total += _casilleros[id].size()
	return total


func marcar(producto: Producto, casillero: int) -> void:
	var marcados: Array = _casilleros.get(producto.id, [])
	marcados.append(casillero)
	_casilleros[producto.id] = marcados


## Quita la marca de ese casillero, y devuelve si la tenía.
func desmarcar(producto: Producto, casillero: int) -> bool:
	var marcados: Array = _casilleros.get(producto.id, [])
	if not marcados.has(casillero):
		return false
	marcados.erase(casillero)
	_casilleros[producto.id] = marcados
	return true
