## Cómo se abre una jornada: qué tareas pide el jefe esta noche, con cuánto tiempo se arranca y
## con qué mercadería.
##
## La apertura declara las fijas y la particular de cada jornada desde una sola tabla.
class_name Apertura
extends RefCounted

const FIJAS: Array[Tarea.Tipo] = [
	Tarea.Tipo.CAJA, Tarea.Tipo.REGISTRAR, Tarea.Tipo.LIMPIAR, Tarea.Tipo.REPONER
]
## Las noches de introducción que todavía no piden todas las fijas.
const INTRODUCCION := {
	1: [Tarea.Tipo.CAJA, Tarea.Tipo.REGISTRAR],
	2: [Tarea.Tipo.CAJA, Tarea.Tipo.REGISTRAR, Tarea.Tipo.REPONER],
}
const PARTICULARES := {
	ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA: [Tarea.Tipo.ORDENAR_LAS_CAJAS],
	ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA + 1: [Tarea.Tipo.SACAR_LA_BASURA],
}


## Las fijas de la jornada y su particular declarada, siempre con instancias nuevas.
static func obligatorias(jornada: int) -> Array[Tarea]:
	var tipos: Array[Tarea.Tipo] = []
	tipos.assign(INTRODUCCION.get(jornada, FIJAS))
	tipos.append_array(PARTICULARES.get(jornada, []))
	var lista: Array[Tarea] = []
	for tipo in tipos:
		lista.append(Tarea.new(tipo))
	return lista


static func pide(jornada: int, tipo: Tarea.Tipo) -> bool:
	return tipo in INTRODUCCION.get(jornada, FIJAS) or tipo in PARTICULARES.get(jornada, [])


static func cantidad_de_obligatorias(jornada: int) -> int:
	return obligatorias(jornada).size()


## El turno de la noche, con el presupuesto entero y las obligatorias que se le declaran.
##
## **Recibe la lista y no la vuelve a construir**: es lo que hace que el reloj pueda entregarle
## al 008 la misma instancia de `Tarea` que el turno está contando.
static func turno_de_la_jornada(obligatorias: Array[Tarea]) -> Turno:
	return Turno.new(Reglas.DURACION_DEL_TURNO, obligatorias)


## La mercadería de una noche en la que sólo importa cuántas unidades faltan, no en qué
## casilleros: el sorteo de `vacios_de_la_jornada()` con la reponible de adelante y las fijas como
## dos tandas.
static func inventario_de_la_jornada(
	jornada: int,
	compradores: Array[Comprador],
	casilleros_totales: Dictionary[Producto.Id, int],
	casilleros_reponibles: Dictionary[Producto.Id, int],
	azar: RandomNumberGenerator
) -> Inventario:
	var tandas: Dictionary[Producto.Id, Array] = {}
	for producto in Catalogo.todos():
		var reponibles: int = casilleros_reponibles.get(producto.id, 0)
		var totales: int = casilleros_totales.get(producto.id, 0)
		tandas[producto.id] = [
			PackedInt32Array(range(reponibles)), PackedInt32Array(range(reponibles, totales))
		]
	var vacios := vacios_de_la_jornada(jornada, compradores, tandas, {}, azar)
	return inventario_con_faltantes(
		faltantes_de(vacios), casilleros_totales, Catalogo.de_la_jornada(jornada)
	)


## Qué casilleros abren vacíos esa noche, producto por producto.
##
## Recibe los mismos compradores de Atención y la fuente de azar de esta sesión. `tandas` trae,
## de cada producto, los casilleros de la fila de adelante de cada tanda, la reponible primero.
## `de_una_fila` dice qué productos tienen tandas de una sola fila (BR-STK-025).
##
## **Cada casillero tiene la misma probabilidad, en cualquier tanda.** Lo único que se descarta es
## un reparto que deja vacía entera una tanda que no puede abrir así: la reponible, y todas si el
## producto es de una fila. Se sortea de nuevo en vez de mover un vacío, que dejaría de ser parejo.
static func vacios_de_la_jornada(
	jornada: int,
	compradores: Array[Comprador],
	tandas: Dictionary[Producto.Id, Array],
	de_una_fila: Dictionary[Producto.Id, bool],
	azar: RandomNumberGenerator
) -> Dictionary[Producto.Id, Array]:
	var vacios: Dictionary[Producto.Id, Array] = {}
	if jornada == ReglasDeLaPartida.PRIMERA_JORNADA:
		return vacios
	var vaciables := casilleros_vaciables(tandas, de_una_fila)
	var presentes: Dictionary[Producto.Id, int] = {}
	for producto in Catalogo.de_la_jornada(jornada):
		presentes[producto.id] = vaciables.get(producto.id, 0)
	var faltantes := faltantes_al_azar(pedidos_de(compradores), presentes, azar)
	for id: Producto.Id in faltantes:
		vacios[id] = _sortear_vacios(tandas[id], de_una_fila.get(id, false), faltantes[id], azar)
	return vacios


## Cuántos casilleros de cada producto pueden abrir vacíos: todos los de adelante, menos uno por
## cada tanda que no puede abrir vacía entera.
static func casilleros_vaciables(
	tandas: Dictionary[Producto.Id, Array], de_una_fila: Dictionary[Producto.Id, bool]
) -> Dictionary[Producto.Id, int]:
	var vaciables: Dictionary[Producto.Id, int] = {}
	for id: Producto.Id in tandas:
		var cuantos := 0
		for tanda: PackedInt32Array in tandas[id]:
			cuantos += tanda.size()
		vaciables[id] = cuantos - _a_salvo(tandas[id], de_una_fila.get(id, false)).size()
	return vaciables


