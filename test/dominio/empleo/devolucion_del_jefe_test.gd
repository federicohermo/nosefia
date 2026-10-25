# gdlint:ignore=max-public-methods
## La devolución de Enrique, armada sin levantar una escena: qué partes van, en qué orden, y qué
## fila de la tabla gana.
extends GdUnitTestSuite

const CondicionesDelJefeTest := preload("res://test/dominio/empleo/condiciones_del_jefe_test.gd")
const T := Tarea.Tipo
const L := Partida.Llamado

## Medios por punto: P = 2 son cuatro medios.
const M := Reglas.MEDIOS_POR_APERCIBIMIENTO

const COMPLETA := ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA


## Las cuentas ya con la noche anotada, como las deja la partida al cerrar.
func _antecedentes(
	fallas: Dictionary = {}, llamados: Dictionary = {}, noches_sin_sumar: int = 0
) -> Antecedentes:
	var datos := {
		Antecedentes.CLAVE_DE_FALLAS: {},
		Antecedentes.CLAVE_DE_LLAMADOS: {},
		Antecedentes.CLAVE_DE_NOCHES_SIN_SUMAR: noches_sin_sumar,
	}
	for tipo: T in fallas:
		datos[Antecedentes.CLAVE_DE_FALLAS][T.keys()[tipo]] = fallas[tipo]
	for motivo: L in llamados:
		datos[Antecedentes.CLAVE_DE_LLAMADOS][L.keys()[motivo]] = llamados[motivo]
	return Antecedentes.desde(datos)


func _cierre(jornada: int, medios: int, noches: int, hubo: bool = false) -> String:
	var llamados := {L.LOCAL_DESORDENADO: 1} if hubo else {}
	return (
		DevolucionDelJefe.armar(jornada, medios, _antecedentes({}, llamados, noches), [], []).back()
	)


func _partida_de_la_noche(
	jornada: int,
	cumplidas: Array[T],
	llamados: Array[L],
	medios: int = 0,
	bolsa_afuera: bool = false
) -> Partida:
	var partida := Partida.desde({"jornada": jornada, "medios": medios})
	partida.abrir_la_jornada()
	for tarea: Tarea in partida.obligatorias():
		if cumplidas.has(tarea.tipo()):
			tarea.completar()
	for llamado: L in llamados:
		partida.anotar_llamado(llamado)
	if bolsa_afuera:
		partida.bolsa_afuera = true
	partida.cerrar_la_jornada(cumplidas.size())
	return partida


func _tipos_de(jornada: int) -> Array[T]:
	var todas: Array[T] = []
	for tarea: Tarea in Apertura.obligatorias(jornada):
		todas.append(tarea.tipo())
	return todas


func test_la_primera_noche_completa_impecable_es_saludo_y_cierre() -> void:  # AC-EMP-051
	var partida := _partida_de_la_noche(COMPLETA, _tipos_de(COMPLETA), [])
	var devolucion := DevolucionDelJefe.new(COMPLETA, partida)
	(
		assert_array(devolucion.mensajes())
		. is_equal(
			[
				"Buen día!",
				"Seguiste todas mis instrucciones al pie de la letra. Excelente. Seguí así.",
			]
		)
	)


func test_las_noches_de_introduccion_cierran_sin_devolucion() -> void:  # AC-EMP-092
	for jornada: int in range(ReglasDeLaPartida.PRIMERA_JORNADA, COMPLETA):
		var partida := _partida_de_la_noche(jornada, _tipos_de(jornada), [])
		var devolucion := DevolucionDelJefe.new(jornada, partida)
		assert_array(devolucion.mensajes()).is_empty()
		assert_array(partida.mensajes_del_jefe()).is_empty()
		var fallida := _partida_de_la_noche(jornada, [], [L.PAPEL_EN_EL_INODORO])
		var sin_mensajes := DevolucionDelJefe.new(jornada, fallida)
		assert_array(sin_mensajes.mensajes()).is_empty()
		assert_array(sin_mensajes.mensajes_fechados()).is_empty()
		assert_array(fallida.mensajes_del_jefe()).is_empty()
		assert_array(PoliticaDeGuardado.datos(fallida).devoluciones).is_empty()
	var completa := _partida_de_la_noche(COMPLETA, _tipos_de(COMPLETA), [])
	assert_array(completa.mensajes_del_jefe()).is_not_empty()


