## La obligatoria de atender por la ventanilla: quién sigue, cuántos van despachados y cuánto se
## desvió la caja en total.
##
## **Recibe la lista de compradores y no sabe cuántos son.** No es un detalle: con el número
## adentro, un test se tendría que armar siempre con los que el balance pide, y mover ese número
## rompería casos que no hablan de él. Es la misma decisión que tomó `Turno` con las obligatorias.
##
## **Se completa con todos despachados, se les haya vendido o no.** Vender exige stock en góndola
## y la góndola arranca vacía, así que exigirlo encadenaría esta obligatoria con reponer y dejaría
## la primera noche imposible de cerrar en cinco.
class_name TareaDeAtender
extends RefCounted

var _compradores: Array[Comprador] = []
var _inventario: Inventario

## Una por comprador que ya llegó a la ventanilla, en orden. Es donde vive el estado: cuántos van
## despachados sale de recorrerlas y no de un contador aparte, que se desincronizaría el día que
## alguien despache por otro camino.
var _atenciones: Array[Atencion] = []


func _init(compradores: Array[Comprador], inventario: Inventario) -> void:
	_compradores = compradores
	_inventario = inventario


## Llama al comprador siguiente y le abre su atención, o devuelve `null` si no queda ninguno.
##
## **Avanza siempre**: quien quiera seguir con el que ya está en la ventanilla pregunta por
## `en_ventanilla()`. Separarlos es lo que permite cerrar y reabrir el panel sin saltearse a
## nadie, sin que la escena tenga que llevar la cuenta.
func atender() -> Comprador:
	if _atenciones.size() >= _compradores.size():
		return null
	var comprador := _compradores[_atenciones.size()]
	_atenciones.append(Atencion.new(comprador, _inventario))
	return comprador


## La atención del último que llegó, o `null` si todavía no llegó nadie.
func atencion() -> Atencion:
	if _atenciones.is_empty():
		return null
	return _atenciones[-1]


## Quién está esperando en la ventanilla ahora mismo: el que llegó y no se despachó, o `null`.
func en_ventanilla() -> Comprador:
	var en_curso := atencion()
	if en_curso == null or en_curso.despachada():
		return null
	return en_curso.comprador()


## Cuántos quedaron despachados, **contando las dos formas**: vender y despachar sin vender
## cuentan igual para el jefe, porque la tarea es atender y no vender.
func despachados() -> int:
	var cuantos := 0
	for atendida in _atenciones:
		if atendida.despachada():
			cuantos += 1
	return cuantos


## Si no quedó nadie sin despachar.
##
## Se compara contra la lista que se recibió y nunca contra un número escrito acá. Una lista
## vacía está completa por vacuidad, que es lo que corresponde: no quedó nadie sin atender.
func completada() -> bool:
	return despachados() == _compradores.size()


## Cuánto se desvió la caja en la noche, sumando **sólo las cobradas** y con signo.
##
## Al que se despachó sin vender no se le cobró nada, así que su diferencia no es plata que falte:
## sumarla haría que despachar sin vender pareciera un robo. Y los signos se conservan: con un
## `abs()` en el camino, uno que paga 500 de más y otro 500 de menos darían 1000 en vez de 0.
func diferencia_acumulada() -> int:
	var suma := 0
	for atendida in _atenciones:
		if atendida.vendida():
			suma += atendida.diferencia()
	return suma
