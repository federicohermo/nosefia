class_name PantallaDeInstrucciones
extends CanvasLayer

signal comenzar_pedido

const DURACION_DE_LA_SUBIDA := 0.3
const TEXTO_DE_SIGUIENTE := "Siguiente"
const TEXTO_DE_VOLVER := "Volver"
const TEXTO_DE_COMENZAR := "OK"
const TEXTO_DE_JUGAR := "SI A JUGAR!!"
const COLOR_DE_RESALTE := Color("e4f850")
const COLOR_DE_SECTOR := Color("f0f4d1")
const SEPARADOR := preload("res://assets/ui/manada/instrucciones/separador.svg")
const CAJA := preload("res://assets/ui/manada/instrucciones/caja.png")
const TICKET := preload("res://assets/ui/manada/instrucciones/ticket.png")
const ALTURAS_DEL_SEPARADOR: Array[float] = [
	271, 328, 306, 306, 222, 168, 222, 222, 222, 258, 356, 188
]
const FOTOS := {
	2:
	{
		"rect": Rect2(0, 374, 324, 233),
		"titulo": "Listas de tareas a realizar",
		"sector": "Sector de ventas",
		"leyenda": Vector2(359, 367)
	},
	4:
	{
		"rect": Rect2(0, 357, 279, 201),
		"titulo": "Ventanilla de recepción",
		"sector": "Sector de ventas",
		"leyenda": Vector2(311, 357)
	},
	5:
	{
		"rect": Rect2(0, 276, 426, 258),
		"titulo": "Lector y la caja registradora",
		"sector": "Sector de ventas",
		"leyenda": Vector2(459, 276)
	},
	6:
	{
		"rect": Rect2(0, 283, 373, 300),
		"titulo": "Computadora",
		"sector": "Sector de ventas",
		"leyenda": Vector2(414, 283)
	},
	7:
	{
		"rect": Rect2(0, 277, 373, 365),
		"titulo": "Estantería con cajas contenedoras",
		"sector": "Sector de depósito",
		"leyenda": Vector2(446, 277)
	},
	9:
	{
		"rect": Rect2(0, 300, 548, 315),
		"titulo": "1 Mopa\n2 Balde\n3 Productos de limpieza",
		"sector": "Sector de baño",
		"leyenda": Vector2(603, 299)
	},
	11:
	{
		"rect": Rect2(0, 397, 480, 270),
		"titulo": "Cajas del proveedor",
		"sector": "Sector de depósito",
		"leyenda": Vector2(535, 397)
	},
}
const FUENTE := preload("res://assets/ui/manada/unscii-16.ttf")

@export var _marco: Control
@export var _contenido: Control
@export var _botones: Control
@export var _volver: Button
@export var _siguiente: Button
@export var _contador: Label
@export var _retrato: Control
@export var _fondo: TextureRect

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
		_contenido.remove_child(anterior)
		anterior.queue_free()
	var numero := _instrucciones.paso_actual()
	var paso: InstruccionesDelJefe.Paso = _pasos[numero - 1]
	for indice in paso.textos.size():
		var altura := 0.0
		if indice == 1:
			altura = 150.0 if numero == 1 else 201.0
		_texto(_resaltar(paso.textos[indice].texto, numero), Vector2(0, altura), 1007, 40)
	_imagen(SEPARADOR, Rect2(0, ALTURAS_DEL_SEPARADOR[numero - 1], 510, 2))
	if paso.foto != null:
		_foto(paso.foto.foto, FOTOS[numero])
	if numero == 5:
		_imagen(CAJA, Rect2(742, 276, 136, 316))
		_imagen(TICKET, Rect2(898, 341, 109, 186))
		_texto("ticket", Vector2(900, 276), 110, 30, COLOR_DE_RESALTE)
	if _instrucciones.en_el_ultimo():
		_texto(TEXTO_DE_JUGAR, Vector2(0, 239), 500, 40, COLOR_DE_RESALTE)
	_retrato.visible = true
	_volver.disabled = not _instrucciones.se_puede_volver()
	_siguiente.text = (TEXTO_DE_COMENZAR if _instrucciones.en_el_ultimo() else TEXTO_DE_SIGUIENTE)
	_contador.text = "%d/%d" % [numero, _pasos.size()]


func _resaltar(texto: String, numero: int) -> String:
	var marcado := texto.replace("[b]", "[color=#e4f850][b]").replace("[/b]", "[/b][/color]")
	if numero == 5:
		for frase: String in ["generar un ticket", "“imprimir”", "caja registradora"]:
			marcado = marcado.replace(frase, "[color=#e4f850]" + frase + "[/color]")
	return marcado


func _texto(
	cuerpo: String, posicion: Vector2, ancho: float, puntos: int, color: Color = Color.WHITE
) -> RichTextLabel:
	var texto := RichTextLabel.new()
	texto.bbcode_enabled = true
	texto.fit_content = true
	texto.scroll_active = false
	texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texto.position = posicion
	texto.size = Vector2(ancho, 1)
	texto.text = cuerpo
	texto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texto.add_theme_color_override("default_color", color)
	texto.add_theme_font_size_override("normal_font_size", puntos)
	texto.add_theme_font_size_override("bold_font_size", puntos)
	texto.add_theme_constant_override("line_separation", 4)
	texto.add_theme_font_override("bold_font", _negrita)
	_contenido.add_child(texto)
	return texto


func _imagen(textura: Texture2D, rectangulo: Rect2) -> TextureRect:
	var imagen := TextureRect.new()
	imagen.texture = textura
	imagen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	imagen.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	imagen.position = rectangulo.position
	imagen.size = rectangulo.size
	imagen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_contenido.add_child(imagen)
	return imagen


func _foto(textura: Texture2D, ficha: Dictionary) -> void:
	var rectangulo: Rect2 = ficha["rect"]
	var borde := Panel.new()
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color("1f1e1e")
	estilo.set_border_width_all(6)
	estilo.border_color = COLOR_DE_SECTOR
	borde.add_theme_stylebox_override("panel", estilo)
	borde.position = rectangulo.position
	borde.size = rectangulo.size
	borde.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_contenido.add_child(borde)
	_imagen(textura, Rect2(rectangulo.position + Vector2(6, 6), rectangulo.size - Vector2(12, 12)))
	var posicion: Vector2 = ficha["leyenda"]
	_texto(ficha["titulo"], posicion, 350, 30, COLOR_DE_RESALTE)
	# La leyenda ocupa el lugar diagramado sin recortar la foto del juego.
	var alto := 117.0 if ficha["titulo"].contains("\n") else 100.0
	if ficha["titulo"] == "Computadora":
		alto = 60.0
	_texto("-" + ficha["sector"], posicion + Vector2(0, alto), 350, 30, COLOR_DE_SECTOR)


func _ajustar() -> void:
	_fondo.size = get_viewport().get_visible_rect().size
	_fondo.modulate.a = _avance
	LienzoDeManada.ajustar(_marco, get_viewport().get_visible_rect().size)
	_marco.position.y += 1080.0 * _marco.scale.y * (1.0 - _avance)
