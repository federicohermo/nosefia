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

@export var presentacion: Presentacion = Presentacion.INICIAL
@export var _marco: Control
@export var _barra: ProgressBar
@export var _texto: Label
@export var _detalle: Label
@export var _fondo: Control
@export var _adornos: Array[Control]

var _en_la_web := OS.has_feature("web")
var _ubicacion_de_los_puntos := ""


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
	set_process(false)


func mostrar() -> void:
	visible = true
	_latir(true)
	set_process(_en_la_web)


func ocultar() -> void:
	visible = false
	_latir(false)
	set_process(false)


func _exit_tree() -> void:
	_latir(false)


func pintar(progreso: float) -> void:
	_barra.value = progreso


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
func _process(_delta: float) -> void:
	var letra := _texto.get_theme_font_size("font_size")
	var fuente := _texto.get_theme_font("font")
	var ancho := fuente.get_string_size(_texto.text, 0, -1, letra).x
	var lado_propio := letra * LADO_DEL_PUNTO
	var renglon := (_texto.size.y - fuente.get_height(letra)) / 2.0
	var base := renglon + fuente.get_ascent(letra) - lado_propio
	var lienzo := _texto.get_global_transform_with_canvas()
	var final := lienzo * Vector2((_texto.size.x + ancho) / 2.0 + lado_propio * 0.6, base)
	var lado := lado_propio * lienzo.get_scale().y
	var ubicacion := "%d,%d,%d" % [final.x, final.y, lado]
	if ubicacion == _ubicacion_de_los_puntos:
		return
	_ubicacion_de_los_puntos = ubicacion
	JavaScriptBridge.eval("window.ubicarLatido?.(%s)" % ubicacion)
