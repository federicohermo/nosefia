## Cuenta los vencidos tirados al contenedor: cada uno una sola vez, y sólo los que el juego
## declara vencidos.
class_name TareaDeLosVencidos
extends RefCounted

var _total: int
var _desechados: int = 0


func _init(cuantos: int) -> void:
	_total = maxi(0, cuantos)


## Los vencidos que pide desechar la jornada, o ninguno si no los declara.
static func de_la_jornada(jornada: int) -> TareaDeLosVencidos:
	var cuantos := 0
	if Apertura.pide(jornada, Tarea.Tipo.DESECHAR_VENCIDOS):
		cuantos = ReglasDelEstante.CINDOLOR_VENCIDOS
	return TareaDeLosVencidos.new(cuantos)


func total() -> int:
	return _total


func desechados() -> int:
	return _desechados


func completada() -> bool:
	return _total > 0 and _desechados >= _total


## Cuenta el objeto tirado si es un vencido que todavía falta, y devuelve si lo contó. Cualquier
## otro objeto no cambia nada.
func desechar(objeto: ObjetoDelAlmacen) -> bool:
	if objeto == null or not objeto.vencido or _desechados >= _total:
		return false
	_desechados += 1
	return true
