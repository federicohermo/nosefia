## Dibuja agua temporal. El puesto valida la superficie antes de pedir el dibujo.
extends Node3D

const AGUA := preload("res://src/escenas/objetos/charcos_temporales.gdshader")

var _mallas: Array[MeshInstance3D] = []
var _edades: Array[float] = []
var _plano := PlaneMesh.new()
var _fase := 0


func _init() -> void:
	_plano.size = Vector2.ONE * ReglasDeLaLimpieza.RADIO_DEL_CHARCO * 2.0


func _ready() -> void:
	# El primer uso necesita su shader compilado, sin añadir agua ni ocupar el cupo.
	var testigo := _crear_malla()
	(testigo.material_override as ShaderMaterial).set_shader_parameter("opacidad", 0.0)
	testigo.hide()
	add_child(testigo)


func _crear_malla() -> MeshInstance3D:
	var malla := MeshInstance3D.new()
	malla.mesh = _plano
	malla.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	malla.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pintura := ShaderMaterial.new()
	pintura.shader = AGUA
	pintura.set_shader_parameter(
		"color", ReglasDeLaLimpieza.COLOR_DEL_AGUA[ReglasDeLaLimpieza.Agua.LIMPIA]
	)
	malla.material_override = pintura
	return malla


func dejar_en(posicion: Vector3, normal: Vector3 = Vector3.UP) -> void:
	var malla: MeshInstance3D
	if _mallas.size() < ReglasDeLaLimpieza.MAXIMO_DE_CHARCOS:
		malla = _crear_malla()
		add_child(malla)
	else:
		# Se reutiliza el más viejo; el número de dibujos no crece con cada pasada.
		malla = _mallas.pop_front()
		_edades.pop_front()
	_mallas.append(malla)
	_edades.append(0.0)
	var arriba := normal.normalized()
	malla.global_transform = Transform3D(
		Basis(Quaternion(Vector3.UP, arriba)), posicion + arriba * 0.003
	)
	_fase = (_fase + 1) % ReglasDeLaLimpieza.MAXIMO_DE_CHARCOS
	(malla.material_override as ShaderMaterial).set_shader_parameter("fase", _fase * 1.7)
	_pintar(malla, 0.0)


func limpiar() -> void:
	for malla: MeshInstance3D in _mallas:
		malla.hide()
		remove_child(malla)
		malla.queue_free()
	_mallas.clear()
	_edades.clear()


func cantidad() -> int:
	return _mallas.size()


func _process(delta: float) -> void:
	for indice in range(_mallas.size() - 1, -1, -1):
		_edades[indice] += maxf(delta, 0.0)
		var malla := _mallas[indice]
		if _edades[indice] >= ReglasDeLaLimpieza.DURACION_DEL_CHARCO:
			malla.hide()
			remove_child(malla)
			malla.queue_free()
			_mallas.remove_at(indice)
			_edades.remove_at(indice)
		else:
			_pintar(malla, _edades[indice])


func _pintar(malla: MeshInstance3D, edad: float) -> void:
	var pintura := malla.material_override as ShaderMaterial
	var progreso := edad / ReglasDeLaLimpieza.DURACION_DEL_CHARCO
	pintura.set_shader_parameter("opacidad", 1.0 - smoothstep(0.0, 1.0, progreso))
	# El borde se expande dentro del disco que el puesto ya validó.
	pintura.set_shader_parameter("expansion", lerpf(0.9, 1.0, smoothstep(0.0, 0.5, edad)))
