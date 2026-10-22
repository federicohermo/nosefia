class_name PantallaDeInstrucciones
extends CanvasLayer

signal comenzar_pedido

enum Etapa { OCULTA, ENTRANDO, LEYENDO, SALIENDO }

const DURACION_DEL_MOVIMIENTO := 0.3
const TEXTO_DE_SIGUIENTE := "Siguiente"
const TEXTO_DE_VOLVER := "Volver"
const TEXTO_DE_COMENZAR := "OK"
const COLOR_DE_RESALTE := Color("e4f850")
const COLOR_DE_SECTOR := Color("f0f4d1")
const SEPARADOR := preload("res://assets/ui/manada/instrucciones/separador.svg")
const CAJA := preload("res://assets/ui/manada/instrucciones/caja.png")
const TICKET := preload("res://assets/ui/manada/instrucciones/ticket.png")
const ANCHO_DEL_TEXTO := 1007.0
const SEPARACION_VERTICAL := 40.0
const SEPARACION_HORIZONTAL := 32.0
const SEPARACION_DEL_SECTOR := 64.0
const TAMANO_DE_LA_CAJA := Vector2(136, 316)
const TAMANO_DEL_TICKET := Vector2(109, 186)
const FOTO_DEL_LECTOR := "J1_Foto04"
const ALTO_DEL_BLOQUE_EN_PAR := 233.0
const ANCHO_DE_LA_LEYENDA := 350.0
## Cada foto lleva su leyenda; la pantalla en que cae depende de la jornada.
const FOTOS := {
	"J1_FotoReloj": {"titulo": "Reloj", "sector": "Sector de ventas"},
	"J1_Foto02": {"titulo": "Listas de tareas a realizar", "sector": "Sector de ventas"},
	"J1_Foto03":
	{
		"tamano": Vector2(279, 201),
		"titulo": "Ventanilla de recepción",
		"sector": "Sector de ventas"
	},
	"J1_Foto04":
	{
		"tamano": Vector2(426, 258),
		"titulo": "Lector y la caja registradora",
		"sector": "Sector de ventas"
	},
	"J1_Foto06":
	{"tamano": Vector2(373, 300), "titulo": "Computadora", "sector": "Sector de ventas"},
	"J2_FotoGondolas": {"titulo": "Góndolas", "sector": "Sector de ventas"},
	"J1_Foto07": {"titulo": "Estantería con cajas contenedoras", "sector": "Sector de depósito"},
	"J1_Foto09":
	{
		"tamano": Vector2(548, 315),
		"titulo": "1 Mopa\n2 Balde\n3 Productos de limpieza",
		"sector": "Sector de baño"
	},
	"J1_Foto11":
	{"tamano": Vector2(480, 270), "titulo": "Cajas del proveedor", "sector": "Sector de depósito"},
}

@export var _marco: Control
@export var _contenido: Control
@export var _botones: Control
@export var _volver: Button
@export var _siguiente: Button
@export var _contador: Label
@export var _retrato: Control
@export var _fondo: TextureRect

var _etapa: Etapa = Etapa.OCULTA
var _avance_al_salir: float = 1.0
var _pasos: Array[InstruccionesDelJefe.Paso] = []
var _instrucciones: InstruccionesDelJefe
var _ahora: Callable = Time.get_ticks_usec
var _ultimo: int = 0
## En microsegundos. Cada cuadro suma a lo sumo el paso máximo de la cabecera: el cuadro que abre
## la partida tarda, y con el tiempo entero la entrada se iba de un salto.
var _transcurrido: int = 0
var _avance: float = 0.0


func _ready() -> void:
	visible = false
	set_process(false)
	_volver.text = TEXTO_DE_VOLVER
	_volver.pressed.connect(_al_volver)
	_siguiente.pressed.connect(_al_avanzar)
	get_viewport().size_changed.connect(_ajustar)
	_ajustar()


func _notification(que: int) -> void:
	if que == NOTIFICATION_UNPAUSED:
		_ultimo = _ahora.call()


