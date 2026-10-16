class_name Expediente
extends RefCounted

signal pista_nueva(pista: Pista)
signal desenlace_alcanzado(desenlace: Desenlace)

enum Resultado { ANOTADA, REPETIDA, DESCONOCIDA }


func _init(_caso: CasoDeInvestigacion) -> void:
	pass


func registrar(_identidad: String) -> Resultado:
	return Resultado.DESCONOCIDA


func registrar_por_canal(_origen: StringName, _canal: Pista.Canal, _jornada: int) -> Resultado:
	return Resultado.DESCONOCIDA


func identidades() -> PackedStringArray:
	return PackedStringArray()


func mensajes_de_notas() -> Array[Mensaje]:
	return []


func reconstruir(_identidades: PackedStringArray, _mensajes: Array[Mensaje] = []) -> void:
	pass


func hipotesis_para(_jornada: int) -> Array[Hipotesis]:
	return []


func desenlaces_alcanzados() -> Array[Desenlace]:
	return []
