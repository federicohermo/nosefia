## Sólo se cargan conversaciones con guion documentado, sin estado de lectura compartido.
##
## **El caso del disco es el que más fácil miente.** Un `.tres` que falta hace abortar la función
## antes de afirmar, y gdUnit4 reporta el caso en verde: por eso acá se afirma primero que el
## recurso **no es nulo**, con su mensaje propio, y recién después lo que dice adentro.
extends GdUnitTestSuite

const CONVERSACION := "res://src/dominio/investigacion/conversacion.gd"


func test_el_catalogo_carga_las_conversaciones_documentadas() -> void:
	var todas := Conversacion.desde_disco()
	assert_int(todas.size()).is_equal(2)
	assert_int(todas[0].interlocutor).is_equal(Conversacion.Interlocutor.JEFE)
	assert_str(todas[0].nombre).is_equal("Enrique Peldaño")


func test_cada_conversacion_documentada_es_de_su_interlocutor() -> void:
	for quien: Conversacion.Interlocutor in Conversacion.ARCHIVOS:
		var conversacion := Conversacion.de(quien)
		(
			assert_object(conversacion)
			. override_failure_message("falta el `.tres` del interlocutor %d" % quien)
			. is_not_null()
		)
		assert_int(conversacion.interlocutor).is_equal(quien)


func test_un_interlocutor_sin_guion_documentado_no_carga_textos_inventados() -> void:
	assert_object(Conversacion.de(Conversacion.Interlocutor.PROVEEDOR)).is_null()
	assert_object(Conversacion.de(Conversacion.Interlocutor.DESCONOCIDO)).is_null()


func test_ninguna_conversacion_llega_vacia() -> void:
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


func test_cada_interlocutor_se_presenta_con_un_nombre() -> void:
	for conversacion in Conversacion.desde_disco():
		assert_object(conversacion).is_not_null()
		assert_str(conversacion.nombre).is_not_empty()


func test_lo_leido_no_vuelve_al_disco() -> void:  # AC-INV-009
	# El `.tres` es el guión y es inmutable: la marca de leído vive en la `Bandeja`, que nunca se
	# guarda. Está medido que dos `load()` del mismo `.tres` devuelven **la misma instancia**, así
	# que un `leido` adentro del recurso dejaría al test siguiente empezando leído — y a la
	# partida siguiente también.
	var texto := FileAccess.get_file_as_string(CONVERSACION)
	assert_str(texto).is_not_empty()
	for patron: String in ["leido", "ResourceSaver"]:
		(
			assert_bool(texto.contains(patron))
			. override_failure_message("`conversacion.gd` nombra `%s`" % patron)
			. is_false()
		)


func test_un_interlocutor_sin_fila_contesta_null_en_vez_de_reventar() -> void:
	# Es la misma forma que `Catalogo.de()`: con un valor nuevo en el enum y sin su archivo, el
	# rojo lo produce una aserción y no un error del motor —que gdUnit4 cuenta como *error* y
	# deja el archivo diciendo `PASSED`—.
	assert_object(Conversacion.de(Conversacion.Interlocutor.size() as int)).is_null()
