## El dibujo conserva el scroll al ampliar: la foto se superpone al chat, no lo reconstruye.
class_name PantallaDelCelular
extends CanvasLayer

signal chat_pedido(quien: Conversacion.Interlocutor)
signal volver_pedido
signal foto_pedida(indice: int)
signal cierre_de_foto_pedido

const RECORRIDO_COMPLETO := 0.25
const TAMANO := Vector2(522.0, 928.0)
const CENTRO := Vector2(960.0, 540.0)
const TEXTO_DEL_MENU := "CHATS"
const TEXTO_DEL_RECORDATORIO := "Q"
const TINTA := Color("1a1a1a")
const PAPEL := Color("ffffff")
const BURBUJA := Color("0b343d")

@export var _velo: Control
@export var _lienzo: Control
@export var _telefono: PanelContainer
@export var _titulo: Label
@export var _volver: Button
@export var _scroll: ScrollContainer
@export var _mensajes: VBoxContainer
@export var _foto_ampliada: PanelContainer
@export var _imagen: TextureRect
@export var _adjunto: RichTextLabel
@export var _recordatorio: HBoxContainer

var _avance: float = 0.0
var _destino: float = 0.0
var _ultimo: int = 0
var _ahora: Callable = Time.get_ticks_usec


func _ready() -> void:
	_volver.text = ""
	_volver.tooltip_text = "Volver al menú"
	var flecha := Line2D.new()
	flecha.name = "Flecha"
	flecha.points = PackedVector2Array([Vector2(6, -12), Vector2(-6, 0), Vector2(6, 12)])
	flecha.width = 3.0
	flecha.default_color = TINTA
	flecha.antialiased = true
	flecha.position = _volver.size / 2.0
	_volver.add_child(flecha)
	_volver.resized.connect(func() -> void: flecha.position = _volver.size / 2.0)
	_volver.pressed.connect(func() -> void: volver_pedido.emit())
	(_recordatorio.get_node("Tecla") as Label).text = TEXTO_DEL_RECORDATORIO
	_foto_ampliada.hide()
	_recordatorio.hide()
	_telefono.hide()
	_velo.hide()
	set_process(false)
	get_viewport().size_changed.connect(_ajustar)
	_ajustar()


func _notification(que: int) -> void:
	if que == NOTIFICATION_UNPAUSED:
		_ultimo = _ahora.call()


func _process(_delta: float) -> void:
	var ahora: int = _ahora.call()
	var segundos := maxf(0.0, (ahora - _ultimo) / 1000000.0)
	_ultimo = ahora
	_avance = move_toward(_avance, _destino, segundos / RECORRIDO_COMPLETO)
	_pintar_posicion()
	if is_equal_approx(_avance, _destino):
		set_process(false)
		if _destino == 0.0:
			_telefono.hide()
			_velo.hide()


func subir() -> void:
	_mover_hacia(1.0)


func bajar() -> void:
	_mover_hacia(0.0)


func mostrar_menu(bandeja: Bandeja) -> void:
	_foto_ampliada.hide()
	_volver.hide()
	_titulo.text = TEXTO_DEL_MENU
	_limpiar()
	for conversacion in bandeja.conversaciones():
		_mensajes.add_child(_boton_de(conversacion, bandeja.no_leidos(conversacion.interlocutor)))
	_scroll.scroll_vertical = 0


func mostrar_chat(conversacion: Conversacion, mensajes: Array[Mensaje], fijo: bool) -> void:
	_foto_ampliada.hide()
	_volver.visible = not fijo
	_titulo.text = conversacion.nombre.to_upper()
	_limpiar()
	for indice in mensajes.size():
		_mensajes.add_child(_burbuja_de(mensajes[indice], indice))
	_ir_al_ultimo.call_deferred()


func ampliar(foto: Mensaje, adjunto: Mensaje) -> void:
	_imagen.texture = foto.foto
	_adjunto.text = adjunto.texto if adjunto != null else ""
	_adjunto.visible = adjunto != null
	_foto_ampliada.show()


func cerrar_foto() -> void:
	_foto_ampliada.hide()


func mostrar_recordatorio(se_ve: bool) -> void:
	_recordatorio.visible = se_ve


func _input(evento: InputEvent) -> void:
	if not _foto_ampliada.visible or not _telefono.visible:
		return
	if (
		evento is InputEventMouseButton
		and evento.button_index == MOUSE_BUTTON_LEFT
		and evento.pressed
	):
		get_viewport().set_input_as_handled()
		cierre_de_foto_pedido.emit()


func _mover_hacia(destino: float) -> void:
	_destino = destino
	_ultimo = _ahora.call()
	if destino == 1.0:
		_telefono.show()
		_velo.show()
	set_process(true)
	_pintar_posicion()


