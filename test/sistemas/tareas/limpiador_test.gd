## El nodo que limpia adentro del motor: traduce la pasada y publica lo que el dominio contestó.
##
## **Ningún caso entra el nodo al árbol y ninguno hace correr `_process`.** Se instancia con
## `auto_free(Limpiador.new())` y se le llama a mano, que es lo que vuelve medible el AC8: sin
## `_process`, el único descuento que puede aparecer en el turno es el de `completar()`.
extends GdUnitTestSuite

const LIMPIADOR := "res://src/sistemas/tareas/limpiador.gd"

## Los cuatro `.gd` de este spec más los dos de la cáscara. Ninguno puede nombrar `consumir`: el
## costo de `LIMPIAR` es del 001 y lo descuenta el reloj del 007, una sola vez.
const ARCHIVOS_DEL_SPEC := [
	"res://src/dominio/almacen/reglas_de_la_limpieza.gd",
	"res://src/dominio/almacen/mancha.gd",
	"res://src/dominio/almacen/piso_del_local.gd",
	"res://src/sistemas/tareas/limpiador.gd",
	"res://src/escenas/objetos/mancha_en_el_piso.gd",
	"res://src/escenas/puestos/limpieza_del_almacen.gd",
]

## Lo que delataría un contador propio de la tarea adentro del nodo. El `PisoDelLocal` ya lleva la
## cuenta y el `Turno` ya sabe que la segunda vez no cuenta.
const PATRONES_DE_ESTADO_PROPIO := "var\\s+_pasadas|var\\s+_limpias|var\\s+_cumplida"

var _turno: Turno = null
var _pasadas: int = 0
var _limpiadas: int = 0
var _rechazos: int = 0
var _avisos_de_tarea: int = 0
var _cumplidas_avisadas: int = 0


func before_test() -> void:
	_turno = null
	_pasadas = 0
	_limpiadas = 0
	_rechazos = 0
	_avisos_de_tarea = 0
	_cumplidas_avisadas = 0


func _limpiador(presupuesto: float = Reglas.DURACION_DEL_TURNO) -> Limpiador:
	var obligatorias := Apertura.obligatorias()
	_turno = Turno.new(presupuesto, obligatorias)
	var reloj: RelojDelTurno = auto_free(RelojDelTurno.new())
	reloj.arrancar(_turno, obligatorias)
	reloj.tarea_completada.connect(_anotar_tarea)

	var limpiador: Limpiador = auto_free(Limpiador.new())
	limpiador.reloj = reloj
	limpiador.pasada_dada.connect(_anotar_pasada)
	limpiador.mancha_limpiada.connect(_anotar_limpiada)
	limpiador.pasada_rechazada.connect(_anotar_rechazo)
	limpiador.arrancar(PisoDelLocal.de_la_jornada())
	return limpiador


## Deja el piso entero limpio menos las pasadas que se pidan, y devuelve cuántas dio.
func _limpiar_menos(limpiador: Limpiador, que_falten: int) -> int:
	var piso := limpiador.piso()
	var dadas := 0
	for zona: PisoDelLocal.Zona in PisoDelLocal.Zona.values():
		for _pasada in range(ReglasDeLaLimpieza.PASADAS_POR_MANCHA):
			if piso.pasadas_totales() - dadas <= que_falten:
				return dadas
			limpiador.pedir_pasada(zona, ReglasDeLaLimpieza.ID_DEL_TRAPEADOR)
			dadas += 1
	return dadas


func test_el_limpiador_devuelve_exactamente_lo_que_contesto_el_dominio() -> void:  # 014-AC7
	# No lo traduce a un `bool`: los tres rechazos se leen distinto adelante del jugador, y
	# aplanarlos daría un solo cartel para dos situaciones.
	var limpiador := _limpiador()
	(
		assert_int(
			limpiador.pedir_pasada(PisoDelLocal.Zona.ENTRADA, ReglasDeLaLimpieza.ID_DEL_TRAPEADOR)
		)
		. is_equal(PisoDelLocal.Resultado.PASADA)
	)
	assert_int(limpiador.pedir_pasada(PisoDelLocal.Zona.ENTRADA, ObjetoDelAlmacen.SIN_ID)).is_equal(
		PisoDelLocal.Resultado.SIN_TRAPEADOR
	)


func test_emite_una_sola_vez_por_pasada_aceptada_y_ninguna_por_rechazada() -> void:  # 014-AC7
	var limpiador := _limpiador()
	limpiador.pedir_pasada(PisoDelLocal.Zona.ENTRADA, ReglasDeLaLimpieza.ID_DEL_TRAPEADOR)
	assert_int(_pasadas).is_equal(1)
	assert_int(_rechazos).is_equal(0)
	limpiador.pedir_pasada(PisoDelLocal.Zona.ENTRADA, ObjetoDelAlmacen.SIN_ID)
	assert_int(_pasadas).is_equal(1)
	assert_int(_rechazos).is_equal(1)


