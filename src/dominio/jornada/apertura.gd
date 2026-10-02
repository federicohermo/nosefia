## Cómo se abre una jornada: qué tareas pide el jefe esta noche, con cuánto tiempo se arranca y
## con qué mercadería.
##
## La lista se arma **recorriendo `Tarea.Tipo`**: una tarea nueva se agrega al `enum` y este
## archivo no se toca.
class_name Apertura
extends RefCounted

## Qué falta en la góndola al abrir cada jornada: `jornada → { Producto.Id: unidades }`, de la
## tabla de la ficha «8. Tarea: Reposición». Cada faltante es a lo sumo lo que trae una caja, y
## el test lo afirma sobre las cinco jornadas.
##
## Por ahora tiene una sola fila: las otras jornadas dicen «A definir» y arrancan como la primera
## (ver `faltantes_de_la_jornada()`).
const FALTANTES_POR_JORNADA := {
	ReglasDeLaPartida.PRIMERA_JORNADA:
	{
		Producto.Id.ACTRONCITO: 5,
		Producto.Id.CORACOLA: 6,
		Producto.Id.MAROLINI: 2,
		Producto.Id.PRONGLES: 8,
		Producto.Id.LAYSNTT: 4,
	},
}


## Una tarea nueva por cada tipo declarado.
##
## Cada llamada devuelve instancias nuevas, y por eso quien abre la jornada la pide **una sola
## vez**: el turno cuenta contra las instancias que recibió, así que completar una tarea de una
## segunda lista devolvería `true` sin que `tareas_cumplidas()` suba — sin error y sin rojo.
static func obligatorias() -> Array[Tarea]:
	var lista: Array[Tarea] = []
	for tipo: Tarea.Tipo in Tarea.Tipo.values():
		lista.append(Tarea.new(tipo))
	return lista


## Cuántas obligatorias tiene una jornada.
##
## Existe porque el `Turno` no expone cuántas son: recibe la lista y no tiene getter. El
## HUD pide el número a la misma fuente que armó la lista y no a una segunda copia.
static func cantidad_de_obligatorias() -> int:
	return Tarea.Tipo.size()


## El turno de la noche, con el presupuesto entero y las obligatorias que se le declaran.
##
## **Recibe la lista y no la vuelve a construir**: es lo que hace que el reloj pueda entregarle
## al 008 la misma instancia de `Tarea` que el turno está contando.
static func turno_de_la_jornada(obligatorias: Array[Tarea]) -> Turno:
	return Turno.new(Reglas.DURACION_DEL_TURNO, obligatorias)


## La mercadería con la que arranca la noche de esa jornada: cada caja del depósito llena, y la
## fila de adelante de cada producto completa salvo lo que la jornada hace faltar.
##
## **Que falte algo es lo que hace que reponer sea una tarea**, y que sea poco es lo que la ficha
## pide: la góndola de un almacén abierto no está vacía. Con la góndola entera por reponer, cada
## noche arrancaría con treinta y un productos que caminar hasta el fondo.
##
## Los casilleros de cada fila los recibe: los mide la escena sobre el modelo, y acá no se
## escribe ninguno. Lo que falta sale de `faltantes_de_la_jornada()`, y la jornada es la que
## abre el ciclo: una partida continuada arranca su noche desde el dato, como una nueva.
##
## **Devuelve un inventario nuevo en cada llamada**, igual que `obligatorias()`: uno compartido
## entre jornadas dejaría lo repuesto anoche en la góndola de esta noche, o sea que la tarea se
## cumpliría sola a partir de la segunda.
static func inventario_de_la_jornada(
	jornada: int, casilleros: Dictionary[Producto.Id, int]
) -> Inventario:
	return inventario_con_faltantes(faltantes_de_la_jornada(jornada), casilleros)


## Lo que falta en la góndola al abrir esa jornada, de cada producto que falta: la ficha
## «8. Tarea: Reposición». Un producto que no está no falta.
##
## **Sólo la primera jornada está decidida.** La ficha dice «A definir» de la 2 a la 5, y
## mientras tanto arrancan como la primera (OQ-STK-005): una jornada sin fila en
## `FALTANTES_POR_JORNADA` contesta la de la primera. El día que la ficha decida otra, es una
## fila más en esa tabla.
##
## Devuelve una copia: quien la reciba puede tocarla sin cambiar la jornada de mañana.
static func faltantes_de_la_jornada(jornada: int) -> Dictionary[Producto.Id, int]:
	var fila: Dictionary[Producto.Id, int] = {}
	fila.assign(
		FALTANTES_POR_JORNADA.get(jornada, FALTANTES_POR_JORNADA[ReglasDeLaPartida.PRIMERA_JORNADA])
	)
	return fila


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
