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
const CONTORNO := preload("res://src/sistemas/marco/contorno.gdshader")

var _pendientes: Array[GeometryInstance3D] = []
var _sin_focos: Array[GeometryInstance3D] = []
var _con_area: Array[GeometryInstance3D] = []
var _objetos: Array[GeometryInstance3D] = []
var _focos: Array[SpotLight3D] = []
var _area: AreaLight3D
var _alcance_area := 0.0
var _alcance_ampliado := 0.0
## Lo que estaba oculto también se dibuja, porque aparece después en medio del juego. Al terminar
## vuelve a quedar oculto.
var _ocultos: Array[GeometryInstance3D] = []
var _vistos: Dictionary = {}
var _total := 0
var _camara: Camera3D
var _anterior: Camera3D
var _contornos_listos := false
var _pases_originales: Dictionary[Material, Material] = {}
var _parametros_originales: Dictionary[ShaderMaterial, Dictionary] = {}
var _muestras: Array[MultiMeshInstance3D] = []


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


## Acá y no en `_init()`: al entrar al árbol, el motor prende el `_process` de quien lo define.
func _ready() -> void:
	set_process(false)


func calentar(escena: Node3D) -> void:
	var caja := AABB()
	var objetos := escena.find_children("*", "GeometryInstance3D", true, false)
	objetos.append_array(_muestras_con_omni(escena))
	for foco: SpotLight3D in escena.find_children("*", "SpotLight3D", true, false):
		if foco.visible:
			_focos.append(foco)
	if not _focos.is_empty():
		for area: AreaLight3D in escena.find_children("*", "AreaLight3D", true, false):
			if area.visible:
				_area = area
				_alcance_area = area.area_range
				break
	for objeto: GeometryInstance3D in objetos:
		# El modelo de referencia queda en el GLB para editarlo, pero tiene un reemplazo en
		# producción. Dibujarlo acá compilaría variantes que nunca aparecen en la partida.
		if objeto.is_in_group(&"geometria_de_referencia"):
			continue
		var suya := objeto.global_transform * objeto.get_aabb()
		caja = suya if _pendientes.is_empty() else caja.merge(suya)
		if not objeto.visible:
			_ocultos.append(objeto)
		objeto.visible = false
		_pendientes.append(objeto)
		_objetos.append(objeto)
		if not _focos.is_empty() and objeto.gi_mode == GeometryInstance3D.GI_MODE_DYNAMIC:
			_sin_focos.append(objeto)
			if _area != null:
				_con_area.append(objeto)
	if _area != null:
		_alcance_ampliado = maxf(
			_alcance_area, caja.size.length() + caja.get_center().distance_to(_area.global_position)
		)
	_total = _pendientes.size() + _sin_focos.size() + _con_area.size()
	_anterior = get_viewport().get_camera_3d()
	_camara = Camera3D.new()
	add_child(_camara)
	_encuadrar(caja)
	_camara.make_current()
	# Los objetos preparan sus materiales por llamada diferida al entrar al árbol.
	# La nuestra entra después: sus contornos deben existir antes del primer dibujo.
	_preparar_contornos.call_deferred()
	set_process(true)


## Un lote oculto conserva una instancia para calentarse en su lugar de origen. Al llevarlo
## hasta una heladera recibe una luz omni que allí no lo alcanza: hace falta ese mismo material
## instanciado, sin modificar posiciones ni buffers de la simulación.
func _muestras_con_omni(escena: Node3D) -> Array[MultiMeshInstance3D]:
	var omni: OmniLight3D = null
	for luz: OmniLight3D in escena.find_children("*", "OmniLight3D", true, false):
		if luz.is_visible_in_tree() and luz.omni_range > 0.0:
			omni = luz
			break
	if omni == null:
		return []
	for objeto: MultiMeshInstance3D in escena.find_children(
		"*", "MultiMeshInstance3D", true, false
	):
		if (
			objeto.visible
			or objeto.gi_mode != GeometryInstance3D.GI_MODE_DYNAMIC
			or objeto.material_override == null
			or objeto.multimesh == null
			or objeto.multimesh.mesh == null
			or objeto.multimesh.instance_count == 0
		):
			continue
		var muestra := MultiMeshInstance3D.new()
		muestra.gi_mode = objeto.gi_mode
		muestra.cast_shadow = objeto.cast_shadow
		muestra.layers = objeto.layers
		muestra.material_override = objeto.material_override
		muestra.material_overlay = objeto.material_overlay
		var lote := MultiMesh.new()
		lote.transform_format = objeto.multimesh.transform_format
		lote.use_colors = objeto.multimesh.use_colors
		lote.use_custom_data = objeto.multimesh.use_custom_data
		lote.mesh = objeto.multimesh.mesh
		lote.instance_count = 1
		lote.visible_instance_count = 1
		lote.set_instance_transform(0, Transform3D.IDENTITY)
		if lote.use_colors:
			lote.set_instance_color(0, objeto.multimesh.get_instance_color(0))
		if lote.use_custom_data:
			lote.set_instance_custom_data(0, objeto.multimesh.get_instance_custom_data(0))
		muestra.multimesh = lote
		add_child(muestra)
		muestra.global_position = omni.global_position
		_muestras.append(muestra)
	return _muestras


