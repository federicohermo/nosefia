extends GdUnitTestSuite

const GUION := "res://src/dominio/investigacion/conversacion_con_el_jefe.tres"
const TEXTOS: Array[String] = [
	(
		"¿Cómo andás, pibe? Llegó el momento de lucirte. Tu período de prueba va "
		+ "a ser de solo cinco jornadas. ¿Quién pudiera, no?"
	),
	(
		"De todos modos, acordate de que el primer mes no es pago, porque lo "
		+ "tomamos como capacitación."
	),
	(
		"Bueno, como ya comenté, la jornada arranca a las 8 PM, cuando se va "
		+ "Yasmín, y termina a las 8 AM. Debería sobrarte el tiempo para cumplir "
		+ "con las tareas que te voy a dejar."
	),
	(
		"Cualquier cosa, siempre van a quedar anotadas en el corcho, atrás del "
		+ "mostrador. Te las resumo:"
	),
	(
		"Primero, y lo más importante: [b]atender a los clientes[/b]. Mi estación "
		+ "de servicio es el único local del pueblo que queda abierto las 24 horas, "
		+ "así que los compradores nocturnos dependen de nosotros. Atenderlos mal "
		+ "es faltarle el respeto a nuestros vecinos, así que ojito."
	),
	(
		"A esa hora, la entrada principal queda cerrada, así que se van a asomar "
		+ "por la ventanilla. Atendé los pedidos y no te olvides de darles un "
		+ "ticket de recibo. Conozco a varios que hasta son capaces de dejar los "
		+ "productos e irse si no se los das. Eso NO puede pasar."
	),
	(
		"Para generar un ticket, tenés que pasar todos los productos por el "
		+ "lector del mostrador y darle al botón “imprimir” en el programa de la "
		+ "caja registradora. Nada muy complejo."
	),
	(
		"En segundo lugar, [b]anotar los productos vendidos [/b]durante la noche "
		+ "en la computadora. Bastante simple."
	),
	(
		"Tercero, hacer la [b]reposición de productos[/b]. Revisá bien todas las "
		+ "góndolas y reponé los ítems que falten con los de las cajas del "
		+ "depósito. No quiero ver ni un solo hueco vacío."
	),
	(
		"Un único producto ausente en la mañana puede hacer la diferencia entre "
		+ "un local de excelencia y uno mediocre. No podemos dar la impresión de "
		+ "que estamos cortos de stock."
	),
	(
		"Cuarto, pero no menor, [b]limpiar[/b]. Vas a encontrar los productos de "
		+ "limpieza en el baño, además de algunas notitas explicando cómo usarlos. "
		+ "No deberías tener problemas con eso."
	),
	(
		"Además de los quehaceres rutinarios, siempre queda alguna cosita por "
		+ "hacer. Por eso, no te sorprendas si ves una quinta tarea diferente cada "
		+ "noche. Tranqui, que te voy a dejar instrucciones por este medio."
	),
	(
		"Para esta noche, te pido que [b]organices las cajas[/b] que dejó el "
		+ "proveedor en el depósito. Acomodalas en los estantes y que no quede ni "
		+ "una en el piso, entendido? Te voy a tener cortito con esos detalles. "
		+ "Para trabajar en una estación de servicio tan prestigiosa como esta, "
		+ "tenés que estar al nivel."
	),
	(
		"Me parece que con eso estaríamos. No te olvides de dejar el local "
		+ "correctamente ordenado antes de irte. Estamos?"
	),
]


func test_uno_doce_volver_y_ok_son_pantallas() -> void:  # AC-EMP-045
	var instrucciones := InstruccionesDelJefe.new(12)
	assert_int(instrucciones.paso_actual()).is_equal(1)
	assert_bool(instrucciones.se_puede_volver()).is_false()
	assert_bool(instrucciones.volver()).is_false()
	for paso in 11:
		instrucciones.avanzar()
	assert_int(instrucciones.paso_actual()).is_equal(12)
	assert_bool(instrucciones.en_el_ultimo()).is_true()
	assert_bool(instrucciones.terminadas()).is_false()
	assert_bool(instrucciones.volver()).is_true()
	assert_int(instrucciones.paso_actual()).is_equal(11)
	assert_bool(instrucciones.en_el_ultimo()).is_false()
	instrucciones.avanzar()
	instrucciones.avanzar()
	assert_bool(instrucciones.terminadas()).is_true()
	instrucciones.avanzar()
	assert_int(instrucciones.paso_actual()).is_equal(12)
	assert_bool(instrucciones.volver()).is_false()
	var otras := InstruccionesDelJefe.new(12)
	for paso in 3:
		otras.avanzar()
	for paso in 3:
		assert_bool(otras.volver()).is_true()
	assert_int(otras.paso_actual()).is_equal(1)
	assert_bool(otras.volver()).is_false()


func test_un_paso_termina_al_primer_avance() -> void:  # AC-EMP-045
	var instrucciones := InstruccionesDelJefe.new(1)
	assert_int(instrucciones.paso_actual()).is_equal(1)
	assert_bool(instrucciones.en_el_ultimo()).is_true()
	assert_bool(instrucciones.volver()).is_false()
	instrucciones.avanzar()
	assert_bool(instrucciones.terminadas()).is_true()
	instrucciones.avanzar()
	assert_int(instrucciones.paso_actual()).is_equal(1)


func test_guion_y_siete_fotos_en_doce_pantallas() -> void:  # AC-EMP-046, AC-EMP-047
	var guion: Conversacion = load(GUION)
	var originales: Array[Mensaje] = guion.mensajes.duplicate()
	var pasos := InstruccionesDelJefe.pasos_de(guion.mensajes)
	assert_int(guion.mensajes.size()).is_equal(21)
	assert_int(pasos.size()).is_equal(12)
	assert_str(guion.nombre).is_equal("Enrique Peldaño")
	assert_object(guion.imagen).is_not_null()
	var fotos: Array[int] = [4, 6, 7, 8, 9, 11, 13]
	var bandeja := Bandeja.new([guion])
	var texto_actual := 0
	var entrada := 0
	for indice in pasos.size():
		var paso: InstruccionesDelJefe.Paso = pasos[indice]
		assert_int(paso.textos.size()).is_equal(2 if indice < 2 else 1)
		for texto in paso.textos:
			if fotos.has(texto_actual + 1):
				assert_object(paso.foto).is_same(guion.mensajes[entrada])
				assert_object(paso.foto.foto).is_not_null()
				assert_str(paso.foto.texto).is_empty()
				assert_object(bandeja.adjunto_de(guion.interlocutor, entrada)).is_same(texto)
				assert_str(paso.foto.foto.resource_path).is_equal(
					"res://assets/ui/manada/fotos/intro-%02d.png" % (texto_actual + 1)
				)
				entrada += 1
			assert_object(texto).is_same(guion.mensajes[entrada])
			assert_str(texto.texto).is_equal(TEXTOS[texto_actual])
			assert_int(texto.jornada).is_equal(1)
			entrada += 1
			texto_actual += 1
	assert_int(texto_actual).is_equal(14)
	assert_int(entrada).is_equal(21)
	assert_array(guion.mensajes).is_equal(originales)


func test_sin_mensajes_no_inventa_pantallas() -> void:  # AC-EMP-046
	assert_array(InstruccionesDelJefe.pasos_de([])).is_empty()
