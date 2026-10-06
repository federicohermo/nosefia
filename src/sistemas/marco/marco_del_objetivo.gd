class_name MarcoDelObjetivo
extends Node

const CONTORNO := preload("res://src/sistemas/marco/contorno.gdshader")

var _objetivo: Node3D
var _previos: Dictionary[MeshInstance3D, Material] = {}
var _material := ShaderMaterial.new()


func _init() -> void:
	_material.shader = CONTORNO
	_material.set_shader_parameter("color", IndicacionDelFoco.COLOR)
	_material.set_shader_parameter("grosor", IndicacionDelFoco.GROSOR)


func _exit_tree() -> void:
	apagar()


func enfocar(objetivo: Node3D, _distancia: float = 0.0) -> void:
	if objetivo == _objetivo:
		return
	apagar()
	_objetivo = objetivo
	var material: Material = _material
	var propio: Variant = objetivo.get("material_de_foco")
	if propio is Material:
		material = propio
	var mallas: Array[MeshInstance3D] = []
	if "mallas" in objetivo:
		mallas.assign(objetivo.get("mallas"))
	else:
		mallas.assign(objetivo.find_children("*", "MeshInstance3D", true, false))
		if objetivo is MeshInstance3D:
			mallas.append(objetivo)
	for malla in mallas:
		if is_instance_valid(malla) and not _previos.has(malla):
			_previos[malla] = malla.material_overlay
			_mostrar_contorno(malla, material)


func apagar() -> void:
	for malla in _previos:
		if is_instance_valid(malla):
			_mostrar_contorno(malla, _previos[malla])
	_previos.clear()
	_objetivo = null


## Las mallas animadas conocen su deformación y dibujan el contorno con ella.
func _mostrar_contorno(malla: MeshInstance3D, material: Material) -> void:
	if malla.has_method("mostrar_contorno"):
		malla.call("mostrar_contorno", material)
	else:
		malla.material_overlay = material
