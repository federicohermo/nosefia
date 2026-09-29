## Qué productos existen en el almacén y con qué valores.
##
## Es el único lugar donde viven el nombre, el precio y el umbral de cada producto. Están acá y
## no adentro de `inventario.gd` porque son los números que se van a mover balanceando, y un
## valor que vive al lado de la lógica que lo usa termina copiado en el segundo lugar que lo
## necesita.
##
## Los productos y sus tres columnas son un **primer valor**: el GDD no los fija. Se
## ajustan jugando, y ajustarlos no rompe ningún test de `inventario.gd`, que recibe los
## productos en vez de venir a buscarlos acá.
class_name Catalogo
extends RefCounted

## Los dos tamaños de caja que guarda el depósito.
enum TamanoDeCaja { CHICA, GRANDE }

## Cada `Producto.Id` con su nombre, su precio en pesos enteros y su umbral de reposición.
##
## **Los nombres son los del modelo 3D**, y no una etiqueta genérica: cada fila tiene detrás
## una malla que el jugador ve en la góndola, y un nombre que no coincide con lo que se ve
## deja al inventario hablando de otra cosa. Qué malla es cada uno lo dice
## `contenido_del_estante.tscn`, donde están en este mismo orden.
##
## Agregar un producto es una línea en el enum de `producto.gd` y una fila acá. Olvidarse de la
## fila es rojo: `catalogo_test.gd` cuenta las filas de acá contra `Producto.Id.size()`, y las
## cuenta sobre este diccionario y no sobre `todos()` a propósito —ver `de()`—.
##
## **El umbral es el cupo, y el cupo va en la fila de adelante de su tanda** (BR-STK-025). Es
## ocho, salvo donde la góndola no da para ocho de frente: una lata de heladera o una bolsa de
## cabecera. Ahí es lo que entra, que lo mide el acomodador del modelo y lo cobra
## `disposicion_de_la_gondola_test.gd`: si el reparto cambia, ese test dice cuál no entra.
const FILAS := {
	Producto.Id.ACTRONCITO: ["Actroncito", 2500, 8],
	Producto.Id.DUREXTRA: ["Durextra", 1200, 7],
	Producto.Id.BURBALOO: ["Burbaloo", 1800, 8],
	Producto.Id.ZUCARACHAS: ["Zucarachas", 900, 8],
	Producto.Id.LAYSNTT: ["Laysntt", 1100, 5],
	Producto.Id.MALBARDO: ["Malbardo", 1500, 8],
	Producto.Id.PRONGLES: ["Prongles", 1200, 8],
	Producto.Id.JORGILLO: ["Jorgillo", 900, 8],
	Producto.Id.ARVEJAS: ["Arvejas", 800, 8],
	Producto.Id.CHISITOS: ["Chisitos", 700, 5],
	Producto.Id.OREMOS: ["Oremos", 1000, 8],
	Producto.Id.PEPITOS: ["Pepitos", 950, 8],
	Producto.Id.SALADIK: ["Saladik", 850, 8],
	Producto.Id.UAKAS: ["Uakas", 1300, 8],
	Producto.Id.CORACOLA: ["Coracola", 1400, 6],
	Producto.Id.FROTLUPS: ["Frotlups", 1600, 8],
	Producto.Id.MAROLINI: ["Marolini", 1050, 8],
	Producto.Id.AMARGADITO: ["Amargadito", 3200, 8],
	Producto.Id.CINDOLOR: ["Cindolor", 1900, 8],
	Producto.Id.FLINPUF: ["Flinpuf", 600, 8],
	Producto.Id.DONSATURADOS: ["Donsaturados", 1150, 8],
	Producto.Id.PETISAS: ["Petisas", 980, 8],
	Producto.Id.MACUMBAS: ["Macumbas", 1250, 8],
	Producto.Id.COSA_DE_MANI: ["Cosa de Maní", 700, 8],
	Producto.Id.DURONGA: ["Duronga", 1300, 7],
	Producto.Id.FERNET_GOD: ["Fernet God", 4500, 5],
	Producto.Id.MAYONCHIS: ["Mayonchis", 1100, 4],
	Producto.Id.OAAAA: ["Oaaaa", 600, 4],
	Producto.Id.TERMINATOR: ["Terminator", 2800, 4],
	Producto.Id.MARRANOS: ["Marranos", 1400, 8],
	Producto.Id.FEEL_RICKY_FORT: ["Feel Ricky Fort", 800, 7],
}

