extends GdUnitTestSuite

const FIXTURE := "res://test/escenas/captura_de_compradores_jornada_2.gd"
const FUENTES := {
	"fede":
	[
		"e2f3b77484e9eadf18c208a4280c64388e69a164b5cb856743f773b561524d06",
		"65edcdc00a3be9e2898957c8a9cf1a32a5e1d4ef253759b82f3d0ee40add16d5",
		"21f8eb974f8e597fd11ebe8990155318d1438dc150dc7c1d2a13665f1dbc6229",
		"5d3758d1560b8f97d522f78dbcfd36414fa8871e63a67d31dfb65c2c220fd967",
		"7d105511e96ce0be061ee2a29ca17508c50617f1fff7af67b1ce64c18a49ede9",
		"e3e9ce5595acbb80fcde979eac8804b4834da52bcf90770e5c3561c831c4b675",
		"fba41cdb83d9b4348a7b9167037ce84d766d508717c3156b491997b21c7da86c",
		"10c98fcd0f51324f2bc4d176df743af5303fd886939a96def1b1c279fcdcba09",
	],
	"mia":
	[
		"908de72357f180f3184c0cdcfe0d14f501ccda2ed99b4afa44565c0b51fdd580",
		"f5114c392b0c2fb4e4f4276614982759e8a46a0add8ad7bcef1b3efed5cab1e4",
		"bfbaade048cca58903047dcdeba0e5aad4268760efd215c649050b3b2eb584e7",
		"0302a97b51afb0140080180a31a69ae42eb83d88c11eb6da0c7955270336c509",
		"bdb1645019c7b390682b527c8cacd8b67aecdf2b7c783cd886fe4c3cd0548485",
		"92cfbb5eab8025b1c3b7f1a3d7e5c9919d06c2d576e7ab138b9567a439e02238",
		"f7721f7eb358687edc768afe18c8ef558b8ae58cae90e89b394f464912498096",
		"83ad7bb3964807c0eaf1607f8602b32c14f93508957cb5868cf9e43fff64d506",
	],
}

var _fixture: RefCounted


func before_test() -> void:
	_fixture = load(FIXTURE).new()


func after_test() -> void:
	if _fixture.get("local") != null:
		await _fixture.call("limpiar")
	_fixture = null


func _crear() -> bool:
	var tabla: Dictionary = _fixture.call("tabla")
	assert_bool(tabla.has(DialogosDeCompradores.Personaje.FEDE)).is_true()
	assert_bool(tabla.has(DialogosDeCompradores.Personaje.MIA)).is_true()
	if (
		not tabla.has(DialogosDeCompradores.Personaje.FEDE)
		or not tabla.has(DialogosDeCompradores.Personaje.MIA)
	):
		return false
	await _fixture.call("crear", self)
	return true


func _figura() -> AnimatedSprite3D:
	return _fixture.call("figura")


func _foco(transparente: bool = false) -> void:
	var resultado: Dictionary = await _fixture.call("mirar", transparente)
	var pixel: Vector2i = resultado.pixel
	assert_int(pixel.x).is_greater_equal(0)
	assert_bool(resultado.get("piso", false)).is_true()
	assert_bool(resultado.get("capsula", false)).is_true()
	assert_float(resultado.get("angulo", INF)).is_less(0.005)
	assert_bool(resultado.get("objetivo", false)).is_equal(not transparente)


func test_los_dieciseis_png_conservan_los_blobs_y_rgba_originales() -> void:
	for carpeta: String in FUENTES:
		for cuadro in 8:
			var ruta := "res://assets/characters/%s/%02d.png" % [carpeta, cuadro + 1]
			assert_str(FileAccess.get_sha256(ruta)).is_equal(FUENTES[carpeta][cuadro])
			var imagen := Image.new()
			assert_int(imagen.load_png_from_buffer(FileAccess.get_file_as_bytes(ruta))).is_equal(OK)
			assert_int(imagen.get_width()).is_equal(1086)
			assert_int(imagen.get_height()).is_equal(1448)
			assert_int(imagen.get_format()).is_equal(Image.FORMAT_RGBA8)


func test_los_recursos_conservan_orden_duracion_y_ritmo_idle() -> void:
	for carpeta: String in ["fede", "mia"]:
		var recurso := load("res://assets/characters/%s/idle.tres" % carpeta) as SpriteFrames
		assert_object(recurso).is_not_null()
		assert_int(recurso.get_frame_count(&"idle")).is_equal(8)
		assert_bool(recurso.get_animation_loop(&"idle")).is_true()
		assert_float(recurso.get_animation_speed(&"idle")).is_equal(2.0)
		for cuadro in 8:
			assert_float(recurso.get_frame_duration(&"idle", cuadro)).is_equal(1.0)
			assert_str(recurso.get_frame_texture(&"idle", cuadro).resource_path).is_equal(
				"res://assets/characters/%s/%02d.png" % [carpeta, cuadro + 1]
			)


