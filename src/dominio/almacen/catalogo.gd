## Qué productos existen en el almacén y con qué valores.
##
## Es el único lugar donde viven el nombre y el precio de cada producto. Están acá y no adentro
## de `inventario.gd` porque son los números que se van a mover balanceando, y un valor que vive
## al lado de la lógica que lo usa termina copiado en el segundo lugar que lo necesita.
##
## Los productos y sus columnas son un **primer valor**: el GDD no los fija. Se ajustan jugando,
## y ajustarlos no rompe ningún test de `inventario.gd`, que recibe los productos en vez de venir
## a buscarlos acá.
class_name Catalogo
extends RefCounted

## Los dos tamaños de caja que guarda el depósito.
enum TamanoDeCaja { CHICA, GRANDE }

const PRODUCTOS_DE_PRUEBA: Array[Producto.Id] = [
	Producto.Id.ACTRONCITO,
	Producto.Id.ZUCARACHAS,
	Producto.Id.MALBARDO,
	Producto.Id.PROGRES,
	Producto.Id.JORGILLO,
	Producto.Id.ARVECOR,
	Producto.Id.PEPITO,
	Producto.Id.PURA_COLA,
	Producto.Id.MAROLINI,
	Producto.Id.DON_SATURADOS,
	Producto.Id.PETISAS,
	Producto.Id.DURONGA,
	Producto.Id.FERNET_GOD,
	Producto.Id.MAYONCHIS,
	Producto.Id.TERMINATOR,
	Producto.Id.POETICO,
]

## Cada `Producto.Id` con su nombre y su precio en pesos enteros.
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
## **Cuántas unidades pide la góndola de cada producto no está acá**: son los casilleros de su
## fila de adelante (BR-STK-008), que mide el modelo y le llegan al inventario desde la escena.
const FILAS := {
	Producto.Id.ACTRONCITO: ["Actroncito", 2500],
	Producto.Id.DUREXTRA: ["Durextra", 1200],
	Producto.Id.BURBALOO: ["Burbaloo", 1800],
	Producto.Id.ZUCARACHAS: ["Zucarachas", 900],
	Producto.Id.LAYSNNT: ["Laysnnt", 1100],
	Producto.Id.MALBARDO: ["Malbardo", 1500],
	Producto.Id.PROGRES: ["Progres", 1200],
	Producto.Id.JORGILLO: ["Jorgillo", 900],
	Producto.Id.ARVECOR: ["Arvecor", 800],
	Producto.Id.CHISITOS: ["Chisitos", 700],
	Producto.Id.OREMOS: ["Oremos", 1000],
	Producto.Id.PEPITO: ["Pepito", 950],
	Producto.Id.SALADICK: ["Saladick", 850],
	Producto.Id.UAKALAS: ["Uakalas", 1300],
	Producto.Id.PURA_COLA: ["Pura-Cola", 1400],
	Producto.Id.FROT_LUPS: ["Frot Lups", 1600],
	Producto.Id.MAROLINI: ["Marolini", 1050],
	Producto.Id.AMARGADITO: ["Amargadito", 3200],
	Producto.Id.CINDOLOR: ["Cindolor", 1900],
	Producto.Id.FLIM_POF: ["Flim Pof", 600],
	Producto.Id.DON_SATURADOS: ["Don Saturados", 1150],
	Producto.Id.PETISAS: ["Petisas", 980],
	Producto.Id.MACUMBAS: ["Macumbas", 1250],
	Producto.Id.COSA_DE_MANI: ["Cosa de Maní", 700],
	Producto.Id.DURONGA: ["Duronga", 1300],
	Producto.Id.FERNET_GOD: ["Fernet God", 4500],
	Producto.Id.MAYONCHIS: ["Mayonchis", 1100],
	Producto.Id.OAAAA: ["Oaaaa", 600],
	Producto.Id.TERMINATOR: ["Terminator", 2800],
	Producto.Id.MARRANOS: ["Marranos", 1400],
	Producto.Id.FEEL_RICKY_FORT: ["Feel Ricky Fort", 800],
	Producto.Id.POETICO: ["Poético", 1800],
}

