## Qué se lleva encima el empleado, y por qué a veces no se puede llevar nada más.
##
## Es la mitad de agarrar que se ejerce sin levantar una escena: acá no hay un solo `Node3D`. Lo
## que `Agarre` hace con esa respuesta —reparentar el cuerpo, congelarle la física— ya no es una
## regla del juego, es traducción al motor.
class_name Manos
extends RefCounted

## Los dos motivos por los que no se puede agarrar algo, más el «se puede». Es un `enum` y no un
## `String` porque el conjunto es cerrado: `"manos_llenas"` mal escrito no rompe nada, el `if`
## simplemente no entra nunca. El 014 cita `MANOS_LLENAS` por su nombre.
enum Rechazo { NINGUNO, MANOS_LLENAS, NO_ES_LEVANTABLE }

## Un `Array` y no un campo suelto para que `MANOS_DISPONIBLES` gobierne de verdad: el día que
## valga 2, acá no cambia una línea. Con 1 la lista tiene a lo sumo un elemento.
var _sostenidos: Array[ObjetoDelAlmacen] = []


## Lo que hay en la mano, o `null`.
func sostenido() -> ObjetoDelAlmacen:
	if _sostenidos.is_empty():
		return null
	return _sostenidos[-1]


## Por qué no se puede agarrar esto, o `NINGUNO`.
##
## **No poder levantarlo se chequea primero, y las manos llenas después.** No es indistinto: no
## poder levantarlo es una propiedad de la cosa y vale siempre, mientras que las manos llenas se
## resuelven soltando. Al revés, apuntarle a una puerta con algo en la mano contestaría el motivo
## que el jugador puede resolver, y al vaciar las manos la puerta seguiría sin levantarse.
func motivo_de_rechazo(objeto: ObjetoDelAlmacen) -> Rechazo:
	if objeto == null or not objeto.es_levantable():
		return Rechazo.NO_ES_LEVANTABLE
	if _sostenidos.size() >= ReglasDeLosObjetos.MANOS_DISPONIBLES:
		return Rechazo.MANOS_LLENAS
	return Rechazo.NINGUNO


## Devuelve `true` **sólo si lo agarró ahora**. Un rechazo no cambia lo que ya se lleva.
func agarrar(objeto: ObjetoDelAlmacen) -> bool:
	if motivo_de_rechazo(objeto) != Rechazo.NINGUNO:
		return false
	_sostenidos.append(objeto)
	return true


## Devuelve lo que había, o `null` con las manos vacías.
##
## De ese `null` se agarra `Agarre` para no avisar que se soltó algo cuando no había nada: sin
## él, cada clic al aire anunciaría un objeto soltado.
func soltar() -> ObjetoDelAlmacen:
	if _sostenidos.is_empty():
		return null
	return _sostenidos.pop_back()


## Deja las manos vacías, hayan estado llenas o no. Lo llaman el cierre de la jornada y la
## suspensión del jugador, que pueden pasar dos veces seguidas.
func vaciar() -> void:
	_sostenidos.clear()
