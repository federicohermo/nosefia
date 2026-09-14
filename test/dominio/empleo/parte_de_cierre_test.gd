## El parte ya decidido: lo que la pantalla va a copiar sin pensar.
##
## Todo lo que la placa dice se arma acá, y por eso se puede probar sin levantar una escena: el
## día que un `match` de bandas se escriba en `ui/`, ninguno de los seis nodos lo va a decir, y
## es lo que estos casos existen para hacer innecesario.
extends GdUnitTestSuite

## Los tres archivos de `dominio/` que este spec agrega. Se afirman juntos porque la propiedad
## que se verifica es la misma para los tres.
const ARCHIVOS_DEL_DOMINIO := [
	"res://src/dominio/empleo/reaccion.gd",
	"res://src/dominio/empleo/catalogo_de_reacciones.gd",
	"res://src/dominio/empleo/parte_de_cierre.gd",
]

## Los patrones que rompen la propiedad que hace útil a esta capa: cada uno pide un árbol de
## escena para existir.
const PATRONES_IMPUROS := ["get_tree(", "get_node(", "_process(", "await"]

## Los tres espejos que `gate_de_tests.py` exige por los tres archivos nuevos de `dominio/`.
const ESPEJOS_DEL_SPEC := [
	"res://test/dominio/empleo/reaccion_test.gd",
	"res://test/dominio/empleo/catalogo_de_reacciones_test.gd",
	"res://test/dominio/empleo/parte_de_cierre_test.gd",
]

const JORNADA_DE_PRUEBA := 2


func test_el_parte_trae_una_linea_por_obligatoria_en_el_orden_declarado() -> void:  # 017-AC4
	var obligatorias := Apertura.obligatorias()
	var parte := ParteDeCierre.new(JORNADA_DE_PRUEBA, obligatorias, 0)
	var renglones := parte.lineas()
	assert_int(renglones.size()).is_equal(obligatorias.size())
	for indice in range(obligatorias.size()):
		var esperado := CatalogoDeReacciones.de_la_tarea(obligatorias[indice].tipo(), false)
		assert_str(renglones[indice]).is_equal(esperado.texto)


func test_la_misma_tarea_cumplida_y_sin_cumplir_dice_cosas_distintas() -> void:  # 017-AC4
	# Sin esto, un catálogo con las dos celdas apuntando al mismo archivo pasaría el conteo de
	# filas y dejaría la placa felicitando por una tarea que no se hizo.
	var limpiar := Tarea.new(Tarea.Tipo.LIMPIAR)
	var pendiente: Array[Tarea] = [limpiar]
	var sin_hacer := ParteDeCierre.new(JORNADA_DE_PRUEBA, pendiente, 0).lineas()[0]
	limpiar.completar()
	var hecha := ParteDeCierre.new(JORNADA_DE_PRUEBA, pendiente, 0).lineas()[0]
	assert_str(hecha).is_not_equal(sin_hacer)


func test_el_saludo_y_el_comentario_salen_del_parte_ya_escritos() -> void:  # 017-AC4
	var parte := ParteDeCierre.new(JORNADA_DE_PRUEBA, Apertura.obligatorias(), 1)
	assert_str(parte.saludo()).is_not_empty()
	assert_str(parte.saludo()).contains(str(JORNADA_DE_PRUEBA))
	assert_str(parte.comentario()).is_equal(CatalogoDeReacciones.del_comentario(1).texto)


func test_el_umbral_del_despido_se_cita_por_su_constante() -> void:  # 017-AC5
	# Escrito como número en la placa, mover el balance del 002 dejaría a la pantalla mintiendo
	# sin que nada avise: el jugador leería «de 4» con el despido en 5.
	var parte := ParteDeCierre.new(JORNADA_DE_PRUEBA, Apertura.obligatorias(), 0)
	assert_int(parte.umbral_del_despido()).is_equal(Reglas.APERCIBIMIENTOS_HASTA_EL_DESPIDO)


func test_el_legajo_en_cero_no_esta_en_riesgo_y_de_uno_en_adelante_si() -> void:  # 017-AC5
	var obligatorias := Apertura.obligatorias()
	assert_bool(ParteDeCierre.new(JORNADA_DE_PRUEBA, obligatorias, 0).en_riesgo()).is_false()
	for cuantos in range(1, Reglas.APERCIBIMIENTOS_HASTA_EL_DESPIDO + 1):
		(
			assert_bool(ParteDeCierre.new(JORNADA_DE_PRUEBA, obligatorias, cuantos).en_riesgo())
			. override_failure_message("con %d apercibimientos el parte no avisa nada" % cuantos)
			. is_true()
		)


func test_el_parte_devuelve_lo_que_recibio_sin_recalcular_nada() -> void:  # 017-AC6
	var parte := ParteDeCierre.new(JORNADA_DE_PRUEBA, Apertura.obligatorias(), 3)
	assert_int(parte.jornada()).is_equal(JORNADA_DE_PRUEBA)
	assert_int(parte.apercibimientos()).is_equal(3)


func test_los_tres_archivos_del_dominio_son_puros() -> void:  # 017-AC7
	for ruta: String in ARCHIVOS_DEL_DOMINIO:
		var texto := FileAccess.get_file_as_string(ruta)
		(
			assert_str(texto)
			. override_failure_message("`%s` está vacío o no existe" % ruta)
			. is_not_empty()
		)
		assert_str(texto).not_contains("extends Node")
		for patron: String in PATRONES_IMPUROS:
			(
				assert_bool(texto.contains(patron))
				. override_failure_message("`%s` nombra `%s`: dejó de ser dominio" % [ruta, patron])
				. is_false()
			)


func test_los_tres_espejos_de_este_spec_estan_escritos() -> void:  # 017-AC13
	# `verificar.py` en verde no se puede afirmar desde adentro de gdUnit4, pero sí lo que hace
	# fallar a su nodo `tdd`: que falte uno de los tres espejos.
	for espejo: String in ESPEJOS_DEL_SPEC:
		(
			assert_bool(FileAccess.file_exists(espejo))
			. override_failure_message("falta el espejo `%s`" % espejo)
			. is_true()
		)
