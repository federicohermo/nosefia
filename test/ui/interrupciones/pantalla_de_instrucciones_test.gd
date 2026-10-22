extends GdUnitTestSuite

const ESCENA := preload("res://src/ui/interrupciones/pantalla_de_instrucciones.tscn")
const GUION := preload("res://src/dominio/investigacion/conversacion_con_el_jefe.tres")


func after_test() -> void:
	get_tree().paused = false
	await get_tree().process_frame
	await get_tree().process_frame


func _pantalla() -> PantallaDeInstrucciones:
	var viewport: SubViewport = auto_free(SubViewport.new())
	viewport.size = Vector2i(1920, 1080)
	viewport.process_mode = Node.PROCESS_MODE_PAUSABLE
	get_tree().root.add_child(viewport)
	var pantalla: PantallaDeInstrucciones = ESCENA.instantiate()
	viewport.add_child(pantalla)
	return pantalla


func _boton(pantalla: PantallaDeInstrucciones, nombre: String) -> Button:
	return pantalla.get(nombre)


func test_subida_llega_en_trescientos_milisegundos_reales() -> void:  # AC-EMP-049
	var pantalla := _pantalla()
	var ahora: Array[int] = [0]
	pantalla.set("_ahora", func() -> int: return ahora[0])
	pantalla.mostrar(_mensajes_de_la_primera_jornada())
	var marco: Control = pantalla.get("_marco")
	assert_float(marco.position.y).is_equal(1080.0)
	_cuadros(ahora, 150000, [pantalla])
	assert_float(marco.position.y).is_equal_approx(540.0, 0.01)
	_cuadros(ahora, 299999, [pantalla])
	assert_float(marco.position.y).is_greater(0.0)
	assert_bool(pantalla.is_processing()).is_true()
	_cuadros(ahora, 300000, [pantalla])
	assert_float(marco.position.y).is_zero()
	assert_bool(pantalla.is_processing()).is_false()


## El cuadro que abre la pantalla tarda: con el tiempo entero, se comía la subida de un salto.
func test_un_cuadro_largo_adelanta_la_subida_un_paso_maximo() -> void:  # AC-EMP-049
	var pantalla := _pantalla()
	var ahora: Array[int] = [0]
	pantalla.set("_ahora", func() -> int: return ahora[0])
	pantalla.mostrar(_mensajes_de_la_primera_jornada())
	ahora[0] = 150000
	pantalla._process(0.0)
	var marco: Control = pantalla.get("_marco")
	var avance := CabeceraConSolapa.PASO_MAXIMO / PantallaDeInstrucciones.DURACION_DE_LA_SUBIDA
	assert_float(marco.position.y).is_equal_approx(1080.0 * (1.0 - avance), 0.01)


func _sin_formato(texto: String) -> String:
	return texto.replace("[b]", "").replace("[/b]", "")


func _comprobar_pantalla(
	pantalla: PantallaDeInstrucciones, numero: int, jornada: int = ReglasDeLaPartida.PRIMERA_JORNADA
) -> void:
	var contenido: Control = pantalla.get("_contenido")
	var pasos := InstruccionesDelJefe.pasos_de(_mensajes_de(jornada))
	var total := pasos.size()
	var paso: InstruccionesDelJefe.Paso = pasos[numero - 1]
	var mensajes_con_foto := _fotos_del_paso(paso)
	var cuerpos: Array[Node] = contenido.find_children("*", "RichTextLabel", false, false)
	for indice in paso.textos.size():
		var cuerpo: RichTextLabel = cuerpos[indice]
		assert_str(cuerpo.get_parsed_text()).is_equal(_sin_formato(paso.textos[indice].texto))
	if mensajes_con_foto.is_empty():
		assert_int(cuerpos.size()).is_equal(paso.textos.size())
	var fotos: Array[Node] = contenido.find_children("*", "TextureRect", false, false)
	var con_caja := mensajes_con_foto.any(
		func(mensaje: Mensaje) -> bool:
			return mensaje.identidad == PantallaDeInstrucciones.FOTO_DEL_LECTOR
	)
	var cantidad := 1 + mensajes_con_foto.size() + (2 if con_caja else 0)
	assert_int(fotos.size()).is_equal(cantidad)
	for indice in mensajes_con_foto.size():
		if indice + 1 < fotos.size():
			var foto: TextureRect = fotos[indice + 1]
			assert_object(foto.texture).is_same(mensajes_con_foto[indice].foto)
	var contador: Label = pantalla.get("_contador")
	assert_str(contador.text).is_equal("%d/%d" % [numero, total])
	var retrato: Control = pantalla.get("_retrato")
	assert_bool(retrato.visible).is_true()
	var volver := _boton(pantalla, "_volver")
	assert_bool(volver.visible).is_true()
	assert_bool(volver.disabled).is_equal(numero == 1)
	assert_str(_boton(pantalla, "_siguiente").text).is_equal(
		(
			PantallaDeInstrucciones.TEXTO_DE_COMENZAR
			if numero == total
			else PantallaDeInstrucciones.TEXTO_DE_SIGUIENTE
		)
	)
	assert_int(pantalla.find_children("*", "ScrollContainer", true, false).size()).is_zero()


