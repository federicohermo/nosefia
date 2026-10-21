## La bandeja de chats: qué está sin leer y qué ya se leyó.
##
## **Lo leído vive acá y no en el `.tres`**, que es la decisión que este spec compró: está medido
## que dos `load()` del mismo recurso devuelven la misma instancia, así que marcar un chat en el
## recurso dejaría al test siguiente —y a la partida siguiente— empezando leído.
extends GdUnitTestSuite

const JEFE := Conversacion.Interlocutor.JEFE
const PRIMERA := ReglasDeLaPartida.PRIMERA_JORNADA
const COMPLETA := ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA


## Cada devolución queda después de los mensajes de su jornada y antes de los de la siguiente.
func test_las_instrucciones_llegan_con_su_jornada() -> void:  # AC-INV-065, AC-EMP-066
	var guion := Conversacion.de(JEFE)
	var bandeja := Bandeja.new([guion])
	var esperado: Array[Mensaje] = []
	var devoluciones: Array[Mensaje] = []
	for jornada in range(PRIMERA, COMPLETA + 1):
		bandeja.abrir_jornada(jornada)
		var propios := guion.mensajes.filter(
			func(mensaje: Mensaje) -> bool: return mensaje.jornada == jornada
		)
		assert_array(propios).is_not_empty()
		esperado.append_array(propios)
		assert_array(bandeja.mensajes_de(JEFE)).is_equal(esperado)
		if jornada == COMPLETA:
			break
		var devolucion := Mensaje.new()
		devolucion.identidad = "devolucion_%d" % jornada
		devolucion.jornada = jornada
		devolucion.momento = Mensaje.Momento.CIERRE
		devolucion.texto = devolucion.identidad
		assert_bool(bandeja.recibir(JEFE, devolucion)).is_true()
		devoluciones.append(devolucion)
		esperado.append(devolucion)
	var retomada := Bandeja.new([guion])
	retomada.abrir_jornada(COMPLETA)
	for devolucion in devoluciones:
		retomada.recibir(JEFE, devolucion)
	assert_array(retomada.mensajes_de(JEFE)).is_equal(esperado)


func test_la_primera_jornada_solo_ofrece_la_introduccion_documentada() -> void:  # AC-INV-028
	var bandeja := Bandeja.new(Conversacion.desde_disco())
	bandeja.abrir_jornada(1)
	assert_int(bandeja.conversaciones().size()).is_equal(1)
	var quien := Conversacion.Interlocutor.JEFE
	assert_int(bandeja.conversaciones()[0].interlocutor).is_equal(quien)
	var mensajes := bandeja.mensajes_de(quien)
	assert_array(mensajes).is_equal(
		Conversacion.de(quien).mensajes.filter(func(m: Mensaje) -> bool: return m.jornada == 1)
	)
	assert_array(mensajes).is_not_empty()
	for mensaje in mensajes:
		assert_int(mensaje.jornada).is_equal(1)
		assert_str(mensaje.de_quien).is_equal("Enrique Peldaño")
	assert_int(bandeja.no_leidos_totales()).is_equal(mensajes.size())
	# La reconstrucción desde un guardado no depende de una bandeja previamente filtrada.
	var restaurada := Bandeja.new(Conversacion.desde_disco())
	restaurada.abrir_jornada(1)
	assert_array(restaurada.conversaciones()).is_equal(bandeja.conversaciones())
	assert_int(restaurada.no_leidos_totales()).is_equal(mensajes.size())
	# Los bloques documentados siguen disponibles; no aparecen contactos sin guion.
	restaurada.abrir_jornada(5)
	assert_int(restaurada.conversaciones().size()).is_equal(2)
	assert_array(restaurada.mensajes_de(quien)).is_equal(Conversacion.de(quien).mensajes)


func test_el_corte_de_jornada_filtra_y_ordena_el_menu() -> void:  # AC-INV-028, AC-INV-037
	var primero := _conversacion(Conversacion.Interlocutor.JEFE, 2)
	primero.mensajes[1].jornada = 3
	var segundo := _conversacion(Conversacion.Interlocutor.PROVEEDOR, 1)
	segundo.mensajes[0].jornada = 2
	var bandeja := Bandeja.new([segundo, primero])
	assert_array(bandeja.conversaciones()).is_equal([primero])
	assert_int(bandeja.mensajes_de(primero.interlocutor).size()).is_equal(1)
	bandeja.abrir_jornada(2)
	assert_array(bandeja.conversaciones()).is_equal([primero, segundo])
	assert_int(bandeja.mensajes_de(primero.interlocutor).size()).is_equal(1)
	bandeja.abrir_jornada(3)
	assert_int(bandeja.mensajes_de(primero.interlocutor).size()).is_equal(2)
	assert_int(bandeja.no_leidos(primero.interlocutor)).is_equal(2)


