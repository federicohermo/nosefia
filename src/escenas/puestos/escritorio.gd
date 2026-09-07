## El escritorio del local: el mueble con la computadora. Cablea y nada más.
##
## **No decide nada sobre el juego.** Si se puede abrir, qué app sigue y cuándo `REGISTRAR` está
## cumplida son preguntas del dominio; qué señal va con qué método es lo único que se decide acá.
##
## **Suspender es clavar la cámara, y alcanza.** El 004 dejó `suspender()` y `reanudar()` en el
## jugador: sin esas dos puertas, abrir la computadora degradaría en silencio —el mouse seguiría
## girando la cámara y el jugador seguiría caminando detrás del panel—.
##
## **Se sale con el clic derecho, y no con la tecla que suelta el cursor.** `jugador.gd` ya usa
## esa tecla y retoma con cualquier botón, así que compartirla dejaría al jugador cerrando la
## computadora cada vez que va a apretar el botón de cerrar la ventana. El nombre de esa acción no
## se escribe acá ni en un comentario: el caso que lo verifica no distingue código de prosa.
##
## Se usa el evento crudo y **no se agrega una acción al `InputMap`**: quién consolida los tres
## usos del clic derecho es el spec 034, y una acción nueva acá sería la que hay que borrar
## después.
##
## **El reloj está acá para apagar la pantalla cuando la noche termina**, no para pausarlo: una
## computadora abierta encima de la placa de cierre dejaría al jugador viendo las dos.
extends StaticBody3D

## El script del jugador se preloadea para poder tiparlo: los scripts de `escenas/` son cáscara y
## no declaran `class_name`, así que sin esto el tipo estático sería `CharacterBody3D` y llamarle
## `suspender()` no compilaría.
const JugadorDelLocal := preload("res://src/escenas/jugador.gd")

@export var jugador: JugadorDelLocal
@export var reloj: RelojDelTurno
@export var computadora: ComputadoraDeEscritorio
@export var pantalla: PantallaDeComputadora


func _ready() -> void:
	reloj.turno_cerrado.connect(_al_cerrar_el_turno)
	computadora.computadora_abierta.connect(_al_abrirse)
	computadora.computadora_cerrada.connect(_al_cerrarse)
	computadora.app_cambiada.connect(_al_cambiar_de_app)
	computadora.chats_actualizados.connect(_al_leer_un_chat)
	computadora.nota_escrita.connect(_al_escribirse_una_nota)
	computadora.caja_actualizada.connect(_al_registrarse_un_producto)
	pantalla.app_pedida.connect(computadora.pedir_cambiar_a)
	pantalla.caja().registro_pedido.connect(computadora.pedir_registrar)
	pantalla.chats().lectura_pedida.connect(_al_pedirse_un_chat)
	pantalla.notas().escritura_pedida.connect(computadora.pedir_escribir)


## El contrato de «con esto se puede interactuar» es este método más el grupo del `.tscn`.
##
## Devuelve `null` porque del escritorio no se levanta nada: si contestara un objeto, el clic del
## 006 se llevaría el mueble en la mano en vez de encender la pantalla.
func interactuar() -> ObjetoDelAlmacen:
	abrir()
	return null


func abrir() -> void:
	jugador.suspender()
	computadora.pedir_abrir()


func cerrar() -> void:
	computadora.pedir_cerrar()


## El botón derecho apaga la pantalla. Es el evento crudo y no una acción del `InputMap`.
##
## **Va en `_input` y no en el que corre después de la interfaz**, y es una medición: el fondo de
## la pantalla es un `ColorRect` a pantalla completa, y un `Control` trae `MOUSE_FILTER_STOP` por
## defecto, así que **se come el botón del mouse antes** — medido en 4.7.2, el botón derecho sobre
## un fondo así llega por `_input` y no llega por el otro. Con el otro, la computadora se abría y
## no se podía cerrar: el jugador quedaba suspendido detrás del panel hasta que cerrara la noche,
## y ningún test de escena lo decía porque el gesto estaba escrito.
func _input(evento: InputEvent) -> void:
	var boton := evento as InputEventMouseButton
	if boton == null or not boton.pressed or boton.button_index != MOUSE_BUTTON_RIGHT:
		return
	cerrar()


func _al_abrirse(app: Computadora.App) -> void:
	pantalla.mostrar(app)
	_repintar(app)


func _al_cerrarse() -> void:
	pantalla.ocultar()
	jugador.reanudar()


func _al_cambiar_de_app(app: Computadora.App) -> void:
	pantalla.cambiar_a(app)
	_repintar(app)


## Cada app se repinta al entrar y no por cuadro: el estado que muestran sólo cambia cuando el
## jugador hace algo, y repintar por cuadro sería reconstruir tres listas sesenta veces por
## segundo para que digan lo mismo.
func _repintar(_app: Computadora.App) -> void:
	pantalla.caja().mostrar(computadora.caja())
	pantalla.chats().mostrar(computadora.bandeja())
	pantalla.notas().mostrar(computadora.cuaderno().notas())


func _al_pedirse_un_chat(quien: Conversacion.Interlocutor) -> void:
	pantalla.chats().mostrar_conversacion(computadora.bandeja().conversacion_de(quien))
	computadora.pedir_marcar_leida(quien)


func _al_leer_un_chat(_sin_leer: int) -> void:
	pantalla.chats().mostrar(computadora.bandeja())


func _al_escribirse_una_nota(_nota: Nota) -> void:
	pantalla.notas().limpiar_campos()
	pantalla.notas().mostrar(computadora.cuaderno().notas())


func _al_registrarse_un_producto(_registrados: int) -> void:
	pantalla.caja().mostrar(computadora.caja())


func _al_cerrar_el_turno(_cumplidas: int) -> void:
	cerrar()
