## El agua del lavatorio y del inodoro, que se mueve sola. Es decorado: no expone nada al juego.
##
## Cada superficie simula sus ondas en la GPU, con dos `SubViewport` que se leen uno al otro. La
## CPU no lee el agua nunca: en la web, `get_image()` devuelve 8 bits.
extends Node3D

const ONDAS := preload("res://src/escenas/puestos/agua_del_bano_ondas.gdshader")

## La simulación avanza a paso fijo. Atada al cuadro, la onda correría el doble de rápido a 144
## que a 60 cuadros por segundo.
const PASO := 1.0 / 60.0
## El esquema de la onda avanza unos 0,7 texeles por paso: con 192 por metro, 22 cm por segundo.
const TEXELES_POR_METRO := 192.0
const SEGUNDOS_ENTRE_GOTAS := Vector2(2.5, 5.0)
const SEGUNDOS_ENTRE_ONDAS_DEL_INODORO := Vector2(6.0, 15.0)
const FUERZA_DE_LA_GOTA := 0.4
const FUERZA_DE_LA_ONDA_DEL_INODORO := 0.25

## El contorno de cada agua sale del modelo: es el corte de la bacha y de la taza a la altura
## del agua, en el plano XZ de su nodo.
@export var lavatorio: MeshInstance3D
@export var contorno_del_lavatorio: PackedVector2Array
@export var inodoro: MeshInstance3D
@export var contorno_del_inodoro: PackedVector2Array
## Arranca en la punta de la canilla.
@export var gota: MeshInstance3D

var _lavatorio: Superficie
var _inodoro: Superficie
var _azar := RandomNumberGenerator.new()
var _acumulado := 0.0
var _hasta_la_gota := 0.0
var _hasta_la_onda := 0.0
var _salida_de_la_gota := Vector3.ZERO


func _ready() -> void:
	_azar.randomize()
	var simula := _hay_floats()
	_lavatorio = Superficie.new(lavatorio, contorno_del_lavatorio, simula)
	_inodoro = Superficie.new(inodoro, contorno_del_inodoro, simula)
	_salida_de_la_gota = gota.position
	gota.visible = false
	_hasta_la_gota = _azar.randf_range(SEGUNDOS_ENTRE_GOTAS.x, SEGUNDOS_ENTRE_GOTAS.y)
	_hasta_la_onda = _azar.randf_range(
		SEGUNDOS_ENTRE_ONDAS_DEL_INODORO.x, SEGUNDOS_ENTRE_ONDAS_DEL_INODORO.y
	)
	if not simula:
		set_process(false)


func _process(delta: float) -> void:
	_hasta_la_gota -= delta
	if _hasta_la_gota <= 0.0:
		_hasta_la_gota = _azar.randf_range(SEGUNDOS_ENTRE_GOTAS.x, SEGUNDOS_ENTRE_GOTAS.y)
		_soltar_gota()
	_hasta_la_onda -= delta
	if _hasta_la_onda <= 0.0:
		_hasta_la_onda = _azar.randf_range(
			SEGUNDOS_ENTRE_ONDAS_DEL_INODORO.x, SEGUNDOS_ENTRE_ONDAS_DEL_INODORO.y
		)
		var punto := Vector2(_azar.randf_range(0.3, 0.7), _azar.randf_range(0.3, 0.7))
		_inodoro.tocar(punto, FUERZA_DE_LA_ONDA_DEL_INODORO)
	# Un `SubViewport` se dibuja una vez por cuadro como mucho. Un cuadro de más de un paso
	# frena la onda, y no la acelera de golpe al cuadro siguiente.
	_acumulado = minf(_acumulado + delta, 2.0 * PASO)
	if _acumulado >= PASO:
		_acumulado -= PASO
		_lavatorio.avanzar()
		_inodoro.avanzar()


func _soltar_gota() -> void:
	var llegada := Vector3(_salida_de_la_gota.x, lavatorio.position.y, _salida_de_la_gota.z)
	gota.position = _salida_de_la_gota
	gota.visible = true
	var gravedad: float = ProjectSettings.get_setting("physics/3d/default_gravity")
	var caida := sqrt(2.0 * (_salida_de_la_gota.y - llegada.y) / gravedad)
	var tween := create_tween()
	tween.tween_property(gota, "position", llegada, caida).set_trans(Tween.TRANS_QUAD).set_ease(
		Tween.EASE_IN
	)
	tween.tween_callback(_gota_en_el_agua.bind(llegada))


func _gota_en_el_agua(llegada: Vector3) -> void:
	gota.visible = false
	_lavatorio.tocar(_lavatorio.uv_de(llegada - lavatorio.position), FUERZA_DE_LA_GOTA)


