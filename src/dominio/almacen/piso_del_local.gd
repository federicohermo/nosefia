## El piso de una jornada: las manchas que hay que borrar y los útiles con que se borran.
##
## «Piso» es lo que hay que dejar limpio, aunque haya manchas en las paredes y en el techo: el
## nombre es el de la obligatoria, no el de la superficie.
##
## **Limpiar cuesta ir al baño**, y ahí está el término que esta tarea aporta a la resta del turno:
## cada mancha pide su jabón, el jabón se mezcla en el balde, y cambiar de jabón es vaciar el balde
## y volver a llenarlo. Acá vive la cuenta; la distancia la pone la escena.
##
## Es la mitad de limpiar que se ejerce sin levantar una escena: acá no hay un solo `Node3D`.
class_name PisoDelLocal
extends RefCounted

## Dónde puede poner una jornada cada mancha. Es un `enum` porque el conjunto es cerrado: un lugar
## mal escrito no rompe nada, la mancha simplemente no se borra nunca.
##
## **Los lugares nuevos van al final**: la escena guarda cada disco con el número de su lugar, y
## reordenar cambiaría en silencio qué disco es qué mancha.
enum Lugar {
	ENTRADA,
	GONDOLAS,
	DEPOSITO,
	BANO,
	RINCON_OPUESTO_AL_MOSTRADOR,
	ARRIBA_DEL_TABLERO,
	PARED_DEL_OTRO_INODORO,
	DETRAS_DEL_MOSTRADOR,
	CERCA_DE_LAS_HELADERAS,
	PUERTA_DEL_BANO_EN_EL_LOCAL,
	ESQUINA_ALTA_DEL_DEPOSITO,
	AL_LADO_DEL_CONTENEDOR,
	PUERTA_DEL_BANO_EN_EL_BANO,
	TECHO_DEL_BANO,
	BAJO_LA_PUERTA_DEL_CUBICULO,
}

## Sobre qué está la mancha. El paso del jugador toca sólo las del piso.
enum Superficie { PISO, PARED, TECHO }

## El script de las habitaciones no declara `class_name`: se preloadea para nombrar su `enum`.
const ReglasDelCierre := preload("res://src/dominio/almacen/reglas_del_cierre.gd")

## La habitación y la superficie de cada lugar: `[Habitacion, Superficie]`.
const LUGARES: Dictionary[Lugar, Array] = {
	Lugar.ENTRADA: [ReglasDelCierre.Habitacion.LOCAL, Superficie.PISO],
	Lugar.GONDOLAS: [ReglasDelCierre.Habitacion.LOCAL, Superficie.PISO],
	Lugar.DEPOSITO: [ReglasDelCierre.Habitacion.DEPOSITO, Superficie.PARED],
	Lugar.BANO: [ReglasDelCierre.Habitacion.BANO, Superficie.PISO],
	Lugar.RINCON_OPUESTO_AL_MOSTRADOR: [ReglasDelCierre.Habitacion.LOCAL, Superficie.PISO],
	Lugar.ARRIBA_DEL_TABLERO: [ReglasDelCierre.Habitacion.DEPOSITO, Superficie.PARED],
	Lugar.PARED_DEL_OTRO_INODORO: [ReglasDelCierre.Habitacion.BANO, Superficie.PARED],
	Lugar.DETRAS_DEL_MOSTRADOR: [ReglasDelCierre.Habitacion.LOCAL, Superficie.PISO],
	Lugar.CERCA_DE_LAS_HELADERAS: [ReglasDelCierre.Habitacion.LOCAL, Superficie.PISO],
	Lugar.PUERTA_DEL_BANO_EN_EL_LOCAL: [ReglasDelCierre.Habitacion.LOCAL, Superficie.PISO],
	Lugar.ESQUINA_ALTA_DEL_DEPOSITO: [ReglasDelCierre.Habitacion.DEPOSITO, Superficie.PARED],
	Lugar.AL_LADO_DEL_CONTENEDOR: [ReglasDelCierre.Habitacion.DEPOSITO, Superficie.PARED],
	Lugar.PUERTA_DEL_BANO_EN_EL_BANO: [ReglasDelCierre.Habitacion.BANO, Superficie.PISO],
	Lugar.TECHO_DEL_BANO: [ReglasDelCierre.Habitacion.BANO, Superficie.TECHO],
	Lugar.BAJO_LA_PUERTA_DEL_CUBICULO: [ReglasDelCierre.Habitacion.BANO, Superficie.PISO],
}