## Qué es cada producto, de la columna «Qué es» de la base «Productos y cajas contenedoras». Va
## aparte de `FILAS` porque `Producto` no lo lleva: sólo lo lee la planilla de ventas.
const RUBROS := {
	Producto.Id.ACTRONCITO: "Caja de medicamentos",
	Producto.Id.DUREXTRA: "Caja de preservativos",
	Producto.Id.BURBALOO: "Caja de chicles",
	Producto.Id.ZUCARACHAS: "Caja de cereal",
	Producto.Id.LAYSNNT: "Paquete de papitas",
	Producto.Id.MALBARDO: "Paquete de cigarrillos",
	Producto.Id.PROGRES: "Tubo de papitas",
	Producto.Id.JORGILLO: "Cajita de alfajor",
	Producto.Id.ARVECOR: "Lata de arvejas",
	Producto.Id.CHISITOS: "Paquete de snacks",
	Producto.Id.OREMOS: "Caja de galletitas",
	Producto.Id.PEPITO: "Caja de galletitas",
	Producto.Id.SALADICK: "Caja de snacks",
	Producto.Id.UAKALAS: "Caja de fideos",
	Producto.Id.PURA_COLA: "Lata de refresco",
	Producto.Id.FROT_LUPS: "Caja de cereal",
	Producto.Id.MAROLINI: "Caja de fideos",
	Producto.Id.AMARGADITO: "Caja de yerba",
	Producto.Id.CINDOLOR: "Caja de chocolatada",
	Producto.Id.FLIM_POF: "Caja de caramelos",
	Producto.Id.DON_SATURADOS: "Paquete de galletitas",
	Producto.Id.PETISAS: "Paquete de galletitas",
	Producto.Id.MACUMBAS: "Paquete de galletitas",
	Producto.Id.COSA_DE_MANI: "Barra de mantecol",
	Producto.Id.DURONGA: "Caja de preservativos",
	Producto.Id.FERNET_GOD: "Botella de Fernet",
	Producto.Id.MAYONCHIS: "Paquete de mayonesa",
	Producto.Id.OAAAA: "Caja de jugo",
	Producto.Id.TERMINATOR: "Caja de vino",
	Producto.Id.MARRANOS: "Lata de atún",
	Producto.Id.FEEL_RICKY_FORT: "Caja de barras de cereal",
	Producto.Id.POETICO: "Producto de limpieza",
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
	Producto.Id.LAYSNNT: EntradaSonora.Sonoridad.ENVOLTORIO_PLASTICO,
	Producto.Id.MALBARDO: EntradaSonora.Sonoridad.CAJITA,
	Producto.Id.PROGRES: EntradaSonora.Sonoridad.LATA,
	Producto.Id.JORGILLO: EntradaSonora.Sonoridad.CAJITA,
	Producto.Id.ARVECOR: EntradaSonora.Sonoridad.LATA,
	Producto.Id.CHISITOS: EntradaSonora.Sonoridad.ENVOLTORIO_PLASTICO,
	Producto.Id.OREMOS: EntradaSonora.Sonoridad.CAJITA,
	Producto.Id.PEPITO: EntradaSonora.Sonoridad.CAJITA,
	Producto.Id.SALADICK: EntradaSonora.Sonoridad.CAJITA,
	Producto.Id.UAKALAS: EntradaSonora.Sonoridad.CAJITA,
	Producto.Id.PURA_COLA: EntradaSonora.Sonoridad.LATA,
	Producto.Id.FROT_LUPS: EntradaSonora.Sonoridad.CAJITA,
	Producto.Id.MAROLINI: EntradaSonora.Sonoridad.CAJITA,
	Producto.Id.AMARGADITO: EntradaSonora.Sonoridad.CAJA,
	Producto.Id.CINDOLOR: EntradaSonora.Sonoridad.CAJA,
	Producto.Id.FLIM_POF: EntradaSonora.Sonoridad.CAJITA,
	Producto.Id.DON_SATURADOS: EntradaSonora.Sonoridad.ENVOLTORIO_PLASTICO,
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
	Producto.Id.POETICO: EntradaSonora.Sonoridad.BOTELLA_PLASTICA,
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
	Producto.Id.LAYSNNT: TamanoDeCaja.GRANDE,
	Producto.Id.MALBARDO: TamanoDeCaja.CHICA,
	Producto.Id.PROGRES: TamanoDeCaja.GRANDE,
	Producto.Id.JORGILLO: TamanoDeCaja.CHICA,
	Producto.Id.ARVECOR: TamanoDeCaja.CHICA,
	Producto.Id.CHISITOS: TamanoDeCaja.GRANDE,
	Producto.Id.OREMOS: TamanoDeCaja.GRANDE,
	Producto.Id.PEPITO: TamanoDeCaja.GRANDE,
	Producto.Id.SALADICK: TamanoDeCaja.GRANDE,
	Producto.Id.UAKALAS: TamanoDeCaja.GRANDE,
	Producto.Id.PURA_COLA: TamanoDeCaja.GRANDE,
	Producto.Id.FROT_LUPS: TamanoDeCaja.GRANDE,
	Producto.Id.MAROLINI: TamanoDeCaja.GRANDE,
	Producto.Id.AMARGADITO: TamanoDeCaja.GRANDE,
	Producto.Id.CINDOLOR: TamanoDeCaja.GRANDE,
	Producto.Id.FLIM_POF: TamanoDeCaja.GRANDE,
	Producto.Id.DON_SATURADOS: TamanoDeCaja.GRANDE,
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
	Producto.Id.POETICO: TamanoDeCaja.GRANDE,
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
	return Producto.new(id, nombre, precio)


## El rubro de ese producto, o `""` si no tiene fila.
static func rubro_de(id: Producto.Id) -> String:
	return RUBROS.get(id, "")


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


static func de_la_jornada(jornada: int) -> Array[Producto]:
	if jornada >= ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA:
		return todos()
	var productos: Array[Producto] = []
	for id in PRODUCTOS_DE_PRUEBA:
		productos.append(de(id))
	return productos
