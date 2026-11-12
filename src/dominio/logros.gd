## Lo que el jugador ganó y vio, y dura más que una partida: los logros desbloqueados, los finales
## alcanzados y las pistas descubiertas. Cuándo se gana cada logro también lo decide acá.
##
## Qué es legible lo decide `desde`. El disco es de `ArchivoDeLogros`.
class_name Logros
extends RefCounted

enum Logro {
	OBELISCO_DE_CARTON,
	REBELDE,
	Y_SE_MARCHO,
	A_LA_BASURA,
	ESTAMOS_AL_PEDO,
	EMPLEADO_EJEMPLAR,
	PESIMA_PRIMERA_IMPRESION,
	MI_TALON_DE_AQUILES,
	ELEMENTAL,
}

const ReglasDelCierre := preload("res://src/dominio/almacen/reglas_del_cierre.gd")

const FALLAS_DEL_TALON := 4

const CLAVE_DE_LOGROS := "logros"
const CLAVE_DE_FINALES := "finales"
const CLAVE_DE_PISTAS := "pistas"

const _NOMBRES: Dictionary[Logro, String] = {
	Logro.OBELISCO_DE_CARTON: "Obelisco de cartón",
	Logro.REBELDE: "Rebelde",
	Logro.Y_SE_MARCHO: "Y se marchó…",
	Logro.A_LA_BASURA: "A la basura",
	Logro.ESTAMOS_AL_PEDO: "Estamos al pedo, ¿no?",
	Logro.EMPLEADO_EJEMPLAR: "Empleado ejemplar",
	Logro.PESIMA_PRIMERA_IMPRESION: "Pésima primera impresión",
	Logro.MI_TALON_DE_AQUILES: "Mi talón de Aquiles",
	Logro.ELEMENTAL: "Elemental, mi querida Yasmín",
}

const _NOMBRES_DE_LOS_FINALES: Dictionary[Partida.Final, String] = {
	Partida.Final.DESPEDIDO: "Despedido",
	Partida.Final.CONTRATO_CUMPLIDO: "Empleado explotado",
	Partida.Final.LOCURA_PARANOICA: "Locura paranoica",
	Partida.Final.JEFE_SABOTEADOR: "Jefe saboteador",
	Partida.Final.JEFE_INCOMPETENTE: "Jefe incompetente",
}

var _logros: Dictionary[Logro, bool] = {}
var _finales: Dictionary[Partida.Final, bool] = {}
var _pistas: Dictionary[String, bool] = {}


static func nombre(logro: Logro) -> String:
	return _NOMBRES[logro]


static func nombre_del_final(final: Partida.Final) -> String:
	return _NOMBRES_DE_LOS_FINALES[final]


## Los finales que una partida terminada puede tener, en el orden de la pantalla.
static func finales() -> Array[Partida.Final]:
	var todos: Array[Partida.Final] = []
	for final: Partida.Final in _NOMBRES_DE_LOS_FINALES:
		todos.append(final)
	return todos


## Una fila de la planilla en el tope: subir hasta ahí y bajar no la desbloquea dos veces.
static func estamos_al_pedo(registro: RegistroDeVentas) -> bool:
	for producto: Producto in registro.productos():
		if registro.unidades_de(producto) >= RegistroDeVentas.TOPE_POR_FILA:
			return true
	return false


static func empleado_ejemplar(final: Partida.Final, medios: int) -> bool:
	var terminada := final != Partida.Final.EN_CURSO and final != Partida.Final.DESPEDIDO
	return terminada and medios == 0


## El despido de la prueba: el único que llega antes de la primera jornada completa.
static func pesima_primera_impresion(final: Partida.Final, jornada: int) -> bool:
	return final == Partida.Final.DESPEDIDO and jornada < ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA


## Una misma obligatoria fija, cuatro veces. La particular no suma fallas (`Antecedentes`).
static func talon_de_aquiles(antecedentes: Antecedentes) -> bool:
	for tipo: Tarea.Tipo in Antecedentes.FIJAS:
		if antecedentes.fallas(tipo) >= FALLAS_DEL_TALON:
			return true
	return false


## «Afuera» es el de `ReglasDelCierre`: el cuerpo sostenido y el eximido no cuentan.
static func y_se_marcho(
	habitacion: ReglasDelCierre.Habitacion, sostenido: bool, eximido: bool
) -> bool:
	return habitacion == ReglasDelCierre.Habitacion.AFUERA and not sostenido and not eximido


## Todo ganado: cada logro, cada final y cada pista del caso. Es una instancia aparte, para mostrar.
static func completos(caso: CasoDeInvestigacion) -> Logros:
	var todos := Logros.new()
	for logro: Logro in Logro.values():
		todos.desbloquear(logro)
	for final: Partida.Final in finales():
		todos.alcanzar_final(final)
	for pista: Pista in caso.pistas:
		todos.descubrir_pista(pista.identidad)
	return todos


## Devuelve si lo ganó ahora: `false` si ya lo tenía.
func desbloquear(logro: Logro) -> bool:
	if _logros.has(logro):
		return false
	_logros[logro] = true
	return true


func desbloqueado(logro: Logro) -> bool:
	return _logros.has(logro)


## Devuelve si es la primera vez. La partida en curso no es un final.
func alcanzar_final(final: Partida.Final) -> bool:
	if not _NOMBRES_DE_LOS_FINALES.has(final) or _finales.has(final):
		return false
	_finales[final] = true
	return true


func final_alcanzado(final: Partida.Final) -> bool:
	return _finales.has(final)


func descubrir_pista(identidad: String) -> bool:
	if identidad.is_empty() or _pistas.has(identidad):
		return false
	_pistas[identidad] = true
	return true


func pista_descubierta(identidad: String) -> bool:
	return _pistas.has(identidad)


## Los nombres del `enum` y no su número: reordenarlo no puede cambiar qué logro está ganado.
func datos() -> Dictionary:
	var logros: Array[String] = []
	for logro: Logro in _logros:
		logros.append(Logro.keys()[logro])
	var finales: Array[String] = []
	for final: Partida.Final in _finales:
		finales.append(Partida.Final.keys()[final])
	return {
		CLAVE_DE_LOGROS: logros,
		CLAVE_DE_FINALES: finales,
		CLAVE_DE_PISTAS: _pistas.keys(),
	}


## Un nombre que el juego no conoce, un campo de otro tipo o un elemento que no es texto se
## ignoran sin descartar lo demás.
static func desde(datos: Dictionary) -> Logros:
	var leidos := Logros.new()
	for nombre_leido: String in _textos_de(datos.get(CLAVE_DE_LOGROS)):
		if Logro.keys().has(nombre_leido):
			leidos._logros[Logro[nombre_leido] as Logro] = true
	for nombre_leido: String in _textos_de(datos.get(CLAVE_DE_FINALES)):
		if Partida.Final.keys().has(nombre_leido):
			var final := Partida.Final[nombre_leido] as Partida.Final
			if _NOMBRES_DE_LOS_FINALES.has(final):
				leidos._finales[final] = true
	for identidad: String in _textos_de(datos.get(CLAVE_DE_PISTAS)):
		leidos.descubrir_pista(identidad)
	return leidos


static func _textos_de(crudo: Variant) -> Array[String]:
	var textos: Array[String] = []
	if crudo is Array:
		for elemento: Variant in crudo:
			if elemento is String:
				textos.append(elemento)
	return textos
