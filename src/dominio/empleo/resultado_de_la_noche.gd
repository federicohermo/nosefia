## Lo que la partida recuerda de una noche de prueba: cuántos clientes se fueron mal atendidos y
## qué obligatorias fijas quedaron sin cumplir al cerrar (BR-EMP-041).
##
## Es el dato y nada más: qué mensaje sale de él lo decide `CondicionesDelJefe`. Separados, el
## resultado de una noche sirve a cualquier jornada que lo lea sin saber qué texto elige.
class_name ResultadoDeLaNoche
extends RefCounted

const CLAVE_DE_MAL_ATENDIDOS := "mal_atendidos"
const CLAVE_DE_SIN_CUMPLIR := "sin_cumplir"

var mal_atendidos: int
var _sin_cumplir: Array[Tarea.Tipo]


func _init(clientes_mal_atendidos: int, sin_cumplir: Array[Tarea.Tipo]) -> void:
	mal_atendidos = clientes_mal_atendidos
	_sin_cumplir = sin_cumplir.duplicate()


func cumplio(tipo: Tarea.Tipo) -> bool:
	return not _sin_cumplir.has(tipo)


## Las obligatorias van por nombre, como en `Antecedentes`: reordenar el `enum` no cambia qué
## se lee.
func a_datos() -> Dictionary:
	var nombres: Array = []
	for tipo: Tarea.Tipo in _sin_cumplir:
		nombres.append(Tarea.Tipo.keys()[tipo])
	return {CLAVE_DE_MAL_ATENDIDOS: mal_atendidos, CLAVE_DE_SIN_CUMPLIR: nombres}


## `null` si el dato no es una noche. Un nombre desconocido se ignora sin descartar la noche.
static func desde_datos(dato: Variant) -> ResultadoDeLaNoche:
	if not dato is Dictionary:
		return null
	var cuantos: Variant = dato.get(CLAVE_DE_MAL_ATENDIDOS)
	var nombres: Variant = dato.get(CLAVE_DE_SIN_CUMPLIR)
	if not cuantos is int or cuantos < 0 or not nombres is Array:
		return null
	var sin_cumplir: Array[Tarea.Tipo] = []
	for nombre: Variant in nombres:
		if nombre is String and Tarea.Tipo.has(nombre):
			sin_cumplir.append(Tarea.Tipo[nombre])
	return ResultadoDeLaNoche.new(cuantos, sin_cumplir)
