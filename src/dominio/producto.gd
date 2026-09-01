## Qué es un producto del almacén: su identidad, el nombre que lee el jugador, cuánto sale y a
## partir de cuántas unidades en góndola hay que reponerlo.
##
## Un producto no hace nada, **es**: no sabe cuántas unidades hay ni dónde están —eso es
## `Inventario`— ni cuáles existen ni cuánto valen —eso es `Catalogo`—.
class_name Producto
extends RefCounted

## La identidad es un `enum` y no un `String` ni la instancia, y las dos mitades importan.
##
## Un `String` es el modo de falla que nombra `CLAUDE.md`: `"yerva"` no rompe nada, el `if`
## simplemente no entra nunca. Y la instancia tampoco sirve como identidad: `Catalogo.de()`
## construye un producto nuevo en cada llamada, así que dos yerbas son objetos distintos y un
## diccionario indexado por instancia contesta ausente donde tenía que haber un número.
enum Id { YERBA, FIDEOS, GASEOSA, GALLETITAS, ARROZ, JABON }

var id: Id
var nombre: String
var precio: int
var umbral: int


## Los argumentos van con prefijo `un_` para no sombrear los campos que asignan.
func _init(un_id: Id, un_nombre: String, un_precio: int, un_umbral: int) -> void:
	id = un_id
	nombre = un_nombre
	precio = un_precio
	umbral = un_umbral
