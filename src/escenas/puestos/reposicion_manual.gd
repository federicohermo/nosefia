## Agrupa los productos colocados y conserva cuerpos independientes al soltarlos.
extends Node3D

const ZonaDeReposicion := preload("res://src/escenas/puestos/zona_de_reposicion.gd")
const GrupoDelPiso := preload("res://src/escenas/objetos/grupo_del_piso.gd")
const CajaDelDeposito := preload("res://src/escenas/objetos/caja_de_productos.gd")
const JugadorDelLocal := preload("res://src/escenas/jugador.gd")
const OBJETO := preload("res://src/escenas/objetos/objeto_agarrable.tscn")
const BORDE := preload("res://src/escenas/puestos/borde_de_reposicion.gdshader")
const PRODUCTOS_NUEVOS := preload("res://assets/models/productos_marolini_jorgillo.glb")

## Hasta dónde se busca piso debajo de una caja recién soltada, en metros.
const CAIDA_MAXIMA := 3.0

@export var repositor: Repositor
@export var jugador: JugadorDelLocal
@export var estante: Node3D
@export var contenido: Node3D

## De dónde cuelga la caja mientras se la lleva: un punto del CUERPO y no de la cámara, porque
## pegada al pitch tapa la mira. Lo mueve este puesto y no `Agarre`, que no puede nombrarla.
@export var punto_de_la_caja: Node3D
@export var apoyos: Array[Vector3] = []
@export var direcciones: Array[Vector3] = []
@export var giros_del_frente: Array[float] = []

var _unidades: Array[Node3D] = []
var _zonas: Array[StaticBody3D] = []
var _modelos: Array[Mesh] = []
var _formas: Array[ConvexPolygonShape3D] = []
var _grupos: Array[MultiMeshInstance3D] = []
var _sueltos: Array[GrupoDelPiso] = []
var _disponible: ObjetoAgarrable = null


func preparar() -> void:
	_preparar_modelos()
	_preparar_grupos()
	estante.remove_from_group(ReglasDelJugador.GRUPO_INTERACTUABLE)
	for producto in Catalogo.todos():
		var casillero := ZonaDeReposicion.new()
		casillero.name = "ZonaDe" + producto.nombre
		casillero.producto = producto.id
		casillero.collision_layer = 0
		casillero.collision_mask = 0
		casillero.add_to_group(ReglasDelJugador.GRUPO_INTERACTUABLE)
		add_child(casillero)
		var limites := zona(producto.id)
		casillero.global_position = limites.get_center()
		var cuerpo := CollisionShape3D.new()
		var forma := BoxShape3D.new()
		forma.size = limites.size
		cuerpo.shape = forma
		casillero.add_child(cuerpo)
		var vista := MeshInstance3D.new()
		var malla := QuadMesh.new()
		var tamano := _modelos[producto.id].get_aabb().size
		malla.size = Vector2(tamano.x, tamano.z) + Vector2.ONE * 0.02
		vista.position.y = -0.15 + 0.005
		vista.rotation.x = -PI / 2
		var material := StandardMaterial3D.new()
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color = Color(0, 0, 0, 0)
		malla.material = material
		vista.mesh = malla
		casillero.add_child(vista)
		casillero.mallas = [vista]
		var borde := ShaderMaterial.new()
		borde.shader = BORDE
		borde.set_shader_parameter("color", IndicacionDelFoco.COLOR)
		borde.set_shader_parameter("tamano", malla.size)
		casillero.material_de_foco = borde
		casillero.colocacion_pedida.connect(pedir_colocar)
		_zonas.append(casillero)
	jugador.uso_pedido.connect(retirar_de_la_caja)
	repositor.agarre.objeto_agarrado.connect(_actualizar_zonas)
	repositor.agarre.objeto_soltado.connect(_actualizar_zonas)
	repositor.agarre.objeto_soltado.connect(_agrupar_suelto)
	repositor.agarre.objeto_agarrado.connect(_retirar_del_grupo)
	repositor.agarre.objeto_soltado.connect(_apoyar_la_caja)
	repositor.agarre.objeto_agarrado.connect(_colgar_la_caja)
	_actualizar_zonas()


func _agrupar_suelto(nodo: Node3D) -> void:
	if nodo is ObjetoAgarrable and nodo.datos is UnidadDeProducto:
		_sueltos[nodo.datos.producto.id].agregar(nodo)


func _retirar_del_grupo(nodo: Node3D) -> void:
	if nodo is ObjetoAgarrable and nodo.datos is UnidadDeProducto:
		_sueltos[nodo.datos.producto.id].quitar(nodo)


