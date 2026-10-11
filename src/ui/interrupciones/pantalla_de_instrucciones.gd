class_name PantallaDeInstrucciones
extends CanvasLayer

signal comenzar_pedido

const DURACION_DE_LA_SUBIDA := 0.3
const TEXTO_DE_SIGUIENTE := "Siguiente"
const TEXTO_DE_VOLVER := "Volver"
const TEXTO_DE_COMENZAR := "Comenzar"
const FUENTE := preload("res://assets/ui/manada/unscii-16.ttf")

@export var _marco: Control
@export var _contenido: VBoxContainer
@export var _botones: HBoxContainer
@export var _volver: Button
@export var _siguiente: Button
@export var _scroll: ScrollContainer

var _pasos: Array[InstruccionesDelJefe.Paso] = []
var _instrucciones: InstruccionesDelJefe
var _ahora: Callable = Time.get_ticks_usec
var _ultimo: int = 0
var _avance: float = 0.0
var _negrita: FontVariation


func _ready() -> void:
	visible = false
	set_process(false)
	_negrita = FontVariation.new()
	_negrita.base_font = FUENTE
	_negrita.variation_embolden = 0.75
	_volver.text = TEXTO_DE_VOLVER
	_volver.pressed.connect(_al_volver)
	_siguiente.pressed.connect(_al_avanzar)
	get_viewport().size_changed.connect(_ajustar)
	_ajustar()


func _notification(que: int) -> void:
	if que == NOTIFICATION_UNPAUSED:
		_ultimo = _ahora.call()


func _process(_delta: float) -> void:
	var ahora: int = _ahora.call()
	_avance = minf(1.0, _avance + maxf(0.0, (ahora - _ultimo) / 1000000.0) / DURACION_DE_LA_SUBIDA)
	_ultimo = ahora
	_ajustar()
	if _avance == 1.0:
		set_process(false)


func mostrar(mensajes: Array[Mensaje]) -> void:
	_pasos = InstruccionesDelJefe.pasos_de(mensajes)
	_instrucciones = InstruccionesDelJefe.new(_pasos.size())
	_avance = 0.0
	_ultimo = _ahora.call()
	visible = true
	set_process(true)
	_pintar()
	_ajustar()


func _al_avanzar() -> void:
	if _instrucciones == null or _instrucciones.terminadas():
		return
	_instrucciones.avanzar()
	if _instrucciones.terminadas():
		visible = false
		set_process(false)
		comenzar_pedido.emit()
		return
	_pintar()


func _al_volver() -> void:
	if _instrucciones != null and _instrucciones.volver():
		_pintar()


func _pintar() -> void:
	for anterior in _contenido.get_children():
		if anterior == _botones:
			continue
		_contenido.remove_child(anterior)
		anterior.queue_free()
	for indice in _instrucciones.a_la_vista():
		_contenido.add_child(_dibujar(_pasos[indice]))
	_contenido.move_child(_botones, -1)
	_volver.visible = _instrucciones.se_puede_volver()
	_siguiente.text = (TEXTO_DE_COMENZAR if _instrucciones.en_el_ultimo() else TEXTO_DE_SIGUIENTE)
	_ir_al_ultimo.call_deferred()


func _dibujar(paso: InstruccionesDelJefe.Paso) -> VBoxContainer:
	var fila := VBoxContainer.new()
	fila.add_theme_constant_override("separation", 24)
	if paso.foto != null:
		var foto := TextureRect.new()
		foto.texture = paso.foto.foto
		foto.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		foto.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		foto.custom_minimum_size = Vector2(0, 540)
		fila.add_child(foto)
	var texto := RichTextLabel.new()
	texto.bbcode_enabled = true
	texto.fit_content = true
	texto.scroll_active = false
	texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texto.text = paso.texto.texto
	texto.add_theme_color_override("default_color", Color.WHITE)
	texto.add_theme_font_size_override("normal_font_size", 40)
	texto.add_theme_font_size_override("bold_font_size", 40)
	texto.add_theme_font_override("bold_font", _negrita)
	fila.add_child(texto)
	return fila


func _ir_al_ultimo() -> void:
	await get_tree().process_frame
	_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)


func _ajustar() -> void:
	LienzoDeManada.ajustar(_marco, get_viewport().get_visible_rect().size)
	_marco.position.y += 1080.0 * _marco.scale.y * (1.0 - _avance)
