## El nodo que limpia adentro del motor: traduce cada uso y publica lo que el dominio contestó.
##
## **Ningún caso entra el nodo al árbol y ninguno hace correr `_process`.** Se instancia con
## `auto_free(Limpiador.new())` y se le llama a mano: sin `_process`, el turno no se mueve, y un
## descuento que apareciera sería un segundo cobro.
extends GdUnitTestSuite

const LIMPIADOR := "res://src/sistemas/tareas/limpiador.gd"

const MOPA := ReglasDeLaLimpieza.ID_DE_LA_MOPA
const BALDE := ReglasDeLaLimpieza.ID_DEL_BALDE
const LAVATORIO := ReglasDeLaLimpieza.ID_DEL_LAVATORIO
const INODORO := ReglasDeLaLimpieza.ID_DEL_INODORO

## Los `.gd` de este spec, del dominio a la cáscara. Ninguno puede nombrar `consumir`: el tiempo de
## limpiar lo descuenta el reloj mientras el jugador limpia, y nadie más.
const ARCHIVOS_DEL_SPEC := [
	"res://src/dominio/almacen/reglas_de_la_limpieza.gd",
	"res://src/dominio/almacen/mancha.gd",
	"res://src/dominio/almacen/balde.gd",
	"res://src/dominio/almacen/mopa.gd",
	"res://src/dominio/almacen/piso_del_local.gd",
	"res://src/sistemas/tareas/limpiador.gd",
	"res://src/escenas/objetos/mancha_en_el_piso.gd",
	"res://src/escenas/objetos/util_de_limpieza.gd",
	"res://src/escenas/puestos/artefacto_del_bano.gd",
	"res://src/escenas/puestos/limpieza_del_almacen.gd",
]

## Lo que delataría estado propio de la tarea adentro del nodo. El piso ya lleva las manchas, el
## balde y la mopa, y el `Turno` ya sabe que la segunda vez no cuenta.
const PATRONES_DE_ESTADO_PROPIO := "var\\s+_(manchas|limpias|cumplida|balde|mopa|agua)\\b"

## El jabón de cada lugar de la jornada, para borrarla entera.
const JABON_DE := {
	PisoDelLocal.Lugar.ENTRADA: &"jabon_amarillo",
	PisoDelLocal.Lugar.GONDOLAS: &"jabon_amarillo",
	PisoDelLocal.Lugar.DEPOSITO: &"jabon_azul",
	PisoDelLocal.Lugar.BANO: &"jabon_rosa",
}

var _turno: Turno = null
var _avisos_de_tarea: int = 0
var _cumplidas_avisadas: int = 0
## Cada señal emitida, en orden, con su argumento: `[nombre, valor]`.
var _emitidas: Array[Array] = []


func before_test() -> void:
	_turno = null
	_avisos_de_tarea = 0
	_cumplidas_avisadas = 0
	_emitidas = []


func _limpiador(presupuesto: float = Reglas.DURACION_DEL_TURNO) -> Limpiador:
	var obligatorias := Apertura.obligatorias()
	_turno = Turno.new(presupuesto, obligatorias)
	var reloj: RelojDelTurno = auto_free(RelojDelTurno.new())
	reloj.arrancar(_turno, obligatorias)
	reloj.tarea_completada.connect(_anotar_tarea)

	var limpiador: Limpiador = auto_free(Limpiador.new())
	limpiador.reloj = reloj
	limpiador.balde_llenado.connect(func() -> void: _emitidas.append(["balde_llenado", null]))
	limpiador.balde_tenido.connect(
		func(agua: ReglasDeLaLimpieza.Agua) -> void: _emitidas.append(["balde_tenido", agua])
	)
	limpiador.balde_vaciado.connect(func() -> void: _emitidas.append(["balde_vaciado", null]))
	limpiador.mopa_mojada.connect(
		func(agua: ReglasDeLaLimpieza.Agua) -> void: _emitidas.append(["mopa_mojada", agua])
	)
	limpiador.piso_humedecido.connect(func() -> void: _emitidas.append(["piso_humedecido", null]))
	limpiador.pasada_dada.connect(
		func(lugar: PisoDelLocal.Lugar) -> void: _emitidas.append(["pasada_dada", lugar])
	)
	limpiador.uso_rechazado.connect(
		func(motivo: ReglasDeLaLimpieza.Resultado) -> void:
			_emitidas.append(["uso_rechazado", motivo])
	)
	limpiador.arrancar(PisoDelLocal.de_la_jornada())
	return limpiador


