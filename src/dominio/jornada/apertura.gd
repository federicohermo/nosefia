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


## Recibe los mismos compradores de Atención y la fuente de azar de esta sesión.
static func inventario_de_la_jornada(
	jornada: int,
	compradores: Array[Comprador],
	casilleros_totales: Dictionary[Producto.Id, int],
	casilleros_reponibles: Dictionary[Producto.Id, int],
	azar: RandomNumberGenerator
) -> Inventario:
	if jornada == ReglasDeLaPartida.PRIMERA_JORNADA:
		return inventario_con_faltantes({}, casilleros_totales)
	return inventario_con_faltantes(
		faltantes_al_azar(pedidos_de(compradores), casilleros_reponibles, azar), casilleros_totales
	)


## La mercadería de una noche con esos faltantes: el depósito de cada producto del catálogo con
## su caja llena, y su góndola con los casilleros de su fila menos lo que le falta.
##
## **Un faltante más grande que la caja no se acomoda**: la caja trae lo que trae, y reponer ese
## producto no se podría terminar. Es un error de los datos, y lo detecta el test que recorre
## las jornadas, no este código. Uno más grande que su fila deja la góndola en cero, que es lo
## que `Inventario.ingresar()` hace con una cantidad que no es positiva.
static func inventario_con_faltantes(
	faltantes: Dictionary[Producto.Id, int], casilleros: Dictionary[Producto.Id, int]
) -> Inventario:
	var productos := Catalogo.todos()
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


## Muestreo sin reemplazo: cada índice restante tiene la misma probabilidad.
static func faltantes_al_azar(
	pedidos: Dictionary[Producto.Id, int],
	casilleros_reponibles: Dictionary[Producto.Id, int],
	azar: RandomNumberGenerator
) -> Dictionary[Producto.Id, int]:
	var maximos: Dictionary[Producto.Id, int] = {}
	var elegibles: Array[Producto.Id] = []
	for producto in Catalogo.todos():
		var maximo := mini(
			ReglasDelEstante.UNIDADES_POR_CAJA - pedidos.get(producto.id, 0),
			casilleros_reponibles.get(producto.id, 0)
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


## Sólo lee los pedidos ya construidos; sus objetos siguen siendo los de Atención.
static func pedidos_de(compradores: Array[Comprador]) -> Dictionary[Producto.Id, int]:
	var pedidos: Dictionary[Producto.Id, int] = {}
	for comprador in compradores:
		for producto in comprador.pedido().productos():
			pedidos[producto.id] = (
				pedidos.get(producto.id, 0) + comprador.pedido().unidades_de(producto)
			)
	return pedidos
