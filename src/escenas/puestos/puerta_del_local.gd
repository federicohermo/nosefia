## **No decide si está abierta ni cuánto giró.** Eso es `Puerta`, que es de `dominio/` y tiene
## test; acá viven la bisagra, el sentido y la aritmética de transformadas, que son geometría de
## la escena y no una regla del juego.
##
## **El cuerpo es animable y no estático.** Un estático movido a mano le pasa a través a lo que
## tiene adelante y no lo despierta. Uno animable lo empuja: el motor arrastra lo suelto sin
## código propio. El `.tscn` no le puede cambiar el tipo al cuerpo que trae el modelo, y por eso
## éste es nuevo y el del modelo queda con la forma apagada.
##
## Va en `puestos/` y no en `objetos/`, que es el criterio de esa carpeta —cuántas instancias
## hay—: de éstas hay una por vano y viven cableadas.
##
## No declara un nombre global a propósito: es cáscara, nadie la nombra desde abajo, y el `.tscn`
## que la usa la trae con su script puesto.
extends AnimatableBody3D

## La hoja quedó quieta: al terminar un giro, o al cerrarla de golpe.
signal hoja_quieta(cuerpo: PhysicsBody3D)

## Un gesto sobre la puerta. Sale una vez, al pedirlo, y no durante el giro.
signal puerta_abierta(puerta: Node3D)
signal puerta_cerrada(puerta: Node3D)
signal puerta_trabada(puerta: Node3D)
signal porton_trabado(puerta: Node3D)
signal salida_solicitada

## La entrada preguntó si se puede salir y la respuesta fue no. Se suma a `puerta_trabada`.
signal salida_rechazada

## Qué aviso da una puerta que no abre.
enum Traba { NINGUNA, PUERTA, PORTON }

## Metros que el sensor de la compuerta se adelanta a cada cara de la hoja.
const ALCANCE_DEL_EMPUJE := 0.25

## Metros. Lo menos que se le exige a un objeto para decir que la hoja lo puede correr.
const CORRIMIENTO_MINIMO := 0.05

## La malla que gira, que es el padre de este cuerpo. Entra por `@export` y no con un
## `get_parent()` para que el `.tscn` diga qué se mueve en vez de que lo suponga el script.
@export var hoja: MeshInstance3D

## Un herraje puede sobresalir del canto de la hoja. El eje explícito evita que ese detalle
## cambie el punto de giro; las puertas sin anclaje conservan el borde de su malla.
@export var eje_de_la_bisagra: Marker3D
@export_enum("Antihorario:-1", "Horario:1") var sentido_del_giro: int = 1

## Las mallas que el marco del objetivo pinta al enfocar. Sin esto iría a buscar
## `MeshInstance3D` hijos de este cuerpo, que no tiene ninguno: la puerta se vería sin contorno.
@export var mallas: Array[MeshInstance3D] = []

## La compuerta del mostrador: además del clic, el cuerpo la abre al pasar. Sólo gira hacia
## `sentido_del_giro`, el lado de sus bisagras: desde el otro lado no cede. Cerrarla es siempre
## a mano.
@export var se_abre_al_empujar := false

## El setter y no `_ready()`: los tests tocan la puerta sin meter la escena al árbol.
@export var traba := Traba.NINGUNA:
	set(valor):
		traba = valor
		_puerta = Puerta.new(valor != Traba.NINGUNA)

## Quién es esta puerta para el subtítulo. Las trabadas comparten la traba, así que la escena
## se la declara por su ruta; una puerta sin identidad no dice nada al examinarla.
var identidad: StringName = &""
var consultar_salida: Callable

var _puerta := Puerta.new()

## La hoja cerrada, en coordenadas del padre. Se guarda entera y no sólo el ángulo porque el
## giro se compone contra ella: acumular sobre la transformada actual arrastra el error de cada
## cuadro y la hoja termina corrida del marco.
var _cerrada: Transform3D