func test_el_celular_sube_desde_la_primera_noche_completa() -> void:  # AC-EMP-093, AC-EMP-064
	for jornada: int in range(ReglasDeLaPartida.PRIMERA_JORNADA, COMPLETA):
		var prueba := _partida_de_la_noche(jornada, _tipos_de(jornada), [])
		assert_bool(DevolucionDelJefe.new(jornada, prueba).por_el_celular()).is_false()
	var completa := _partida_de_la_noche(COMPLETA, _tipos_de(COMPLETA), [])
	assert_bool(DevolucionDelJefe.new(COMPLETA, completa).por_el_celular()).is_true()


func test_reponer_dice_la_falla_que_es() -> void:  # AC-EMP-052
	var primera := DevolucionDelJefe.armar(
		COMPLETA, 2, _antecedentes({T.REPONER: 1}), [T.REPONER], []
	)
	assert_bool(primera[1].begins_with("Faltó reponer algunas unidades")).is_true()
	var segunda := DevolucionDelJefe.armar(
		COMPLETA + 1, 4, _antecedentes({T.REPONER: 2}, {}, 0), [T.REPONER], []
	)
	assert_int(segunda.size()).is_equal(3)
	assert_bool(segunda[1].begins_with("No podés dejarle a tu compañera")).is_true()
	var cumplida := DevolucionDelJefe.armar(
		COMPLETA + 2, 4, _antecedentes({T.REPONER: 2}, {}, 1), [], []
	)
	assert_int(cumplida.size()).is_equal(2)
	var registrar := DevolucionDelJefe.armar(
		COMPLETA + 2, 6, _antecedentes({T.REGISTRAR: 3}), [T.REGISTRAR], []
	)
	assert_str(registrar[1]).contains("está mal otra vez")


func test_el_reto_2_de_la_jornada_5_cuenta_para_despues() -> void:  # AC-EMP-053
	var jornada_5 := DevolucionDelJefe.armar(
		5, 2, _antecedentes({}, {L.OBJETO_TIRADO: 1}), [], [L.OBJETO_TIRADO]
	)
	assert_bool(jornada_5[1].begins_with('Por si no lo sabías, la "basura"')).is_true()
	var jornada_7 := DevolucionDelJefe.armar(
		7, 4, _antecedentes({}, {L.OBJETO_TIRADO: 2}), [], [L.OBJETO_TIRADO]
	)
	assert_str(jornada_7[1]).is_equal("El contenedor de basura es para BASURA solamente.")
	var jornada_4 := DevolucionDelJefe.armar(
		COMPLETA, 1, _antecedentes({}, {L.OBJETO_TIRADO: 1}), [], [L.OBJETO_TIRADO]
	)
	assert_str(jornada_4[1]).is_equal("Puede ser que hayas estado tirando cosas a la basura?")
	var basura := DevolucionDelJefe.armar(5, 2, _antecedentes(), [T.SACAR_LA_BASURA], [])
	assert_str(basura[1]).is_equal("De verdad era tan difícil tirar tres bolsas de basura?")


func test_el_reto_2_de_la_jornada_6_no_trae_tarea_5() -> void:  # AC-EMP-054
	for n: int in [1, 2]:
		var mensajes := DevolucionDelJefe.armar(
			6, 2, _antecedentes({}, {L.OBJETO_TIRADO: n}), [], [L.OBJETO_TIRADO]
		)
		assert_int(mensajes.size()).is_equal(3)
		assert_str(mensajes[1]).is_equal(
			(
				"Cuando te pedí que tiraras algunos productos, no me refería a objetos útiles "
				+ "y en buen estado!"
			)
		)


func test_p_4_en_la_octava_despide() -> void:  # AC-EMP-055
	var despido := DevolucionDelJefe.armar(8, 4 * M, _antecedentes(), [], [])
	assert_str(despido[0]).is_equal("Che")
	assert_str(despido.back()).is_equal(DevolucionDelJefe.CIERRE_DEL_DESPIDO)
	for fila: Array in DevolucionDelJefe.CIERRES_DE_LA_ULTIMA:
		assert_array(despido).not_contains([fila[1]])
	var al_borde := DevolucionDelJefe.armar(8, 7, _antecedentes(), [], [])
	assert_str(al_borde[0]).is_equal("Buenos días...")
	(
		assert_bool(al_borde.back().begins_with("Me parece que quedan muchas cosas para pulir"))
		. is_true()
	)


