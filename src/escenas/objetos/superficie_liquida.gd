## Aproximación visual con inercia, sin volumen ni estado de limpieza.
extends MeshInstance3D

signal encogida

const Gotas := preload("res://src/escenas/objetos/gotas_del_balde.gd")
const Ondas := preload("res://src/escenas/objetos/ondas_del_balde.gd")
const ASPECTO_VISIBLE := preload("res://src/escenas/objetos/agua_y_manchas.gdshader")
const GUIA_DE_MANCHAS := preload(
	"res://assets/models/SEPT_JUEGOS_PROTOTIPO_Guía de jabones y manchas copy.png"
)
const SEGMENTOS := 48
const ANILLOS := 12
const PASO := 1.0 / 120.0
const RELIEVE_DE_LAS_ONDAS := 1.8
const DURACION_DE_MEZCLA := 0.7
const DURACION_DEL_NIVEL := 0.25
# Tapa interior del modelo a -0.138054 m: el agua empieza 3 mm por encima.
const ALTURA_MINIMA := -0.135

@export var en_balde := false
@export var escala_de_reposo := Vector3.ONE

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
var _normales := PackedVector3Array()
var _puntos := PackedVector2Array()
var _coordenadas := PackedVector2Array()
var _indices := PackedInt32Array()
var _superficie := ArrayMesh.new()
# El renderizador sin pantalla no implementa las escrituras de buffers.
var _recrea_la_superficie := DisplayServer.get_name() == "headless"
var _normales_empaquetadas := PackedInt32Array()
var _inicio_de_normales := 0
var _paso_de_normales := 0
var _gotas: Gotas
var _nivel_previo := Vector2.ZERO
var _centro_de_onda := Vector2.ZERO
var _ultima_inclinacion := Vector2.INF
var _estaba_quieta := false
var _ondas := Ondas.new()
var _aceleracion := Vector2.ZERO
var _encogimiento: Tween
var _color_previo := Color.TRANSPARENT
var _densidad_previa := 0.0
var _progreso_de_mezcla := 1.0
var _altura_de_reposo := 0.0
var _nivel_visual := 1.0
var _nivel_desde := 1.0
var _nivel_hasta := 1.0
var _tiempo_del_nivel := DURACION_DEL_NIVEL
var _cambiando_nivel := false


func _ready() -> void:
	_altura_de_reposo = position.y
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
	if not acuosa:
		return
	var pintura := material_override as ShaderMaterial
	if pintura != null:
		if pintura.shader != ASPECTO_VISIBLE or not pintura.get_shader_parameter("es_mancha"):
			return
	else:
		var color_previo := color_de_la_superficie()
		pintura = ShaderMaterial.new()
		pintura.shader = ASPECTO_VISIBLE
		pintura.set_shader_parameter("color_del_agua", color_previo)
		material_override = pintura
	pintura.set_shader_parameter("es_mancha", false)
	pintura.set_shader_parameter("densidad_de_solucion", _densidad_visual(color_de_la_superficie()))
	pintura.set_shader_parameter("normal_de_la_malla", true)
	pintura.set_shader_parameter("transparencia", 0.4 if en_balde else 0.55)
	pintura.set_shader_parameter("hacia_la_luz", Vector3(-0.41, 0.88, 0.23))
	pintura.set_shader_parameter("brillo", 0.65)
	material_override = pintura
	_cancelar_mezcla()
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func pintar(color: Color) -> void:
	if _cambiando_nivel and _nivel_hasta == 0.0 and color.a <= 0.0:
		return
	if color == color_de_la_superficie():
		return
	if material_override is ShaderMaterial:
		(material_override as ShaderMaterial).set_shader_parameter("color_del_agua", color)
		(material_override as ShaderMaterial).set_shader_parameter(
			"densidad_de_solucion", _densidad_visual(color)
		)
	else:
		(material_override as StandardMaterial3D).albedo_color = color
	_cancelar_mezcla()