## Saca una unidad de la caja apuntada, y sólo con la caja apoyada en el suelo.
##
## El clic derecho llega por `uso_pedido`, que se reparte entre los puestos: acá se descarta lo
## que no es una caja. Desde qué altura entrega lo decide `ReglasDeLosObjetos`, donde tiene test.
func retirar_de_la_caja(objetivo: Node3D) -> void:
	var caja := objetivo as CajaDelDeposito
	if caja == null or not ReglasDeLosObjetos.se_puede_retirar(caja.global_position.y):
		return
	retirar(caja.producto)


## Baja a la cintura la caja recién levantada y le da su volumen al cuerpo del jugador.
func _colgar_la_caja(nodo: Node3D) -> void:
	if nodo is CajaDelDeposito and punto_de_la_caja != null:
		repositor.agarre.mover_lo_sostenido(punto_de_la_caja)
		jugador.ocupar_el_frente(true)


## Apoya la caja recién soltada donde el jugador tiene la mira, derecha y de una.
##
## El cuerpo es estático, así que el motor no la mueve solo. El `top_level` vuelve a `false`,
## que es lo que soltar deja en `true`.
func _apoyar_la_caja(nodo: Node3D) -> void:
	var caja := nodo as CajaDelDeposito
	if caja == null:
		return
	jugador.ocupar_el_frente(false)
	caja.top_level = false
	caja.global_basis = Basis.IDENTITY
	caja.global_position = _llevar_hasta(caja, _lugar_apuntado(caja))
	var apoyo := _bajar_hasta_el_apoyo(caja)
	if apoyo != null:
		_acomodar_sobre(caja, apoyo)
		_bajar_hasta_el_apoyo(caja)
	if _le_queda_encima_al_jugador(caja):
		repositor.agarre.pedir_agarrar(caja.datos, caja)


## Si la caja terminó adentro del cuerpo del jugador es que ahí no hay lugar para apoyarla, y
## dejarla igual lo sube arriba de ella. Entonces no se suelta: se la vuelve a la mano.
func _le_queda_encima_al_jugador(caja: CajaDelDeposito) -> bool:
	var forma: CollisionShape3D = caja.get_node("Cuerpo")
	var consulta := PhysicsShapeQueryParameters3D.new()
	consulta.shape = forma.shape
	consulta.transform = forma.global_transform
	consulta.exclude = [caja.get_rid()]
	for choque in get_world_3d().direct_space_state.intersect_shape(consulta, 8):
		if choque["collider"] == jugador:
			return true
	return false


## Dónde iría el centro de la caja según lo que el jugador tiene en la mira: encima de una
## superficie horizontal, y delante de cualquier otra cosa.
func _lugar_apuntado(caja: CajaDelDeposito) -> Vector3:
	var ojo := jugador.mira()
	var lejos := ojo.origin - ojo.basis.z * ReglasDelJugador.ALCANCE_DE_LA_MIRA
	var consulta := PhysicsRayQueryParameters3D.create(ojo.origin, lejos)
	consulta.exclude = [caja.get_rid(), jugador.get_rid()]
	var golpe := get_world_3d().direct_space_state.intersect_ray(consulta)
	if golpe.is_empty():
		return lejos
	var media := _media_caja(caja)
	var punto: Vector3 = golpe["position"]
	if ReglasDeLosObjetos.se_puede_apoyar_en((golpe["normal"] as Vector3).y):
		return punto + Vector3.UP * media.y
	return punto + (ojo.origin - punto).normalized() * media.length()


## Hasta dónde llega la caja yendo de la mano al destino: primero sube, después entra.
##
## Derecho no alcanza: el labio de un estante queda justo a la altura a la que se la lleva, así
## que el camino recto choca contra él y la caja nunca entra. Una persona la sube y la mete.
func _llevar_hasta(caja: CajaDelDeposito, destino: Vector3) -> Vector3:
	var mano := punto_de_la_caja.global_position
	var media := _media_caja(caja)
	var arriba := _barrer(caja, mano, Vector3(mano.x, destino.y + media.y, mano.z))
	return _barrer(caja, arriba, Vector3(destino.x, arriba.y, destino.z))


## El punto más cercano a `hasta` al que la caja llega sin meterse adentro de nada.
func _barrer(caja: CajaDelDeposito, desde: Vector3, hasta: Vector3) -> Vector3:
	var forma: CollisionShape3D = caja.get_node("Cuerpo")
	var consulta := PhysicsShapeQueryParameters3D.new()
	consulta.shape = forma.shape
	consulta.transform = Transform3D(Basis.IDENTITY.scaled(forma.scale), desde)
	consulta.motion = hasta - desde
	consulta.exclude = [caja.get_rid(), jugador.get_rid()]
	var avance: float = get_world_3d().direct_space_state.cast_motion(consulta)[0]
	return desde + consulta.motion * avance


