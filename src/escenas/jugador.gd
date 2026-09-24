## La cáscara del jugador: traduce el motor al dominio y de vuelta, y no decide nada.
##
## La prueba de que salió bien es que no hay un solo `if` sobre una regla del juego: el clamp
## del pitch, la vuelta del yaw, la normalización de la diagonal y «cuándo cambió el objetivo»
## viven todos en `src/dominio/` y tienen test. Acá quedan `Input`, `move_and_slide()`, el
## campo espacial y las señales.
##
## Que la aritmética no se haya vuelto a colar acá lo verifica un gate con un `rg`
## sobre este archivo, que busca las cuatro llamadas del motor con las que se harían esas
## cuentas y exige cero líneas. Los nombres no se escriben ni en un comentario: el gate no
## distingue código de prosa, y hacerlo pasar comentando distinto sería trampa.
extends CharacterBody3D

## Se llaman por lo que pasó y no por lo que hay que hacer. Son el punto donde se cuelga
## agarrar y examinar: quien las emite no sabe quién las escucha.
signal objetivo_enfocado(objetivo: Node3D, distancia: float)
signal objetivo_perdido
signal uso_pedido(objetivo: Node3D)

## Los dos sistemas de agarrar, por `@export` y no por `@onready`: un `@onready` se resuelve
## recién al entrar la escena al árbol, y entonces `id_en_la_mano()` se caería sobre un jugador
## apenas instanciado — que es como lo instancia todo test de esta escena. Tampoco son autoloads:
## está medido que `gate_de_capas.py` no ve uno nombrado por su nombre global, o sea que esa
## puerta cruzaría capas sin dejar rastro.
@export var agarre: Agarre
@export var examen: Examen

## Se arma en la declaración y no en `_ready()` a propósito: así un test puede instanciar la
## escena sin entrarla al árbol y el control ya existe. Entrar la escena al árbol haría correr
## `_ready()`, que toca el cursor y conecta sistemas — dos cosas que en headless no significan nada.
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

## Cuánto mide ahora el brazo de cada mano. Es estado del dibujo y no del juego: el brazo del
## motor contesta el lugar libre de golpe, y cuánto de ese salto se recorre por cuadro lo decide
## `RetornoDeLaMano`.
var _largo_de_carga := 0.0
var _largo_de_producto := 0.0

## Dónde estaba el cuerpo en los dos últimos pasos de física. Entre uno y otro, la cámara y la
## caja se dibujan en el medio, y el giro no espera al paso siguiente. Ver `_process()`.
var _origen_anterior := Vector3.ZERO
var _origen_actual := Vector3.ZERO

## Dónde van la cámara y la caja sobre el cuerpo, antes de correrlas para el dibujo.
var _ojo := Vector3.ZERO
var _lugar_de_la_caja := Vector3.ZERO

@onready var _camara: Camera3D = $Camara
@onready var _campo: Area3D = $Camara/CampoDeInteraccion

## Los dos brazos que miden cuánto lugar hay para lo que se lleva.
@onready var _brazo_de_carga: SpringArm3D = $Camara/BrazoDeCarga
@onready var _brazo_de_producto: SpringArm3D = $Camara/BrazoDeProducto

## El brazo de la caja cuelga del cuerpo y no de la cámara: pegado al pitch taparía la mira.
@onready var _brazo_de_la_caja: SpringArm3D = $BrazoDeCaja
@onready var _punto_de_la_caja: Node3D = $PuntoDeCaja

## La caja cuelga del cuerpo y no de la cámara, y ocupa lugar: mientras se la lleva, el jugador
## no puede acercarse a una pared más de lo que la caja mide.
@onready var _forma_de_la_caja: CollisionShape3D = $FormaDeLaCaja


