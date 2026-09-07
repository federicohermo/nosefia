## La placa del cierre: que copie el parte y que no decida nada.
##
## **Esta suite existe además del gate, no en su lugar.** Está medido que una pantalla con su
## `match` de bandas adentro y sin un solo test da `sin hallazgos` en `tdd` y `capas`: el gate de
## tests no mira `ui/`, y que `ui/` nombre a `dominio/` es legal. O sea que la versión ingenua de
## este spec nace con su única regla sin test y con los seis nodos en verde.
##
## Los dos casos de texto son lo único ejecutable que ata esa regla, y por eso están acá y no
## librados a la revisión.
extends GdUnitTestSuite

const ESCENA := "res://src/ui/interrupciones/pantalla_de_cierre.tscn"
const PANTALLA := "res://src/ui/interrupciones/pantalla_de_cierre.gd"

## Lo que la placa **no** puede nombrar: las tres piezas que deciden cómo cerró la noche, y el
## dueño del ciclo. El umbral entra por el parte y nunca por la constante.
const NOMBRES_QUE_DECIDEN := [
	"Consecuencias",
	"consecuencia_de",
	"Legajo",
	"APERCIBIMIENTOS_HASTA_EL_DESPIDO",
	"CicloDeJornadas",
]

## Las dos capas que no pueden mirar hacia arriba. Nombrar a la pantalla desde acá es la
## violación que el gate de capas sí ve; este caso la afirma con su propio nombre.
const CAPAS_DE_ABAJO := ["res://src/dominio", "res://src/sistemas"]

const JORNADA_DE_PRUEBA := 3

var _despachos: int = 0


func before_test() -> void:
	_despachos = 0


func test_la_pantalla_arranca_invisible() -> void:  # 017-AC10
	# La placa es del cierre, no del arranque: visible desde el primer cuadro taparía la jornada
	# entera, y el jugador no tendría cómo sacarla porque el turno recién empieza.
	var pantalla := await _pantalla()
	assert_bool(pantalla.visible).is_false()


func test_mostrar_pinta_el_parte_entero_y_oscurece_lo_de_atras() -> void:  # 017-AC10
	var pantalla := await _pantalla()
	var parte := _parte()
	pantalla.mostrar(parte)
	assert_bool(pantalla.visible).is_true()

	var fondo: ColorRect = pantalla.get_node("Fondo")
	(
		assert_float(fondo.color.a)
		. override_failure_message("el fondo es transparente: no oscurece nada")
		. is_greater(0.0)
	)

	assert_str(_etiqueta(pantalla, "Saludo").text).is_equal(parte.saludo())
	assert_str(_etiqueta(pantalla, "Comentario").text).is_equal(parte.comentario())

	var renglones: VBoxContainer = pantalla.get_node("Fondo/Panel/Lineas")
	assert_int(renglones.get_child_count()).is_equal(parte.lineas().size())
	for indice in range(renglones.get_child_count()):
		var etiqueta: Label = renglones.get_child(indice)
		assert_str(etiqueta.text).is_equal(parte.lineas()[indice])


func test_mostrar_dos_veces_no_acumula_las_lineas_de_la_jornada_anterior() -> void:  # 017-AC10
	# Cinco noches con la misma pantalla: sin limpiar, la placa de la jornada 5 tendría
	# veinticinco renglones y ninguna aserción del caso de arriba lo diría.
	var pantalla := await _pantalla()
	pantalla.mostrar(_parte())
	pantalla.mostrar(_parte())
	var renglones: VBoxContainer = pantalla.get_node("Fondo/Panel/Lineas")
	assert_int(renglones.get_child_count()).is_equal(Apertura.cantidad_de_obligatorias())


func test_el_aviso_de_riesgo_sale_del_parte_y_se_esconde_con_el_legajo_limpio() -> void:  # 017-AC10
	# Es la única línea de la placa que aparece y desaparece, así que sin los dos estados el
	# `visible` quedaría escrito y sin ejercer: una placa que avisa siempre no avisa nunca.
	var pantalla := await _pantalla()
	var en_riesgo := _parte()
	pantalla.mostrar(en_riesgo)
	var riesgo := _etiqueta(pantalla, "Riesgo")
	assert_str(riesgo.text).is_equal(en_riesgo.aviso_de_riesgo())
	assert_bool(riesgo.visible).is_true()

	pantalla.mostrar(ParteDeCierre.new(JORNADA_DE_PRUEBA, Apertura.obligatorias(), 0))
	assert_bool(riesgo.visible).is_false()


