## La ventanilla que se ve: su cableado, su contrato de interacción y lo que tiene prohibido.
##
## **La escena se instancia y no se entra al árbol**, igual que las otras suites de `escenas/`.
extends GdUnitTestSuite

const ESCENA := "res://src/escenas/puestos/ventanilla.tscn"
const SCRIPT := "res://src/escenas/puestos/ventanilla.gd"
const ESCENA_DEL_ALMACEN := "res://src/escenas/almacen.tscn"
const ESCENA_DEL_JUGADOR := "res://src/escenas/jugador.tscn"
const ESCENA_DEL_PANEL := "res://src/ui/diegetica/panel_de_la_ventanilla.tscn"

## El script del puesto se preloadea para poder tiparlo: los scripts de `escenas/` son cáscara y
## no declaran `class_name`.
const VentanillaQueSeVe := preload("res://src/escenas/puestos/ventanilla.gd")

## Lo que escribiría la posición del jugador desde afuera. El 004 aplica su yaw por cuadro, así
## que escribirlo acá lo desincroniza del dominio y al reanudar la cámara salta al yaw viejo.
const ESCRITURAS_PROHIBIDAS := [
	"jugador.transform", "jugador.position", "jugador.rotation", "jugador.global_position"
]


func _ventanilla() -> VentanillaQueSeVe:
	return auto_free(load(ESCENA).instantiate())


func test_la_ventanilla_esta_en_el_grupo_que_la_mira_puede_enfocar() -> void:  # 013-AC12
	# Sin el grupo, el rayo del 004 la ve y el jugador no: la mira no la marca como algo con lo
	# que se puede interactuar, y el jugador no tiene cómo enterarse de que ahí se atiende.
	var ventanilla := _ventanilla()
	assert_bool(ventanilla.is_in_group(ReglasDelJugador.GRUPO_INTERACTUABLE)).is_true()
	assert_bool(ventanilla.has_method(ReglasDeLosObjetos.METODO_INTERACTUAR)).is_true()


func test_la_ventanilla_recibe_al_jugador_y_al_reloj_por_export() -> void:  # 013-AC12
	# Los dos por `@export` y no por `get_node()` hacia arriba: una escena que se reacomoda
	# rompe la ruta sin que nada avise hasta que se corre.
	var texto := FileAccess.get_file_as_string(SCRIPT)
	assert_str(texto).is_not_empty()
	for propiedad in ["@export var jugador", "@export var reloj"]:
		(
			assert_bool(texto.contains(propiedad))
			. override_failure_message("`ventanilla.gd` no declara `%s`" % propiedad)
			. is_true()
		)


func test_la_ventanilla_sale_con_la_tecla_de_cancelar() -> void:  # 013-AC12
	# Es la misma salida que el resto del juego, y la única que no depende de que el jugador
	# encuentre un botón mientras la cámara está clavada.
	var texto := FileAccess.get_file_as_string(SCRIPT)
	assert_bool(texto.contains("ui_cancel")).is_true()


func test_la_ventanilla_no_le_escribe_el_transform_al_jugador() -> void:  # 013-AC12
	# Suspender **es** clavar la cámara: la puerta del 004 alcanza, y escribir la pose por
	# encima la desincroniza del dominio sin que ningún gate lo diga.
	var texto := FileAccess.get_file_as_string(SCRIPT)
	for escritura: String in ESCRITURAS_PROHIBIDAS:
		(
			assert_bool(texto.contains(escritura))
			. override_failure_message("`ventanilla.gd` escribe `%s`" % escritura)
			. is_false()
		)


func test_el_almacen_instancia_la_ventanilla_exactamente_una_vez() -> void:  # 013-AC12
	# Se cuenta sobre el texto del `.tscn` y no sobre el árbol instanciado porque lo que hay que
	# afirmar es que se referencia **una sola vez**: dos ventanillas serían dos tareas de atender
	# corriendo sobre el mismo turno, y el jefe contaría una sola.
	var texto := FileAccess.get_file_as_string(
		"res://src/escenas/puestos/estructura_del_almacen.tscn"
	)
	assert_str(texto).is_not_empty()
	assert_int(texto.count(ESCENA)).is_equal(1)


func test_tocar_la_ventanilla_clava_al_jugador_y_no_entrega_nada_para_levantar() -> void:
	# 013-AC12
	# Devuelve `null` a propósito: si contestara un objeto, el clic del 006 se llevaría la
	# ventanilla en la mano en vez de abrir la atención. Y suspender **es** clavar la cámara: el
	# `ControlDelJugador` del 004 deja de girar y de caminar con eso solo.
	var ventanilla := _ventanilla()
	var jugador: Node3D = auto_free(load(ESCENA_DEL_JUGADOR).instantiate())
	var atenciones: Ventanilla = auto_free(Ventanilla.new())
	var obligatorias := Apertura.obligatorias()
	var reloj: RelojDelTurno = auto_free(RelojDelTurno.new())
	reloj.arrancar(Apertura.turno_de_la_jornada(obligatorias), obligatorias)
	atenciones.reloj = reloj
	atenciones.arrancar(TareaDeAtender.new(Compradores.de_la_jornada(), Inventario.new([])))
	ventanilla.jugador = jugador
	ventanilla.reloj = reloj
	ventanilla.atenciones = atenciones
	var pose := jugador.transform

	assert_object(ventanilla.call(ReglasDeLosObjetos.METODO_INTERACTUAR)).is_null()
	assert_object(atenciones.atencion()).is_not_null()
	assert_that(jugador.transform).is_equal(pose)


