## Dibuja una vez cada objeto de una escena, con una cámara que la abarca entera, antes de que el
## jugador la vea.
##
## Compatibility no precompila shaders: cada variante se compila la primera vez que se dibuja, y
## en la web cada una frena el navegador alrededor de un segundo. Dibujarlas detrás de la pantalla
## de carga las saca del medio del juego. La cámara propia está para que entren todos los objetos,
## y con ellos todas las luces: la variante depende de las luces que tocan al objeto.
class_name CalentamientoDeShaders
extends Node

signal avanzo(progreso: float)
signal terminado

## Cuánto más arriba del techo va la cámara, para que el techo entre en el cuadro.
const ALTURA_EXTRA := 10.0

var _pendientes: Array[GeometryInstance3D] = []
## Lo que estaba oculto también se dibuja, porque aparece después en medio del juego. Al terminar
## vuelve a quedar oculto.
var _ocultos: Array[GeometryInstance3D] = []
var _vistos: Dictionary = {}
var _total := 0
var _camara: Camera3D
var _anterior: Camera3D


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


## Acá y no en `_init()`: al entrar al árbol, el motor prende el `_process` de quien lo define.
func _ready() -> void:
	set_process(false)


func calentar(escena: Node3D) -> void:
	var caja := AABB()
	for objeto: GeometryInstance3D in escena.find_children("*", "GeometryInstance3D", true, false):
		var suya := objeto.global_transform * objeto.get_aabb()
		caja = suya if _pendientes.is_empty() else caja.merge(suya)
		if not objeto.visible:
			_ocultos.append(objeto)
		objeto.visible = false
		_pendientes.append(objeto)
	_total = _pendientes.size()
	_anterior = get_viewport().get_camera_3d()
	_camara = Camera3D.new()
	add_child(_camara)
	_encuadrar(caja)
	_camara.make_current()
	set_process(true)


func progreso() -> float:
	return 1.0 - float(_pendientes.size()) / maxi(_total, 1)


## Cada cuadro destapa objetos hasta el primero que trae un material sin dibujar: el costo está
## en el material nuevo, no en la cantidad de objetos. Termina un cuadro después del último, que
## es el cuadro en que se dibuja.
func _process(_delta: float) -> void:
	if _pendientes.is_empty():
		_terminar()
		return
	var nuevo := false
	while not nuevo and not _pendientes.is_empty():
		var objeto: GeometryInstance3D = _pendientes.pop_back()
		objeto.visible = true
		for material: Variant in _materiales_de(objeto):
			nuevo = nuevo or not _vistos.has(material)
			_vistos[material] = true
	avanzo.emit(progreso())


## La clase entra como un material más: un `Label3D` o un `Sprite3D` traen el suyo adentro.
func _materiales_de(objeto: GeometryInstance3D) -> Array:
	var materiales: Array = [objeto.get_class(), objeto.material_override, objeto.material_overlay]
	var malla: Mesh = null
	if objeto is MeshInstance3D:
		malla = (objeto as MeshInstance3D).mesh
	elif objeto is MultiMeshInstance3D and (objeto as MultiMeshInstance3D).multimesh != null:
		malla = (objeto as MultiMeshInstance3D).multimesh.mesh
	if malla != null:
		for superficie: int in malla.get_surface_count():
			# Las fibras reemplazan el material por superficie sin cambiar la malla del modelo.
			if objeto is MeshInstance3D:
				materiales.append((objeto as MeshInstance3D).get_active_material(superficie))
			else:
				materiales.append(malla.surface_get_material(superficie))
	return materiales.filter(func(material: Variant) -> bool: return material != null)


## Desde arriba y ortogonal: así entra la escena entera, sin importar su forma.
func _encuadrar(caja: AABB) -> void:
	_camara.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camara.size = maxf(caja.size.x, caja.size.z)
	_camara.far = caja.size.y + 2.0 * ALTURA_EXTRA
	_camara.position = caja.get_center() + Vector3.UP * (caja.size.y / 2.0 + ALTURA_EXTRA)
	_camara.rotation = Vector3(-PI / 2.0, 0.0, 0.0)


func _terminar() -> void:
	set_process(false)
	for objeto: GeometryInstance3D in _ocultos:
		objeto.visible = false
	_camara.queue_free()
	if _anterior != null:
		_anterior.make_current()
	terminado.emit()
