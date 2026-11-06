class_name Pista
extends Resource

enum Canal { LEVANTAR, EXAMINAR_NO_LEVANTABLE, CHAT, COMPRADOR, ACCION }

@export var identidad: String = ""
@export var jornada: int = 1
@export var canal: Canal = Canal.LEVANTAR
@export var origen: StringName = &""
@export var exigencias: PackedStringArray = PackedStringArray()
@export var foto: Texture2D = null
@export_multiline var texto: String = ""


func se_dispara_con(un_origen: StringName, un_canal: Canal, una_jornada: int) -> bool:
	return origen == un_origen and canal == un_canal and jornada == una_jornada


## Si anotarla deja algo que mostrar: su foto y su texto en el chat de notas y un aviso. Una
## pista de acción como la 7B no deja nada de eso (BR-INV-140).
func deja_nota() -> bool:
	return foto != null and not texto.is_empty()
