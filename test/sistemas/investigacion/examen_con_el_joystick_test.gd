## Girar lo examinado con el joystick derecho, sin árbol de escena: el equivalente del arrastre del
## mouse.
extends GdUnitTestSuite

const Agarre := preload("res://src/sistemas/marco/agarre.gd")
const Examen := preload("res://src/sistemas/investigacion/examen.gd")
const ObjetoDelAlmacen := preload("res://src/dominio/almacen/objeto_del_almacen.gd")


func _examen(agarre: Node) -> Node:
	var examen: Node = auto_free(Examen.new())
	examen.agarre = agarre
	examen.punto_de_examen = auto_free(Node3D.new())
	return examen


func _agarre() -> Node:
	var agarre: Node = auto_free(Agarre.new())
	agarre.punto_de_carga = auto_free(Node3D.new())
	agarre.punto_de_soltado = auto_free(Node3D.new())
	agarre.punto_de_respaldo = auto_free(Node3D.new())
	return agarre


func _cuerpo() -> RigidBody3D:
	var padre: Node3D = auto_free(Node3D.new())
	var cuerpo := RigidBody3D.new()
	padre.add_child(cuerpo)
	return cuerpo


func _lata() -> Resource:
	var objeto := ObjetoDelAlmacen.new()
	objeto.id = &"lata_de_tomate"
	objeto.nombre = "Lata de tomate"
	return objeto


func test_el_joystick_derecho_gira_lo_examinado_en_proporcion() -> void:  # AC-CFG-029
	var agarre := _agarre()
	var examen := _examen(agarre)
	var cuerpo := _cuerpo()
	agarre.pedir_agarrar(_lata(), cuerpo)
	examen.iniciar()
	var antes := cuerpo.basis
	examen.girar_con_el_joystick(Vector2.RIGHT, 0.25)
	var a_fondo := cuerpo.basis
	assert_bool(a_fondo.is_equal_approx(antes)).is_false()
	cuerpo.basis = antes
	examen.girar_con_el_joystick(Vector2.RIGHT * 0.5, 0.5)
	assert_bool(cuerpo.basis.is_equal_approx(a_fondo)).is_true()


func test_a_inclinacion_cero_lo_examinado_no_gira() -> void:  # AC-CFG-029
	var agarre := _agarre()
	var examen := _examen(agarre)
	var cuerpo := _cuerpo()
	agarre.pedir_agarrar(_lata(), cuerpo)
	examen.iniciar()
	var antes := cuerpo.basis
	examen.girar_con_el_joystick(Vector2.ZERO, 1.0)
	assert_bool(cuerpo.basis.is_equal_approx(antes)).is_true()


func test_girar_con_el_joystick_sin_examinar_nada_no_rompe() -> void:  # AC-CFG-029
	var examen := _examen(_agarre())
	examen.girar_con_el_joystick(Vector2.RIGHT, 0.5)
	assert_bool(examen.esta_examinando()).is_false()
