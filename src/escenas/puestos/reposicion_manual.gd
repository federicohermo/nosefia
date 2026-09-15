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


## Baja a la cintura la caja recién levantada.
func _colgar_la_caja(nodo: Node3D) -> void:
	if nodo is CajaDelDeposito and punto_de_la_caja != null:
		repositor.agarre.mover_lo_sostenido(punto_de_la_caja)


## Deja apoyada en el piso la caja recién soltada, derecha y de una.
##
## El cuerpo es estático, así que el motor no la baja solo: se la baja con un barrido de su
## propia forma. El `top_level` vuelve a `false`, que es lo que soltar deja en `true`.
func _apoyar_la_caja(nodo: Node3D) -> void:
	var caja := nodo as CajaDelDeposito
	if caja == null:
		return
	caja.top_level = false
	caja.global_basis = Basis.IDENTITY
	var forma: CollisionShape3D = caja.get_node("Cuerpo")
	var consulta := PhysicsShapeQueryParameters3D.new()
	consulta.shape = forma.shape
	consulta.transform = forma.global_transform
	consulta.motion = Vector3.DOWN * CAIDA_MAXIMA
	consulta.collision_mask = caja.collision_mask
	consulta.exclude = [caja.get_rid(), jugador.get_rid()]
	# El segundo valor es el contacto y el primero se queda un margen antes: una caja tiene
	# que quedar tocando el piso, no flotando un centímetro sobre él.
	var libre: float = get_world_3d().direct_space_state.cast_motion(consulta)[1]
	caja.global_position += consulta.motion * libre


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
