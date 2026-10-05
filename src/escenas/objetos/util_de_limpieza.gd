## Un útil de limpieza —la mopa, el balde o un jabón—: se levanta como cualquier objeto del
## almacén, y se dibuja con la malla del modelo que lo trae.
##
## La geometría se toma, por su nombre, del nodo del `.glb` que la dibujaba fija en el baño.
## La mopa y el balde añaden anclajes de fibras y datos del asa a copias temporales; no hay un
## asset duplicado que pueda quedar viejo al cambiar el modelo. El `transform` sí está escrito
## en la escena, y un caso afirma que coincide con el del modelo.
##
## Es cáscara: qué tiene el balde y de qué está mojada la mopa lo sabe `PisoDelLocal`. Acá vive la
## carga que se ve —el agua del balde, la punta mojada de la mopa—, y quien la pinta es el puesto
## de limpieza, con el color que contesta el dominio.
extends ObjetoAgarrable

const MODELO := preload("res://assets/models/SEPT_JUEGOS_PROTOTIPO.glb")
const SuperficieLiquida := preload("res://src/escenas/objetos/superficie_liquida.gd")
const FibrasDeLaMopa := preload("res://src/escenas/objetos/fibras_de_la_mopa.gd")
const Gotas := preload("res://src/escenas/objetos/gotas_del_balde.gd")

## El nodo del modelo que lo dibujaba fijo: su malla es la de este útil.
@export var nodo_del_modelo: StringName

@export var malla: MeshInstance3D
@export var escala_apoyada := 1.0
@export var examen: Examen

## Lo que muestra de qué está cargado: el agua del balde, la punta mojada de la mopa. Los jabones
## no llevan.
@export var carga: MeshInstance3D

## Lo que se marca al enfocarlo: la malla, y no la carga, que queda adentro del balde.
@export var mallas: Array[MeshInstance3D] = []

var contacto_del_movimiento: PhysicsBody3D
var _bajada: Tween
var _tamanos_originales: Dictionary[Node3D, Transform3D] = {}
var _gotas: Gotas
var _pintura_de_gotas: StandardMaterial3D


func _ready() -> void:
	super()
	malla.mesh = malla_del_modelo(nodo_del_modelo)
	if datos.id == ReglasDeLaLimpieza.ID_DE_LA_MOPA:
		_gotas = Gotas.new()
		_pintura_de_gotas = StandardMaterial3D.new()
		_pintura_de_gotas.roughness = 0.3
		add_child(_gotas)
		_gotas.preparar(_pintura_de_gotas)
	if escala_apoyada != 1.0:
		for parte: Node3D in [malla, carga, get_node("Forma")]:
			_tamanos_originales[parte] = parte.transform
		_actualizar_tamano()
	set_process(datos.id == ReglasDeLaLimpieza.ID_DEL_BALDE)
	if datos.id == ReglasDeLaLimpieza.ID_DEL_BALDE:
		set_notify_transform(true)
		orientacion_en_mano = Basis(
			Vector3.RIGHT, ReglasDeLaLimpieza.INCLINACION_DEL_BALDE_EN_LA_MANO
		)


func _process(_delta: float) -> void:
	_mantener_vertical()


## Conserva el punto de carga y el giro horizontal, sin heredar el cabeceo de la vista.
func _mantener_vertical() -> void:
	if not is_inside_tree() or datos == null or datos.id != ReglasDeLaLimpieza.ID_DEL_BALDE:
		return
	if not freeze or top_level:
		return
	if examen != null and examen.esta_examinando():
		return
	var ancla := get_parent() as Node3D
	if ancla == null:
		return
	var derecha := ancla.global_basis.x
	derecha.y = 0.0
	if derecha.length_squared() < 0.000001:
		return
	derecha = derecha.normalized()
	var vertical := Basis(derecha, Vector3.UP, derecha.cross(Vector3.UP))
	# Evita volver a notificar un transform que ya corregimos.
	if not global_basis.is_equal_approx(vertical):
		global_basis = vertical


## El movimiento pertenece al util: el ancla sigue el brazo del jugador en cada cuadro.
func mostrar_la_mojada(
	balde: Node3D,
	punto_mundo: Vector3 = Vector3.INF,
	orientacion_de_destino: Basis = Basis.IDENTITY
) -> void:
	if not freeze or top_level:
		return
	if _bajada != null:
		_bajada.kill()
	contacto_del_movimiento = balde as PhysicsBody3D
	if punto_mundo.is_finite():
		(malla as FibrasDeLaMopa).liberar()
	transform = Transform3D(orientacion_en_mano, Vector3.ZERO)
	_bajada = create_tween()
	_bajada.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var mover := _mover_la_mopa.bind(balde, punto_mundo, orientacion_de_destino)
	var duracion := ReglasDeLaLimpieza.DURACION_DE_LA_MOJADA
	_bajada.tween_method(mover, 0.0, 1.0, duracion * 0.4)
	_bajada.tween_interval(duracion * 0.2)
	_bajada.tween_method(mover, 1.0, 0.0, duracion * 0.4)