func test_recibir_despues_de_leer_suma_sin_mutar_el_guion() -> void:  # AC-INV-010, AC-INV-029
	var conversacion := _conversacion(Conversacion.Interlocutor.JEFE, 1)
	var bandeja := Bandeja.new([conversacion])
	bandeja.marcar_leida(conversacion.interlocutor)
	var recibido := Mensaje.new()
	recibido.texto = "Llegó después"
	assert_bool(bandeja.recibir(conversacion.interlocutor, recibido)).is_true()
	assert_bool(bandeja.recibir(conversacion.interlocutor, recibido)).is_true()
	assert_int(bandeja.no_leidos(conversacion.interlocutor)).is_equal(2)
	assert_int(conversacion.mensajes.size()).is_equal(1)
	assert_int(Bandeja.new([conversacion]).mensajes_de(conversacion.interlocutor).size()).is_equal(
		1
	)
	bandeja.mensajes_de(conversacion.interlocutor).clear()
	bandeja.conversaciones().clear()
	assert_int(bandeja.mensajes_de(conversacion.interlocutor).size()).is_equal(3)
	assert_bool(bandeja.marcar_leida(conversacion.interlocutor)).is_true()
	assert_int(bandeja.no_leidos(conversacion.interlocutor)).is_zero()


func test_recepciones_invalidas_no_cambian_la_bandeja() -> void:  # AC-INV-030
	var bandeja := Bandeja.new([_conversacion(Conversacion.Interlocutor.JEFE, 1)])
	assert_bool(bandeja.recibir(Conversacion.Interlocutor.JEFE, null)).is_false()
	assert_bool(bandeja.recibir(Conversacion.Interlocutor.PROVEEDOR, Mensaje.new())).is_false()
	assert_int(bandeja.no_leidos_totales()).is_equal(1)


func test_una_foto_final_y_otra_foto_cortan_el_adjunto() -> void:  # AC-INV-031
	var conversacion := _conversacion(Conversacion.Interlocutor.JEFE, 4)
	conversacion.mensajes[0].foto = GradientTexture2D.new()
	conversacion.mensajes[2].foto = GradientTexture2D.new()
	conversacion.mensajes[3].foto = GradientTexture2D.new()
	var bandeja := Bandeja.new([conversacion])
	assert_object(bandeja.adjunto_de(conversacion.interlocutor, 0)).is_same(
		conversacion.mensajes[1]
	)
	for indice: int in [-1, 1, 2, 3, 4]:
		assert_object(bandeja.adjunto_de(conversacion.interlocutor, indice)).is_null()


func test_cada_foto_sin_texto_del_grupo_adjunta_la_misma_intro() -> void:  # AC-INV-031
	var conversacion := _conversacion(JEFE, 4)
	for indice in 3:
		conversacion.mensajes[indice].foto = GradientTexture2D.new()
		conversacion.mensajes[indice].texto = ""
	var bandeja := Bandeja.new([conversacion])
	for indice in 3:
		assert_object(bandeja.adjunto_de(JEFE, indice)).is_same(conversacion.mensajes[3])
	assert_object(bandeja.adjunto_de(JEFE, 3)).is_null()


func test_fotos_huerfanas_no_toman_texto_inexistente() -> void:  # AC-INV-031
	var conversacion := _conversacion(JEFE, 2)
	for mensaje in conversacion.mensajes:
		mensaje.foto = GradientTexture2D.new()
		mensaje.texto = ""
	var bandeja := Bandeja.new([conversacion])
	assert_object(bandeja.adjunto_de(JEFE, 0)).is_null()
	assert_object(bandeja.adjunto_de(JEFE, 1)).is_null()


