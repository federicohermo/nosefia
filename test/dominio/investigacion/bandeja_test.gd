## La bandeja de chats: qué está sin leer y qué ya se leyó.
##
## **Lo leído vive acá y no en el `.tres`**, que es la decisión que este spec compró: está medido
## que dos `load()` del mismo recurso devuelven la misma instancia, así que marcar un chat en el
## recurso dejaría al test siguiente —y a la partida siguiente— empezando leído.
extends GdUnitTestSuite


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


func test_una_bandeja_nueva_tiene_todo_sin_leer() -> void:  # 009-AC4
	var bandeja := _bandeja()
	assert_int(bandeja.no_leidos(Conversacion.Interlocutor.JEFE)).is_equal(2)
	assert_int(bandeja.no_leidos_totales()).is_equal(9)


func test_marcar_leida_deja_esa_conversacion_en_cero() -> void:  # 009-AC4
	var bandeja := _bandeja()
	assert_bool(bandeja.marcar_leida(Conversacion.Interlocutor.JEFE)).is_true()
	assert_int(bandeja.no_leidos(Conversacion.Interlocutor.JEFE)).is_equal(0)
	assert_bool(bandeja.esta_leida(Conversacion.Interlocutor.JEFE)).is_true()


func test_marcar_leida_no_toca_las_otras_dos() -> void:  # 009-AC4
	# Es la mitad que un contador único de «no leídos» daría por buena: con uno solo, leer al
	# jefe apagaría el aviso de los otros dos y el jugador no volvería a mirarlos.
	var bandeja := _bandeja()
	bandeja.marcar_leida(Conversacion.Interlocutor.JEFE)
	assert_int(bandeja.no_leidos(Conversacion.Interlocutor.PROVEEDOR)).is_equal(3)
	assert_int(bandeja.no_leidos(Conversacion.Interlocutor.DESCONOCIDO)).is_equal(4)
	assert_int(bandeja.no_leidos_totales()).is_equal(7)


func test_marcar_leida_dos_veces_devuelve_false_la_segunda() -> void:  # 009-AC4
	var bandeja := _bandeja()
	assert_bool(bandeja.marcar_leida(Conversacion.Interlocutor.JEFE)).is_true()
	assert_bool(bandeja.marcar_leida(Conversacion.Interlocutor.JEFE)).is_false()


func test_marcar_un_interlocutor_que_no_esta_en_la_bandeja_devuelve_false() -> void:  # 009-AC4
	var bandeja := Bandeja.new([_conversacion(Conversacion.Interlocutor.JEFE, 1)])
	assert_bool(bandeja.marcar_leida(Conversacion.Interlocutor.PROVEEDOR)).is_false()
	assert_int(bandeja.no_leidos(Conversacion.Interlocutor.PROVEEDOR)).is_equal(0)


func test_la_conversacion_se_pide_por_interlocutor_y_la_que_falta_es_null() -> void:  # 009-AC4
	var bandeja := _bandeja()
	var del_jefe := bandeja.conversacion_de(Conversacion.Interlocutor.JEFE)
	assert_object(del_jefe).is_not_null()
	assert_int(del_jefe.interlocutor).is_equal(Conversacion.Interlocutor.JEFE)
	var vacia := Bandeja.new([])
	assert_object(vacia.conversacion_de(Conversacion.Interlocutor.JEFE)).is_null()


func test_la_bandeja_no_se_arma_con_las_conversaciones_del_disco_en_cada_llamada() -> void:
	# 009-AC4
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