## La cabeza salva el borde del recipiente y entra desde arriba, sin mover la cámara.
func _mover_la_mopa(
	progreso: float,
	balde: Node3D,
	punto_mundo: Vector3 = Vector3.INF,
	orientacion_de_destino: Basis = Basis.IDENTITY
) -> void:
	if not is_instance_valid(balde) or not freeze or top_level:
		return
	var reposo := Transform3D(orientacion_en_mano, Vector3.ZERO)
	var destino_explicito := punto_mundo.is_finite()
	if progreso <= 0.0:
		transform = reposo
		contacto_del_movimiento = null
		if destino_explicito:
			(malla as FibrasDeLaMopa).liberar()
		else:
			(malla as FibrasDeLaMopa).limitar_en(balde, 0.0)
		return
	contacto_del_movimiento = balde as PhysicsBody3D
	var ancla := get_parent() as Node3D
	var inicio := ancla.global_transform * reposo
	var destino := (
		orientacion_de_destino.orthonormalized()
		if destino_explicito
		else balde.global_basis.orthonormalized()
	)
	var orientacion := inicio.basis.orthonormalized().slerp(destino, progreso)
	var desde := inicio * carga.position
	var hasta := punto_mundo if destino_explicito else balde.to_global(Vector3(0.0, 0.07, 0.0))
	# El punto del inodoro queda bajo el asiento; el arco lo salva antes de bajar a la taza.
	var borde := hasta.y + 0.24 if destino_explicito else balde.to_global(Vector3(0.0, 0.18, 0.0)).y
	var control := hasta
	control.y = maxf(desde.y, borde) + 0.35
	# La tangente final es vertical: primero salva el borde, luego baja por la abertura.
	var cabeza := desde.lerp(control, progreso).lerp(control.lerp(hasta, progreso), progreso)
	global_transform = Transform3D(orientacion, cabeza - orientacion * carga.position)
	if destino_explicito:
		(malla as FibrasDeLaMopa).enjuagar_en(contacto_del_movimiento)
	else:
		(malla as FibrasDeLaMopa).limitar_en(balde, progreso)


## Agarre quita y vuelve a colgar el nodo tanto al soltar como al cambiar de mano.
## La orientacion mundial de ese instante la conserva Agarre antes de quitarlo.
func _notification(que: int) -> void:
	if que == NOTIFICATION_PARENTED:
		_actualizar_tamano.call_deferred()
	if que == NOTIFICATION_TRANSFORM_CHANGED:
		_mantener_vertical()
	if que == NOTIFICATION_UNPARENTED and _bajada != null:
		_bajada.kill()
		_bajada = null
		contacto_del_movimiento = null
		(malla as FibrasDeLaMopa).liberar()


## Agranda lo apoyado desde su base, sin cambiar el tamaño que ocupa en la mano.
func _actualizar_tamano() -> void:
	if _tamanos_originales.is_empty() or not is_inside_tree():
		return
	var escala := 1.0 if freeze and not top_level else escala_apoyada
	var base := malla.mesh.get_aabb().position.y
	var ajuste := Transform3D(
		Basis.IDENTITY.scaled(Vector3.ONE * escala), Vector3.UP * base * (1.0 - escala)
	)
	for parte: Node3D in _tamanos_originales:
		parte.transform = ajuste * _tamanos_originales[parte]


## Muestra la carga del color que se le pasa, o la esconde. Cuál y de qué color lo decide el
## dominio: acá sólo se pinta.
func mostrar_la_carga(cargada: bool, color: Color, cantidad: float = 1.0) -> void:
	if carga is SuperficieLiquida:
		(carga as SuperficieLiquida).presentar(cargada)
		(carga as SuperficieLiquida).pintar(color)
	else:
		carga.visible = cargada
		(carga.material_override as StandardMaterial3D).albedo_color = (
			color if cantidad >= 1.0 else Color(0.72, 0.70, 0.62).lerp(color, cantidad)
		)
		if malla is FibrasDeLaMopa:
			(malla as FibrasDeLaMopa).mostrar_la_carga(cargada, color, cantidad)


func mostrar_goteo(cargada: bool, color: Color) -> void:
	if _gotas == null or not cargada or not is_visible_in_tree():
		return
	if not _pintura_de_gotas.albedo_color.is_equal_approx(color):
		_pintura_de_gotas.albedo_color = color
	_gotas.emitir(carga.global_position + Vector3.DOWN * 0.025, Vector3.DOWN * 0.2, 1)


func color_de_la_carga() -> Color:
	if carga is SuperficieLiquida:
		return (carga as SuperficieLiquida).color_de_la_superficie()
	return (carga.material_override as StandardMaterial3D).albedo_color


## La malla del nodo del modelo que se llama así, o `null`.
##
## Se lee del `SceneState` y no instanciando el modelo: son doscientos nodos para quedarse con uno.
static func malla_del_modelo(nombre: StringName) -> Mesh:
	var estado := MODELO.get_state()
	for nodo: int in estado.get_node_count():
		if estado.get_node_name(nodo) != nombre:
			continue
		for propiedad: int in estado.get_node_property_count(nodo):
			if estado.get_node_property_name(nodo, propiedad) == &"mesh":
				return estado.get_node_property_value(nodo, propiedad)
	return null
