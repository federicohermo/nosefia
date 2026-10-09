## El contenido compartido es inmutable; cada atención crea su propio cursor de diálogo.
class_name DialogosDeCompradores
extends Resource

enum Personaje { NINGUNO, MARTIN, TIAGO }

@export var martin: PackedStringArray = []
@export var tiago: PackedStringArray = []
@export var despedida_martin: PackedStringArray = []
@export var despedida_tiago: PackedStringArray = []
@export var recordatorio_martin: String = ""
@export var recordatorio_tiago: String = ""


func inicial(personaje: int) -> Dialogo:
	return Dialogo.new(tiago if personaje == Personaje.TIAGO else martin)


func despedida(personaje: int) -> Dialogo:
	return Dialogo.new(despedida_tiago if personaje == Personaje.TIAGO else despedida_martin)


func recordatorio(personaje: int, rechazo: bool = false) -> Dialogo:
	var texto := recordatorio_tiago if personaje == Personaje.TIAGO else recordatorio_martin
	var prefijo := "Yo no pedí esto. " if rechazo else ""
	return Dialogo.new(PackedStringArray([prefijo + texto]))