## La sonoridad de cada producto, de la columna «Familia sonora» de la ficha. Va aparte de
## `FILAS` porque `Producto` no la lleva: sólo la usa el audio.
##
## **Dos familias de la ficha no existen acá**: la botella de vidrio suena como la plástica y la
## caja de cereal como la cajita, que son las más parecidas. Cuáles suenan de verdad es
## OQ-STK-004.
const SONORIDADES := {
	Producto.Id.ACTRONCITO: EntradaSonora.Sonoridad.CAJITA,
	Producto.Id.DUREXTRA: EntradaSonora.Sonoridad.CAJITA,
	Producto.Id.BURBALOO: EntradaSonora.Sonoridad.CAJITA,
	Producto.Id.ZUCARACHAS: EntradaSonora.Sonoridad.CAJITA,
	Producto.Id.LAYSNTT: EntradaSonora.Sonoridad.ENVOLTORIO_PLASTICO,
	Producto.Id.MALBARDO: EntradaSonora.Sonoridad.CAJITA,
	Producto.Id.PRONGLES: EntradaSonora.Sonoridad.LATA,
	Producto.Id.JORGILLO: EntradaSonora.Sonoridad.CAJITA,
	Producto.Id.ARVEJAS: EntradaSonora.Sonoridad.LATA,
	Producto.Id.CHISITOS: EntradaSonora.Sonoridad.ENVOLTORIO_PLASTICO,
	Producto.Id.OREMOS: EntradaSonora.Sonoridad.CAJITA,
	Producto.Id.PEPITOS: EntradaSonora.Sonoridad.CAJITA,
	Producto.Id.SALADIK: EntradaSonora.Sonoridad.CAJITA,
	Producto.Id.UAKAS: EntradaSonora.Sonoridad.CAJITA,
	Producto.Id.CORACOLA: EntradaSonora.Sonoridad.LATA,
	Producto.Id.FROTLUPS: EntradaSonora.Sonoridad.CAJITA,
	Producto.Id.MAROLINI: EntradaSonora.Sonoridad.CAJITA,
	Producto.Id.AMARGADITO: EntradaSonora.Sonoridad.CAJA,
	Producto.Id.CINDOLOR: EntradaSonora.Sonoridad.CAJA,
	Producto.Id.FLINPUF: EntradaSonora.Sonoridad.CAJITA,
	Producto.Id.DONSATURADOS: EntradaSonora.Sonoridad.ENVOLTORIO_PLASTICO,
	Producto.Id.PETISAS: EntradaSonora.Sonoridad.ENVOLTORIO_PLASTICO,
	Producto.Id.MACUMBAS: EntradaSonora.Sonoridad.ENVOLTORIO_PLASTICO,
	Producto.Id.COSA_DE_MANI: EntradaSonora.Sonoridad.ENVOLTORIO_PLASTICO,
	Producto.Id.DURONGA: EntradaSonora.Sonoridad.CAJITA,
	Producto.Id.FERNET_GOD: EntradaSonora.Sonoridad.BOTELLA_PLASTICA,
	Producto.Id.MAYONCHIS: EntradaSonora.Sonoridad.ENVOLTORIO_PLASTICO,
	Producto.Id.OAAAA: EntradaSonora.Sonoridad.CAJA,
	Producto.Id.TERMINATOR: EntradaSonora.Sonoridad.CAJA,
	Producto.Id.MARRANOS: EntradaSonora.Sonoridad.LATA,
	Producto.Id.FEEL_RICKY_FORT: EntradaSonora.Sonoridad.CAJITA,
}