## Apoya la caja sobre lo que haya debajo de su CENTRO y devuelve qué es, o `null` si no hay nada.
##
## El centro y no la forma entera: un barrido de la caja la deja enganchada del borde de un
## estante, en el aire y sin caerse.
func _bajar_hasta_el_apoyo(caja: CajaDelDeposito) -> CollisionObject3D:
	var consulta := PhysicsRayQueryParameters3D.create(
		caja.global_position, caja.global_position + Vector3.DOWN * CAIDA_MAXIMA
	)
	consulta.exclude = [caja.get_rid(), jugador.get_rid()]
	var golpe := get_world_3d().direct_space_state.intersect_ray(consulta)
	if golpe.is_empty():
		return null
	var abajo := caja.global_position
	abajo.y = (golpe["position"] as Vector3).y + _media_caja(caja).y
	caja.global_position = _barrer(caja, caja.global_position, abajo)
	return golpe["collider"] as CollisionObject3D


## Corre la caja para que quede entera sobre su apoyo — centrada, si el apoyo es de su tamaño.
##
## Es lo que la deja puesta como estaba al abrir la noche: derecha y adentro del estante, en vez
## de colgando de un borde. Sobre otra caja, que mide lo mismo, el margen se invierte y las dos
## cuentas dan el medio del apoyo, que es justo donde va.
func _acomodar_sobre(caja: CajaDelDeposito, apoyo: CollisionObject3D) -> void:
	var limites := _limites_de(apoyo)
	var media := _media_caja(caja)
	var lugar := caja.global_position
	lugar.x = _adentro(lugar.x, limites.position.x + media.x, limites.end.x - media.x)
	lugar.z = _adentro(lugar.z, limites.position.z + media.z, limites.end.z - media.z)
	# Barrido y no salto: los límites son los del apoyo entero, parantes incluidos, así que
	# acomodar a ciegas mete la caja adentro de uno.
	caja.global_position = _barrer(caja, caja.global_position, lugar)


## Lo que ocupa un cuerpo, en coordenadas del mundo.
func _limites_de(cuerpo: CollisionObject3D) -> AABB:
	var limites := AABB(cuerpo.global_position, Vector3.ZERO)
	for forma: CollisionShape3D in cuerpo.find_children("*", "CollisionShape3D", true, false):
		limites = limites.merge(forma.global_transform * forma.shape.get_debug_mesh().get_aabb())
	return limites


## El valor adentro del rango, o su medio cuando el rango viene dado vuelta.
static func _adentro(valor: float, desde: float, hasta: float) -> float:
	if desde > hasta:
		return (desde + hasta) / 2.0
	return clampf(valor, desde, hasta)


func _media_caja(caja: CajaDelDeposito) -> Vector3:
	var forma: CollisionShape3D = caja.get_node("Cuerpo")
	return (forma.shape as BoxShape3D).size * forma.scale / 2.0


func pedir_colocar(id: Producto.Id) -> void:
	repositor.pedir_colocar_de_la_mano(Catalogo.de(id))
	_actualizar_zonas()


func _actualizar_zonas(_nodo: Node3D = null) -> void:
	var unidad := repositor.agarre.manos().sostenido() as UnidadDeProducto
	for casillero in _zonas:
		var activo: bool = unidad != null and unidad.producto.id == casillero.producto
		casillero.collision_layer = 2 if activo else 0
		casillero.visible = activo
		casillero.global_position = _apoyo(casillero.producto) + Vector3.UP * 0.15


## La tolerancia permite apuntar al entorno del producto, no a un píxel.
func zona(id: Producto.Id) -> AABB:
	var tamano := _modelos[id].get_aabb().size
	tamano.y = 0.3
	return AABB(_apoyo(id) - Vector3(tamano.x / 2, 0, tamano.z / 2), tamano).grow(0.25)


func _apoyo(id: Producto.Id) -> Vector3:
	var cantidad := repositor.estante().unidades_en_gondola(Catalogo.de(id))
	return _posicion(id, cantidad)


func _posicion(id: Producto.Id, indice: int) -> Vector3:
	var base := to_global(apoyos[id])
	var direccion := direcciones[id]
	var separacion := _modelos[id].get_aabb().size.dot(direccion.abs()) + 0.03
	return base + direccion * separacion * indice


func _preparar_modelos() -> void:
	for grupo: MeshInstance3D in contenido.get_children():
		var herramienta := SurfaceTool.new()
		herramienta.append_from(grupo.mesh, 0, Transform3D(grupo.global_basis, Vector3.ZERO))
		herramienta.set_material(grupo.mesh.surface_get_material(0))
		_modelos.append(herramienta.commit())
	_modelos[Producto.Id.ACTRONCITO] = preload("res://assets/models/producto_actroncito.res")
	var nuevos := PRODUCTOS_NUEVOS.instantiate()
	_modelos.append(nuevos.get_node("Marolini").mesh)
	_modelos.append(nuevos.get_node("Jorgillo").mesh)
	nuevos.free()
	for modelo in _modelos:
		var forma := ConvexPolygonShape3D.new()
		var puntos := modelo.get_faces()
		var centro := modelo.get_aabb().get_center()
		for indice in puntos.size():
			puntos[indice] -= centro
		forma.points = puntos
		_formas.append(forma)


