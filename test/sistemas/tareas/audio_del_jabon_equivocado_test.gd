## La pasada con el jabón equivocado tiene su propia señal, para que la tabla de sonidos la haga
## sonar sin escuchar todos los rechazos del limpiador.
##
## Se instancia con `auto_free(Limpiador.new())` y se le llama a mano, como en la suite del
## limpiador: sin `_process`, el turno no se mueve.
extends GdUnitTestSuite

const MOPA := ReglasDeLaLimpieza.ID_DE_LA_MOPA
const BALDE := ReglasDeLaLimpieza.ID_DEL_BALDE
const LAVATORIO := ReglasDeLaLimpieza.ID_DEL_LAVATORIO
const INODORO := ReglasDeLaLimpieza.ID_DEL_INODORO

var _equivocadas: Array[PisoDelLocal.Lugar] = []
var _rechazos: Array[ReglasDeLaLimpieza.Resultado] = []


func before_test() -> void:
	_equivocadas = []
	_rechazos = []


func _limpiador() -> Limpiador:
	var obligatorias := Apertura.obligatorias(1)
	var reloj: RelojDelTurno = auto_free(RelojDelTurno.new())
	reloj.arrancar(Turno.new(Reglas.DURACION_DEL_TURNO, obligatorias), obligatorias)
	var limpiador: Limpiador = auto_free(Limpiador.new())
	limpiador.reloj = reloj
	limpiador.pasada_con_jabon_equivocado.connect(
		func(lugar: PisoDelLocal.Lugar) -> void: _equivocadas.append(lugar)
	)
	limpiador.uso_rechazado.connect(
		func(motivo: ReglasDeLaLimpieza.Resultado) -> void: _rechazos.append(motivo)
	)
	limpiador.arrancar(PisoDelLocal.de_la_jornada(ReglasDeLaPartida.PRIMERA_JORNADA))
	return limpiador


## Llena el balde, le echa ese jabón y moja la mopa.
func _preparar(limpiador: Limpiador, jabon: StringName) -> void:
	limpiador.usar(BALDE, INODORO)
	limpiador.usar(BALDE, LAVATORIO)
	limpiador.usar(jabon, BALDE)
	limpiador.usar(MOPA, BALDE)


## El jabón que borra la mancha de ese lugar, o el primero que no la borra.
static func _jabon(limpiador: Limpiador, lugar: PisoDelLocal.Lugar, que_borre: bool) -> StringName:
	var pedida: ReglasDeLaLimpieza.Agua = ReglasDeLaLimpieza.AGUA_QUE_BORRA[
		limpiador.piso().mancha_de(lugar).tipo()
	]
	for jabon: StringName in ReglasDeLaLimpieza.JABONES:
		if (ReglasDeLaLimpieza.JABONES[jabon] == pedida) == que_borre:
			return jabon
	return &""


func test_el_jabon_equivocado_avisa_una_vez_y_conserva_el_rechazo() -> void:
	var limpiador := _limpiador()
	var lugar: PisoDelLocal.Lugar = limpiador.piso().lugares()[0]
	_preparar(limpiador, _jabon(limpiador, lugar, false))
	_rechazos.clear()
	var resultado := limpiador.pasar(MOPA, lugar)
	assert_int(resultado).is_equal(ReglasDeLaLimpieza.Resultado.JABON_EQUIVOCADO)
	assert_array(_equivocadas).is_equal([lugar])
	assert_array(_rechazos).is_equal([ReglasDeLaLimpieza.Resultado.JABON_EQUIVOCADO])
	assert_bool(limpiador.piso().mancha_de(lugar).esta_limpia()).is_false()


func test_la_pasada_que_borra_y_los_otros_rechazos_no_avisan() -> void:
	var limpiador := _limpiador()
	var lugar: PisoDelLocal.Lugar = limpiador.piso().lugares()[0]
	assert_int(limpiador.pasar(MOPA, lugar)).is_equal(ReglasDeLaLimpieza.Resultado.MOPA_SECA)
	limpiador.usar(BALDE, INODORO)
	limpiador.usar(&"bolsa_de_basura_1", BALDE)
	_preparar(limpiador, _jabon(limpiador, lugar, true))
	assert_int(limpiador.pasar(MOPA, lugar)).is_equal(ReglasDeLaLimpieza.Resultado.MANCHA_BORRADA)
	assert_int(limpiador.pasar(MOPA, lugar)).is_equal(ReglasDeLaLimpieza.Resultado.YA_ESTABA_LIMPIA)
	assert_array(_rechazos).is_not_empty()
	assert_array(_equivocadas).is_empty()