## Qué mancha pone cada jornada en cada lugar, según la ficha: `jornada → {Lugar: TipoDeMancha}`.
##
## Una jornada sin fila arranca como la primera: las filas de la 3 a la 5 dependen de un cuartito
## de limpieza que el almacén no tiene y de techos que hoy quedan fuera del alcance de la mira.
const MANCHAS_POR_JORNADA: Dictionary[int, Dictionary] = {
	1:
	{
		Lugar.ENTRADA: ReglasDeLaLimpieza.TipoDeMancha.POLVO,
		Lugar.GONDOLAS: ReglasDeLaLimpieza.TipoDeMancha.POLVO,
		Lugar.RINCON_OPUESTO_AL_MOSTRADOR: ReglasDeLaLimpieza.TipoDeMancha.POLVO,
		Lugar.DEPOSITO: ReglasDeLaLimpieza.TipoDeMancha.MOHO,
		Lugar.ARRIBA_DEL_TABLERO: ReglasDeLaLimpieza.TipoDeMancha.MOHO,
		Lugar.BANO: ReglasDeLaLimpieza.TipoDeMancha.CACA,
		Lugar.PARED_DEL_OTRO_INODORO: ReglasDeLaLimpieza.TipoDeMancha.CACA,
	},
	2:
	{
		Lugar.DETRAS_DEL_MOSTRADOR: ReglasDeLaLimpieza.TipoDeMancha.POLVO,
		Lugar.CERCA_DE_LAS_HELADERAS: ReglasDeLaLimpieza.TipoDeMancha.POLVO,
		Lugar.PUERTA_DEL_BANO_EN_EL_LOCAL: ReglasDeLaLimpieza.TipoDeMancha.POLVO,
		Lugar.ESQUINA_ALTA_DEL_DEPOSITO: ReglasDeLaLimpieza.TipoDeMancha.MOHO,
		Lugar.AL_LADO_DEL_CONTENEDOR: ReglasDeLaLimpieza.TipoDeMancha.MOHO,
		Lugar.PUERTA_DEL_BANO_EN_EL_BANO: ReglasDeLaLimpieza.TipoDeMancha.POLVO,
		Lugar.TECHO_DEL_BANO: ReglasDeLaLimpieza.TipoDeMancha.MOHO,
		Lugar.BAJO_LA_PUERTA_DEL_CUBICULO: ReglasDeLaLimpieza.TipoDeMancha.CACA,
	},
}
var _manchas: Dictionary[Lugar, Mancha] = {}
var _balde := Balde.new()
var _mopa := Mopa.new()

## Qué hace cada cosa en la mano sobre cada otra. Es la única puerta de los gestos: sin el par
## declarado, ni la mopa mojada del jabón justo borra nada.
var _uso := Uso.para_el_almacen()
var _jornada: int


func _init(
	manchas: Dictionary[Lugar, Mancha], jornada: int = ReglasDeLaPartida.PRIMERA_JORNADA
) -> void:
	_manchas = manchas
	_jornada = jornada
	_uso = Uso.para_el_almacen(jornada)


## El piso de esa noche: las manchas que declara su fila, todas sucias, el balde vacío y la mopa
## seca. Una jornada sin fila arranca con las de la primera.
##
## Se construye entero cada vez: con un piso compartido, lo borrado anoche llegaría borrado esta
## noche, y el balde teñido de anoche ahorraría el primer viaje a la canilla.
static func de_la_jornada(jornada: int) -> PisoDelLocal:
	var fila: Dictionary = MANCHAS_POR_JORNADA.get(
		jornada, MANCHAS_POR_JORNADA[ReglasDeLaPartida.PRIMERA_JORNADA]
	)
	var manchas: Dictionary[Lugar, Mancha] = {}
	for lugar: Lugar in fila:
		manchas[lugar] = Mancha.new(fila[lugar])
	return PisoDelLocal.new(manchas, jornada)


