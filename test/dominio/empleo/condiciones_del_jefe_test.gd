extends GdUnitTestSuite

const GUION := "res://src/dominio/investigacion/conversacion_con_el_jefe.tres"
const SEGUNDA := ReglasDeLaPartida.PRIMERA_JORNADA + 1

## Clientes mal atendidos, si registrar quedó cumplida y la entrada que abre la jornada 2.
const FILAS := [
	[0, true, "J2_Mensaje1_SinFallas"],
	[0, false, "J2_Mensaje1_RegistroMal"],
	[1, true, "J2_Mensaje1_UnClienteMal"],
	[1, false, "J2_Mensaje1_UnClienteMal"],
	[2, true, "J2_Mensaje1_NingunoEnCero"],
	[2, false, "J2_Mensaje1_NingunoAnotado"],
]

const TEXTOS: Dictionary[String, String] = {
	"J2_Mensaje1_SinFallas":
	"Muy bien. Veo que pudiste cumplir con tus tareas correctamente, así que te voy a sumar una más.",
	"J2_Mensaje1_RegistroMal":
	(
		"Bueno, por lo visto, pudiste atender bien a todos los clientes, "
		+ "pero el registro de ventas no cuadra.\n\n"
		+ "Vas a tener que prestar más atención, especialmente ahora que te voy a sumar una tarea más."
	),
	"J2_Mensaje1_UnClienteMal":
	(
		"Bueno, por lo visto, el registro de ventas cuadra bien, "
		+ "pero me enteré de que un cliente se fue insatisfecho ayer.\n\n"
		+ "Voy a ser considerado con vos porque fue tu primer día, "
		+ "pero vas a tener que ponerte las pilas, "
		+ "especialmente ahora que te voy a sumar una tarea más."
	),
	"J2_Mensaje1_NingunoEnCero":
	(
		"Che, me enteré de que ayer pasaron dos clientes "
		+ "y no atendiste correctamente a ninguno de los dos. "
		+ "O sea, por culpa tuya no tuvimos ingresos en el turno nocturno.\n\n"
		+ "Voy a ser considerado con vos porque fue tu primer día, "
		+ "pero vamos a tener problemas si no te ponés las pilas, "
		+ "especialmente ahora que te voy a sumar una tarea más."
	),
	"J2_Mensaje1_NingunoAnotado":
	(
		"Che, me enteré de que ayer pasaron dos clientes "
		+ "y no atendiste correctamente a ninguno de los dos. "
		+ "O sea, por culpa tuya no tuvimos ingresos en el turno nocturno. "
		+ "Y encima anotaste en el registro productos que no se vendieron "
		+ "¿me estás tomando el pelo?\n\n"
		+ "Voy a ser considerado con vos porque fue tu primer día, "
		+ "pero vamos a tener problemas si no te ponés las pilas, "
		+ "especialmente ahora que te voy a sumar una tarea más."
	),
}


static func cerrar_la_primera(mal_atendidos: int, registrar: bool) -> Partida:
	var partida := Partida.nueva()
	partida.abrir_la_jornada()
	var cumplidas := 0
	for tarea: Tarea in partida.obligatorias():
		if tarea.tipo() != Tarea.Tipo.REGISTRAR or registrar:
			tarea.completar()
			cumplidas += 1
	partida.cerrar_la_jornada(cumplidas, mal_atendidos)
	return partida


func _identidades(mensajes: Array[Mensaje]) -> Array[String]:
	var identidades: Array[String] = []
	for mensaje in mensajes:
		identidades.append(mensaje.identidad)
	return identidades


func test_cada_noche_1_elige_una_sola_fila() -> void:  # AC-EMP-084
	var guion: Conversacion = load(GUION)
	for fila: Array in FILAS:
		var partida := cerrar_la_primera(fila[0], fila[1])
		assert_int(partida.jornada()).is_equal(SEGUNDA)
		var propios := InstruccionesDelJefe.de_la_jornada(
			guion.mensajes, SEGUNDA, CondicionesDelJefe.elegidas(partida.noches_de_prueba)
		)
		assert_array(_identidades(propios)).is_equal(
			[fila[2], "J1_Foto07", "J1_Intro07", "J1_Intro08"]
		)
		assert_str(propios[0].texto).is_equal(TEXTOS[fila[2]])


func test_sin_la_noche_1_la_jornada_2_abre_con_intro_7() -> void:  # AC-EMP-084
	var guion: Conversacion = load(GUION)
	var partida := Partida.desde({"jornada": SEGUNDA})
	assert_array(CondicionesDelJefe.elegidas(partida.noches_de_prueba)).is_empty()
	var propios := InstruccionesDelJefe.de_la_jornada(
		guion.mensajes, SEGUNDA, CondicionesDelJefe.elegidas(partida.noches_de_prueba)
	)
	assert_array(_identidades(propios)).is_equal(["J1_Foto07", "J1_Intro07", "J1_Intro08"])


func test_cada_fila_del_guion_tiene_su_condicion() -> void:  # AC-EMP-084
	var guion: Conversacion = load(GUION)
	var elegibles: Array[StringName] = []
	for fila: Array in FILAS:
		elegibles.append_array(
			CondicionesDelJefe.elegidas(cerrar_la_primera(fila[0], fila[1]).noches_de_prueba)
		)
	for mensaje: Mensaje in guion.mensajes:
		if mensaje.condicion.is_empty():
			continue
		assert_int(mensaje.jornada).is_equal(SEGUNDA)
		assert_bool(elegibles.has(mensaje.condicion)).is_true()
		assert_bool(mensaje.dice_algo()).is_true()