func _preparar_grupos() -> void:
	for producto in Catalogo.todos():
		var grupo := MultiMeshInstance3D.new()
		grupo.name = "ProductosDe" + producto.nombre
		var malla := _modelos[producto.id]
		var limites := malla.get_aabb()
		var copias := MultiMesh.new()
		copias.transform_format = MultiMesh.TRANSFORM_3D
		copias.mesh = malla
		copias.instance_count = repositor.estante().cupo(producto)
		copias.visible_instance_count = 0
		var posiciones := PackedFloat32Array()
		for indice in copias.instance_count:
			var apoyo := _posicion(producto.id, indice) + Vector3.UP * limites.size.y / 2
			var posicion := to_local(apoyo) - limites.get_center()
			# MultiMesh recibe tres filas de cuatro valores por transformación.
			posiciones.append_array([1, 0, 0, posicion.x, 0, 1, 0, posicion.y, 0, 0, 1, posicion.z])
		copias.buffer = posiciones
		grupo.multimesh = copias
		add_child(grupo)
		_grupos.append(grupo)
		var sueltos := GrupoDelPiso.new()
		sueltos.name = "SueltosDe" + producto.nombre
		sueltos.preparar(malla, repositor.estante().cupo(producto))
		add_child(sueltos)
		_sueltos.append(sueltos)


func retirar(id: Producto.Id) -> void:
	var unidad := _disponible
	_disponible = null
	if unidad == null:
		unidad = OBJETO.instantiate()
		add_child(unidad)
		_unidades.append(unidad)
		unidad.add_collision_exception_with(jugador)
		# Las bolsas delgadas necesitan detectar el impacto entre pasos de física.
		unidad.continuous_cd = true
	# El frente de cada modelo se alinea antes de darle la inclinación de la mano.
	unidad.orientacion_en_mano = (
		Basis.from_euler(Vector3(deg_to_rad(-17), deg_to_rad(-20), 0))
		* Basis(Vector3.UP, deg_to_rad(giros_del_frente[id]))
	)
	unidad.collision_layer = 1
	unidad.collision_mask = 1
	if not repositor.pedir_retirar(id, unidad):
		_guardar_cuerpo(unidad)
		return
	unidad.show()
	var malla := _modelos[id]
	var limites := malla.get_aabb()
	var vista: MeshInstance3D = unidad.get_node("Malla")
	vista.mesh = malla
	vista.position = -limites.get_center()
	unidad.get_node("Forma").shape = _formas[id]


func depositar(unidad: Node3D, producto: Producto, unidades: int) -> void:
	_grupos[producto.id].multimesh.visible_instance_count = unidades
	_guardar_cuerpo(unidad)


func _guardar_cuerpo(unidad: ObjetoAgarrable) -> void:
	unidad.hide()
	unidad.reparent(self)
	unidad.freeze = true
	unidad.collision_layer = 0
	unidad.collision_mask = 0
	unidad.linear_velocity = Vector3.ZERO
	unidad.angular_velocity = Vector3.ZERO
	unidad.datos = null
	if _disponible != null:
		_unidades.erase(unidad)
		unidad.queue_free()
	else:
		_disponible = unidad


## Deja el dibujo de la góndola en las unidades que el inventario dice que quedan.
##
## Vender no pasa por acá: descuenta en `Inventario`, y sin este repintado la góndola seguiría
## mostrando lo que ya no está. Se redibuja el catálogo entero y no sólo lo vendido porque la
## atención despacha varios productos de una y el despachado no dice cuáles.
##
## **Baja `visible_instance_count` en vez de borrar copias**, y es lo que lo deja de acuerdo con
## `_apoyo()`: la próxima unidad se coloca en el índice que devuelve `unidades_en_gondola`, o sea
## justo la primera copia que este método acaba de ocultar. Borrar copias correría los índices y
## la unidad repuesta caería sobre una que ya se ve.
func actualizar_stock(_despachados: int) -> void:
	for producto in Catalogo.todos():
		var copias := _grupos[producto.id].multimesh
		copias.visible_instance_count = repositor.estante().unidades_en_gondola(producto)
	_actualizar_zonas()


func limpiar() -> void:
	for grupo in _sueltos:
		while not grupo.cuerpos.is_empty():
			grupo.quitar(grupo.cuerpos[-1])
	for unidad in _unidades:
		if is_instance_valid(unidad):
			unidad.queue_free()
	_unidades.clear()
	_disponible = null
	for grupo in _grupos:
		grupo.multimesh.visible_instance_count = 0
	_actualizar_zonas()
