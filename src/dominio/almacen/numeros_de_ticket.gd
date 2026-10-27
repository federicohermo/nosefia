## Sortea el número de cada ticket, y ninguno se repite en la partida.
##
## Lo lleva la partida y no el generador: el generador nace de nuevo cada jornada, y con él se
## perdería la cuenta de lo ya sorteado.
class_name NumerosDeTicket
extends RefCounted

## El mayor número de ticket: cuatro cifras, como `N°0887`.
const MAXIMO := 9999

var _azar := RandomNumberGenerator.new()
var _sorteados: Dictionary[int, bool] = {}


## Sin semilla, cada partida sortea distinto.
func _init(semilla: int = -1) -> void:
	if semilla < 0:
		_azar.randomize()
	else:
		_azar.seed = semilla


## Si ya salieron todos, empieza otra vuelta: es más de lo que una noche alcanza a imprimir.
func sortear() -> int:
	if _sorteados.size() >= MAXIMO:
		_sorteados.clear()
	var numero := _azar.randi_range(1, MAXIMO)
	while _sorteados.has(numero):
		numero = numero % MAXIMO + 1
	_sorteados[numero] = true
	return numero
