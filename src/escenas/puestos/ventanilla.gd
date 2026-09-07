## La ventanilla que se ve: el vidrio por el que se atiende. Cablea y nada más.
##
## **No decide nada sobre el juego.** A quién hay que atender, cuánto marca la caja y cuándo la
## obligatoria queda cumplida son preguntas del dominio; qué señal va con qué método es lo único
## que se decide acá.
##
## **Suspender es clavar la cámara, y alcanza.** El 004 dejó `suspender()` y `reanudar()` en el
## jugador, y su `ControlDelJugador` deja de girar y de caminar con eso solo. **No se le escribe
## el `transform`**: el 004 aplica su yaw por cuadro desde el dominio, así que escribirlo desde
## afuera lo desincroniza y al reanudar la cámara salta al yaw viejo — sin un solo error.
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


## El contrato de «con esto se puede interactuar» es este método más el grupo del `.tscn`.
##
## Devuelve `null` porque de la ventanilla no se levanta nada: si contestara un objeto, el clic
## del 006 se la llevaría en la mano en vez de abrir la atención.
func interactuar() -> ObjetoDelAlmacen:
	abrir()
	return null


## Clava al jugador delante del vidrio y pide a quien corresponda.
func abrir() -> void:
	_abierta = true
	jugador.suspender()
	atenciones.pedir_abrir()


## Devuelve el control y baja el panel. Es idempotente a propósito: lo llaman la tecla de salida
## y el cierre del turno, que pueden pasar en cualquier orden.
##
## **Con el vidrio cerrado no hace nada**, y ése es el corte que importa: `ui_cancel` llega desde
## cualquier rincón del local, y examinar un objeto también suspende al jugador. Sin el corte, la
## tecla le devolvería la caminata en medio de un examen con el objeto pegado a la cara — el 006
## seguiría creyendo que examina, y no habría un solo error.
func cerrar() -> void:
	if not _abierta:
		return
	_abierta = false
	panel.ocultar()
	jugador.reanudar()


## La salida es la misma tecla que el resto del juego, y es la única que no depende de que el
## jugador encuentre un botón con la cámara clavada.
func _unhandled_input(evento: InputEvent) -> void:
	if evento.is_action_pressed("ui_cancel"):
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
