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
const TEXTO_DEL_OPERADOR := "CAJA 01\nOPERADOR\nTURNO NOCHE"
const TEXTO_DEL_ATAJO_DE_SALIDA := "CLIC DERECHO"
const TEXTO_DE_SALIDA := "< VOLVER AL LOCAL"
const TEXTO_DE_LA_TABLA := "/ UNIDADES VENDIDAS"
const TEXTO_DE_LA_COLUMNA_IMAGEN := "IMAGEN"
const TEXTO_DE_LA_COLUMNA_MARCA := "MARCA"
const TEXTO_DE_LA_COLUMNA_PRODUCTO := "PRODUCTO"
const TEXTO_DE_LA_COLUMNA_PRECIO := "PRECIO"
const TEXTO_DE_LA_COLUMNA_VENDIDO := "VENDIDO"
const TEXTO_DE_LA_COLUMNA_TOTAL := "TOTAL"
const TEXTO_DE_LA_CANTIDAD := "%d PRODUCTOS EN EL REGISTRO"
const TEXTO_DEL_DESPLAZAMIENTO := "ARRASTRÁ PARA DESPLAZAR  /  + − AJUSTAR UNIDADES"
const TEXTO_DE_LA_ETIQUETA_TOTAL := "TOTAL"
const TEXTO_DE_SUMAR := "+"
const TEXTO_DE_RESTAR := "−"

## El ancho de cada columna fija, igual en el encabezado y en las filas. La marca y el rubro
## se reparten lo que sobra según su peso.
const ANCHO_DE_LA_IMAGEN := 112.0
const ANCHO_DEL_PRECIO := 168.0
const ANCHO_DE_LO_VENDIDO := 240.0
const ANCHO_DEL_TOTAL := 200.0
const PESO_DE_LA_MARCA := 2.0
const PESO_DEL_RUBRO := 3.0
const TAMANO_DE_LETRA_DE_LA_DESCRIPCION := 28
const IMAGENES := {
	Producto.Id.ACTRONCITO: preload("res://assets/ui/manada/actroncito.png"),
	Producto.Id.DUREXTRA: preload("res://assets/ui/manada/durextra.png"),
	Producto.Id.BURBALOO: preload("res://assets/ui/manada/burbaloo.png"),
	Producto.Id.ZUCARACHAS: preload("res://assets/ui/manada/zucarachas.png"),
	Producto.Id.LAYSNNT: preload("res://assets/ui/manada/laysntt.png"),
	Producto.Id.MALBARDO: preload("res://assets/ui/manada/malbardo.png"),
	Producto.Id.PROGRES: preload("res://assets/ui/manada/prongles.png"),
	Producto.Id.JORGILLO: preload("res://assets/ui/manada/jorgillo.png"),
	Producto.Id.ARVECOR: preload("res://assets/ui/manada/arvejas.png"),
	Producto.Id.CHISITOS: preload("res://assets/ui/manada/chisitos.png"),
	Producto.Id.OREMOS: preload("res://assets/ui/manada/oremos.png"),
	Producto.Id.PEPITO: preload("res://assets/ui/manada/pepitos.png"),
	Producto.Id.SALADICK: preload("res://assets/ui/manada/saladik.png"),
	Producto.Id.UAKALAS: preload("res://assets/ui/manada/uakas.png"),
	Producto.Id.PURA_COLA: preload("res://assets/ui/manada/pura_cola.png"),
	Producto.Id.FROT_LUPS: preload("res://assets/ui/manada/frotlups.png"),
	Producto.Id.MAROLINI: preload("res://assets/ui/manada/marolini.png"),
	Producto.Id.AMARGADITO: preload("res://assets/ui/manada/amargadito.png"),
	Producto.Id.CINDOLOR: preload("res://assets/ui/manada/cindolor.png"),
	Producto.Id.FLIM_POF: preload("res://assets/ui/manada/flinpuf.png"),
	Producto.Id.DON_SATURADOS: preload("res://assets/ui/manada/donsaturados.png"),
	Producto.Id.PETISAS: preload("res://assets/ui/manada/petisas.png"),
	Producto.Id.MACUMBAS: preload("res://assets/ui/manada/macumbas.png"),
	Producto.Id.COSA_DE_MANI: preload("res://assets/ui/manada/cosa_de_mani.png"),
	Producto.Id.DURONGA: preload("res://assets/ui/manada/duronga.png"),
	Producto.Id.FERNET_GOD: preload("res://assets/ui/manada/fernet_god.png"),
	Producto.Id.MAYONCHIS: preload("res://assets/ui/manada/mayonchis.png"),
	Producto.Id.OAAAA: preload("res://assets/ui/manada/oaaaa.png"),
	Producto.Id.TERMINATOR: preload("res://assets/ui/manada/terminator.png"),
	Producto.Id.MARRANOS: preload("res://assets/ui/manada/marranos.png"),
	Producto.Id.FEEL_RICKY_FORT: preload("res://assets/ui/manada/feel_ricky_fort.png"),
	Producto.Id.POETICO: preload("res://assets/ui/manada/poetico.png"),
}

