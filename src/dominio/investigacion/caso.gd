class_name CasoDeInvestigacion
extends Resource

enum Consistencia {
	VALIDO, ID_REPETIDA, EXIGENCIA_AJENA, CICLO, DESENLACE_INALCANZABLE, IDENTIDAD_INVALIDA
}

@export var pistas: Array[Pista] = []
@export var desenlaces: Array[Desenlace] = []
@export var hipotesis: Array[HipotesisDeLaJornada] = []


func consistencia() -> Consistencia:
	var identidades := _validar_identidades()
	if identidades != Consistencia.VALIDO:
		return identidades
	var referencias := _validar_exigencias()
	if referencias != Consistencia.VALIDO:
		return referencias
	var en_curso: Dictionary[String, bool] = {}
	var revisadas: Dictionary[String, bool] = {}
	for pista: Pista in pistas:
		if _hay_ciclo(pista.identidad, en_curso, revisadas):
			return Consistencia.CICLO
	return _validar_desenlaces()


func pista_de(identidad: String) -> Pista:
	for pista: Pista in pistas:
		if pista != null and pista.identidad == identidad:
			return pista
	return null


## Lo que se levanta para dar una pista está en el local sólo la noche de esa pista.
func esta_en_el_local(origen: StringName, jornada: int) -> bool:
	if origen.is_empty():
		return true
	for pista: Pista in pistas:
		if pista != null and pista.canal == Pista.Canal.LEVANTAR and pista.origen == origen:
			return pista.jornada == jornada
	return true


## El objeto que se levanta para dar una pista es esa pista sólo la noche de ella.
func levanta_una_pista(origen: StringName, jornada: int) -> bool:
	for pista: Pista in pistas:
		if pista != null and pista.se_dispara_con(origen, Pista.Canal.LEVANTAR, jornada):
			return true
	return false


func hipotesis_para(jornada: int, descubiertas: PackedStringArray) -> Array[Hipotesis]:
	for opciones: HipotesisDeLaJornada in hipotesis:
		if opciones != null and opciones.jornada == jornada:
			return opciones.disponibles(descubiertas)
	return []


func _validar_identidades() -> Consistencia:
	var identidades := PackedStringArray()
	for pista: Pista in pistas:
		if pista == null or pista.identidad.is_empty():
			return Consistencia.IDENTIDAD_INVALIDA
		if identidades.has(pista.identidad):
			return Consistencia.ID_REPETIDA
		identidades.append(pista.identidad)
	return Consistencia.VALIDO


func _validar_exigencias() -> Consistencia:
	for pista: Pista in pistas:
		for exigida: String in pista.exigencias:
			if pista_de(exigida) == null:
				return Consistencia.EXIGENCIA_AJENA
	return Consistencia.VALIDO


func _validar_desenlaces() -> Consistencia:
	for desenlace: Desenlace in desenlaces:
		if desenlace == null or desenlace.umbral < 0 or desenlace.umbral > pistas.size():
			return Consistencia.DESENLACE_INALCANZABLE
		for exigida: String in desenlace.exigencias:
			if pista_de(exigida) == null:
				return Consistencia.DESENLACE_INALCANZABLE
	return Consistencia.VALIDO


func _hay_ciclo(
	identidad: String, en_curso: Dictionary[String, bool], revisadas: Dictionary[String, bool]
) -> bool:
	if en_curso.has(identidad):
		return true
	if revisadas.has(identidad):
		return false
	en_curso[identidad] = true
	for exigida: String in pista_de(identidad).exigencias:
		if _hay_ciclo(exigida, en_curso, revisadas):
			return true
	en_curso.erase(identidad)
	revisadas[identidad] = true
	return false


static func de_la_partida() -> CasoDeInvestigacion:
	return load("res://assets/investigacion/jornada_2/caso.tres") as CasoDeInvestigacion