func mezclar(color: Color) -> void:
	var pintura := material_override as ShaderMaterial
	if (
		not en_balde
		or not visible
		or pintura == null
		or pintura.shader != ASPECTO_VISIBLE
		or pintura.get_shader_parameter("es_mancha")
	):
		pintar(color)
		return
	if color == color_de_la_superficie():
		return
	# El destino ya sirve para la carga de la mopa; únicamente la superficie tarda en teñirse.
	_color_previo = color_de_la_superficie()
	_densidad_previa = _densidad_visual(_color_previo)
	pintura.set_shader_parameter("color_del_agua", color)
	pintura.set_shader_parameter("densidad_de_solucion", _densidad_visual(color))
	_progreso_de_mezcla = 0.0
	_actualizar_mezcla()
	set_physics_process(true)
	set_process(true)


func llenar() -> void:
	if not en_balde or (visible and not _cambiando_nivel):
		return
	if not visible:
		reiniciar()
		_nivel_visual = 0.0
	visible = true
	_cambiar_nivel(1.0)


func vaciar() -> void:
	if not en_balde or not visible:
		return
	_cancelar_mezcla()
	_cambiar_nivel(0.0)


func _cambiar_nivel(hasta: float) -> void:
	if _cambiando_nivel and _nivel_hasta == hasta:
		return
	_nivel_desde = _nivel_visual
	_nivel_hasta = hasta
	_tiempo_del_nivel = 0.0
	_cambiando_nivel = true
	position.y = lerpf(ALTURA_MINIMA, _altura_de_reposo, _nivel_visual)
	_estaba_quieta = false
	set_physics_process(true)
	set_process(true)


func _avanzar_nivel(delta: float) -> void:
	if not _cambiando_nivel:
		return
	_tiempo_del_nivel = minf(DURACION_DEL_NIVEL, _tiempo_del_nivel + delta)
	var progreso := smoothstep(0.0, 1.0, _tiempo_del_nivel / DURACION_DEL_NIVEL)
	_nivel_visual = lerpf(_nivel_desde, _nivel_hasta, progreso)
	position.y = lerpf(ALTURA_MINIMA, _altura_de_reposo, _nivel_visual)
	_estaba_quieta = false
	if _tiempo_del_nivel >= DURACION_DEL_NIVEL:
		_cambiando_nivel = false
		visible = _nivel_hasta != 0.0


func _cancelar_mezcla() -> void:
	_progreso_de_mezcla = 1.0
	_color_previo = color_de_la_superficie()
	_densidad_previa = _densidad_visual(_color_previo)
	_actualizar_mezcla()


func _actualizar_mezcla() -> void:
	var pintura := material_override as ShaderMaterial
	if pintura != null and pintura.shader == ASPECTO_VISIBLE:
		pintura.set_shader_parameter("color_previo", _color_previo)
		pintura.set_shader_parameter("densidad_previa", _densidad_previa)
		pintura.set_shader_parameter("progreso_de_mezcla", _progreso_de_mezcla)


func _densidad_visual(color: Color) -> float:
	# El interior azul no debe cambiar el matiz que identifica al producto.
	var limpia: Color = ReglasDeLaLimpieza.COLOR_DEL_AGUA[ReglasDeLaLimpieza.Agua.LIMPIA]
	return float(en_balde and color.a > 0.0 and not color.is_equal_approx(limpia))


func configurar_mancha(tipo: ReglasDeLaLimpieza.TipoDeMancha, acuosa: bool) -> void:
	var pintura := material_override as ShaderMaterial
	if pintura == null or pintura.shader != ASPECTO_VISIBLE:
		var color_previo := color_de_la_superficie()
		pintura = ShaderMaterial.new()
		pintura.shader = ASPECTO_VISIBLE
		pintura.set_shader_parameter("color_del_agua", color_previo)
		material_override = pintura
	_cancelar_mezcla()
	pintura.set_shader_parameter("es_mancha", true)
	pintura.set_shader_parameter("guia_de_manchas", GUIA_DE_MANCHAS)
	pintura.set_shader_parameter("tipo_de_suciedad", tipo)
	pintura.set_shader_parameter("acuosa", acuosa)
	pintura.set_shader_parameter("transparencia", 0.55 if acuosa else 1.0)


