extends GdUnitTestSuite

const GUION := "res://src/dominio/investigacion/conversacion_con_el_jefe.tres"
const TEXTOS: Array[String] = [
	(
		"¿Cómo andás, pibe? Llegó el momento de lucirte. Tu período de prueba va a "
		+ "ser de solo cinco jornadas. ¿Quién pudiera, no?\n\nDe todos modos, acordate "
		+ "de que el primer mes no es pago, porque lo tomamos como capacitación. ;)"
	),
	(
		"Bueno, como ya te comenté, [b]la jornada es de 20:00 a 08:00. [/b]Debería "
		+ "sobrarte el tiempo para cumplir con las [b]tareas [/b]que te voy a "
		+ "dejar.\n\nCualquier cosa, siempre van a quedar [b]anotadas en el corcho[/b],"
		+ " atrás del mostrador. Te las resumo:"
	),
	(
		"Primero, y lo más importante: [b]ATENDER A LOS CLIENTES[/b]. A esa hora, la "
		+ "entrada principal queda cerrada, así que vas a tener que [b]hablarles y "
		+ "entregarles los productos por la ventanilla[/b]. ¡Y no te olvides de "
		+ "[b]darles un ticket [/b]de recibo!"
	),
	(
		"Para [b]generar un ticket[/b], tenés que pasar todos los productos por el "
		+ "[b]lector del mostrador[/b] y darle al botón “IMPRIMIR” en el [b]programa de"
		+ " la caja registradora[/b]. Nada muy complejo."
	),
	(
		"Conozco a varios que hasta son capaces de dejar los productos e irse si no "
		+ "les das su recibo. Eso NO puede pasar.\n\nMi estación de servicio es el "
		+ "único local del pueblo que queda abierto las 24 horas, así que los "
		+ "compradores nocturnos dependen de nosotros. Atenderlos mal es faltarle el "
		+ "respeto a nuestros vecinos, así que ojito."
	),
	(
		"En segundo lugar, [b]ANOTAR LOS PRODUCTOS VENDIDOS [/b]durante la noche en "
		+ "la [b]computadora[/b]. Bastante simple."
	),
	(
		"Tercero, hacer la [b]REPOSICIÓN[/b]. Revisá bien todas las [b]góndolas [/b]y"
		+ " reponé los ítems que falten con los de las [b]cajas del depósito[/b]."
	),
	(
		"No quiero ver ni un solo hueco vacío.\n\nUn único producto ausente en la "
		+ "mañana puede hacer la diferencia entre un local de excelencia y uno "
		+ "mediocre. No podemos dar la impresión de que estamos cortos de stock."
	),
	(
		"Cuarto, pero no menor, [b]LIMPIAR[/b]. Vas a encontrar los [b]productos de "
		+ "limpieza en el baño[/b], además de algunas [b]notitas [/b]explicando cómo "
		+ "usarlos. No deberías tener problemas con eso."
	),
	(
		"Además de los quehaceres rutinarios, siempre queda alguna cosita por hacer. "
		+ "Por eso, no te sorprendas si ves una quinta tarea diferente cada noche. "
		+ "Tranqui, que te voy a dejar instrucciones por mensaje."
	),
	(
		"Para esta noche, te pido [b]ORGANIZAR LAS CAJAS[/b] que dejó el proveedor. "
		+ "Acomodalas [b]en los estantes del depósito[/b] y que no quede ni una en el "
		+ "piso, ¿ok?"
	),
	(
		"Te voy a tener cortito con esos detalles. Para trabajar en una estación de "
		+ "servicio tan prestigiosa como esta, tenés que estar al nivel.\n\nMe parece "
		+ "que con eso cubrimos todo. No te olvides de dejar el local correctamente "
		+ "ordenado antes de irte. ¿Estamos?"
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
	var mensajes := Bandeja.new([guion]).mensajes_de(guion.interlocutor)
	var pasos := InstruccionesDelJefe.pasos_de(mensajes)
	assert_int(mensajes.size()).is_equal(19)
	assert_int(pasos.size()).is_equal(12)
	assert_str(guion.nombre).is_equal("Enrique Peldaño")
	assert_object(guion.imagen).is_not_null()
	var fotos: Array[int] = [2, 3, 4, 6, 7, 9, 11]
	var bandeja := Bandeja.new([guion])
	var texto_actual := 0
	var entrada := 0
	for indice in pasos.size():
		var paso: InstruccionesDelJefe.Paso = pasos[indice]
		assert_int(paso.textos.size()).is_equal(1)
		for texto in paso.textos:
			if fotos.has(texto_actual + 1):
				assert_object(paso.foto).is_same(mensajes[entrada])
				assert_object(paso.foto.foto).is_not_null()
				assert_str(paso.foto.texto).is_empty()
				assert_object(bandeja.adjunto_de(guion.interlocutor, entrada)).is_same(texto)
				assert_str(paso.foto.foto.resource_path).is_equal(
					(
						"res://assets/ui/manada/fotos/intro-%02d.png"
						% ([4, 6, 7, 8, 9, 11, 13][fotos.find(texto_actual + 1)])
					)
				)
				entrada += 1
			assert_object(texto).is_same(mensajes[entrada])
			assert_str(texto.texto).is_equal(TEXTOS[texto_actual])
			assert_int(texto.jornada).is_equal(1)
			entrada += 1
			texto_actual += 1
	assert_int(texto_actual).is_equal(12)
	assert_int(entrada).is_equal(19)
	assert_array(guion.mensajes).is_equal(originales)


func test_sin_mensajes_no_inventa_pantallas() -> void:  # AC-EMP-046
	assert_array(InstruccionesDelJefe.pasos_de([])).is_empty()
