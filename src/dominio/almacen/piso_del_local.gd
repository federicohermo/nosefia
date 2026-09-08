## El piso del local: qué zonas hay que limpiar y cuánto le falta a cada una.
##
## **Son cuatro zonas y están repartidas**, y ahí está el término que esta tarea aporta a la resta
## del turno: cada una obliga a un tramo de caminata que no se puede saltear. La distancia la fija
## `ReglasDeLaLimpieza` y la escena la cumple; acá vive la cuenta.
##
## **Limpiar se puede dejar por la mitad**, que es lo que la vuelve parte de la tensión: dos
## pasadas, irse a la computadora, volver, y la mancha sigue esperando en una. Es la misma forma
## del 008 con otro recurso escaso — allá la unidad del depósito, acá la única mano.
##
## Es la mitad de limpiar que se ejerce sin levantar una escena: acá no hay un solo `Node3D`.
class_name PisoDelLocal
extends RefCounted

## Las cuatro esquinas del local que hay que pasar. Es un `enum` porque el conjunto es cerrado: un
## `"deposito"` mal escrito no rompe nada, la mancha simplemente no se limpia nunca.
enum Zona { ENTRADA, PASILLO, DEPOSITO, VENTANILLA }

## Cómo salió la pasada. `MANCHA_LIMPIADA` y `PASADA` se distinguen porque son dos cosas distintas
## adelante del jugador: una mancha que desaparece y una que se aclara.
enum Resultado { PASADA, MANCHA_LIMPIADA, SIN_TRAPEADOR, YA_ESTABA_LIMPIA }

## `Zona` → `Mancha`, en el orden del `enum`.
var _manchas: Dictionary = {}


func _init(manchas: Dictionary) -> void:
	_manchas = manchas


## El piso de una noche: una mancha por cada zona declarada.
##
## Se recorre el `enum` y no se enumeran cuatro a mano: una quinta zona es una línea en el `enum`
## y este archivo no se toca. Y no se sortea nada — sortear las zonas haría variar el presupuesto
## de trayecto que el 011 mide.
static func de_la_jornada() -> PisoDelLocal:
	var manchas := {}
	for zona: Zona in Zona.values():
		manchas[zona] = Mancha.new()
	return PisoDelLocal.new(manchas)


## Cuántas pasadas lleva el piso entero.
##
## Se multiplica y nunca se escribe el producto: con las cuatro zonas y tres pasadas son doce, y
## un `12` acá quedaría viejo el día que se agregue una zona o se rebalanceen las pasadas.
func pasadas_totales() -> int:
	return _manchas.size() * ReglasDeLaLimpieza.PASADAS_POR_MANCHA


func zonas() -> Array:
	return _manchas.keys()


## Cuántas pasadas le faltan a esa zona, o `0` si no es una zona del piso.
func pasadas_restantes(zona: Zona) -> int:
	var mancha := mancha_de(zona)
	if mancha == null:
		return 0
	return mancha.pasadas_restantes()


## La mancha de esa zona, o `null`.
func mancha_de(zona: Zona) -> Mancha:
	if not _manchas.has(zona):
		return null
	var mancha: Mancha = _manchas[zona]
	return mancha


## Pasa el trapeador por esa zona, y devuelve cómo salió.
##
## **Lo que se lleva en la mano entra como `id` y no como objeto**: es lo que permite ejercer esto
## sin el 006 puesto, y lo que evita que el dominio de la limpieza tenga que conocer al de agarrar.
## Un `id` que no es el del trapeador —incluido el centinela de mano vacía— no baja una sola
## pasada: limpiar con la lata en la mano sería limpiar gratis.
func pasar(zona: Zona, id_en_la_mano: StringName) -> Resultado:
	if id_en_la_mano != ReglasDeLaLimpieza.ID_DEL_TRAPEADOR:
		return Resultado.SIN_TRAPEADOR
	var mancha := mancha_de(zona)
	if mancha == null or not mancha.pasar():
		return Resultado.YA_ESTABA_LIMPIA
	if mancha.esta_limpia():
		return Resultado.MANCHA_LIMPIADA
	return Resultado.PASADA


## Si no queda una sola mancha.
##
## Se recorren todas y no se lleva un contador de limpias: un contador se desincronizaría el día
## que alguien limpie por otro camino, y ésa es la clase de bug que no da error.
func esta_limpio() -> bool:
	for zona: Zona in _manchas:
		if not mancha_de(zona).esta_limpia():
			return false
	return true
