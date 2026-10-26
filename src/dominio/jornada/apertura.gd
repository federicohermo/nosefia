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
## dos tandas. `de_una_fila` dice qué productos no pueden abrir vacía ninguna de las dos, y
## `alturas`, qué estante queda justo arriba de cuál.
static func inventario_de_la_jornada(
	jornada: int,
	compradores: Array[Comprador],
	casilleros_totales: Dictionary[Producto.Id, int],
	casilleros_reponibles: Dictionary[Producto.Id, int],
	azar: RandomNumberGenerator,
	de_una_fila: Dictionary[Producto.Id, bool] = {},
	alturas: Dictionary[Producto.Id, PackedFloat32Array] = {}
) -> Inventario:
	var tandas: Dictionary[Producto.Id, Array] = {}
	for producto in Catalogo.todos():
		var reponibles: int = casilleros_reponibles.get(producto.id, 0)
		var totales: int = casilleros_totales.get(producto.id, 0)
		tandas[producto.id] = [
			PackedInt32Array(range(reponibles)), PackedInt32Array(range(reponibles, totales))
		]
	var vacios := vacios_de_la_jornada(jornada, compradores, tandas, de_una_fila, azar, alturas)
	return inventario_con_faltantes(
		faltantes_de(vacios), casilleros_totales, Catalogo.de_la_jornada(jornada)
	)