func _ready() -> void:
	# El motor interpola el cuerpo entre dos pasos de física, pero el giro se escribe al llegar el
	# mouse, en el medio. Medido: el giro dibujado iba de 0,05 a 1,9 veces el pedido. Sin
	# interpolar, el giro se dibuja entero en el cuadro en que llega; la caminata la interpola
	# `_process()`.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_ojo = _camara.position
	_lugar_de_la_caja = _punto_de_la_caja.position
	_origen_anterior = global_position
	_origen_actual = global_position
	_aplicar_el_modo_del_cursor()
	_aplicar_la_rotacion()
	# Los brazos barren desde el hombro, que está adentro de la propia cápsula. Está medido que
	# un barrido que arranca solapado se descarta entero: sin esta exclusión el brazo nunca
	# acorta y lo que se lleva en la mano vuelve a meterse en la madera.
	for brazo: SpringArm3D in find_children("*", "SpringArm3D", true, false):
		brazo.add_excluded_object(get_rid())
	# Estirados desde el primer cuadro: arrancar en cero haría que las manos salgan del hombro
	# a la vista del jugador cada vez que empieza una jornada.
	_largo_de_carga = _brazo_de_carga.spring_length
	_largo_de_producto = _brazo_de_producto.spring_length
	# Examinar clava la cámara y la caminata. Se cablea acá y no adentro de `Examen` porque
	# `sistemas/` no puede nombrar un nodo de `escenas/`: allá se emite lo que pasó, acá se
	# traduce a lo que hay que hacer.
	examen.examen_iniciado.connect(_al_empezar_a_examinar)
	examen.examen_terminado.connect(reanudar)
	agarre.objeto_soltado.connect(_devolver_al_mundo)


## Deja de chocar con el detalle de un mueble: el cuerpo y los brazos chocan con su contorno.
##
## **El detalle es caro de rozar.** La colisión de una góndola es su malla entera, con cada
## chapa, labio y agujero del panel. La cápsula que camina pegada al lateral de una cabecera
## prueba contacto contra cientos de triángulos en cada paso: está medido en 5,4 ms por paso en
## escritorio contra 0,7 con una caja, y en la web el cuadro llegaba a 80 ms. El detalle sigue
## ahí para lo que sí lo necesita: los productos que caen y los rayos de la mira.
func ignorar_el_detalle(cuerpo: PhysicsBody3D) -> void:
	add_collision_exception_with(cuerpo)
	for brazo: SpringArm3D in find_children("*", "SpringArm3D", true, false):
		brazo.add_excluded_object(cuerpo.get_rid())


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
			_interactuar()
	elif evento.is_action_pressed(ReglasDelJugador.ACCION_USAR):
		if _enfocado != null and not _control.esta_suspendido():
			uso_pedido.emit(_enfocado)
	elif evento.is_action_pressed(ReglasDeLosObjetos.ACCION_EXAMINAR):
		examen.alternar(_datos_de_lo_enfocado())


## **El clic se lo gasta quien hace algo con él, y sólo ése.** Tener `interactuar()` es la
## declaración de que el clic izquierdo es suyo: los puestos lo resuelven por señal y contestan
## `null` —el escritorio abre, el estante coloca—, y soltar además sería un segundo efecto del
## mismo clic; las cajas contestan sus datos, y eso es lo que se agarra.
##
## **Lo que está en el grupo pero no tiene el método no se gasta nada**, y ésa es la diferencia
## que antes no existía: el corte miraba si había algo enfocado, así que la mancha del piso
## —que se limpia con el otro botón y no contesta nada acá— se comía el clic. Llevando una caja
## y con la mira sobre un charco, soltar no hacía absolutamente nada, sin un solo aviso.
func _interactuar() -> void:
	var datos: ObjetoDelAlmacen = null
	if _enfocado != null and _enfocado.has_method(ReglasDeLosObjetos.METODO_INTERACTUAR):
		datos = _enfocado.call(ReglasDeLosObjetos.METODO_INTERACTUAR)
		if datos == null:
			return
	agarre.alternar(datos, _enfocado)


func _physics_process(delta: float) -> void:
	# El modo del cursor se recalcula cada cuadro porque es una función pura del estado del
	# control: así `suspender()` y `reanudar()` no tienen que acordarse de tocarlo, que es
	# exactamente el olvido que la suspensión como modo único existe para evitar.
	_aplicar_el_modo_del_cursor()
	# La física mira desde donde está el cuerpo, no desde donde se lo dibuja.
	_correr_para_el_dibujo(Vector3.ZERO)

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
	_origen_anterior = _origen_actual
	_origen_actual = global_position
	_empujar_lo_que_estorba()

	_acomodar_las_manos(delta)
	_acomodar_la_caja()
	_leer_la_mira()


## Dibuja la cámara y la caja entre los dos últimos pasos de física, como el motor dibujaría el
## cuerpo. Se corre sólo el lugar: el giro ya está entero en el cuerpo.
##
## Lo que se lleva cuelga de esos dos puntos, y por eso se corre con ellos. Así no tiembla contra
## la cámara.
func _process(_delta: float) -> void:
	var fraccion := Engine.get_physics_interpolation_fraction()
	_correr_para_el_dibujo(_origen_anterior.lerp(_origen_actual, fraccion) - _origen_actual)