func test_la_tabla_resuelve_cuatro_identidades_con_recursos_propios() -> void:
	var tabla: Dictionary = _fixture.call("tabla")
	for fila: Array in [
		[DialogosDeCompradores.Personaje.TIN, "martin"],
		[DialogosDeCompradores.Personaje.TIA, "tiago"],
		[DialogosDeCompradores.Personaje.FEDE, "fede"],
		[DialogosDeCompradores.Personaje.MIA, "mia"],
	]:
		assert_bool(tabla.has(fila[0])).is_true()
		if tabla.has(fila[0]):
			assert_str((tabla[fila[0]] as SpriteFrames).resource_path).is_equal(
				"res://assets/characters/%s/idle.tres" % fila[1]
			)


func test_cada_figura_permanece_visible_al_hablar_y_volver_al_mundo() -> void:
	for mia: bool in [false, true]:
		if not await _crear():
			return
		await _fixture.call("llegar", mia)
		var puesto: Node3D = _fixture.call("puesto")
		assert_bool(_figura().visible).is_true()
		assert_bool(puesto.get("panel").visible).is_false()
		var orientacion := _figura().global_basis
		await _foco()
		await _fixture.call("clic")
		assert_bool(puesto.get("panel").visible).is_true()
		assert_bool(_figura().visible).is_true()
		await _fixture.call("clic")
		assert_bool(puesto.get("panel").visible).is_false()
		assert_bool(_figura().visible).is_true()
		assert_bool(_figura().global_basis.is_equal_approx(orientacion)).is_true()
		assert_bool(_figura().no_depth_test).is_false()
		assert_int(_figura().billboard).is_equal(BaseMaterial3D.BILLBOARD_DISABLED)
		await _fixture.call("limpiar")


func test_el_foco_y_contorno_usan_alfa_y_frame_actual_de_ambos() -> void:
	for mia: bool in [false, true]:
		if not await _crear():
			return
		await _fixture.call("llegar", mia)
		for cuadro: int in [0, 3]:
			_figura().set_frame_and_progress(cuadro, 0.0)
			await _foco()
			var material := _figura().material_overlay as ShaderMaterial
			assert_object(material).is_not_null()
			if material != null:
				assert_object(material.get_shader_parameter("figura")).is_same(
					_figura().sprite_frames.get_frame_texture(&"idle", cuadro)
				)
			await _foco(true)
			assert_object(_figura().material_overlay).is_null()
		await _fixture.call("limpiar")


func test_cambiar_comprador_cambia_recurso_y_reinicia_sin_contorno_anterior() -> void:
	if not await _crear():
		return
	await _fixture.call("llegar")
	_figura().set_frame_and_progress(3, 0.0)
	await _foco()
	var anterior := _figura().sprite_frames
	var contorno := _figura().material_overlay
	await _fixture.call("llegar", true)
	assert_int(_figura().frame).is_zero()
	assert_object(_figura().sprite_frames).is_not_same(anterior)
	assert_str(_figura().sprite_frames.resource_path).is_equal(
		"res://assets/characters/mia/idle.tres"
	)
	await _foco()
	assert_object(_figura().material_overlay).is_not_same(contorno)


func test_pausar_entrada_y_retirada_y_reiniciar_no_duplica_imagenes() -> void:
	if not await _crear():
		return
	var local: Node3D = _fixture.get("local")
	var reloj: RelojDelTurno = local.get("_reloj")
	reloj.avanzar(30.0)
	await _fixture.call("cuadros")
	var posicion := _figura().position
	var cuadro := _figura().frame
	get_tree().paused = true
	await get_tree().create_timer(0.2, true).timeout
	assert_vector(_figura().position).is_equal(posicion)
	assert_int(_figura().frame).is_equal(cuadro)
	get_tree().paused = false
	reloj.avanzar(180.0)
	var puesto: Node3D = _fixture.call("puesto")
	var retiradas: Array = puesto.get("_retiradas")
	assert_array(retiradas).has_size(1)
	var retirada := retiradas[0] as AnimatedSprite3D
	assert_str(retirada.sprite_frames.resource_path).is_equal(
		"res://assets/characters/fede/idle.tres"
	)
	posicion = retirada.position
	cuadro = retirada.frame
	get_tree().paused = true
	await get_tree().create_timer(0.2, true).timeout
	assert_vector(retirada.position).is_equal(posicion)
	assert_int(retirada.frame).is_equal(cuadro)
	get_tree().paused = false
	assert_bool(local.get("_ciclo").abrir_la_jornada()).is_true()
	assert_array(puesto.get("_retiradas")).is_empty()
	assert_bool(_figura().visible).is_false()
	assert_object(puesto.get("_imagen_de")).is_null()


