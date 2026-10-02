class_name MarcoDelObjetivo
extends Node

const CONTORNO := preload("res://src/sistemas/marco/contorno.gdshader")
const ARISTAS := preload("res://src/sistemas/marco/aristas_del_foco.gdshader")

var _objetivo: Node3D
var _previos: Dictionary[MeshInstance3D, Material] = {}
var _material := ShaderMaterial.new()
var _aristas := ShaderMaterial.new()


func _init() -> void:
	_material.shader = CONTORNO
	_material.set_shader_parameter("color", IndicacionDelFoco.COLOR)
	_material.set_shader_parameter("grosor", IndicacionDelFoco.GROSOR)
	_aristas.shader = ARISTAS
	_aristas.set_shader_parameter("color", IndicacionDelFoco.COLOR)
	_aristas.set_shader_parameter("grosor", IndicacionDelFoco.GROSOR_DE_PRODUCTOS)


func _exit_tree() -> void:
	apagar()


func enfocar(objetivo: Node3D, _distancia: float = 0.0) -> void:
	if objetivo == _objetivo:
		return
	apagar()
	_objetivo = objetivo
	var material: Material = _material
	if "datos" in objetivo and objetivo.get("datos") is UnidadDeProducto:
		material = _aristas
	if "material_de_foco" in objetivo:
		material = objetivo.get("material_de_foco")
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
			malla.material_overlay = material


func apagar() -> void:
	for malla in _previos:
		if is_instance_valid(malla):
			malla.material_overlay = _previos[malla]
	_previos.clear()
	_objetivo = null