func progreso() -> float:
	return 1.0 - float(_pendientes.size() + _sin_focos.size() + _con_area.size()) / maxi(_total, 1)


## Cada cuadro destapa objetos hasta el primero que trae un material sin dibujar: el costo está
## en el material nuevo, no en la cantidad de objetos. Termina un cuadro después del último, que
## es el cuadro en que se dibuja.
func _process(_delta: float) -> void:
	if not _contornos_listos:
		return
	if _pendientes.is_empty():
		if _sin_focos.is_empty() and _con_area.is_empty():
			_terminar()
			return
		# Al salir del baño, un útil puede recibir sus focos y las luces de área del local,
		# o sólo las del local. El material necesita ambas variantes antes del primer uso.
		for objeto: GeometryInstance3D in _objetos:
			objeto.visible = false
		if not _con_area.is_empty():
			_area.area_range = _alcance_ampliado
			_pendientes.assign(_con_area)
			_con_area.clear()
		else:
			for foco: SpotLight3D in _focos:
				foco.visible = false
			_pendientes.assign(_sin_focos)
			_sin_focos.clear()
		_vistos.clear()
	var nuevo := false
	while not nuevo and not _pendientes.is_empty():
		var objeto: GeometryInstance3D = _pendientes.pop_back()
		objeto.visible = true
		for material: Variant in _materiales_de(objeto):
			nuevo = nuevo or not _vistos.has(material)
			_vistos[material] = true
	avanzo.emit(progreso())


func _preparar_contornos() -> void:
	var indicacion := ShaderMaterial.new()
	indicacion.shader = CONTORNO
	indicacion.set_shader_parameter("grosor", 0.0)
	indicacion.set_shader_parameter("color", Color.WHITE)
	for objeto: GeometryInstance3D in _objetos:
		if not objeto.has_method("mostrar_contorno"):
			continue
		for material: Variant in _materiales_de(objeto):
			if material is Material:
				_guardar_pases(material as Material)
		# El protocolo lo declara el objeto; el sistema no conoce su clase ni su escena.
		objeto.call("mostrar_contorno", indicacion)
	_contornos_listos = true


func _guardar_pases(material: Material) -> void:
	if _pases_originales.has(material):
		return
	_pases_originales[material] = material.next_pass
	var pase := material.next_pass
	while pase != null:
		var sombreado := pase as ShaderMaterial
		if sombreado != null and not _parametros_originales.has(sombreado):
			var shader := sombreado.shader
			var parametros: Dictionary = {}
			if shader != null:
				for uniforme: Dictionary in shader.get_shader_uniform_list():
					var nombre := StringName(uniforme["name"])
					parametros[nombre] = sombreado.get_shader_parameter(nombre)
			_parametros_originales[sombreado] = parametros
		pase = pase.next_pass


func _restaurar_pases() -> void:
	for material: Material in _pases_originales:
		material.next_pass = _pases_originales[material]
	for pase: ShaderMaterial in _parametros_originales:
		for nombre: StringName in _parametros_originales[pase]:
			pase.set_shader_parameter(nombre, _parametros_originales[pase][nombre])
	_pases_originales.clear()
	_parametros_originales.clear()


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
	_restaurar_escena()
	terminado.emit()


func _exit_tree() -> void:
	if _camara != null:
		_restaurar_escena()


func _restaurar_escena() -> void:
	_restaurar_pases()
	if is_instance_valid(_area):
		_area.area_range = _alcance_area
	for foco: SpotLight3D in _focos:
		if is_instance_valid(foco):
			foco.visible = true
	for objeto: GeometryInstance3D in _objetos:
		if is_instance_valid(objeto):
			objeto.visible = not _ocultos.has(objeto)
	for muestra in _muestras:
		muestra.hide()
		muestra.queue_free()
	_muestras.clear()
	if is_instance_valid(_camara):
		_camara.queue_free()
	_camara = null
	if is_instance_valid(_anterior) and _anterior.is_inside_tree():
		_anterior.make_current()
