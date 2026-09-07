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

## Los dos sistemas del spec 006, por `@export` y no por `@onready`: un `@onready` se resuelve
## recién al entrar la escena al árbol, y entonces `id_en_la_mano()` se caería sobre un jugador
## apenas instanciado — que es como lo instancia todo test de esta escena. Tampoco son autoloads:
## está medido que `gate_de_capas.py` no ve uno nombrado por su nombre global, o sea que esa
## puerta cruzaría capas sin dejar rastro.
@export var agarre: Agarre
@export var examen: Examen

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

## Lo que la mira tiene adelante ahora mismo. Se guarda el nodo y no el `id` porque agarrar
## necesita el `Node3D`; el dominio sigue viendo sólo el `int` que le pasa `_leer_la_mira()`.
var _enfocado: Node3D = null

@onready var _camara: Camera3D = $Camara
@onready var _mira: RayCast3D = $Camara/Mira


func _ready() -> void:
	_aplicar_el_modo_del_cursor()
	_aplicar_la_rotacion()
	# Examinar clava la cámara y la caminata. Se cablea acá y no adentro de `Examen` porque
	# `sistemas/` no puede nombrar un nodo de `escenas/`: allá se emite lo que pasó, acá se
	# traduce a lo que hay que hacer.
	examen.examen_iniciado.connect(_al_empezar_a_examinar)
	examen.examen_terminado.connect(reanudar)
	agarre.objeto_soltado.connect(_devolver_al_mundo)


func _unhandled_input(evento: InputEvent) -> void:
	# El giro se descarta con el cursor suelto porque en `MOUSE_MODE_VISIBLE` el motor sigue
	# entregando el `relative` del mouse: sin este filtro, ir a apretar el botón de cerrar la
	# ventana gira la cámara todo el camino, y la salida de emergencia deja de servir.
	#
	# El mismo `relative` va a `Examen` cuando el cursor NO está tomado, que es lo que pasa
	# mientras se examina algo —examinar suspende—. No hay un `if` sobre el examen acá: `rotar()`
	# no hace nada si no hay nada en examen, y esa decisión vive donde está el estado.
	if evento is InputEventMouseMotion:
		var relativo := (evento as InputEventMouseMotion).relative
		if _el_cursor_esta_tomado():
			_control.girar(relativo)
			_aplicar_la_rotacion()
		else:
			examen.rotar(relativo)
		return
	if evento is InputEventMouseButton and (evento as InputEventMouseButton).pressed:
		# El primer clic después de la salida de emergencia recupera el cursor **y nada más**: sin
		# el corte, ir a apretar el botón de cerrar la ventana y volver agarraría de paso lo que
		# hubiera adelante.
		var venia_suelto := _cursor_soltado_a_mano
		_cursor_soltado_a_mano = false
		if venia_suelto:
			return
	if evento.is_action_pressed("ui_cancel"):
		_cursor_soltado_a_mano = true
	elif evento.is_action_pressed(ReglasDeLosObjetos.ACCION_AGARRAR):
		# Quién se come el clic lo contesta `Examen`, que es el que sabe si hay algo pegado a la
		# cara. Acá sólo se lo pasa al que quedó: esto es ruteo, no una regla del juego.
		if not examen.atajar_el_clic():
			agarre.alternar(_datos_de_lo_enfocado(), _enfocado)
	elif evento.is_action_pressed(ReglasDeLosObjetos.ACCION_EXAMINAR):
		examen.alternar(_datos_de_lo_enfocado())


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


## Qué `id` del dominio se está llevando en la mano, o `SIN_ID`.
##
## La única puerta por la que otra escena pregunta qué lleva el jugador — la piden los tres
## llamadores del 014 para saber si lo que hay en la mano es el trapeador, que es lo que decide
## si una pasada cuenta: `PisoDelLocal.pasar()` compara este `id` contra el del trapeador y una
## mano con otra cosa no baja una sola pasada. Devuelve el `id` y nunca el nodo: un nodo
## cruzaría la dirección de las capas al revés.
func id_en_la_mano() -> StringName:
	var datos := agarre.manos().sostenido()
	if datos == null:
		return ObjetoDelAlmacen.SIN_ID
	return datos.id


