## Las conversaciones que el jugador lee en los chats: que estén las tres y que no guarden estado.
##
## **El caso del disco es el que más fácil miente.** Un `.tres` que falta hace abortar la función
## antes de afirmar, y gdUnit4 reporta el caso en verde: por eso acá se afirma primero que el
## recurso **no es nulo**, con su mensaje propio, y recién después lo que dice adentro.
extends GdUnitTestSuite

const CONVERSACION := "res://src/dominio/investigacion/conversacion.gd"


func test_hay_una_conversacion_por_cada_interlocutor() -> void:  # 009-AC5
	# Se cuenta contra el `enum` y nunca contra un número escrito acá: un interlocutor sin su
	# `.tres` sería una pestaña que el jugador abre y encuentra vacía, sin un solo error.
	var todas := Conversacion.desde_disco()
	(
		assert_int(todas.size())
		. override_failure_message(
			(
				"hay %d conversaciones en disco y el enum declara %d interlocutores"
				% [todas.size(), Conversacion.Interlocutor.size()]
			)
		)
		. is_equal(Conversacion.Interlocutor.size())
	)


func test_cada_interlocutor_tiene_la_suya_y_no_la_de_otro() -> void:  # 009-AC5
	for quien: Conversacion.Interlocutor in Conversacion.Interlocutor.values():
		var conversacion := Conversacion.de(quien)
		(
			assert_object(conversacion)
			. override_failure_message("falta el `.tres` del interlocutor %d" % quien)
			. is_not_null()
		)
		assert_int(conversacion.interlocutor).is_equal(quien)


func test_ninguna_conversacion_llega_vacia() -> void:  # 009-AC5
	# Al menos un mensaje con texto: una conversación vacía es contenido que el jugador paga en
	# minutos de turno y no le devuelve nada.
	for conversacion in Conversacion.desde_disco():
		assert_object(conversacion).is_not_null()
		(
			assert_int(conversacion.mensajes.size())
			. override_failure_message("`%s` no trae mensajes" % conversacion.nombre)
			. is_greater(0)
		)
		var con_texto := 0
		for mensaje in conversacion.mensajes:
			if mensaje != null and mensaje.dice_algo():
				con_texto += 1
		(
			assert_int(con_texto)
			. override_failure_message("`%s` trae mensajes vacíos" % conversacion.nombre)
			. is_greater(0)
		)


func test_cada_interlocutor_se_presenta_con_un_nombre() -> void:  # 009-AC5
	for conversacion in Conversacion.desde_disco():
		assert_object(conversacion).is_not_null()
		assert_str(conversacion.nombre).is_not_empty()


func test_lo_leido_no_vuelve_al_disco() -> void:  # 009-AC5
	# El `.tres` es el guión y es inmutable: la marca de leído vive en la `Bandeja`, que nunca se
	# guarda. Está medido que dos `load()` del mismo `.tres` devuelven **la misma instancia**, así
	# que un `leido` adentro del recurso dejaría al test siguiente empezando leído — y a la
	# partida siguiente también.
	var texto := FileAccess.get_file_as_string(CONVERSACION)
	assert_str(texto).is_not_empty()
	for patron in ["leido", "ResourceSaver"]:
		(
			assert_bool(texto.contains(patron))
			. override_failure_message("`conversacion.gd` nombra `%s`" % patron)
			. is_false()
		)


func test_un_interlocutor_sin_fila_contesta_null_en_vez_de_reventar() -> void:  # 009-AC5
	# Es la misma forma que `Catalogo.de()`: con un valor nuevo en el enum y sin su archivo, el
	# rojo lo produce una aserción y no un error del motor —que gdUnit4 cuenta como *error* y
	# deja el archivo diciendo `PASSED`—.
	assert_object(Conversacion.de(Conversacion.Interlocutor.size() as int)).is_null()
