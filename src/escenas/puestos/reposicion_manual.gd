## Presenta la unidad que el repositor entrega y conserva su cuerpo al depositarla.
extends Node3D

const ZonaDeReposicion := preload("res://src/escenas/puestos/zona_de_reposicion.gd")
const OBJETO := preload("res://src/escenas/objetos/objeto_agarrable.tscn")
const BORDE := preload("res://src/escenas/puestos/borde_de_reposicion.gdshader")
const PRODUCTOS_NUEVOS := preload("res://assets/models/productos_marolini_jorgillo.glb")

@export var repositor: Repositor
@export var estante: Node3D
@export var contenido: Node3D
@export var apoyos: Array[Vector3] = []
@export var direcciones: Array[Vector3] = []
@export var giros_del_frente: Array[float] = []

var _unidades: Array[Node3D] = []
var _zonas: Array[StaticBody3D] = []
var _modelos: Array[Mesh] = []


func preparar() -> void:
	_preparar_modelos()
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
	repositor.agarre.objeto_agarrado.connect(_actualizar_zonas)
	repositor.agarre.objeto_soltado.connect(_actualizar_zonas)
	_actualizar_zonas()


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


func retirar(id: Producto.Id) -> void:
	var unidad: ObjetoAgarrable = OBJETO.instantiate()
	# El frente de cada modelo se alinea antes de darle la inclinación de la mano.
	unidad.orientacion_en_mano = (
		Basis.from_euler(Vector3(deg_to_rad(-17), deg_to_rad(-20), 0))
		* Basis(Vector3.UP, deg_to_rad(giros_del_frente[id]))
	)
	add_child(unidad)
	if not repositor.pedir_retirar(id, unidad):
		unidad.free()
		return
	_unidades.append(unidad)
	var malla := _modelos[id]
	var limites := malla.get_aabb()
	var vista: MeshInstance3D = unidad.get_node("Malla")
	vista.mesh = malla
	vista.position = -limites.get_center()
	var forma := BoxShape3D.new()
	forma.size = limites.size
	unidad.get_node("Forma").shape = forma


func depositar(unidad: Node3D, producto: Producto, unidades: int) -> void:
	var forma: BoxShape3D = unidad.get_node("Forma").shape
	var posicion := _posicion(producto.id, unidades - 1) + Vector3.UP * forma.size.y / 2
	unidad.reparent(estante)
	unidad.global_transform = Transform3D(Basis.IDENTITY, posicion)
	unidad.remove_from_group(ReglasDelJugador.GRUPO_INTERACTUABLE)


func actualizar_stock(_despachados: int) -> void:
	var visibles: Dictionary[int, int] = {}
	for nodo in estante.get_children():
		if not nodo is ObjetoAgarrable or not nodo.datos is UnidadDeProducto:
			continue
		var producto: Producto = nodo.datos.producto
		var cantidad: int = visibles.get(producto.id, 0)
		if cantidad < repositor.estante().unidades_en_gondola(producto):
			visibles[producto.id] = cantidad + 1
		else:
			_unidades.erase(nodo)
			estante.remove_child(nodo)
			nodo.queue_free()
	_actualizar_zonas()


func limpiar() -> void:
	for unidad in _unidades:
		if is_instance_valid(unidad):
			unidad.queue_free()
	_unidades.clear()
	_actualizar_zonas()
