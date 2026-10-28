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
## Cuánto pueden diferir dos distancias para contar como iguales, en metros: lo que mide el modelo
## de un casillero a otro de la misma columna, con lugar de sobra para el redondeo.
const HOLGURA_DE_COLUMNA := 0.01
## El producto cuya góndola abre completa y con unidades vencidas en la jornada que lo pide.
const PRODUCTO_CON_VENCIDOS := Producto.Id.CINDOLOR
const PARTICULARES := {
	ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA: [Tarea.Tipo.ORDENAR_LAS_CAJAS],
	ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA + 1: [Tarea.Tipo.SACAR_LA_BASURA],
	ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA + 2: [Tarea.Tipo.DESECHAR_VENCIDOS],
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
## dos tandas. `de_una_fila` dice qué productos no pueden abrir vacía ninguna de las dos.
static func inventario_de_la_jornada(
	jornada: int,
	compradores: Array[Comprador],
	casilleros_totales: Dictionary[Producto.Id, int],
	casilleros_reponibles: Dictionary[Producto.Id, int],
	azar: RandomNumberGenerator,
	de_una_fila: Dictionary[Producto.Id, bool] = {}
) -> Inventario:
	var tandas: Dictionary[Producto.Id, Array] = {}
	for producto in Catalogo.todos():
		var reponibles: int = casilleros_reponibles.get(producto.id, 0)
		var totales: int = casilleros_totales.get(producto.id, 0)
		tandas[producto.id] = [
			PackedInt32Array(range(reponibles)), PackedInt32Array(range(reponibles, totales))
		]
	var vacios := vacios_de_la_jornada(jornada, compradores, tandas, de_una_fila, azar)
	return inventario_con_faltantes(
		faltantes_de(vacios), casilleros_totales, Catalogo.de_la_jornada(jornada)
	)


## Qué casilleros abren vacíos esa noche, producto por producto.
##
## Recibe los mismos compradores de Atención y la fuente de azar de esta sesión. `tandas` trae,
## de cada producto, los casilleros de la fila de adelante de cada tanda, la reponible primero.
## `de_una_fila` dice qué productos tienen tandas de una sola fila (BR-STK-025). `posiciones` trae
## el lugar de cada casillero, tanda por tanda, y sólo decide dónde sigue un faltante que se parte.
##
## **Los vacíos de un producto van juntos**: un bloque de casilleros seguidos de una tanda al azar
## entre las que lo reciben entero, y sólo si ninguna lo recibe se parte en tandas vacías enteras
## y contiguas. Una tanda de un producto de una fila cede un casillero menos: no abre vacía entera.
static func vacios_de_la_jornada(
	jornada: int,
	compradores: Array[Comprador],
	tandas: Dictionary[Producto.Id, Array],
	de_una_fila: Dictionary[Producto.Id, bool],
	azar: RandomNumberGenerator,
	posiciones: Dictionary[Producto.Id, Array] = {}
) -> Dictionary[Producto.Id, Array]:
	var vacios: Dictionary[Producto.Id, Array] = {}
	if jornada == ReglasDeLaPartida.PRIMERA_JORNADA:
		return vacios
	var vaciables := casilleros_vaciables(tandas, de_una_fila)
	var presentes: Dictionary[Producto.Id, int] = {}
	for producto in Catalogo.de_la_jornada(jornada):
		presentes[producto.id] = vaciables.get(producto.id, 0)
	if pide(jornada, Tarea.Tipo.DESECHAR_VENCIDOS):
		presentes[PRODUCTO_CON_VENCIDOS] = 0
	var faltantes := faltantes_al_azar(pedidos_de(compradores), presentes, azar)
	for id: Producto.Id in faltantes:
		vacios[id] = _sortear_vacios(
			tandas[id], de_una_fila.get(id, false), faltantes[id], azar, posiciones.get(id, [])
		)
	return vacios


## Cuántos casilleros de cada producto pueden abrir vacíos: todos los de adelante, menos uno por
## cada tanda de un producto de una fila, que no puede abrir vacía entera.
static func casilleros_vaciables(
	tandas: Dictionary[Producto.Id, Array], de_una_fila: Dictionary[Producto.Id, bool]
) -> Dictionary[Producto.Id, int]:
	var vaciables: Dictionary[Producto.Id, int] = {}
	for id: Producto.Id in tandas:
		var cuantos := 0
		for tanda: PackedInt32Array in tandas[id]:
			cuantos += _cupo_de(tanda, de_una_fila.get(id, false))
		vaciables[id] = cuantos
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


## Qué casilleros de Cindolor abren con una unidad vencida: `CINDOLOR_VENCIDOS` distintos, al azar,
## sólo en la jornada que pide desecharlos. Una góndola con menos casilleros los marca todos.
static func vencidos_de_la_jornada(
	jornada: int, casilleros: Dictionary[Producto.Id, int], azar: RandomNumberGenerator
) -> Dictionary[Producto.Id, Array]:
	var vencidos: Dictionary[Producto.Id, Array] = {}
	if not pide(jornada, Tarea.Tipo.DESECHAR_VENCIDOS):
		return vencidos
	var libres: Array[int] = []
	libres.assign(range(casilleros.get(PRODUCTO_CON_VENCIDOS, 0)))
	var elegidos: Array[int] = []
	while elegidos.size() < ReglasDelEstante.CINDOLOR_VENCIDOS and not libres.is_empty():
		elegidos.append(libres.pop_at(azar.randi_range(0, libres.size() - 1)))
	elegidos.sort()
	vencidos[PRODUCTO_CON_VENCIDOS] = elegidos
	return vencidos


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


## Cuántos casilleros de una tanda pueden abrir vacíos. La tanda de un producto de una fila no
## abre vacía entera; en uno de dos filas, la de atrás dice qué va ahí (BR-STK-024).
static func _cupo_de(tanda: PackedInt32Array, de_una_fila: bool) -> int:
	return tanda.size() - (1 if de_una_fila and not tanda.is_empty() else 0)


## Un bloque de casilleros seguidos en una tanda al azar entre las que lo reciben entero. Sólo si
## no entra en ninguna se parte: las tandas se vacían enteras, una junto a la otra, y la última
## recibe lo que sobra.
##
## **Las tandas se recorren por altura**, de arriba abajo, desde una al azar: el bloque de tandas
## vacías es contiguo y la parcial queda debajo. Sólo si el bloque llega al estante de más abajo,
## sigue por arriba. En un producto de una fila el sentido es el contrario: lo que sobra cae en el
## estante de justo arriba, y abajo sólo si no hay uno arriba. `posiciones` trae el lugar de cada
## casillero de cada tanda, en el orden de `tandas`; sin él todas tienen la misma altura y se
## recorren en el orden de `tandas`. Cada bloque que sigue a otro cae en los casilleros que quedan
## en las mismas columnas.
static func _sortear_vacios(
	tandas: Array,
	de_una_fila: bool,
	cuantos: int,
	azar: RandomNumberGenerator,
	posiciones: Array = []
) -> Array:
	var lugares: Array[PackedVector3Array] = []
	var cupos: Array[int] = []
	var con_lugar: Array[int] = []
	for indice in tandas.size():
		var tanda: PackedInt32Array = tandas[indice]
		lugares.append(_lugares_de(posiciones, indice, tanda.size()))
		cupos.append(_cupo_de(tanda, de_una_fila))
		if cupos[indice] > 0:
			con_lugar.append(indice)
	con_lugar.sort_custom(
		func(uno: int, otro: int) -> bool:
			var alto := _altura_de(lugares[uno])
			var otro_alto := _altura_de(lugares[otro])
			return alto > otro_alto or (alto == otro_alto and uno < otro)
	)
	if de_una_fila:
		con_lugar.reverse()
	var entran: Array[int] = con_lugar.filter(
		func(indice: int) -> bool: return cupos[indice] >= cuantos
	)
	var opciones: Array[int] = con_lugar if entran.is_empty() else entran
	var inicio := con_lugar.find(opciones[azar.randi_range(0, opciones.size() - 1)])
	var recorrido: Array[int] = con_lugar.slice(inicio)
	var del_otro_lado := con_lugar.slice(0, inicio)
	del_otro_lado.reverse()
	recorrido.append_array(del_otro_lado)
	var vacios: Array[int] = []
	var anterior := PackedVector3Array()
	var faltan := cuantos
	for indice in recorrido:
		if faltan == 0:
			break
		var tanda: PackedInt32Array = tandas[indice]
		var largo := mini(faltan, cupos[indice])
		var desde := _el_menor_al_azar(
			_distancias_de_columna(lugares[indice], largo, anterior), azar
		)
		for casillero in tanda.slice(desde, desde + largo):
			vacios.append(casillero)
		anterior = lugares[indice].slice(desde, desde + largo)
		faltan -= largo
	vacios.sort()
	return vacios


## Los lugares de una tanda, o ceros si no se declararon: así no hay cercanía que decida nada.
static func _lugares_de(posiciones: Array, indice: int, tamano: int) -> PackedVector3Array:
	if indice < posiciones.size():
		var declarados: PackedVector3Array = posiciones[indice]
		if declarados.size() == tamano:
			return declarados
	var ceros := PackedVector3Array()
	ceros.resize(tamano)
	return ceros


static func _altura_de(lugares: PackedVector3Array) -> float:
	var suma := 0.0
	for lugar in lugares:
		suma += lugar.y
	return suma / maxi(lugares.size(), 1)


## Cuánto se aparta de las columnas del bloque anterior cada bloque de `largo` casilleros seguidos
## de la tanda: la suma de lo que cada casillero queda lejos, en el plano, de su columna más cerca.
static func _distancias_de_columna(
	lugares: PackedVector3Array, largo: int, anterior: PackedVector3Array
) -> Array[float]:
	var distancias: Array[float] = []
	for desde in lugares.size() - largo + 1:
		var distancia := 0.0
		for lugar in lugares.slice(desde, desde + largo):
			var mas_cerca := INF
			for columna in anterior:
				mas_cerca = minf(
					mas_cerca, Vector2(lugar.x, lugar.z).distance_to(Vector2(columna.x, columna.z))
				)
			distancia += 0.0 if anterior.is_empty() else mas_cerca
		distancias.append(distancia)
	return distancias


## El índice de la distancia más chica; si varias se igualan, una al azar.
static func _el_menor_al_azar(distancias: Array[float], azar: RandomNumberGenerator) -> int:
	var menor: float = distancias.min()
	var empatadas: Array[int] = []
	for indice in distancias.size():
		if distancias[indice] <= menor + HOLGURA_DE_COLUMNA:
			empatadas.append(indice)
	return empatadas[azar.randi_range(0, empatadas.size() - 1)]


## Sólo lee los pedidos ya construidos; sus objetos siguen siendo los de Atención.
static func pedidos_de(compradores: Array[Comprador]) -> Dictionary[Producto.Id, int]:
	var pedidos: Dictionary[Producto.Id, int] = {}
	for comprador in compradores:
		for producto in comprador.pedido().productos():
			pedidos[producto.id] = (
				pedidos.get(producto.id, 0) + comprador.pedido().unidades_de(producto)
			)
	return pedidos
