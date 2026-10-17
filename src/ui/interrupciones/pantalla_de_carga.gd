## La pantalla «Cargando...»: dibuja el progreso que le pasan.
class_name PantallaDeCarga
extends Control

const TEXTO := "CARGANDO..."

@export var _marco: Control
@export var _barra: ProgressBar
@export var _texto: Label


func _notification(que: int) -> void:
	if que == NOTIFICATION_RESIZED:
		LienzoDeManada.ajustar(_marco, size)


func _ready() -> void:
	visible = false
	_texto.text = TEXTO


func mostrar() -> void:
	visible = true
	_latir(true)


func ocultar() -> void:
	visible = false
	_latir(false)


func _exit_tree() -> void:
	_latir(false)


## Mientras compila, el motor puede trabar la imagen, y la barra se traba con él.
## Los puntos de `html/head_include` los anima el navegador aparte, y siguen latiendo.
func _latir(prendido: bool) -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval(
			"document.body.classList.toggle('cargando', %s)" % ("true" if prendido else "false")
		)


func pintar(progreso: float) -> void:
	_barra.value = progreso
