## La pantalla «Cargando...»: dibuja el progreso que le pasan.
class_name PantallaDeCarga
extends Control

const TEXTO := "CARGANDO..."

@export var _barra: ProgressBar
@export var _texto: Label


func _ready() -> void:
	visible = false
	_texto.text = TEXTO


func mostrar() -> void:
	visible = true


func ocultar() -> void:
	visible = false


func pintar(progreso: float) -> void:
	_barra.value = progreso
