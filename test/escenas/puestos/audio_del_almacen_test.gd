## El audio del local: los cuatro buses, la cáscara sin reglas, y que ningún test de este spec
## afirme sobre el estado de reproducción.
##
## **La escena se instancia y no se entra al árbol**, igual que las otras suites de `escenas/`.
extends GdUnitTestSuite

const ESCENA := "res://src/escenas/puestos/audio_del_almacen.tscn"
const SCRIPT := "res://src/escenas/puestos/audio_del_almacen.gd"
const ESCENA_DEL_ALMACEN := "res://src/escenas/almacen.tscn"
const SCRIPT_DEL_ALMACEN := "res://src/escenas/almacen.gd"
const LAYOUT := "res://default_bus_layout.tres"

## El archivo que declara los nombres de los buses. Es el único que los puede escribir como
## literal — el `.tres` del layout y `project.godot` los escriben otra vez porque no pueden leer
## un `const`, y por eso este archivo los compara contra el motor.
const DECLARA_LOS_BUSES := "res://src/dominio/ambiente/entrada_sonora.gd"

## Dónde **no** puede aparecer el nombre de un bus como literal.
const ARCHIVOS_QUE_NO_DECLARAN_BUSES := [
	"res://src/dominio/ambiente/tabla_de_sonidos.gd",
	"res://src/dominio/ambiente/ronda_de_voces.gd",
	"res://src/sistemas/marco/reproductor_de_sonidos.gd",
	"res://src/sistemas/marco/enlace_de_audio.gd",
	"res://src/escenas/puestos/audio_del_almacen.gd",
]

## Lo que ningún test de este spec puede nombrar. Está medido que en headless el driver dummy no
## mezcla: afirmar sobre ellos sería **rojo permanente**, y el arreglo tentador sería apagar el
## test. Se busca sobre `test/` entero, que es donde la tentación aparece.
##
## **Se arman por pedazos y no como literales**, y no es astucia: este archivo cae adentro de la
## búsqueda, así que escribirlos enteros lo pondría en rojo contra sí mismo. La alternativa era
## exceptuarlo, y una excepción es exactamente la puerta por la que el criterio se apaga.
const NOMBRES_DE_REPRODUCCION := ["play" + "ing", "get_playback" + "_position", "finish" + "ed"]

const CARPETA_DE_TESTS := "res://test"

const CARPETA_DE_FUENTES := "res://src"


func test_los_cuatro_buses_existen_en_el_motor() -> void:  # 021-AC3
	# Sin el layout el motor deja **un solo bus** y todo sale por `Master`: la mezcla entera
	# dejaría de existir sin que nada lo diga.
	for nombre: String in EntradaSonora.BUSES:
		(
			assert_int(AudioServer.get_bus_index(nombre))
			. override_failure_message("el bus `%s` no existe en el motor" % nombre)
			. is_greater(0)
		)


func test_cada_bus_manda_a_master() -> void:  # 021-AC3
	# Uno que mande a otro lado se saltearía el volumen general, y el jugador bajaría el volumen
	# del juego con un canal siguiendo igual de fuerte.
	for nombre: String in EntradaSonora.BUSES:
		var indice := AudioServer.get_bus_index(nombre)
		(
			assert_str(String(AudioServer.get_bus_send(indice)))
			. override_failure_message(
				"el bus `%s` no manda a `%s`" % [nombre, EntradaSonora.BUS_MAESTRO]
			)
			. is_equal(EntradaSonora.BUS_MAESTRO)
		)


func test_el_layout_de_buses_apunta_a_un_archivo_que_existe() -> void:  # 021-AC3
	# **Hoy no existía**: `project.godot` no declaraba ninguno y el motor caía al layout por
	# defecto. El ajuste y el archivo van juntos: uno sin el otro no cambia nada.
	var declarado: String = ProjectSettings.get_setting("audio/buses/default_bus_layout", "")
	assert_str(declarado).is_equal(LAYOUT)
	(
		assert_bool(FileAccess.file_exists(declarado))
		. override_failure_message("`%s` no existe: el motor cae a un solo bus" % declarado)
		. is_true()
	)