func test_p_2_distingue_si_hubo_llamados_en_la_partida() -> void:  # AC-EMP-056
	var sin := _cierre(COMPLETA + 1, 2 * M, 0, false)
	var con := _cierre(COMPLETA + 1, 2 * M, 0, true)
	assert_str(sin).is_equal(
		"Acordate de chequear que todas las tareas estén cerradas antes de irte, dale?"
	)
	assert_str(con).is_equal(
		"Acordate de hacer bien tu trabajo y respetar las normas básicas de convivencia, dale?"
	)
	assert_str(sin).is_equal(sin.strip_edges())
	assert_str(con).is_equal(con.strip_edges())


func test_la_mejora_gana_sobre_la_advertencia() -> void:  # AC-EMP-057
	assert_str(_cierre(COMPLETA + 1, 2, 1)).is_equal(
		"Ahora sí le vas agarrando la mano! Muy bien. Seguí así."
	)
	assert_str(_cierre(COMPLETA + 2, 2, 2)).is_equal("Sin nada para comentar. Adelante con eso.")
	assert_str(_cierre(COMPLETA + 1, 1, 1)).is_equal(DevolucionDelJefe.MEJORA_BAJA)
	assert_str(_cierre(COMPLETA + 1, 4, 1)).is_equal(
		"Esta vez sí cumpliste con todo. Bien. Continuá por este camino."
	)
	assert_str(_cierre(COMPLETA + 1, 4, 2)).is_equal("Sin comentarios.")
	assert_str(_cierre(COMPLETA, 2, 0)).is_equal("Que no se repita, ok?")
	var una_vez := _cierre(COMPLETA + 1, 3, 0)
	assert_bool(una_vez.begins_with("No duermas con tus responsabilidades")).is_true()
	assert_int(una_vez.count("tus")).is_equal(1)


func test_los_cuatro_bordes_de_la_octava() -> void:  # AC-EMP-058
	var tropiezos := (
		"Mirá, hubo un par de veces que la pifiaste, pero como soy generoso, te voy a dar el "
		+ "puesto igual. No aflojes. Desde ahora, espero que des lo mejor de vos."
	)
	assert_bool(_cierre(8, 2, 0).begins_with("Bueno, más allá de alguna que otra cosita")).is_true()
	assert_str(_cierre(8, 3, 0)).is_equal(tropiezos)
	assert_str(_cierre(8, 4, 0)).is_equal(tropiezos)
	assert_bool(_cierre(8, 5, 0).begins_with("Honestamente, solo puedo concluir")).is_true()
	assert_str(_cierre(8, 4, 1)).is_equal(tropiezos)
	var cierres := 0
	var todos: Array[String] = [DevolucionDelJefe.CIERRE_DEL_DESPIDO, DevolucionDelJefe.MEJORA_ALTA]
	for fila: Array in DevolucionDelJefe.CIERRES_DE_LA_ULTIMA:
		todos.append(fila[1])
	for mensaje: String in DevolucionDelJefe.armar(8, 4, _antecedentes({}, {}, 1), [], []):
		if todos.has(mensaje):
			cierres += 1
	assert_int(cierres).is_equal(1)


func test_ningun_numero_y_siempre_saludo_y_cierre() -> void:  # AC-EMP-060
	var prohibidas := RegEx.create_from_string("[0-9]|punto|medio|apercibimiento")
	var saludos := DevolucionDelJefe.SALUDOS
	for jornada: int in range(COMPLETA, DevolucionDelJefe.ULTIMA_JORNADA + 1):
		for medios: int in range(0, 9):
			for noches: int in range(0, 8):
				for n: int in range(1, 9):
					var antecedentes := _antecedentes(
						{T.CAJA: mini(n, 4), T.REGISTRAR: mini(n, 4), T.REPONER: 1, T.LIMPIAR: 2},
						{
							L.PAPEL_EN_EL_INODORO: n,
							L.OBJETO_TIRADO: n,
							L.OBJETO_AFUERA: n,
							L.LOCAL_DESORDENADO: n
						},
						noches
					)
					var mensajes := DevolucionDelJefe.armar(
						jornada,
						medios,
						antecedentes,
						[T.CAJA, T.REGISTRAR, T.REPONER, T.LIMPIAR, T.SACAR_LA_BASURA],
						[
							L.LOCAL_DESORDENADO,
							L.OBJETO_AFUERA,
							L.PAPEL_EN_EL_INODORO,
							L.OBJETO_TIRADO
						]
					)
					assert_bool(saludos.has(mensajes[0])).is_true()
					assert_int(mensajes.size()).is_equal(
						11 if DevolucionDelJefe.PARTICULARES.has(jornada) else 10
					)
					for mensaje: String in mensajes:
						assert_bool(saludos.has(mensaje) and mensaje != mensajes[0]).is_false()
						assert_object(prohibidas.search(mensaje.to_lower())).is_null()
						assert_str(mensaje).is_equal(mensaje.strip_edges(false, true))
				var sin_nada := DevolucionDelJefe.armar(
					jornada, medios, _antecedentes({}, {}, noches), [], []
				)
				assert_int(sin_nada.size()).is_equal(2)