func test_la_ultima_pasada_de_una_zona_avisa_que_la_mancha_se_fue() -> void:  # 014-AC7
	var limpiador := _limpiador()
	for _pasada in range(ReglasDeLaLimpieza.PASADAS_POR_MANCHA):
		limpiador.pedir_pasada(PisoDelLocal.Zona.ENTRADA, ReglasDeLaLimpieza.ID_DEL_TRAPEADOR)
	assert_int(_limpiadas).is_equal(1)
	assert_int(_pasadas).is_equal(ReglasDeLaLimpieza.PASADAS_POR_MANCHA)


func test_el_limpiador_no_lleva_estado_propio_de_la_tarea() -> void:  # 014-AC7
	# Está medido que un contador acá pasa los dos gates en verde: `sistemas/` puede escribir la
	# regla y nadie lo dice. Por eso el criterio la ata con una búsqueda sobre el archivo.
	var texto := FileAccess.get_file_as_string(LIMPIADOR)
	assert_str(texto).is_not_empty()
	var propio := RegEx.create_from_string(PATRONES_DE_ESTADO_PROPIO).search_all(texto)
	(
		assert_array(propio)
		. override_failure_message("`limpiador.gd` lleva estado propio de la tarea")
		. is_empty()
	)


func test_con_una_pasada_de_menos_la_obligatoria_no_se_cuenta() -> void:  # 014-AC8
	var limpiador := _limpiador()
	var dadas := _limpiar_menos(limpiador, 1)
	assert_int(dadas).is_equal(limpiador.piso().pasadas_totales() - 1)
	assert_int(_avisos_de_tarea).is_equal(0)
	assert_int(_turno.tareas_cumplidas()).is_equal(0)


func test_la_ultima_pasada_cuenta_la_obligatoria_y_descuenta_una_sola_vez() -> void:  # 014-AC8
	var limpiador := _limpiador()
	_limpiar_menos(limpiador, 0)
	assert_int(_avisos_de_tarea).is_equal(1)
	assert_int(_cumplidas_avisadas).is_equal(1)
	var esperado := Reglas.DURACION_DEL_TURNO - Reglas.costo_de(Tarea.Tipo.LIMPIAR)
	assert_float(_turno.tiempo_restante()).is_equal(esperado)
	# Machacar de más no vuelve a cobrar: las cuatro zonas están limpias y el dominio rechaza.
	limpiador.pedir_pasada(PisoDelLocal.Zona.ENTRADA, ReglasDeLaLimpieza.ID_DEL_TRAPEADOR)
	assert_float(_turno.tiempo_restante()).is_equal(esperado)
	assert_int(_avisos_de_tarea).is_equal(1)


func test_sin_tiempo_para_limpiar_la_tarea_no_se_cuenta_ni_descuenta() -> void:  # 014-AC8
	# El piso igual queda limpio: el estado del local no depende de que el jefe lo cuente.
	var limpiador := _limpiador(0.0)
	_limpiar_menos(limpiador, 0)
	assert_bool(limpiador.piso().esta_limpio()).is_true()
	assert_int(_avisos_de_tarea).is_equal(0)
	assert_float(_turno.tiempo_restante()).is_equal(0.0)


func test_ningun_archivo_de_este_spec_nombra_consumir() -> void:  # 014-AC8
	# El nombre no se escribe ni en un comentario: este caso no distingue código de prosa, y
	# hacerlo pasar comentando distinto sería trampa.
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


func _anotar_pasada(_zona: PisoDelLocal.Zona, _restantes: int) -> void:
	_pasadas += 1


func _anotar_limpiada(_zona: PisoDelLocal.Zona) -> void:
	_limpiadas += 1


func _anotar_rechazo(_motivo: PisoDelLocal.Resultado) -> void:
	_rechazos += 1


func _anotar_tarea(cumplidas: int) -> void:
	_avisos_de_tarea += 1
	_cumplidas_avisadas = cumplidas


func test_la_pasada_necesita_un_efecto_del_despacho() -> void:  # 034-AC7 034-AC11
	var limpiador := _limpiador()
	limpiador.set("_uso", Uso.new())
	var antes := limpiador.piso().pasadas_restantes(PisoDelLocal.Zona.ENTRADA)
	(
		assert_int(
			limpiador.pedir_pasada(PisoDelLocal.Zona.ENTRADA, ReglasDeLaLimpieza.ID_DEL_TRAPEADOR)
		)
		. is_equal(PisoDelLocal.Resultado.SIN_TRAPEADOR)
	)
	assert_int(limpiador.piso().pasadas_restantes(PisoDelLocal.Zona.ENTRADA)).is_equal(antes)
	assert_int(_rechazos).is_equal(1)