## Prepara el balde con ese jabón y moja la mopa, desde el balde como esté.
func _preparar(limpiador: Limpiador, jabon: StringName) -> void:
	limpiador.usar(BALDE, INODORO)
	limpiador.usar(BALDE, LAVATORIO)
	limpiador.usar(jabon, BALDE)
	limpiador.usar(MOPA, BALDE)


## Borra todas las manchas menos las que se pidan, y devuelve cuántas borró.
func _borrar_menos(limpiador: Limpiador, que_falten: int) -> int:
	var borradas := 0
	for lugar: PisoDelLocal.Lugar in JABON_DE:
		if JABON_DE.size() - borradas <= que_falten:
			break
		_preparar(limpiador, JABON_DE[lugar])
		limpiador.pasar(MOPA, lugar)
		borradas += 1
	return borradas


func _anotar_tarea(cumplidas: int) -> void:
	_avisos_de_tarea += 1
	_cumplidas_avisadas = cumplidas


func test_el_limpiador_devuelve_exactamente_lo_que_contesto_el_dominio() -> void:
	# No lo traduce a un `bool`: los rechazos se leen distinto adelante del jugador, y aplanarlos
	# daría un solo cartel para situaciones que se resuelven distinto.
	var limpiador := _limpiador()
	assert_int(limpiador.usar(BALDE, INODORO)).is_equal(ReglasDeLaLimpieza.Resultado.BALDE_VACIO)
	assert_int(limpiador.usar(BALDE, LAVATORIO)).is_equal(
		ReglasDeLaLimpieza.Resultado.BALDE_LLENADO
	)
	assert_int(limpiador.pasar(MOPA, PisoDelLocal.Lugar.ENTRADA)).is_equal(
		ReglasDeLaLimpieza.Resultado.MOPA_SECA
	)
	assert_int(limpiador.usar(ObjetoDelAlmacen.SIN_ID, BALDE)).is_equal(
		ReglasDeLaLimpieza.Resultado.SIN_EFECTO
	)


func test_cada_gesto_que_cambia_algo_emite_su_senal_una_vez() -> void:
	var limpiador := _limpiador()
	limpiador.usar(BALDE, LAVATORIO)
	limpiador.usar(&"jabon_amarillo", BALDE)
	limpiador.usar(MOPA, BALDE)
	limpiador.pasar(MOPA, PisoDelLocal.Lugar.GONDOLAS)
	limpiador.usar(BALDE, INODORO)
	(
		assert_array(_emitidas)
		. is_equal(
			[
				["balde_llenado", null],
				["balde_tenido", ReglasDeLaLimpieza.Agua.AMARILLO],
				["mopa_mojada", ReglasDeLaLimpieza.Agua.AMARILLO],
				["pasada_dada", PisoDelLocal.Lugar.GONDOLAS],
				["balde_vaciado", null],
			]
		)
	)


func test_cada_rechazo_emite_su_motivo_y_nada_mas() -> void:  # AC-CLN-024
	var limpiador := _limpiador()
	limpiador.usar(BALDE, INODORO)
	limpiador.pasar(MOPA, PisoDelLocal.Lugar.BANO)
	limpiador.usar(&"bolsa_de_basura_1", BALDE)
	(
		assert_array(_emitidas)
		. is_equal(
			[
				["uso_rechazado", ReglasDeLaLimpieza.Resultado.BALDE_VACIO],
				["uso_rechazado", ReglasDeLaLimpieza.Resultado.MOPA_SECA],
				["uso_rechazado", ReglasDeLaLimpieza.Resultado.SIN_EFECTO],
			]
		)
	)


