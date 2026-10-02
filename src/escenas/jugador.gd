## La cáscara del jugador: traduce el motor al dominio y de vuelta.
extends CharacterBody3D

## Se llaman por lo que pasó y no por lo que hay que hacer. Son el punto donde se cuelga
## agarrar y examinar: quien las emite no sabe quién las escucha.
signal objetivo_enfocado(objetivo: Node3D, distancia: float)
signal objetivo_perdido
signal uso_pedido(objetivo: Node3D)

## Cuando la cadencia dice que toca un paso. No se emite por cuadro: ver `CadenciaDePasos`.
signal paso_dado

## Cuántos choques se piden por consulta al medir lo soltado contra el cuerpo. El motor corta ahí.
const TOPE_DE_CHOQUES := 32

## Cuánto se aparta lo soltado de lo que frenó el barrido, en metros, para caer sin rozarlo.
const HOLGURA_DE_LA_CAIDA := 0.01

## Resolución de la búsqueda del volumen libre para un útil largo junto a una pared.
const PASOS_DEL_UTIL_EN_LA_MANO := 64

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

var _cadencia := CadenciaDePasos.new()

## Lo que la mira tiene adelante ahora mismo. Se guarda el nodo y no el `id` porque agarrar
## necesita el `Node3D`; el dominio sigue viendo sólo el `int` que le pasa `_leer_la_mira()`.
var _enfocado: Node3D = null

## Cuánto mide ahora el brazo de cada mano. Es estado del dibujo y no del juego: el brazo del
## motor contesta el lugar libre de golpe, y cuánto de ese salto se recorre por cuadro lo decide
## `RetornoDeLaMano`.
var _largo_de_carga := 0.0
var _largo_de_producto := 0.0

## Lo que el barrido de la caja no ve: lo mismo que excluyen los brazos, que no lo devuelven.
var _excluidos: Array[RID] = []

## Si el giro dibujado todavía va atrás de la mirada. Mientras tanto se lo reescribe cada cuadro,
## y sólo entonces: un test que apunta la cámara a mano no la pierde en el cuadro siguiente.
var _girando_el_dibujo := false

## El yaw va acá y no al cuerpo, que es la receta de Godot para mirar con el mouse: el cuerpo se
## dibuja interpolado entre dos pasos de física, y este nodo no. Así la caminata sale pareja y el
## giro no espera al paso siguiente. Su interpolación apagada está en el `.tscn`.
@onready var _giro: Node3D = $Giro
@onready var _camara: Camera3D = $Giro/Camara
@onready var _campo: Area3D = $Giro/Camara/CampoDeInteraccion

## Los dos brazos que miden cuánto lugar hay para lo que se lleva.
@onready var _brazo_de_carga: SpringArm3D = $Giro/Camara/BrazoDeCarga
@onready var _brazo_de_producto: SpringArm3D = $Giro/Camara/BrazoDeProducto

## El brazo de la caja gira con el yaw y no con la cámara: pegado al pitch taparía la mira.
@onready var _brazo_de_la_caja: SpringArm3D = $Giro/BrazoDeCaja
@onready var _punto_de_la_caja: Node3D = $Giro/PuntoDeCaja

## La caja ocupa lugar: mientras se la lleva, el jugador no puede acercarse a una pared más de lo
## que la caja mide. La forma es hija del cuerpo y no del giro, porque sólo así choca.
@onready var _forma_de_la_caja: CollisionShape3D = $FormaDeLaCaja

## El cuerpo del jugador: lo soltado que queda metido en él cae al lado.
@onready var _forma_del_cuerpo: CollisionShape3D = $Cuerpo