func test_el_despido_en_la_primera_noche_completa() -> void:  # AC-EMP-061
	var papel: Array[L] = [L.PAPEL_EN_EL_INODORO]
	var partida := _partida_de_la_noche(COMPLETA, _tipos_de(COMPLETA), papel, 7)
	assert_int(partida.medios()).is_equal(4 * M)
	var devolucion := DevolucionDelJefe.new(COMPLETA, partida)
	assert_array(devolucion.mensajes()).is_equal(
		["Che", DevolucionDelJefe.PAPEL_1, DevolucionDelJefe.CIERRE_DEL_DESPIDO]
	)
	assert_array(devolucion.opciones()).is_equal([DevolucionDelJefe.Opcion.VOLVER_AL_MENU])


func test_el_despido_ordena_las_tareas_y_los_retos() -> void:  # AC-EMP-061
	var todos: Array[L] = [
		L.LOCAL_DESORDENADO, L.OBJETO_AFUERA, L.PAPEL_EN_EL_INODORO, L.OBJETO_TIRADO
	]
	var llamados := {}
	for motivo: L in todos:
		llamados[motivo] = 1
	var mensajes := DevolucionDelJefe.armar(
		COMPLETA,
		4 * M,
		_antecedentes({T.CAJA: 1, T.REPONER: 1}, llamados),
		[T.CAJA, T.REPONER],
		todos
	)
	(
		assert_array(mensajes)
		. is_equal(
			[
				"Che",
				DevolucionDelJefe.TAREAS[T.CAJA][0],
				DevolucionDelJefe.TAREAS[T.REPONER][0],
				DevolucionDelJefe.PAPEL_1,
				DevolucionDelJefe.BASURA[0],
				DevolucionDelJefe.AFUERA[0],
				DevolucionDelJefe.DESORDEN[0],
				DevolucionDelJefe.CIERRE_DEL_DESPIDO,
			]
		)
	)


func test_la_prueba_perdida_termina_con_el_mensaje_del_despido() -> void:  # AC-EMP-090
	var todo: Array[T] = [T.REGISTRAR, T.REPONER]
	var tercera := ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA - 1
	var perdida := CondicionesDelJefeTest.cerrar_la_prueba([[2, todo], [2, todo], [0, [T.LIMPIAR]]])
	assert_int(perdida.final()).is_equal(Partida.Final.DESPEDIDO)
	assert_int(perdida.jornada()).is_equal(tercera)
	var devolucion := DevolucionDelJefe.new(tercera, perdida)
	var despido := (
		"No, no, no. Flaco, no te puedo tomar como empleado si trabajás a medias. Un par de "
		+ "errores los puedo dejar pasar, pero si se repite todos los días...\n\nHasta acá "
		+ "llegó mi paciencia. Suerte consiguiendo otro trabajo."
	)
	assert_array(devolucion.mensajes()).is_equal([despido])
	assert_array(devolucion.opciones()).is_equal([DevolucionDelJefe.Opcion.VOLVER_AL_MENU])
	assert_object(perdida.abrir_la_jornada()).is_null()
	var textos_de_la_tercera: Array[String] = []
	for mensaje: Mensaje in perdida.devoluciones_del_jefe():
		if mensaje.jornada == tercera:
			textos_de_la_tercera.append(mensaje.texto)
	assert_array(textos_de_la_tercera).is_equal([despido])
	var redimida := CondicionesDelJefeTest.cerrar_la_prueba([[2, todo], [2, todo], [0, []]])
	assert_bool(redimida.terminada()).is_false()
	assert_array(DevolucionDelJefe.new(tercera, redimida).mensajes()).not_contains(
		[DevolucionDelJefe.DESPIDO_DE_LA_PRUEBA]
	)