func test_el_cableado_de_atender_llega_entero_desde_el_almacen() -> void:  # 013-AC12
	# Un `@export` de tipo `Node` en una escena escrita a mano va declarado ADEMÁS en el
	# `node_paths` del tag del nodo, o queda en `null`: la escena carga sin un solo error, los
	# seis nodos dan verde, y el juego muere en el primer cuadro con un
	# `Nonexistent function … in base 'Nil'` que no nombra ni al `.tscn` ni al `@export`.
	#
	# Los tres niveles se afirman juntos porque la trampa es la misma en los tres: la raíz, el
	# puesto instanciado que apunta afuera de su sub-escena, y el nodo de `sistemas/` que cuelga
	# suelto de la raíz. Contar la instancia no alcanza: una ventanilla instanciada sin su
	# `node_paths` está en la escena y no atiende a nadie.
	var almacen: Node3D = auto_free(load(ESCENA_DEL_ALMACEN).instantiate())
	(
		assert_object(almacen.get("_atenciones"))
		. override_failure_message(
			"`_atenciones` quedó en null: falta en el `node_paths` de la raíz"
		)
		. is_not_null()
	)
	var puesto: VentanillaQueSeVe = almacen.get_node("Estructura/Ventanilla")
	for propiedad in ["jugador", "reloj", "atenciones", "panel"]:
		(
			assert_object(puesto.get(propiedad))
			. override_failure_message(
				"`Ventanilla.%s` quedó en null: falta en su `node_paths`" % propiedad
			)
			. is_not_null()
		)
	var atenciones: Ventanilla = almacen.get_node("Servicios/Atenciones")
	assert_object(atenciones.reloj).is_not_null()


func test_el_panel_de_la_ventanilla_llega_con_sus_seis_nodos() -> void:  # 013-AC12
	# Una sub-escena instanciada necesita su `script` declarado en su propio `.tscn`: sin él, el
	# `@export` que la apunta desde afuera queda en `null` **con el `node_paths` de la raíz bien
	# escrito**, y se diagnostica mal porque se revisa el `node_paths`, que está bien.
	var panel: PanelDeLaVentanilla = auto_free(load(ESCENA_DEL_PANEL).instantiate())
	for propiedad in ["_fondo", "_nombre", "_renglones", "_aviso", "_cobrar", "_despachar"]:
		(
			assert_object(panel.get(propiedad))
			. override_failure_message("`PanelDeLaVentanilla.%s` quedó en null" % propiedad)
			. is_not_null()
		)


func test_cancelar_con_el_vidrio_cerrado_no_le_devuelve_la_caminata_al_jugador() -> void:
	# 013-AC12
	# `ui_cancel` llega desde cualquier rincón del local y examinar un objeto también suspende
	# (006): sin el corte, la salida de la ventanilla le devuelve la caminata al jugador en medio
	# de un examen, con el objeto pegado a la cara y sin un solo error.
	var ventanilla := _ventanilla()
	var jugador: Node3D = auto_free(load(ESCENA_DEL_JUGADOR).instantiate())
	ventanilla.jugador = jugador
	jugador.suspender()

	ventanilla.cerrar()

	assert_bool(jugador._control.esta_suspendido()).is_true()


func test_abrir_y_cerrar_la_ventanilla_suspende_y_devuelve_el_control() -> void:  # 013-AC12
	# La otra mitad del corte: con el vidrio abierto, cancelar sí tiene que bajar el panel y
	# devolver la caminata, o el jugador queda clavado delante del vidrio para siempre.
	var ventanilla := _ventanilla()
	var jugador: Node3D = auto_free(load(ESCENA_DEL_JUGADOR).instantiate())
	var atenciones: Ventanilla = auto_free(Ventanilla.new())
	var panel: PanelDeLaVentanilla = auto_free(load(ESCENA_DEL_PANEL).instantiate())
	var obligatorias := Apertura.obligatorias()
	var reloj: RelojDelTurno = auto_free(RelojDelTurno.new())
	reloj.arrancar(Apertura.turno_de_la_jornada(obligatorias), obligatorias)
	atenciones.reloj = reloj
	atenciones.arrancar(TareaDeAtender.new(Compradores.de_la_jornada(), Inventario.new([])))
	ventanilla.jugador = jugador
	ventanilla.reloj = reloj
	ventanilla.atenciones = atenciones
	ventanilla.panel = panel

	ventanilla.abrir()
	assert_bool(jugador._control.esta_suspendido()).is_true()

	ventanilla.cerrar()
	assert_bool(jugador._control.esta_suspendido()).is_false()
	assert_bool(panel.visible).is_false()
