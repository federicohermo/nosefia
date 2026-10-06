## El piso de una jornada: las manchas que hay que borrar y los útiles con que se borran.
##
## «Piso» es lo que hay que dejar limpio, aunque la mancha del depósito esté en una pared: el
## nombre es el de la obligatoria, no el de la superficie.
##
## **Limpiar cuesta ir al baño**, y ahí está el término que esta tarea aporta a la resta del turno:
## cada mancha pide su jabón, el jabón se mezcla en el balde, y cambiar de jabón es vaciar el balde
## y volver a llenarlo. Acá vive la cuenta; la distancia la pone la escena.
##
## Es la mitad de limpiar que se ejerce sin levantar una escena: acá no hay un solo `Node3D`.
class_name PisoDelLocal
extends RefCounted

## Dónde pone la jornada cada mancha. Es un `enum` porque el conjunto es cerrado: un lugar mal
## escrito no rompe nada, la mancha simplemente no se borra nunca.
enum Lugar { ENTRADA, GONDOLAS, DEPOSITO, BANO }

## Qué mancha hay en cada lugar al abrir la jornada: dos de polvo en el local, una de moho en la
## pared del depósito y una de caca al lado del inodoro. Es la primera jornada de la ficha; las
## otras cuatro no están definidas todavía, y arrancan como ésta.
const MANCHAS_DE_LA_JORNADA: Dictionary[Lugar, ReglasDeLaLimpieza.TipoDeMancha] = {
	Lugar.ENTRADA: ReglasDeLaLimpieza.TipoDeMancha.POLVO,
	Lugar.GONDOLAS: ReglasDeLaLimpieza.TipoDeMancha.POLVO,
	Lugar.DEPOSITO: ReglasDeLaLimpieza.TipoDeMancha.MOHO,
	Lugar.BANO: ReglasDeLaLimpieza.TipoDeMancha.CACA,
}

var _manchas: Dictionary[Lugar, Mancha] = {}
var _balde := Balde.new()
var _mopa := Mopa.new()

## Qué hace cada cosa en la mano sobre cada otra. Es la única puerta de los gestos: sin el par
## declarado, ni la mopa mojada del jabón justo borra nada.
var _uso := Uso.para_el_almacen()


func _init(manchas: Dictionary[Lugar, Mancha]) -> void:
	_manchas = manchas


## El piso de una noche: sus cuatro manchas sucias, el balde vacío y la mopa seca.
##
## Se construye entero cada vez: con un piso compartido, lo borrado anoche llegaría borrado esta
## noche, y el balde teñido de anoche ahorraría el primer viaje a la canilla.
static func de_la_jornada() -> PisoDelLocal:
	var manchas: Dictionary[Lugar, Mancha] = {}
	for lugar: Lugar in MANCHAS_DE_LA_JORNADA:
		manchas[lugar] = Mancha.new(MANCHAS_DE_LA_JORNADA[lugar])
	return PisoDelLocal.new(manchas)


func lugares() -> Array[Lugar]:
	var lugares: Array[Lugar] = []
	lugares.assign(_manchas.keys())
	return lugares


## La mancha de ese lugar, o `null` si la jornada no puso ninguna ahí.
func mancha_de(lugar: Lugar) -> Mancha:
	return _manchas.get(lugar, null)


func balde() -> Balde:
	return _balde


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
			return _balde.tenir(ReglasDeLaLimpieza.agua_del_jabon(en_la_mano))
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
func desgastar_mopa(en_la_mano: StringName, segundos: float, metros: float) -> void:
	var recorrido := metros if en_la_mano == ReglasDeLaLimpieza.ID_DE_LA_MOPA else 0.0
	_mopa.desgastar(segundos, recorrido)


## La escena mide alcance, obstáculos y sectores reservados; el dominio sólo recibe el permiso.
func humedecer_piso(en_la_mano: StringName, habilitado: bool) -> ReglasDeLaLimpieza.Resultado:
	if _uso.resolver(en_la_mano, Uso.PISO) != Uso.Efecto.HUMEDECER:
		return ReglasDeLaLimpieza.Resultado.SIN_EFECTO
	if not _mopa.esta_mojada():
		return ReglasDeLaLimpieza.Resultado.MOPA_SECA
	if _mopa.agua() != ReglasDeLaLimpieza.Agua.LIMPIA or not habilitado:
		return ReglasDeLaLimpieza.Resultado.SIN_EFECTO
	return ReglasDeLaLimpieza.Resultado.CHARCO_DEJADO