func test_con_una_mancha_de_menos_la_obligatoria_no_se_cuenta() -> void:  # AC-CLN-012
	var limpiador := _limpiador()
	assert_int(_borrar_menos(limpiador, 1)).is_equal(JABON_DE.size() - 1)
	assert_bool(limpiador.piso().esta_limpio()).is_false()
	assert_int(_avisos_de_tarea).is_equal(0)
	assert_int(_turno.tareas_cumplidas()).is_equal(0)


func test_la_ultima_mancha_cuenta_la_obligatoria_una_sola_vez() -> void:  # AC-CLN-012
	var limpiador := _limpiador()
	_borrar_menos(limpiador, 0)
	assert_bool(limpiador.piso().esta_limpio()).is_true()
	assert_int(_avisos_de_tarea).is_equal(1)
	assert_int(_cumplidas_avisadas).is_equal(1)
	assert_float(_turno.tiempo_restante()).is_equal(Reglas.DURACION_DEL_TURNO)
	# Pasar otra vez no la vuelve a contar: la mancha ya no está y el dominio rechaza.
	assert_int(limpiador.pasar(MOPA, PisoDelLocal.Lugar.ENTRADA)).is_equal(
		ReglasDeLaLimpieza.Resultado.YA_ESTABA_LIMPIA
	)
	assert_float(_turno.tiempo_restante()).is_equal(Reglas.DURACION_DEL_TURNO)
	assert_int(_avisos_de_tarea).is_equal(1)


func test_con_el_turno_cerrado_limpiar_no_cuenta() -> void:
	# El piso igual queda limpio: el estado del local no depende de que el jefe lo cuente.
	var limpiador := _limpiador(0.0)
	_borrar_menos(limpiador, 0)
	assert_bool(limpiador.piso().esta_limpio()).is_true()
	assert_int(_avisos_de_tarea).is_equal(0)
	assert_float(_turno.tiempo_restante()).is_equal(0.0)


func test_el_limpiador_no_lleva_estado_propio_de_la_tarea() -> void:
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


func test_ningun_archivo_de_este_spec_nombra_consumir() -> void:
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


func test_desgastar_la_mopa_rechaza_la_pasada_sin_cobrar_tiempo() -> void:  # AC-CLN-026
	var limpiador := _limpiador()
	_preparar(limpiador, &"jabon_amarillo")
	var tiempo := _turno.tiempo_restante()
	limpiador.desgastar_mopa(ReglasDeLaLimpieza.DURACION_DE_LA_CARGA, 0.0)
	assert_int(limpiador.pasar(MOPA, PisoDelLocal.Lugar.ENTRADA)).is_equal(
		ReglasDeLaLimpieza.Resultado.MOPA_SECA
	)
	assert_bool(limpiador.piso().mancha_de(PisoDelLocal.Lugar.ENTRADA).esta_limpia()).is_false()
	assert_float(_turno.tiempo_restante()).is_equal(tiempo)


func test_remojar_cerca_recupera_la_limpieza_despues_del_viaje() -> void:  # AC-CLN-027
	var limpiador := _limpiador()
	_preparar(limpiador, &"jabon_amarillo")
	limpiador.desgastar_mopa(3.0, ReglasDeLaLimpieza.RECORRIDO_DE_LA_CARGA)
	assert_int(limpiador.pasar(MOPA, PisoDelLocal.Lugar.ENTRADA)).is_equal(
		ReglasDeLaLimpieza.Resultado.MOPA_SECA
	)
	limpiador.usar(MOPA, BALDE)
	limpiador.desgastar_mopa(0.5, 0.5)
	assert_int(limpiador.pasar(MOPA, PisoDelLocal.Lugar.ENTRADA)).is_equal(
		ReglasDeLaLimpieza.Resultado.MANCHA_BORRADA
	)