func test_mostrar_deja_el_boton_con_el_foco_para_alcanzarlo_sin_el_mouse() -> void:  # 017-AC10
	# El cursor del juego sigue tomado cuando la placa aparece —`jugador.gd` lo recaptura en cada
	# cuadro de física—, así que el puntero queda clavado en el centro de la ventana y «Seguir»
	# no se alcanza con el mouse. Sin el foco no hay forma de llegar a la noche 2 jugando.
	var pantalla := await _pantalla()
	pantalla.mostrar(_parte())
	var boton: Button = pantalla.get_node("Fondo/Panel/Continuar")
	(
		assert_bool(boton.has_focus())
		. override_failure_message("el botón de continuar no quedó con el foco")
		. is_true()
	)


func test_el_boton_de_continuar_despacha_el_cierre() -> void:  # 017-AC10
	# Es lo que reabre la jornada siguiente. Sin esta señal la partida se queda en la placa y no
	# hay forma de llegar a la noche 2.
	var pantalla := await _pantalla()
	pantalla.cierre_despachado.connect(_anotar_despacho)
	pantalla.mostrar(_parte())
	var boton: Button = pantalla.get_node("Fondo/Panel/Continuar")
	boton.pressed.emit()
	assert_int(_despachos).is_equal(1)
	assert_bool(pantalla.visible).is_false()


func test_la_pantalla_no_decide_como_cerro_la_noche() -> void:  # 017-AC8
	# El riesgo medido de este spec no es «hacer una pantalla»: es que la única regla nueva
	# termine acá adentro, donde nace sin test y ningún gate lo dice.
	var texto := FileAccess.get_file_as_string(PANTALLA)
	assert_str(texto).is_not_empty()
	(
		assert_array(_condiciones_en(texto))
		. override_failure_message("`pantalla_de_cierre.gd` decide en vez de copiar campos")
		. is_empty()
	)
	for nombre: String in NOMBRES_QUE_DECIDEN:
		(
			assert_bool(texto.contains(nombre))
			. override_failure_message("`pantalla_de_cierre.gd` nombra `%s`" % nombre)
			. is_false()
		)


func test_nadie_mira_la_pantalla_desde_abajo() -> void:  # 017-AC9
	var culpables: Array[String] = []
	var mirados := 0
	for capa: String in CAPAS_DE_ABAJO:
		for ruta in _scripts_de(capa):
			mirados += 1
			if FileAccess.get_file_as_string(ruta).contains("PantallaDeCierre"):
				culpables.append(ruta)
	# Sin esto el caso pasa por vacuidad el día que la recorrida no encuentre nada: cero archivos
	# mirados da cero culpables, y el rojo que tenía que aparecer no aparece nunca.
	(
		assert_int(mirados)
		. override_failure_message(
			"la recorrida no abrió un solo archivo de `dominio/` ni de `sistemas/`"
		)
		. is_greater(0)
	)
	(
		assert_array(culpables)
		. override_failure_message(
			"estos archivos nombran la pantalla desde abajo: %s" % ", ".join(culpables)
		)
		. is_empty()
	)


func _pantalla() -> PantallaDeCierre:
	var pantalla: PantallaDeCierre = auto_free(load(ESCENA).instantiate())
	add_child(pantalla)
	await get_tree().process_frame
	return pantalla


func _parte() -> ParteDeCierre:
	return ParteDeCierre.new(JORNADA_DE_PRUEBA, Apertura.obligatorias(), 1)


func _etiqueta(pantalla: PantallaDeCierre, nombre: String) -> Label:
	return pantalla.get_node("Fondo/Panel/" + nombre)


func _anotar_despacho() -> void:
	_despachos += 1


## Las líneas de código que abren una condición. Corta en el primer `#`, así que las palabras de
## los comentarios no cuentan, y busca por palabra entera: `verificar` no es un `if`.
func _condiciones_en(texto: String) -> Array[String]:
	var abiertas: Array[String] = []
	var condicion := RegEx.create_from_string("\\b(if|elif|match)\\b")
	for linea in texto.split("\n"):
		var codigo: String = linea.split("#")[0]
		if not condicion.search_all(codigo).is_empty():
			abiertas.append(linea.strip_edges())
	return abiertas


## Todos los `.gd` de una carpeta, recorriendo las subcarpetas. `DirAccess` y no una lista a
## mano: una lista se olvida del archivo nuevo justo el día que el archivo nuevo aparece.
func _scripts_de(carpeta: String) -> Array[String]:
	var encontrados: Array[String] = []
	for nombre in DirAccess.get_files_at(carpeta):
		if nombre.ends_with(".gd"):
			encontrados.append(carpeta + "/" + nombre)
	for subcarpeta in DirAccess.get_directories_at(carpeta):
		encontrados.append_array(_scripts_de(carpeta + "/" + subcarpeta))
	return encontrados
