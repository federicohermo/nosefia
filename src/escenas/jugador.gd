## La cáscara del jugador: traduce el motor al dominio y de vuelta, y no decide nada.
##
## La prueba de que salió bien es que no hay un solo `if` sobre una regla del juego: el clamp
## del pitch, la vuelta del yaw, la normalización de la diagonal y «cuándo cambió el objetivo»
## viven todos en `src/dominio/` y tienen test. Acá quedan `Input`, `move_and_slide()`, el
## `RayCast3D` y las señales.
##
## Que la aritmética no se haya vuelto a colar acá lo verifica el AC28 del spec 004 con un `rg`
## sobre este archivo, que busca las cuatro llamadas del motor con las que se harían esas
## cuentas y exige cero líneas. Los nombres no se escriben ni en un comentario: el gate no
## distingue código de prosa, y hacerlo pasar comentando distinto sería trampa.
extends CharacterBody3D

## Se llaman por lo que pasó y no por lo que hay que hacer. Son el punto donde se cuelga el
## spec 006: quien las emite no sabe quién las escucha.
signal objetivo_enfocado(objetivo: Node3D, distancia: float)
signal objetivo_perdido

## Se arma en la declaración y no en `_ready()` a propósito: así un test puede instanciar la
## escena sin entrarla al árbol y el control ya existe. Entrar la escena al árbol haría correr
## `_ready()`, que toca el cursor y lee el rayo — dos cosas que en headless no significan nada.
var _control := ControlDelJugador.new(
	Mirada.new(
		ReglasDelJugador.SENSIBILIDAD_DEL_MOUSE,
		ReglasDelJugador.PITCH_MINIMO,
		ReglasDelJugador.PITCH_MAXIMO
	),
	ReglasDelJugador.VELOCIDAD_DE_CAMINATA
)

## La salida de emergencia mientras se desarrolla, y por eso vive acá y no en `dominio/`: no es
## una regla del juego, es poder llegar al botón de cerrar la ventana sin matar el proceso.
var _cursor_soltado_a_mano := false

@onready var _camara: Camera3D = $Camara
@onready var _mira: RayCast3D = $Camara/Mira


func _ready() -> void:
	_aplicar_el_modo_del_cursor()
	_aplicar_la_rotacion()


func _unhandled_input(evento: InputEvent) -> void:
	if evento is InputEventMouseMotion:
		_control.girar((evento as InputEventMouseMotion).relative)
		_aplicar_la_rotacion()
	elif evento is InputEventMouseButton and (evento as InputEventMouseButton).pressed:
		_cursor_soltado_a_mano = false
	elif evento.is_action_pressed("ui_cancel"):
		_cursor_soltado_a_mano = true


func _physics_process(delta: float) -> void:
	# El modo del cursor se recalcula cada cuadro porque es una función pura del estado del
	# control: así `suspender()` y `reanudar()` no tienen que acordarse de tocarlo, que es
	# exactamente el olvido que la suspensión como modo único existe para evitar.
	_aplicar_el_modo_del_cursor()

	if not is_on_floor():
		velocity += get_gravity() * delta

	# `Input.get_vector` ya devuelve `x` a la derecha e `y` adelante, que es la convención con
	# la que `Caminata` está escrita. El orden de los cuatro argumentos es
	# (negativo_x, positivo_x, negativo_y, positivo_y).
	var entrada := Input.get_vector(
		ReglasDelJugador.ACCION_IZQUIERDA,
		ReglasDelJugador.ACCION_DERECHA,
		ReglasDelJugador.ACCION_ATRAS,
		ReglasDelJugador.ACCION_ADELANTE
	)
	var horizontal := _control.velocidad(entrada)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	move_and_slide()

	_leer_la_mira()


## La única puerta por la que otra escena puede decir «el jugador no controla»: el
## `ControlDelJugador` es de `dominio/` y su instancia vive privada acá. La piden por separado
## el spec 006 (examinar un objeto) y el 009 (abrir la computadora), y sin ellas los dos
## degradan en silencio —el mouse sigue girando la cámara, el jugador sigue caminando—.
func suspender() -> void:
	# El aviso sale una sola vez, acá: mientras dura la suspensión `observar()` devuelve `false`,
	# así que si no se emitiera en este momento no se emitiría nunca y quien escucha se quedaría
	# creyendo que el jugador sigue enfocando algo durante toda la atención.
	var habia_objetivo := _control.objetivo() != Foco.SIN_OBJETIVO
	_control.suspender()
	if habia_objetivo:
		objetivo_perdido.emit()


func reanudar() -> void:
	_control.reanudar()


## El yaw va al cuerpo —así el adelante de la caminata y el de la vista son el mismo— y el pitch
## a la cámara. El dominio devuelve dos ángulos y no sabe a qué nodo van.
func _aplicar_la_rotacion() -> void:
	rotation.y = _control.yaw()
	_camara.rotation.x = _control.pitch()


## `dominio/` decide SI el cursor tiene que estar tomado; acá se traduce a QUÉ modo es ése.
func _aplicar_el_modo_del_cursor() -> void:
	var tomado := _control.quiere_el_cursor_tomado() and not _cursor_soltado_a_mano
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if tomado else Input.MOUSE_MODE_VISIBLE


## Arma la terna `(id, distancia, interactuable)` y se la pasa al dominio, que contesta si eso
## CAMBIÓ. La señal sale sólo cuando contesta que sí: sin eso serían 60 emisiones por segundo
## mirando fijo una estantería.
func _leer_la_mira() -> void:
	var golpeado := _mira.get_collider()
	var id := Foco.SIN_OBJETIVO
	var distancia := 0.0
	var interactuable := false
	if golpeado is Node3D:
		var nodo := golpeado as Node3D
		# El dominio guarda un `int` y no el nodo: guardar el nodo pondría en rojo el gate de
		# capas por `src/dominio → src/escenas` sin que haya un solo `preload`.
		id = nodo.get_instance_id()
		distancia = global_position.distance_to(nodo.global_position)
		interactuable = nodo.is_in_group(ReglasDelJugador.GRUPO_INTERACTUABLE)
	if not _control.observar(id, distancia, interactuable):
		return
	if _control.objetivo() == Foco.SIN_OBJETIVO:
		objetivo_perdido.emit()
	else:
		objetivo_enfocado.emit(golpeado, distancia)
