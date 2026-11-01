## Baja el paquete con el mapa de la noche del corte y lo monta, sin frenar la partida.
##
## En la web el horneado oscuro viaja aparte: son unos 17 MB que sólo usa la sexta noche. Este
## sistema ejecuta la regla de `MapaDelCorte`: pide el archivo, lo deja en `user://` y lo monta
## con `ProjectSettings.load_resource_pack`.
##
## **En escritorio y en los tests no hay nada que bajar**: el mapa viene con el juego y la regla
## arranca lista. Tampoco se baja si el jugador no llegó a esa noche.
##
## **La noche del corte no se rompe.** Si el pedido falla, se reintenta con espera creciente y se
## avisa; quien necesita el mapa espera. El sistema no deja el local sin horneado.
##
## `bajar` y `montar` se inyectan para poder ejercer el reintento sin red ni disco.
class_name DescargaDelMapa
extends Node

## El paquete se montó y el horneado oscuro ya se puede cargar.
signal lista

## Cambió el estado de la descarga: hay que volver a preguntar quién esté esperando.
signal estado_cambiado

const PAQUETE := "user://mapa_del_corte.pck"
const ARCHIVO := "mapa_del_corte.pck"
const HORNEADO := "res://src/escenas/almacen_sin_luz.lmbake"

var regla: MapaDelCorte
## Lo que hace el pedido y lo que monta el paquete. Se reemplazan en los tests.
var bajar: Callable
var montar: Callable

var _espera := 0.0
var _pedido: HTTPRequest


func _init() -> void:
	regla = MapaDelCorte.new(_viene_con_el_juego())
	bajar = _bajar_por_http
	montar = _montar_el_paquete


func _ready() -> void:
	set_process(false)


## Pide el mapa para la jornada que abre, si hace falta. Devuelve si ya está listo.
func preparar(jornada: int) -> bool:
	if not regla.hace_falta(jornada):
		return regla.listo()
	_pedir()
	return regla.listo()


## Llegó el cuerpo del paquete. Montarlo y avisar es lo que cierra la espera.
func llego(cuerpo: PackedByteArray) -> void:
	if not bool(montar.call(cuerpo)):
		no_llego()
		return
	regla.terminar()
	set_process(false)
	lista.emit()


## El intento no llegó.
func no_llego() -> void:
	regla.fallar()
	_espera = 0.0
	set_process(true)
	estado_cambiado.emit()


## Un cuadro de espera: cuando pasa la espera del último fallo, se vuelve a pedir.
func _process(delta: float) -> void:
	_espera += delta
	if not regla.toca_reintentar(_espera):
		return
	_pedir()


func _pedir() -> void:
	if not regla.empezar():
		return
	_espera = 0.0
	bajar.call()


func _bajar_por_http() -> void:
	if _pedido == null:
		_pedido = HTTPRequest.new()
		_pedido.request_completed.connect(_al_terminar_el_pedido)
		add_child(_pedido)
	if _pedido.request(_url_del_paquete()) != OK:
		no_llego()


func _al_terminar_el_pedido(
	resultado: int, codigo: int, _cabeceras: PackedStringArray, cuerpo: PackedByteArray
) -> void:
	if resultado != HTTPRequest.RESULT_SUCCESS or codigo != 200 or cuerpo.is_empty():
		no_llego()
		return
	llego(cuerpo)


func _montar_el_paquete(cuerpo: PackedByteArray) -> bool:
	var archivo := FileAccess.open(PAQUETE, FileAccess.WRITE)
	if archivo == null:
		return false
	archivo.store_buffer(cuerpo)
	archivo.close()
	if not ProjectSettings.load_resource_pack(PAQUETE, true):
		return false
	return FileAccess.file_exists(HORNEADO)


## El paquete viaja al lado del juego: la misma carpeta desde la que se sirvió la página.
func _url_del_paquete() -> String:
	if not OS.has_feature("web"):
		return ARCHIVO
	var carpeta: String = JavaScriptBridge.eval("location.href.replace(/[^/]*$/, '')", true)
	return carpeta + ARCHIVO


static func _viene_con_el_juego() -> bool:
	return FileAccess.file_exists(HORNEADO)
