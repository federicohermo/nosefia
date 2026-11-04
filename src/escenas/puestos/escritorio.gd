## El escritorio del local: el mueble con la computadora. Cablea y nada más.
##
## **No decide nada sobre el juego.** Si se puede abrir y cuándo `REGISTRAR` está
## cumplida son preguntas del dominio; qué señal va con qué método es lo único que se decide acá.
##
## **Suspender es clavar la cámara, y alcanza.** El 004 dejó `suspender()` y `reanudar()` en el
## jugador: sin esas dos puertas, abrir la computadora degradaría en silencio —el mouse seguiría
## girando la cámara y el jugador seguiría caminando detrás del panel—.
##
## **Se sale con el clic derecho, y la tecla de la pausa también.** Ésa la atiende el nodo de la
## pausa, que registra a este puesto y le pide cerrar. Pausar con la computadora abierta pasa por
## el segundo toque. El nombre de esa acción no se escribe acá ni en un comentario: el caso que lo
## verifica no distingue código de prosa.
##
## **El reloj está acá para apagar la pantalla cuando la noche termina**, no para pausarlo: una
## computadora abierta encima de la placa de cierre dejaría al jugador viendo las dos.
extends StaticBody3D

signal apertura_rechazada_sin_luz

## El script del jugador se preloadea para poder tiparlo: los scripts de `escenas/` son cáscara y
## no declaran `class_name`, así que sin esto el tipo estático sería `CharacterBody3D` y llamarle
## `suspender()` no compilaría.
const JugadorDelLocal := preload("res://src/escenas/jugador.gd")

@export var jugador: JugadorDelLocal
@export var reloj: RelojDelTurno
@export var computadora: ComputadoraDeEscritorio
@export var pantalla: PantallaDeComputadora
@export var mallas: Array[MeshInstance3D] = []

## Sin luz la computadora no abre. Lo declara el corte de luz; el escritorio no sabe por qué.
var con_luz := true


func _ready() -> void:
	reloj.turno_cerrado.connect(_al_cerrar_el_turno)
	computadora.computadora_abierta.connect(_al_abrirse)
	computadora.computadora_cerrada.connect(_al_cerrarse)
	computadora.registro_actualizado.connect(_al_cambiar_el_registro)
	pantalla.caja().suma_pedida.connect(computadora.pedir_sumar)
	pantalla.caja().resta_pedida.connect(computadora.pedir_restar)


## El clic izquierdo abre lo fijo sin soltar lo que se lleva.
func accionar() -> void:
	if con_luz:
		abrir()
	else:
		apertura_rechazada_sin_luz.emit()


func abrir() -> void:
	jugador.suspender()
	computadora.pedir_abrir()


func cerrar() -> void:
	computadora.pedir_cerrar()


func esta_abierta() -> bool:
	return computadora.computadora().abierta()


## Lo pide el nodo de la pausa. Como el clic derecho: devuelve el cursor al juego.
func cerrar_con_esc() -> void:
	cerrar()
	jugador.tomar_el_cursor_desde_entrada()


## Atiende el cierre antes de que la interfaz reciba el gesto.
func _input(evento: InputEvent) -> void:
	if not computadora.computadora().abierta():
		return
	if evento.is_action_pressed(ReglasDelJugador.ACCION_USAR):
		get_viewport().set_input_as_handled()
		cerrar()
		jugador.tomar_el_cursor_desde_entrada()


func _al_abrirse() -> void:
	pantalla.mostrar()
	_al_cambiar_el_registro()


func _al_cerrarse() -> void:
	pantalla.ocultar()
	jugador.reanudar()


func _al_cambiar_el_registro() -> void:
	pantalla.caja().mostrar(computadora.registro())


func _al_cerrar_el_turno(_cumplidas: int) -> void:
	cerrar()


## Lo que dice la computadora al examinarla, sin abrirla.
func texto_al_examinar() -> String:
	return SubtitulosAlExaminar.de_lo_fijo(SubtitulosAlExaminar.COMPUTADORA)
