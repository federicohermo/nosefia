## El audio del local: los cuatro buses, la cáscara sin reglas, y que ningún test de este spec
## afirme sobre el estado de reproducción.
##
## **La escena se instancia y no se entra al árbol**, igual que las otras suites de `escenas/`.
## Salvo en los casos que escuchan el local entero: lo que suena desde un lugar tiene que estar en
## el árbol, y fuera de él se rechaza por no tener posición.
extends GdUnitTestSuite

const AperturaConLugar := preload("res://test/escenas/apertura_con_lugar.gd")

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

## El reproductor del local, adentro del almacén.
const REPRODUCTOR := "Servicios/AudioDelAlmacen/Reproductor"


func test_los_cuatro_buses_existen_en_el_motor() -> void:  # AC-AMB-003
	# Sin el layout el motor deja **un solo bus** y todo sale por `Master`: la mezcla entera
	# dejaría de existir sin que nada lo diga.
	for nombre: String in EntradaSonora.BUSES:
		(
			assert_int(AudioServer.get_bus_index(nombre))
			. override_failure_message("el bus `%s` no existe en el motor" % nombre)
			. is_greater(0)
		)


func test_cada_bus_manda_a_master() -> void:
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


func test_el_layout_de_buses_apunta_a_un_archivo_que_existe() -> void:
	# El motor trae esta misma ruta como valor por defecto, así que la igualdad pasa aunque
	# `project.godot` no declare el ajuste. Lo que este caso protege es el archivo: sin él el
	# motor deja un solo bus y toda la mezcla sale por `Master`.
	var declarado: String = ProjectSettings.get_setting("audio/buses/default_bus_layout", "")
	assert_str(declarado).is_equal(LAYOUT)
	(
		assert_bool(FileAccess.file_exists(declarado))
		. override_failure_message("`%s` no existe: el motor cae a un solo bus" % declarado)
		. is_true()
	)


func test_ningun_nombre_de_bus_se_escribe_fuera_del_archivo_que_los_declara() -> void:
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


func test_ningun_test_de_este_spec_afirma_sobre_el_estado_de_reproduccion() -> void:
	# **Es la decisión que hace existir al spec.** Se busca sobre `test/` entero y no sólo sobre
	# los de este spec: la tentación de afirmar sobre el estado de reproducción aparece en
	# cualquier suite que toque audio, y en headless eso es rojo permanente.
	for ruta: String in _suites():
		var texto := FileAccess.get_file_as_string(ruta)
		var estados := _estados_de_audio_en(texto)
		(
			assert_array(estados)
			. override_failure_message(
				(
					"`%s` afirma sobre estados de audio que no cambian en headless: %s"
					% [ruta, estados]
				)
			)
			. is_empty()
		)


func test_el_detector_acepta_fin_de_tween_y_rechaza_fin_de_audio() -> void:
	var fin: String = NOMBRES_DE_REPRODUCCION[-1]
	var animacion := "var bajada: Tween\nbajada.%s.connect(func(): pass)" % fin
	assert_array(_estados_de_audio_en(animacion)).is_empty()
	for tipo: String in ["AudioStreamPlayer", "AudioStreamPlayer3D"]:
		var sonido := "var voz: %s\nawait voz.%s" % [tipo, fin]
		assert_array(_estados_de_audio_en(sonido)).is_equal([fin])
	var dos_funciones := (
		"func animar():\n\tvar voz: Tween\n\tawait voz.%s\n" % fin
		+ "func sonar():\n\tvar voz: AudioStreamPlayer\n\tawait voz.%s" % fin
	)
	assert_array(_estados_de_audio_en(dos_funciones)).is_equal([fin])


## La senal de fin se admite solo para un receptor de tipo Tween en ese mismo alcance.
## Un receptor desconocido sigue bloqueado: no se pierde el guard de audio.
static func _estados_de_audio_en(texto: String) -> Array[String]:
	var estados: Array[String] = []
	for indice in NOMBRES_DE_REPRODUCCION.size() - 1:
		var nombre: String = NOMBRES_DE_REPRODUCCION[indice]
		if texto.contains(nombre):
			estados.append(nombre)
	var fin: String = NOMBRES_DE_REPRODUCCION[-1]
	var declaracion := RegEx.new()
	declaracion.compile("([A-Za-z_]\\w*)\\s*:\\s*Tween\\b")
	var creacion := RegEx.new()
	creacion.compile("\\bvar\\s+(\\w+)\\s*:=\\s*(?:\\w+\\.)?create_tween\\s*\\(")
	var acceso := RegEx.new()
	acceso.compile("(?:(\\b\\w+)\\s*)?\\.\\s*" + fin + "\\b")
	var globales: Dictionary[String, bool] = {}
	var tweens: Dictionary[String, bool] = {}
	var en_funcion := false
	for linea: String in texto.split("\n"):
		var inicio := linea.strip_edges()
		if inicio.begins_with("func ") or inicio.begins_with("static func "):
			en_funcion = true
			tweens = globales.duplicate()
		for patron: RegEx in [declaracion, creacion]:
			for encontrado: RegExMatch in patron.search_all(linea):
				var nombre := encontrado.get_string(1)
				tweens[nombre] = true
				if not en_funcion:
					globales[nombre] = true
		for encontrado: RegExMatch in acceso.search_all(linea):
			if not tweens.has(encontrado.get_string(1)) and not estados.has(fin):
				estados.append(fin)
	return estados