## El punto por el que pasa el eje, en coordenadas del padre.
var _bisagra: Vector3

var _girando := false

## Lo pesado que la hoja encontró en el último paso.
var _pesados: Array[RigidBody3D] = []

## Dónde va este cuerpo respecto de la hoja. **El cuerpo no sigue a la hoja solo**: un cuerpo
## animable sincronizado con la física sólo se entera de su propia transformada, no de la del
## padre. Medido el 2026-09-26: con la hoja girando, el cuerpo del servidor no se movía. Por eso
## va suelto de la jerarquía y el giro se le escribe a él.
var _desde_la_hoja: Transform3D


func _ready() -> void:
	_cerrada = hoja.transform
	var punto := Vector3(hoja.get_aabb().position.x, 0.0, 0.0)
	if eje_de_la_bisagra != null:
		punto = hoja.to_local(eje_de_la_bisagra.global_position)
	_bisagra = _cerrada * punto
	_desde_la_hoja = hoja.global_transform.affine_inverse() * global_transform
	top_level = true
	if se_abre_al_empujar:
		_armar_el_empuje()


## Un sensor del tamaño de la hoja y más grueso que ella: el cuerpo lo toca antes que a la hoja,
## y la hoja ya está girando cuando llega.
func _armar_el_empuje() -> void:
	var caja := hoja.get_aabb()
	var espesor := 0 if caja.size.x < caja.size.z else 2
	var tamano := caja.size
	tamano[espesor] += 2.0 * ALCANCE_DEL_EMPUJE
	var forma := BoxShape3D.new()
	forma.size = tamano
	var volumen := CollisionShape3D.new()
	volumen.shape = forma
	volumen.position = caja.get_center()
	var sensor := Area3D.new()
	sensor.collision_layer = 0
	sensor.add_child(volumen)
	sensor.body_entered.connect(_al_tocar)
	# Diferido: en `_ready()` la hoja todavía está armando sus hijos y rechaza uno nuevo.
	hoja.add_child.call_deferred(sensor)


func _al_tocar(cuerpo: Node3D) -> void:
	if not cuerpo is CharacterBody3D:
		return
	# La punta libre de la hoja se aleja de quien empuja: gira hacia el lado de la hoja opuesto
	# al cuerpo.
	var padre := hoja.get_parent_node_3d()
	var caja := hoja.get_aabb()
	var espesor := Vector3.RIGHT if caja.size.x < caja.size.z else Vector3.BACK
	var punta := _cerrada * caja.get_center() - _bisagra
	var normal := _cerrada.basis * espesor
	var lejos := (
		normal
		* signf(normal.dot(_cerrada * caja.get_center() - padre.to_local(cuerpo.global_position)))
	)
	var hacia := 1 if Vector3.UP.cross(punta).dot(lejos) >= 0.0 else -1
	if hacia != sentido_del_giro or not _puerta.empujar():
		return
	puerta_abierta.emit(self)


func accionar() -> void:
	if consultar_salida.is_valid():
		if consultar_salida.call():
			salida_solicitada.emit()
			return
		salida_rechazada.emit()
	alternar()


func contexto_de_interaccion(_sostenido: ObjetoDelAlmacen) -> ReferenciaDeControles.Contexto:
	if consultar_salida.is_valid():
		return ReferenciaDeControles.contexto_primario(
			(
				ReferenciaDeControles.Linea.INTERACTUAR_PRIMARIO
				if consultar_salida.call()
				else ReferenciaDeControles.Linea.NINGUNA
			),
			ReferenciaDeControles.Ruta.ACCIONAR
		)
	return ReferenciaDeControles.contexto_de_lo_fijo(_puerta.abierta())


## Abre, cierra o intenta una trabada, y emite el aviso que dispara su sonido.
func alternar() -> void:
	if not _puerta.alternar():
		(porton_trabado if traba == Traba.PORTON else puerta_trabada).emit(self)
	elif _puerta.abierta():
		puerta_abierta.emit(self)
	else:
		puerta_cerrada.emit(self)


