## Lo que dice cada cosa del local cuando se la examina: las tablas de la ficha «Subtítulos».
##
## **No es la revelación.** Lo que un objeto esconde vive en su `Revelacion`, y sale sólo al
## examinarlo según las reglas de investigación; esto lo nombra, y se dice gratis. La ficha
## define las descripciones; el nombre de cada producto sale del catálogo.
##
## Lo levantable escrito en un `.tres` lleva su texto en `ObjetoDelAlmacen.subtitulo`. Acá van
## los productos, que no tienen `.tres`, y lo fijo, que no tiene `datos`: con `datos`, lo fijo
## dejaría de admitir que se le apoye algo encima.
class_name SubtitulosAlExaminar
extends RefCounted

## Las identidades de lo fijo. Los dos artefactos del baño se llaman como los nombra la limpieza,
## que es el `destino` que ya llevan.
const INODORO := ReglasDeLaLimpieza.ID_DEL_INODORO
const LAVATORIO := ReglasDeLaLimpieza.ID_DEL_LAVATORIO
const COMPUTADORA := &"computadora"
const CAJA_REGISTRADORA := &"caja_registradora"
const LECTOR := &"lector"
const ENTRADA_PRINCIPAL := &"entrada_principal"
const PUERTA_DEL_JEFE := &"puerta_del_jefe"
const PORTON := &"porton"
const CONTENEDOR := &"contenedor"

const DE_LOS_PRODUCTOS := {
	Producto.Id.ZUCARACHAS: "Una caja de cereal %s.",
	Producto.Id.FROT_LUPS: "Una caja de cereal %s.",
	Producto.Id.PURA_COLA: "Una lata de %s.",
	Producto.Id.MARRANOS: "Una lata de atún %s.",
	Producto.Id.ARVECOR: "Una lata de arvejas %s.",
	Producto.Id.MAYONCHIS: "Un paquete de %s.",
	Producto.Id.JORGILLO: "Un alfajor %s.",
	Producto.Id.MAROLINI: "Una caja de fideos %s.",
	Producto.Id.UAKALAS: "Una caja de fideos %s.",
	Producto.Id.SALADICK: "Una caja de %s.",
	Producto.Id.PEPITO: "Una caja de galletitas %s.",
	Producto.Id.OREMOS: "Una caja de galletitas %s.",
	Producto.Id.DON_SATURADOS: "Un paquete de %s.",
	Producto.Id.PETISAS: "Un paquete de galletitas %s.",
	Producto.Id.MACUMBAS: "Un paquete de galletitas %s.",
	Producto.Id.PROGRES: "Un tubo de papitas %s.",
	Producto.Id.LAYSNNT: "Un paquete de papitas %s.",
	Producto.Id.CHISITOS: "Un paquete de %s.",
	Producto.Id.DUREXTRA: "Una caja de preservativos %s.",
	Producto.Id.DURONGA: "Una caja de preservativos %s.",
	Producto.Id.ACTRONCITO: "Una caja de medicamentos %s.",
	Producto.Id.BURBALOO: "Una caja de chicles %s.",
	Producto.Id.FLIM_POF: "Una caja de caramelos %s.",
	Producto.Id.MALBARDO: "Un paquete de cigarrillos %s.",
	Producto.Id.AMARGADITO: "Una caja de yerba %s.",
	Producto.Id.CINDOLOR: "Una caja de chocolatada %s.",
	Producto.Id.COSA_DE_MANI: "Una barra de %s.",
	Producto.Id.FEEL_RICKY_FORT: "Una caja de barritas %s.",
	Producto.Id.FERNET_GOD: "Una botella de %s.",
	Producto.Id.OAAAA: "Una caja de jugo %s.",
	Producto.Id.TERMINATOR: "Una caja de vino %s.",
	Producto.Id.POETICO: "Una botella de %s.",
}

const DE_LAS_NOTAS := {
	NotaPegada.Id.JABONES_Y_MANCHAS: "Una nota explicando qué jabón usar para cada tipo de mancha.",
	NotaPegada.Id.INSTRUCCIONES_DE_LIMPIEZA:
	"Una nota que explica cómo usar los elementos de limpieza.",
	NotaPegada.Id.NO_TIRAR_PAPEL: "“Por favor, no tirar papel en el inodoro”",
	NotaPegada.Id.TAREAS_A_REALIZAR: "Una lista de las tareas que me dejó Enrique.",
	NotaPegada.Id.LOCAL_ORDENADO:
	"Una nota sobre el correcto orden del local. Enrique es medio insoportable con eso…",
}

const DE_LOS_TACHOS := {
	TareaDeLaBasura.Tacho.LOCAL: "Un tacho de basura para los compradores diurnos.",
	TareaDeLaBasura.Tacho.ESCRITORIO: "Un tachito de basura para nosotros, los empleados.",
	TareaDeLaBasura.Tacho.BANO: "El tacho de basura del baño. Mejor ni mirar lo que tiene adentro.",
}

const DE_LO_DEMAS := {
	INODORO:
	"Un inodoro. Enrique me pidió encarecidamente que no tire papel en él, porque se tapa.",
	LAVATORIO: "Un lavatorio. Acá puedo cargar el balde.",
	COMPUTADORA:
	"Una computadora viejita. El único programa que tiene es el registro de productos vendidos.",
	CAJA_REGISTRADORA: "La caja registradora. Acá puedo hacer los tickets para los compradores.",
	LECTOR:
	(
		"El lector de código de barras. Si le paso un producto, lo va a anotar en el programa"
		+ " generador de tickets de la caja."
	),
	ENTRADA_PRINCIPAL:
	"La entrada principal al local. Queda cerrada con llave durante el turno nocturno.",
	PUERTA_DEL_JEFE:
	"Esta puerta lleva a la “oficina” de Enrique. Así le dice él. Siempre está cerrada.",
	PORTON: "Un portón que da a la calle.",
	CONTENEDOR: "Un contenedor de basura.",
}

const PREFIJO_DE_LA_NOTA := "nota_"
const PREFIJO_DEL_TACHO := "tacho_"


static func de_producto(id: Producto.Id) -> String:
	var plantilla: String = DE_LOS_PRODUCTOS.get(id, "")
	return "" if plantilla.is_empty() else plantilla % Catalogo.de(id).nombre


## Lo que dice algo que no se levanta. Una identidad sin fila no dice nada: las puertas
## interiores, las heladeras, la ventanilla, el comprador, la góndola y las manchas callan.
static func de_lo_fijo(id: StringName) -> String:
	if DE_LO_DEMAS.has(id):
		return DE_LO_DEMAS[id]
	for nota: NotaPegada.Id in DE_LAS_NOTAS:
		if id == id_de_la_nota(nota):
			return DE_LAS_NOTAS[nota]
	for tacho: TareaDeLaBasura.Tacho in DE_LOS_TACHOS:
		if id == id_del_tacho(tacho):
			return DE_LOS_TACHOS[tacho]
	return ""


## Cada nota con el mismo contenido dice lo mismo: la identidad sale de qué dice, no de dónde
## está pegada.
static func id_de_la_nota(nota: NotaPegada.Id) -> StringName:
	return StringName(PREFIJO_DE_LA_NOTA + String(NotaPegada.Id.find_key(nota)).to_lower())


## El texto del tacho no depende de su bolsa: examinarlo no la mira.
static func id_del_tacho(tacho: TareaDeLaBasura.Tacho) -> StringName:
	return StringName(PREFIJO_DEL_TACHO + String(TareaDeLaBasura.Tacho.find_key(tacho)).to_lower())