func _ready() -> void:
	_aplicar_el_modo_del_cursor()
	_aplicar_la_rotacion()
	# Los brazos barren desde el hombro, que está adentro de la propia cápsula. Está medido que
	# un barrido que arranca solapado se descarta entero: sin esta exclusión el brazo nunca
	# acorta y lo que se lleva en la mano vuelve a meterse en la madera.
	# Y barren antes de que el cuerpo los lea: con la misma prioridad el padre va primero y lee el
	# largo del paso anterior.
	_excluidos.append(get_rid())
	for brazo: SpringArm3D in find_children("*", "SpringArm3D", true, false):
		brazo.add_excluded_object(get_rid())
		brazo.process_physics_priority = process_physics_priority - 1
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
	_excluidos.append(cuerpo.get_rid())
	for brazo: SpringArm3D in find_children("*", "SpringArm3D", true, false):
		brazo.add_excluded_object(cuerpo.get_rid())


func _unhandled_input(evento: InputEvent) -> void:
	# El giro se descarta con el cursor suelto porque en `MOUSE_MODE_VISIBLE` el motor sigue
	# entregando el `relative` del mouse: sin este filtro, mover el mouse hasta el botón de la
	# pausa gira la cámara todo el camino.
	#
	# El mismo `relative` va a `Examen` cuando el cursor NO está tomado, que es lo que pasa
	# mientras se examina algo —examinar suspende—. No hay un `if` sobre el examen acá:
	# `arrastrar()` decide con el estado del examen y del clic.
	if evento is InputEventMouseMotion:
		var movimiento := evento as InputEventMouseMotion
		if _el_cursor_esta_tomado():
			_control.girar(movimiento.relative)
			_aplicar_la_rotacion()
		else:
			var con_el_clic := movimiento.button_mask & MOUSE_BUTTON_MASK_LEFT != 0
			examen.arrastrar(movimiento.relative, con_el_clic)
		return
	if evento.is_action_pressed(ReglasDeLosObjetos.ACCION_AGARRAR):
		# Quién se come el clic lo contesta `Examen`, que es el que sabe si hay algo pegado a la
		# cara. Acá sólo se lo pasa al que quedó: esto es ruteo, no una regla del juego.
		if not examen.atajar_el_clic():
			_interactuar()
	elif evento.is_action_pressed(ReglasDelJugador.ACCION_USAR):
		if _enfocado != null and not _control.esta_suspendido():
			uso_pedido.emit(_enfocado)
	elif evento.is_action_pressed(ReglasDeLosObjetos.ACCION_EXAMINAR):
		# Con otra pantalla encima, la E no abre un examen: al cerrarlo reanudaría al jugador.
		if examen.esta_examinando() or not _control.esta_suspendido():
			examen.alternar(_datos_de(_enfocado), _enfocado)


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

	if not is_on_floor():
		velocity += get_gravity() * delta

	var horizontal := _control.velocidad(_entrada())
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	var antes := global_position
	move_and_slide()
	_contar_el_paso(global_position - antes)
	_empujar_lo_que_estorba()

	_acomodar_las_manos(delta)
	_acomodar_la_caja()
	_leer_la_mira()


## Cuenta lo que el cuerpo se movió de verdad sobre el piso: contra una pared, nada. Lo vertical
## no es caminar.
func _contar_el_paso(recorrido: Vector3) -> void:
	if _cadencia.avanzar(Vector2(recorrido.x, recorrido.z).length()):
		paso_dado.emit()


func _process(delta: float) -> void:
	# Lo examinado cuelga de la cámara, que no se interpola: girarlo en el paso de física lo
	# dibujaría a saltos.
	examen.girar(_entrada(), delta)
	_control.avanzar_el_dibujo(delta)
	var atrasado := _control.giro_atrasado()
	if atrasado or _girando_el_dibujo:
		_aplicar_la_rotacion()
	_girando_el_dibujo = atrasado


## `Input.get_vector` ya devuelve `x` a la derecha e `y` adelante, que es la convención con la
## que `Caminata` y el giro del examen están escritos. El orden de los cuatro argumentos es
## (negativo_x, positivo_x, negativo_y, positivo_y).
func _entrada() -> Vector2:
	return Input.get_vector(
		ReglasDelJugador.ACCION_IZQUIERDA,
		ReglasDelJugador.ACCION_DERECHA,
		ReglasDelJugador.ACCION_ATRAS,
		ReglasDelJugador.ACCION_ADELANTE
	)


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
	_acomodar_la_mopa()
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