func test_pantallas_de_la_primera_y_ok_idempotente() -> void:  # AC-EMP-045, AC-EMP-046
	var pantalla := _pantalla()
	pantalla.mostrar(_mensajes_de_la_primera_jornada())
	var total := InstruccionesDelJefe.pasos_de(_mensajes_de_la_primera_jornada()).size()
	var botones: Control = pantalla.get("_botones")
	var posicion := botones.position
	var siguiente := _boton(pantalla, "_siguiente")
	for numero in range(1, total + 1):
		await get_tree().process_frame
		await get_tree().process_frame
		_comprobar_pantalla(pantalla, numero)
		assert_vector(botones.position).is_equal(posicion)
		if numero < total:
			siguiente.pressed.emit()
	var volver := _boton(pantalla, "_volver")
	volver.pressed.emit()
	await get_tree().process_frame
	_comprobar_pantalla(pantalla, total - 1)
	var comienzos: Array[int] = [0]
	pantalla.comenzar_pedido.connect(func() -> void: comienzos[0] += 1)
	siguiente.pressed.emit()
	siguiente.pressed.emit()
	siguiente.pressed.emit()
	assert_int(comienzos[0]).is_equal(1)
	assert_bool(pantalla.visible).is_false()


func test_la_segunda_y_la_tercera_cuentan_sus_pantallas() -> void:  # AC-EMP-045, AC-EMP-046
	var primera := ReglasDeLaPartida.PRIMERA_JORNADA
	var segunda := _pantalla()
	segunda.mostrar(_mensajes_de(primera + 1))
	await get_tree().process_frame
	_comprobar_pantalla(segunda, 1, primera + 1)
	var tercera := _pantalla()
	tercera.mostrar(_mensajes_de(primera + 2))
	await get_tree().process_frame
	_comprobar_pantalla(tercera, 1, primera + 2)
	var comienzos: Array[int] = [0]
	segunda.comenzar_pedido.connect(func() -> void: comienzos[0] += 1)
	_boton(segunda, "_siguiente").pressed.emit()
	await get_tree().process_frame
	_comprobar_pantalla(segunda, 2, primera + 1)
	assert_int(comienzos[0]).is_zero()
	_boton(segunda, "_siguiente").pressed.emit()
	_boton(segunda, "_siguiente").pressed.emit()
	assert_int(comienzos[0]).is_equal(1)
	assert_bool(segunda.visible).is_false()
	var comienzos_de_la_tercera: Array[int] = [0]
	tercera.comenzar_pedido.connect(func() -> void: comienzos_de_la_tercera[0] += 1)
	assert_str(_boton(tercera, "_siguiente").text).is_equal(
		PantallaDeInstrucciones.TEXTO_DE_COMENZAR
	)
	_boton(tercera, "_siguiente").pressed.emit()
	_boton(tercera, "_siguiente").pressed.emit()
	assert_int(comienzos_de_la_tercera[0]).is_equal(1)
	assert_bool(tercera.visible).is_false()


