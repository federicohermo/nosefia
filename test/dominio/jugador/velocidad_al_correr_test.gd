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


func test_correr_con_una_caja_grande_o_el_balde_con_agua_acelera_poco() -> void:  # AC-PLY-193
	var control := _control()
	var caminando := ReglasDelJugador.VELOCIDAD_DE_CAMINATA
	var adelante := Vector2(0.0, 1.0)
	var con_peso := {
		"caja grande": [CAJA_DE_REPOSICION.id, false, true],
		"balde con agua": [ReglasDeLaLimpieza.ID_DEL_BALDE, true, false],
	}
	for cual: String in con_peso:
		var mano: Array = con_peso[cual]
		var corriendo := control.velocidad(adelante, true, mano[0], mano[1], mano[2]).length()
		assert_float(corriendo).is_equal_approx(
			caminando * ReglasDelJugador.MULTIPLICADOR_DE_CORRER_CON_PESO, 1e-4
		)
		assert_float(corriendo).is_greater(caminando)
		assert_float(corriendo).is_less(caminando * ReglasDelJugador.MULTIPLICADOR_DE_CORRER)
		(
			assert_float(control.velocidad(adelante, false, mano[0], mano[1], mano[2]).length())
			. is_equal_approx(caminando, 1e-4)
		)


func test_correr_con_el_balde_vacio_o_una_caja_chica_no_frena() -> void:  # AC-PLY-193
	var control := _control()
	var libre := ReglasDelJugador.VELOCIDAD_DE_CAMINATA * ReglasDelJugador.MULTIPLICADOR_DE_CORRER
	var adelante := Vector2(0.0, 1.0)
	(
		assert_float(
			(
				control
				. velocidad(adelante, true, ReglasDeLaLimpieza.ID_DEL_BALDE, false, false)
				. length()
			)
		)
		. is_equal_approx(libre, 1e-4)
	)
	(
		assert_float(
			control.velocidad(adelante, true, CAJA_DE_REPOSICION.id, false, false).length()
		)
		. is_equal_approx(libre, 1e-4)
	)


func test_correr_con_lo_suelto_corre_como_con_la_mano_vacia() -> void:  # AC-PLY-193
	var control := _control()
	var libre := ReglasDelJugador.VELOCIDAD_DE_CAMINATA * ReglasDelJugador.MULTIPLICADOR_DE_CORRER
	var livianos: Array[StringName] = [
		ReglasDeLaLimpieza.ID_DE_LA_MOPA,
		BOLSA_DE_BASURA.id,
		CAJA_CHICA.id,
		LATA.id,
		UnidadDeProducto.new(Catalogo.todos()[0]).id,
		Partida.PALANCA,
		Partida.LLAVE,
		Ticket.ID,
	]
	livianos.append_array(ReglasDeLaLimpieza.JABONES.keys())
	for liviano: StringName in livianos:
		# El agua del balde y el tamaño de una caja no son de lo que no es ni balde ni caja.
		for hecho: bool in [false, true]:
			(
				assert_float(
					control.velocidad(Vector2(0.0, 1.0), true, liviano, hecho, hecho).length()
				)
				. is_equal_approx(libre, 1e-4)
			)


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