## La esfera del brazo protege la mano, pero no alcanza la cabeza de una mopa inclinada.
## Se mide su forma real, incluida la posición transitoria de la animación de mojarla.
func _acomodar_la_mopa() -> void:
	for nodo in agarre.punto_de_carga.get_children():
		var datos := _datos_de(nodo)
		if not nodo is RigidBody3D or datos == null or datos.id != ReglasDeLaLimpieza.ID_DE_LA_MOPA:
			continue
		var retroceso := _retroceso_libre(nodo as RigidBody3D)
		if retroceso == 0.0:
			return
		_largo_de_carga -= retroceso
		agarre.punto_de_carga.position = _brazo_de_carga.transform * Vector3(0, 0, _largo_de_carga)
		agarre.punto_de_carga.reset_physics_interpolation()
		return


## Cuánto tiene que retroceder el cuerpo por el brazo de carga para no tocar una pared. No mueve
## nada: cero es que ya está libre, o que no hay lugar libre en todo su largo.
func _retroceso_libre(cuerpo: RigidBody3D) -> float:
	var forma: CollisionShape3D = cuerpo.get_node("Forma")
	var consulta := PhysicsShapeQueryParameters3D.new()
	consulta.shape = forma.shape
	consulta.transform = forma.global_transform
	consulta.margin = HOLGURA_DE_LA_CAIDA
	consulta.collision_mask = _brazo_de_carga.collision_mask
	consulta.exclude = [get_rid(), cuerpo.get_rid()]
	var espacio := get_world_3d().direct_space_state
	# La cabeza entra en el balde al mojarse. Ese contacto con un objeto móvil no debe
	# esconderla detrás de la cámara como si fuera una pared del almacén.
	var excluidos: Array[RID] = consulta.exclude
	for choque: Dictionary in espacio.intersect_shape(consulta, TOPE_DE_CHOQUES):
		if choque.collider is RigidBody3D:
			excluidos.append(choque.rid)
	consulta.exclude = excluidos
	if espacio.intersect_shape(consulta, 1).is_empty():
		return 0.0
	var original := consulta.transform
	var eje := _brazo_de_carga.global_basis.z.normalized()
	var largo := (original * forma.shape.get_debug_mesh().get_aabb()).size.length()
	for paso in range(1, PASOS_DEL_UTIL_EN_LA_MANO + 1):
		var retroceso := largo * paso / PASOS_DEL_UTIL_EN_LA_MANO
		consulta.transform.origin = original.origin - eje * retroceso
		if not espacio.intersect_shape(consulta, 1).is_empty():
			continue
		# Desde un inicio libre, el barrido mide el borde exacto: los pasos no se dibujan.
		consulta.motion = eje * retroceso
		return retroceso * (1.0 - espacio.cast_motion(consulta)[0])
	return 0.0


## Le da o le saca al cuerpo el volumen de la caja que lleva. Es lo que la vuelve un objeto de
## verdad: con ella en la mano el jugador choca donde chocaría la caja.
func ocupar_el_frente(ocupado: bool) -> void:
	# Primero se la acomoda y después se enciende: encender el volumen donde no entra —que es lo
	# que pasa sacando una caja de un estante pegado a él— empuja al jugador.
	_acomodar_la_caja()
	_forma_de_la_caja.disabled = not ocupado


## Corre la caja sobre el eje de su brazo, hasta donde haya lugar.
##
## Sin suavizado, al revés que las manos: el volumen se enciende justo en el punto libre. Un punto
## intermedio quedaría adentro de la madera.
func _acomodar_la_caja() -> void:
	# Barre acá y no lee el brazo: su barrido es de antes de `move_and_slide()`, y con ese largo la
	# forma quedaba adentro de la pared y rebotaba el cuerpo.
	var brazo := _brazo_de_la_caja
	var barrido := PhysicsShapeQueryParameters3D.new()
	barrido.shape = brazo.shape
	barrido.transform = brazo.global_transform
	barrido.motion = brazo.global_basis.z * brazo.spring_length
	barrido.collision_mask = brazo.collision_mask
	barrido.exclude = _excluidos
	var libre := get_world_3d().direct_space_state.cast_motion(barrido)[0]
	var lugar := brazo.transform * Vector3(0.0, 0.0, brazo.spring_length * libre)
	_punto_de_la_caja.position = lugar
	# El cuerpo no gira: la forma se gira con el yaw a mano.
	_forma_de_la_caja.transform = _giro.transform * Transform3D(Basis.IDENTITY, lugar)