func _process(_delta: float) -> void:
	if _etapa not in [Etapa.ENTRANDO, Etapa.SALIENDO]:
		return
	var ahora: int = _ahora.call()
	_transcurrido += clampi(ahora - _ultimo, 0, roundi(CabeceraConSolapa.PASO_MAXIMO * 1000000.0))
	_ultimo = ahora
	_avance = minf(1.0, _transcurrido / (DURACION_DEL_MOVIMIENTO * 1000000.0))
	_ajustar()
	if _avance == 1.0:
		set_process(false)
		if _etapa == Etapa.SALIENDO:
			_etapa = Etapa.OCULTA
			visible = false
			comenzar_pedido.emit()
		else:
			_etapa = Etapa.LEYENDO


func mostrar(mensajes: Array[Mensaje]) -> void:
	_pasos = InstruccionesDelJefe.pasos_de(mensajes)
	_instrucciones = InstruccionesDelJefe.new(_pasos.size())
	_etapa = Etapa.ENTRANDO
	_avance = 0.0
	_transcurrido = 0
	_ultimo = _ahora.call()
	visible = true
	_siguiente.disabled = false
	set_process(true)
	_pintar()
	_ajustar()


func _al_avanzar() -> void:
	if _instrucciones == null or _instrucciones.terminadas():
		return
	_instrucciones.avanzar()
	if _instrucciones.terminadas():
		_avance_al_salir = _avance if _etapa == Etapa.ENTRANDO else 1.0
		_etapa = Etapa.SALIENDO
		_avance = 0.0
		_transcurrido = 0
		_ultimo = _ahora.call()
		_volver.disabled = true
		_siguiente.disabled = true
		set_process(true)
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
	var altura := 0.0
	for mensaje in paso.textos:
		var cuerpo := _texto(_resaltar(mensaje.texto), Vector2(0, altura), ANCHO_DEL_TEXTO, 40)
		altura += cuerpo.get_content_height() + SEPARACION_VERTICAL
	_imagen(SEPARADOR, Rect2(0, altura, 510, 2))
	var altura_de_la_foto := altura + 2.0 + SEPARACION_VERTICAL
	var ancho_de_la_leyenda := ANCHO_DE_LA_LEYENDA
	var x_del_ticket := ANCHO_DEL_TEXTO - TAMANO_DEL_TICKET.x
	var x_de_la_caja := x_del_ticket - SEPARACION_HORIZONTAL - TAMANO_DE_LA_CAJA.x
	var foto: Mensaje = paso.fotos[0] if paso.fotos.size() == 1 else null
	var con_caja := foto != null and foto.identidad == FOTO_DEL_LECTOR
	if con_caja:
		var tamano_de_la_foto: Vector2 = FOTOS[FOTO_DEL_LECTOR]["tamano"]
		ancho_de_la_leyenda = x_de_la_caja - tamano_de_la_foto.x - 2.0 * SEPARACION_HORIZONTAL
	if paso.fotos.size() > 1:
		_fotos_en_fila(paso.fotos, altura_de_la_foto)
	elif foto != null:
		_foto(foto.foto, FOTOS[foto.identidad], altura_de_la_foto, ancho_de_la_leyenda)
	if con_caja:
		_imagen(CAJA, Rect2(Vector2(x_de_la_caja, altura_de_la_foto), TAMANO_DE_LA_CAJA))
		var titulo := _texto(
			"ticket",
			Vector2(x_del_ticket, altura_de_la_foto),
			TAMANO_DEL_TICKET.x,
			30,
			COLOR_DE_RESALTE
		)
		_imagen(
			TICKET,
			Rect2(
				Vector2(
					x_del_ticket,
					altura_de_la_foto + titulo.get_content_height() + SEPARACION_VERTICAL
				),
				TAMANO_DEL_TICKET
			)
		)
	_retrato.visible = true
	_volver.disabled = not _instrucciones.se_puede_volver()
	_siguiente.text = (TEXTO_DE_COMENZAR if _instrucciones.en_el_ultimo() else TEXTO_DE_SIGUIENTE)
	_contador.text = "%d/%d" % [numero, _pasos.size()]