## Qué casilleros abren vacíos esa noche, producto por producto.
##
## Recibe los mismos compradores de Atención y la fuente de azar de esta sesión. `tandas` trae,
## de cada producto, los casilleros de la fila de adelante de cada tanda, la reponible primero.
## `de_una_fila` dice qué productos tienen tandas de una sola fila (BR-STK-025). `alturas` trae, de
## cada producto, la altura de cada tanda en el mismo orden que `tandas`.
##
## **Los vacíos de un producto van juntos**: un bloque de casilleros seguidos de una tanda al azar
## entre las que lo reciben entero, y sólo si ninguna lo recibe se parte en otra. Un producto de
## una fila no abre vacía entera ninguna tanda (`sin_tandas_vacias()`); uno de dos filas sí puede.
static func vacios_de_la_jornada(
	jornada: int,
	compradores: Array[Comprador],
	tandas: Dictionary[Producto.Id, Array],
	de_una_fila: Dictionary[Producto.Id, bool],
	azar: RandomNumberGenerator,
	alturas: Dictionary[Producto.Id, PackedFloat32Array] = {}
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
		var sorteados := _sortear_vacios(tandas[id], faltantes[id], azar)
		if de_una_fila.get(id, false):
			sorteados = sin_tandas_vacias(
				sorteados, tandas[id], alturas.get(id, PackedFloat32Array()), azar
			)
		vacios[id] = sorteados
	return vacios


## Cuántos casilleros de cada producto pueden abrir vacíos: todos los de adelante, menos uno por
## cada tanda de un producto de una fila, que no puede abrir vacía entera.
static func casilleros_vaciables(
	tandas: Dictionary[Producto.Id, Array], de_una_fila: Dictionary[Producto.Id, bool]
) -> Dictionary[Producto.Id, int]:
	var vaciables: Dictionary[Producto.Id, int] = {}
	for id: Producto.Id in tandas:
		var cuantos := 0
		var con_casilleros := 0
		for tanda: PackedInt32Array in tandas[id]:
			cuantos += tanda.size()
			con_casilleros += 0 if tanda.is_empty() else 1
		vaciables[id] = cuantos - (con_casilleros if de_una_fila.get(id, false) else 0)
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


## Un bloque de casilleros seguidos en una tanda al azar entre las que lo reciben entero. Sólo si
## no entra en ninguna se parte: la tanda elegida se llena y lo que sobra sigue como bloque en otra.
static func _sortear_vacios(tandas: Array, cuantos: int, azar: RandomNumberGenerator) -> Array:
	var con_lugar: Array[int] = []
	for indice in tandas.size():
		if not tandas[indice].is_empty():
			con_lugar.append(indice)
	var vacios: Array[int] = []
	var faltan := cuantos
	while faltan > 0:
		var entran: Array[int] = con_lugar.filter(
			func(indice: int) -> bool: return tandas[indice].size() >= faltan
		)
		var opciones: Array[int] = con_lugar if entran.is_empty() else entran
		var elegida := opciones[azar.randi_range(0, opciones.size() - 1)]
		con_lugar.erase(elegida)
		var tanda: PackedInt32Array = tandas[elegida]
		var largo := mini(faltan, tanda.size())
		var desde := azar.randi_range(0, tanda.size() - largo)
		for casillero in tanda.slice(desde, desde + largo):
			vacios.append(casillero)
		faltan -= largo
	vacios.sort()
	return vacios


## Ninguna tanda de un producto de una fila abre vacía entera (BR-STK-024).
##
## De abajo hacia arriba, la tanda que los vacíos dejarían sin una unidad conserva la primera, y
## el vacío que sobra pasa al estante de justo arriba, o al de justo abajo si no hay uno arriba.
## Si ese estante no puede ceder uno sin quedar vacío entero, sigue al siguiente en el mismo
## sentido. `casilleros_vaciables()` garantiza que alguno puede; si en ese sentido no queda
## ninguno, se busca en el contrario (OQ-STK-010). `alturas` va en el orden de `tandas`; sin ellas,
## ese orden es el de abajo hacia arriba. El vacío que llega queda pegado a los que ya tiene.
static func sin_tandas_vacias(
	vacios: Array, tandas: Array, alturas: PackedFloat32Array, azar: RandomNumberGenerator
) -> Array[int]:
	var resultado: Array[int] = []
	resultado.assign(vacios)
	var orden := _de_abajo_hacia_arriba(tandas, alturas)
	for lugar in orden.size():
		var tanda: PackedInt32Array = tandas[orden[lugar]]
		if _vaciados_de(tanda, resultado) < tanda.size():
			continue
		resultado.erase(tanda[0])
		var receptora := _receptora(tandas, orden, lugar, resultado)
		assert(receptora >= 0, "ninguna tanda del producto puede ceder un casillero más")
		resultado.append(_pegado_a_los_vacios(tandas[receptora], resultado, azar))
	resultado.sort()
	return resultado


## Los índices de las tandas con casilleros, de la más baja a la más alta.
static func _de_abajo_hacia_arriba(tandas: Array, alturas: PackedFloat32Array) -> Array[int]:
	var orden: Array[int] = []
	for indice in tandas.size():
		if not tandas[indice].is_empty():
			orden.append(indice)
	var altura := func(indice: int) -> float:
		return alturas[indice] if indice < alturas.size() else float(indice)
	orden.sort_custom(
		func(a: int, b: int) -> bool:
			return altura.call(a) < altura.call(b) or (altura.call(a) == altura.call(b) and a < b)
	)
	return orden


## La tanda que recibe el vacío que sobra de `orden[lugar]`: la primera que puede ceder uno, hacia
## arriba, o hacia abajo si es la más alta. Con -1 si ninguna puede.
static func _receptora(tandas: Array, orden: Array[int], lugar: int, vacios: Array[int]) -> int:
	var sentido := 1 if lugar < orden.size() - 1 else -1
	for paso in [sentido, -sentido]:
		var vecina: int = lugar + paso
		while vecina >= 0 and vecina < orden.size():
			var tanda: PackedInt32Array = tandas[orden[vecina]]
			if tanda.size() - _vaciados_de(tanda, vacios) > 1:
				return orden[vecina]
			vecina += paso
	return -1


## Un casillero ocupado de la tanda, pegado a su bloque de vacíos, o cualquiera si no tiene.
static func _pegado_a_los_vacios(
	tanda: PackedInt32Array, vacios: Array[int], azar: RandomNumberGenerator
) -> int:
	var lugares: Array[int] = []
	for lugar in tanda.size():
		if vacios.has(tanda[lugar]):
			lugares.append(lugar)
	var candidatos: Array[int] = []
	if lugares.is_empty():
		candidatos.assign(range(tanda.size()))
	else:
		if lugares.front() > 0:
			candidatos.append(lugares.front() - 1)
		if lugares.back() < tanda.size() - 1:
			candidatos.append(lugares.back() + 1)
	return tanda[candidatos[azar.randi_range(0, candidatos.size() - 1)]]


static func _vaciados_de(tanda: PackedInt32Array, vacios: Array[int]) -> int:
	var vaciados := 0
	for casillero in tanda:
		vaciados += 1 if vacios.has(casillero) else 0
	return vaciados


## Sólo lee los pedidos ya construidos; sus objetos siguen siendo los de Atención.
static func pedidos_de(compradores: Array[Comprador]) -> Dictionary[Producto.Id, int]:
	var pedidos: Dictionary[Producto.Id, int] = {}
	for comprador in compradores:
		for producto in comprador.pedido().productos():
			pedidos[producto.id] = (
				pedidos.get(producto.id, 0) + comprador.pedido().unidades_de(producto)
			)
	return pedidos
