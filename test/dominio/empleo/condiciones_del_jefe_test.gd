extends GdUnitTestSuite

const GUION := "res://src/dominio/investigacion/conversacion_con_el_jefe.tres"
const SEGUNDA := ReglasDeLaPartida.PRIMERA_JORNADA + 1
const TERCERA := ReglasDeLaPartida.PRIMERA_JORNADA + 2
const CUARTA := ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA
const T := Tarea.Tipo

## Clientes mal atendidos, si registrar quedó cumplida y la entrada que abre la jornada 2.
const FILAS := [
	[0, true, "J2_Mensaje1_SinFallas"],
	[0, false, "J2_Mensaje1_RegistroMal"],
	[1, true, "J2_Mensaje1_UnClienteMal"],
	[1, false, "J2_Mensaje1_UnClienteMal"],
	[2, true, "J2_Mensaje1_NingunoEnCero"],
	[2, false, "J2_Mensaje1_NingunoAnotado"],
]
## Clientes mal atendidos, si registrar y reponer quedaron cumplidas y la entrada que abre la
## jornada 3.
const FILAS_DE_LA_TERCERA := [
	[0, true, true, "J3_Mensaje1_SinFallas"],
	[0, true, false, "J3_Mensaje1_ReposicionMal"],
	[0, false, true, "J3_Mensaje1_RegistroMal"],
	[0, false, false, "J3_Mensaje1_RegistroYReposicionMal"],
	[1, true, true, "J3_Mensaje1_AtencionMal"],
	[1, false, true, "J3_Mensaje1_AtencionYRegistroMal"],
	[1, true, false, "J3_Mensaje1_AtencionYReposicionMal"],
	[1, false, false, "J3_Mensaje1_TodoMal"],
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
	var sin_cumplir: Array[Tarea.Tipo] = []
	if not registrar:
		sin_cumplir.append(Tarea.Tipo.REGISTRAR)
	cerrar_la_noche(partida, mal_atendidos, sin_cumplir)
	return partida


static func cerrar_la_segunda(mal_atendidos: int, registrar: bool, reponer: bool) -> Partida:
	var partida := cerrar_la_primera(0, true)
	var sin_cumplir: Array[Tarea.Tipo] = []
	if not registrar:
		sin_cumplir.append(Tarea.Tipo.REGISTRAR)
	if not reponer:
		sin_cumplir.append(Tarea.Tipo.REPONER)
	cerrar_la_noche(partida, mal_atendidos, sin_cumplir)
	return partida


## Las tres noches de prueba, cada una con sus clientes mal atendidos y lo que dejó sin cumplir.
static func cerrar_la_prueba(noches: Array) -> Partida:
	var partida := Partida.nueva()
	for noche: Array in noches:
		var sin_cumplir: Array[Tarea.Tipo] = []
		sin_cumplir.assign(noche[1])
		cerrar_la_noche(partida, noche[0], sin_cumplir)
	return partida


static func cerrar_la_noche(
	partida: Partida, mal_atendidos: int, sin_cumplir: Array[Tarea.Tipo]
) -> void:
	partida.abrir_la_jornada()
	var cumplidas := 0
	for tarea: Tarea in partida.obligatorias():
		if not sin_cumplir.has(tarea.tipo()):
			tarea.completar()
			cumplidas += 1
	partida.cerrar_la_jornada(cumplidas, mal_atendidos)


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
			[fila[2], "J2_FotoGondolas", "J1_Foto07", "J1_Intro07", "J1_Intro08"]
		)
		assert_str(propios[0].texto).is_equal(TEXTOS[fila[2]])


func test_sin_la_noche_1_la_jornada_2_abre_con_intro_7() -> void:  # AC-EMP-084
	var guion: Conversacion = load(GUION)
	var partida := Partida.desde({"jornada": SEGUNDA})
	assert_array(CondicionesDelJefe.elegidas(partida.noches_de_prueba)).is_empty()
	var propios := InstruccionesDelJefe.de_la_jornada(
		guion.mensajes, SEGUNDA, CondicionesDelJefe.elegidas(partida.noches_de_prueba)
	)
	assert_array(_identidades(propios)).is_equal(
		["J2_FotoGondolas", "J1_Foto07", "J1_Intro07", "J1_Intro08"]
	)


func test_cada_noche_2_elige_una_sola_fila() -> void:  # AC-EMP-087
	var guion: Conversacion = load(GUION)
	for fila: Array in FILAS_DE_LA_TERCERA:
		var partida := cerrar_la_segunda(fila[0], fila[1], fila[2])
		assert_int(partida.jornada()).is_equal(TERCERA)
		var propios := InstruccionesDelJefe.de_la_jornada(
			guion.mensajes, TERCERA, CondicionesDelJefe.elegidas(partida.noches_de_prueba)
		)
		assert_array(_identidades(propios)).is_equal([fila[3], "J1_Foto09", "J1_Intro09"])


