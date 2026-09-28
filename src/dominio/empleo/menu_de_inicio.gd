## Qué opciones muestra el menú de inicio, en qué orden, y cuáles se pueden elegir.
class_name MenuDeInicio
extends RefCounted

enum Opcion { NUEVO_JUEGO, CONTINUAR, CONFIGURACIONES, LOGROS, SALIR }

const HABILITADAS: Array[Opcion] = [Opcion.NUEVO_JUEGO, Opcion.SALIR]

var _es_web: bool


## En la web no se ofrece salir: la página no puede cerrar su pestaña.
func _init(es_web: bool) -> void:
	_es_web = es_web


func opciones() -> Array[Opcion]:
	var todas: Array[Opcion] = [
		Opcion.CONTINUAR,
		Opcion.NUEVO_JUEGO,
		Opcion.LOGROS,
		Opcion.CONFIGURACIONES,
	]
	if not _es_web:
		todas.append(Opcion.SALIR)
	return todas


func habilitada(opcion: Opcion) -> bool:
	return HABILITADAS.has(opcion)
