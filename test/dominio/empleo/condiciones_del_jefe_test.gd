## Qué mensaje 1 abre cada jornada de prueba según la noche anterior, jugada sobre una partida y
## leído del guion real.
extends GdUnitTestSuite

const GUION := "res://src/dominio/investigacion/conversacion_con_el_jefe.tres"
const SEGUNDA := ReglasDeLaPartida.PRIMERA_JORNADA + 1
const TERCERA := ReglasDeLaPartida.PRIMERA_JORNADA + 2

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


static func cerrar_la_primera(mal_atendidos: int, registrar: bool) -> Partida:
	var partida := Partida.nueva()
	var sin_cumplir: Array[Tarea.Tipo] = []
	if not registrar:
		sin_cumplir.append(Tarea.Tipo.REGISTRAR)
	cerrar_la_noche(partida, mal_atendidos, sin_cumplir)
	return partida


## La noche 1 sin fallas y la 2 como dice la fila.
static func cerrar_la_segunda(mal_atendidos: int, registrar: bool, reponer: bool) -> Partida:
	var partida := cerrar_la_primera(0, true)
	var sin_cumplir: Array[Tarea.Tipo] = []
	if not registrar:
		sin_cumplir.append(Tarea.Tipo.REGISTRAR)
	if not reponer:
		sin_cumplir.append(Tarea.Tipo.REPONER)
	cerrar_la_noche(partida, mal_atendidos, sin_cumplir)
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
			[fila[2], "J1_Foto07", "J1_Intro07", "J1_Intro08"]
		)


func test_sin_la_noche_1_la_jornada_2_abre_con_intro_7() -> void:  # AC-EMP-084
	var guion: Conversacion = load(GUION)
	var partida := Partida.desde({"jornada": SEGUNDA})
	assert_array(CondicionesDelJefe.elegidas(partida.noches_de_prueba)).is_empty()
	var propios := InstruccionesDelJefe.de_la_jornada(
		guion.mensajes, SEGUNDA, CondicionesDelJefe.elegidas(partida.noches_de_prueba)
	)
	assert_array(_identidades(propios)).is_equal(["J1_Foto07", "J1_Intro07", "J1_Intro08"])


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


func test_cada_fila_del_guion_tiene_su_condicion() -> void:  # AC-EMP-084, AC-EMP-087
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
	for mensaje: Mensaje in guion.mensajes:
		if mensaje.condicion.is_empty():
			continue
		assert_array([SEGUNDA, TERCERA]).contains([mensaje.jornada])
		assert_bool(elegibles.has(mensaje.condicion)).is_true()
		assert_bool(mensaje.dice_algo()).is_true()
