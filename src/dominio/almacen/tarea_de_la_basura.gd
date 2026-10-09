## Cuenta las bolsas tiradas, por identidad y una sola vez cada una.
class_name TareaDeLaBasura
extends RefCounted

enum Resultado { DEPOSITADA, YA_DEPOSITADA, NO_ES_BASURA }

var _ids: Array[StringName] = []
var _depositadas: Array[StringName] = []


func _init(ids: Array[StringName]) -> void:
	for id in ids:
		if id == ObjetoDelAlmacen.SIN_ID or _ids.has(id):
			continue
		_ids.append(id)


static func de_la_jornada() -> TareaDeLaBasura:
	return TareaDeLaBasura.new(ReglasDeLaBasura.ids_de_las_bolsas())


func bolsas() -> int:
	return _ids.size()


func depositadas() -> int:
	return _depositadas.size()


func esta_depositada(id: StringName) -> bool:
	return _depositadas.has(id)


func completada() -> bool:
	return depositadas() == bolsas()


func depositar(id: StringName) -> Resultado:
	if not _ids.has(id):
		return Resultado.NO_ES_BASURA
	if esta_depositada(id):
		return Resultado.YA_DEPOSITADA
	_depositadas.append(id)
	return Resultado.DEPOSITADA
