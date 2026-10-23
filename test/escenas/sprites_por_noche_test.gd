## Los cuadros de los compradores se cargan y se leen por noche: sólo los de quienes la atienden.
##
## En la web, leer el alfa de un cuadro espera a la GPU, y la carga entera no puede pagar los
## cuadros de personajes que la noche no usa. Qué personajes atienden cada noche lo contesta
## `Compradores`; acá se afirma que la escena carga y lee eso, lo suelta al pasar de noche, y no
## se rompe con un personaje que el dominio no puso en la noche.
extends GdUnitTestSuite

const RelojDePrueba := preload("res://test/reloj_de_prueba.gd")
const PERSONAJE := DialogosDeCompradores.Personaje

var _almacenes: Array[Node3D] = []
var _ruta_anterior: String


func before_test() -> void:
	_ruta_anterior = Guardado.ruta_por_defecto
	Guardado.ruta_por_defecto = "user://sprites_por_noche_prueba.guardado"
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


func _abrir(jornada: int, compradores: Callable = Callable()) -> Node3D:
	assert_str(Guardado.ruta_por_defecto).is_not_equal(Guardado.RUTA_DEL_USUARIO)
	var almacen: Node3D = load("res://src/escenas/almacen.tscn").instantiate()
	almacen.set("_partida", Partida.desde({"jornada": jornada, "medios": 0}))
	if compradores.is_valid():
		almacen.set("compradores_de_la_apertura", compradores)
	_almacenes.append(almacen)
	add_child(almacen)
	almacen.get_node("Jugador").set_physics_process(false)
	almacen.get("_reloj").set_process(false)
	await _cuadros()
	return almacen


func _cuadros() -> void:
	for cuadro in 3:
		await get_tree().physics_frame


func _tabla() -> Dictionary:
	var script: Script = load("res://src/escenas/puestos/ventanilla.gd")
	return script.get_script_constant_map()["ANIMACIONES"]


func _puesto(almacen: Node3D) -> Node3D:
	return almacen.get_node("Estructura/Ventanilla")


## Las rutas de las texturas cuya imagen se leyó, ordenadas.
func _leidas(almacen: Node3D) -> Array[String]:
	var imagenes: Dictionary = _puesto(almacen).get("objetivo").get("_imagenes")
	var rutas: Array[String] = []
	for textura: Texture2D in imagenes:
		rutas.append(textura.resource_path)
	rutas.sort()
	return rutas


## Las rutas de todos los cuadros de los personajes, ordenadas.
func _cuadros_de(personajes: Array) -> Array[String]:
	var rutas: Array[String] = []
	for personaje: int in personajes:
		var cuadros := load(_tabla()[personaje]) as SpriteFrames
		for animacion: StringName in cuadros.get_animation_names():
			for indice: int in cuadros.get_frame_count(animacion):
				rutas.append(cuadros.get_frame_texture(animacion, indice).resource_path)
	rutas.sort()
	return rutas


func _en_la_memoria(personaje: int) -> bool:
	return ResourceLoader.has_cached(_tabla()[personaje])


func _cambiar_de_noche(almacen: Node3D) -> void:
	var partida: Partida = almacen.get("_partida")
	partida.cerrar_la_jornada(partida.obligatorias().size())
	assert_bool(almacen.get("_ciclo").abrir_la_jornada()).is_true()
	await _cuadros()


func _con_fede(_jornada: int) -> Array[Comprador]:
	var compradores := Compradores.segunda_jornada_definida()
	compradores.resize(1)
	return compradores


func test_la_primera_noche_lee_los_cuadros_de_tin_y_tia_y_ningun_otro() -> void:
	var almacen := await _abrir(ReglasDeLaPartida.PRIMERA_JORNADA)
	var leidas := _leidas(almacen)
	assert_array(leidas).is_equal(_cuadros_de([PERSONAJE.TIN, PERSONAJE.TIA]))
	for personaje: int in [PERSONAJE.FEDE, PERSONAJE.MIA, PERSONAJE.CAMI]:
		assert_bool(_en_la_memoria(personaje)).is_false()


func test_cada_noche_lee_los_cuadros_de_los_personajes_que_dice_el_dominio() -> void:
	var jornada := ReglasDeLaPartida.PRIMERA_JORNADA + 2
	var almacen := await _abrir(jornada)
	assert_array(_leidas(almacen)).is_equal(_cuadros_de(Compradores.personajes_de(jornada)))


func test_una_noche_sin_comprador_con_sprite_no_lee_ni_carga_ningun_cuadro() -> void:
	var almacen := await _abrir(ReglasDeLaPartida.PRIMERA_JORNADA + 5)
	assert_array(_leidas(almacen)).is_empty()
	for personaje: int in _tabla():
		assert_bool(_en_la_memoria(personaje)).is_false()


func test_pasar_de_noche_suelta_a_los_personajes_que_ya_no_atienden() -> void:
	var tercera := ReglasDeLaPartida.PRIMERA_JORNADA + 2
	var cuarta := tercera + 1
	var almacen := await _abrir(tercera)
	assert_bool(_en_la_memoria(PERSONAJE.CAMI)).is_true()
	await _cambiar_de_noche(almacen)
	assert_array(_leidas(almacen)).is_equal(_cuadros_de(Compradores.personajes_de(cuarta)))
	assert_bool(_en_la_memoria(PERSONAJE.CAMI)).is_false()
	assert_bool(_en_la_memoria(PERSONAJE.TIN)).is_false()
	assert_bool(_en_la_memoria(PERSONAJE.FEDE)).is_true()


func test_reintentar_la_noche_conserva_las_imagenes_que_ya_se_leyeron() -> void:
	var almacen := await _abrir(ReglasDeLaPartida.PRIMERA_JORNADA)
	var objetivo: Node = _puesto(almacen).get("objetivo")
	var antes: Dictionary = objetivo.get("_imagenes").duplicate()
	assert_bool(almacen.get("_ciclo").abrir_la_jornada()).is_true()
	await _cuadros()
	var despues: Dictionary = objetivo.get("_imagenes")
	assert_int(despues.size()).is_equal(antes.size())
	for textura: Texture2D in antes:
		assert_object(despues.get(textura)).is_same(antes[textura])


func test_un_personaje_fuera_de_la_noche_se_muestra_y_se_suelta_a_la_noche_siguiente() -> void:
	var almacen := await _abrir(ReglasDeLaPartida.PRIMERA_JORNADA, _con_fede)
	assert_bool(_en_la_memoria(PERSONAJE.FEDE)).is_false()
	RelojDePrueba.avanzar_hasta(almacen.get("_reloj"), Vector2i(21, 15))
	await _cuadros()
	var figura: AnimatedSprite3D = _puesto(almacen).get("comprador_visible")
	assert_bool(figura.visible).is_true()
	assert_str(figura.sprite_frames.resource_path).is_equal(_tabla()[PERSONAJE.FEDE])
	assert_bool(almacen.get("_ciclo").abrir_la_jornada()).is_true()
	await _cuadros()
	assert_bool(_en_la_memoria(PERSONAJE.FEDE)).is_false()
