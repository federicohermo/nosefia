## La E con las manos vacías piensa: pide el subtítulo de lo que se mira, sin examen.
##
## Los casos viejos de `Examen` viven en su espejo, que está a un método del tope de `gdlint`.
## Éstos son los del pensamiento. El texto lo resuelve la cáscara, que es la que sabe qué se
## mira; acá se afirma qué hace `Examen` con él.
extends GdUnitTestSuite

const INODORO := (
	"Un inodoro. Enrique me pidió encarecidamente" + " que no tire papel en él, porque se tapa."
)
const BOLSA := "Una bolsa de basura."


func _agarre() -> Agarre:
	var agarre: Agarre = auto_free(Agarre.new())
	agarre.punto_de_carga = auto_free(Node3D.new())
	agarre.punto_de_soltado = auto_free(Node3D.new())
	agarre.punto_de_respaldo = auto_free(Node3D.new())
	return agarre


func _examen(agarre: Agarre) -> Examen:
	var examen: Examen = auto_free(Examen.new())
	examen.agarre = agarre
	examen.punto_de_examen = auto_free(Node3D.new())
	return examen


func _cuerpo() -> RigidBody3D:
	var padre: Node3D = auto_free(Node3D.new())
	var cuerpo := RigidBody3D.new()
	padre.add_child(cuerpo)
	return cuerpo


## Cuenta lo que avisa el examen, para afirmar que el pensamiento no lo toca.
class Avisos:
	var pensamientos: Array[String] = []
	var iniciados: int = 0
	var terminados: int = 0
	var revelados: Array[ObjetoDelAlmacen] = []

	func _init(examen: Examen) -> void:
		examen.pensamiento_pedido.connect(func(texto: String) -> void: pensamientos.append(texto))
		examen.examen_iniciado.connect(func(_nodo: Node3D) -> void: iniciados += 1)
		examen.examen_terminado.connect(func() -> void: terminados += 1)
		examen.objeto_revelado.connect(
			func(datos: ObjetoDelAlmacen, _nuevo: bool) -> void: revelados.append(datos)
		)


func test_lo_fijo_con_texto_se_piensa_sin_examen() -> void:  # AC-SUB-002
	var agarre := _agarre()
	var examen := _examen(agarre)
	var avisos := Avisos.new(examen)
	var linea := Subtitulo.new()
	examen.pensamiento_pedido.connect(linea.pensar)
	examen.alternar(null, INODORO)
	assert_array(avisos.pensamientos).contains_exactly([INODORO])
	assert_str(linea.texto()).is_equal(INODORO)
	assert_bool(examen.esta_examinando()).is_false()
	assert_int(avisos.iniciados).is_zero()
	assert_int(avisos.terminados).is_zero()
	assert_array(avisos.revelados).is_empty()
	assert_object(agarre.manos().sostenido()).is_null()


func test_un_levantable_con_texto_se_piensa_y_no_se_registra() -> void:  # AC-SUB-002, AC-SUB-010
	var agarre := _agarre()
	var examen := _examen(agarre)
	var avisos := Avisos.new(examen)
	var bolsa := load("res://src/dominio/almacen/bolsa_de_basura_1.tres") as ObjetoDelAlmacen
	examen.alternar(bolsa, bolsa.texto_al_examinar())
	assert_array(avisos.pensamientos).contains_exactly([BOLSA])
	assert_int(avisos.iniciados).is_zero()
	assert_array(avisos.revelados).is_empty()
	assert_int(examen.hallazgos().cantidad()).is_zero()


func test_sin_texto_o_sin_nada_en_la_mira_no_se_pide_nada() -> void:  # AC-SUB-003
	var examen := _examen(_agarre())
	var avisos := Avisos.new(examen)
	var linea := Subtitulo.new()
	examen.pensamiento_pedido.connect(linea.pensar)
	examen.alternar()
	examen.alternar(null, "")
	var sin_texto := ObjetoDelAlmacen.new()
	sin_texto.levantable = false
	examen.alternar(sin_texto, "")
	assert_array(avisos.pensamientos).is_empty()
	assert_str(linea.texto()).is_empty()
	# Un pensamiento que se ve sigue su curso: el gesto sin texto no lo reinicia.
	linea.pensar(BOLSA)
	linea.avanzar(1.0)
	examen.alternar(null, "")
	linea.avanzar(1.8)
	assert_str(linea.texto()).is_empty()


func test_lo_fijo_con_revelacion_se_publica_y_el_subtitulo_sale_igual() -> void:  # AC-SUB-010
	var examen := _examen(_agarre())
	var avisos := Avisos.new(examen)
	var revelacion := Revelacion.new()
	revelacion.texto = "La cerradura es nueva y el marco no."
	var puerta := ObjetoDelAlmacen.new()
	puerta.id = &"puerta"
	puerta.levantable = false
	puerta.revelacion = revelacion
	examen.alternar(puerta, "Un portón que da a la calle.")
	assert_array(avisos.revelados).contains_exactly([puerta])
	assert_array(avisos.pensamientos).contains_exactly(["Un portón que da a la calle."])
	assert_int(avisos.iniciados).is_zero()


func test_repetir_el_gesto_pide_el_pensamiento_otra_vez() -> void:  # AC-SUB-006
	var examen := _examen(_agarre())
	var avisos := Avisos.new(examen)
	var linea := Subtitulo.new()
	examen.pensamiento_pedido.connect(linea.pensar)
	examen.alternar(null, BOLSA)
	linea.avanzar(2.0)
	examen.alternar(null, BOLSA)
	assert_int(avisos.pensamientos.size()).is_equal(2)
	assert_float(linea.opacidad()).is_equal(1.0)
	linea.avanzar(2.8)
	assert_str(linea.texto()).is_empty()


func test_con_algo_en_la_mano_se_examina_y_no_se_piensa() -> void:  # AC-SUB-007
	var agarre := _agarre()
	var examen := _examen(agarre)
	var avisos := Avisos.new(examen)
	var mopa := load("res://src/dominio/almacen/mopa.tres") as ObjetoDelAlmacen
	agarre.pedir_agarrar(mopa, _cuerpo())
	examen.alternar(null, INODORO)
	assert_bool(examen.esta_examinando()).is_true()
	assert_int(avisos.iniciados).is_equal(1)
	assert_array(avisos.pensamientos).is_empty()
	examen.alternar(null, INODORO)
	assert_int(avisos.terminados).is_equal(1)
	assert_array(avisos.pensamientos).is_empty()