## El yaw va al cuerpo —así el adelante de la caminata y el de la vista son el mismo— y el pitch
## a la cámara. El dominio devuelve dos ángulos y no sabe a qué nodo van.
func _aplicar_la_rotacion() -> void:
	rotation.y = _control.yaw()
	_camara.rotation.x = _control.pitch()


## `dominio/` decide SI el cursor tiene que estar tomado, y acá se le suma la salida de
## emergencia, que no es una regla del juego. Vive en una función propia porque la respuesta la
## necesitan dos: el modo del cursor y el filtro del giro.
func _el_cursor_esta_tomado() -> bool:
	return _control.quiere_el_cursor_tomado() and not _cursor_soltado_a_mano


## Acá se traduce ese SI a QUÉ modo de cursor es ése.
func _aplicar_el_modo_del_cursor() -> void:
	var tomado := _el_cursor_esta_tomado()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if tomado else Input.MOUSE_MODE_VISIBLE


## Arma la terna `(id, distancia, interactuable)` y se la pasa al dominio, que contesta si eso
## CAMBIÓ. La señal sale sólo cuando contesta que sí: sin eso serían 60 emisiones por segundo
## mirando fijo una estantería.
func _leer_la_mira() -> void:
	var enfocado := _mira.get_collider() as Node3D
	var id := Foco.SIN_OBJETIVO
	var distancia := 0.0
	var interactuable := false
	if enfocado != null:
		# El dominio guarda un `int` y no el nodo: guardar el nodo pondría en rojo el gate de
		# capas por `src/dominio → src/escenas` sin que haya un solo `preload`.
		id = enfocado.get_instance_id()
		# Del ojo al punto donde pegó el rayo, y no entre los dos orígenes: el del cuerpo está
		# apoyado en el piso y el del objeto en su centro, así que medir origen a origen le suma
		# la altura de la cámara a todo lo que se mira de cerca. Es el número con el que el spec
		# 006 decide si algo está al alcance de la mano, y ahí ese error importa.
		distancia = _camara.global_position.distance_to(_mira.get_collision_point())
		interactuable = enfocado.is_in_group(ReglasDelJugador.GRUPO_INTERACTUABLE)
	_enfocado = enfocado
	if not _control.observar(id, distancia, interactuable):
		return
	if _control.objetivo() == Foco.SIN_OBJETIVO:
		objetivo_perdido.emit()
	else:
		objetivo_enfocado.emit(enfocado, distancia)


## Le pide a lo enfocado que se presente, por el nombre de método que ES el contrato. `null` si
## no hay nada enfocado o si lo que hay no es un objeto del almacén —una pared, una estantería—.
func _datos_de_lo_enfocado() -> ObjetoDelAlmacen:
	if _enfocado == null or not _enfocado.has_method(ReglasDeLosObjetos.METODO_INTERACTUAR):
		return null
	return _enfocado.call(ReglasDeLosObjetos.METODO_INTERACTUAR)


## Traduce «empezó un examen» a «el jugador no controla». El argumento se descarta: quién es el
## nodo ya lo sabe `Examen`, que es el que lo está moviendo.
func _al_empezar_a_examinar(_nodo: Node3D) -> void:
	suspender()


## Lo soltado vuelve a colgar del mundo y no del punto de soltado, que se mueve con la cámara.
## Es cableado —quién es «el mundo» sólo lo sabe la escena— y por eso `Agarre` deja el objeto en
## el punto y avisa, en vez de salir a buscar dónde ponerlo.
func _devolver_al_mundo(nodo: Node3D) -> void:
	var mundo := get_parent()
	if nodo == null or mundo == null or not nodo.is_inside_tree():
		return
	nodo.reparent(mundo, true)