func _ajustar() -> void:
	LienzoDeManada.ajustar(_lienzo, get_viewport().get_visible_rect().size)
	_pintar_posicion()


func _pintar_posicion() -> void:
	_telefono.size = TAMANO
	var arriba := CENTRO.y - TAMANO.y / 2.0
	_telefono.position = Vector2(CENTRO.x - TAMANO.x / 2.0, lerpf(1080.0, arriba, _avance))


func _boton_de(conversacion: Conversacion, sin_leer: int) -> Button:
	var boton := Button.new()
	boton.custom_minimum_size = Vector2(0, 132)
	boton.tooltip_text = conversacion.nombre
	boton.add_theme_stylebox_override("normal", _estilo(PAPEL, 8))
	boton.add_theme_stylebox_override("hover", _estilo(Color("ebebeb"), 8))
	boton.add_theme_stylebox_override("pressed", _estilo(Color("c8c8c8"), 8))
	var fila := HBoxContainer.new()
	fila.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fila.offset_left = 12
	fila.offset_right = -12
	fila.add_theme_constant_override("separation", 18)
	fila.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boton.add_child(fila)
	fila.add_child(_avatar(conversacion.imagen))
	var nombre := _etiqueta(conversacion.nombre.to_upper(), TINTA, 24)
	nombre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nombre.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	nombre.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fila.add_child(nombre)
	if sin_leer > 0:
		var cuenta := _etiqueta(str(sin_leer), BURBUJA, 24)
		cuenta.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		fila.add_child(cuenta)
	var quien := conversacion.interlocutor
	boton.pressed.connect(func() -> void: chat_pedido.emit(quien))
	return boton


func _avatar(imagen: Texture2D) -> PanelContainer:
	var avatar := PanelContainer.new()
	avatar.custom_minimum_size = Vector2(66, 66)
	avatar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	avatar.add_theme_stylebox_override("panel", _estilo(BURBUJA, 33))
	if imagen != null:
		var textura := TextureRect.new()
		textura.texture = imagen
		textura.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		textura.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		textura.mouse_filter = Control.MOUSE_FILTER_IGNORE
		avatar.add_child(textura)
	return avatar


func _burbuja_de(mensaje: Mensaje, indice: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _estilo(BURBUJA, 14, 16))
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	var contenido := VBoxContainer.new()
	contenido.add_theme_constant_override("separation", 12)
	contenido.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.add_child(contenido)
	if not mensaje.de_quien.is_empty():
		contenido.add_child(_etiqueta(mensaje.de_quien, Color("c8c8c8"), 18))
	if mensaje.foto != null:
		var foto := TextureButton.new()
		foto.texture_normal = mensaje.foto
		foto.ignore_texture_size = true
		foto.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		foto.custom_minimum_size = Vector2(0, 240)
		foto.pressed.connect(func() -> void: foto_pedida.emit(indice))
		contenido.add_child(foto)
	if not mensaje.texto.is_empty():
		var texto := _texto(mensaje.texto, PAPEL, 26)
		texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		contenido.add_child(texto)
	return panel


func _ir_al_ultimo() -> void:
	# El contenedor debe terminar de medir los mensajes antes de pedir el extremo del scroll.
	await get_tree().process_frame
	_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)


func _limpiar() -> void:
	for viejo in _mensajes.get_children():
		_mensajes.remove_child(viejo)
		viejo.queue_free()


func _etiqueta(texto: String, color: Color, tamano: int) -> Label:
	var etiqueta := Label.new()
	etiqueta.text = texto
	etiqueta.add_theme_color_override("font_color", color)
	etiqueta.add_theme_font_size_override("font_size", tamano)
	etiqueta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return etiqueta


func _estilo(color: Color, radio: int, margen: int = 0) -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = color
	estilo.set_corner_radius_all(radio)
	estilo.content_margin_left = margen
	estilo.content_margin_right = margen
	estilo.content_margin_top = margen
	estilo.content_margin_bottom = margen
	return estilo


func _texto(texto: String, color: Color, tamano: int) -> RichTextLabel:
	var etiqueta := RichTextLabel.new()
	etiqueta.bbcode_enabled = true
	etiqueta.fit_content = true
	etiqueta.scroll_active = false
	etiqueta.text = texto
	etiqueta.add_theme_color_override("default_color", color)
	etiqueta.add_theme_font_size_override("normal_font_size", tamano)
	etiqueta.add_theme_font_size_override("bold_font_size", tamano)
	etiqueta.add_theme_font_override("bold_font", _adjunto.get_theme_font("bold_font"))
	etiqueta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return etiqueta
