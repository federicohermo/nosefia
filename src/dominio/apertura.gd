## Cómo se abre una jornada: qué tareas pide el jefe esta noche y con cuánto tiempo se arranca.
##
## El 001 dejó esto abierto a propósito —«las obligatorias se reciben, no se construyen adentro
## del `Turno`»— y acá se cierra. **Va en `dominio/` y no en el script de la escena** porque
## «cuáles son las obligatorias de una jornada» es una regla del juego, y en `escenas/` una regla
## nace sin test y ningún gate lo dice.
##
## La lista se arma **recorriendo `Tarea.Tipo`**, no enumerando tareas a mano. El 001 aterrizó
## con las cinco declaradas —`SACAR_LA_BASURA` incluida—, así que acá no hay ningún `5` escrito:
## una sexta se agrega al `enum` del 001 con su costo en `reglas.gd` y este archivo no se toca.
class_name Apertura
extends RefCounted


## Una tarea nueva por cada tipo declarado.
##
## Cada llamada devuelve instancias nuevas, y por eso quien abre la jornada la pide **una sola
## vez**: el turno cuenta contra las instancias que recibió, así que completar una tarea de una
## segunda lista devolvería `true` sin que `tareas_cumplidas()` suba — sin error y sin rojo.
static func obligatorias() -> Array[Tarea]:
	var lista: Array[Tarea] = []
	for tipo: Tarea.Tipo in Tarea.Tipo.values():
		lista.append(Tarea.new(tipo))
	return lista


## Cuántas obligatorias tiene una jornada.
##
## Existe porque el `Turno` del 001 no expone cuántas son: recibe la lista y no tiene getter. El
## HUD pide el número a la misma fuente que armó la lista y no a una segunda copia.
static func cantidad_de_obligatorias() -> int:
	return Tarea.Tipo.size()


## El turno de la noche, con el presupuesto entero y las obligatorias que se le declaran.
##
## **Recibe la lista y no la vuelve a construir**: es lo que hace que el reloj pueda entregarle
## al 008 la misma instancia de `Tarea` que el turno está contando.
static func turno_de_la_jornada(obligatorias: Array[Tarea]) -> Turno:
	return Turno.new(Reglas.DURACION_DEL_TURNO, obligatorias)
