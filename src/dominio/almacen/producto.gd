## Qué es un producto del almacén: su identidad, el nombre que lee el jugador y cuánto sale.
##
## Un producto no hace nada, **es**: no sabe cuántas unidades hay ni dónde están —eso es
## `Inventario`—, ni cuáles existen ni cuánto valen —eso es `Catalogo`—, ni cuántas le entran a
## su góndola —eso son los casilleros de su fila de adelante, que el inventario recibe del
## local—.
class_name Producto
extends RefCounted

## La identidad es un `enum` y no un `String` ni la instancia, y las dos mitades importan.
##
## Un `String` es el modo de falla que nombra `CLAUDE.md`: uno mal escrito no rompe nada, el `if`
## simplemente no entra nunca. Y la instancia tampoco sirve como identidad: `Catalogo.de()`
## construye un producto nuevo en cada llamada, así que dos con el mismo `id` son objetos
## distintos y un
## diccionario indexado por instancia contesta ausente donde tenía que haber un número.
##
## Los números son persistentes: los usan las partidas guardadas y las referencias de los
## diálogos. Un producto nuevo recibe un número nuevo; renombrarlo conserva el que ya tenía.
enum Id {
	ACTRONCITO = 0,
	DUREXTRA = 1,
	BURBALOO = 2,
	ZUCARACHAS = 3,
	LAYSNNT = 4,
	MALBARDO = 5,
	PROGRES = 6,
	JORGILLO = 7,
	ARVECOR = 8,
	CHISITOS = 9,
	OREMOS = 10,
	PEPITO = 11,
	SALADICK = 12,
	UAKALAS = 13,
	PURA_COLA = 14,
	FROT_LUPS = 15,
	MAROLINI = 16,
	AMARGADITO = 17,
	CINDOLOR = 18,
	FLIM_POF = 19,
	DON_SATURADOS = 20,
	PETISAS = 21,
	MACUMBAS = 22,
	COSA_DE_MANI = 23,
	DURONGA = 24,
	FERNET_GOD = 25,
	MAYONCHIS = 26,
	OAAAA = 27,
	TERMINATOR = 28,
	MARRANOS = 29,
	FEEL_RICKY_FORT = 30,
	POETICO = 31,
}

var id: Id
var nombre: String
var precio: int


## Los argumentos van con prefijo `un_` para no sombrear los campos que asignan.
func _init(un_id: Id, un_nombre: String, un_precio: int) -> void:
	id = un_id
	nombre = un_nombre
	precio = un_precio
