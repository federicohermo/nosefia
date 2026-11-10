## Cuánto se corre: el multiplicador de la postura y de lo que se lleva. La acción y la escena se
## prueban en `correr_test.gd` de `test/escenas/`.
extends GdUnitTestSuite

const CAJA_DE_REPOSICION := preload("res://src/dominio/almacen/caja_de_reposicion.tres")
const CAJA_CHICA := preload("res://src/dominio/almacen/caja_de_fideos.tres")
const LATA := preload("res://src/dominio/almacen/lata_de_tomate.tres")
const BOLSA_DE_BASURA := preload("res://src/dominio/almacen/bolsa_de_basura_1.tres")
const SENSIBILIDAD := 0.01
const CUADRO := 1.0 / 60.0


func _control() -> ControlDelJugador:
	var mirada := Mirada.new(
		SENSIBILIDAD, ReglasDelJugador.PITCH_MINIMO, ReglasDelJugador.PITCH_MAXIMO
	)
	return ControlDelJugador.new(mirada, ReglasDelJugador.VELOCIDAD_DE_CAMINATA)


func test_correr_camina_a_la_caminata_por_el_multiplicador() -> void:  # AC-PLY-192
	var control := _control()
	var corriendo := (
		ReglasDelJugador.VELOCIDAD_DE_CAMINATA * ReglasDelJugador.MULTIPLICADOR_DE_CORRER
	)
	var adelante := control.velocidad(Vector2(0.0, 1.0), true)
	assert_float(adelante.length()).is_equal_approx(corriendo, 1e-4)
	assert_vector(adelante.normalized()).is_equal_approx(Vector3.FORWARD, Vector3.ONE * 1e-4)
	assert_float(control.velocidad(Vector2(1.0, 1.0), true).length()).is_equal_approx(
		corriendo, 1e-4
	)
	assert_float(control.velocidad(Vector2(0.0, 1.0), false).length()).is_equal_approx(
		ReglasDelJugador.VELOCIDAD_DE_CAMINATA, 1e-4
	)
	assert_vector(control.velocidad(Vector2.ZERO, true)).is_equal(Vector3.ZERO)


## La velocidad corriendo adelante con lo que se pide en la mano.
func _corriendo(
	control: ControlDelJugador, mano: StringName, con_agua := false, grande := false
) -> float:
	return control.velocidad(Vector2(0.0, 1.0), true, mano, con_agua, grande).length()


func test_correr_con_una_caja_grande_o_el_balde_con_agua_acelera_poco() -> void:  # AC-PLY-193
	var control := _control()
	var caminando := ReglasDelJugador.VELOCIDAD_DE_CAMINATA
	var pesados := {
		"caja grande": _corriendo(control, CAJA_DE_REPOSICION.id, false, true),
		"balde con agua": _corriendo(control, ReglasDeLaLimpieza.ID_DEL_BALDE, true),
	}
	for cual: String in pesados:
		assert_float(pesados[cual]).is_equal_approx(
			caminando * ReglasDelJugador.MULTIPLICADOR_DE_CORRER_CON_PESO, 1e-4
		)
	(
		assert_float(
			control.velocidad(Vector2(0.0, 1.0), false, CAJA_DE_REPOSICION.id, false, true).length()
		)
		. is_equal_approx(caminando, 1e-4)
	)


func test_correr_con_un_bidon_o_una_caja_pequena_acelera_algo_menos() -> void:  # AC-PLY-193
	var control := _control()
	var caminando := ReglasDelJugador.VELOCIDAD_DE_CAMINATA
	var intermedios: Array[float] = [
		_corriendo(control, CAJA_DE_REPOSICION.id, false, false),
		_corriendo(control, CAJA_CHICA.id),
	]
	for jabon: StringName in ReglasDeLaLimpieza.JABONES:
		intermedios.append(_corriendo(control, jabon))
	for corriendo in intermedios:
		assert_float(corriendo).is_equal_approx(
			caminando * ReglasDelJugador.MULTIPLICADOR_DE_CORRER_INTERMEDIO, 1e-4
		)
		assert_float(corriendo).is_greater(
			caminando * ReglasDelJugador.MULTIPLICADOR_DE_CORRER_CON_PESO
		)
		assert_float(corriendo).is_less(caminando * ReglasDelJugador.MULTIPLICADOR_DE_CORRER)


func test_correr_con_el_balde_vacio_o_lo_liviano_no_frena() -> void:  # AC-PLY-193
	var control := _control()
	var libre := ReglasDelJugador.VELOCIDAD_DE_CAMINATA * ReglasDelJugador.MULTIPLICADOR_DE_CORRER
	assert_float(_corriendo(control, ReglasDeLaLimpieza.ID_DEL_BALDE)).is_equal_approx(libre, 1e-4)
	var livianos: Array[StringName] = [
		ReglasDeLaLimpieza.ID_DE_LA_MOPA,
		BOLSA_DE_BASURA.id,
		LATA.id,
		UnidadDeProducto.new(Catalogo.todos()[0]).id,
		Partida.PALANCA,
		Partida.LLAVE,
		Ticket.ID,
	]
	for liviano: StringName in livianos:
		# El agua del balde y el tamaño de una caja no son de lo que no es ni balde ni caja.
		for hecho: bool in [false, true]:
			assert_float(_corriendo(control, liviano, hecho, hecho)).is_equal_approx(libre, 1e-4)


func test_agachado_correr_acelera_poco_y_una_sola_vez() -> void:  # AC-PLY-194
	var control := _control()
	_asentar(control, true)
	var agachado := ReglasDelJugador.VELOCIDAD_AGACHADO
	var corriendo := control.velocidad(Vector2(0.0, 1.0), true).length()
	assert_float(corriendo).is_equal_approx(
		agachado * ReglasDelJugador.MULTIPLICADOR_DE_CORRER_CON_PESO, 1e-4
	)
	assert_float(corriendo).is_greater(agachado)
	assert_float(corriendo).is_less(
		ReglasDelJugador.VELOCIDAD_DE_CAMINATA * ReglasDelJugador.MULTIPLICADOR_DE_CORRER
	)
	(
		assert_float(
			control.velocidad(Vector2(0.0, 1.0), true, CAJA_DE_REPOSICION.id, false, true).length()
		)
		. is_equal_approx(corriendo, 1e-4)
	)


func test_correr_no_se_cansa() -> void:  # AC-PLY-195
	var control := _control()
	var primero := control.velocidad(Vector2(0.0, 1.0), true).length()
	var ultimo := primero
	for cuadro in roundi(600.0 / CUADRO):
		ultimo = control.velocidad(Vector2(0.0, 1.0), true).length()
	assert_float(ultimo).is_equal(primero)


func test_suspendido_correr_no_mueve_y_al_reanudar_corre() -> void:  # AC-PLY-196
	var control := _control()
	control.suspender()
	assert_vector(control.velocidad(Vector2(0.0, 1.0), true)).is_equal(Vector3.ZERO)
	control.reanudar()
	assert_float(control.velocidad(Vector2(0.0, 1.0), true).length()).is_equal_approx(
		ReglasDelJugador.VELOCIDAD_DE_CAMINATA * ReglasDelJugador.MULTIPLICADOR_DE_CORRER, 1e-4
	)


## La altura con la acción como esté, dejando pasar más que lo que dura el agache.
func _asentar(control: ControlDelJugador, agachando: bool) -> float:
	return control.altura_de_la_vista(agachando, ReglasDelJugador.DURACION_DEL_AGACHE * 2.0)