## Cuántas unidades le faltan a cada producto con esos vacíos.
static func faltantes_de(vacios: Dictionary[Producto.Id, Array]) -> Dictionary[Producto.Id, int]:
	var faltantes: Dictionary[Producto.Id, int] = {}
	for id: Producto.Id in vacios:
		faltantes[id] = vacios[id].size()
	return faltantes


## La mercadería de una noche con esos faltantes: el depósito de cada producto del catálogo con
## su caja llena, y su góndola con los casilleros de su fila menos lo que le falta.
##
## **Un faltante más grande que la caja no se acomoda**: la caja trae lo que trae, y reponer ese
## producto no se podría terminar. Es un error de los datos, y lo detecta el test que recorre
## las jornadas, no este código. Uno más grande que su fila deja la góndola en cero, que es lo
## que `Inventario.ingresar()` hace con una cantidad que no es positiva.
static func inventario_con_faltantes(
	faltantes: Dictionary[Producto.Id, int],
	casilleros: Dictionary[Producto.Id, int],
	productos: Array[Producto]
) -> Inventario:
	var inventario := Inventario.new(productos, casilleros)
	for producto in productos:
		inventario.ingresar(
			producto, Inventario.Ubicacion.DEPOSITO, ReglasDelEstante.UNIDADES_POR_CAJA
		)
		var falta: int = faltantes.get(producto.id, 0)
		inventario.ingresar(
			producto, Inventario.Ubicacion.GONDOLA, inventario.casilleros(producto) - falta
		)
	return inventario


static func cajas_apiladas(jornada: int) -> bool:
	return Tarea.Tipo.ORDENAR_LAS_CAJAS in PARTICULARES.get(jornada, [])


static func productos_con_cajas_apiladas(jornada: int) -> Array[Producto.Id]:
	var identidades: Array[Producto.Id] = []
	if cajas_apiladas(jornada):
		for producto in Catalogo.todos():
			if producto.id not in Catalogo.PRODUCTOS_DE_PRUEBA:
				identidades.append(producto.id)
	return identidades


## Muestreo sin reemplazo: cada índice restante tiene la misma probabilidad.
static func faltantes_al_azar(
	pedidos: Dictionary[Producto.Id, int],
	casilleros_que_pueden_faltar: Dictionary[Producto.Id, int],
	azar: RandomNumberGenerator
) -> Dictionary[Producto.Id, int]:
	var maximos: Dictionary[Producto.Id, int] = {}
	var elegibles: Array[Producto.Id] = []
	for producto in Catalogo.todos():
		var maximo := mini(
			ReglasDelEstante.UNIDADES_POR_CAJA - pedidos.get(producto.id, 0),
			casilleros_que_pueden_faltar.get(producto.id, 0)
		)
		if maximo >= ReglasDelEstante.MENOS_QUE_FALTA:
			elegibles.append(producto.id)
			maximos[producto.id] = maximo
	var cantidad := azar.randi_range(
		ReglasDelEstante.TIPOS_QUE_FALTAN.x, ReglasDelEstante.TIPOS_QUE_FALTAN.y
	)
	var faltantes: Dictionary[Producto.Id, int] = {}
	for elegido in mini(cantidad, elegibles.size()):
		var indice := azar.randi_range(0, elegibles.size() - 1)
		var id := elegibles[indice]
		elegibles.remove_at(indice)
		faltantes[id] = azar.randi_range(ReglasDelEstante.MENOS_QUE_FALTA, maximos[id])
	return faltantes


## Las tandas que no pueden abrir con todos sus casilleros vacíos: la reponible, y todas si el
## producto es de una sola fila. Una tanda sin casilleros no se cuenta.
static func _a_salvo(tandas: Array, de_una_fila: bool) -> Array:
	var a_salvo: Array = tandas if de_una_fila else tandas.slice(0, 1)
	return a_salvo.filter(func(tanda: PackedInt32Array) -> bool: return not tanda.is_empty())


static func _sortear_vacios(
	tandas: Array, de_una_fila: bool, cuantos: int, azar: RandomNumberGenerator
) -> Array:
	var todos: Array[int] = []
	for tanda: PackedInt32Array in tandas:
		for casillero in tanda:
			todos.append(casillero)
	var a_salvo := _a_salvo(tandas, de_una_fila)
	var vacios := _sacar_al_azar(todos, cuantos, azar)
	while not _deja_uno_en_cada(a_salvo, vacios):
		vacios = _sacar_al_azar(todos, cuantos, azar)
	vacios.sort()
	return vacios


## Muestreo sin reemplazo de `cuantos` casilleros: cada uno de los restantes tiene la misma
## probabilidad.
static func _sacar_al_azar(
	casilleros: Array[int], cuantos: int, azar: RandomNumberGenerator
) -> Array[int]:
	var restantes: Array[int] = casilleros.duplicate()
	var sacados: Array[int] = []
	for _vez in cuantos:
		sacados.append(restantes.pop_at(azar.randi_range(0, restantes.size() - 1)))
	return sacados


static func _deja_uno_en_cada(a_salvo: Array, vacios: Array[int]) -> bool:
	for tanda: PackedInt32Array in a_salvo:
		var ocupado := false
		for casillero in tanda:
			ocupado = ocupado or casillero not in vacios
		if not ocupado:
			return false
	return true


## Sólo lee los pedidos ya construidos; sus objetos siguen siendo los de Atención.
static func pedidos_de(compradores: Array[Comprador]) -> Dictionary[Producto.Id, int]:
	var pedidos: Dictionary[Producto.Id, int] = {}
	for comprador in compradores:
		for producto in comprador.pedido().productos():
			pedidos[producto.id] = (
				pedidos.get(producto.id, 0) + comprador.pedido().unidades_de(producto)
			)
	return pedidos
