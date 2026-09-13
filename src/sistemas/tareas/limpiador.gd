## El nodo que limpia adentro del motor: recibe la pasada, se la pasa al dominio y publica lo que
## el dominio contestó.
##
## **Traduce, no decide.** Cuántas pasadas lleva una mancha, con qué se limpia y cuándo el piso
## está listo son preguntas de `PisoDelLocal`, que es donde tienen test. Los `if` de este archivo
## son el valor que devolvió el dominio y el estado nulo del cableado.
##
## **No lleva un flag de «ya la conté»**: le pide al reloj que complete `Tarea.Tipo.LIMPIAR` cada
## vez que el piso queda limpio, y el `Turno` ya sabe que la segunda vez no cuenta. Un flag acá
## sería esa misma regla escrita en la capa que traduce.
class_name Limpiador
extends Node

signal pasada_dada(zona: PisoDelLocal.Zona, restantes: int)
signal mancha_limpiada(zona: PisoDelLocal.Zona)
signal pasada_rechazada(motivo: PisoDelLocal.Resultado)

## Entra por `@export` y no como autoload: está medido que `gate_de_capas.py` no ve un autoload
## nombrado por su nombre global, así que esa puerta cruzaría capas sin dejar rastro.
@export var reloj: RelojDelTurno

var _piso: PisoDelLocal = null
var _uso := Uso.para_el_almacen()


## Le entrega al limpiador el piso de la noche.
##
## El piso se recibe y no se construye acá para que cada jornada arranque sucia sin que este nodo
## sepa qué es una jornada. Guardar el piso entre noches está fuera de alcance a propósito.
func arrancar(piso: PisoDelLocal) -> void:
	_piso = piso


func piso() -> PisoDelLocal:
	return _piso


## Pasa el trapeador por una zona con lo que sea que el jugador lleve en la mano.
##
## **Devuelve exactamente lo que contestó el dominio** en vez de traducirlo a un `bool`: los tres
## rechazos se leen distinto adelante del jugador —«eso no es un trapeador», «acá ya está
## limpio»— y aplanarlos daría un solo cartel para dos situaciones.
func pedir_pasada(zona: PisoDelLocal.Zona, id_en_la_mano: StringName) -> PisoDelLocal.Resultado:
	if _piso == null or reloj == null:
		# Un cableado incompleto es un `.tscn` mal armado y no un rechazo del juego: sale por el
		# panel de depuración, que es donde se lee.
		push_error("Limpiador sin cablear: revisar almacen.tscn y almacen.gd")
		return PisoDelLocal.Resultado.SIN_TRAPEADOR
	if _uso.resolver(id_en_la_mano, Uso.MANCHA) != Uso.Efecto.LIMPIAR:
		pasada_rechazada.emit(PisoDelLocal.Resultado.SIN_TRAPEADOR)
		return PisoDelLocal.Resultado.SIN_TRAPEADOR
	var resultado := _piso.pasar(zona, id_en_la_mano)
	if resultado == PisoDelLocal.Resultado.SIN_TRAPEADOR:
		pasada_rechazada.emit(resultado)
		return resultado
	if resultado == PisoDelLocal.Resultado.YA_ESTABA_LIMPIA:
		pasada_rechazada.emit(resultado)
		return resultado
	pasada_dada.emit(zona, _piso.pasadas_restantes(zona))
	if resultado == PisoDelLocal.Resultado.MANCHA_LIMPIADA:
		mancha_limpiada.emit(zona)
	if _piso.esta_limpio():
		reloj.completar(reloj.obligatoria(Tarea.Tipo.LIMPIAR))
	return resultado
