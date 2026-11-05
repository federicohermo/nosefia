## El chat de Hernán aparece en la jornada del pedido, sin historial. Enrique abre esa noche con
## la foto de las estanterías y el aviso del pedido (BR-INV-123, BR-INV-126).
extends GdUnitTestSuite

const JEFE := Conversacion.Interlocutor.JEFE
const PROVEEDOR := Conversacion.Interlocutor.PROVEEDOR
const PEDIDO := ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA + 3

const ANTES: Array[int] = [1, 2, 3, 4, 5]


func _bandeja(jornada: int) -> Bandeja:
	var bandeja := Bandeja.new(Conversacion.desde_disco())
	bandeja.abrir_jornada(jornada)
	return bandeja


func _identidades(mensajes: Array[Mensaje]) -> Array[String]:
	var identidades: Array[String] = []
	for mensaje in mensajes:
		identidades.append(mensaje.identidad)
	return identidades


func test_hernan_no_esta_antes_de_la_jornada_del_pedido() -> void:  # AC-INV-169
	for jornada: int in ANTES:
		var conversaciones := _bandeja(jornada).conversaciones()
		for conversacion in conversaciones:
			(
				assert_bool(conversacion.interlocutor == PROVEEDOR)
				. override_failure_message("jornada %d" % jornada)
				. is_false()
			)


func test_hernan_esta_en_la_jornada_del_pedido_tras_enrique_sin_mensajes() -> void:  # AC-INV-169
	var bandeja := _bandeja(PEDIDO)
	var quienes: Array[Conversacion.Interlocutor] = []
	for conversacion in bandeja.conversaciones():
		quienes.append(conversacion.interlocutor)
	assert_bool(quienes.has(PROVEEDOR)).is_true()
	assert_int(quienes.find(PROVEEDOR)).is_equal(quienes.find(JEFE) + 1)
	assert_array(bandeja.mensajes_de(PROVEEDOR)).is_empty()
	assert_int(bandeja.no_leidos(PROVEEDOR)).is_zero()
	var hernan := bandeja.conversacion_de(PROVEEDOR)
	assert_str(hernan.nombre).is_not_empty()
	assert_object(hernan.imagen).is_not_null()


func test_abrir_el_chat_de_hernan_vacio_es_posible() -> void:  # AC-INV-169
	var celular := Celular.new(_bandeja(PEDIDO))
	celular.habilitar(true)
	assert_bool(celular.alternar(false)).is_true()
	assert_bool(celular.abrir_chat(PROVEEDOR)).is_true()
	assert_int(celular.chat()).is_equal(PROVEEDOR)


func test_enrique_abre_la_jornada_del_pedido_con_la_foto_y_el_aviso() -> void:  # AC-INV-174
	var del_pedido: Array[Mensaje] = []
	for mensaje in _bandeja(PEDIDO).mensajes_de(JEFE):
		if mensaje.jornada == PEDIDO:
			del_pedido.append(mensaje)
	assert_int(del_pedido.size()).is_equal(2)
	assert_object(del_pedido[0].foto).is_not_null()
	assert_str(del_pedido[0].texto).is_empty()
	assert_str(del_pedido[1].texto).is_not_empty()
	assert_object(del_pedido[1].foto).is_null()
	assert_str(del_pedido[0].hora).is_equal(del_pedido[1].hora)
	var bandeja := _bandeja(PEDIDO)
	var indice := bandeja.mensajes_de(JEFE).find(del_pedido[0])
	assert_object(bandeja.adjunto_de(JEFE, indice)).is_same(del_pedido[1])
	assert_int(_identidades(bandeja.mensajes_de(JEFE)).count(del_pedido[0].identidad)).is_equal(1)
	assert_int(_identidades(bandeja.mensajes_de(JEFE)).count(del_pedido[1].identidad)).is_equal(1)


func test_antes_de_la_jornada_del_pedido_enrique_no_los_trae() -> void:  # AC-INV-174
	var guion := Conversacion.de(JEFE)
	var del_pedido: Array[String] = []
	for mensaje in guion.mensajes:
		if (
			mensaje.jornada == PEDIDO
			and (mensaje.foto != null or mensaje.texto.contains("proveedor"))
		):
			del_pedido.append(mensaje.identidad)
	assert_int(del_pedido.size()).is_equal(2)
	for jornada: int in ANTES:
		var identidades := _identidades(_bandeja(jornada).mensajes_de(JEFE))
		for identidad in del_pedido:
			(
				assert_bool(identidades.has(identidad))
				. override_failure_message("jornada %d" % jornada)
				. is_false()
			)