func test_volver_tres_veces_recupera_solo_la_primera_pantalla() -> void:  # AC-EMP-045
	var pantalla := _pantalla()
	pantalla.mostrar(_mensajes_de_la_primera_jornada())
	for _paso in 3:
		_boton(pantalla, "_siguiente").pressed.emit()
	for _paso in 4:
		_boton(pantalla, "_volver").pressed.emit()
	await get_tree().process_frame
	_comprobar_pantalla(pantalla, 1)
	var contenido: Control = pantalla.get("_contenido")
	assert_int(contenido.get_child_count()).is_equal(2)


func test_pantallas_sin_scroll_en_ambos_viewports() -> void:  # AC-EMP-045, AC-EMP-046
	for resolucion: Vector2i in [Vector2i(1920, 1080), Vector2i(1280, 720)]:
		var pantalla := _pantalla()
		var viewport: SubViewport = pantalla.get_viewport()
		viewport.size = resolucion
		pantalla.mostrar(_mensajes_de_la_primera_jornada())
		pantalla.set("_avance", 1.0)
		pantalla.set("_transcurrido", roundi(PantallaDeInstrucciones.DURACION_DE_LA_SUBIDA * 1e6))
		pantalla.call("_ajustar")
		var total := InstruccionesDelJefe.pasos_de(_mensajes_de_la_primera_jornada()).size()
		for numero in range(1, total + 1):
			await get_tree().process_frame
			await get_tree().process_frame
			var botones: Control = pantalla.get("_botones")
			var posicion := botones.global_position
			var contenido: Control = pantalla.get("_contenido")
			for hijo: Control in contenido.get_children():
				assert_float(hijo.get_global_rect().end.y).is_less(
					botones.get_global_rect().position.y
				)
				assert_float(hijo.get_global_rect().end.x).is_less_equal(float(resolucion.x))
			var rueda := InputEventMouseButton.new()
			rueda.button_index = MOUSE_BUTTON_WHEEL_DOWN
			rueda.pressed = true
			rueda.position = contenido.get_global_rect().get_center()
			viewport.push_input(rueda)
			await get_tree().process_frame
			assert_vector(botones.global_position).is_equal(posicion)
			_comprobar_pantalla(pantalla, numero)
			if numero < total:
				_boton(pantalla, "_siguiente").pressed.emit()


func test_pausa_conserva_la_subida_y_no_cobra_el_tiempo_pausado() -> void:  # AC-EMP-049
	var pantalla := _pantalla()
	var ahora: Array[int] = [0]
	pantalla.set("_ahora", func() -> int: return ahora[0])
	pantalla.mostrar(_mensajes_de_la_primera_jornada())
	_cuadros(ahora, 150000, [pantalla])
	var marco: Control = pantalla.get("_marco")
	var posicion := marco.position
	get_tree().paused = true
	ahora[0] += 120000000
	for _cuadro in 4:
		await get_tree().process_frame
	assert_vector(marco.position).is_equal(posicion)
	get_tree().paused = false
	_cuadros(ahora, ahora[0] + 150000, [pantalla])
	assert_float(marco.position.y).is_zero()