func test_otra_jornada_u_otro_momento_interrumpen_el_adjunto() -> void:  # AC-INV-031
	for cambio: String in ["jornada", "momento"]:
		for intermedio: bool in [false, true]:
			var conversacion := _conversacion(JEFE, 3 if intermedio else 2)
			var primera := conversacion.mensajes[0]
			primera.texto = ""
			primera.foto = GradientTexture2D.new()
			var corte := conversacion.mensajes[1]
			if cambio == "jornada":
				corte.jornada += 1
			else:
				corte.momento = Mensaje.Momento.CIERRE
			if intermedio:
				corte.texto = ""
				corte.foto = GradientTexture2D.new()
				conversacion.mensajes[2].jornada = corte.jornada
				conversacion.mensajes[2].momento = corte.momento
			var bandeja := Bandeja.new([conversacion])
			bandeja.abrir_jornada(2)
			assert_object(bandeja.adjunto_de(JEFE, 0)).is_null()


func test_una_foto_con_texto_intermedia_impide_buscar_mas_adelante() -> void:  # AC-INV-031
	var conversacion := _conversacion(JEFE, 4)
	for indice in 3:
		conversacion.mensajes[indice].foto = GradientTexture2D.new()
	conversacion.mensajes[0].texto = ""
	conversacion.mensajes[1].texto = ""
	var bandeja := Bandeja.new([conversacion])
	assert_object(bandeja.adjunto_de(JEFE, 0)).is_null()
	assert_object(bandeja.adjunto_de(JEFE, 1)).is_null()
	assert_object(bandeja.adjunto_de(JEFE, 2)).is_same(conversacion.mensajes[3])


func _conversacion(quien: Conversacion.Interlocutor, cuantos: int) -> Conversacion:
	var conversacion := Conversacion.new()
	conversacion.interlocutor = quien
	conversacion.nombre = "Interlocutor %d" % quien
	var mensajes: Array[Mensaje] = []
	for indice in range(cuantos):
		var mensaje := Mensaje.new()
		mensaje.de_quien = conversacion.nombre
		mensaje.texto = "mensaje %d" % indice
		mensajes.append(mensaje)
	conversacion.mensajes = mensajes
	return conversacion


## Una bandeja de prueba con las tres conversaciones y un número distinto de mensajes en cada
## una, para que confundir dos se note en el número y no sólo en la etiqueta.
func _bandeja() -> Bandeja:
	return (
		Bandeja
		. new(
			[
				_conversacion(Conversacion.Interlocutor.JEFE, 2),
				_conversacion(Conversacion.Interlocutor.PROVEEDOR, 3),
				_conversacion(Conversacion.Interlocutor.DESCONOCIDO, 4),
			]
		)
	)


func test_una_bandeja_nueva_tiene_todo_sin_leer() -> void:
	var bandeja := _bandeja()
	assert_int(bandeja.no_leidos(Conversacion.Interlocutor.JEFE)).is_equal(2)
	assert_int(bandeja.no_leidos_totales()).is_equal(9)


func test_marcar_leida_deja_esa_conversacion_en_cero() -> void:  # AC-INV-010
	var bandeja := _bandeja()
	assert_bool(bandeja.marcar_leida(Conversacion.Interlocutor.JEFE)).is_true()
	assert_int(bandeja.no_leidos(Conversacion.Interlocutor.JEFE)).is_equal(0)
	assert_bool(bandeja.esta_leida(Conversacion.Interlocutor.JEFE)).is_true()


func test_marcar_leida_no_toca_las_otras_dos() -> void:  # AC-INV-010
	# Es la mitad que un contador único de «no leídos» daría por buena: con uno solo, leer al
	# jefe apagaría el aviso de los otros dos y el jugador no volvería a mirarlos.
	var bandeja := _bandeja()
	bandeja.marcar_leida(Conversacion.Interlocutor.JEFE)
	assert_int(bandeja.no_leidos(Conversacion.Interlocutor.PROVEEDOR)).is_equal(3)
	assert_int(bandeja.no_leidos(Conversacion.Interlocutor.DESCONOCIDO)).is_equal(4)
	assert_int(bandeja.no_leidos_totales()).is_equal(7)


func test_marcar_leida_dos_veces_devuelve_false_la_segunda() -> void:
	var bandeja := _bandeja()
	assert_bool(bandeja.marcar_leida(Conversacion.Interlocutor.JEFE)).is_true()
	assert_bool(bandeja.marcar_leida(Conversacion.Interlocutor.JEFE)).is_false()


func test_marcar_un_interlocutor_que_no_esta_en_la_bandeja_devuelve_false() -> void:
	var bandeja := Bandeja.new([_conversacion(Conversacion.Interlocutor.JEFE, 1)])
	assert_bool(bandeja.marcar_leida(Conversacion.Interlocutor.PROVEEDOR)).is_false()
	assert_int(bandeja.no_leidos(Conversacion.Interlocutor.PROVEEDOR)).is_equal(0)


