## Aproximación visual con inercia, sin volumen ni estado de limpieza.
extends MeshInstance3D

signal encogida

const Gotas := preload("res://src/escenas/objetos/gotas_del_balde.gd")
const Ondas := preload("res://src/escenas/objetos/ondas_del_balde.gd")
const AGUA_VISIBLE := preload("res://src/escenas/puestos/agua_del_bano.gdshader")
const SEGMENTOS := 48
const ANILLOS := 12
const PASO := 1.0 / 120.0
const RELIEVE_DE_LAS_ONDAS := 1.8

@export var en_balde := false

var _radio := 0.6
var _pendiente := Vector2.ZERO
var _impulso := Vector2.ZERO
var _posicion_previa := Vector3.ZERO
var _velocidad_previa := Vector3.ZERO
var _padre_previo: Node
var _muestreada := false
var _tiempo := 0.0
var _onda := 0.0
var _espera := 0.0
var _vertices := PackedVector3Array()
var _indices := PackedInt32Array()
var _superficie := ArrayMesh.new()
var _gotas: Gotas
var _nivel_previo := Vector2.ZERO
var _centro_de_onda := Vector2.ZERO
var _ultima_inclinacion := Vector2.INF
var _estaba_quieta := false
var _ondas := Ondas.new()
var _aceleracion := Vector2.ZERO
var _encogimiento: Tween


func _ready() -> void:
	_radio = (mesh as CylinderMesh).top_radius
	_crear_topologia()
	mesh = _superficie
	if en_balde:
		configurar_agua(true)
		_gotas = Gotas.new()
		add_child(_gotas)
		_gotas.preparar(material_override)
	else:
		_onda = float(absf(global_basis.y.normalized().dot(Vector3.UP)) > 0.8)
	_dibujar()


func configurar_agua(acuosa: bool) -> void:
	if not acuosa or material_override is ShaderMaterial:
		return
	var pintura := ShaderMaterial.new()
	pintura.shader = AGUA_VISIBLE
	pintura.set_shader_parameter(
		"color_del_agua", (material_override as StandardMaterial3D).albedo_color
	)
	pintura.set_shader_parameter("normal_de_la_malla", true)
	pintura.set_shader_parameter("transparencia", 0.4 if en_balde else 0.55)
	pintura.set_shader_parameter("hacia_la_luz", Vector3(-0.41, 0.88, 0.23))
	pintura.set_shader_parameter("brillo", 0.65)
	material_override = pintura
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func pintar(color: Color) -> void:
	if material_override is ShaderMaterial:
		(material_override as ShaderMaterial).set_shader_parameter("color_del_agua", color)
	else:
		(material_override as StandardMaterial3D).albedo_color = color


func color_de_la_superficie() -> Color:
	if material_override is ShaderMaterial:
		return (material_override as ShaderMaterial).get_shader_parameter("color_del_agua")
	return (material_override as StandardMaterial3D).albedo_color


## Llenar, vaciar y transportar entre escenas no producen chorros espurios.
func reiniciar() -> void:
	_pendiente = Vector2.ZERO
	_impulso = Vector2.ZERO
	_velocidad_previa = Vector3.ZERO
	_muestreada = false
	_onda = 0.0
	_espera = 0.0
	_nivel_previo = _nivel()
	_ondas.reiniciar()
	_aceleracion = Vector2.ZERO
	if _gotas != null:
		_gotas.limpiar()


func perturbar() -> void:
	if absf(global_basis.y.normalized().dot(Vector3.UP)) > 0.8:
		_onda = 1.0
		_tiempo = 0.0
		set_physics_process(true)


func presentar(activa: bool) -> void:
	if not en_balde and activa:
		_cancelar_encogimiento()
	if not en_balde and not activa and esta_encogiendo():
		return
	if en_balde and (visible != activa or not activa):
		reiniciar()
	if not en_balde and activa and not visible:
		perturbar()
	visible = activa


func esta_encogiendo() -> bool:
	return _encogimiento != null and _encogimiento.is_running()