func test_la_partida_en_curso_ofrece_solo_continuar() -> void:  # AC-EMP-016
	var en_curso := _partida_de_la_noche(COMPLETA, [], [])
	assert_bool(en_curso.terminada()).is_false()
	assert_array(DevolucionDelJefe.new(COMPLETA, en_curso).opciones()).is_equal(
		[DevolucionDelJefe.Opcion.CONTINUAR]
	)


func test_un_mensaje_mas_por_segundo() -> void:  # AC-EMP-062
	var esperado := {0.0: 1, 0.99: 1, 1.0: 2, 3.0: 4, 10.0: 4}
	for transcurrido: float in esperado:
		assert_int(DevolucionDelJefe.a_la_vista(transcurrido, 4)).is_equal(esperado[transcurrido])


func test_los_retos_eligen_la_repeticion_y_el_despido() -> void:  # AC-EMP-060
	var repeticiones: Dictionary[L, Array] = {
		L.PAPEL_EN_EL_INODORO:
		[
			"El baño se tapó.",
			"Se tapó el baño de nuevo.",
			"Dejá de tirar papel",
			"Dejá de tirar papel",
			"Dejá de tirar papel"
		],
		L.OBJETO_TIRADO:
		[
			"Puede ser que hayas",
			"El contenedor de basura es",
			"Una vez más tuve que sacar",
			"Una vez más tuve que sacar",
			"Una vez más tuve que sacar"
		],
		L.OBJETO_AFUERA:
		[
			"Puedo saber por qué",
			"Ya es la segunda vez",
			"En serio, si sigue apareciendo",
			"BASTA DE TIRAR COSAS",
			"A esta altura del partido"
		],
		L.LOCAL_DESORDENADO:
		[
			"Más allá de cumplir",
			"Dejá las cosas donde corresponde",
			"Me parece que no está",
			"Y si esta vez dejás",
			"Realmente me sorprende"
		],
	}
	for motivo: L in repeticiones:
		for indice: int in 5:
			var cuentas := _antecedentes({}, {motivo: indice + 1})
			var mensajes := DevolucionDelJefe.armar(4, 7, cuentas, [], [motivo])
			assert_bool(mensajes[1].begins_with(repeticiones[motivo][indice])).is_true()
	var despedido := 4 * M
	var papel := DevolucionDelJefe.armar(
		4, despedido, _antecedentes({}, {L.PAPEL_EN_EL_INODORO: 3}), [], [L.PAPEL_EN_EL_INODORO]
	)
	assert_bool(papel[1].begins_with("Una vez más tapaste el baño")).is_true()
	var desorden := DevolucionDelJefe.armar(
		4, despedido, _antecedentes({}, {L.LOCAL_DESORDENADO: 2}), [], [L.LOCAL_DESORDENADO]
	)
	assert_bool(desorden[1].begins_with("Realmente me sorprende")).is_true()


func test_el_saludo_cambia_en_cada_umbral() -> void:  # AC-EMP-060
	var esperados := [
		"Buen día!",
		"Buen día!",
		"Buenas",
		"Buenas",
		"Hola",
		"Hola",
		"Buenos días...",
		"Buenos días...",
		"Che"
	]
	for medios: int in esperados.size():
		assert_str(DevolucionDelJefe.armar(COMPLETA, medios, _antecedentes(), [], [])[0]).is_equal(
			esperados[medios]
		)


func test_el_impecable_de_las_noches_del_medio() -> void:  # AC-EMP-073
	var fichas: Array[String] = [
		"Seguiste todas mis instrucciones al pie de la letra. Excelente. Seguí así.",
		"Nuevamente, todo en orden. Seguí así!",
		"Sin comentarios por mi parte. Dale para adelante.",
		"La jornada cerró cuadrada, como de costumbre. Excelente trabajo.",
	]
	for indice: int in fichas.size():
		var cierre := _cierre(COMPLETA + indice, 0, 0)
		assert_str(cierre).is_equal(fichas[indice])
	assert_array(DevolucionDelJefe.CIERRES_IMPECABLES.keys()).contains_exactly(
		range(COMPLETA, COMPLETA + fichas.size())
	)
	(
		assert_str(_cierre(DevolucionDelJefe.ULTIMA_JORNADA, 0, 0))
		. is_equal(
			(
				"La verdad es que estoy impresionado. No hizo falta corregirte ni una sola cosa "
				+ "en las cinco noches. Un trabajo excepcional. Va a ser un placer tenerte trabajando acá."
			)
		)
	)


