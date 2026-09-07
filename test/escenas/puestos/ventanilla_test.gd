## La ventanilla que se ve: su cableado, su contrato de interacción y lo que tiene prohibido.
##
## **La escena se instancia y no se entra al árbol**, igual que las otras suites de `escenas/`.
extends GdUnitTestSuite

const ESCENA := "res://src/escenas/puestos/ventanilla.tscn"
const SCRIPT := "res://src/escenas/puestos/ventanilla.gd"
const ESCENA_DEL_ALMACEN := "res://src/escenas/almacen.tscn"
const ESCENA_DEL_JUGADOR := "res://src/escenas/jugador.tscn"

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
	var texto := FileAccess.get_file_as_string(ESCENA_DEL_ALMACEN)
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
