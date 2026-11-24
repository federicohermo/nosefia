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
	set_process(false)


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
	var arriba := normal.normalized()
	var destino := posicion + arriba * 0.003
	var malla := _retirar_cercano(destino)
	if malla == null:
		if _mallas.size() < ReglasDeLaLimpieza.MAXIMO_DE_CHARCOS:
			malla = _crear_malla()
			add_child(malla)
		else:
			# Se reutiliza el más viejo; el número de dibujos no crece con cada pasada.
			malla = _mallas.pop_front()
			_edades.pop_front()
	_mallas.append(malla)
	_edades.append(0.0)
	malla.global_transform = Transform3D(Basis(Quaternion(Vector3.UP, arriba)), destino)
	_fase = (_fase + 1) % ReglasDeLaLimpieza.MAXIMO_DE_CHARCOS
	(malla.material_override as ShaderMaterial).set_shader_parameter("fase", _fase * 1.7)
	_pintar(malla, 0.0)
	set_process(true)


func _retirar_cercano(destino: Vector3) -> MeshInstance3D:
	# Repasar el mismo punto refresca el charco en vez de apilar planos coplanares.
	var radio_de_fusion := ReglasDeLaLimpieza.RADIO_DEL_CHARCO * 0.55
	var umbral := radio_de_fusion * radio_de_fusion
	for indice in range(_mallas.size() - 1, -1, -1):
		if _mallas[indice].global_position.distance_squared_to(destino) <= umbral:
			var malla := _mallas[indice]
			_mallas.remove_at(indice)
			_edades.remove_at(indice)
			return malla
	return null


func limpiar() -> void:
	for malla: MeshInstance3D in _mallas:
		malla.hide()
		remove_child(malla)
		malla.queue_free()
	_mallas.clear()
	_edades.clear()
	set_process(false)


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
	if _mallas.is_empty():
		set_process(false)


func _pintar(malla: MeshInstance3D, edad: float) -> void:
	var pintura := malla.material_override as ShaderMaterial
	var progreso := edad / ReglasDeLaLimpieza.DURACION_DEL_CHARCO
	pintura.set_shader_parameter("opacidad", 1.0 - smoothstep(0.0, 1.0, progreso))
	# El borde se expande dentro del disco que el puesto ya validó.
	pintura.set_shader_parameter("expansion", lerpf(0.9, 1.0, smoothstep(0.0, 0.5, edad)))
