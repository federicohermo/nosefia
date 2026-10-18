## Lo que dura más que una noche: qué jornada va, el legajo que se arrastra y cómo termina todo.
##
## **Es la pieza que hace jugable la regla del despido.** Hasta acá el legajo vivía adentro del
## script de la escena y moría con ella, así que `despedido()` no podía devolver `true` jugando:
## la regla estaba en verde en los tests y muerta en la build. Con la partida el mismo legajo
## cruza las cinco jornadas y el despido se alcanza.
##
## **Va en `dominio/` y no en un autoload**, y está medido por qué: el gate de tests no mira
## `escenas/`, así que «qué jornada va» escrito ahí nace sin test; y un autoload es peor, porque
## el gate de capas no puede verlo. Este spec no agrega el primero.
##
## Abre y cierra jornadas, pero **no las hace correr**: el tiempo lo trae `sistemas/` y entra
## por `cerrar_la_jornada()` ya convertido en cuántas tareas se cumplieron.
class_name Partida
extends RefCounted

## Los tres estados en los que puede estar una partida. Es un conjunto cerrado y por eso es un
## `enum`: un `String` suelto dejaría al `if` del menú sin entrar nunca, sin decir una palabra.
enum Final { EN_CURSO, CONTRATO_CUMPLIDO, DESPEDIDO }
enum Llamado { LOCAL_DESORDENADO, OBJETO_AFUERA, PAPEL_EN_EL_INODORO, OBJETO_TIRADO }
enum RegistroDePoetico { RECHAZADO, ANOTADO, REPETIDO }

var expediente: Expediente:
	get:
		return _expediente
	set(_nuevo):
		push_error("El expediente pertenece a la partida y no se sustituye")

## La reflexión de la última noche cerrada, o `null` si esa noche no tiene o la partida terminó.
var reflexion: ReflexionDeCierre:
	get:
		return _reflexion
	set(_nueva):
		push_error("La reflexión la abre el cierre de la jornada y no se sustituye")

var _expediente: Expediente
var _legajo: Legajo
var _jornada: int = ReglasDeLaPartida.PRIMERA_JORNADA
var _obligatorias: Array[Tarea] = []
var _jornada_abierta: bool = false
var _final: Final = Final.EN_CURSO
var _llamados: Array[Llamado] = []
var _antecedentes := Antecedentes.new()
var _devoluciones: Array[Mensaje] = []
var _mopa_secada := false
var _poetico_usado_en: Array[int] = []
var _reflexion: ReflexionDeCierre = null


func anotar_uso_de_poetico(
	identidad: StringName, resultado: ReglasDeLaLimpieza.Resultado, permitido: bool
) -> RegistroDePoetico:
	if (
		not permitido
		or not _jornada_abierta
		or terminada()
		or resultado != ReglasDeLaLimpieza.Resultado.BALDE_TENIDO
		or not AnomaliasDeLaJornada.sustituye_azul(identidad, _jornada)
	):
		return RegistroDePoetico.RECHAZADO
	if uso_de_poetico_en(_jornada):
		return RegistroDePoetico.REPETIDO
	_poetico_usado_en.append(_jornada)
	return RegistroDePoetico.ANOTADO


func uso_de_poetico_en(jornada: int) -> bool:
	return _poetico_usado_en.has(jornada)


func anotar_llamado(llamado: Llamado) -> void:
	if not _jornada_abierta or terminada() or _llamados.has(llamado):
		return
	_llamados.append(llamado)


func medios() -> int:
	return _legajo.medios()


func llamados() -> Array[Llamado]:
	return _llamados.duplicate()


## La partida del primer día: legajo limpio y la primera jornada por abrir.
##
## El constructor recibe el legajo en vez de armarlo para que el 019 pueda restaurar uno que
## viene de disco sin abrirle una segunda puerta a esta clase.
static func nueva() -> Partida:
	return Partida.new(Legajo.new())


## La partida de un guardado. Un diccionario vacío da la partida nueva.
static func desde(datos: Dictionary) -> Partida:
	var saneado := PartidaSerializada.sanear(datos)
	var medios: int = saneado[PartidaSerializada.clave(PartidaSerializada.Campo.MEDIOS)]
	var partida := Partida.new(Legajo.con_medios(medios))
	partida._jornada = saneado[PartidaSerializada.clave(PartidaSerializada.Campo.JORNADA)]
	partida._antecedentes = Antecedentes.desde(saneado)
	for dato: Variant in saneado[PartidaSerializada.clave(PartidaSerializada.Campo.DEVOLUCIONES)]:
		var mensaje := Mensaje.desde_datos(dato)
		if mensaje != null:
			partida._devoluciones.append(mensaje)
	partida._mopa_secada = saneado[PartidaSerializada.clave(PartidaSerializada.Campo.MOPA_SECADA)]
	partida._restaurar_la_investigacion(saneado)
	return partida


func _restaurar_la_investigacion(saneado: Dictionary) -> void:
	var notas := PackedStringArray()
	for dato: Variant in saneado[PartidaSerializada.clave(PartidaSerializada.Campo.NOTAS)]:
		var nota := Mensaje.desde_datos(dato)
		if nota != null:
			notas.append(nota.identidad)
	ReflexionDeCierre.restaurar_notas(_expediente, notas)
	var identidades := PackedStringArray()
	for dato: Variant in saneado[PartidaSerializada.clave(PartidaSerializada.Campo.EXPEDIENTE)]:
		if dato is String:
			identidades.append(dato)
	_expediente.restaurar(
		identidades, saneado[PartidaSerializada.clave(PartidaSerializada.Campo.ELECCIONES)]
	)
	var pendiente: int = saneado[PartidaSerializada.clave(
		PartidaSerializada.Campo.CIERRE_PENDIENTE
	)]
	if pendiente == _jornada - 1:
		_reflexion = ReflexionDeCierre.para(pendiente, _expediente)


