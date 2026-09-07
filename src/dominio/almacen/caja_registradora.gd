## La mitad *registrar* de la caja: qué productos hay que pasar hoy y cuáles ya se pasaron.
##
## **Es `Tarea.Tipo.REGISTRAR` y no `Tarea.Tipo.CAJA`**, y la frontera va escrita porque las dos
## se llaman «caja»: cobrarle a un comprador es de la ventanilla del 013, y lo de acá es pasar
## por el sistema los productos del día.
##
## **Los del día son tres y no los seis del catálogo**: es lo que hace de esto una tarea y no un
## panel. Con los seis, registrar sería recorrer la lista entera y no habría nada que elegir — y
## el minuto que cuesta dejaría de disputarse con la investigación.
##
## **Los faltantes se preguntan, no se guardan.** Cuál es el umbral de reposición lo decide el
## 005 y `Inventario.faltantes()` lo aplica: una lista propia acá se separaría de la del
## inventario y el jugador repondría la góndola con la pantalla pidiéndole lo mismo.
class_name CajaRegistradora
extends RefCounted

## Cuáles son los tres de hoy.
##
## **Esta clase no los elige**: entran por parámetro al `_init`, y esta lista es la que la jornada
## usa. Es lo que permite que un test se arme con uno o con cinco sin que mover el balance rompa
## casos que no hablan de él.
const PRODUCTOS_DEL_DIA := [Producto.Id.YERBA, Producto.Id.FIDEOS, Producto.Id.GASEOSA]

var _inventario: Inventario

## En el orden en que se listan en la app. Sin `id` repetido: uno duplicado daría una tarea que
## se completa registrando menos productos de los que la lista muestra.
var _del_dia: Array[Producto] = []

## Los `id` ya pasados. Se indexa por `id` y nunca por instancia: `Catalogo.de()` construye un
## producto nuevo en cada llamada, así que dos yerbas son objetos distintos y por instancia la
## misma yerba contaría dos veces.
var _registrados: Array[Producto.Id] = []


func _init(inventario: Inventario, del_dia: Array[Producto]) -> void:
	_inventario = inventario
	for producto in del_dia:
		if producto == null or _tiene(producto.id):
			continue
		_del_dia.append(producto)


## Los productos que hay que registrar hoy, armados desde el catálogo.
##
## Saltea el `id` sin fila para no meter un `null` en la lista: un `null` ahí dejaría una tarea
## imposible de terminar, con el jugador registrando todo lo que puede tocar y la caja diciendo
## que todavía falta.
static func productos_del_dia() -> Array[Producto]:
	var lista: Array[Producto] = []
	for id: Producto.Id in PRODUCTOS_DEL_DIA:
		var producto := Catalogo.de(id)
		if producto == null:
			continue
		lista.append(producto)
	return lista


## Los del día, **como copia**.
func del_dia() -> Array[Producto]:
	return _del_dia.duplicate()


func registrados() -> int:
	return _registrados.size()


func esta_registrado(producto: Producto) -> bool:
	return producto != null and _registrados.has(producto.id)


## Pasa el producto por la caja, y devuelve `true` **sólo si lo registró ahora**.
##
## Un producto ajeno a los del día devuelve `false` sin registrarlo: registrar cualquier cosa
## dejaría la tarea cumplible con tres latas del estante, o sea sin nada que buscar.
func registrar(producto: Producto) -> bool:
	if producto == null or not _tiene(producto.id) or esta_registrado(producto):
		return false
	_registrados.append(producto.id)
	return true


## Si ya se pasaron todos los del día.
##
## Se compara contra la lista que se recibió y nunca contra un número escrito acá. Una lista vacía
## está completa por vacuidad, que es lo que corresponde: no quedó nada sin registrar.
func completada() -> bool:
	return registrados() == _del_dia.size()


## Lo que le falta a la góndola, preguntándoselo al inventario.
##
## Es exactamente `Inventario.faltantes()` y no una cuenta propia: el umbral es del 005, y
## copiarlo acá daría dos listas que se separan el día que se rebalancee, sin que nada avise.
func faltantes() -> Array[Producto]:
	return _inventario.faltantes()


func _tiene(id: Producto.Id) -> bool:
	for producto in _del_dia:
		if producto.id == id:
			return true
	return false
