## El paso que sigue a la devolución de las jornadas 1 y 2, con el celular en las notas: tres
## textos para leer en la primera, una hipótesis para elegir en la segunda.
##
## Cuánto se avanzó no se guarda acá: se lee del expediente, que recibe cada nota aceptada. Así
## una reflexión retomada desde el guardado sigue donde quedó sin un segundo estado que sanear.
class_name ReflexionDeCierre
extends RefCounted

## POR_EMPEZAR cubre la devolución que todavía está en pantalla: la reflexión ya existe, porque
## el guardado del cierre la conserva, pero no responde.
enum Etapa { POR_EMPEZAR, TEXTOS, ELEGIR, ESPERA, TERMINADA }
enum Eleccion { ACEPTADA, REPETIDA, NO_DISPONIBLE, FUERA_DE_ETAPA }

const JORNADA_DE_LOS_TEXTOS := 1
## La errata «faltabo» es de la fuente y se conserva hasta que diseño la corrija.
const ENCABEZADOS: Dictionary[int, String] = {
	1: "Primera jornada terminada…",
	2:
	(
		"Hoy faltabo uno de los jabones para la limpieza del local. No me quiero empezar a "
		+ "perseguir, pero…"
	),
}
const TEXTOS_DE_LA_PRIMERA: Array[String] = [
	(
		"Bueno, no será el mejor trabajo del mundo, pero es algo. Por lo menos, con lo que tengo "
		+ "me alcanza para cubrir los gastos hasta que Enrique me empiece a pagar."
	),
	(
		"Mi psicólogo tenía razón. Mudarme acá sin duda fue la decisión correcta. Desde que "
		+ "llegué, no volví a tener ningún episodio de paranoia."
	),
	(
		"Está claro que el problema era el estrés de la ciudad. Creo que la vida de pueblo me "
		+ "sienta mejor."
	),
]
## En segundos de juego, entre elegir la hipótesis y pedir la entrada de la noche siguiente.
const ESPERA_ANTES_DE_LA_NOCHE := 1.5

var _jornada: int
var _expediente: Expediente
var _etapa: Etapa = Etapa.POR_EMPEZAR
var _mostrada: int = 0
var _espera: float = 0.0


## La reflexión pendiente de esa jornada cerrada, o `null` si no tiene o ya terminó.
static func para(jornada: int, expediente: Expediente) -> ReflexionDeCierre:
	if not ENCABEZADOS.has(jornada) or expediente == null:
		return null
	var reflexion := ReflexionDeCierre.new(jornada, expediente)
	return null if reflexion._completa() else reflexion


## Los textos de la primera jornada que el guardado dice recibidos, en el orden de la reflexión.
## El texto sale de acá y no del disco: el guardado no puede inventar una reflexión.
static func restaurar_notas(expediente: Expediente, identidades: PackedStringArray) -> void:
	for indice: int in TEXTOS_DE_LA_PRIMERA.size():
		if not identidades.has(_identidad(indice)):
			return
		expediente.anotar(_nota(indice))


func _init(jornada: int, expediente: Expediente) -> void:
	_jornada = jornada
	_expediente = expediente


func jornada() -> int:
	return _jornada


func etapa() -> Etapa:
	return _etapa


## Si falta un gesto del jugador: es lo que el guardado conserva como cierre pendiente.
func pendiente() -> bool:
	return _etapa in [Etapa.POR_EMPEZAR, Etapa.TEXTOS, Etapa.ELEGIR]


func encabezado() -> String:
	return ENCABEZADOS[_jornada]


func empezar() -> void:
	if _etapa != Etapa.POR_EMPEZAR:
		return
	if _completa():
		_etapa = Etapa.TERMINADA
	else:
		_etapa = Etapa.TEXTOS if _jornada == JORNADA_DE_LOS_TEXTOS else Etapa.ELEGIR


func texto_actual() -> String:
	return TEXTOS_DE_LA_PRIMERA[_recibidos()] if _etapa == Etapa.TEXTOS else ""


## La identidad del texto a la vista. El pedido la trae para que un gesto repetido no avance dos.
func identidad_del_texto() -> String:
	return _identidad(_recibidos()) if _etapa == Etapa.TEXTOS else ""


func continuar(identidad: String) -> bool:
	if _etapa != Etapa.TEXTOS or identidad != identidad_del_texto():
		return false
	_expediente.anotar(_nota(_recibidos()))
	if _completa():
		_etapa = Etapa.TERMINADA
	return true


func opciones() -> Array[Hipotesis]:
	if _etapa in [Etapa.ELEGIR, Etapa.ESPERA]:
		return _expediente.hipotesis_para(_jornada)
	return []


func mostrada() -> Hipotesis:
	var disponibles := opciones()
	return disponibles[_mostrada % disponibles.size()] if not disponibles.is_empty() else null


func siguiente() -> bool:
	return _navegar(1)


func anterior() -> bool:
	return _navegar(-1)


func elegir(identidad: String) -> Eleccion:
	if _jornada == JORNADA_DE_LOS_TEXTOS or _etapa == Etapa.POR_EMPEZAR:
		return Eleccion.FUERA_DE_ETAPA
	match _expediente.elegir(_jornada, identidad):
		Expediente.Resultado.ANOTADA:
			_etapa = Etapa.ESPERA
			_espera = 0.0
			return Eleccion.ACEPTADA
		Expediente.Resultado.REPETIDA:
			return Eleccion.REPETIDA
	return Eleccion.NO_DISPONIBLE


## Corre la espera con el tiempo que le pasan. Contesta `true` una sola vez: cuando termina.
func avanzar(segundos: float) -> bool:
	if _etapa != Etapa.ESPERA or segundos <= 0.0:
		return false
	_espera += segundos
	if _espera < ESPERA_ANTES_DE_LA_NOCHE:
		return false
	_etapa = Etapa.TERMINADA
	return true


func restante() -> float:
	return maxf(0.0, ESPERA_ANTES_DE_LA_NOCHE - _espera) if _etapa == Etapa.ESPERA else 0.0


func _navegar(paso: int) -> bool:
	var disponibles := opciones().size()
	if _etapa != Etapa.ELEGIR or disponibles < 2:
		return false
	_mostrada = posmod(_mostrada + paso, disponibles)
	return true


func _completa() -> bool:
	if _jornada == JORNADA_DE_LOS_TEXTOS:
		return _recibidos() == TEXTOS_DE_LA_PRIMERA.size()
	return not _expediente.eleccion(_jornada).is_empty()


func _recibidos() -> int:
	var recibidos := 0
	var notas := PackedStringArray()
	for nota: Mensaje in _expediente.mensajes_de_notas():
		notas.append(nota.identidad)
	while recibidos < TEXTOS_DE_LA_PRIMERA.size() and notas.has(_identidad(recibidos)):
		recibidos += 1
	return recibidos


static func _identidad(indice: int) -> String:
	return "REFLEXION_J%d_%d" % [JORNADA_DE_LOS_TEXTOS, indice + 1]


static func _nota(indice: int) -> Mensaje:
	var nota := Mensaje.new()
	nota.identidad = _identidad(indice)
	nota.jornada = JORNADA_DE_LOS_TEXTOS
	nota.momento = Mensaje.Momento.CIERRE
	nota.texto = TEXTOS_DE_LA_PRIMERA[indice]
	return nota
