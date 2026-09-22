## El nodo que saca la basura adentro del motor: traduce el depósito y publica.
##
## **Ningún caso entra el nodo al árbol y ninguno hace correr `_process`.** Es lo que vuelve
## medible el AC5: sin `_process`, el único descuento que puede aparecer en el turno es el de
## `completar()`.
extends GdUnitTestSuite

const RECOLECTOR := "res://src/sistemas/tareas/recolector_de_basura.gd"

## Los cuatro `.gd` de este spec más el de la escena, que es el que ningún gate mira.
const ARCHIVOS_DEL_SPEC := [
	"res://src/dominio/almacen/reglas_de_la_basura.gd",
	"res://src/dominio/almacen/trayecto.gd",
	"res://src/dominio/almacen/tarea_de_la_basura.gd",
	"res://src/sistemas/tareas/recolector_de_basura.gd",
	"res://src/escenas/puestos/zona_de_descarte.gd",
]

## Lo que delataría un contador propio de la tarea adentro del nodo.
const PATRONES_DE_ESTADO_PROPIO := "var\\s+_depositadas|var\\s+_bolsas|var\\s+_cumplida"

const ADENTRO := 0.0
const AFUERA := 50.0

var _turno: Turno = null
var _depositos: int = 0
var _rechazos: int = 0
var _avisos_de_tarea: int = 0
var _cumplidas_avisadas: int = 0


func before_test() -> void:
	_turno = null
	_depositos = 0
	_rechazos = 0
	_avisos_de_tarea = 0
	_cumplidas_avisadas = 0


func _ids() -> Array[StringName]:
	return ReglasDeLaBasura.ids_de_las_bolsas()


func _recolector(presupuesto: float = Reglas.DURACION_DEL_TURNO) -> RecolectorDeBasura:
	var obligatorias := Apertura.obligatorias()
	_turno = Turno.new(presupuesto, obligatorias)
	var reloj: RelojDelTurno = auto_free(RelojDelTurno.new())
	reloj.arrancar(_turno, obligatorias)
	reloj.tarea_completada.connect(_anotar_tarea)

	var recolector: RecolectorDeBasura = auto_free(RecolectorDeBasura.new())
	recolector.reloj = reloj
	recolector.bolsa_depositada.connect(_anotar_deposito)
	recolector.deposito_rechazado.connect(_anotar_rechazo)
	recolector.arrancar(TareaDeLaBasura.de_la_jornada())
	return recolector


func test_el_recolector_devuelve_exactamente_lo_que_contesto_el_dominio() -> void:  # 015-AC6
	var recolector := _recolector()
	assert_int(recolector.pedir_depositar(_ids()[0], AFUERA)).is_equal(
		TareaDeLaBasura.Resultado.FUERA_DE_LA_ZONA
	)
	assert_int(recolector.pedir_depositar(_ids()[0], ADENTRO)).is_equal(
		TareaDeLaBasura.Resultado.DEPOSITADA
	)
	assert_int(_depositos).is_equal(1)
	assert_int(_rechazos).is_equal(1)


func test_el_recolector_no_lleva_estado_propio() -> void:  # 015-AC6
	# Está medido que un contador acá pasa los dos gates en verde: `sistemas/` puede escribir la
	# regla y nadie lo dice.
	var texto := FileAccess.get_file_as_string(RECOLECTOR)
	assert_str(texto).is_not_empty()
	var propio := RegEx.create_from_string(PATRONES_DE_ESTADO_PROPIO).search_all(texto)
	(
		assert_array(propio)
		. override_failure_message("`recolector_de_basura.gd` lleva estado propio de la tarea")
		. is_empty()
	)


func test_con_una_bolsa_de_menos_la_obligatoria_no_se_cuenta() -> void:  # 015-AC5
	var recolector := _recolector()
	var ids := _ids()
	for indice in range(ids.size() - 1):
		recolector.pedir_depositar(ids[indice], ADENTRO)
	assert_int(_depositos).is_equal(ids.size() - 1)
	assert_int(_avisos_de_tarea).is_equal(0)
	assert_int(_turno.tareas_cumplidas()).is_equal(0)


func test_la_ultima_bolsa_cuenta_la_obligatoria_y_descuenta_una_sola_vez() -> void:  # 015-AC5
	var recolector := _recolector()
	for id in _ids():
		recolector.pedir_depositar(id, ADENTRO)
	assert_int(_avisos_de_tarea).is_equal(1)
	assert_int(_cumplidas_avisadas).is_equal(1)
	var esperado := Reglas.DURACION_DEL_TURNO - Reglas.costo_de(Tarea.Tipo.SACAR_LA_BASURA)
	assert_float(_turno.tiempo_restante()).is_equal(esperado)
	# Volver a soltar una bolsa ya depositada no cobra de nuevo: el dominio contesta que ya está.
	recolector.pedir_depositar(_ids()[0], ADENTRO)
	assert_float(_turno.tiempo_restante()).is_equal(esperado)
	assert_int(_avisos_de_tarea).is_equal(1)


func test_sin_tiempo_para_la_basura_la_tarea_no_se_cuenta_ni_descuenta() -> void:  # 015-AC5
	# Las bolsas igual llegan al fondo: el estado del local no depende de que el jefe lo cuente.
	var recolector := _recolector(0.0)
	for id in _ids():
		recolector.pedir_depositar(id, ADENTRO)
	assert_bool(recolector.tarea().completada()).is_true()
	assert_int(_avisos_de_tarea).is_equal(0)
	assert_float(_turno.tiempo_restante()).is_equal(0.0)


func test_ningun_archivo_de_este_spec_nombra_consumir() -> void:  # 015-AC5
	# El nombre no se escribe ni en un comentario: este caso no distingue código de prosa.
	for ruta: String in ARCHIVOS_DEL_SPEC:
		var texto := FileAccess.get_file_as_string(ruta)
		(
			assert_str(texto)
			. override_failure_message("`%s` está vacío o no existe" % ruta)
			. is_not_empty()
		)
		(
			assert_bool(texto.contains("consumir"))
			. override_failure_message("`%s` nombra `consumir`: es un segundo cobro" % ruta)
			. is_false()
		)


func _anotar_deposito(_depositadas: int) -> void:
	_depositos += 1


func _anotar_rechazo(_motivo: TareaDeLaBasura.Resultado) -> void:
	_rechazos += 1


func _anotar_tarea(cumplidas: int) -> void:
	_avisos_de_tarea += 1
	_cumplidas_avisadas = cumplidas
