extends GdUnitTestSuite

const RUTA_DEL_ALMACEN := "res://src/escenas/almacen.tscn"
const ENTRADA := "Estructura/puertaentrada/CuerpoDeLaHoja"

var _ruta_guardado: String


func before_test() -> void:
	_ruta_guardado = Guardado.ruta_por_defecto
	Guardado.ruta_por_defecto = "user://animacion_de_salida.guardado"
	Guardado.new().borrar()


func after_test() -> void:
	get_tree().paused = false
	Guardado.new().borrar()
	Guardado.ruta_por_defecto = _ruta_guardado


func test_salir_toma_el_control_sin_bajar_la_persiana_ni_abrir_aun() -> void:  # AC-SHF-043
	for jornada: int in [1, 2, 3]:
		var almacen: Node3D = auto_free(load(RUTA_DEL_ALMACEN).instantiate())
		almacen.set("_partida", Partida.desde({"jornada": jornada}))
		almacen.set("compradores_de_la_apertura", func(_n: int) -> Array[Comprador]: return [])
		add_child(almacen)
		var reloj: RelojDelTurno = almacen.get("_reloj")
		reloj.set_process(false)
		var jugador: Node3D = almacen.get("_jugador")
		jugador.set_physics_process(false)
		await get_tree().process_frame
		jugador.call("reanudar")
		for tarea in (almacen.get("_partida") as Partida).obligatorias():
			reloj.completar(tarea)
		var entrada: Node3D = almacen.get_node(ENTRADA)
		var persiana: PersianaDeLaNoche = almacen.get_node("Interfaz/PersianaDeLaNoche")
		var pantalla: PantallaDeDevolucion = almacen.get("_pantalla")
		assert_bool(almacen.call("_puede_salir")).is_true()
		assert_bool(entrada.call("puerta").abierta()).is_false()
		assert_bool(persiana.visible).is_false()
		assert_bool(pantalla.visible).is_false()
		entrada.call("accionar")
		assert_bool(jugador.call("suspendido")).is_true()
		assert_bool(persiana.visible).is_false()
		assert_bool(pantalla.visible).is_false()
		assert_bool(entrada.call("puerta").abierta()).is_false()