func test_los_pares_van_despues_del_texto_en_orden_y_dentro_del_ancho() -> void:  # AC-EMP-046
	for caso: Array in [
		[1, 1, ["J1_FotoReloj", "J1_Foto02"]],
		[2, 0, ["J2_FotoGondolas", "J1_Foto07"]],
	]:
		var pantalla := _pantalla()
		pantalla.mostrar(_mensajes_de(caso[0]))
		for avance: int in caso[1]:
			_boton(pantalla, "_siguiente").pressed.emit()
		await get_tree().process_frame
		await get_tree().process_frame
		var contenido: Control = pantalla.get("_contenido")
		var fotos: Array[TextureRect] = []
		for identidad: String in caso[2]:
			for mensaje in GUION.mensajes:
				if mensaje.identidad == identidad:
					for imagen: TextureRect in contenido.find_children(
						"*", "TextureRect", true, false
					):
						if imagen.texture == mensaje.foto:
							fotos.append(imagen)
		assert_int(fotos.size()).is_equal(2)
		if fotos.size() != 2:
			continue
		var textos := contenido.find_children("*", "RichTextLabel", true, false)
		var cuerpo := textos[0] as RichTextLabel
		var izquierda := fotos[0].get_rect()
		var derecha := fotos[1].get_rect()
		assert_float(izquierda.position.y).is_greater_equal(cuerpo.get_rect().end.y)
		assert_float(izquierda.end.x).is_less(derecha.position.x)
		assert_float(izquierda.position.y).is_equal(derecha.position.y)
		assert_float(izquierda.size.y).is_equal(derecha.size.y)
		assert_float(izquierda.position.x).is_greater_equal(0.0)
		assert_float(derecha.end.x).is_less_equal(PantallaDeInstrucciones.ANCHO_DEL_TEXTO)
		for foto in fotos:
			assert_int(foto.stretch_mode).is_equal(TextureRect.STRETCH_KEEP_ASPECT_COVERED)
		var leyendas: Array[String] = []
		var rectangulos: Array[Rect2] = []
		var limites := Rect2(Vector2.ZERO, contenido.size)
		for texto: RichTextLabel in textos:
			if texto == cuerpo:
				continue
			leyendas.append(texto.get_parsed_text())
			var rectangulo := texto.get_rect()
			assert_bool(limites.encloses(rectangulo)).is_true()
			for foto in fotos:
				assert_bool(rectangulo.intersects(foto.get_rect())).is_false()
			for anterior in rectangulos:
				assert_bool(rectangulo.intersects(anterior)).is_false()
			rectangulos.append(rectangulo)
		var esperadas: Array[String] = []
		for identidad: String in caso[2]:
			var ficha: Dictionary = PantallaDeInstrucciones.FOTOS[identidad]
			esperadas.append(ficha["titulo"])
			esperadas.append("-" + ficha["sector"])
		assert_array(leyendas).contains_exactly_in_any_order(esperadas)


func test_las_fotos_individuales_conservan_marco_y_caja_con_ticket() -> void:  # AC-EMP-046
	for identidad: String in ["J1_Foto03", "J1_Foto04", "J1_Foto06", "J1_Foto09", "J1_Foto11"]:
		var foto: Mensaje
		for mensaje in GUION.mensajes:
			if mensaje.identidad == identidad:
				foto = mensaje
		assert_object(foto).is_not_null()
		if foto == null:
			continue
		var texto := Mensaje.new()
		texto.texto = "Instrucción con una foto"
		var pantalla := _pantalla()
		pantalla.mostrar([foto, texto])
		await get_tree().process_frame
		var contenido: Control = pantalla.get("_contenido")
		var imagenes := contenido.find_children("*", "TextureRect", true, false)
		var fotografias := 0
		var caja := 0
		var ticket := 0
		for imagen: TextureRect in imagenes:
			if imagen.texture == foto.foto:
				fotografias += 1
				var marco: Vector2 = PantallaDeInstrucciones.FOTOS[identidad]["tamano"]
				assert_vector(imagen.size).is_equal(marco - Vector2(12, 12))
				assert_int(imagen.stretch_mode).is_equal(TextureRect.STRETCH_KEEP_ASPECT_COVERED)
			if imagen.texture == PantallaDeInstrucciones.CAJA:
				caja += 1
			if imagen.texture == PantallaDeInstrucciones.TICKET:
				ticket += 1
		assert_int(fotografias).is_equal(1)
		assert_int(caja).is_equal(1 if identidad == PantallaDeInstrucciones.FOTO_DEL_LECTOR else 0)
		assert_int(ticket).is_equal(caja)


func _fotos_del_paso(paso: InstruccionesDelJefe.Paso) -> Array[Mensaje]:
	var fotos: Variant = paso.get("fotos")
	assert_bool(fotos is Array).is_true()
	if not fotos is Array:
		return []
	return fotos


## Avanza el reloj hasta `hasta` en cuadros de 10 ms, como un juego que corre parejo.
func _cuadros(ahora: Array[int], hasta: int, nodos: Array[Node]) -> void:
	while ahora[0] < hasta:
		ahora[0] = mini(ahora[0] + 10000, hasta)
		for nodo in nodos:
			nodo.call("_process", 0.0)


func _mensajes_de_la_primera_jornada() -> Array[Mensaje]:
	return _mensajes_de(ReglasDeLaPartida.PRIMERA_JORNADA)


func _mensajes_de(jornada: int) -> Array[Mensaje]:
	return InstruccionesDelJefe.de_la_jornada(GUION.mensajes, jornada)
