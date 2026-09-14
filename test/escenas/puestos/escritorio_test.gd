## El escritorio que se ve: su cableado, su contrato de interacción y cómo se sale.
##
## **La escena se instancia y no se entra al árbol**, igual que las otras suites de `escenas/`.
extends GdUnitTestSuite

const SCRIPT := "res://src/escenas/puestos/escritorio.gd"
const ESCENA_DEL_ALMACEN := "res://src/escenas/almacen.tscn"
const ESCENA_DEL_JUGADOR := "res://src/escenas/jugador.tscn"
const ESCENA_DE_LA_PANTALLA := "res://src/ui/diegetica/pantalla_de_computadora.tscn"

## El script del puesto se preloadea para poder tiparlo: los scripts de `escenas/` son cáscara y
## no declaran `class_name`.
const EscritorioQueSeVe := preload("res://src/escenas/puestos/escritorio.gd")


func _escritorio() -> EscritorioQueSeVe:
	var almacen: Node3D = auto_free(load(ESCENA_DEL_ALMACEN).instantiate())
	return almacen.get_node("Estructura/compu/StaticBody3D")


func test_el_escritorio_esta_en_el_grupo_que_la_mira_puede_enfocar() -> void:  # 009-AC9
	var escritorio := _escritorio()
	assert_bool(escritorio.is_in_group(ReglasDelJugador.GRUPO_INTERACTUABLE)).is_true()
	assert_bool(escritorio.has_method(ReglasDeLosObjetos.METODO_INTERACTUAR)).is_true()


func test_el_almacen_instancia_el_escritorio_exactamente_una_vez() -> void:  # 009-AC9
	var almacen: Node3D = auto_free(load(ESCENA_DEL_ALMACEN).instantiate())
	var cantidad := 0
	for cuerpo in almacen.find_children("*", "StaticBody3D", true, false):
		if cuerpo.get_script() == EscritorioQueSeVe:
			cantidad += 1
	assert_int(cantidad).is_equal(1)


func test_el_escritorio_recibe_al_jugador_y_al_reloj_por_export() -> void:  # 009-AC10
	# Y **ningún `get_node(`**: una escena que se reacomoda rompe la ruta sin que nada avise
	# hasta que se corre.
	var texto := FileAccess.get_file_as_string(SCRIPT)
	assert_str(texto).is_not_empty()
	for propiedad in ["@export var jugador", "@export var reloj"]:
		(
			assert_bool(texto.contains(propiedad))
			. override_failure_message("`escritorio.gd` no declara `%s`" % propiedad)
			. is_true()
		)
	(
		assert_bool(texto.contains("get_node("))
		. override_failure_message("`escritorio.gd` sale a buscar un nodo por ruta")
		. is_false()
	)


func test_el_jugador_expone_las_dos_lineas_que_este_spec_necesita() -> void:  # 009-AC10
	# **Rojo si el 004 aterriza sin exponerlas**: su `ControlDelJugador` vive privado adentro de
	# `jugador.gd`, y sin estas dos puertas abrir la computadora degradaría en silencio — el
	# mouse seguiría girando la cámara y el jugador seguiría caminando detrás del panel.
	var jugador: Node3D = auto_free(load(ESCENA_DEL_JUGADOR).instantiate())
	assert_bool(jugador.has_method("suspender")).is_true()
	assert_bool(jugador.has_method("reanudar")).is_true()


func test_del_escritorio_se_sale_con_el_clic_derecho_y_no_con_cancelar() -> void:  # 009-AC10
	var texto := FileAccess.get_file_as_string(SCRIPT)
	(
		assert_bool(texto.contains("ReglasDelJugador.ACCION_USAR"))
		. override_failure_message("`escritorio.gd` no sale con el clic derecho")
		. is_true()
	)
	(
		assert_bool(texto.contains("ui_cancel"))
		. override_failure_message("`escritorio.gd` comparte la tecla del cursor")
		. is_false()
	)


func test_el_clic_derecho_llega_aunque_la_pantalla_tape_el_viewport() -> void:  # 009-AC10
	# **Medido en 4.7.2**: el fondo de la pantalla es un `ColorRect` a pantalla completa y un
	# `Control` trae `MOUSE_FILTER_STOP` por defecto, así que se come el botón del mouse. Con el
	# gesto escrito en el callback que corre después de la interfaz, la computadora se abría y no
	# se cerraba nunca: el jugador quedaba suspendido detrás del panel hasta que cerrara la noche,
	# con el `MOUSE_BUTTON_RIGHT` escrito y los seis nodos en verde.
	var pantalla: CanvasLayer = auto_free(load(ESCENA_DE_LA_PANTALLA).instantiate())
	var fondo := pantalla.get_node("Fondo") as Control
	(
		assert_int(fondo.mouse_filter)
		. override_failure_message("el fondo dejó de tapar el viewport: revisar por qué")
		. is_equal(Control.MOUSE_FILTER_STOP)
	)
	var texto := FileAccess.get_file_as_string(SCRIPT)
	(
		assert_bool(texto.contains("func _unhandled_input("))
		. override_failure_message("el clic derecho no llega: la interfaz se lo come antes")
		. is_false()
	)


func test_el_cierre_usa_la_accion_compartida() -> void:  # 009-AC10 034-AC1
	assert_bool(InputMap.has_action(ReglasDelJugador.ACCION_USAR)).is_true()


func test_tocar_el_escritorio_suspende_al_jugador_y_no_entrega_nada() -> void:  # 009-AC10
	var escritorio := _escritorio()
	var jugador: Node3D = auto_free(load(ESCENA_DEL_JUGADOR).instantiate())
	var obligatorias := Apertura.obligatorias()
	var reloj: RelojDelTurno = auto_free(RelojDelTurno.new())
	reloj.arrancar(Apertura.turno_de_la_jornada(obligatorias), obligatorias)
	var computadora: ComputadoraDeEscritorio = auto_free(ComputadoraDeEscritorio.new())
	computadora.reloj = reloj
	computadora.arrancar(
		CajaRegistradora.new(
			Apertura.inventario_de_la_jornada(), CajaRegistradora.productos_del_dia()
		)
	)
	escritorio.jugador = jugador
	escritorio.reloj = reloj
	escritorio.computadora = computadora

	assert_object(escritorio.call(ReglasDeLosObjetos.METODO_INTERACTUAR)).is_null()
	assert_bool(computadora.computadora().abierta()).is_true()