## Desde dónde y hacia dónde mira. La pide `reposicion_manual.gd` para saber dónde quiere el
## jugador apoyar la caja; el nodo de la cámara es privado y su ruta no se cruza desde afuera.
func mira() -> Transform3D:
	return _camara.global_transform


## Hacia adónde mira el jugador en el piso, sin el pitch. El cuerpo no gira: el yaw es del giro.
func frente() -> Vector3:
	return -_giro.global_basis.z


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


## Pone al jugador en `lugar`, quieto y con la vista horizontal hacia donde mira `lugar`.
func ubicar(lugar: Transform3D) -> void:
	global_position = lugar.origin
	velocity = Vector3.ZERO
	_control.orientar(lugar.basis.get_euler().y)
	_aplicar_la_rotacion()
	reset_physics_interpolation()


## Qué `id` del dominio se está llevando en la mano, o `SIN_ID`.
##
## La única puerta por la que otra escena pregunta qué lleva el jugador — la pide el puesto de
## limpieza para saber qué útil hay en la mano, que es lo que decide qué hace cada uso:
## `PisoDelLocal` busca este `id` en su tabla de usos, y una mano con otra cosa no hace nada.
## Devuelve el `id` y nunca el nodo: un nodo cruzaría la dirección de las capas al revés.
func id_en_la_mano() -> StringName:
	var datos := agarre.manos().sostenido()
	if datos == null:
		return ObjetoDelAlmacen.SIN_ID
	return datos.id


## El yaw va al giro y el pitch a la cámara. Son los dibujados: con un mouse rápido, los mismos que
## los de la mirada. El dominio devuelve dos ángulos y no sabe a qué nodo van.
func _aplicar_la_rotacion() -> void:
	# Un jugador instanciado sin entrar al árbol recibe eventos igual, y todavía no tiene cámara.
	if _camara == null:
		return
	_giro.rotation.y = _control.yaw_dibujado()
	_camara.rotation.x = _control.pitch_dibujado()