func test_la_cascara_no_tiene_una_sola_regla() -> void:
	# Está medido que una regla escrita en `escenas/` da cero hallazgos en los dos gates.
	var texto := FileAccess.get_file_as_string(SCRIPT)
	assert_str(texto).is_not_empty()
	var decide := RegEx.create_from_string("(?m)^\\s*(if|elif|match)\\b").search_all(texto)
	assert_array(decide).override_failure_message("`audio_del_almacen.gd` decide algo").is_empty()


func test_el_almacen_instancia_el_audio_exactamente_una_vez() -> void:
	# Dos instancias serían dos tablas y dos rondas sobre los mismos eventos: cada sonido se
	# pediría dos veces y el jugador escucharía todo doble.
	var texto := FileAccess.get_file_as_string(
		"res://src/escenas/puestos/servicios_del_almacen.tscn"
	)
	assert_str(texto).is_not_empty()
	assert_int(texto.count(ESCENA)).is_equal(1)


func test_el_dominio_no_nombra_un_solo_nodo_de_audio() -> void:
	# `AudioStreamPlayer` es un `Node` y `AudioServer` es el motor: los dos romperían la
	# propiedad de la que cuelga todo lo demás — que el dominio se ejerza sin levantar una escena.
	for ruta: String in DirAccess.get_files_at("res://src/dominio/ambiente"):
		if not ruta.ends_with(".gd"):
			continue
		var texto := FileAccess.get_file_as_string("res://src/dominio/ambiente/" + ruta)
		assert_str(texto).is_not_empty()
		for prohibido: String in ["AudioStreamPlayer", "AudioServer"]:
			(
				assert_bool(texto.contains(prohibido))
				. override_failure_message("`%s` nombra `%s`" % [ruta, prohibido])
				. is_false()
			)


func test_la_cascara_carga_con_sus_dos_sistemas_cableados() -> void:
	# El `node_paths` de un `.tscn` escrito a mano es la trampa que deja los dos `@export` en
	# `null` sin un solo error, y el juego muere en el primer cuadro.
	var audio: Node = auto_free(load(ESCENA).instantiate())
	assert_object(audio.get("reproductor")).is_not_null()
	assert_object(audio.get("enlace")).is_not_null()


func test_cada_senal_de_la_tabla_la_declara_alguien_de_verdad() -> void:
	# **El agujero que deja el desacople.** El enlace es por nombre de señal, así que un nombre
	# que no existe no rompe nada: la fila cae en `sin_fuente()`, que es un estado normal, y las
	# suites del enlazador usan fuentes inventadas — con lo cual los nodos dan verde y ese
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


func test_el_almacen_llega_cableado_al_audio_y_al_agarre() -> void:
	# Los dos `@export` que este spec le suma a la raíz. Está medido en este mismo lote que
	# borrar una entrada del `node_paths` deja 36 casos en verde con el nodo muerto: el caso que
	# barre los `@export` de la raíz lleva una lista escrita a mano, y estos dos no estaban.
	# Sin `_audio` el juego muere en el primer cuadro; sin `_agarre`, las tres señales del
	# agarre quedan mudas para siempre y nada lo dice.
	var almacen: Node3D = auto_free(load(ESCENA_DEL_ALMACEN).instantiate())
	for propiedad: String in ["_audio", "_agarre"]:
		(
			assert_object(almacen.get(propiedad))
			. override_failure_message(
				"`%s` quedó en null: falta su entrada en el `node_paths` de la raíz" % propiedad
			)
			. is_not_null()
		)


func test_el_cableado_enlaza_las_fuentes_y_arranca_el_ambiente() -> void:
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