func color_de_la_superficie() -> Color:
	if material_override is ShaderMaterial:
		return (material_override as ShaderMaterial).get_shader_parameter("color_del_agua")
	return (material_override as StandardMaterial3D).albedo_color


## Llenar, vaciar y transportar entre escenas no producen chorros espurios.
func reiniciar() -> void:
	if en_balde:
		_cambiando_nivel = false
		_nivel_visual = 1.0
		_nivel_desde = 1.0
		_nivel_hasta = 1.0
		_tiempo_del_nivel = DURACION_DEL_NIVEL
		position.y = _altura_de_reposo
		_estaba_quieta = false
	_cancelar_mezcla()
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
		set_process(true)


func presentar(activa: bool) -> void:
	if en_balde and _cambiando_nivel:
		return
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
	_encogimiento.tween_property(self, "scale", escala_de_reposo * Vector3(0.01, 1.0, 0.01), 0.45)
	_encogimiento.tween_callback(_terminar_encogimiento)


func _cancelar_encogimiento() -> void:
	if _encogimiento != null:
		_encogimiento.kill()
		_encogimiento = null
	scale = escala_de_reposo


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
	_avanzar_nivel(delta)
	if not visible:
		return
	var paso := minf(delta, 0.1)
	if _progreso_de_mezcla < 1.0:
		_progreso_de_mezcla = minf(1.0, _progreso_de_mezcla + delta / DURACION_DE_MEZCLA)
		_actualizar_mezcla()
	_tiempo += paso
	_espera = maxf(0.0, _espera - paso)
	if en_balde:
		_mover_agua(paso)
		_ondas.avanzar(paso, _aceleracion)
	else:
		if _onda < 0.001:
			set_physics_process(false)
			set_process(false)
			return
		_onda *= exp(-paso * 1.8)


## La física puede recuperar varios pasos; basta subir la malla una vez por cuadro.
func _process(_delta: float) -> void:
	if is_visible_in_tree() and (en_balde or _onda >= 0.001):
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
	# Las esquinas de las doce paredes están a 0°, 30°…; sus normales, a 15°, 45°…
	var normal := cos(wrapf(angulo, 0.0, PI / 6.0) - PI / 12.0)
	# El apotema interior a la altura llena es 0.1663 m y el fondo es más angosto.
	var apotema := 0.165 * lerpf(0.9, 1.0, _nivel_visual)
	return minf(_radio, apotema / normal)