func test_dos_clientes_mal_atendidos_son_la_atencion_mal() -> void:  # AC-EMP-087
	var guion: Conversacion = load(GUION)
	var partida := cerrar_la_segunda(2, true, true)
	var propios := InstruccionesDelJefe.de_la_jornada(
		guion.mensajes, TERCERA, CondicionesDelJefe.elegidas(partida.noches_de_prueba)
	)
	assert_str(propios[0].identidad).is_equal("J3_Mensaje1_AtencionMal")


func test_sin_la_noche_2_la_jornada_3_abre_con_intro_9() -> void:  # AC-EMP-087
	var guion: Conversacion = load(GUION)
	var clave := PartidaSerializada.clave(PartidaSerializada.Campo.NOCHES_DE_PRUEBA)
	var primera := {ReglasDeLaPartida.PRIMERA_JORNADA: ResultadoDeLaNoche.new(0, []).a_datos()}
	var partida := Partida.desde({"jornada": TERCERA, clave: primera})
	assert_array(CondicionesDelJefe.elegidas(partida.noches_de_prueba)).is_not_empty()
	var propios := InstruccionesDelJefe.de_la_jornada(
		guion.mensajes, TERCERA, CondicionesDelJefe.elegidas(partida.noches_de_prueba)
	)
	assert_array(_identidades(propios)).is_equal(["J1_Foto09", "J1_Intro09"])


## Lo primero que Enrique dice en la jornada 4, hasta su mensaje 2. Las instrucciones dicen lo
## mismo que el chat.
func _apertura_de_la_cuarta(partida: Partida) -> Array[String]:
	var guion: Conversacion = load(GUION)
	var condiciones := CondicionesDelJefe.elegidas(partida.noches_de_prueba)
	var bandeja := Bandeja.new([guion])
	bandeja.abrir_jornada(CUARTA, condiciones)
	var propios: Array[String] = []
	for mensaje in bandeja.mensajes_de(guion.interlocutor):
		if mensaje.jornada == CUARTA:
			propios.append(mensaje.identidad)
	var instrucciones := InstruccionesDelJefe.de_la_jornada(guion.mensajes, CUARTA, condiciones)
	assert_array(_identidades(instrucciones)).is_equal(propios)
	return propios.slice(0, propios.find("J1_Intro10") + 1)


func test_las_tres_noches_eligen_el_mensaje_1_de_la_cuarta() -> void:  # AC-EMP-089
	var limpio := [0, []]
	var tres_fallas := [2, [T.REGISTRAR]]
	var casos := [
		[[limpio, limpio, limpio], "J4_Mensaje1_SinFallas"],
		[[tres_fallas, [2, []], limpio], "J4_Mensaje1_Redimido"],
		[[tres_fallas, limpio, limpio], "J4_Mensaje1_ConAltibajos"],
		[[[1, []], limpio, [0, [T.LIMPIAR]]], "J4_Mensaje1_ConAltibajos"],
	]
	for caso: Array in casos:
		var partida := cerrar_la_prueba(caso[0])
		assert_int(partida.jornada()).is_equal(CUARTA)
		assert_array(_apertura_de_la_cuarta(partida)).is_equal([caso[1], "J1_Intro10"])


func test_sin_la_noche_3_la_cuarta_abre_con_su_mensaje_2() -> void:  # AC-EMP-089
	var partida := cerrar_la_segunda(0, true, true)
	assert_array(_apertura_de_la_cuarta(partida)).is_equal(["J1_Intro10"])


func test_cada_fila_del_guion_tiene_su_condicion() -> void:  # AC-EMP-084, AC-EMP-087, AC-EMP-089
	var guion: Conversacion = load(GUION)
	var elegibles: Array[StringName] = []
	for fila: Array in FILAS:
		elegibles.append_array(
			CondicionesDelJefe.elegidas(cerrar_la_primera(fila[0], fila[1]).noches_de_prueba)
		)
	for fila: Array in FILAS_DE_LA_TERCERA:
		elegibles.append_array(
			CondicionesDelJefe.elegidas(
				cerrar_la_segunda(fila[0], fila[1], fila[2]).noches_de_prueba
			)
		)
	for noches: Array in [
		[[0, []], [0, []], [0, []]],
		[[5, []], [0, []], [0, []]],
		[[1, []], [0, []], [0, []]],
	]:
		elegibles.append_array(
			CondicionesDelJefe.elegidas(cerrar_la_prueba(noches).noches_de_prueba)
		)
	for mensaje: Mensaje in guion.mensajes:
		if mensaje.condicion.is_empty():
			continue
		assert_array([SEGUNDA, TERCERA, CUARTA]).contains([mensaje.jornada])
		assert_bool(elegibles.has(mensaje.condicion)).is_true()
		assert_bool(mensaje.dice_algo()).is_true()
