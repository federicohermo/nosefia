## La partida de prueba que pide la URL de la build web: qué jornada abrir, con qué camino de
## pistas y qué hacer con el reloj y las tareas.
##
## **Recibe la búsqueda como `String`**, así que se ejerce sin escena ni navegador. Leer la URL es
## de `sistemas/`. Sin parámetros no hay partida de prueba, y el juego se comporta como siempre.
##
## El camino se nombra por su última hipótesis. Las anteriores se deducen de los datos del caso:
## no hay una tabla escrita a mano que una hipótesis nueva tenga que actualizar.
class_name PartidaDePrueba
extends RefCounted

const _JORNADA := "jornada"
const _CIERRE := "cierre"
const _CAMINO := "camino"
const _COMPLETAS := "completas"
const _LOGROS := "logros"
const _JOYSTICK := "joystick"

## `familia_del_joystick` cuando la búsqueda no fija ninguna.
const SIN_FAMILIA := -1

## Lo que `?joystick=` dice por nombre: qué familia fijan los glifos.
const _FAMILIAS_DEL_JOYSTICK: Dictionary[String, FamiliaDeJoystick.Familia] = {
	"xbox": FamiliaDeJoystick.Familia.XBOX,
	"ps": FamiliaDeJoystick.Familia.PLAYSTATION,
	"nintendo": FamiliaDeJoystick.Familia.NINTENDO,
}

## `-1` si no vino.
var jornada: int = -1
## `-1.0` si no vino.
var segundos_al_cierre: float = -1.0
var completas := false
## Que la pantalla de logros muestre todo como ganado. Sólo cambia lo que se ve: no se escribe el
## archivo de logros.
var logros_completos := false
## Que la pantalla de controles se vea como con un joystick conectado.
var joystick := false
## `SIN_FAMILIA` si no vino: queda la del joystick conectado.
var familia_del_joystick: int = SIN_FAMILIA
## Vacío si no vino.
var camino: String = ""


## La partida de una búsqueda (`location.search`), con o sin `?`. `null` si no trae ningún parámetro
## reconocido. Una `jornada` que no es una jornada de la partida anula todos los parámetros.
static func desde_busqueda(busqueda: String) -> PartidaDePrueba:
	var parametros := _parametros(busqueda)
	var prueba := PartidaDePrueba.new()
	var reconocido := false
	if parametros.has(_JORNADA):
		var texto: String = parametros[_JORNADA]
		if not texto.is_valid_int() or not _es_de_la_partida(texto.to_int()):
			return null
		prueba.jornada = texto.to_int()
		reconocido = true
	var cierre: String = parametros.get(_CIERRE, "")
	if cierre.is_valid_float() and cierre.to_float() >= 0.0:
		prueba.segundos_al_cierre = cierre.to_float()
		reconocido = true
	var todas: String = parametros.get(_COMPLETAS, "")
	if todas == "1" or todas == "0":
		prueba.completas = todas == "1"
		reconocido = true
	if parametros.get(_LOGROS, "") == "1":
		prueba.logros_completos = true
		reconocido = true
	var del_joystick: String = parametros.get(_JOYSTICK, "")
	if del_joystick == "1" or _FAMILIAS_DEL_JOYSTICK.has(del_joystick):
		prueba.joystick = true
		prueba.familia_del_joystick = _FAMILIAS_DEL_JOYSTICK.get(del_joystick, SIN_FAMILIA)
		reconocido = true
	if prueba.jornada >= 0 and parametros.get(_CAMINO, "") != "":
		prueba.camino = parametros[_CAMINO]
	return prueba if reconocido else null


## Las hipótesis del camino que termina en `final`, de la primera jornada a la última. La anterior
## de una hipótesis es la de la jornada previa cuyo camino contiene las pistas que ella exige, y la
## primera del caso si hay dos. Vacía si `final` no es una hipótesis del caso.
static func cadena(caso: CasoDeInvestigacion, final: String) -> Array[Hipotesis]:
	var eslabones: Array[Hipotesis] = []
	var actual := _hipotesis_de(caso, final)
	while actual != null:
		eslabones.push_front(actual)
		actual = _anterior_a(caso, actual)
	return eslabones


## El guardado de la partida en `jornada`: sus elecciones son las del camino anterior a ella, y el
## expediente trae las pistas que esas hipótesis exigen. Sin `camino` válido no hay elecciones.
func guardado(caso: CasoDeInvestigacion) -> Dictionary:
	var elecciones := {}
	var pistas := []
	for hipotesis: Hipotesis in cadena(caso, camino):
		if hipotesis.jornada >= jornada:
			break
		elecciones[hipotesis.jornada] = hipotesis.identidad
		for exigida: String in hipotesis.exigencias:
			if not pistas.has(exigida):
				pistas.append(exigida)
	return (
		PartidaSerializada
		. sanear(
			{
				PartidaSerializada.clave(PartidaSerializada.Campo.JORNADA): jornada,
				PartidaSerializada.clave(PartidaSerializada.Campo.EXPEDIENTE): pistas,
				PartidaSerializada.clave(PartidaSerializada.Campo.ELECCIONES): elecciones,
			}
		)
	)


static func _parametros(busqueda: String) -> Dictionary[String, String]:
	var parametros: Dictionary[String, String] = {}
	for par: String in busqueda.trim_prefix("?").split("&", false):
		var igual := par.find("=")
		if igual > 0 and not parametros.has(par.substr(0, igual)):
			parametros[par.substr(0, igual)] = par.substr(igual + 1)
	return parametros


static func _es_de_la_partida(numero: int) -> bool:
	var primera := ReglasDeLaPartida.PRIMERA_JORNADA
	return numero >= primera and numero < primera + ReglasDeLaPartida.JORNADAS_DE_LA_PARTIDA


## Las opciones de cada jornada, más la predeterminada y la de antecedentes, que no están en ellas.
static func _hipotesis_de(caso: CasoDeInvestigacion, identidad: String) -> Hipotesis:
	for jornada_del_caso: HipotesisDeLaJornada in caso.hipotesis:
		var candidatas: Array[Hipotesis] = jornada_del_caso.opciones.duplicate()
		candidatas.append(jornada_del_caso.predeterminada)
		candidatas.append(jornada_del_caso.con_antecedentes)
		for candidata: Hipotesis in candidatas:
			if candidata != null and candidata.identidad == identidad:
				return candidata
	return null


static func _anterior_a(caso: CasoDeInvestigacion, hipotesis: Hipotesis) -> Hipotesis:
	if hipotesis.exigencias.is_empty():
		return null
	for jornada_del_caso: HipotesisDeLaJornada in caso.hipotesis:
		if jornada_del_caso.jornada != hipotesis.jornada - 1:
			continue
		for candidata: Hipotesis in jornada_del_caso.opciones:
			if candidata != null and _abre_todas(candidata, hipotesis.exigencias):
				return candidata
	return null


static func _abre_todas(hipotesis: Hipotesis, pistas: PackedStringArray) -> bool:
	for pista: String in pistas:
		if not hipotesis.camino.has(pista):
			return false
	return true