func test_enjuagar_en_inodoro_publica_agua_limpia_sin_contar_tarea() -> void:  # AC-CLN-029
	var limpiador := _limpiador()
	_preparar(limpiador, &"jabon_rosa")
	limpiador.desgastar_mopa(2.0, 1.0)
	_emitidas.clear()
	var tiempo := _turno.tiempo_restante()
	assert_int(limpiador.usar(MOPA, INODORO)).is_equal(ReglasDeLaLimpieza.Resultado.MOPA_MOJADA)
	assert_array(_emitidas).is_equal([["mopa_mojada", ReglasDeLaLimpieza.Agua.LIMPIA]])
	assert_int(limpiador.piso().balde().agua()).is_equal(ReglasDeLaLimpieza.Agua.ROSA)
	assert_float(limpiador.piso().mopa().carga_restante()).is_equal(1.0)
	assert_int(_avisos_de_tarea).is_zero()
	assert_float(_turno.tiempo_restante()).is_equal(tiempo)


func test_charco_aceptado_emite_una_senal_sin_tarea_ni_desgaste() -> void:  # AC-CLN-030
	var limpiador := _limpiador()
	limpiador.usar(BALDE, LAVATORIO)
	limpiador.usar(MOPA, BALDE)
	limpiador.desgastar_mopa(1.0, 0.5)
	var carga := limpiador.piso().mopa().carga_restante()
	var tiempo := _turno.tiempo_restante()
	_emitidas.clear()
	assert_int(limpiador.humedecer_piso(MOPA, true)).is_equal(
		ReglasDeLaLimpieza.Resultado.CHARCO_DEJADO
	)
	assert_array(_emitidas).is_equal([["piso_humedecido", null]])
	assert_float(limpiador.piso().mopa().carga_restante()).is_equal(carga)
	assert_int(_avisos_de_tarea).is_zero()
	assert_int(_turno.tareas_cumplidas()).is_zero()
	assert_float(_turno.tiempo_restante()).is_equal(tiempo)


func test_charco_rechazado_emite_solo_motivo_y_conserva_carga() -> void:  # AC-CLN-031
	var limpiador := _limpiador()
	limpiador.usar(BALDE, LAVATORIO)
	limpiador.usar(MOPA, BALDE)
	var carga := limpiador.piso().mopa().carga_restante()
	_emitidas.clear()
	assert_int(limpiador.humedecer_piso(MOPA, false)).is_equal(
		ReglasDeLaLimpieza.Resultado.SIN_EFECTO
	)
	assert_array(_emitidas).is_equal([["uso_rechazado", ReglasDeLaLimpieza.Resultado.SIN_EFECTO]])
	assert_float(limpiador.piso().mopa().carga_restante()).is_equal(carga)
	assert_int(_avisos_de_tarea).is_zero()


func test_charco_con_mano_vacia_seca_o_jabon_no_emite_agua() -> void:  # AC-CLN-030
	var limpiador := _limpiador()
	assert_int(limpiador.humedecer_piso(MOPA, true)).is_equal(
		ReglasDeLaLimpieza.Resultado.MOPA_SECA
	)
	assert_array(_emitidas).is_equal([["uso_rechazado", ReglasDeLaLimpieza.Resultado.MOPA_SECA]])
	_preparar(limpiador, &"jabon_azul")
	var carga := limpiador.piso().mopa().carga_restante()
	_emitidas.clear()
	assert_int(limpiador.humedecer_piso(MOPA, true)).is_equal(
		ReglasDeLaLimpieza.Resultado.SIN_EFECTO
	)
	assert_int(limpiador.humedecer_piso(ObjetoDelAlmacen.SIN_ID, true)).is_equal(
		ReglasDeLaLimpieza.Resultado.SIN_EFECTO
	)
	(
		assert_array(_emitidas)
		. is_equal(
			[
				["uso_rechazado", ReglasDeLaLimpieza.Resultado.SIN_EFECTO],
				["uso_rechazado", ReglasDeLaLimpieza.Resultado.SIN_EFECTO],
			]
		)
	)
	assert_float(limpiador.piso().mopa().carga_restante()).is_equal(carga)
	assert_int(_avisos_de_tarea).is_zero()