## En la web, el render target de floats pide una extensión de WebGL2. Sin ella la textura es
## de 8 bits, la onda sale rota, y es mejor el agua quieta.
func _hay_floats() -> bool:
	if not OS.has_feature("web"):
		return true
	var extension := "document.createElement('canvas').getContext('webgl2')?.getExtension('%s')"
	var consulta := (
		"!!(%s || %s)"
		% [extension % "EXT_color_buffer_float", extension % "EXT_color_buffer_half_float"]
	)
	# `JavaScriptBridge.eval` devuelve un booleano como `int`, y compararlo con `true` es un error
	# que corta la función. Medido el 2026-09-24 en Chrome.
	var hay: Variant = JavaScriptBridge.eval(consulta)
	return hay == 1


class Superficie:
	var _malla: MeshInstance3D
	var _material: ShaderMaterial
	var _desde: Vector2
	var _tamano: Vector2
	var _pasos: Array[ShaderMaterial] = []
	var _vistas: Array[SubViewport] = []
	var _escrita := 0
	var _arranco := false
	var _en_pantalla: VisibleOnScreenNotifier3D
	var _gota := Vector3.ZERO

	func _init(malla: MeshInstance3D, contorno: PackedVector2Array, simula: bool) -> void:
		_malla = malla
		_material = malla.material_override as ShaderMaterial
		var desde := contorno[0]
		var hasta := contorno[0]
		for punto in contorno:
			desde = desde.min(punto)
			hasta = hasta.max(punto)
		_desde = desde
		_tamano = hasta - desde
		malla.mesh = _malla_plana(contorno)
		_en_pantalla = VisibleOnScreenNotifier3D.new()
		_en_pantalla.aabb = malla.mesh.get_aabb()
		malla.add_child(_en_pantalla)
		if not simula:
			return
		var lado := Vector2i((_tamano * TEXELES_POR_METRO).ceil())
		_material.set_shader_parameter("texel", Vector2.ONE / Vector2(lado))
		for i in 2:
			_vistas.append(_vista(lado))
		_pasos[0].set_shader_parameter("previo", _vistas[1].get_texture())
		_pasos[1].set_shader_parameter("previo", _vistas[0].get_texture())

	## El punto de la onda que cae sobre `local`, un punto en el plano de la malla.
	func uv_de(local: Vector3) -> Vector2:
		return (Vector2(local.x, local.z) - _desde) / _tamano

	func tocar(uv: Vector2, fuerza: float) -> void:
		_gota = Vector3(uv.x, uv.y, fuerza)

	## Fuera de la pantalla la onda no avanza, y la gota que cae ahí se pierde: nadie la ve.
	func avanzar() -> void:
		if _vistas.is_empty() or not _en_pantalla.is_on_screen():
			_gota = Vector3.ZERO
			return
		var destino := 1 - _escrita
		_pasos[destino].set_shader_parameter("gota", _gota)
		_pasos[destino].set_shader_parameter("reiniciar", not _arranco)
		_arranco = true
		_gota = Vector3.ZERO
		_vistas[destino].render_target_update_mode = SubViewport.UPDATE_ONCE
		_material.set_shader_parameter("ondas", _vistas[destino].get_texture())
		_escrita = destino

	func _vista(lado: Vector2i) -> SubViewport:
		var vista := SubViewport.new()
		vista.size = lado
		vista.use_hdr_2d = true
		vista.transparent_bg = true
		vista.disable_3d = true
		vista.render_target_update_mode = SubViewport.UPDATE_DISABLED
		var lienzo := ColorRect.new()
		lienzo.size = Vector2(lado)
		var paso := ShaderMaterial.new()
		paso.shader = ONDAS
		lienzo.material = paso
		vista.add_child(lienzo)
		_malla.add_child(vista)
		_pasos.append(paso)
		return vista

	## La malla va en el plano XZ, con el UV en el rectángulo que encierra el contorno.
	func _malla_plana(contorno: PackedVector2Array) -> ArrayMesh:
		var puntos := PackedVector3Array()
		var uvs := PackedVector2Array()
		var normales := PackedVector3Array()
		for punto in contorno:
			puntos.append(Vector3(punto.x, 0.0, punto.y))
			uvs.append((punto - _desde) / _tamano)
			normales.append(Vector3.UP)
		var arreglos := []
		arreglos.resize(Mesh.ARRAY_MAX)
		arreglos[Mesh.ARRAY_VERTEX] = puntos
		arreglos[Mesh.ARRAY_TEX_UV] = uvs
		arreglos[Mesh.ARRAY_NORMAL] = normales
		arreglos[Mesh.ARRAY_INDEX] = Geometry2D.triangulate_polygon(contorno)
		var malla := ArrayMesh.new()
		malla.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arreglos)
		return malla