## El tamaño de la caja del depósito de cada producto, de la columna «Caja» de la ficha.
##
## **Es un dato y no una medida de la escena.** No sale del volumen de la unidad: Actroncito es un
## envase grande y va en caja chica, y Zucarachas al revés. Cuánto mide cada tamaño es de la
## escena de la caja; qué tamaño lleva cada producto, de acá.
const TAMANOS_DE_CAJA := {
	Producto.Id.ACTRONCITO: TamanoDeCaja.CHICA,
	Producto.Id.DUREXTRA: TamanoDeCaja.CHICA,
	Producto.Id.BURBALOO: TamanoDeCaja.GRANDE,
	Producto.Id.ZUCARACHAS: TamanoDeCaja.GRANDE,
	Producto.Id.LAYSNTT: TamanoDeCaja.GRANDE,
	Producto.Id.MALBARDO: TamanoDeCaja.CHICA,
	Producto.Id.PRONGLES: TamanoDeCaja.GRANDE,
	Producto.Id.JORGILLO: TamanoDeCaja.CHICA,
	Producto.Id.ARVEJAS: TamanoDeCaja.CHICA,
	Producto.Id.CHISITOS: TamanoDeCaja.GRANDE,
	Producto.Id.OREMOS: TamanoDeCaja.GRANDE,
	Producto.Id.PEPITOS: TamanoDeCaja.GRANDE,
	Producto.Id.SALADIK: TamanoDeCaja.GRANDE,
	Producto.Id.UAKAS: TamanoDeCaja.GRANDE,
	Producto.Id.CORACOLA: TamanoDeCaja.GRANDE,
	Producto.Id.FROTLUPS: TamanoDeCaja.GRANDE,
	Producto.Id.MAROLINI: TamanoDeCaja.GRANDE,
	Producto.Id.AMARGADITO: TamanoDeCaja.GRANDE,
	Producto.Id.CINDOLOR: TamanoDeCaja.GRANDE,
	Producto.Id.FLINPUF: TamanoDeCaja.GRANDE,
	Producto.Id.DONSATURADOS: TamanoDeCaja.GRANDE,
	Producto.Id.PETISAS: TamanoDeCaja.GRANDE,
	Producto.Id.MACUMBAS: TamanoDeCaja.GRANDE,
	Producto.Id.COSA_DE_MANI: TamanoDeCaja.CHICA,
	Producto.Id.DURONGA: TamanoDeCaja.CHICA,
	Producto.Id.FERNET_GOD: TamanoDeCaja.GRANDE,
	Producto.Id.MAYONCHIS: TamanoDeCaja.GRANDE,
	Producto.Id.OAAAA: TamanoDeCaja.CHICA,
	Producto.Id.TERMINATOR: TamanoDeCaja.GRANDE,
	Producto.Id.MARRANOS: TamanoDeCaja.GRANDE,
	Producto.Id.FEEL_RICKY_FORT: TamanoDeCaja.GRANDE,
}


## Construye un producto nuevo en cada llamada, y eso es correcto: la identidad es el `id`, así
## que dos productos con el mismo `id` indexan al mismo lugar. Es lo que permite que esto sea
## `static` y que ningún test tenga que compartir estado.
##
## Un `id` sin fila devuelve `null` en vez de indexar el diccionario y reventar. El motivo está
## medido el 2026-09-01: con un séptimo valor en el enum y sin su fila, `FILAS[id]` tira
## `Out of bounds get index '6' (on base: 'Dictionary')`, gdUnit4 lo cuenta como *error* y no
## como *failure* —la línea de estadísticas del archivo sigue diciendo `PASSED`— y la aserción
## que tenía que ponerse en rojo **nunca llega a correr**. Con `null` el rojo lo produce la
## aserción, que es lo que el AC promete.
static func de(id: Producto.Id) -> Producto:
	if not FILAS.has(id):
		return null
	var fila: Array = FILAS[id]
	var nombre: String = fila[0]
	var precio: int = fila[1]
	var umbral: int = fila[2]
	return Producto.new(id, nombre, precio, umbral)


## La sonoridad de ese producto, o `NINGUNA` si no tiene fila.
static func sonoridad_de(id: Producto.Id) -> EntradaSonora.Sonoridad:
	return SONORIDADES.get(id, EntradaSonora.Sonoridad.NINGUNA)


## El tamaño de la caja del depósito de ese producto.
static func caja_de(id: Producto.Id) -> TamanoDeCaja:
	return TAMANOS_DE_CAJA.get(id, TamanoDeCaja.GRANDE)


## En el orden del enum, que es el orden en que el jugador los va a ver listados.
##
## Saltea los `id` sin fila para no meter un `null` en la lista que después recorre la pantalla:
## así la falta de una fila se lee como un producto que no está y la cuenta de `catalogo_test.gd`
## se pone en rojo afirmando, en vez de romperse al desreferenciar.
static func todos() -> Array[Producto]:
	var productos: Array[Producto] = []
	for id: Producto.Id in Producto.Id.values():
		var producto := de(id)
		if producto == null:
			continue
		productos.append(producto)
	return productos
