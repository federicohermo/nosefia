## La app de registro: la planilla de lo vendido, con una fila por producto y el total.
##
## No decide nada: las filas, los topes, el total y si coincide con lo vendido los contesta
## `RegistroDeVentas`, que tiene test. Acá sólo se dibuja lo que responde.
class_name AppCaja
extends Control

signal suma_pedida(producto: Producto)
signal resta_pedida(producto: Producto)

const TEXTO_DEL_TITULO := "/ PRODUCTOS:"
const TEXTO_DEL_SUBTITULO := "REGISTRO DE ARTÍCULOS DEL LOCAL"
const TEXTO_DE_AYUDA := "Anotá con + y − cuántas unidades se vendieron de cada producto."
const ENCABEZADOS := {
	^"Encabezado/Nombre": "NOMBRE",
	^"Encabezado/Precio": "PRECIO",
	^"Encabezado/Unidades": "UNIDADES",
	^"Total/Etiqueta": "TOTAL",
}
const TEXTO_DEL_PRECIO := "$%d"
const TEXTO_DE_LAS_UNIDADES := "%02d"
const TEXTO_DEL_TOTAL := "$%d"
const TEXTO_DE_SUMAR := "+"
const TEXTO_DE_RESTAR := "−"
const IMAGENES := {
	Producto.Id.ACTRONCITO: preload("res://assets/ui/manada/actroncito.png"),
	Producto.Id.DUREXTRA: preload("res://assets/ui/manada/durextra.png"),
	Producto.Id.BURBALOO: preload("res://assets/ui/manada/burbaloo.png"),
	Producto.Id.ZUCARACHAS: preload("res://assets/ui/manada/zucarachas.png"),
	Producto.Id.LAYSNTT: preload("res://assets/ui/manada/laysntt.png"),
	Producto.Id.MALBARDO: preload("res://assets/ui/manada/malbardo.png"),
	Producto.Id.PRONGLES: preload("res://assets/ui/manada/prongles.png"),
	Producto.Id.JORGILLO: preload("res://assets/ui/manada/jorgillo.png"),
	Producto.Id.ARVEJAS: preload("res://assets/ui/manada/arvejas.png"),
	Producto.Id.CHISITOS: preload("res://assets/ui/manada/chisitos.png"),
	Producto.Id.OREMOS: preload("res://assets/ui/manada/oremos.png"),
	Producto.Id.PEPITOS: preload("res://assets/ui/manada/pepitos.png"),
	Producto.Id.SALADIK: preload("res://assets/ui/manada/saladik.png"),
	Producto.Id.UAKAS: preload("res://assets/ui/manada/uakas.png"),
	Producto.Id.CORACOLA: preload("res://assets/ui/manada/coracola.png"),
	Producto.Id.FROTLUPS: preload("res://assets/ui/manada/frotlups.png"),
	Producto.Id.MAROLINI: preload("res://assets/ui/manada/marolini.png"),
	Producto.Id.AMARGADITO: preload("res://assets/ui/manada/amargadito.png"),
	Producto.Id.CINDOLOR: preload("res://assets/ui/manada/cindolor.png"),
	Producto.Id.FLINPUF: preload("res://assets/ui/manada/flinpuf.png"),
	Producto.Id.DONSATURADOS: preload("res://assets/ui/manada/donsaturados.png"),
	Producto.Id.PETISAS: preload("res://assets/ui/manada/petisas.png"),
	Producto.Id.MACUMBAS: preload("res://assets/ui/manada/macumbas.png"),
}

@export var _titulo: Label
@export var _subtitulo: Label
@export var _ayuda: Label
@export var _filas: VBoxContainer
@export var _total: Label

var _registro: RegistroDeVentas

## Las etiquetas de unidades por `producto.id`. Las filas se arman una vez por planilla y después
## sólo se reescriben: rehacerlas en cada gesto vaciaría el contenedor un instante y el
## desplazamiento volvería arriba.
var _unidades_por_id: Dictionary = {}


func _ready() -> void:
	_titulo.text = TEXTO_DEL_TITULO
	_subtitulo.text = TEXTO_DEL_SUBTITULO
	_ayuda.text = TEXTO_DE_AYUDA
	for ruta: NodePath in ENCABEZADOS:
		(get_node(ruta) as Label).text = ENCABEZADOS[ruta]


func mostrar(registro: RegistroDeVentas) -> void:
	if registro != _registro:
		_registro = registro
		_armar_filas()
	for producto in registro.productos():
		var unidades: Label = _unidades_por_id[producto.id]
		unidades.text = TEXTO_DE_LAS_UNIDADES % registro.unidades_de(producto)
	_total.text = TEXTO_DEL_TOTAL % registro.total()


func _armar_filas() -> void:
	for vieja in _filas.get_children():
		_filas.remove_child(vieja)
		vieja.queue_free()
	_unidades_por_id.clear()
	for producto in _registro.productos():
		_filas.add_child(_fila_de(producto))


func _fila_de(producto: Producto) -> HBoxContainer:
	var fila := HBoxContainer.new()
	fila.custom_minimum_size = Vector2(0, 104)
	fila.add_theme_constant_override(&"separation", 24)
	fila.mouse_filter = Control.MOUSE_FILTER_PASS
	var imagen := TextureRect.new()
	imagen.texture = IMAGENES.get(producto.id)
	imagen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	imagen.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	imagen.custom_minimum_size = Vector2(96, 96)
	imagen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fila.add_child(imagen)
	fila.add_child(_etiqueta(producto.nombre.to_upper(), 0, true))
	fila.add_child(_etiqueta(TEXTO_DEL_PRECIO % producto.precio, 200))
	fila.add_child(_boton(TEXTO_DE_RESTAR, func() -> void: resta_pedida.emit(producto)))
	var unidades := _etiqueta("", 96)
	unidades.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_unidades_por_id[producto.id] = unidades
	fila.add_child(unidades)
	fila.add_child(_boton(TEXTO_DE_SUMAR, func() -> void: suma_pedida.emit(producto)))
	return fila


func _etiqueta(texto: String, ancho: float, expandir: bool = false) -> Label:
	var etiqueta := Label.new()
	etiqueta.text = texto
	etiqueta.custom_minimum_size = Vector2(ancho, 0)
	etiqueta.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	etiqueta.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	etiqueta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if expandir:
		etiqueta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return etiqueta


## El botón deja pasar el evento: sin eso, la rueda sobre un «+» no llega al desplazamiento y las
## filas de abajo quedan fuera de alcance.
func _boton(texto: String, al_apretar: Callable) -> Button:
	var boton := Button.new()
	boton.text = texto
	boton.custom_minimum_size = Vector2(72, 72)
	boton.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	boton.mouse_filter = Control.MOUSE_FILTER_PASS
	boton.pressed.connect(al_apretar)
	return boton
