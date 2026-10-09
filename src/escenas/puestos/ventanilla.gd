## La ventanilla que se ve: el vidrio por el que se atiende. Cablea y nada más.
##
## **No decide nada sobre el juego.** A quién hay que atender, cuánto marca la caja y cuándo la
## obligatoria queda cumplida son preguntas del dominio; qué señal va con qué método es lo único
## que se decide acá.
##
## El jugador encuadra sólo su cámara por una puerta propia, sin escribir el cuerpo desde acá.
## El control conserva sus ángulos; al salir la vista recupera su reposo y su orientación efectiva.
## Dintel y antepecho se leen a su profundidad real; la base enterrada no es visible.
##
## **El reloj está acá para cerrar el panel cuando la noche termina**, no para pausarlo: si la
## ventanilla se quedara abierta encima de la placa de cierre, el jugador vería las dos y no
## tendría cómo sacar la de arriba.
##
## Va en `puestos/` y no en `objetos/`, que es el criterio de esa carpeta —cuántas instancias
## hay—: hay una sola y llega cableada.
extends StaticBody3D

## El script del jugador se preloadea para poder tiparlo: los scripts de `escenas/` son cáscara y
## no declaran `class_name`, así que sin esto el tipo estático sería `CharacterBody3D` y llamarle
## `suspender()` no compilaría.
const JugadorDelLocal := preload("res://src/escenas/jugador.gd")

@export var jugador: JugadorDelLocal
@export var reloj: RelojDelTurno
@export var atenciones: Ventanilla
@export var panel: PanelDeLaVentanilla
@export var borde_superior: Marker3D
@export var antepecho: MeshInstance3D

## Si el vidrio está abierto ahora mismo. Es estado de cáscara —qué ventana hay arriba— y no una
## regla del juego: a quién hay que atender lo sigue contestando el dominio.
var _abierta := false


func _ready() -> void:
	reloj.turno_cerrado.connect(_al_cerrar_el_turno)
	panel.cobro_pedido.connect(atenciones.pedir_cobrar)
	panel.despacho_pedido.connect(atenciones.pedir_despachar_sin_vender)
	atenciones.comprador_llegado.connect(_al_llegar_un_comprador)
	atenciones.cobro_rechazado.connect(_al_rechazarse_el_cobro)
	atenciones.atencion_despachada.connect(_al_despacharse)
	atenciones.ventanilla_vacia.connect(panel.mostrar_sin_nadie)


## El clic derecho abre lo fijo.
func accionar() -> void:
	abrir()


## Clava al jugador delante del vidrio y pide a quien corresponda.
func abrir() -> void:
	_abierta = true
	var referencia := borde_superior.global_transform
	var soporte: AABB = (
		referencia.affine_inverse() * antepecho.global_transform * antepecho.get_aabb()
	)
	var tamano := Vector2(soporte.size.x, -soporte.end.y)
	var profundidad := -soporte.position.z
	var marco := referencia
	marco.origin = referencia * Vector3(soporte.get_center().x, -tamano.y / 2.0, -profundidad / 2.0)
	jugador.asomarse(marco, tamano, profundidad)
	jugador.suspender()
	atenciones.pedir_abrir()


## Cierra una vez y devuelve el control.
func cerrar() -> void:
	if not _abierta:
		return
	_abierta = false
	panel.ocultar()
	jugador.dejar_de_asomarse()
	jugador.reanudar()


## Atiende el cierre antes de que la interfaz reciba el gesto.
func _input(evento: InputEvent) -> void:
	if _abierta and evento.is_action_pressed(ReglasDelJugador.ACCION_USAR):
		get_viewport().set_input_as_handled()
		cerrar()


func _al_llegar_un_comprador(_comprador: Comprador) -> void:
	panel.mostrar(atenciones.atencion())


## Un cobro rechazado repinta la misma atención: el aviso de lo que falta lo arma el dominio, así
## que acá no hay que traducir la lista a un cartel.
func _al_rechazarse_el_cobro(_faltantes: Array[Producto]) -> void:
	panel.mostrar(atenciones.atencion())


## Despachado el comprador, el vidrio queda vacío hasta que el jugador vuelva a tocar.
func _al_despacharse(_despachados: int) -> void:
	panel.mostrar_sin_nadie()


func _al_cerrar_el_turno(_cumplidas: int) -> void:
	cerrar()