## Corre la cámara y la caja, en metros del mundo, desde su lugar sobre el cuerpo.
func _correr_para_el_dibujo(desvio: Vector3) -> void:
	var local := global_basis.inverse() * desvio
	_camara.position = _ojo + local
	_punto_de_la_caja.position = _lugar_de_la_caja + local


## Le pasa a lo chocado el paso que no se pudo dar, para que se corra en vez de tapar el paso.
##
## Quién puede recibirlo lo dice el nombre de un método, igual que interactuar: acá no se nombra
## ninguna escena. Cuánto se corre lo decide quien recibe, con el número del dominio.
func _empujar_lo_que_estorba() -> void:
	for indice in get_slide_collision_count():
		var choque := get_slide_collision(indice)
		var estorbo := choque.get_collider() as Node
		if estorbo != null and estorbo.has_method(ReglasDeLosObjetos.METODO_EMPUJAR):
			estorbo.call(ReglasDeLosObjetos.METODO_EMPUJAR, choque.get_remainder())


## Corre las dos manos sobre el eje de su brazo, hasta donde haya lugar.
##
## El brazo no mueve a nadie: los puntos cuelgan de la cámara y no de él, así que la única
## escritura sobre ellos es ésta. Colgarlos del brazo sería más corto, pero entonces el motor
## les escribiría la posición entera cada cuadro y el suavizado no tendría dónde entrar.
func _acomodar_las_manos(delta: float) -> void:
	_largo_de_carga = _acomodar(_brazo_de_carga, agarre.punto_de_carga, _largo_de_carga, delta)
	_largo_de_producto = _acomodar(
		_brazo_de_producto, agarre.punto_de_producto, _largo_de_producto, delta
	)


## Mueve un punto sobre el eje de su brazo y devuelve el largo que quedó.
func _acomodar(brazo: SpringArm3D, punto: Node3D, largo: float, delta: float) -> float:
	if brazo == null or punto == null:
		return largo
	var siguiente := RetornoDeLaMano.siguiente(largo, brazo.get_hit_length(), delta)
	punto.position = brazo.transform * Vector3(0.0, 0.0, siguiente)
	return siguiente


## Le da o le saca al cuerpo el volumen de la caja que lleva. Es lo que la vuelve un objeto de
## verdad: con ella en la mano el jugador choca donde chocaría la caja.
func ocupar_el_frente(ocupado: bool) -> void:
	# Primero se la acomoda y después se enciende: encender el volumen donde no entra —que es lo
	# que pasa sacando una caja de un estante pegado a él— empuja al jugador.
	_acomodar_la_caja()
	_forma_de_la_caja.disabled = not ocupado


## Corre la caja sobre el eje de su brazo, hasta donde haya lugar.
##
## Sin suavizado, al revés que las manos: el brazo ya contesta un punto libre, y el volumen se
## enciende justo ahí. Un punto intermedio quedaría adentro de la madera.
func _acomodar_la_caja() -> void:
	_lugar_de_la_caja = (
		_brazo_de_la_caja.transform * Vector3(0.0, 0.0, _brazo_de_la_caja.get_hit_length())
	)
	_punto_de_la_caja.position = _lugar_de_la_caja
	_forma_de_la_caja.position = _lugar_de_la_caja


## Desde dónde y hacia dónde mira. La pide `reposicion_manual.gd` para saber dónde quiere el
## jugador apoyar la caja; el nodo de la cámara es privado y su ruta no se cruza desde afuera.
func mira() -> Transform3D:
	return _camara.global_transform


## La única puerta por la que otra escena puede decir «el jugador no controla»: el
## `ControlDelJugador` es de `dominio/` y su instancia vive privada acá. La piden por separado
## examinar un objeto y abrir la computadora, y sin ellas los dos
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
## llamadores de limpiar para saber si lo que hay en la mano es el trapeador, que es lo que decide
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