func _resaltar(texto: String) -> String:
	return texto.replace("[b]", "[color=#e4f850]").replace("[/b]", "[/color]")


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


func _foto(textura: Texture2D, ficha: Dictionary, altura: float, ancho_de_leyenda: float) -> void:
	var rectangulo := Rect2(Vector2(0, altura), ficha["tamano"])
	_marco_de_foto(textura, rectangulo)
	var posicion := Vector2(rectangulo.size.x + SEPARACION_HORIZONTAL, altura)
	var titulo := _texto(ficha["titulo"], posicion, ancho_de_leyenda, 30, COLOR_DE_RESALTE)
	_texto(
		"-" + ficha["sector"],
		posicion + Vector2(0, titulo.get_content_height() + SEPARACION_DEL_SECTOR),
		ancho_de_leyenda,
		30,
		COLOR_DE_SECTOR
	)


func _fotos_en_fila(fotos: Array[Mensaje], altura: float) -> void:
	var bloque := Rect2(
		0, altura, ANCHO_DEL_TEXTO, minf(ALTO_DEL_BLOQUE_EN_PAR, _contenido.size.y - altura)
	)
	var proporcion_total := 0.0
	for mensaje in fotos:
		proporcion_total += float(mensaje.foto.get_width()) / mensaje.foto.get_height()
	var ancho_de_fotos := bloque.size.x - ANCHO_DE_LA_LEYENDA - SEPARACION_HORIZONTAL * fotos.size()
	var alto_de_foto := minf(
		bloque.size.y, 12.0 + (ancho_de_fotos - 12.0 * fotos.size()) / proporcion_total
	)
	var posicion_de_foto := bloque.position
	var posicion_de_leyenda := Vector2(bloque.end.x - ANCHO_DE_LA_LEYENDA, bloque.position.y)
	for mensaje in fotos:
		var textura: Texture2D = mensaje.foto
		var ancho_de_foto := (
			12.0 + (alto_de_foto - 12.0) * textura.get_width() / textura.get_height()
		)
		var rectangulo := Rect2(posicion_de_foto, Vector2(ancho_de_foto, alto_de_foto))
		_marco_de_foto(textura, rectangulo)
		posicion_de_foto.x = rectangulo.end.x + SEPARACION_HORIZONTAL
		var ficha: Dictionary = FOTOS[mensaje.identidad]
		var titulo := _texto(
			ficha["titulo"], posicion_de_leyenda, ANCHO_DE_LA_LEYENDA, 30, COLOR_DE_RESALTE
		)
		posicion_de_leyenda.y += titulo.get_content_height() + 12.0
		var sector := _texto(
			"-" + ficha["sector"], posicion_de_leyenda, ANCHO_DE_LA_LEYENDA, 30, COLOR_DE_SECTOR
		)
		posicion_de_leyenda.y += sector.get_content_height() + 12.0


func _marco_de_foto(textura: Texture2D, rectangulo: Rect2) -> void:
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
	var foto := _imagen(
		textura, Rect2(rectangulo.position + Vector2(6, 6), rectangulo.size - Vector2(12, 12))
	)
	foto.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED


func _ajustar() -> void:
	var disponible := get_viewport().get_visible_rect().size
	_fondo.size = disponible
	_fondo.modulate.a = _avance if _etapa == Etapa.ENTRANDO else 1.0
	if _etapa == Etapa.SALIENDO:
		_fondo.modulate.a = minf(1.0, _avance_al_salir + _avance)
	LienzoDeManada.ajustar(_marco, disponible)
	var derecha := disponible.x - _marco.position.x
	if _etapa == Etapa.ENTRANDO:
		_marco.position.x += derecha * pow(1.0 - _avance, 2.0)
	elif _etapa == Etapa.SALIENDO:
		var izquierda := -_marco.position.x - _marco.size.x * _marco.scale.x
		var inicio := derecha * pow(1.0 - _avance_al_salir, 2.0)
		_marco.position.x += lerpf(inicio, izquierda, _avance * _avance)
