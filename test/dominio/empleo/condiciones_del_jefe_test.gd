extends GdUnitTestSuite

const GUION := "res://src/dominio/investigacion/conversacion_con_el_jefe.tres"
const SEGUNDA := ReglasDeLaPartida.PRIMERA_JORNADA + 1
const TERCERA := ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA
const T := Tarea.Tipo

## Clientes mal atendidos, si registrar y reponer quedaron cumplidas y la entrada que abre la
## jornada 2. Sin fila en la ficha, cero clientes con registrar y reponer sin cumplir usa la de
## registrar (OQ-EMP-014).
const FILAS := [
	[0, true, true, "J2_Mensaje1_SinFallas"],
	[0, false, true, "J2_Mensaje1_RegistroMal"],
	[0, false, false, "J2_Mensaje1_RegistroMal"],
	[0, true, false, "J2_Mensaje1_ReposicionMal"],
	[1, true, true, "J2_Mensaje1_UnClienteMal"],
	[1, true, false, "J2_Mensaje1_UnClienteYReposicionMal"],
	[1, false, true, "J2_Mensaje1_UnClienteYRegistroMal"],
	[1, false, false, "J2_Mensaje1_UnClienteYTodoMal"],
	[2, true, true, "J2_Mensaje1_NingunoEnCero"],
	[2, true, false, "J2_Mensaje1_NingunoEnCeroYReposicionMal"],
	[2, false, true, "J2_Mensaje1_NingunoAnotado"],
	[2, false, false, "J2_Mensaje1_NingunoAnotadoYReposicionMal"],
]
const RESTO_DE_LA_SEGUNDA := [
	"J2_FotoGondolas", "J1_Foto07", "J1_Intro07", "J1_Intro08", "J1_Foto09", "J1_Intro09"
]


static func cerrar_la_primera(mal_atendidos: int, registrar: bool, reponer: bool = true) -> Partida:
	var partida := Partida.nueva()
	var sin_cumplir: Array[Tarea.Tipo] = []
	if not registrar:
		sin_cumplir.append(Tarea.Tipo.REGISTRAR)
	if not reponer:
		sin_cumplir.append(Tarea.Tipo.REPONER)
	cerrar_la_noche(partida, mal_atendidos, sin_cumplir)
	return partida


## Las dos noches de prueba, cada una con sus clientes mal atendidos y lo que dejó sin cumplir.
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
		var partida := cerrar_la_primera(fila[0], fila[1], fila[2])
		assert_int(partida.jornada()).is_equal(SEGUNDA)
		var propios := InstruccionesDelJefe.de_la_jornada(
			guion.mensajes, SEGUNDA, CondicionesDelJefe.elegidas(partida.noches_de_prueba)
		)
		assert_array(_identidades(propios)).is_equal([fila[3]] + RESTO_DE_LA_SEGUNDA)
		assert_bool(propios[0].dice_algo()).is_true()


func test_tres_o_mas_clientes_mal_atendidos_cuentan_como_dos() -> void:  # AC-EMP-084
	var guion: Conversacion = load(GUION)
	var partida := cerrar_la_primera(5, true, true)
	var propios := InstruccionesDelJefe.de_la_jornada(
		guion.mensajes, SEGUNDA, CondicionesDelJefe.elegidas(partida.noches_de_prueba)
	)
	assert_str(propios[0].identidad).is_equal("J2_Mensaje1_NingunoEnCero")


func test_sin_la_noche_1_la_jornada_2_abre_con_intro_7() -> void:  # AC-EMP-084
	var guion: Conversacion = load(GUION)
	var partida := Partida.desde({"jornada": SEGUNDA})
	assert_array(CondicionesDelJefe.elegidas(partida.noches_de_prueba)).is_empty()
	var propios := InstruccionesDelJefe.de_la_jornada(
		guion.mensajes, SEGUNDA, CondicionesDelJefe.elegidas(partida.noches_de_prueba)
	)
	assert_array(_identidades(propios)).is_equal(RESTO_DE_LA_SEGUNDA)


func _apertura_de_la_tercera(partida: Partida) -> Array[String]:
	var guion: Conversacion = load(GUION)
	var condiciones := CondicionesDelJefe.elegidas(partida.noches_de_prueba)
	var bandeja := Bandeja.new([guion])
	bandeja.abrir_jornada(TERCERA, condiciones)
	var propios: Array[String] = []
	for mensaje in bandeja.mensajes_de(guion.interlocutor):
		if mensaje.jornada == TERCERA:
			propios.append(mensaje.identidad)
	var instrucciones := InstruccionesDelJefe.de_la_jornada(guion.mensajes, TERCERA, condiciones)
	assert_array(_identidades(instrucciones)).is_equal(propios)
	return propios.slice(0, propios.find("J1_Intro10") + 1)


func test_las_dos_noches_eligen_el_mensaje_1_de_la_tercera() -> void:  # AC-EMP-089
	var limpio := [0, []]
	var tres_fallas := [2, [T.REGISTRAR]]
	var casos := [
		[[limpio, limpio], "J3_Mensaje1_SinFallas"],
		[[[5, []], limpio], "J3_Mensaje1_Redimido"],
		[[tres_fallas, limpio], "J3_Mensaje1_ConAltibajos"],
		[[[1, []], [0, [T.LIMPIAR]]], "J3_Mensaje1_ConAltibajos"],
	]
	for caso: Array in casos:
		var partida := cerrar_la_prueba(caso[0])
		assert_int(partida.jornada()).is_equal(TERCERA)
		assert_array(_apertura_de_la_tercera(partida)).is_equal([caso[1], "J1_Intro10"])


func test_sin_la_noche_2_la_tercera_abre_con_su_mensaje_2() -> void:  # AC-EMP-089
	var partida := cerrar_la_primera(0, true)
	assert_array(_apertura_de_la_tercera(partida)).is_equal(["J1_Intro10"])


func test_cada_fila_del_guion_tiene_su_condicion() -> void:  # AC-EMP-084, AC-EMP-089
	var guion: Conversacion = load(GUION)
	var elegibles: Array[StringName] = []
	for fila: Array in FILAS:
		elegibles.append_array(
			CondicionesDelJefe.elegidas(
				cerrar_la_primera(fila[0], fila[1], fila[2]).noches_de_prueba
			)
		)
	for noches: Array in [
		[[0, []], [0, []]],
		[[5, []], [0, []]],
		[[1, []], [0, []]],
	]:
		elegibles.append_array(
			CondicionesDelJefe.elegidas(cerrar_la_prueba(noches).noches_de_prueba)
		)
	for mensaje: Mensaje in guion.mensajes:
		if mensaje.condicion.is_empty():
			continue
		assert_array([SEGUNDA, TERCERA]).contains([mensaje.jornada])
		assert_bool(elegibles.has(mensaje.condicion)).is_true()
		assert_bool(mensaje.dice_algo()).is_true()
