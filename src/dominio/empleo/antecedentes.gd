## Lo que la devolución de Enrique cuenta entre noches: las fallas de cada obligatoria fija, los
## llamados de cada motivo y cuántas noches seguidas terminaron sin sumar medios.
##
## La particular no suma fallas: su Tarea depende de la jornada, no de una cuenta.
class_name Antecedentes
extends RefCounted

## Las cuatro obligatorias que se repiten todas las noches, en el orden de las Tareas 1 a 4.
const FIJAS: Array[Tarea.Tipo] = [
	Tarea.Tipo.CAJA, Tarea.Tipo.REGISTRAR, Tarea.Tipo.REPONER, Tarea.Tipo.LIMPIAR
]

const CLAVE_DE_FALLAS := "fallas"
const CLAVE_DE_LLAMADOS := "llamados"
const CLAVE_DE_NOCHES_SIN_SUMAR := "noches_sin_sumar"

var _fallas: Dictionary[Tarea.Tipo, int] = {}
var _llamados: Dictionary[Partida.Llamado, int] = {}
var _noches_sin_sumar: int = 0


## Anota una noche cerrada. Cada obligatoria y cada motivo cuentan una sola vez por noche.
func anotar_noche(
	sin_cumplir: Array[Tarea.Tipo], llamados: Array[Partida.Llamado], medios_sumados: int
) -> void:
	for tipo: Tarea.Tipo in FIJAS:
		if sin_cumplir.has(tipo):
			_fallas[tipo] = fallas(tipo) + 1
	for motivo: Partida.Llamado in Partida.Llamado.values():
		if llamados.has(motivo):
			_llamados[motivo] = self.llamados(motivo) + 1
	_noches_sin_sumar = 0 if medios_sumados > 0 else _noches_sin_sumar + 1


func fallas(tipo: Tarea.Tipo) -> int:
	return _fallas.get(tipo, 0)


func llamados(motivo: Partida.Llamado) -> int:
	return _llamados.get(motivo, 0)


## Si hubo algún llamado en la partida, contando la última noche anotada.
func hubo_llamados() -> bool:
	return not _llamados.is_empty()


## R: cuántas noches seguidas terminaron sin sumar medios, contando la última.
func noches_sin_sumar() -> int:
	return _noches_sin_sumar


## Las claves son los nombres del `enum` y no su número: reordenarlo no puede cambiar qué cuenta
## se lee en cada obligatoria.
func a_datos() -> Dictionary:
	var fallas_por_nombre := {}
	for tipo: Tarea.Tipo in _fallas:
		fallas_por_nombre[Tarea.Tipo.keys()[tipo]] = _fallas[tipo]
	var llamados_por_nombre := {}
	for motivo: Partida.Llamado in _llamados:
		llamados_por_nombre[Partida.Llamado.keys()[motivo]] = _llamados[motivo]
	return {
		CLAVE_DE_FALLAS: fallas_por_nombre,
		CLAVE_DE_LLAMADOS: llamados_por_nombre,
		CLAVE_DE_NOCHES_SIN_SUMAR: _noches_sin_sumar,
	}


## Una clave desconocida, una cuenta que no es un entero positivo o un campo de otro tipo se
## ignoran sin descartar lo demás.
static func desde(datos: Dictionary) -> Antecedentes:
	var antecedentes := Antecedentes.new()
	var fallas_leidas: Variant = datos.get(CLAVE_DE_FALLAS)
	if fallas_leidas is Dictionary:
		for tipo: Tarea.Tipo in FIJAS:
			var cuenta: Variant = fallas_leidas.get(Tarea.Tipo.keys()[tipo])
			if cuenta is int and cuenta > 0:
				antecedentes._fallas[tipo] = cuenta
	var llamados_leidos: Variant = datos.get(CLAVE_DE_LLAMADOS)
	if llamados_leidos is Dictionary:
		for motivo: Partida.Llamado in Partida.Llamado.values():
			var cuenta: Variant = llamados_leidos.get(Partida.Llamado.keys()[motivo])
			if cuenta is int and cuenta > 0:
				antecedentes._llamados[motivo] = cuenta
	var noches: Variant = datos.get(CLAVE_DE_NOCHES_SIN_SUMAR)
	if noches is int and noches >= 0:
		antecedentes._noches_sin_sumar = noches
	return antecedentes
