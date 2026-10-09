## El mensaje del jefe a la mañana siguiente, ya decidido: un saludo, una línea por obligatoria
## y un comentario general.
##
## **Todo lo que la placa dice se arma acá, y ésa es la única decisión de diseño de este
## archivo.** Los mismos textos elegidos con una condición adentro de la pantalla nacerían sin
## test y con los nodos en verde: está medido que ni el gate de tests ni el de capas ven una
## regla escrita en `ui/`. Acá el test es barato y obligatorio.
##
## **Recibe y no recalcula.** La jornada y los apercibimientos llegan de afuera: quien los cuenta
## es la partida, y una segunda cuenta acá sería la misma regla en dos lugares.
##
## No reusa `Marcador.tareas()`: la placa no muestra `"3/5"` sino las líneas del jefe.
class_name ParteDeCierre
extends RefCounted

enum Opcion { SEGUIR, VOLVER_AL_MENU }

## El número de jornada se muestra sobre el total y no solo: «jornada 4» no dice nada,
## «jornada 4 de 5» dice cuánto falta. El total sale de la constante de la partida y nunca de
## un número escrito.
const SALUDO := "Jornada %d de %d. El jefe dejó una nota."

const MOTIVOS: Dictionary[Partida.Llamado, String] = {
	Partida.Llamado.LOCAL_DESORDENADO: "Local desordenado",
	Partida.Llamado.OBJETO_AFUERA: "Objetos fuera del local",
	Partida.Llamado.PAPEL_EN_EL_INODORO: "Papel en el inodoro",
	Partida.Llamado.OBJETO_TIRADO: "Objetos importantes en la basura",
}

## Lo que el jugador puede elegir según cómo quedó la partida. Con la partida terminada no hay
## noche siguiente que abrir.
const OPCIONES_POR_FINAL: Dictionary[Partida.Final, Array] = {
	Partida.Final.EN_CURSO: [Opcion.SEGUIR, Opcion.VOLVER_AL_MENU],
	Partida.Final.DESPEDIDO: [Opcion.VOLVER_AL_MENU],
	Partida.Final.CONTRATO_CUMPLIDO: [Opcion.VOLVER_AL_MENU],
}

var _jornada: int
var _obligatorias: Array[Tarea]
var _apercibimientos: int
var _final: Partida.Final
var _llamados: Array[Partida.Llamado]


func _init(
	jornada: int,
	obligatorias: Array[Tarea],
	apercibimientos: int,
	final: Partida.Final,
	llamados: Array[Partida.Llamado] = []
) -> void:
	_jornada = jornada
	_obligatorias = obligatorias
	_apercibimientos = apercibimientos
	_final = final
	_llamados = llamados.duplicate()


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
	var penalizacion := (
		String
		. num(float(Reglas.MEDIOS_POR_LLAMADO) / Reglas.MEDIOS_POR_APERCIBIMIENTO, 1)
		. replace(".", ",")
	)
	for motivo: Partida.Llamado in MOTIVOS:
		if _llamados.has(motivo):
			renglones.append("%s (+%s puntos)" % [MOTIVOS[motivo], penalizacion])
	return renglones


func comentario() -> String:
	return CatalogoDeReacciones.del_comentario(_apercibimientos).texto


## Qué botones lleva la placa, en orden.
func opciones() -> Array[Opcion]:
	var elegibles: Array[Opcion] = []
	elegibles.assign(OPCIONES_POR_FINAL[_final])
	return elegibles