func abrir_para_salida() -> void:
	if _puerta.abrir_para_salida():
		puerta_abierta.emit(self)


## En qué estado está.
func puerta() -> Puerta:
	return _puerta


## Sin reiniciar la interpolación, la hoja se dibujaría girando hasta cerrarse.
func cerrar_de_golpe() -> void:
	_puerta.cerrar_de_golpe()
	_girando = false
	hoja.transform = _cerrada
	# Animable, el cuerpo llega a su lugar con velocidad y despide lo que toca la hoja: medido el
	# 2026-09-26, una unidad apoyada salía a 85 m/s. Estático, salta.
	PhysicsServer3D.body_set_mode(get_rid(), PhysicsServer3D.BODY_MODE_STATIC)
	PhysicsServer3D.body_set_state(
		get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, hoja.global_transform * _desde_la_hoja
	)
	PhysicsServer3D.body_set_mode(get_rid(), PhysicsServer3D.BODY_MODE_KINEMATIC)
	hoja.reset_physics_interpolation()
	hoja_quieta.emit(self)


## El giro va por cuadro de física y no de dibujo: lo que se mueve es un cuerpo de colisión, y
## adelantarlo en el cuadro equivocado lo deja medio paso atrás del jugador que lo está cruzando.
func _physics_process(delta: float) -> void:
	var antes := _puerta.angulo()
	var freno := _freno(delta)
	var angulo := _puerta.avanzar(delta, freno.factor, freno.tope)
	_llevar_lo_pesado(antes, angulo)
	hoja.transform = _pose_de_la_hoja(angulo)
	global_transform = hoja.global_transform * _desde_la_hoja
	if not _puerta.quieta():
		_girando = true
	elif _girando:
		_girando = false
		hoja_quieta.emit(self)


func _pose_de_la_hoja(angulo: float) -> Transform3D:
	var giro := Basis(Vector3.UP, angulo * sentido_del_giro)
	return Transform3D(giro, _bisagra - giro * _bisagra) * _cerrada


## Qué hay en el recorrido del próximo paso. Sólo mide el contacto y la movilidad; qué hace la
## hoja con eso lo decide `FrenoDeLaPuerta`.
func _freno(delta: float) -> FrenoDeLaPuerta:
	var siguiente := _puerta.angulo_siguiente(delta)
	var frenado := _puerta.angulo_siguiente(delta * FrenoDeLaPuerta.FACTOR_DE_LO_PESADO)
	if is_equal_approx(siguiente, _puerta.angulo()) or not is_inside_tree():
		return FrenoDeLaPuerta.new()
	var padre := hoja.global_transform * hoja.transform.affine_inverse()
	var pose := padre * _pose_de_la_hoja(siguiente) * _desde_la_hoja
	var consulta := PhysicsShapeQueryParameters3D.new()
	consulta.collision_mask = collision_mask
	consulta.exclude = [get_rid()]
	var obstaculo := FrenoDeLaPuerta.Obstaculo.NADA
	var puede_correrse := true
	_pesados.clear()
	for volumen: CollisionShape3D in find_children("*", "CollisionShape3D", false, false):
		if volumen.disabled:
			continue
		consulta.shape = volumen.shape
		consulta.transform = pose * volumen.transform
		for golpe in get_world_3d().direct_space_state.intersect_shape(consulta, 16):
			var objeto := golpe["collider"] as RigidBody3D
			if objeto == null:
				continue
			if objeto.has_method(ReglasDeLosObjetos.METODO_EMPUJAR):
				obstaculo = FrenoDeLaPuerta.Obstaculo.PESADO
				_pesados.append(objeto)
				puede_correrse = puede_correrse and _se_corre(objeto, frenado)
			elif obstaculo == FrenoDeLaPuerta.Obstaculo.NADA:
				obstaculo = FrenoDeLaPuerta.Obstaculo.LIVIANO
	return FrenoDeLaPuerta.decidir(obstaculo, puede_correrse, _puerta.angulo())