## Si la mopa ya se secó una vez en la partida y se mostró su pensamiento (BR-SUB-014).
func mopa_secada() -> bool:
	return _mopa_secada


func anotar_mopa_secada() -> void:
	_mopa_secada = true


func _init(legajo: Legajo) -> void:
	_legajo = legajo
	_expediente = Expediente.new(CasoDeInvestigacion.de_la_partida())


## El legajo que la partida recibió, **la misma instancia** y no una copia. Con una copia, un
## legajo restaurado acumularía sobre otro objeto y la historia guardada no despediría a nadie.
func legajo() -> Legajo:
	return _legajo


## Los apercibimientos enteros acumulados, para el comentario del jefe.
##
## Existe para que el cableado de la escena no tenga que encadenar dos llamadas hasta el legajo:
## quienes lo leen necesitan el número, no la pieza que lo lleva.
func apercibimientos() -> int:
	return _legajo.apercibimientos()


## Las cuentas que la devolución lee entre noches, con la última noche cerrada ya anotada.
func antecedentes() -> Antecedentes:
	return _antecedentes


## Los mensajes de las devoluciones recibidas, en el orden en que llegaron.
func mensajes_del_jefe() -> PackedStringArray:
	var textos := PackedStringArray()
	for mensaje: Mensaje in _devoluciones:
		textos.append(mensaje.texto)
	return textos


func devoluciones_del_jefe() -> Array[Mensaje]:
	return _devoluciones.duplicate()


func datos_de_devoluciones() -> Array:
	var datos: Array = []
	for mensaje: Mensaje in _devoluciones:
		datos.append(mensaje.a_datos())
	return datos


func jornada() -> int:
	return _jornada


func final() -> Final:
	return _final


func terminada() -> bool:
	return _final != Final.EN_CURSO


## Si la noche en curso es la última que el contrato pide.
##
## La cuenta sale de las dos constantes y nunca de un número escrito acá: la partida numera
## desde `PRIMERA_JORNADA`, así que la última es esa más las que faltan.
func es_la_ultima_jornada() -> bool:
	var ultima := ReglasDeLaPartida.PRIMERA_JORNADA + ReglasDeLaPartida.JORNADAS_DE_LA_PARTIDA - 1
	return _jornada == ultima


## Las obligatorias de la jornada abierta, para que quien la haga correr cuente contra las
## mismas instancias que el turno está contando.
func obligatorias() -> Array[Tarea]:
	return _obligatorias


## Abre la noche y entrega su turno.
##
## **Las obligatorias se piden de nuevo en cada jornada, y ésa es la razón de ser de esta
## función.** Reusar la lista de ayer arrancaría la noche siguiente con las tareas ya
## completadas: la jornada empezaría ganada, sin un solo error y sin un solo rojo.
##
## Sobre una partida terminada no abre y devuelve `null`, por el mismo motivo que el guard de
## `cerrar_la_jornada()`: la puerta es pública y el 017 la va a tocar desde una pantalla. Sin
## esto, una noche jugada después del despido avanzaría una partida ya terminada.
func abrir_la_jornada() -> Turno:
	if terminada():
		return null
	_llamados.clear()
	_obligatorias = Apertura.obligatorias(_jornada)
	_jornada_abierta = true
	return Apertura.turno_de_la_jornada(_obligatorias)


## Anota la noche y avanza, o termina la partida.
##
## El guard de `_jornada_abierta` es lo que hace que la puerta sea idempotente: es pública, y el
## 017 la va a tocar desde una pantalla. Sin él, un segundo cierre anota una jornada que nadie
## jugó, con la banda que le toque.
##
## **El despido se pregunta antes que el contrato cumplido**, y no es un detalle de orden: la
## última noche puede cerrar mal justo cuando el legajo llega al tope, y ahí felicitar a alguien
## recién echado sería la lectura equivocada de las dos condiciones a la vez.
func cerrar_la_jornada(cumplidas: int) -> void:
	if not _jornada_abierta:
		return
	_jornada_abierta = false
	var cerrada := _jornada
	var medios_antes := _legajo.medios()
	_legajo.registrar(cumplidas, _obligatorias.size(), _llamados.size())
	var sin_cumplir: Array[Tarea.Tipo] = []
	for tarea: Tarea in _obligatorias:
		if not tarea.completada():
			sin_cumplir.append(tarea.tipo())
	_antecedentes.anotar_noche(sin_cumplir, _llamados, _legajo.medios() - medios_antes)
	if _legajo.despedido():
		_final = Final.DESPEDIDO
	elif es_la_ultima_jornada():
		_final = Final.CONTRATO_CUMPLIDO
	else:
		_jornada += 1
	_reflexion = null if terminada() else ReflexionDeCierre.para(cerrada, _expediente)
	# Después de anotar la noche: la devolución lee las cuentas que ya la incluyen.
	_devoluciones.append_array(DevolucionDelJefe.new(cerrada, self).mensajes_fechados())
