## El mensaje del jefe a la mañana siguiente, ya decidido: un saludo, una línea por obligatoria
## y un comentario general.
##
## **Todo lo que la placa dice se arma acá, y ésa es la única decisión de diseño de este
## archivo.** Los mismos textos elegidos con una condición adentro de la pantalla nacerían sin
## test y con los seis nodos en verde: está medido que ni el gate de tests ni el de capas ven una
## regla escrita en `ui/`. Acá el test es barato y obligatorio.
##
## **Recibe y no recalcula.** La jornada y los apercibimientos llegan de afuera: quien los cuenta
## es la partida, y una segunda cuenta acá sería la misma regla en dos lugares.
##
## No reusa `Marcador.tareas()`: la placa no muestra `"3/5"` sino las líneas del jefe.
class_name ParteDeCierre
extends RefCounted

## El número de jornada se muestra sobre el total y no solo: «jornada 4» no dice nada, «jornada 4
## de 5» dice cuánto falta. El total sale de la constante del 016 y nunca de un número escrito.
const SALUDO := "Jornada %d de %d. El jefe dejó una nota."

## El tope se cita por su constante y nunca como número: escrito acá, moverlo en `reglas.gd`
## dejaría la placa mintiendo sin que nada avise.
const AVISO_DE_RIESGO := "Llevás %d apercibimientos de %d."

var _jornada: int
var _obligatorias: Array[Tarea]
var _apercibimientos: int


func _init(jornada: int, obligatorias: Array[Tarea], apercibimientos: int) -> void:
	_jornada = jornada
	_obligatorias = obligatorias
	_apercibimientos = apercibimientos


func jornada() -> int:
	return _jornada


func apercibimientos() -> int:
	return _apercibimientos


func saludo() -> String:
	return SALUDO % [_jornada, ReglasDeLaPartida.JORNADAS_DE_LA_PARTIDA]


## Una línea por obligatoria, **en el orden en que se declararon**.
##
## El orden es el de la lista que armó la jornada y no uno propio: el jugador leyó las tareas en
## ese orden toda la noche, y reordenarlas acá lo obligaría a buscar cuál es cuál.
func lineas() -> Array[String]:
	var renglones: Array[String] = []
	for tarea in _obligatorias:
		renglones.append(CatalogoDeReacciones.de_la_tarea(tarea.tipo(), tarea.completada()).texto)
	return renglones


func comentario() -> String:
	return CatalogoDeReacciones.del_comentario(_apercibimientos).texto


func umbral_del_despido() -> int:
	return Reglas.APERCIBIMIENTOS_HASTA_EL_DESPIDO


## Si el legajo ya tiene algo encima. Con cero no hay nada que avisar: es el mismo estado que
## haber cumplido las cinco, y una placa que avisa siempre no avisa nunca.
func en_riesgo() -> bool:
	return _apercibimientos > 0


func aviso_de_riesgo() -> String:
	return AVISO_DE_RIESGO % [_apercibimientos, umbral_del_despido()]
