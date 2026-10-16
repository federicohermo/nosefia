class_name Pista
extends Resource

enum Canal { LEVANTAR, EXAMINAR_NO_LEVANTABLE, CHAT, COMPRADOR }

@export var identidad: String = ""
@export var jornada: int = 1
@export var canal: Canal = Canal.LEVANTAR
@export var origen: StringName = &""
@export var exigencias: PackedStringArray = PackedStringArray()
@export var foto: Texture2D = null
@export_multiline var texto: String = ""


func se_dispara_con(_origen: StringName, _canal: Canal, _jornada: int) -> bool:
	return false
