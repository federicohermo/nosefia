## Presenta la unidad que el repositor entrega y conserva su cuerpo al depositarla.
extends Node3D

const ZonaDeReposicion := preload("res://src/escenas/puestos/zona_de_reposicion.gd")
const OBJETO := preload("res://src/escenas/objetos/objeto_agarrable.tscn")
const BORDE := preload("res://src/escenas/puestos/borde_de_reposicion.gdshader")

@export var repositor: Repositor
@export var estante: Node3D
@export var contenido: Node3D
@export var apoyos: Array[Vector3] = []

var _unidades: Array[Node3D] = []
var _zonas: Array[StaticBody3D] = []


func preparar() -> void:
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
		malla.size = Vector2(0.24, 0.24)
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
	return AABB(_apoyo(id) - Vector3(0.12, 0, 0.12), Vector3(0.24, 0.3, 0.24)).grow(0.35)


func _apoyo(id: Producto.Id) -> Vector3:
	var cantidad := repositor.estante().unidades_en_gondola(Catalogo.de(id))
	return _posicion(id, cantidad)


func _posicion(id: Producto.Id, indice: int) -> Vector3:
	var base := to_global(apoyos[id])
	var hacia_centro := estante.global_position - base
	var direccion := Vector3.RIGHT if absf(hacia_centro.z) > 3 else Vector3.BACK
	return base + direccion * signf(hacia_centro.dot(direccion)) * 0.24 * indice


func retirar(id: Producto.Id) -> void:
	var unidad: ObjetoAgarrable = OBJETO.instantiate()
	add_child(unidad)
	if not repositor.pedir_retirar(id, unidad):
		unidad.free()
		return
	_unidades.append(unidad)
	var grupo: MeshInstance3D = contenido.get_child(id)
	var herramienta := SurfaceTool.new()
	herramienta.append_from(grupo.mesh, 0, Transform3D(grupo.global_basis, Vector3.ZERO))
	herramienta.set_material(grupo.mesh.surface_get_material(0))
	var malla := herramienta.commit()
	if id == Producto.Id.YERBA:
		malla = preload("res://assets/models/producto_lata.res")
	var limites := malla.get_aabb()
	var tamano := limites.size
	var escala := tamano / limites.size * (0.22 / tamano[tamano.max_axis_index()])
	var vista: MeshInstance3D = unidad.get_node("Malla")
	vista.mesh = malla
	vista.scale = escala
	vista.position = -limites.get_center() * escala
	var forma := BoxShape3D.new()
	forma.size = limites.size * escala
	unidad.get_node("Forma").shape = forma
	unidad.rotation.x = -0.3


func depositar(unidad: Node3D, producto: Producto, unidades: int) -> void:
	var forma: BoxShape3D = unidad.get_node("Forma").shape
	var posicion := _posicion(producto.id, unidades - 1) + Vector3.UP * forma.size.y / 2
	unidad.reparent(estante)
	unidad.global_transform = Transform3D(Basis.IDENTITY, posicion)
	unidad.remove_from_group(ReglasDelJugador.GRUPO_INTERACTUABLE)


func limpiar() -> void:
	for unidad in _unidades:
		if is_instance_valid(unidad):
			unidad.queue_free()
	_unidades.clear()
	_actualizar_zonas()
