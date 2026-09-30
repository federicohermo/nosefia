## Qué hace cada cosa en la mano sobre cada otra: el efecto declarado para ese par, o ninguno.
class_name Uso
extends RefCounted

enum Efecto { NINGUNO, LIMPIAR, LLENAR, TENIR, MOJAR, VACIAR }

const MANCHA: StringName = &"mancha"

var _combinaciones: Dictionary[Array, Efecto] = {}


## Los gestos de limpiar, uno por cada paso de la ficha: el balde se llena en el lavatorio, cada
## jabón lo tiñe, la mopa se moja en él, el balde se vacía en el inodoro y la mopa borra.
static func para_el_almacen() -> Uso:
	var uso := Uso.new()
	var balde := ReglasDeLaLimpieza.ID_DEL_BALDE
	var mopa := ReglasDeLaLimpieza.ID_DE_LA_MOPA
	uso.registrar(balde, ReglasDeLaLimpieza.ID_DEL_LAVATORIO, Efecto.LLENAR)
	for jabon: StringName in ReglasDeLaLimpieza.JABONES:
		uso.registrar(jabon, balde, Efecto.TENIR)
	uso.registrar(mopa, balde, Efecto.MOJAR)
	uso.registrar(balde, ReglasDeLaLimpieza.ID_DEL_INODORO, Efecto.VACIAR)
	uso.registrar(mopa, MANCHA, Efecto.LIMPIAR)
	return uso


func registrar(herramienta: StringName, objetivo: StringName, efecto: Efecto) -> bool:
	var par := [herramienta, objetivo]
	if efecto == Efecto.NINGUNO or _combinaciones.has(par):
		return false
	_combinaciones[par] = efecto
	return true


func resolver(herramienta: StringName, objetivo: StringName) -> Efecto:
	if herramienta == ObjetoDelAlmacen.SIN_ID:
		return Efecto.NINGUNO
	return _combinaciones.get([herramienta, objetivo], Efecto.NINGUNO)


func cantidad() -> int:
	return _combinaciones.size()