## `dominio/` decide SI el cursor tiene que estar tomado. La pausa lo suelta sin preguntarle, y
## al reanudar el cuadro siguiente lo vuelve a tomar.
func _el_cursor_esta_tomado() -> bool:
	return _control.quiere_el_cursor_tomado()


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
		for direccion: Vector3 in [
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
		var candidato := CampoDeInteraccion.Candidato.new(
			cuerpo.get_instance_id(),
			ojo.distance_to(impacto),
			adelante.angle_to(impacto - ojo),
			true,
			true
		)
		candidato.es_producto = "casillero" in cuerpo or _datos_de(cuerpo) is UnidadDeProducto
		return candidato
	return CampoDeInteraccion.Candidato.new(cuerpo.get_instance_id(), INF, INF, true, false)


## Los datos de un cuerpo del almacén, o `null` si no es un objeto. Se leen sin llamar a
## `interactuar()`, que activa cajas y puestos.
func _datos_de(cuerpo: Object) -> ObjetoDelAlmacen:
	if cuerpo != null and ReglasDeLosObjetos.PROPIEDAD_DATOS in cuerpo:
		return cuerpo.get(ReglasDeLosObjetos.PROPIEDAD_DATOS) as ObjetoDelAlmacen
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
	# Sale de donde se lo veía, que es hasta un paso de física atrás. Se mide en el punto del que
	# cuelga: soltarlo lo deja `top_level` y ya no hereda el dibujo del cuerpo. El reset evita que
	# se dibuje cruzando el local desde donde se lo agarró.
	var ancla := nodo.get_parent() as Node3D
	var atras := Vector3.ZERO
	if ancla != null:
		atras = ancla.get_global_transform_interpolated().origin - ancla.global_position
	# El dibujo va como mucho un paso atrás. El doble ya es un salto del cuerpo, no un atraso.
	var un_paso := velocity.length() / Engine.physics_ticks_per_second
	if atras.length() > 2.0 * un_paso:
		atras = Vector3.ZERO
	nodo.reparent(mundo, true)
	var datos := _datos_de(nodo)
	if nodo is RigidBody3D and datos != null and datos.se_apoya_derecho:
		nodo.global_basis = _derecho(nodo.global_basis)
		if ancla == agarre.punto_de_soltado and _apoyar_derecho_sobre_lo_mirado(nodo):
			nodo.reset_physics_interpolation()
			return
		if _dejar_al_lado(nodo):
			nodo.reset_physics_interpolation()
			return
		_ajustar_la_caida(nodo)
		nodo.reset_physics_interpolation()
		return
	# Sólo lo soltado al frente: vaciar las manos lo deja a los pies aunque se mire el piso.
	if nodo is RigidBody3D and ancla == agarre.punto_de_soltado and _apoyar_sobre_lo_mirado(nodo):
		nodo.reset_physics_interpolation()
		return
	nodo.global_position += atras
	nodo.reset_physics_interpolation()
	if nodo is RigidBody3D:
		_ajustar_la_caida(nodo)


## Apoya lo soltado sobre el punto que la mira toca, y devuelve si pudo. Qué superficie lo admite
## lo decide el dominio; acá se mide la superficie y si ahí entra.
func _apoyar_sobre_lo_mirado(cuerpo: RigidBody3D) -> bool:
	var ojo := _camara.global_position
	var consulta := PhysicsRayQueryParameters3D.create(
		ojo,
		ojo - _camara.global_basis.z * ReglasDelJugador.ALCANCE_DE_LA_MIRA,
		cuerpo.collision_mask
	)
	consulta.exclude = [get_rid(), cuerpo.get_rid()]
	var espacio := get_world_3d().direct_space_state
	var golpe := espacio.intersect_ray(consulta)
	if golpe.is_empty():
		return false
	var normal: Vector3 = golpe["normal"]
	if not ReglasDeLosObjetos.admite_lo_soltado(normal.y, _datos_de(golpe["collider"])):
		return false
	var formas: Array[CollisionShape3D] = []
	var base := INF
	for forma: CollisionShape3D in cuerpo.find_children("*", "CollisionShape3D", false, false):
		if forma.disabled or forma.shape == null:
			continue
		formas.append(forma)
		var orientada := Transform3D(cuerpo.global_basis) * forma.transform
		base = minf(base, (orientada * forma.shape.get_debug_mesh().get_aabb()).position.y)
	if formas.is_empty():
		return false
	var antes := cuerpo.global_position
	# Un roce por encima: apoyado justo, la consulta de abajo contestaría que choca con el piso.
	cuerpo.global_position = golpe["position"] + Vector3.UP * (ReglasDeLosObjetos.ROCE - base)
	if not _entra_entero(cuerpo, formas):
		cuerpo.global_position = antes
		return false
	return true


## Mide lugares cercanos sobre el mismo apoyo, con el volumen ya derecho.
func _apoyar_derecho_sobre_lo_mirado(cuerpo: RigidBody3D) -> bool:
	var ojo := _camara.global_position
	var consulta := PhysicsRayQueryParameters3D.create(
		ojo,
		ojo - _camara.global_basis.z * ReglasDelJugador.ALCANCE_DE_LA_MIRA,
		cuerpo.collision_mask
	)
	consulta.exclude = [get_rid(), cuerpo.get_rid()]
	var espacio := get_world_3d().direct_space_state
	var golpe := espacio.intersect_ray(consulta)
	if (
		golpe.is_empty()
		or not ReglasDeLosObjetos.admite_lo_soltado(golpe["normal"].y, _datos_de(golpe["collider"]))
	):
		return false
	var formas := _formas_de(cuerpo)
	if formas.is_empty():
		return false
	var limites := AABB()
	for indice in formas.size():
		var forma := formas[indice]
		var suyos := (
			Transform3D(cuerpo.global_basis)
			* forma.transform
			* forma.shape.get_debug_mesh().get_aabb()
		)
		limites = suyos if indice == 0 else limites.merge(suyos)
	var antes := cuerpo.global_position
	var punto: Vector3 = golpe["position"]
	# El piso tiene malla y volumen superpuestos: se identifica el apoyo con el mismo rayo
	# vertical que se usa alrededor, en vez de comparar dos maneras distintas de medirlo.
	consulta.from = punto + Vector3.UP * ReglasDeLosObjetos.ROCE
	consulta.to = punto - Vector3.UP * ReglasDeLosObjetos.ROCE
	var apoyo_apuntado := espacio.intersect_ray(consulta)
	if apoyo_apuntado.is_empty():
		return false
	var ancho := maxf(limites.size.x, limites.size.z)
	for anillo in ReglasDeLosObjetos.LADOS_ALREDEDOR + 1:
		for lado in 1 if anillo == 0 else ReglasDeLosObjetos.LADOS_ALREDEDOR:
			var vuelta := Basis(Vector3.UP, TAU * lado / ReglasDeLosObjetos.LADOS_ALREDEDOR)
			var candidato := (
				punto + vuelta * Vector3.RIGHT * ancho * anillo / ReglasDeLosObjetos.LADOS_ALREDEDOR
			)
			consulta.from = candidato + Vector3.UP * ReglasDeLosObjetos.ROCE
			consulta.to = candidato - Vector3.UP * ReglasDeLosObjetos.ROCE
			var apoyo := espacio.intersect_ray(consulta)
			# Dos cajas pueden tener tapas a la misma altura: la altura sola no conserva el apoyo.
			if (
				apoyo.is_empty()
				or apoyo["rid"] != apoyo_apuntado["rid"]
				or absf(apoyo["position"].y - punto.y) > ReglasDeLosObjetos.ROCE
			):
				continue
			if not ReglasDeLosObjetos.admite_lo_soltado(
				apoyo["normal"].y, _datos_de(apoyo["collider"])
			):
				continue
			cuerpo.global_position = (
				candidato + Vector3.UP * (ReglasDeLosObjetos.ROCE - limites.position.y)
			)
			if _entra_entero(cuerpo, formas):
				return true
	cuerpo.global_position = antes
	return false


## El punto fijo puede quedar detrás de la madera. Se barre el volumen desde el jugador.
##
## **Y lo que queda metido en el cuerpo cae derecho al piso, al lado del jugador**, como la caja.
## El barrido no cuenta el cuerpo, que es de donde sale: lo que tiene más fondo que el lugar entre
## el cuerpo y una pared quedaba encimado con él, y la física lo sacaba a los empujones. Medido el
## 2026-09-30 mirando 40° abajo: un bidón a 0,7-1,0 m de una pared quedaba 5 cm adentro de ella, y
## a 0,5 m un balde saltaba 28 cm y la mopa salía despedida 42 cm de costado.
func _ajustar_la_caida(cuerpo: RigidBody3D) -> void:
	var inicio := _camara.global_position
	var recorrido := cuerpo.global_position - inicio
	var iniciales := _inicios_del_barrido(cuerpo, inicio, recorrido)
	if iniciales.is_empty():
		_dejar_al_lado(cuerpo)
		cuerpo.reset_physics_interpolation()
		return
	inicio = iniciales[0]
	recorrido = cuerpo.global_position - inicio
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
	# Lo que el barrido frenó contra algo queda a un centímetro, y no pegado. Cayendo pegada a una
	# pared, una unidad se enganchaba en una arista del modelo, giraba y se hundía 3 cm en el
	# rincón con el piso. Medido el 2026-09-30 al pie de la fachada: pasaba según qué suites
	# hubieran corrido antes, y con el centímetro no pasa en ningún orden.
	if avance < 1.0:
		cuerpo.global_position -= recorrido.normalized() * HOLGURA_DE_LA_CAIDA
	# Si al lado tampoco entra, queda donde lo dejó el barrido: lo que ya no tiene lugar lo resuelve
	# la red de seguridad.
	if _metido_en_el_cuerpo(cuerpo) and _dejar_al_lado(cuerpo):
		cuerpo.reset_physics_interpolation()


## Una cabeza muy adelantada puede empezar el barrido ya dentro de la pared.
## cast_motion no resuelve solapes iniciales. Se comienza con la punta del volumen
## en la camara, solo si ese inicio completo esta libre, incluidos los solidos detras.
func _inicios_del_barrido(
	cuerpo: RigidBody3D, inicio: Vector3, recorrido: Vector3
) -> Array[Vector3]:
	var datos := _datos_de(cuerpo)
	if datos == null or datos.id != ReglasDeLaLimpieza.ID_DE_LA_MOPA:
		return [inicio]
	var formas := _formas_de(cuerpo)
	var espacio := get_world_3d().direct_space_state
	var toca := false
	var retroceso := 0.0
	var direccion := recorrido.normalized()
	for forma in formas:
		var consulta := PhysicsShapeQueryParameters3D.new()
		consulta.shape = forma.shape
		consulta.transform = forma.global_transform
		consulta.transform.origin -= recorrido
		consulta.margin = safe_margin
		consulta.collision_mask = cuerpo.collision_mask
		consulta.exclude = [get_rid(), cuerpo.get_rid()]
		toca = toca or not espacio.intersect_shape(consulta, 1).is_empty()
		var limites := (
			Transform3D(cuerpo.global_basis)
			* forma.transform
			* forma.shape.get_debug_mesh().get_aabb()
		)
		var punta := limites.position
		for eje in 3:
			if direccion[eje] > 0.0:
				punta[eje] += limites.size[eje]
		retroceso = maxf(retroceso, punta.dot(direccion))
	if not toca:
		return [inicio]
	var libre := inicio - direccion * (retroceso + ReglasDeLosObjetos.ROCE)
	for forma in formas:
		var consulta := PhysicsShapeQueryParameters3D.new()
		consulta.shape = forma.shape
		consulta.transform = forma.global_transform
		consulta.transform.origin -= cuerpo.global_position - libre
		consulta.margin = safe_margin
		consulta.collision_mask = cuerpo.collision_mask
		consulta.exclude = [get_rid(), cuerpo.get_rid()]
		if not espacio.intersect_shape(consulta, 1).is_empty():
			return []
	return [libre]


## Si lo soltado quedó metido en el cuerpo del jugador más que un roce.
##
## Se mide con las formas de lo soltado contra el cuerpo solo: lo demás que tocan se excluye, y
## lo que queda es cuánto se superponen los dos. Tocarlo no cuenta: la física no tiene nada que
## sacar. Se pregunta desde lo soltado y no desde la cápsula: recién vuelto al mundo, el motor no
## lo encuentra donde quedó. Medido el 2026-09-30: preguntando desde la cápsula no aparecía.
func _metido_en_el_cuerpo(cuerpo: RigidBody3D) -> bool:
	# Llevando una caja, su volumen es parte del cuerpo, y lo que se suelta es ella: se mediría
	# metida en sí misma. A la caja la acomoda la reposición, que corre después.
	if not _forma_de_la_caja.disabled:
		return false
	var espacio := get_world_3d().direct_space_state
	for forma in _formas_de(cuerpo):
		var consulta := PhysicsShapeQueryParameters3D.new()
		consulta.shape = forma.shape
		consulta.transform = forma.global_transform
		consulta.collision_mask = collision_layer
		var otros: Array[RID] = [cuerpo.get_rid()]
		var lo_toca := false
		for choque in espacio.intersect_shape(consulta, TOPE_DE_CHOQUES):
			if choque["rid"] == get_rid():
				lo_toca = true
			else:
				otros.append(choque["rid"])
		if not lo_toca:
			continue
		consulta.exclude = otros
		var puntos := espacio.collide_shape(consulta, TOPE_DE_CHOQUES)
		for indice in range(0, puntos.size() - 1, 2):
			if puntos[indice].distance_to(puntos[indice + 1]) > ReglasDeLosObjetos.ROCE:
				return true
	return false


## Lo deja derecho en el piso, al lado del jugador, en el primer lugar donde entra entero, y
## devuelve si lo encontró. Se prueba de adelante hacia los costados, como la caja.
##
## Derecho como la caja: la mira lo inclina, y un bidón inclinado apoyado en el piso se vuelca. Con
## el mismo rumbo, eso sí: lo que ya venía derecho cae sin girar.
func _dejar_al_lado(cuerpo: RigidBody3D) -> bool:
	var formas := _formas_de(cuerpo)
	if formas.is_empty():
		return false
	var antes := cuerpo.global_transform
	cuerpo.global_basis = _derecho(cuerpo.global_basis)
	var limites := AABB()
	for indice in formas.size():
		var forma := formas[indice]
		var suyos := (
			Transform3D(cuerpo.global_basis)
			* forma.transform
			* forma.shape.get_debug_mesh().get_aabb()
		)
		limites = suyos if indice == 0 else limites.merge(suyos)
	var capsula := _forma_del_cuerpo.shape as CapsuleShape3D
	var ancho := Vector2(limites.size.x, limites.size.z).length() / 2.0
	var lugares := LugaresDelPiso.alrededor(
		get_world_3d().direct_space_state,
		global_position,
		frente(),
		capsula.radius + ancho + ReglasDeLosObjetos.ROCE,
		limites.size.y,
		ReglasDeLosObjetos.CAIDA_HASTA_EL_PISO,
		ReglasDeLosObjetos.LADOS_ALREDEDOR,
		cuerpo.collision_mask,
		[cuerpo.get_rid(), get_rid()]
	)
	var centro := limites.get_center()
	for punto in lugares:
		# Un roce por encima del piso, como al apoyarlo sobre lo mirado.
		cuerpo.global_position = (
			punto + Vector3(-centro.x, ReglasDeLosObjetos.ROCE - limites.position.y, -centro.z)
		)
		if _entra_entero(cuerpo, formas):
			return true
	cuerpo.global_transform = antes
	return false


## Si lo soltado entra entero donde está, cuerpo del jugador incluido. Con el contorno de los
## muebles: el hueco de un estante es lugar libre y no es un apoyo.
func _entra_entero(cuerpo: RigidBody3D, formas: Array[CollisionShape3D]) -> bool:
	var espacio := get_world_3d().direct_space_state
	for forma in formas:
		var lugar := PhysicsShapeQueryParameters3D.new()
		lugar.shape = forma.shape
		lugar.transform = forma.global_transform
		lugar.collision_mask = cuerpo.collision_mask | ReglasDeLosObjetos.CAPA_DEL_CONTORNO
		lugar.exclude = [cuerpo.get_rid()]
		if not espacio.intersect_shape(lugar, 1).is_empty():
			return false
	return true


## La misma orientación sin la inclinación: el rumbo en el piso, y arriba para arriba. Si el
## costado quedó vertical —lo soltado venía acostado—, el rumbo sale del frente.
static func _derecho(base: Basis) -> Basis:
	var costado := Vector3(base.x.x, 0.0, base.x.z)
	if costado.length_squared() < 0.0001:
		var frente := Vector3(base.z.x, 0.0, base.z.z)
		if frente.length_squared() < 0.0001:
			return Basis.IDENTITY
		costado = Vector3.UP.cross(frente)
	costado = costado.normalized()
	return Basis(costado, Vector3.UP, costado.cross(Vector3.UP))


## Las formas con las que el cuerpo choca: las apagadas no cuentan.
static func _formas_de(cuerpo: RigidBody3D) -> Array[CollisionShape3D]:
	var formas: Array[CollisionShape3D] = []
	for forma: CollisionShape3D in cuerpo.find_children("*", "CollisionShape3D", false, false):
		if not forma.disabled and forma.shape != null:
			formas.append(forma)
	return formas
