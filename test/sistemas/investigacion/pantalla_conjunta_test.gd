## La pantalla conjunta de la computadora y el celular: quién la pide, cuándo avisa y qué no cuesta.
extends GdUnitTestSuite

const JORNADA := QuejasDeLaJornada.JORNADA

var _cambios: Array[bool] = []
var _orden: Array[String] = []


func before_test() -> void:
	_cambios.clear()
	_orden.clear()


func _escritorio(con_la_conjunta: bool) -> ComputadoraDeEscritorio:
	var tareas := Apertura.obligatorias(JORNADA)
	var reloj: RelojDelTurno = auto_free(RelojDelTurno.new())
	reloj.arrancar(Apertura.turno_de_la_jornada(tareas), tareas)
	var inventario := Inventario.new(Catalogo.todos())
	var compradores: Array[Comprador] = []
	var atender := TareaDeAtender.new(compradores, inventario)
	var escritorio: ComputadoraDeEscritorio = auto_free(ComputadoraDeEscritorio.new())
	escritorio.reloj = reloj
	escritorio.arrancar(RegistroDeVentas.new(Catalogo.todos(), atender), con_la_conjunta)
	escritorio.pantalla_conjunta_cambiada.connect(
		func(activa: bool) -> void:
			_cambios.append(activa)
			_orden.append("conjunta")
	)
	escritorio.computadora_cerrada.connect(func() -> void: _orden.append("cerrada"))
	return escritorio


func test_el_boton_alterna_entre_la_pantalla_normal_y_la_conjunta() -> void:  # AC-INV-149
	var escritorio := _escritorio(true)
	escritorio.pedir_abrir()
	assert_bool(escritorio.computadora().conjunta()).is_false()
	escritorio.pedir_alternar_la_conjunta()
	assert_bool(escritorio.computadora().conjunta()).is_true()
	escritorio.pedir_alternar_la_conjunta()
	assert_bool(escritorio.computadora().conjunta()).is_false()
	assert_array(_cambios).contains_exactly([true, false])


func test_con_la_computadora_cerrada_no_alterna_nada() -> void:  # AC-INV-149
	var escritorio := _escritorio(true)
	escritorio.pedir_alternar_la_conjunta()
	assert_bool(escritorio.computadora().conjunta()).is_false()
	assert_array(_cambios).is_empty()


func test_una_jornada_que_no_la_ofrece_ignora_el_pedido() -> void:  # AC-INV-149
	var escritorio := _escritorio(false)
	escritorio.pedir_abrir()
	escritorio.pedir_alternar_la_conjunta()
	assert_bool(escritorio.computadora().conjunta()).is_false()
	assert_array(_cambios).is_empty()


func test_cerrar_la_computadora_vuelve_a_la_normal_antes_de_cerrarse() -> void:  # AC-INV-149
	var escritorio := _escritorio(true)
	escritorio.pedir_abrir()
	escritorio.pedir_alternar_la_conjunta()
	escritorio.pedir_cerrar()
	assert_array(_orden).contains_exactly(["conjunta", "conjunta", "cerrada"])
	assert_array(_cambios).contains_exactly([true, false])
	escritorio.pedir_abrir()
	assert_bool(escritorio.computadora().conjunta()).is_false()


func test_el_celular_cerrado_con_esc_devuelve_la_pantalla_normal() -> void:  # AC-INV-149
	var escritorio := _escritorio(true)
	escritorio.pedir_abrir()
	escritorio.pedir_volver_a_la_normal()
	assert_array(_cambios).is_empty()
	escritorio.pedir_alternar_la_conjunta()
	escritorio.pedir_volver_a_la_normal()
	assert_bool(escritorio.computadora().conjunta()).is_false()
	assert_array(_cambios).contains_exactly([true, false])


func test_alternar_no_descuenta_ni_suma_tiempo() -> void:  # AC-INV-149
	var escritorio := _escritorio(true)
	var antes := escritorio.reloj.obligatoria(Tarea.Tipo.REGISTRAR).completada()
	escritorio.pedir_abrir()
	var restante := escritorio.reloj.hora()
	escritorio.pedir_alternar_la_conjunta()
	escritorio.pedir_alternar_la_conjunta()
	assert_str(escritorio.reloj.hora()).is_equal(restante)
	assert_bool(escritorio.reloj.obligatoria(Tarea.Tipo.REGISTRAR).completada()).is_equal(antes)
