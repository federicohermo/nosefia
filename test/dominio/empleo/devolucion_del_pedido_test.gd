## La Tarea 5 de la jornada del pedido al proveedor: qué dice Enrique según cómo salió el pedido
## (BR-EMP-047).
extends GdUnitTestSuite

const PEDIDO := ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA + 3
const T := Tarea.Tipo


func _antecedentes() -> Antecedentes:
	return (
		Antecedentes
		. desde(
			{
				Antecedentes.CLAVE_DE_FALLAS: {},
				Antecedentes.CLAVE_DE_LLAMADOS: {},
				Antecedentes.CLAVE_DE_NOCHES_SIN_SUMAR: 0,
			}
		)
	)


## La devolución de la noche con el pedido sin cumplir, o cumplido si `sin_cumplir` va vacío.
func _devolucion(jornada: int, sin_cumplir: Array[T], equivocado: bool = false) -> Array[String]:
	var llamados: Array[Partida.Llamado] = []
	var desorden: Array[ReglasDelCierre.Clase] = []
	return DevolucionDelJefe.armar(
		jornada,
		0,
		_antecedentes(),
		sin_cumplir,
		llamados,
		false,
		false,
		desorden,
		false,
		false,
		equivocado
	)


func test_sin_pedido_o_sin_wifi_tarea_5_reclama_el_pedido() -> void:  # AC-EMP-115
	var mensajes := _devolucion(PEDIDO, [T.PEDIR_AL_PROVEEDOR])
	assert_array(mensajes).contains(DevolucionDelJefe.PEDIDO_SIN_HACER)
	assert_array(mensajes).not_contains(DevolucionDelJefe.PEDIDO_EQUIVOCADO)
	var partida := Partida.desde({"jornada": PEDIDO, "medios": 0})
	partida.abrir_la_jornada()
	partida.cerrar_la_jornada(0)
	assert_array(DevolucionDelJefe.new(PEDIDO, partida).mensajes()).contains(
		DevolucionDelJefe.PEDIDO_SIN_HACER
	)


func test_un_pedido_con_wifi_y_equivocado_dice_el_otro_texto() -> void:  # AC-EMP-116
	var mensajes := _devolucion(PEDIDO, [T.PEDIR_AL_PROVEEDOR], true)
	assert_array(mensajes).contains(DevolucionDelJefe.PEDIDO_EQUIVOCADO)
	assert_array(mensajes).not_contains(DevolucionDelJefe.PEDIDO_SIN_HACER)
	var partida := Partida.desde({"jornada": PEDIDO, "medios": 0})
	partida.abrir_la_jornada()
	partida.pedido_equivocado = true
	partida.cerrar_la_jornada(0)
	var textos := DevolucionDelJefe.new(PEDIDO, partida).mensajes()
	assert_array(textos).contains(DevolucionDelJefe.PEDIDO_EQUIVOCADO)
	assert_array(textos).not_contains(DevolucionDelJefe.PEDIDO_SIN_HACER)


func test_cumplido_o_en_otra_jornada_no_hay_ninguno_de_los_dos_textos() -> void:  # AC-EMP-117
	var cumplido := _devolucion(PEDIDO, [])
	assert_array(cumplido).not_contains(DevolucionDelJefe.PEDIDO_SIN_HACER)
	assert_array(cumplido).not_contains(DevolucionDelJefe.PEDIDO_EQUIVOCADO)
	for jornada in range(ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA, PEDIDO + 2):
		if jornada == PEDIDO:
			continue
		var otra := _devolucion(jornada, [T.PEDIR_AL_PROVEEDOR], true)
		assert_array(otra).not_contains(DevolucionDelJefe.PEDIDO_SIN_HACER)
		assert_array(otra).not_contains(DevolucionDelJefe.PEDIDO_EQUIVOCADO)