func test_ningun_nombre_de_bus_se_escribe_fuera_del_archivo_que_los_declara() -> void:  # 021-AC3
	# Una copia se desincroniza el día que un bus se renombre, y el canal quedaría saliendo por
	# `Master` sin que el motor diga una palabra.
	for ruta: String in ARCHIVOS_QUE_NO_DECLARAN_BUSES:
		var texto := FileAccess.get_file_as_string(ruta)
		(
			assert_str(texto)
			. override_failure_message("`%s` está vacío o no existe" % ruta)
			. is_not_empty()
		)
		for nombre: String in EntradaSonora.BUSES:
			(
				assert_bool(texto.contains('"%s"' % nombre))
				. override_failure_message("`%s` escribe el bus `%s` como literal" % [ruta, nombre])
				. is_false()
			)
	var declara := FileAccess.get_file_as_string(DECLARA_LOS_BUSES)
	for nombre: String in EntradaSonora.BUSES:
		assert_bool(declara.contains('"%s"' % nombre)).is_true()


func test_ningun_test_de_este_spec_afirma_sobre_el_estado_de_reproduccion() -> void:  # 021-AC7
	# **Es la decisión que hace existir al spec.** Se busca sobre `test/` entero y no sólo sobre
	# los de este spec: la tentación de afirmar sobre el estado de reproducción aparece en
	# cualquier suite que toque audio, y en headless eso es rojo permanente.
	for ruta: String in _suites():
		var texto := FileAccess.get_file_as_string(ruta)
		for nombre: String in NOMBRES_DE_REPRODUCCION:
			(
				assert_bool(texto.contains(nombre))
				. override_failure_message(
					"`%s` afirma sobre `%s`, que en headless no cambia nunca" % [ruta, nombre]
				)
				. is_false()
			)


func test_la_cascara_no_tiene_una_sola_regla() -> void:  # 021-AC10
	# Está medido que una regla escrita en `escenas/` da cero hallazgos en los dos gates.
	var texto := FileAccess.get_file_as_string(SCRIPT)
	assert_str(texto).is_not_empty()
	var decide := RegEx.create_from_string("(?m)^\\s*(if|elif|match)\\b").search_all(texto)
	assert_array(decide).override_failure_message("`audio_del_almacen.gd` decide algo").is_empty()


func test_el_almacen_instancia_el_audio_exactamente_una_vez() -> void:  # 021-AC10
	# Dos instancias serían dos tablas y dos rondas sobre los mismos eventos: cada sonido se
	# pediría dos veces y el jugador escucharía todo doble.
	var texto := FileAccess.get_file_as_string(ESCENA_DEL_ALMACEN)
	assert_str(texto).is_not_empty()
	assert_int(texto.count(ESCENA)).is_equal(1)


func test_el_dominio_no_nombra_un_solo_nodo_de_audio() -> void:  # 021-AC10
	# `AudioStreamPlayer` es un `Node` y `AudioServer` es el motor: los dos romperían la
	# propiedad de la que cuelga todo lo demás — que el dominio se ejerza sin levantar una escena.
	for ruta: String in ["entrada_sonora.gd", "tabla_de_sonidos.gd", "ronda_de_voces.gd"]:
		var texto := FileAccess.get_file_as_string("res://src/dominio/ambiente/" + ruta)
		assert_str(texto).is_not_empty()
		for prohibido: String in ["AudioStreamPlayer", "AudioServer"]:
			(
				assert_bool(texto.contains(prohibido))
				. override_failure_message("`%s` nombra `%s`" % [ruta, prohibido])
				. is_false()
			)


func test_la_cascara_carga_con_sus_dos_sistemas_cableados() -> void:  # 021-AC10
	# El `node_paths` de un `.tscn` escrito a mano es la trampa que deja los dos `@export` en
	# `null` sin un solo error, y el juego muere en el primer cuadro.
	var audio: Node = auto_free(load(ESCENA).instantiate())
	assert_object(audio.get("reproductor")).is_not_null()
	assert_object(audio.get("enlace")).is_not_null()