func test_cada_emisor_de_la_tabla_esta_en_la_escena() -> void:
	# Un emisor que falta deja su fila rechazada por no tener lugar, y el timbre no suena nunca.
	var audio: Node = auto_free(load(ESCENA).instantiate())
	var emisores: Node3D = audio.get("emisores")
	assert_object(emisores).is_not_null()
	if emisores == null:
		return
	for entrada: EntradaSonora in TablaDeSonidos.desde_disco().entradas:
		if entrada.emisor == &"":
			continue
		var emisor := emisores.get_node_or_null(NodePath(String(entrada.emisor)))
		(
			assert_object(emisor)
			. override_failure_message("la escena no tiene el emisor `%s`" % entrada.emisor)
			. is_not_null()
		)


func test_el_ambiente_tiene_sus_emisores_en_la_heladera_y_los_tubos() -> void:
	var audio: Node = auto_free(load(ESCENA).instantiate())
	var emisores: Node3D = audio.get("emisores")
	var ambiente := TablaDeSonidos.desde_disco().de(EntradaSonora.Evento.AMBIENTE_DEL_LOCAL)
	var neon := emisores.get_node(NodePath(String(ambiente.emisor)))
	assert_int(neon.get_child_count()).is_greater(EmisoresDelAmbiente.TOPE)


func test_el_jugador_es_una_fuente_del_audio() -> void:
	# Sin esto `paso_dado` queda sin fuente, que es un estado normal y nada lo avisa.
	var texto := FileAccess.get_file_as_string(SCRIPT_DEL_ALMACEN)
	var fuentes := RegEx.create_from_string("(?s)_audio\\s*\\.\\s*enlazar\\(\\s*\\[([^\\]]*)\\]")
	var hallado := fuentes.search(texto)
	assert_object(hallado).is_not_null()
	if hallado != null:
		assert_str(hallado.get_string(1)).contains("_jugador")


func test_la_jornada_arranca_la_musica_y_el_cierre_la_corta() -> void:
	var cascara := FileAccess.get_file_as_string(SCRIPT)
	for funcion: String in ["arrancar_el_ambiente", "callar_la_musica"]:
		var cuerpo := cascara.get_slice("func %s(" % funcion, 1).get_slice("\nfunc ", 0)
		assert_str(cuerpo).contains("EntradaSonora.Evento.MUSICA_DE_LA_NOCHE")
	var texto := FileAccess.get_file_as_string(SCRIPT_DEL_ALMACEN)
	var corta := RegEx.create_from_string("_audio\\s*\\.\\s*callar_la_musica\\(\\)")
	assert_array(corta.search_all(texto)).is_not_empty()


# AC-AMB-024 AC-AMB-025
func test_el_balde_y_sus_gestos_suenan_en_el_local_sin_un_rechazo() -> void:
	# El limpiador de la escena, el agarre de la escena y el cableado de la raíz: que las filas
	# existan no dice que el local las ate.
	var almacen: Node3D = auto_free(load(ESCENA_DEL_ALMACEN).instantiate())
	add_child(almacen)
	await get_tree().physics_frame
	(almacen.get("_jugador") as Node3D).set_physics_process(false)
	var escucha := _escuchar(almacen)
	var balde: RigidBody3D = almacen.get_node("Objetos/Balde")
	var agarre: Agarre = almacen.get("_agarre")
	assert_bool(agarre.pedir_agarrar(balde.get("datos"), balde)).is_true()
	var limpiador: Limpiador = almacen.get("_limpiador")
	var id_del_balde := ReglasDeLaLimpieza.ID_DEL_BALDE
	for uso: Array in [
		[id_del_balde, ReglasDeLaLimpieza.ID_DEL_LAVATORIO],
		[&"jabon_azul", id_del_balde],
		[ReglasDeLaLimpieza.ID_DE_LA_MOPA, id_del_balde],
		[id_del_balde, ReglasDeLaLimpieza.ID_DEL_INODORO],
		[id_del_balde, ReglasDeLaLimpieza.ID_DEL_INODORO],
	]:
		limpiador.usar(uso[0], uso[1])
	var esperados := [
		EntradaSonora.Evento.OBJETO_AGARRADO,
		EntradaSonora.Evento.BALDE_LLENADO,
		EntradaSonora.Evento.BALDE_TENIDO,
		EntradaSonora.Evento.MOPA_MOJADA,
		EntradaSonora.Evento.BALDE_VACIADO,
	]
	var de_estos := func(evento: EntradaSonora.Evento) -> bool: return esperados.has(evento)
	assert_array(escucha["pedidos"].filter(de_estos)).is_equal(esperados)
	assert_array(escucha["rechazados"].filter(de_estos)).is_empty()
	var reproductor: ReproductorDeSonidos = almacen.get_node(REPRODUCTOR)
	assert_array(_audios(reproductor.voces_en_el_espacio())).contains(["SFX_OBJETO_Balde_Alzar"])
	(
		assert_array(_audios(reproductor.voces()))
		. contains(
			[
				"SFX_OBJETO_Balde_Llenar",
				"SFX_OBJETO_Jabon_VertirEnBalde",
				"SFX_OBJETO_Mopa_MojarEnBalde",
				"SFX_OBJETO_Balde_Vaciar",
			]
		)
	)


