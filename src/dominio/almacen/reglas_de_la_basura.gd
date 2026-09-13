## Los valores fijos de sacar la basura: cuántas bolsas hay, cuán lejos está el descarte y cuánto
## mide su zona.
##
## Es un archivo aparte de `reglas.gd` por el mismo criterio que separa a los otros `reglas_de_*`
## de esta carpeta: no es de qué trata el número, es quién lo toca y probando qué. `reglas.gd` se
## toca discutiendo cuánto dura la noche; esto, probando si la basura obliga a caminar.
##
## **No hay ninguna constante que diga «esta tarea cuesta caminar».** El trayecto no es un número:
## es una consecuencia de tres hechos afirmables —una mano y tres bolsas son tres viajes, el
## descarte está lejos de todo, y esa distancia no entra en el alcance de la mira—. Si alguien la
## resuelve sin caminar, uno de los tres se pone rojo.
class_name ReglasDeLaBasura
extends RefCounted

## Cuántas bolsas hay que sacar en una jornada.
##
## **Tres, y lo que importa es que sea mayor que `ReglasDeLosObjetos.MANOS_DISPONIBLES`**: con una
## sola mano son tres viajes de ida y vuelta, y no hay forma de hacerlo en uno. Eso no se declara
## en ningún lado — se deduce de dos constantes, y hay un caso que las compara.
const BOLSAS_DE_LA_JORNADA := 3

## A cuánto está el descarte de todo lo demás, en metros.
##
## **Tiene que ser mayor que `ReglasDelJugador.ALCANCE_DE_LA_MIRA`**: si no lo fuera, el fondo
## quedaría a la vista desde la tarea de al lado y el viaje dejaría de existir sin que nada lo
## dijera. Es un mínimo, y `almacen.tscn` lo cumple con margen — hay un caso que mide las
## posiciones de verdad.
const DISTANCIA_MINIMA_AL_DESCARTE := 6.0

## El radio de la zona donde vale soltar la bolsa, en metros.
##
## Es chico a propósito: una zona grande convertiría «llegar al fondo» en «tirarla más o menos
## para allá», que es exactamente el modo de falla que este spec vino a cerrar.
##
## El `.tscn` de la zona escribe este número **otra vez**, porque un `.tscn` no puede leer una
## constante. Por eso hay un caso que compara los dos: sin él, la esfera de la escena y la regla
## se separan y el jugador suelta la bolsa donde el juego dice que no cuenta.
const RADIO_DEL_DESCARTE := 1.5

## Con qué empieza el `id` de cada bolsa. Las bolsas se numeran de 1 a `BOLSAS_DE_LA_JORNADA`, así
## que agregar una es subir la constante y poner su `.tres` — no hay una lista escrita dos veces.
const PREFIJO_DE_LA_BOLSA := "bolsa_de_basura_"


## El `id` de la bolsa número `numero`, contando desde 1.
static func id_de_la_bolsa(numero: int) -> StringName:
	return StringName(PREFIJO_DE_LA_BOLSA + str(numero))


## Los `id` de las bolsas de la jornada, en orden.
static func ids_de_las_bolsas() -> Array[StringName]:
	var ids: Array[StringName] = []
	for numero in range(1, BOLSAS_DE_LA_JORNADA + 1):
		ids.append(id_de_la_bolsa(numero))
	return ids