func encoger() -> void:
	_cancelar_encogimiento()
	visible = true
	_encogimiento = create_tween()
	_encogimiento.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_encogimiento.tween_property(self, "scale", Vector3(0.01, 1.0, 0.01), 0.45)
	_encogimiento.tween_callback(_terminar_encogimiento)


func _cancelar_encogimiento() -> void:
	if _encogimiento != null:
		_encogimiento.kill()
		_encogimiento = null
	scale = Vector3.ONE


func _terminar_encogimiento() -> void:
	_encogimiento = null
	visible = false
	encogida.emit()


func tocar_en(punto: Vector3) -> void:
	var local := to_local(punto)
	_centro_de_onda = Vector2(local.x, local.z).limit_length(_radio)
	perturbar()


func _physics_process(delta: float) -> void:
	if not is_visible_in_tree():
		_muestreada = false
		return
	if delta <= 0.0:
		return
	var paso := minf(delta, 0.1)
	_tiempo += paso
	_espera = maxf(0.0, _espera - paso)
	if en_balde:
		_mover_agua(paso)
		_ondas.avanzar(paso, _aceleracion)
	else:
		if _onda < 0.001:
			set_physics_process(false)
			return
		_onda *= exp(-paso * 1.8)
	_dibujar()


func _mover_agua(delta: float) -> void:
	var desplazamiento := global_position - _posicion_previa
	var padre := get_parent().get_parent()
	if not _muestreada or desplazamiento.length() > 0.75 or padre != _padre_previo:
		_posicion_previa = global_position
		_padre_previo = padre
		_velocidad_previa = Vector3.ZERO
		_pendiente = Vector2.ZERO
		_impulso = Vector2.ZERO
		_nivel_previo = _nivel()
		_ondas.reiniciar()
		_aceleracion = Vector2.ZERO
		_muestreada = true
		return
	var velocidad := desplazamiento / delta
	var aceleracion := (velocidad - _velocidad_previa) / delta
	_posicion_previa = global_position
	_velocidad_previa = velocidad
	var local := global_basis.inverse() * aceleracion.limit_length(24.0)
	# Filtra el cabeceo entre cuadros para no generar pulsos al caminar.
	_aceleracion = _aceleracion.lerp(Vector2(local.x, local.z), 1.0 - exp(-delta / 0.07))
	if _aceleracion.length() > 3.0:
		_ondas.perturbar(-_aceleracion.normalized() * 0.65, _aceleracion.length() * delta * 0.25)
	var objetivo := -Vector2(local.x, local.z) / 9.81
	# Inclinar o girar el recipiente también excita el agua aunque no se traslade.
	var nivel := _nivel()
	_impulso -= (nivel - _nivel_previo) * 4.0
	_nivel_previo = nivel
	var restante := delta
	while restante > 0.0:
		var paso := minf(PASO, restante)
		_impulso += ((objetivo - _pendiente) * 45.0 - _impulso * 5.0) * paso
		_pendiente = (_pendiente + _impulso * paso).limit_length(0.65)
		restante -= paso
	_onda = minf(1.0, _pendiente.length() + _impulso.length() * 0.04)
	var inclinacion := _inclinacion()
	var cresta := (
		inclinacion.length() * _radio
		+ _ondas.amplitud() * RELIEVE_DE_LAS_ONDAS
		+ _impulso.length() * 0.06
	)
	if cresta > 0.095 and _onda > 0.1 and _espera <= 0.0:
		var lado := (inclinacion + _pendiente).normalized()
		lado *= _radio_del_borde(lado.angle())
		var borde := Vector3(lado.x, 0.105, lado.y)
		var salida := global_basis * Vector3(lado.x * 5.0, 0.7, lado.y * 5.0)
		_gotas.emitir(to_global(borde), velocidad.limit_length(3.0) + salida)
		_espera = 0.12


func _inclinacion() -> Vector2:
	return (_nivel() + _pendiente * 0.35).limit_length(0.8)


