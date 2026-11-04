## Las horas de cada mensaje del guion salen de las fichas de Notion, y los introductorios del
## jefe, a los que la ficha no les pone hora, de la decisión del 2026-10-26.
extends GdUnitTestSuite


func _guion() -> Dictionary[String, Mensaje]:
	var por_identidad: Dictionary[String, Mensaje] = {}
	for quien: Conversacion.Interlocutor in [
		Conversacion.Interlocutor.JEFE, Conversacion.Interlocutor.YASMIN
	]:
		for mensaje: Mensaje in Conversacion.de(quien).mensajes:
			por_identidad[mensaje.identidad] = mensaje
	return por_identidad


func _horas(guion: Dictionary[String, Mensaje], identidades: Array[String]) -> Array[String]:
	var horas: Array[String] = []
	for identidad: String in identidades:
		assert_bool(guion.has(identidad)).is_true()
		horas.append(guion[identidad].hora if guion.has(identidad) else "?")
	return horas


func _repetida(hora: String, cantidad: int) -> Array[String]:
	var horas: Array[String] = []
	horas.resize(cantidad)
	horas.fill(hora)
	return horas


func _ids(prefijo: String, desde: int, hasta: int) -> Array[String]:
	var identidades: Array[String] = []
	for numero: int in range(desde, hasta + 1):
		identidades.append("%s%d" % [prefijo, numero])
	return identidades


func test_yasmin_lleva_la_hora_de_su_ficha() -> void:  # AC-INV-103
	var guion := _guion()
	var tabla := {
		"17:34": _ids("J2_", 1, 4),
		"17:35": _ids("J2_", 5, 7),
		"17:36": _ids("J2_", 8, 9),
		"17:37": _ids("J2_", 10, 12),
		"17:38": _ids("J2_", 13, 15),
		"09:11": _ids("J3_", 1, 4),
		"09:12": _ids("J3_", 5, 7),
		"09:13": _ids("J3_", 8, 10),
	}
	for hora: String in tabla:
		var identidades: Array[String] = tabla[hora]
		assert_array(_horas(guion, identidades)).is_equal(_repetida(hora, identidades.size()))


func test_los_introductorios_del_jefe_quedan_antes_de_las_20() -> void:  # AC-INV-104
	var guion := _guion()
	var tabla := {
		"19:40": ["J1_Intro01"],
		"19:41": ["J1_FotoReloj", "J1_Foto02", "J1_Intro02", "J2_FotoGondolas", "J1_Foto07"],
		"19:42": ["J1_Foto03", "J1_Intro03", "J1_Intro07", "J1_Intro08"],
		"19:43": ["J1_Foto04", "J1_Intro04", "J1_Intro05", "J1_Foto09", "J1_Intro09"],
		"19:44": ["J1_Foto06", "J1_Intro06"],
	}
	for hora: String in tabla:
		var identidades: Array[String] = []
		identidades.assign(tabla[hora])
		assert_array(_horas(guion, identidades)).is_equal(_repetida(hora, identidades.size()))
	var por_jornada := {2: "19:40", 3: "19:40"}
	for identidad: String in guion:
		var mensaje := guion[identidad]
		if identidad.contains("_Mensaje1_"):
			assert_str(mensaje.hora).is_equal(por_jornada[mensaje.jornada])
	var segunda_parte: Array[String] = ["J1_Intro10", "J1_Foto11"]
	assert_array(_horas(guion, segunda_parte)).is_equal(["19:41", "19:41"])
	var tercera_parte: Array[String] = ["J1_Intro11", "J1_Intro12"]
	assert_array(_horas(guion, tercera_parte)).is_equal(["19:42", "19:42"])


func test_ningun_mensaje_recibido_cae_durante_la_jornada() -> void:  # AC-INV-103, AC-INV-104
	var guion := _guion()
	for identidad: String in guion:
		var partes := guion[identidad].hora.split(":")
		assert_int(partes.size()).is_equal(2)
		var hora := partes[0].to_int()
		assert_bool(hora >= 8 and hora < 20).is_true()


func test_la_apertura_de_la_cuarta_jornada_lleva_la_hora_de_la_ficha() -> void:  # AC-INV-105
	var guion := _guion()
	var apertura: Array[String] = ["J2_CONTENEDOR_FOTO", "J2_CONTENEDOR_TEXTO"]
	assert_array(_horas(guion, apertura)).is_equal(["19:31", "19:31"])


func test_la_devolucion_suma_un_minuto_por_mensaje() -> void:  # AC-INV-105
	var primeras := {3: "8:26", 4: "8:38", 5: "9:05", 6: "8:42", 7: "9:11"}
	for jornada: int in primeras:
		assert_str(DevolucionDelJefe.mensaje("Saludo", jornada, 0).hora).is_equal(primeras[jornada])
	assert_str(DevolucionDelJefe.mensaje("Tarea", 3, 1).hora).is_equal("8:27")
	assert_str(DevolucionDelJefe.mensaje("Cierre", 3, 2).hora).is_equal("8:28")
	assert_str(DevolucionDelJefe.mensaje("Cierre", 5, 55).hora).is_equal("10:00")
	assert_str(DevolucionDelJefe.mensaje("Legado").hora).is_empty()