## En qué habitación está ese lugar, según la pertenencia del cierre.
static func habitacion_de(lugar: Lugar) -> ReglasDelCierre.Habitacion:
	var habitacion: ReglasDelCierre.Habitacion = LUGARES[lugar][0]
	return habitacion


## Si ese lugar está en el piso, en una pared o en el techo.
static func superficie_de(lugar: Lugar) -> Superficie:
	var superficie: Superficie = LUGARES[lugar][1]
	return superficie


func lugares() -> Array[Lugar]:
	var lugares: Array[Lugar] = []
	lugares.assign(_manchas.keys())
	return lugares


## La mancha de ese lugar, o `null` si la jornada no puso ninguna ahí.
func mancha_de(lugar: Lugar) -> Mancha:
	return _manchas.get(lugar, null)


func balde() -> Balde:
	return _balde


func jornada() -> int:
	return _jornada


func mopa() -> Mopa:
	return _mopa


## Si no queda una sola mancha.
##
## Se recorren todas y no se lleva un contador de borradas: un contador se desincronizaría el día
## que alguien borre por otro camino, y ésa es la clase de bug que no da error.
func esta_limpio() -> bool:
	for lugar: Lugar in _manchas:
		if not _manchas[lugar].esta_limpia():
			return false
	return true


## Usa lo que se lleva en la mano sobre el balde, el lavatorio o el inodoro, y devuelve cómo salió.
##
## **Lo que se lleva entra como `id` y no como objeto**: es lo que permite ejercer esto sin agarrar
## nada, y lo que evita que el dominio de la limpieza tenga que conocer al de agarrar. Un par que
## no es un gesto de limpiar —otro objeto, la mano vacía, uno de los gestos al revés— contesta
## `SIN_EFECTO` y no cambia nada. Sobre una mancha se pasa con `pasar()`, que sabe cuál.
func usar(en_la_mano: StringName, objetivo: StringName) -> ReglasDeLaLimpieza.Resultado:
	match _uso.resolver(en_la_mano, objetivo):
		Uso.Efecto.LLENAR:
			return _balde.llenar()
		Uso.Efecto.TENIR:
			return _balde.tenir(ReglasDeLaLimpieza.agua_del_jabon(en_la_mano, _jornada))
		Uso.Efecto.VACIAR:
			return _balde.vaciar()
		Uso.Efecto.MOJAR:
			return _mopa.mojar_en(_balde)
		Uso.Efecto.ENJUAGAR:
			return _mopa.enjuagar()
	return ReglasDeLaLimpieza.Resultado.SIN_EFECTO


## Pasa lo que se lleva en la mano por la mancha de ese lugar, y devuelve cómo salió.
func pasar(en_la_mano: StringName, lugar: Lugar) -> ReglasDeLaLimpieza.Resultado:
	var mancha := mancha_de(lugar)
	if mancha == null or _uso.resolver(en_la_mano, Uso.MANCHA) != Uso.Efecto.LIMPIAR:
		return ReglasDeLaLimpieza.Resultado.SIN_EFECTO
	return mancha.borrar_con(_mopa)


## El tiempo gasta la mopa esté donde esté; los metros, sólo si es lo que se lleva en la mano.
## Devuelve si la mopa se secó en este paso.
func desgastar_mopa(en_la_mano: StringName, segundos: float, metros: float) -> bool:
	var recorrido := metros if en_la_mano == ReglasDeLaLimpieza.ID_DE_LA_MOPA else 0.0
	return _mopa.desgastar(segundos, recorrido)


## La escena mide alcance, obstáculos y sectores reservados; el dominio sólo recibe el permiso.
func humedecer_piso(en_la_mano: StringName, habilitado: bool) -> ReglasDeLaLimpieza.Resultado:
	if _uso.resolver(en_la_mano, Uso.PISO) != Uso.Efecto.HUMEDECER:
		return ReglasDeLaLimpieza.Resultado.SIN_EFECTO
	if not _mopa.esta_mojada():
		return ReglasDeLaLimpieza.Resultado.MOPA_SECA
	if _mopa.agua() != ReglasDeLaLimpieza.Agua.LIMPIA or not habilitado:
		return ReglasDeLaLimpieza.Resultado.SIN_EFECTO
	return ReglasDeLaLimpieza.Resultado.CHARCO_DEJADO