func test_los_retos_mas_alla_de_la_ficha() -> void:  # AC-EMP-074
	var retos := {
		L.PAPEL_EN_EL_INODORO: DevolucionDelJefe.PAPEL_MAS,
		L.OBJETO_AFUERA: DevolucionDelJefe.AFUERA.back(),
		L.LOCAL_DESORDENADO: DevolucionDelJefe.DESORDEN_SIN_REMEDIO,
	}
	for n: int in [6, 8]:
		for motivo: L in retos:
			var mensajes := DevolucionDelJefe.armar(
				8, 2, _antecedentes({}, {motivo: n}), [], [motivo]
			)
			assert_str(mensajes[1]).is_equal(retos[motivo])
	var basura := DevolucionDelJefe.armar(
		8, 2, _antecedentes({}, {L.OBJETO_TIRADO: 6}), [], [L.OBJETO_TIRADO]
	)
	assert_str(basura[1]).is_equal(DevolucionDelJefe.BASURA.back())


func _con_la_basura_sin_cumplir(jornada: int) -> Array[T]:
	var cumplidas := _tipos_de(jornada)
	cumplidas.erase(T.SACAR_LA_BASURA)
	return cumplidas


func test_una_bolsa_afuera_cambia_la_tarea_5_de_la_jornada_5() -> void:  # AC-EMP-096
	var segunda := COMPLETA + 1
	var partida := _partida_de_la_noche(segunda, _con_la_basura_sin_cumplir(segunda), [], 0, true)
	var mensajes := DevolucionDelJefe.new(segunda, partida).mensajes()
	var ventana: String = DevolucionDelJefe.PARTICULARES_CON_BOLSA_AFUERA[segunda]
	assert_int(mensajes.count(ventana)).is_equal(1)
	assert_array(mensajes).not_contains([DevolucionDelJefe.PARTICULARES[segunda]])
	assert_int(mensajes.size()).is_equal(3)


func test_sin_bolsa_afuera_la_tarea_5_de_la_jornada_5_sigue_igual() -> void:  # AC-EMP-096
	var segunda := COMPLETA + 1
	var partida := _partida_de_la_noche(segunda, _con_la_basura_sin_cumplir(segunda), [])
	var mensajes := DevolucionDelJefe.new(segunda, partida).mensajes()
	assert_int(mensajes.count(DevolucionDelJefe.PARTICULARES[segunda])).is_equal(1)
	assert_array(mensajes).not_contains([DevolucionDelJefe.PARTICULARES_CON_BOLSA_AFUERA[segunda]])


func test_una_bolsa_que_volvio_al_contenedor_no_deja_tarea_5() -> void:  # AC-EMP-096
	var segunda := COMPLETA + 1
	var partida := _partida_de_la_noche(segunda, _tipos_de(segunda), [])
	var mensajes := DevolucionDelJefe.new(segunda, partida).mensajes()
	assert_int(mensajes.size()).is_equal(2)
	assert_array(mensajes).not_contains([DevolucionDelJefe.PARTICULARES[segunda]])
	assert_array(mensajes).not_contains([DevolucionDelJefe.PARTICULARES_CON_BOLSA_AFUERA[segunda]])


func test_la_bolsa_afuera_solo_cambia_la_jornada_5() -> void:  # AC-EMP-096
	var ventana: String = DevolucionDelJefe.PARTICULARES_CON_BOLSA_AFUERA[COMPLETA + 1]
	for jornada: int in [COMPLETA, COMPLETA + 2, COMPLETA + 3]:
		var partida := _partida_de_la_noche(jornada, [], [], 0, true)
		assert_array(DevolucionDelJefe.new(jornada, partida).mensajes()).not_contains([ventana])


func test_el_texto_de_la_ventana_solo_existe_en_la_jornada_5() -> void:  # AC-EMP-096
	assert_array(DevolucionDelJefe.PARTICULARES_CON_BOLSA_AFUERA.keys()).contains_exactly(
		[COMPLETA + 1]
	)
