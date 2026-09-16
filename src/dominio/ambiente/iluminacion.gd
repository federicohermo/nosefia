## Qué luminarias del almacén están encendidas.
##
## **Es dominio y no decorado.** La tensión del juego es aritmética —cada minuto investigando es
## un minuto que no se dedica a las tareas— y la luz entra en esa cuenta: un pasillo a oscuras
## encarece cualquier tarea que pase por ahí. Por eso el estado vive acá, donde se puede ejercer
## sin levantar una escena, y no en el `.tscn` donde nace sin test.
##
## **Guarda un estado por luminaria y no un contador.** Un contador se lee más corto y miente en
## el borde: apagar dos veces la misma lámpara le restaría dos. El caso que lo ejerce está escrito.
##
## Qué evento del juego apaga una luminaria no se decide acá ni todavía: esto es la palanca.
class_name Iluminacion
extends Resource

## Cuántas luminarias tiene el salón. Son las tres tiras que el modelo trae unidas al almacén, y
## este número es el único lugar donde están contadas: la escena monta tantas luces como diga acá.
const LUMINARIAS := 3

var _encendidas: Array[bool] = []


func _init() -> void:
	for _indice in LUMINARIAS:
		_encendidas.append(true)


## Cuántas luminarias están encendidas.
func encendidas() -> int:
	return _encendidas.count(true)


## Si esa luminaria está encendida. Un índice que no existe contesta `false` y no rompe nada.
func esta_encendida(indice: int) -> bool:
	if not _es_valido(indice):
		return false
	return _encendidas[indice]


func apagar(indice: int) -> void:
	_poner(indice, false)


func encender(indice: int) -> void:
	_poner(indice, true)


func _poner(indice: int, valor: bool) -> void:
	if _es_valido(indice):
		_encendidas[indice] = valor


func _es_valido(indice: int) -> bool:
	return indice >= 0 and indice < LUMINARIAS
