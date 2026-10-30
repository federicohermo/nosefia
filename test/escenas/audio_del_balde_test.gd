## Cómo suena el balde del local según tenga agua o no: al llenarlo, vaciarlo y abrir otra noche.
## Se afirma qué se pidió al reproductor: el driver de los tests no mezcla.
extends GdUnitTestSuite

const ESCENA_DEL_ALMACEN := "res://src/escenas/almacen.tscn"
const REPRODUCTOR := "Servicios/AudioDelAlmacen/Reproductor"
const ALZAR_VACIO := "SFX_OBJETO_Balde_AlzarVacio"
const ALZAR_LLENO := "SFX_OBJETO_Balde_Alzar"

var _almacen: Node3D
var _balde: RigidBody3D
var _agarre: Agarre
var _limpiador: Limpiador
var _reproductor: ReproductorDeSonidos


func before_test() -> void:
	_almacen = auto_free(load(ESCENA_DEL_ALMACEN).instantiate())
	add_child(_almacen)
	await get_tree().physics_frame
	(_almacen.get("_jugador") as Node3D).set_physics_process(false)
	_balde = _almacen.get_node("Objetos/Balde")
	_agarre = _almacen.get("_agarre")
	_limpiador = _almacen.get("_limpiador")
	_reproductor = _almacen.get_node(REPRODUCTOR)


## El audio que suena al agarrar el balde ahora, y lo suelta para el gesto siguiente.
func _alzar() -> Array:
	_reproductor.silenciar()
	assert_bool(_agarre.pedir_agarrar(_balde.get("datos"), _balde)).is_true()
	var nombres := []
	for voz in _reproductor.voces_en_el_espacio():
		if voz.stream != null:
			nombres.append(voz.stream.resource_path.get_file().get_basename())
	return nombres


## El audio de un contacto del balde ahora.
func _dejar() -> Array:
	_reproductor.silenciar()
	_reproductor.recibir(EntradaSonora.Evento.OBJETO_SOLTADO, _balde, 3.0)
	var nombres := []
	for voz in _reproductor.voces_en_el_espacio():
		if voz.stream != null:
			nombres.append(voz.stream.resource_path.get_file().get_basename())
	return nombres


func _usar(usado: StringName, sobre: StringName) -> void:
	_limpiador.usar(usado, sobre)


func test_el_balde_vacio_suena_vacio_al_agarrarlo_y_al_dejarlo() -> void:
	assert_array(_alzar()).contains_exactly([ALZAR_VACIO])
	assert_array(_dejar()).contains_exactly(["SFX_OBJETO_Balde_DejarVacio"])


func test_llenarlo_lo_hace_sonar_con_agua_y_vaciarlo_lo_devuelve_a_vacio() -> void:
	var id := ReglasDeLaLimpieza.ID_DEL_BALDE
	_alzar()
	_usar(id, ReglasDeLaLimpieza.ID_DEL_LAVATORIO)
	_agarre.soltar(false)
	assert_array(_alzar()).contains_exactly([ALZAR_LLENO])
	assert_array(_dejar()).contains_exactly(["SFX_OBJETO_Balde_Dejar"])
	_usar(id, ReglasDeLaLimpieza.ID_DEL_INODORO)
	_agarre.soltar(false)
	assert_array(_alzar()).contains_exactly([ALZAR_VACIO])


func test_con_cada_jabon_el_agua_tenida_suena_como_con_agua() -> void:
	var id := ReglasDeLaLimpieza.ID_DEL_BALDE
	for jabon: StringName in ReglasDeLaLimpieza.JABONES:
		_limpiador.arrancar(PisoDelLocal.de_la_jornada(1))
		_almacen.get("_limpieza").call("reiniciar")
		_usar(id, ReglasDeLaLimpieza.ID_DEL_LAVATORIO)
		_usar(jabon, id)
		assert_array(_alzar()).contains_exactly([ALZAR_LLENO])
		_agarre.soltar(false)


func test_abrir_otra_noche_con_el_balde_lleno_lo_deja_sonar_vacio() -> void:
	_usar(ReglasDeLaLimpieza.ID_DEL_BALDE, ReglasDeLaLimpieza.ID_DEL_LAVATORIO)
	assert_array(_alzar()).contains_exactly([ALZAR_LLENO])
	_agarre.soltar(false)
	_limpiador.arrancar(PisoDelLocal.de_la_jornada(1))
	_almacen.get("_limpieza").call("reiniciar")
	assert_array(_alzar()).contains_exactly([ALZAR_VACIO])


func test_los_datos_compartidos_del_balde_no_cambian_con_su_estado() -> void:
	var datos: ObjetoDelAlmacen = _balde.get("datos")
	var antes := datos.sonoridad
	_usar(ReglasDeLaLimpieza.ID_DEL_BALDE, ReglasDeLaLimpieza.ID_DEL_LAVATORIO)
	assert_int(datos.sonoridad).is_equal(antes)
