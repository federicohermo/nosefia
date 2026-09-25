class_name Uso
extends RefCounted

enum Efecto { NINGUNO, LIMPIAR }

const MANCHA: StringName = &"mancha"

var _combinaciones: Dictionary[Array, Efecto] = {}


static func para_el_almacen() -> Uso:
	var uso := Uso.new()
	uso.registrar(ReglasDeLaLimpieza.ID_DEL_TRAPEADOR, MANCHA, Efecto.LIMPIAR)
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