## Si el objeto tiene lugar para correrse lo que la hoja avanza hasta `siguiente`, que es el paso
## ya frenado: la hoja que se corre no gira al paso entero. Se mide sin contar la hoja, que
## es justamente lo que lo empuja, y sin mirar si está congelado o dormido: se pregunta al espacio
## y no se mueve el cuerpo, porque una caja congelada es estática para el motor y un movimiento
## de prueba no la hace chocar con ninguna pared.
func _se_corre(objeto: RigidBody3D, siguiente: float) -> bool:
	var corrimiento := _corrimiento_de(objeto, _puerta.angulo(), siguiente)
	if corrimiento.length() < CORRIMIENTO_MINIMO:
		corrimiento = corrimiento.normalized() * CORRIMIENTO_MINIMO
	var consulta := PhysicsShapeQueryParameters3D.new()
	consulta.collision_mask = objeto.collision_mask
	consulta.exclude = [objeto.get_rid(), get_rid()]
	consulta.margin = -ReglasDeLosObjetos.ROCE
	for volumen: CollisionShape3D in objeto.find_children("*", "CollisionShape3D", false, false):
		if volumen.disabled:
			continue
		consulta.shape = volumen.shape
		consulta.transform = volumen.global_transform.translated(corrimiento)
		if not get_world_3d().direct_space_state.intersect_shape(consulta, 1).is_empty():
			return false
	return true


## Adónde llevaría la hoja a ese objeto si lo arrastrara de `desde` a `hasta`.
##
## La hoja toca al objeto por donde asoma más lejos de la bisagra, y ahí avanza más que en su
## centro. Si el objeto sólo recorriera lo que recorre su centro, la hoja lo penetraría un poco
## más por cuadro.
func _corrimiento_de(objeto: RigidBody3D, desde: float, hasta: float) -> Vector3:
	var padre := hoja.global_transform * hoja.transform.affine_inverse()
	var bisagra := padre * _bisagra
	var radio := objeto.global_position - bisagra
	radio.y = 0.0
	if radio.is_zero_approx():
		return Vector3.ZERO
	var giro := Basis(Vector3.UP, (hasta - desde) * sentido_del_giro)
	return (giro * radio - radio) * maxf(1.0, _alcance_de(objeto, bisagra) / radio.length())


## Hasta dónde llega el objeto desde la bisagra, en el plano.
func _alcance_de(objeto: RigidBody3D, bisagra: Vector3) -> float:
	var alcance := 0.0
	for volumen: CollisionShape3D in objeto.find_children("*", "CollisionShape3D", false, false):
		var limites := LimitesDeForma.de(volumen.shape)
		for indice in 8:
			var punto := volumen.global_transform * limites.get_endpoint(indice)
			alcance = maxf(alcance, Vector2(punto.x - bisagra.x, punto.z - bisagra.z).length())
	return alcance


## Una caja congelada es estática para el motor y la hoja le pasaría de largo: la lleva el
## script, entera, aunque `empujar` sólo arrastre la mitad de lo que se le pide.
func _llevar_lo_pesado(desde: float, hasta: float) -> void:
	if is_equal_approx(desde, hasta):
		return
	for objeto in _pesados:
		if objeto.freeze:
			var corrimiento := _corrimiento_de(objeto, desde, hasta)
			objeto.add_collision_exception_with(self)
			objeto.call(
				ReglasDeLosObjetos.METODO_EMPUJAR,
				corrimiento / ReglasDeLosObjetos.ARRASTRE_DE_LA_CAJA
			)
			objeto.remove_collision_exception_with(self)


func texto_al_examinar() -> String:
	return SubtitulosAlExaminar.de_lo_fijo(identidad)
