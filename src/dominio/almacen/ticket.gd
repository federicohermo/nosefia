## El papel impreso conserva los productos, el número, la jornada y la hora de ese momento.
class_name Ticket
extends ObjetoDelAlmacen

const ID := &"ticket"

const TEXTO_AL_EXAMINAR := "Un ticket de compra por %s"

## Cuántos caracteres de ancho tiene un renglón cuando entra cómodo: los tres del diseño.
const COLUMNAS_MINIMAS := 21
const RELLENO := "."
const MONEDA := "$"
const SEPARADOR_DE_MILES := "."

## El `N°` sorteado al imprimir.
var numero: int
var jornada: int
## `HH:MM` de la noche en que se imprimió.
var hora: String

var _renglones: Array[Producto] = []


func _init(
	productos: Array[Producto] = [], un_numero := 0, una_jornada := 0, una_hora := ""
) -> void:
	id = ID
	numero = un_numero
	jornada = una_jornada
	hora = una_hora
	nombre = "Ticket"
	levantable = true
	sonoridad = EntradaSonora.Sonoridad.PAPEL
	_renglones.assign(productos)


func renglones() -> Array[Producto]:
	return _renglones.duplicate()


## Agrupa por identidad y conserva el orden de la primera aparición.
func resumen() -> Dictionary[Producto.Id, int]:
	var cuantos: Dictionary[Producto.Id, int] = {}
	for producto in _renglones:
		if not cuantos.has(producto.id):
			cuantos[producto.id] = 0
		cuantos[producto.id] += 1
	return cuantos


## El precio de lista con punto de miles y signo: `1.050$`.
static func con_precio(valor: int) -> String:
	var digitos := str(valor)
	var texto := ""
	while digitos.length() > 3:
		texto = SEPARADOR_DE_MILES + digitos.right(3) + texto
		digitos = digitos.left(digitos.length() - 3)
	return digitos + texto + MONEDA


func total() -> int:
	var suma := 0
	for producto in _renglones:
		suma += producto.precio
	return suma


func texto_del_total() -> String:
	return con_precio(total())


func texto_del_numero() -> String:
	return "N°%04d" % numero


func texto_de_la_fecha() -> String:
	return "Día: %d Hora:%s" % [jornada, hora]


## Cuántos caracteres de ancho tienen los renglones de este papel. Crece sólo si el más largo no
## entra en los del diseño, con un punto de relleno como mínimo.
func columnas() -> int:
	var ancho := COLUMNAS_MINIMAS
	for fila in _filas():
		ancho = maxi(ancho, fila[0].length() + RELLENO.length() + fila[1].length())
	return ancho


## Un renglón por producto distinto, en el orden en que el programa lo anotó: cantidad, nombre,
## relleno y precio de todas sus unidades, alineado a la derecha.
func lineas_impresas() -> Array[String]:
	var ancho := columnas()
	var lineas: Array[String] = []
	for fila in _filas():
		var relleno := RELLENO.repeat(ancho - fila[0].length() - fila[1].length())
		lineas.append(fila[0] + relleno + fila[1])
	return lineas


## Cada producto con su cantidad, en el orden en que aparece por primera vez, separados por
## «, » y el último por « y ».
func texto_al_examinar() -> String:
	var cuantos := resumen()
	var productos := _primeros()
	var partes: Array[String] = []
	for id: Producto.Id in cuantos:
		partes.append("%d %s" % [cuantos[id], productos[id].nombre])
	var lista: String = partes.back() if not partes.is_empty() else ""
	if partes.size() > 1:
		lista = ", ".join(partes.slice(0, -1)) + " y " + lista
	return TEXTO_AL_EXAMINAR % lista


## Cada fila es el texto de la izquierda y el precio de sus unidades.
func _filas() -> Array[PackedStringArray]:
	var cuantos := resumen()
	var productos := _primeros()
	var filas: Array[PackedStringArray] = []
	for id: Producto.Id in cuantos:
		filas.append(
			PackedStringArray(
				[
					"%dx %s" % [cuantos[id], productos[id].nombre],
					con_precio(productos[id].precio * cuantos[id])
				]
			)
		)
	return filas


func _primeros() -> Dictionary[Producto.Id, Producto]:
	var productos: Dictionary[Producto.Id, Producto] = {}
	for producto in _renglones:
		if not productos.has(producto.id):
			productos[producto.id] = producto
	return productos


static func se_desecha_en(objeto: ObjetoDelAlmacen, destino: StringName) -> bool:
	return objeto is Ticket and destino == ReglasDeLaLimpieza.ID_DEL_INODORO