func test_la_conversacion_se_pide_por_interlocutor_y_la_que_falta_es_null() -> void:
	var bandeja := _bandeja()
	var del_jefe := bandeja.conversacion_de(Conversacion.Interlocutor.JEFE)
	assert_object(del_jefe).is_not_null()
	assert_int(del_jefe.interlocutor).is_equal(Conversacion.Interlocutor.JEFE)
	var vacia := Bandeja.new([])
	assert_object(vacia.conversacion_de(Conversacion.Interlocutor.JEFE)).is_null()


# AC-INV-012
func test_la_bandeja_no_se_arma_con_las_conversaciones_del_disco_en_cada_llamada() -> void:
	# Es la forma ejercible de «lo leído sobrevive a cerrar y reabrir»: la bandeja es una sola
	# instancia y las lecturas se le quedan adentro. Si la pantalla la reconstruyera al mostrar
	# los chats, cambiar de app las tiraría — sin un solo error.
	var bandeja := _bandeja()
	bandeja.marcar_leida(Conversacion.Interlocutor.DESCONOCIDO)
	var leidos_antes := bandeja.no_leidos_totales()
	# Recorrer y volver a pedir la lista no cambia nada: la bandeja no se reconstruye sola.
	assert_int(bandeja.conversaciones().size()).is_equal(3)
	assert_int(bandeja.no_leidos_totales()).is_equal(leidos_antes)
	assert_bool(bandeja.esta_leida(Conversacion.Interlocutor.DESCONOCIDO)).is_true()


func test_notas_recibidas_antes_de_la_sexta_no_dan_boton() -> void:  # AC-INV-028, AC-INV-052
	var normal := Conversacion.new()
	normal.interlocutor = Conversacion.Interlocutor.JEFE
	var notas := Conversacion.de(Conversacion.Interlocutor.NOTAS)
	assert_object(notas).is_not_null()
	if notas == null:
		return
	var bandeja := Bandeja.new([normal, notas])
	var mensaje := Mensaje.new()
	mensaje.identidad = "normal_J2"
	mensaje.jornada = 2
	mensaje.texto = "Mensaje normal"
	var nota := Mensaje.new()
	nota.identidad = "nota_J2"
	nota.jornada = 2
	nota.texto = "Mensaje de notas"
	bandeja.recibir(Conversacion.Interlocutor.JEFE, mensaje)
	bandeja.recibir(Conversacion.Interlocutor.NOTAS, nota)
	bandeja.abrir_jornada(1)
	assert_array(bandeja.conversaciones()).is_empty()
	assert_array(bandeja.mensajes_de(Conversacion.Interlocutor.NOTAS)).is_empty()
	bandeja.abrir_jornada(2)
	assert_array(bandeja.conversaciones()).is_equal([normal])
	assert_array(bandeja.mensajes_de(Conversacion.Interlocutor.NOTAS)).is_equal([nota])
	bandeja.abrir_jornada(notas.jornada_de_menu)
	assert_array(bandeja.conversaciones()).is_equal([normal, notas])
	assert_array(notas.mensajes).is_empty()
	assert_array(bandeja.mensajes_de(Conversacion.Interlocutor.NOTAS)).is_equal([nota])


func test_recibido_futuro_no_aparece_antes_de_su_jornada() -> void:  # AC-INV-028
	var normal := Conversacion.new()
	normal.interlocutor = Conversacion.Interlocutor.JEFE
	var bandeja := Bandeja.new([normal])
	var futuro := Mensaje.new()
	futuro.identidad = "futuro_J4"
	futuro.jornada = 4
	futuro.texto = "Mensaje de jornada cuatro"
	bandeja.abrir_jornada(2)
	assert_bool(bandeja.recibir(Conversacion.Interlocutor.JEFE, futuro)).is_true()
	assert_array(bandeja.mensajes_de(Conversacion.Interlocutor.JEFE)).is_empty()
	assert_array(bandeja.conversaciones()).is_empty()
	assert_int(bandeja.no_leidos_totales()).is_zero()
	bandeja.abrir_jornada(4)
	assert_array(bandeja.mensajes_de(Conversacion.Interlocutor.JEFE)).is_equal([futuro])
	assert_array(bandeja.conversaciones()).is_equal([normal])
	assert_int(bandeja.no_leidos_totales()).is_equal(1)
