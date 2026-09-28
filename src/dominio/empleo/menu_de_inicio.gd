## Qué opciones muestra el menú de inicio, en qué orden, y cuáles se pueden elegir.
class_name MenuDeInicio
extends RefCounted

enum Opcion { NUEVO_JUEGO, CONTINUAR, CONFIGURACIONES, LOGROS, SALIR }

const HABILITADAS: Array[Opcion] = [Opcion.NUEVO_JUEGO, Opcion.SALIR]

var _es_web: bool
var _hay_guardado: bool


## En la web no se ofrece salir: la página no puede cerrar su pestaña.
func _init(es_web: bool, hay_guardado: bool = false) -> void:
	_es_web = es_web
	_hay_guardado = hay_guardado


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
	if opcion == Opcion.CONTINUAR:
		return _hay_guardado
	return HABILITADAS.has(opcion)


## Empezar de nuevo borra el guardado, y eso no se deshace.
func nuevo_juego_pide_confirmacion() -> bool:
	return _hay_guardado