func test_cada_senal_de_la_tabla_la_declara_alguien_de_verdad() -> void:  # 021-AC9
	# **El agujero que deja el desacople.** El enlace es por nombre de señal, así que un nombre
	# que no existe no rompe nada: la fila cae en `sin_fuente()`, que es un estado normal, y las
	# suites del enlazador usan fuentes inventadas — con lo cual los seis nodos dan verde y ese
	# sonido no se pide nunca en el juego. Está medido: la fila del timbre decía
	# `timbre_de_la_ventanilla`, que no lo declara nadie, y nada lo dijo.
	#
	# Se busca sobre el texto de `src/` y no llamando a `has_signal()`: preguntarle a una clase
	# obligaría a nombrarla, que es justo lo que este spec no hace. Una fila que todavía no
	# tiene quién la dispare deja la señal **vacía** —`tiene_fuente()` ya cubre ese caso—, en
	# vez de nombrar una que no existe.
	var tabla := TablaDeSonidos.desde_disco()
	assert_object(tabla).is_not_null()
	var texto := ""
	for ruta: String in _fuentes():
		texto += FileAccess.get_file_as_string(ruta)
	assert_str(texto).is_not_empty()
	for entrada: EntradaSonora in tabla.entradas:
		if not entrada.tiene_fuente():
			continue
		var declarada := RegEx.create_from_string("(?m)^signal\\s+%s\\b" % entrada.senal)
		(
			assert_array(declarada.search_all(texto))
			. override_failure_message(
				"nadie declara `signal %s`: esa fila no suena nunca" % entrada.senal
			)
			. is_not_empty()
		)


func test_el_almacen_llega_cableado_al_audio_y_al_agarre() -> void:  # 021-AC10
	# Los dos `@export` que este spec le suma a la raíz. Está medido en este mismo lote que
	# borrar una entrada del `node_paths` deja 36 casos en verde con el nodo muerto: el caso que
	# barre los `@export` de la raíz lleva una lista escrita a mano, y estos dos no estaban.
	# Sin `_audio` el juego muere en el primer cuadro; sin `_agarre`, las tres señales del
	# agarre quedan mudas para siempre y nada lo dice.
	var almacen: Node3D = auto_free(load(ESCENA_DEL_ALMACEN).instantiate())
	for propiedad in ["_audio", "_agarre"]:
		(
			assert_object(almacen.get(propiedad))
			. override_failure_message(
				"`%s` quedó en null: falta su entrada en el `node_paths` de la raíz" % propiedad
			)
			. is_not_null()
		)


func test_el_cableado_enlaza_las_fuentes_y_arranca_el_ambiente() -> void:  # 021-AC10
	# La cáscara no se llama sola: quien le pasa las fuentes y quien arranca el bucle es la raíz.
	# Sin la primera línea el audio entero queda sin enlazar; sin la segunda, el ambiente del
	# local no suena nunca — y las dos fallan en silencio.
	var texto := FileAccess.get_file_as_string(SCRIPT_DEL_ALMACEN)
	assert_str(texto).is_not_empty()
	# La llamada se busca con un `RegEx` que se come los espacios: `gdformat` envuelve el
	# paréntesis cuando la lista de fuentes crece, y un `contains()` literal se rompería con el
	# reformateo en vez de con el bug.
	var enlaza := RegEx.create_from_string("_audio\\s*\\.\\s*enlazar\\(")
	assert_array(enlaza.search_all(texto)).is_not_empty()
	var ambiente := RegEx.create_from_string("_audio\\s*\\.\\s*arrancar_el_ambiente\\(\\)")
	assert_array(ambiente.search_all(texto)).is_not_empty()


## Todos los `.gd` de `src/`, para el caso de las señales de la tabla.
static func _fuentes(carpeta: String = CARPETA_DE_FUENTES) -> Array[String]:
	var encontradas: Array[String] = []
	for nombre in DirAccess.get_files_at(carpeta):
		if nombre.ends_with(".gd"):
			encontradas.append(carpeta + "/" + nombre)
	for sub in DirAccess.get_directories_at(carpeta):
		encontradas.append_array(_fuentes(carpeta + "/" + sub))
	return encontradas


## Todas las suites del repo, para el caso del AC7.
static func _suites(carpeta: String = CARPETA_DE_TESTS) -> Array[String]:
	var encontradas: Array[String] = []
	for nombre in DirAccess.get_files_at(carpeta):
		if nombre.ends_with("_test.gd"):
			encontradas.append(carpeta + "/" + nombre)
	for sub in DirAccess.get_directories_at(carpeta):
		encontradas.append_array(_suites(carpeta + "/" + sub))
	return encontradas
