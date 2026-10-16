class_name CasoDeInvestigacion
extends Resource

enum Consistencia { VALIDO, ID_REPETIDA, EXIGENCIA_AJENA, CICLO, DESENLACE_INALCANZABLE }

@export var pistas: Array[Pista] = []
@export var desenlaces: Array[Desenlace] = []
@export var hipotesis: Array[HipotesisDeLaJornada] = []


func consistencia() -> Consistencia:
	return Consistencia.VALIDO


func pista_de(_identidad: String) -> Pista:
	return null


func hipotesis_para(_jornada: int, _descubiertas: PackedStringArray) -> Array[Hipotesis]:
	return []


static func de_la_partida() -> CasoDeInvestigacion:
	return CasoDeInvestigacion.new()
