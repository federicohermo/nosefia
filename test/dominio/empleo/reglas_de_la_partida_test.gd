## Los dos números de la partida, y la invariante que los ata a los del 002.
##
## El caso que más pesa no es el que afirma el `5`: es el que cruza las jornadas contra las
## constantes de apercibimientos. Sin él, bajar la partida a una jornada dejaría la regla del
## despido escrita, verde en `legajo_test.gd` y **muerta en la build** — que es exactamente el
## agujero que este spec vino a cerrar.
extends GdUnitTestSuite

## Los archivos que este spec escribe y que **no** pueden llevar un número de balance adentro.
## `reglas_de_la_partida.gd` queda afuera a propósito: es el único que los declara.
const ARCHIVOS_SIN_CIFRAS := [
	"res://src/dominio/empleo/partida.gd",
	"res://src/sistemas/marco/ciclo_de_jornadas.gd",
	"res://src/escenas/almacen.gd",
]

## Los tres espejos que `gate_de_tests.py` exige por los dos archivos nuevos de `dominio/` y el
## de `sistemas/`. Se afirman por ruta y no por nombre de clase: lo que el gate mira es el
## archivo.
const ESPEJOS_DEL_SPEC := [
	"res://test/dominio/empleo/reglas_de_la_partida_test.gd",
	"res://test/dominio/empleo/partida_test.gd",
	"res://test/sistemas/marco/ciclo_de_jornadas_test.gd",
]

## Desde acá arriba un entero escrito en el código es balance y no estructura. El `0` y el `1`
## quedan afuera porque son las dos cifras que no se pueden evitar sin inventar una constante
## por cada contador: el paso con el que avanza una jornada y el índice con el que arranca.
const PRIMERA_CIFRA_DE_BALANCE := 2


func test_la_partida_dura_las_cinco_jornadas_del_gdd() -> void:  # 016-AC1
	assert_int(ReglasDeLaPartida.JORNADAS_DE_LA_PARTIDA).is_equal(5)
	assert_int(ReglasDeLaPartida.PRIMERA_JORNADA).is_equal(1)


func test_ningun_otro_archivo_del_ciclo_escribe_una_cifra_de_balance() -> void:  # 016-AC1
	# Una copia del `5` en la partida, en el ciclo o en el cableado de la escena no rompe nada
	# hoy: rompe el día que se rebalancee, y lo hace en silencio, porque el juego seguiría
	# corriendo con dos números distintos diciendo cuántas noches dura.
	var copias: Array[String] = []
	for ruta: String in ARCHIVOS_SIN_CIFRAS:
		copias.append_array(_cifras_de_balance(ruta))
	(
		assert_array(copias)
		. override_failure_message(
			"hay cifras escritas fuera de `reglas_de_la_partida.gd`: %s" % ", ".join(copias)
		)
		. is_empty()
	)


func test_la_demo_alcanza_para_llegar_al_despido() -> void:  # 016-AC2
	# El camino más rápido al despido encadena bandas graves, que son las que más pesan. Si la
	# partida terminara antes de esa cuenta, `despedido()` no podría devolver `true` ni una vez
	# jugando, y los diecisiete criterios del 002 seguirían en verde igual.
	#
	# Se afirma contra las tres constantes y nunca contra el `5`: mover cualquiera de ellas
	# tiene que poner esto en rojo, que es lo único que hace que la invariante sea una
	# invariante y no un comentario.
	var por_grave := float(Reglas.APERCIBIMIENTOS_POR_BANDA_GRAVE)
	var jornadas_hasta_el_despido := ceili(Reglas.APERCIBIMIENTOS_HASTA_EL_DESPIDO / por_grave)
	(
		assert_int(ReglasDeLaPartida.JORNADAS_DE_LA_PARTIDA)
		. override_failure_message(
			(
				"la partida dura %d jornadas y el despido pide %d: la regla del 002 es inalcanzable"
				% [ReglasDeLaPartida.JORNADAS_DE_LA_PARTIDA, jornadas_hasta_el_despido]
			)
		)
		. is_greater_equal(jornadas_hasta_el_despido)
	)


func test_los_tres_espejos_de_este_spec_estan_escritos() -> void:  # 016-AC13
	# `verificar.py` con los seis nodos en verde no se puede afirmar desde adentro de gdUnit4,
	# pero sí lo que hace fallar a su nodo `tdd`: que falte uno de los tres espejos.
	for espejo: String in ESPEJOS_DEL_SPEC:
		(
			assert_bool(FileAccess.file_exists(espejo))
			. override_failure_message("falta el espejo `%s`" % espejo)
			. is_true()
		)


## Los enteros de balance escritos en el código de un archivo, ya redactados con su línea.
##
## Corta cada línea en el primer `#`, así que los números de los comentarios y de los docstrings
## —los `002` y los `016` de la prosa— no cuentan. Vale porque ninguno de los tres archivos que
## mira lleva un `#` adentro de un string; el día que lleve uno, este helper se queda corto y hay
## que decirlo acá.
func _cifras_de_balance(ruta: String) -> Array[String]:
	var encontradas: Array[String] = []
	var numero := RegEx.create_from_string("\\b\\d+\\b")
	for linea in FileAccess.get_file_as_string(ruta).split("\n"):
		var codigo: String = linea.split("#")[0]
		for coincidencia in numero.search_all(codigo):
			if int(coincidencia.get_string()) >= PRIMERA_CIFRA_DE_BALANCE:
				encontradas.append("%s → %s" % [ruta.get_file(), linea.strip_edges()])
	return encontradas
