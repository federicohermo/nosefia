## El contenido compartido es inmutable; cada atención crea su propio cursor de diálogo.
class_name DialogosDeCompradores
extends Resource

enum Personaje { NINGUNO, TIN, TIA }

@export var tin := PackedStringArray()
@export var tia := PackedStringArray()
@export var despedida_tin := PackedStringArray()
@export var despedida_tia := PackedStringArray()
@export var recordatorio_tin: String = ""
@export var recordatorio_tia: String = ""


func inicial(personaje: int) -> Dialogo:
	return Dialogo.new(tia if personaje == Personaje.TIA else tin)


func despedida(personaje: int) -> Dialogo:
	return Dialogo.new(despedida_tia if personaje == Personaje.TIA else despedida_tin)


func recordatorio(personaje: int, rechazo: bool = false) -> Dialogo:
	var texto := recordatorio_tia if personaje == Personaje.TIA else recordatorio_tin
	var prefijo := "Yo no pedí esto. " if rechazo else ""
	return Dialogo.new(PackedStringArray([prefijo + texto]))