func test_el_fixture_no_modifica_las_selecciones_productivas() -> void:
	var antes: Array[Array] = []
	for jornada in range(1, 6):
		var datos: Array = []
		for comprador in Compradores.de_la_jornada(jornada):
			datos.append([comprador.nombre(), comprador.personaje, comprador.horario])
		antes.append(datos)
	if not await _crear():
		return
	await _fixture.call("llegar")
	for jornada in range(1, 6):
		var datos: Array = []
		for comprador in Compradores.de_la_jornada(jornada):
			datos.append([comprador.nombre(), comprador.personaje, comprador.horario])
		assert_array(datos).is_equal(antes[jornada - 1])


func _segmento_cruza_el_antepecho(antepecho: MeshInstance3D, ojo: Vector3, punto: Vector3) -> bool:
	var inversa := antepecho.global_transform.affine_inverse()
	var desde := inversa * ojo
	var hasta := inversa * punto
	if antepecho.get_aabb().intersects_segment(desde, hasta) == null:
		return false
	var caras := antepecho.mesh.get_faces()
	for indice in range(0, caras.size(), 3):
		if (
			Geometry3D.segment_intersects_triangle(
				desde, hasta, caras[indice], caras[indice + 1], caras[indice + 2]
			)
			!= null
		):
			return true
	return false


func _pixel_opaco_detras_del_antepecho(
	sprite: AnimatedSprite3D, antepecho: MeshInstance3D, ojos: Array[Vector3]
) -> Vector3:
	var textura := sprite.sprite_frames.get_frame_texture(&"idle", sprite.frame)
	var imagen := textura.get_image()
	var caja: AABB = (
		sprite.global_transform.affine_inverse() * antepecho.global_transform * antepecho.get_aabb()
	)
	for y in range(0, imagen.get_height(), 4):
		for x in range(imagen.get_width() / 8, imagen.get_width() * 7 / 8, 4):
			if imagen.get_pixel(x, y).a == 0.0:
				continue
			var pixel := Vector2(x, y) + Vector2.ONE * 0.5
			if sprite.flip_h:
				pixel.x = textura.get_width() - pixel.x
			if sprite.flip_v:
				pixel.y = textura.get_height() - pixel.y
			var plano := (pixel - textura.get_size() / 2.0 + sprite.offset) * sprite.pixel_size
			var local := Vector3(plano.x, -plano.y, 0.0)
			if local.y >= caja.end.y - sprite.pixel_size:
				continue
			var candidato := sprite.to_global(local)
			var tapado := true
			for ojo in ojos:
				if not _segmento_cruza_el_antepecho(antepecho, ojo, candidato):
					tapado = false
					break
			if tapado:
				return candidato
	return Vector3.INF


func test_el_antepecho_ocluye_el_corte_desde_frente_lados_y_encuadre() -> void:
	for mia: bool in [false, true]:
		if not await _crear():
			return
		await _fixture.call("llegar", mia)
		var local: Node3D = _fixture.get("local")
		var camara: Camera3D = local.get_node("Jugador/Giro/Camara")
		var puesto: Node3D = _fixture.call("puesto")
		var antepecho: MeshInstance3D = puesto.get("antepecho")
		for direccion: float in [-1.0, 0.0, 1.0]:
			var pose: Dictionary = {}
			for distancia: float in [0.65, 0.5, 0.35, 0.2]:
				pose = await _fixture.call("mirar", false, direccion * distancia)
				if pose.get("piso", false) and pose.get("capsula", false):
					break
				if direccion == 0.0:
					break
			assert_bool(pose.get("piso", false)).is_true()
			assert_bool(pose.get("capsula", false)).is_true()
			assert_bool(pose.get("objetivo", false)).is_true()
			var ojos: Array[Vector3] = [camara.global_position]
			var punto := _pixel_opaco_detras_del_antepecho(_figura(), antepecho, ojos)
			(
				assert_bool(punto.is_finite())
				. override_failure_message("No hay corte opaco tapado")
				. is_true()
			)
			if not punto.is_finite():
				return
			(
				assert_bool(_segmento_cruza_el_antepecho(antepecho, camara.global_position, punto))
				. is_true()
			)
			(
				assert_bool(
					puesto.get("objetivo").call("admite_foco_en", punto, camara.global_position)
				)
				. is_false()
			)
		await _foco()
		await _fixture.call("clic")
		await _fixture.call("cuadros", 12)
		var ojos: Array[Vector3] = [camara.global_position]
		var punto := _pixel_opaco_detras_del_antepecho(_figura(), antepecho, ojos)
		(
			assert_bool(punto.is_finite())
			. override_failure_message("El encuadre muestra el corte")
			. is_true()
		)
		if punto.is_finite():
			(
				assert_bool(_segmento_cruza_el_antepecho(antepecho, camara.global_position, punto))
				. is_true()
			)
			(
				assert_bool(
					puesto.get("objetivo").call("admite_foco_en", punto, camara.global_position)
				)
				. is_false()
			)
		assert_bool(_figura().no_depth_test).is_false()
		await _fixture.call("limpiar")
