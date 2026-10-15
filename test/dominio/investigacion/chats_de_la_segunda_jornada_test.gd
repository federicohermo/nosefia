extends GdUnitTestSuite

const JEFE := Conversacion.Interlocutor.JEFE
const TEXTOS: Array[String] = [
	"holuuu ✨",
	"que onda compa?",
	"soy Yas del turno diurno",
	"la otra esclavita de enrique jsjsj",
	"el chabon es bastante denso pero ya te vas a acostumbrar",
	"y te aviso q acá siempre falta algo o anda todo a medias",
	"para que te vayas acostumbrando también",
	"p ejemplo hoy parece que se acabo uno de los jabones para la limpieza y no había ningún repuesto",
	"no le reclames a enrique porque no va a hacer nada y encima se va a irritar",
	"creo que lo podes reemplazar con chorrito del producto ese de limpieza que vendemos",
	"no creo que enrique se de cuenta si usás uno",
	"pero nada",
	"quería darte la bienvenida",
	"quedamos en contacto p cualquier cosa",
	"exitos con eso!  💪",
]
const APERTURA := (
	"Buen día, pibe. Hoy te pido que tires la basura de todos los tachos del local "
	+ "en el contenedor. Saludos"
)


func test_solo_enrique_en_uno_y_dos_contactos_desde_dos() -> void:  # AC-INV-039
	var bandeja := Bandeja.new(Conversacion.desde_disco())
	bandeja.abrir_jornada(1)
	assert_int(bandeja.conversaciones().size()).is_equal(1)
	bandeja.abrir_jornada(2)
	assert_int(bandeja.conversaciones().size()).is_equal(2)
	if bandeja.conversaciones().size() != 2:
		return
	var yasmin := bandeja.conversaciones()[1]
	assert_str(yasmin.nombre).is_equal("Yasmín")
	var mensajes := bandeja.mensajes_de(yasmin.interlocutor)
	assert_int(mensajes.size()).is_equal(TEXTOS.size())
	for indice: int in mensajes.size():
		assert_str(mensajes[indice].texto).is_equal(TEXTOS[indice])
		assert_that(mensajes[indice].get("identidad")).is_equal("J2_%d" % (indice + 1))
		assert_int(mensajes[indice].jornada).is_equal(2)
	assert_that(yasmin.get("rol")).is_equal("Compañera de trabajo")
	var del_jefe := bandeja.no_leidos(JEFE)
	bandeja.marcar_leida(yasmin.interlocutor)
	assert_int(bandeja.no_leidos(yasmin.interlocutor)).is_zero()
	assert_int(bandeja.no_leidos(JEFE)).is_equal(del_jefe)
	assert_int(Bandeja.new(Conversacion.desde_disco()).no_leidos(JEFE)).is_equal(19)


func test_la_apertura_dos_contiene_foto_y_texto_siguiente() -> void:  # AC-INV-042
	var bandeja := Bandeja.new(Conversacion.desde_disco())
	bandeja.abrir_jornada(2)
	var mensajes := bandeja.mensajes_de(JEFE)
	assert_int(mensajes.size()).is_equal(21)
	if mensajes.size() != 21:
		return
	assert_object(mensajes[19].foto).is_not_null()
	assert_str(mensajes[20].texto).is_equal(APERTURA)
	assert_object(bandeja.adjunto_de(JEFE, 19)).is_same(mensajes[20])


func test_repetir_apertura_no_duplica_guion() -> void:  # AC-INV-040
	var bandeja := Bandeja.new(Conversacion.desde_disco())
	bandeja.abrir_jornada(2)
	var antes := bandeja.mensajes_de(JEFE)
	bandeja.abrir_jornada(2)
	assert_array(bandeja.mensajes_de(JEFE)).is_equal(antes)
	assert_int(bandeja.conversaciones().size()).is_equal(2)


func test_recibido_de_una_jornada_queda_antes_de_apertura_siguiente() -> void:  # AC-INV-040
	var uno := Mensaje.new()
	uno.texto = "Apertura uno"
	uno.jornada = 1
	var dos := Mensaje.new()
	dos.texto = "Apertura dos"
	dos.jornada = 2
	var cierre := Mensaje.new()
	cierre.texto = "Cierre uno"
	cierre.jornada = 1
	var conversacion := Conversacion.new()
	conversacion.mensajes = [uno, dos]
	var bandeja := Bandeja.new([conversacion])
	bandeja.abrir_jornada(2)
	assert_bool(bandeja.recibir(JEFE, cierre)).is_true()
	assert_array(bandeja.mensajes_de(JEFE)).is_equal([uno, cierre, dos])
	assert_array(conversacion.mensajes).is_equal([uno, dos])