func _nivel() -> Vector2:
	var arriba := global_basis.inverse() * Vector3.UP
	return -Vector2(arriba.x, arriba.z) / maxf(absf(arriba.y), 0.35)


func _radio_del_borde(angulo: float) -> float:
	# Medido en la malla: doce paredes con apotema 0,1719 m, no un recipiente circular.
	var normal := cos(wrapf(angulo + PI / 12.0, 0.0, PI / 6.0) - PI / 12.0)
	return minf(_radio, 0.167 / normal)


func _crear_topologia() -> void:
	_vertices.resize(1 + ANILLOS * SEGMENTOS)
	for segmento: int in SEGMENTOS:
		_indices.append_array(PackedInt32Array([0, 1 + segmento, 1 + (segmento + 1) % SEGMENTOS]))
	for anillo: int in range(1, ANILLOS):
		for segmento: int in SEGMENTOS:
			var a := 1 + (anillo - 1) * SEGMENTOS + segmento
			var b := 1 + (anillo - 1) * SEGMENTOS + (segmento + 1) % SEGMENTOS
			var c := a + SEGMENTOS
			var d := b + SEGMENTOS
			_indices.append_array(PackedInt32Array([a, c, b, b, c, d]))


func _dibujar() -> void:
	var inclinacion := _inclinacion() if en_balde else Vector2.ZERO
	var quieta := _onda < 0.0001 and (not en_balde or _ondas.amplitud() < 0.0001)
	if quieta and _estaba_quieta and inclinacion.is_equal_approx(_ultima_inclinacion):
		return
	_estaba_quieta = quieta
	_ultima_inclinacion = inclinacion
	_vertices[0] = Vector3(
		0.0, _ondas.altura_en(Vector2.ZERO) * RELIEVE_DE_LAS_ONDAS if en_balde else 0.0, 0.0
	)
	for anillo: int in range(1, ANILLOS + 1):
		var proporcion := float(anillo) / ANILLOS
		for segmento: int in SEGMENTOS:
			var angulo := TAU * segmento / SEGMENTOS
			var borde := 1.0
			if not en_balde:
				# El contorno queda dentro del cuerpo enfocable y se asienta después de la onda.
				var fase := float(get_parent().get("lugar")) * 1.7
				borde = 0.84 + 0.08 * sin(angulo * 3.0 + fase) + 0.04 * cos(angulo * 7.0)
				borde *= 1.0 - _onda * 0.12 * (0.5 + 0.5 * cos(_tiempo * 5.0))
			var radio := _radio_del_borde(angulo) if en_balde else _radio
			var punto := Vector2(cos(angulo), sin(angulo)) * radio * proporcion * borde
			var altura := inclinacion.dot(punto)
			if en_balde:
				altura += _ondas.altura_en(punto / _radio) * RELIEVE_DE_LAS_ONDAS
			else:
				var distancia := punto.distance_to(_centro_de_onda) / _radio
				altura += sin(distancia * 12.0 - _tiempo * 9.0) * 0.0015 * _onda
				altura = clampf(altura + 0.0015, 0.0002, 0.0015) * (1.0 - proporcion * 0.7)
			_vertices[1 + (anillo - 1) * SEGMENTOS + segmento] = Vector3(
				punto.x, clampf(altura, -0.1, 0.105), punto.y
			)
	var normales := PackedVector3Array()
	normales.resize(_vertices.size())
	for triangulo: int in range(0, _indices.size(), 3):
		var a := _indices[triangulo]
		var b := _indices[triangulo + 1]
		var c := _indices[triangulo + 2]
		var normal := (_vertices[c] - _vertices[a]).cross(_vertices[b] - _vertices[a])
		normales[a] += normal
		normales[b] += normal
		normales[c] += normal
	for indice: int in normales.size():
		normales[indice] = normales[indice].normalized()
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _vertices
	arrays[Mesh.ARRAY_NORMAL] = normales
	arrays[Mesh.ARRAY_INDEX] = _indices
	_superficie.clear_surfaces()
	_superficie.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