func _crear_topologia() -> void:
	_vertices.resize(1 + ANILLOS * SEGMENTOS)
	_normales.resize(_vertices.size())
	_puntos.resize(_vertices.size())
	var fase := 0.0 if en_balde else float(get_parent().get("lugar")) * 1.7
	for anillo: int in range(1, ANILLOS + 1):
		for segmento: int in SEGMENTOS:
			var angulo := TAU * segmento / SEGMENTOS
			var radio := _radio_del_borde(angulo) if en_balde else _radio
			var borde := (
				1.0
				if en_balde
				else 0.84 + 0.08 * sin(angulo * 3.0 + fase) + 0.04 * cos(angulo * 7.0)
			)
			_puntos[1 + (anillo - 1) * SEGMENTOS + segmento] = (
				Vector2(cos(angulo), sin(angulo)) * radio * float(anillo) / ANILLOS * borde
			)
	for punto: Vector2 in _puntos:
		_coordenadas.append(punto / (_radio * 2.0) + Vector2(0.5, 0.5))
	if en_balde:
		var muestras := PackedVector2Array()
		for punto: Vector2 in _puntos:
			muestras.append(punto / _radio)
		_ondas.preparar_muestras(muestras)
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
	var alturas := _ondas.alturas_muestreadas() if en_balde else PackedFloat32Array()
	_vertices[0] = Vector3(
		0.0, alturas[0] * RELIEVE_DE_LAS_ONDAS * _nivel_visual if en_balde else 0.0, 0.0
	)
	var borde := (
		lerpf(0.9, 1.0, _nivel_visual)
		if en_balde
		else 1.0 - _onda * 0.12 * (0.5 + 0.5 * cos(_tiempo * 5.0))
	)
	for anillo: int in range(1, ANILLOS + 1):
		var proporcion := float(anillo) / ANILLOS
		for segmento: int in SEGMENTOS:
			var punto := _puntos[1 + (anillo - 1) * SEGMENTOS + segmento] * borde
			var altura := inclinacion.dot(punto)
			if en_balde:
				altura += alturas[1 + (anillo - 1) * SEGMENTOS + segmento] * RELIEVE_DE_LAS_ONDAS
				altura *= _nivel_visual
			else:
				var distancia := punto.distance_to(_centro_de_onda) / _radio
				altura += sin(distancia * 12.0 - _tiempo * 9.0) * 0.0015 * _onda
				altura = clampf(altura + 0.0015, 0.0002, 0.0015) * (1.0 - proporcion * 0.7)
			_vertices[1 + (anillo - 1) * SEGMENTOS + segmento] = Vector3(
				punto.x, clampf(altura, -0.1, 0.105), punto.y
			)
	# Dos tangentes por vértice evitan acumular cada triángulo de la superficie.
	_normales[0] = (
		(_vertices[1 + SEGMENTOS / 4] - _vertices[1 + SEGMENTOS * 3 / 4])
		. cross(_vertices[1] - _vertices[1 + SEGMENTOS / 2])
		. normalized()
	)
	for anillo: int in ANILLOS:
		var inicio := 1 + anillo * SEGMENTOS
		for segmento: int in SEGMENTOS:
			var indice := inicio + segmento
			var anterior := inicio + (segmento + SEGMENTOS - 1) % SEGMENTOS
			var siguiente := inicio + (segmento + 1) % SEGMENTOS
			var interior := indice - SEGMENTOS if anillo > 0 else 0
			var exterior := indice + SEGMENTOS if anillo < ANILLOS - 1 else indice
			_normales[indice] = (
				(_vertices[siguiente] - _vertices[anterior])
				. cross(_vertices[exterior] - _vertices[interior])
				. normalized()
			)
	if _recrea_la_superficie:
		_superficie.clear_surfaces()
	if _superficie.get_surface_count() == 0:
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = _vertices
		arrays[Mesh.ARRAY_NORMAL] = _normales
		arrays[Mesh.ARRAY_TEX_UV] = _coordenadas
		arrays[Mesh.ARRAY_INDEX] = _indices
		_superficie.add_surface_from_arrays(
			Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, Mesh.ARRAY_FLAG_USE_DYNAMIC_UPDATE
		)
		_superficie.custom_aabb = AABB(
			Vector3(-_radio, -0.1, -_radio), Vector3(_radio * 2.0, 0.205, _radio * 2.0)
		)
		var formato := _superficie.surface_get_format(0)
		_inicio_de_normales = RenderingServer.mesh_surface_get_format_offset(
			formato, _vertices.size(), Mesh.ARRAY_NORMAL
		)
		_paso_de_normales = (
			RenderingServer.mesh_surface_get_format_normal_tangent_stride(formato, _vertices.size())
			/ 4
		)
		_normales_empaquetadas.resize(_vertices.size() * _paso_de_normales)
	else:
		for indice: int in _normales.size():
			var normal := _normales[indice].octahedron_encode() * 65535.0
			_normales_empaquetadas[indice * _paso_de_normales] = (
				int(normal.x) | (int(normal.y) << 16)
			)
		_superficie.surface_update_vertex_region(0, 0, _vertices.to_byte_array())
		_superficie.surface_update_vertex_region(
			0, _inicio_de_normales, _normales_empaquetadas.to_byte_array()
		)