## La identidad sigue siendo la del cuerpo; cambiar el punto visible no reemite el foco.
func _leer_la_mira() -> void:
	var candidatos: Array[CampoDeInteraccion.Candidato] = []
	var cuerpos: Dictionary[int, Node3D] = {}
	var distancias: Dictionary[int, float] = {}
	for cuerpo: Node3D in _campo.get_overlapping_bodies():
		if cuerpo == self or not cuerpo.is_in_group(ReglasDelJugador.GRUPO_INTERACTUABLE):
			continue
		var candidato := _medir_candidato(cuerpo)
		candidatos.append(candidato)
		cuerpos[candidato.id] = cuerpo
		distancias[candidato.id] = candidato.distancia
	var excluido := Foco.SIN_OBJETIVO
	for nodo in agarre.punto_de_carga.get_children() + examen.punto_de_examen.get_children():
		excluido = nodo.get_instance_id()
	var id := CampoDeInteraccion.elegir(candidatos, excluido)
	_enfocado = cuerpos.get(id)
	var distancia: float = distancias.get(id, 0.0)
	if not _control.observar(id, distancia, _enfocado != null):
		return
	if _control.objetivo() == Foco.SIN_OBJETIVO:
		objetivo_perdido.emit()
	else:
		objetivo_enfocado.emit(_enfocado, distancia)


## Los bounds orientan los rayos. Sólo un impacto real sobre el cuerpo da un punto visible.
func _medir_candidato(cuerpo: Node3D) -> CampoDeInteraccion.Candidato:
	var ojo := _camara.global_position
	var adelante := -_camara.global_basis.z
	var puntos: Array[Vector3] = [ojo + adelante * ReglasDelJugador.ALCANCE_DE_LA_MIRA]
	for forma: CollisionShape3D in cuerpo.find_children("*", "CollisionShape3D", false, false):
		if forma.disabled or forma.shape == null:
			continue
		var limites := forma.global_transform * forma.shape.get_debug_mesh().get_aabb()
		var centro := limites.get_center()
		var eje := ojo + adelante * (centro - ojo).dot(adelante)
		puntos.append(eje.clamp(limites.position, limites.end))
		puntos.append(centro)
		for direccion in [
			Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.FORWARD, Vector3.BACK
		]:
			puntos.append(centro + direccion * limites.size / 2)
	var espacio := get_world_3d().direct_space_state
	for punto in puntos:
		var consulta := PhysicsRayQueryParameters3D.create(
			ojo, ojo + ojo.direction_to(punto) * ReglasDelJugador.ALCANCE_DE_LA_MIRA
		)
		consulta.exclude = [get_rid()]
		# Con la máscara del campo y no con todas: el contorno de un mueble lo envuelve, y un
		# rayo que lo mirara pegaría siempre ahí antes que en el mueble.
		consulta.collision_mask = _campo.collision_mask
		var golpe := espacio.intersect_ray(consulta)
		if golpe.get("collider") != cuerpo:
			continue
		var impacto: Vector3 = golpe.position
		return CampoDeInteraccion.Candidato.new(
			cuerpo.get_instance_id(),
			ojo.distance_to(impacto),
			adelante.angle_to(impacto - ojo),
			true,
			true
		)
	return CampoDeInteraccion.Candidato.new(cuerpo.get_instance_id(), INF, INF, true, false)


## Examinar consulta los datos sin activar cajas ni puestos.
func _datos_de_lo_enfocado() -> ObjetoDelAlmacen:
	if _enfocado is ObjetoAgarrable:
		return (_enfocado as ObjetoAgarrable).datos
	return null


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
	if nodo is RigidBody3D:
		_ajustar_la_caida(nodo)


## El punto fijo puede quedar detrás de la madera. Se barre el volumen desde el jugador.
func _ajustar_la_caida(cuerpo: RigidBody3D) -> void:
	var inicio := _camara.global_position
	var recorrido := cuerpo.global_position - inicio
	var avance := 1.0
	var espacio := get_world_3d().direct_space_state
	for forma: CollisionShape3D in cuerpo.find_children("*", "CollisionShape3D", false, false):
		if forma.disabled or forma.shape == null:
			continue
		var consulta := PhysicsShapeQueryParameters3D.new()
		consulta.shape = forma.shape
		consulta.transform = forma.global_transform
		consulta.transform.origin -= recorrido
		consulta.motion = recorrido
		consulta.margin = safe_margin
		consulta.collision_mask = cuerpo.collision_mask
		consulta.exclude = [get_rid(), cuerpo.get_rid()]
		avance = minf(avance, espacio.cast_motion(consulta)[0])
	cuerpo.global_position = inicio + recorrido * avance
