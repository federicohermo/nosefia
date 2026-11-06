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


## Lo que se levanta, o con lo que se actúa, para dar una pista está en el local sólo la noche de
## esa pista, y sólo si esa pista está activa por lo elegido y lo sorteado.
func esta_en_el_local(
	origen: StringName, jornada: int, elecciones: Dictionary, sorteos: Dictionary
) -> bool:
	if origen.is_empty():
		return true
	for pista: Pista in pistas:
		if (
			pista != null
			and pista.origen == origen
			and pista.canal in [Pista.Canal.LEVANTAR, Pista.Canal.ACCION]
		):
			return (
				pista.jornada == jornada
				and pistas_activas(jornada, elecciones, sorteos).has(pista.identidad)
			)
	return true


## El objeto que se levanta para dar una pista es esa pista sólo la noche de ella.
func levanta_una_pista(origen: StringName, jornada: int) -> bool:
	for pista: Pista in pistas:
		if pista != null and pista.se_dispara_con(origen, Pista.Canal.LEVANTAR, jornada):
			return true
	return false


## El título de la hipótesis que sólo esa pista habilita, o vacío si no hay una.
func titulo_de_la_pista(identidad: String) -> String:
	for opciones: HipotesisDeLaJornada in hipotesis:
		if opciones == null:
			continue
		for opcion: Hipotesis in opciones.opciones:
			if opcion != null and opcion.exigencias == PackedStringArray([identidad]):
				return opcion.titulo
	return ""


func hipotesis_para(jornada: int, descubiertas: PackedStringArray) -> Array[Hipotesis]:
	var opciones := _hipotesis_de(jornada)
	if opciones == null:
		return []
	return opciones.disponibles(descubiertas, _hay_pistas_antes_de(jornada, descubiertas))


## La hipótesis de esa jornada con esa identidad, o `null`.
func opcion(jornada: int, identidad: String) -> Hipotesis:
	var opciones := _hipotesis_de(jornada)
	return null if opciones == null else opciones.opcion_de(identidad)


## Las pistas de esa jornada que se pueden anotar. La primera jornada con pistas las tiene
## todas; las siguientes, sólo las del camino que abrió la hipótesis elegida en la anterior o
## la sorteada. Sin ninguna de las dos, ninguna.
func pistas_activas(jornada: int, elecciones: Dictionary, sorteos: Dictionary) -> PackedStringArray:
	var activas := PackedStringArray()
	var anterior := _hipotesis_de(jornada - 1)
	var camino := PackedStringArray()
	if anterior != null:
		var origen := String(sorteos.get(jornada, elecciones.get(jornada - 1, "")))
		var abierta := anterior.opcion_de(origen)
		if abierta == null:
			return activas
		camino = abierta.camino
	for pista: Pista in pistas:
		if pista.jornada == jornada and (anterior == null or camino.has(pista.identidad)):
			activas.append(pista.identidad)
	return activas


## Las hipótesis de la jornada anterior entre las que se sortea el camino de ésta: las que sus
## pistas activas habilitan. Ninguna si esa jornada no sortea, si dio alguna pista, si no tuvo
## pistas activas o si ya las activó un sorteo: dos jornadas seguidas sin pistas cortan el camino.
func opciones_a_sortear(
	jornada: int, descubiertas: PackedStringArray, elecciones: Dictionary, sorteos: Dictionary
) -> Array[Hipotesis]:
	var candidatas: Array[Hipotesis] = []
	var anterior := _hipotesis_de(jornada - 1)
	if anterior == null or not anterior.sortea_la_siguiente or sorteos.has(jornada - 1):
		return candidatas
	for identidad: String in descubiertas:
		var pista := pista_de(identidad)
		if pista != null and pista.jornada == jornada - 1:
			return candidatas
	var activas := pistas_activas(jornada - 1, elecciones, sorteos)
	if activas.is_empty():
		return candidatas
	for posible: Hipotesis in anterior.opciones:
		if posible != null and posible.habilitada_por(activas):
			candidatas.append(posible)
	return candidatas


func _hipotesis_de(jornada: int) -> HipotesisDeLaJornada:
	for opciones: HipotesisDeLaJornada in hipotesis:
		if opciones != null and opciones.jornada == jornada:
			return opciones
	return null


func _hay_pistas_antes_de(jornada: int, descubiertas: PackedStringArray) -> bool:
	for identidad: String in descubiertas:
		var pista := pista_de(identidad)
		if pista != null and pista.jornada < jornada:
			return true
	return false


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
