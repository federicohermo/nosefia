## La referencia de controles: qué líneas valen para lo que la mira enfoca y lo que se lleva, y
## cuándo el clic derecho cuenta con efecto.
##
## **Recibe todo ya traducido.** La mira llega como una de cuatro clases, el efecto del derecho
## ya contestado por quien atiende ese objetivo, y el control de cada gesto como texto. No lee el
## teclado ni el mouse: el HUD le pasa el nombre del control asignado, y así una asignación nueva
## se lee sin tocar esto.
##
## **El derecho no adelanta el resultado** (BR-PLY-036). Cuenta con efecto el par declarado de lo
## que se lleva y su objetivo, aunque el uso vaya a rechazarse por el estado: si dependiera del
## resultado, mirar una mancha diría cuál es el jabón correcto sin probarlo.
class_name ReferenciaDeControles
extends RefCounted

## Las líneas de la ficha, en su orden de arriba abajo. El orden del enum es el de la pantalla.
enum Linea {
	EXAMINAR_LA_MANO,
	EXAMINAR,
	AGARRAR,
	DEJAR,
	INTERACTUAR,
	SACAR_PRODUCTO,
	METER_PRODUCTO,
}

## Qué enfoca la mira: nada, algo que se levanta, algo fijo o una caja del depósito. La caja se
## levanta, pero el derecho sobre ella saca o mete y nunca «interactúa».
enum Mira { NADA, LEVANTABLE, FIJO, CAJA }

## Qué haría el clic derecho sobre lo enfocado con lo que hay en la mano.
enum Derecho { NINGUNO, INTERACTUAR, SACAR, METER }

## Cómo se lee una línea: el control entre corchetes y el texto de la ficha.
const FORMATO := "[%s] %s"

const TEXTOS: Dictionary[Linea, String] = {
	Linea.EXAMINAR_LA_MANO: "Examinar (mano)",
	Linea.EXAMINAR: "Examinar",
	Linea.AGARRAR: "Agarrar",
	Linea.DEJAR: "Dejar",
	Linea.INTERACTUAR: "Interactuar",
	Linea.SACAR_PRODUCTO: "Sacar producto",
	Linea.METER_PRODUCTO: "Meter producto",
}

## El gesto de cada línea: su control es el que ese gesto tiene asignado.
const ACCIONES := {
	Linea.EXAMINAR_LA_MANO: ReglasDeLosObjetos.ACCION_EXAMINAR,
	Linea.EXAMINAR: ReglasDeLosObjetos.ACCION_EXAMINAR,
	Linea.AGARRAR: ReglasDeLosObjetos.ACCION_AGARRAR,
	Linea.DEJAR: ReglasDeLosObjetos.ACCION_AGARRAR,
	Linea.INTERACTUAR: ReglasDelJugador.ACCION_USAR,
	Linea.SACAR_PRODUCTO: ReglasDelJugador.ACCION_USAR,
	Linea.METER_PRODUCTO: ReglasDelJugador.ACCION_USAR,
}


## Las líneas que valen, en el orden de la ficha. Suspendido no vale ninguna: no se mira nada.
##
## Con algo en la mano, el izquierdo se lee «Dejar» aunque vaya a tirarlo al contenedor: la
## ficha no tiene una línea para tirar.
static func lineas(
	con_la_mano: bool, mira: Mira, derecho: Derecho, suspendido: bool
) -> Array[Linea]:
	var valen: Array[Linea] = []
	if suspendido:
		return valen
	if con_la_mano:
		valen.append(Linea.EXAMINAR_LA_MANO)
	elif mira != Mira.NADA:
		valen.append(Linea.EXAMINAR)
	if not con_la_mano and (mira == Mira.LEVANTABLE or mira == Mira.CAJA):
		valen.append(Linea.AGARRAR)
	if con_la_mano:
		valen.append(Linea.DEJAR)
	if mira == Mira.CAJA:
		if derecho == Derecho.SACAR and not con_la_mano:
			valen.append(Linea.SACAR_PRODUCTO)
		elif derecho == Derecho.METER and con_la_mano:
			valen.append(Linea.METER_PRODUCTO)
	elif mira != Mira.NADA and derecho == Derecho.INTERACTUAR:
		valen.append(Linea.INTERACTUAR)
	return valen


## La línea como se lee, con el nombre del control que llega. Sin nombre no hay línea: devuelve
## vacío, y quien pinta la saltea.
static func texto(linea: Linea, control: String) -> String:
	if control.is_empty():
		return ""
	return FORMATO % [control, TEXTOS[linea]]


static func accion(linea: Linea) -> StringName:
	return StringName(ACCIONES[linea])


## Sacar o meter según lo que la caja contesta que es posible; con nada posible, ninguno.
static func derecho_de_la_caja(gesto: ContenidoDeLaCaja.Gesto) -> Derecho:
	match gesto:
		ContenidoDeLaCaja.Gesto.SACAR:
			return Derecho.SACAR
		ContenidoDeLaCaja.Gesto.METER:
			return Derecho.METER
	return Derecho.NINGUNO


## Un par declarado de herramienta y objetivo cuenta, sin mirar el estado de ninguno.
static func derecho_del_uso(efecto: Uso.Efecto) -> Derecho:
	return Derecho.NINGUNO if efecto == Uso.Efecto.NINGUNO else Derecho.INTERACTUAR


## El lector cuenta con una unidad en la mano y estando presente, aunque el programa esté lleno.
static func derecho_del_lector(sostenido: ObjetoDelAlmacen, lector_presente: bool) -> Derecho:
	if lector_presente and sostenido is UnidadDeProducto:
		return Derecho.INTERACTUAR
	return Derecho.NINGUNO


## Lo que se desecha en ese destino —el ticket en el inodoro— cuenta.
static func derecho_del_descarte(sostenido: ObjetoDelAlmacen, destino: StringName) -> Derecho:
	if Ticket.se_desecha_en(sostenido, destino):
		return Derecho.INTERACTUAR
	return Derecho.NINGUNO


## El tacho cuenta si conserva su bolsa y la mano está vacía. Se pregunta, no se saca.
static func derecho_del_tacho(con_bolsa: bool, con_la_mano: bool) -> Derecho:
	if con_bolsa and not con_la_mano:
		return Derecho.INTERACTUAR
	return Derecho.NINGUNO
