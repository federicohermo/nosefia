## Qué frena al correr en el almacén real: la caja grande y el balde con agua, y nada más. La regla
## se prueba en `velocidad_al_correr_test.gd`; acá, que el cuerpo en la mano contesta lo que el
## dominio pregunta.
extends GdUnitTestSuite

const ESCENA_DEL_ALMACEN := "res://src/escenas/almacen.tscn"
const CUADRO := 1.0 / 60.0

var _almacen: Node3D
var _jugador: CharacterBody3D
var _agarre: Agarre
var _limpiador: Limpiador


func before_test() -> void:
	_almacen = auto_free(load(ESCENA_DEL_ALMACEN).instantiate())
	add_child(_almacen)
	await get_tree().physics_frame
	_jugador = _almacen.get("_jugador")
	_jugador.set_physics_process(false)
	_jugador.get("_control").reanudar()
	_agarre = _almacen.get("_agarre")
	_limpiador = _almacen.get("_limpiador")


func after_test() -> void:
	Input.action_release(ReglasDelJugador.ACCION_CORRER)
	Input.action_release(ReglasDelJugador.ACCION_ADELANTE)


func _balde() -> RigidBody3D:
	return _almacen.get_node("Objetos/Balde")


func _caja_de(producto: Producto.Id) -> RigidBody3D:
	var caja: RigidBody3D = _almacen.get("_cajas_de_productos")[0]
	caja.set("producto", producto)
	return caja


func _llevar(cuerpo: RigidBody3D) -> void:
	assert_bool(_agarre.pedir_agarrar(cuerpo.get("datos"), cuerpo)).is_true()


## Cuánto acelera correr con lo que hay en la mano: la velocidad que el jugador le pide al cuerpo.
func _rapidez_corriendo() -> float:
	Input.action_press(ReglasDelJugador.ACCION_ADELANTE)
	Input.action_press(ReglasDelJugador.ACCION_CORRER)
	var velocidad: Vector3 = _jugador.call("_velocidad_horizontal")
	return velocidad.length()


func test_el_balde_con_agua_frena_y_vacio_no() -> void:  # AC-PLY-193
	var libre := ReglasDelJugador.VELOCIDAD_DE_CAMINATA * ReglasDelJugador.MULTIPLICADOR_DE_CORRER
	var frenado := (
		ReglasDelJugador.VELOCIDAD_DE_CAMINATA * ReglasDelJugador.MULTIPLICADOR_DE_CORRER_CON_PESO
	)
	_llevar(_balde())
	assert_float(_rapidez_corriendo()).is_equal_approx(libre, 1e-3)
	_limpiador.usar(ReglasDeLaLimpieza.ID_DEL_BALDE, ReglasDeLaLimpieza.ID_DEL_LAVATORIO)
	assert_float(_rapidez_corriendo()).is_equal_approx(frenado, 1e-3)
	_limpiador.usar(ReglasDeLaLimpieza.ID_DEL_BALDE, ReglasDeLaLimpieza.ID_DEL_INODORO)
	assert_float(_rapidez_corriendo()).is_equal_approx(libre, 1e-3)


func test_la_caja_grande_frena_y_la_chica_no() -> void:  # AC-PLY-193
	var libre := ReglasDelJugador.VELOCIDAD_DE_CAMINATA * ReglasDelJugador.MULTIPLICADOR_DE_CORRER
	var frenado := (
		ReglasDelJugador.VELOCIDAD_DE_CAMINATA * ReglasDelJugador.MULTIPLICADOR_DE_CORRER_CON_PESO
	)
	var chica: Producto.Id = (
		Catalogo
		. todos()
		. filter(
			func(p: Producto) -> bool: return Catalogo.caja_de(p.id) == Catalogo.TamanoDeCaja.CHICA
		)[0]
		. id
	)
	var grande: Producto.Id = (
		Catalogo
		. todos()
		. filter(
			func(p: Producto) -> bool: return Catalogo.caja_de(p.id) == Catalogo.TamanoDeCaja.GRANDE
		)[0]
		. id
	)
	var caja := _caja_de(chica)
	_llevar(caja)
	assert_float(_rapidez_corriendo()).is_equal_approx(libre, 1e-3)
	caja.set("producto", grande)
	assert_float(_rapidez_corriendo()).is_equal_approx(frenado, 1e-3)
