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


func ocultar() -> void:
	visible = false


func pintar(progreso: float) -> void:
	_barra.value = progreso
