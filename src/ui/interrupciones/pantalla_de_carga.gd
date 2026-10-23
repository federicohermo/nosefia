## La pantalla «Cargando»: dibuja el progreso que le pasan y qué se está cargando.
class_name PantallaDeCarga
extends Control

enum Presentacion { INICIAL, ENTRE_NOCHES }

## En la web los puntos los dibuja `html/head_include`, pegados a la palabra.
const TEXTO_EN_LA_WEB := "CARGANDO"
const TEXTO := "CARGANDO..."
const LEYENDO := "Leyendo el local: %d %%"
const PREPARANDO := "Preparando el local: %d de %d"
const COMPILANDO := "Compilando sombreadores: quedan %d"
const ENTRANDO := "Entrando al local"
## El lado de cada punto, en proporción a la letra.
const LADO_DEL_PUNTO := 0.2
const DURACION_DEL_LATIDO := 0.9
const DESFASE_DEL_PUNTO := 0.15

@export var presentacion: Presentacion = Presentacion.INICIAL
@export var _marco: Control
@export var _barra: ProgressBar
@export var _texto: Label
@export var _detalle: Label
@export var _fondo: Control
@export var _adornos: Array[Control]

var _en_la_web := OS.has_feature("web")
var _ubicacion_de_los_puntos := ""
var _puntos: Array[ColorRect] = []
var _tiempo_del_latido := 0.0


func _notification(que: int) -> void:
	if que == NOTIFICATION_RESIZED:
		LienzoDeManada.ajustar(_marco, size)


func _ready() -> void:
	visible = false
	_texto.text = TEXTO_EN_LA_WEB if _en_la_web else TEXTO
	_detalle.text = ""
	if presentacion == Presentacion.ENTRE_NOCHES:
		_fondo.hide()
		for adorno: Control in _adornos:
			adorno.hide()
		_detalle.hide()
		if not _en_la_web:
			_texto.visible_characters = TEXTO_EN_LA_WEB.length()
			var relleno: StyleBoxFlat = _barra.get_theme_stylebox("fill")
			for indice: int in range(3):
				var punto := ColorRect.new()
				punto.mouse_filter = Control.MOUSE_FILTER_IGNORE
				punto.color = relleno.bg_color
				_texto.add_child(punto)
				_puntos.append(punto)
	set_process(false)


func mostrar() -> void:
	_barra.value = _barra.min_value
	visible = true
	_tiempo_del_latido = 0.0
	_latir(true)
	set_process(_en_la_web or not _puntos.is_empty())


func ocultar() -> void:
	visible = false
	_latir(false)
	set_process(false)


func _exit_tree() -> void:
	_latir(false)


func pintar(progreso: float) -> void:
	_barra.value = maxf(_barra.value, progreso)


func progreso() -> float:
	return _barra.value


func contar_lectura(progreso: float) -> void:
	_detalle.text = LEYENDO % roundi(progreso * 100.0)


func contar_preparacion(hechos: int, total: int) -> void:
	_detalle.text = PREPARANDO % [hechos, total]


func contar_compilacion(quedan: int) -> void:
	_detalle.text = COMPILANDO % quedan


func contar_entrada() -> void:
	_detalle.text = ENTRANDO


## Mientras compila, el motor puede trabar la imagen, y la barra se traba con él.
## Los puntos de `html/head_include` los anima el navegador aparte, y siguen latiendo.
func _latir(prendido: bool) -> void:
	if _en_la_web:
		JavaScriptBridge.eval(
			"document.body.classList.toggle('cargando', %s)" % ("true" if prendido else "false")
		)


## Los puntos van donde termina la palabra. El navegador los ubica en píxeles de la página, y el
## lienzo puede medir otra cosa: la proporción la saca la página.
func _process(delta: float) -> void:
	var letra := _texto.get_theme_font_size("font_size")
	var fuente := _texto.get_theme_font("font")
	var ancho := fuente.get_string_size(_texto.text, 0, -1, letra).x
	var lado_propio := letra * LADO_DEL_PUNTO
	var renglon := (_texto.size.y - fuente.get_height(letra)) / 2.0
	var base := renglon + fuente.get_ascent(letra) - lado_propio
	if not _en_la_web:
		var palabra := fuente.get_string_size(TEXTO_EN_LA_WEB, 0, -1, letra).x
		var inicio := Vector2(
			(_texto.size.x - ancho) / 2.0 + palabra + lado_propio * 0.6, base - lado_propio / 2.0
		)
		_tiempo_del_latido += delta
		for indice: int in _puntos.size():
			var punto := _puntos[indice]
			punto.size = Vector2.ONE * lado_propio
			punto.pivot_offset = punto.size / 2.0
			punto.position = inicio + Vector2.RIGHT * indice * lado_propio * 1.6
			var tiempo := maxf(0.0, _tiempo_del_latido - indice * DESFASE_DEL_PUNTO)
			var pulso := (1.0 - cos(TAU * tiempo / DURACION_DEL_LATIDO)) / 2.0
			punto.scale = Vector2.ONE * lerpf(0.5, 1.0, pulso)
			punto.modulate.a = lerpf(0.3, 1.0, pulso)
		return
	var lienzo := _texto.get_global_transform_with_canvas()
	var final := lienzo * Vector2((_texto.size.x + ancho) / 2.0 + lado_propio * 0.6, base)
	var lado := lado_propio * lienzo.get_scale().y
	var ubicacion := "%d,%d,%d" % [final.x, final.y, lado]
	if ubicacion == _ubicacion_de_los_puntos:
		return
	_ubicacion_de_los_puntos = ubicacion
	JavaScriptBridge.eval("window.ubicarLatido?.(%s)" % ubicacion)