@export var _titulo: Label
@export var _subtitulo: Label
@export var _ayuda: Label
@export var _operador: Label
@export var _salida: Label
@export var _atajo_de_salida: Label
@export var _titulo_de_tabla: Label
@export var _columna_imagen: Label
@export var _columna_marca: Label
@export var _columna_producto: Label
@export var _columna_precio: Label
@export var _columna_vendido: Label
@export var _columna_total: Label
@export var _cantidad: Label
@export var _desplazamiento: Label
@export var _etiqueta_del_total: Label
@export var _filas: VBoxContainer
@export var _scroll: ScrollContainer
@export var _total: Label

var _registro: RegistroDeVentas
var _arrastrando: bool = false
var _posicion_del_arrastre: float = 0.0

## Las etiquetas de unidades y de total de cada fila, por `producto.id`. Las filas se arman una
## vez por planilla y después sólo se reescriben: rehacerlas en cada gesto vaciaría el contenedor
## un instante y el desplazamiento volvería arriba.
var _unidades_por_id: Dictionary = {}
var _totales_por_id: Dictionary = {}


func _ready() -> void:
	_titulo.text = TEXTO_DEL_TITULO
	_subtitulo.text = TEXTO_DEL_SUBTITULO
	_ayuda.text = TEXTO_DE_AYUDA
	_operador.text = TEXTO_DEL_OPERADOR
	_salida.text = TEXTO_DE_SALIDA
	_atajo_de_salida.text = TEXTO_DEL_ATAJO_DE_SALIDA
	_titulo_de_tabla.text = TEXTO_DE_LA_TABLA
	_encabezar(_columna_imagen, TEXTO_DE_LA_COLUMNA_IMAGEN, ANCHO_DE_LA_IMAGEN)
	_encabezar(_columna_marca, TEXTO_DE_LA_COLUMNA_MARCA, 0.0, PESO_DE_LA_MARCA)
	_encabezar(_columna_producto, TEXTO_DE_LA_COLUMNA_PRODUCTO, 0.0, PESO_DEL_RUBRO)
	_encabezar(_columna_precio, TEXTO_DE_LA_COLUMNA_PRECIO, ANCHO_DEL_PRECIO)
	_encabezar(_columna_vendido, TEXTO_DE_LA_COLUMNA_VENDIDO, ANCHO_DE_LO_VENDIDO)
	_encabezar(_columna_total, TEXTO_DE_LA_COLUMNA_TOTAL, ANCHO_DEL_TOTAL)
	_desplazamiento.text = TEXTO_DEL_DESPLAZAMIENTO
	_etiqueta_del_total.text = TEXTO_DE_LA_ETIQUETA_TOTAL
	_scroll.gui_input.connect(_al_tocar_la_lista)
	_scroll.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _notification(que: int) -> void:
	if que == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_terminar_arrastre()
	elif que == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
		_terminar_arrastre()


func _input(evento: InputEvent) -> void:
	if not _arrastrando:
		return
	if evento is InputEventMouseButton and evento.button_index == MOUSE_BUTTON_LEFT:
		if not evento.pressed:
			_terminar_arrastre()
			get_viewport().set_input_as_handled()
	elif evento is InputEventMouseMotion:
		var escala := _scroll.get_global_transform_with_canvas().get_scale().y
		var barra := _scroll.get_v_scroll_bar()
		_posicion_del_arrastre = clampf(
			_posicion_del_arrastre - evento.relative.y / escala,
			barra.min_value,
			maxf(barra.min_value, barra.max_value - barra.page)
		)
		_scroll.scroll_vertical = roundi(_posicion_del_arrastre)
		get_viewport().set_input_as_handled()


func _al_tocar_la_lista(evento: InputEvent) -> void:
	if evento is InputEventMouseButton:
		if evento.button_index == MOUSE_BUTTON_LEFT and evento.pressed:
			_arrastrando = true
			_posicion_del_arrastre = _scroll.scroll_vertical
			_pintar_cursor(Control.CURSOR_DRAG)
			_scroll.accept_event()


func _terminar_arrastre() -> void:
	if not _arrastrando:
		return
	_arrastrando = false
	_pintar_cursor(Control.CURSOR_POINTING_HAND)


func _pintar_cursor(forma: Control.CursorShape) -> void:
	_scroll.mouse_default_cursor_shape = forma
	for panel: PanelContainer in _filas.get_children():
		panel.mouse_default_cursor_shape = forma
		(panel.get_child(0) as Control).mouse_default_cursor_shape = forma


