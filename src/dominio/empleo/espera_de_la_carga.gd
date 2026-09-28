## Cuándo la pantalla de carga deja entrar al almacén: con la carga terminada y el mínimo
## cumplido. Con el almacén ya cargado, sin el mínimo la pantalla duraría un cuadro.
class_name EsperaDeLaCarga
extends RefCounted

## En segundos.
const MINIMO := 1.0

var _transcurrido := 0.0
var _cargada := false


func avanzar(segundos: float) -> void:
	_transcurrido += segundos


func terminar_carga() -> void:
	_cargada = true


func puede_entrar() -> bool:
	return _cargada and _transcurrido >= MINIMO
