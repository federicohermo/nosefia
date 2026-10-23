extends GdUnitTestSuite

const RelojDePrueba := preload("res://test/reloj_de_prueba.gd")
const PERSONAJE := DialogosDeCompradores.Personaje
const FIGURAS := {
	PERSONAJE.TIN: "res://assets/characters/martin/idle.tres",
	PERSONAJE.TIA: "res://assets/characters/tiago/idle.tres",
	PERSONAJE.FEDE: "res://assets/characters/fede/idle.tres",
	PERSONAJE.MIA: "res://assets/characters/mia/idle.tres",
	PERSONAJE.CAMI: "res://assets/characters/cami/idle.tres",
}

var _almacenes: Array[Node3D] = []
var _ruta_anterior: String


func before_test() -> void:
	_ruta_anterior = Guardado.ruta_por_defecto
	Guardado.ruta_por_defecto = "user://atencion_459_prueba.guardado"
	Guardado.new().borrar()


func after_test() -> void:
	get_tree().paused = false
	for almacen in _almacenes:
		for tipo: String in ["AudioStreamPlayer", "AudioStreamPlayer3D"]:
			for audio: Node in almacen.find_children("*", tipo, true, false):
				audio.call("stop")
				audio.set("stream", null)
		almacen.queue_free()
	_almacenes.clear()
	for cuadro in 4:
		await get_tree().process_frame
	Guardado.new().borrar()
	Guardado.ruta_por_defecto = _ruta_anterior


func _abrir(jornada: int) -> Node3D:
	assert_str(Guardado.ruta_por_defecto).is_not_equal(Guardado.RUTA_DEL_USUARIO)
	var almacen: Node3D = load("res://src/escenas/almacen.tscn").instantiate()
	almacen.set("_partida", Partida.desde({"jornada": jornada, "medios": 0}))
	_almacenes.append(almacen)
	add_child(almacen)
	almacen.get_node("Jugador").set_physics_process(false)
	almacen.get("_reloj").set_process(false)
	for cuadro in 3:
		await get_tree().physics_frame
	return almacen


func _ir_al_segundo(almacen: Node3D, segundo: float) -> void:
	var reloj: RelojDelTurno = almacen.get("_reloj")
	var turno: Turno = reloj.get("_turno")
	var consumido := Reglas.DURACION_DEL_TURNO - turno.tiempo_restante()
	RelojDePrueba.avanzar_turno(reloj, maxf(0.0, segundo - consumido))


func _ids(compradores: Array[Comprador]) -> Array:
	var ids: Array = []
	for comprador in compradores:
		for producto in comprador.pedido().productos():
			ids.append(producto.id)
	return ids


func test_cada_noche_muestra_a_sus_compradores_en_su_horario() -> void:  # AC-CTR-070
	for jornada in range(
		ReglasDeLaPartida.PRIMERA_JORNADA + 2, ReglasDeLaPartida.PRIMERA_JORNADA + 5
	):
		var almacen := await _abrir(jornada)
		var ventanilla: Node3D = almacen.get_node("Estructura/Ventanilla")
		var atenciones: Ventanilla = almacen.get("_atenciones")
		var sprite: AnimatedSprite3D = ventanilla.get("comprador_visible")
		var esperados := Compradores.de_la_jornada(jornada, almacen.get("_partida").semilla)
		for esperado in esperados:
			_ir_al_segundo(almacen, esperado.horario.x)
			var atendida := atenciones.atencion()
			assert_str(atendida.comprador().nombre()).is_equal(esperado.nombre())
			assert_int(atendida.comprador().personaje).is_equal(esperado.personaje)
			assert_bool(sprite.visible).is_true()
			assert_str(sprite.sprite_frames.resource_path).is_equal(FIGURAS[esperado.personaje])
			if esperado.horario.y < Reglas.DURACION_DEL_TURNO:
				_ir_al_segundo(almacen, esperado.horario.y)
				assert_bool(atendida.despachada()).is_true()
				assert_bool(atendida.vendida()).is_false()
				assert_bool(sprite.visible).is_false()
		var compradores: Array[Comprador] = atenciones.tarea().get("_compradores")
		assert_array(_ids(compradores)).is_equal(_ids(esperados))