func test_devolver_una_unidad_suena_una_vez_desde_la_mano() -> void:  # AC-AMB-026
	# Con el clic sobre la caja, como en el juego: el primero saca y el segundo devuelve.
	var almacen: Node3D = auto_free(load(ESCENA_DEL_ALMACEN).instantiate())
	add_child(almacen)
	await get_tree().physics_frame
	AperturaConLugar.abrir_con_todo_el_lugar(almacen)
	(almacen.get("_jugador") as Node3D).set_physics_process(false)
	var escucha := _escuchar(almacen)
	var puesto: Node3D = almacen.get("_reposicion_manual")
	var caja: Node3D = (almacen.get("_cajas_de_productos") as Array)[Producto.Id.ACTRONCITO]
	var repositor: Repositor = almacen.get("_repositor")
	var lugares: Array[Vector3] = []
	repositor.unidad_devuelta.connect(
		func(nodo: Node3D, _producto: Producto) -> void: lugares.append(nodo.global_position)
	)
	puesto.call("usar_la_caja", caja)
	assert_object(repositor.agarre.manos().sostenido() as UnidadDeProducto).is_not_null()
	puesto.call("usar_la_caja", caja)
	assert_object(repositor.agarre.manos().sostenido()).is_null()
	assert_int(escucha["pedidos"].count(EntradaSonora.Evento.UNIDAD_DEVUELTA)).is_equal(1)
	assert_bool(escucha["rechazados"].has(EntradaSonora.Evento.UNIDAD_DEVUELTA)).is_false()
	assert_int(lugares.size()).is_equal(1)
	var reproductor: ReproductorDeSonidos = almacen.get_node(REPRODUCTOR)
	var dejar: Array[AudioStreamPlayer3D] = []
	for voz in reproductor.voces_en_el_espacio():
		if voz.stream != null and _audio(voz.stream) == "SFX_OBJETO_Cajita_Dejar":
			dejar.append(voz)
	assert_int(dejar.size()).is_equal(1)
	if dejar.size() != 1 or lugares.size() != 1:
		return
	assert_vector(dejar[0].global_position).is_equal_approx(lugares[0], Vector3.ONE * 0.001)
	assert_float(dejar[0].volume_db).is_equal(0.0)
	assert_str(dejar[0].bus).is_equal(EntradaSonora.BUS_DE_EFECTOS)


## Lo que el reproductor del local pide y lo que rechaza, evento por evento y en orden.
func _escuchar(almacen: Node3D) -> Dictionary:
	var reproductor: ReproductorDeSonidos = almacen.get_node(REPRODUCTOR)
	var escucha := {"pedidos": [], "rechazados": []}
	reproductor.sonido_pedido.connect(
		func(evento: EntradaSonora.Evento) -> void: escucha["pedidos"].append(evento)
	)
	reproductor.sonido_rechazado.connect(
		func(evento: EntradaSonora.Evento, _motivo: ReproductorDeSonidos.Motivo) -> void:
			escucha["rechazados"].append(evento)
	)
	return escucha


## El nombre del audio de un stream, sin carpeta ni extensión.
static func _audio(stream: AudioStream) -> String:
	return stream.resource_path.get_file().get_basename()


## Los nombres de los audios que quedaron pedidos en esas voces.
static func _audios(voces: Array) -> Array:
	var nombres := []
	for voz: Node in voces:
		var stream: AudioStream = voz.get(&"stream")
		if stream != null:
			nombres.append(_audio(stream))
	return nombres


## Todos los `.gd` de `src/`, para el caso de las señales de la tabla.
static func _fuentes(carpeta: String = CARPETA_DE_FUENTES) -> Array[String]:
	var encontradas: Array[String] = []
	for nombre in DirAccess.get_files_at(carpeta):
		if nombre.ends_with(".gd"):
			encontradas.append(carpeta + "/" + nombre)
	for sub in DirAccess.get_directories_at(carpeta):
		encontradas.append_array(_fuentes(carpeta + "/" + sub))
	return encontradas


## Todas las suites del repo, para el caso que las recorre.
static func _suites(carpeta: String = CARPETA_DE_TESTS) -> Array[String]:
	var encontradas: Array[String] = []
	for nombre in DirAccess.get_files_at(carpeta):
		if nombre.ends_with("_test.gd"):
			encontradas.append(carpeta + "/" + nombre)
	for sub in DirAccess.get_directories_at(carpeta):
		encontradas.append_array(_suites(carpeta + "/" + sub))
	return encontradas