func mostrar(registro: RegistroDeVentas) -> void:
	if registro != _registro:
		_registro = registro
		_armar_filas()
	for producto in registro.productos():
		var unidades: Label = _unidades_por_id[producto.id]
		unidades.text = str(registro.unidades_de(producto))
		var total_de_la_fila: Label = _totales_por_id[producto.id]
		total_de_la_fila.text = texto_de_pesos(registro.total_de(producto))
	_total.text = texto_de_pesos(registro.total())


## El monto con el signo, un espacio y el punto como separador de miles. La planilla no produce
## montos negativos.
static func texto_de_pesos(monto: int) -> String:
	var cifras := str(monto)
	var miles := ""
	while cifras.length() > 3:
		miles = "." + cifras.substr(cifras.length() - 3) + miles
		cifras = cifras.substr(0, cifras.length() - 3)
	return "$ " + cifras + miles


func _encabezar(columna: Label, texto: String, ancho: float, peso: float = 0.0) -> void:
	columna.text = texto
	columna.custom_minimum_size.x = ancho
	columna.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if peso > 0.0:
		columna.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		columna.size_flags_stretch_ratio = peso


func _armar_filas() -> void:
	for vieja in _filas.get_children():
		_filas.remove_child(vieja)
		vieja.queue_free()
	_unidades_por_id.clear()
	_totales_por_id.clear()
	for producto in _registro.productos():
		_filas.add_child(_fila_de(producto))
	_cantidad.text = TEXTO_DE_LA_CANTIDAD % _unidades_por_id.size()


func _fila_de(producto: Producto) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.theme_type_variation = (
		&"FilaAlternaDelRegistro" if _filas.get_child_count() % 2 else &"FilaDelRegistro"
	)
	panel.custom_minimum_size = Vector2(0, 105)
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override(&"separation", 24)
	fila.mouse_filter = Control.MOUSE_FILTER_PASS
	fila.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	panel.add_child(fila)
	var marco := CenterContainer.new()
	marco.custom_minimum_size = Vector2(ANCHO_DE_LA_IMAGEN, 0)
	marco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fila.add_child(marco)
	var imagen := TextureRect.new()
	imagen.texture = IMAGENES.get(producto.id)
	imagen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	imagen.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	imagen.custom_minimum_size = Vector2(72, 72)
	imagen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marco.add_child(imagen)
	var marca := _etiqueta(producto.nombre, 0, PESO_DE_LA_MARCA)
	marca.add_theme_font_size_override(&"font_size", TAMANO_DE_LETRA_DE_LA_DESCRIPCION)
	fila.add_child(marca)
	var rubro := _etiqueta(Catalogo.rubro_de(producto.id), 0, PESO_DEL_RUBRO)
	rubro.add_theme_font_size_override(&"font_size", TAMANO_DE_LETRA_DE_LA_DESCRIPCION)
	fila.add_child(rubro)
	fila.add_child(_etiqueta(texto_de_pesos(producto.precio), ANCHO_DEL_PRECIO))
	fila.add_child(_boton(TEXTO_DE_RESTAR, func() -> void: resta_pedida.emit(producto)))
	var unidades := _etiqueta("", 64)
	unidades.theme_type_variation = &"CantidadDelRegistro"
	unidades.custom_minimum_size.y = 64
	unidades.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	unidades.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_unidades_por_id[producto.id] = unidades
	fila.add_child(unidades)
	fila.add_child(_boton(TEXTO_DE_SUMAR, func() -> void: suma_pedida.emit(producto)))
	var total_de_la_fila := _etiqueta("", ANCHO_DEL_TOTAL)
	_totales_por_id[producto.id] = total_de_la_fila
	fila.add_child(total_de_la_fila)
	return panel


func _etiqueta(texto: String, ancho: float, peso: float = 0.0) -> Label:
	var etiqueta := Label.new()
	etiqueta.text = texto
	etiqueta.custom_minimum_size = Vector2(ancho, 0)
	etiqueta.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	etiqueta.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	etiqueta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if peso > 0.0:
		etiqueta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		etiqueta.size_flags_stretch_ratio = peso
	return etiqueta


## El clic queda en el botón y la rueda llega a la lista. Así un «+» no inicia un arrastre.
func _boton(texto: String, al_apretar: Callable) -> Button:
	var boton := Button.new()
	boton.text = texto
	boton.theme_type_variation = &"BotonDelRegistro"
	boton.custom_minimum_size = Vector2(64, 64)
	boton.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	boton.mouse_filter = Control.MOUSE_FILTER_STOP
	boton.mouse_force_pass_scroll_events = true
	boton.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	boton.pressed.connect(al_apretar)
	return boton
