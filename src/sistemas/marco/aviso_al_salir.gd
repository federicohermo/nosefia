## Registra en la página el aviso «¿Salir del sitio?» mientras corre una noche, y lo retira cuando
## deja de correr.
##
## **Traduce, no decide.** Cuándo se pide lo contesta `ConfirmacionAlSalir`. Acá sólo se lee si la
## noche está en curso y se escribe el `beforeunload` de la página. Fuera de la web no hace nada.
## El navegador muestra el aviso sólo si el jugador interactuó antes con la página.
class_name AvisoAlSalir
extends Node

## Un solo manejador, para que registrarlo dos veces no lo duplique ni retirarlo falle.
const DEFINIR := (
	"window.avisoAlSalir = window.avisoAlSalir "
	+ "|| (e => { e.preventDefault(); e.returnValue = ''; });"
)
const REGISTRAR := "window.addEventListener('beforeunload', window.avisoAlSalir);"
const RETIRAR := "window.removeEventListener('beforeunload', window.avisoAlSalir);"

var _confirmacion := ConfirmacionAlSalir.new()
var _reloj: RelojDelTurno = null
var _escribir: Callable = _escribir_en_la_pagina


## `escribir` recibe `true` para pedir la confirmación y `false` para retirarla.
func vigilar(reloj: RelojDelTurno, escribir: Callable = Callable()) -> void:
	_reloj = reloj
	if escribir.is_valid():
		_escribir = escribir


func _process(_delta: float) -> void:
	if _reloj != null:
		_aplicar(_confirmacion.orden(_reloj.en_curso()))


## Un almacén que se cierra en plena noche —el menú, o una partida nueva— retira el aviso.
func _exit_tree() -> void:
	_aplicar(_confirmacion.orden(false))


func _aplicar(orden: ConfirmacionAlSalir.Orden) -> void:
	if orden != ConfirmacionAlSalir.Orden.NADA:
		_escribir.call(orden == ConfirmacionAlSalir.Orden.PEDIR)


func _escribir_en_la_pagina(pide: bool) -> void:
	if not OS.has_feature("web"):
		return
	JavaScriptBridge.eval(DEFINIR + (REGISTRAR if pide else RETIRAR))
