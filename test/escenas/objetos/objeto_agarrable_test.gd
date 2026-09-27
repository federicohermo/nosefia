## El contrato de «se puede interactuar con esto», que no es un tipo sino dos cosas sueltas: un
## grupo de Godot y un nombre de método.
##
## Tiene que ser así y no una clase base: `sistemas/` no puede nombrar un `class_name` de
## `escenas/` —el gate de capas lo caza sin que haya un solo `preload`— y `dominio/` tampoco,
## porque lo que se agarra es un `Node3D`. O sea que nadie puede escribir el contrato como tipo,
## y entonces lo único que lo sostiene es este test.
##
## **Los casos del contrato instancian la escena y NO la entran al árbol**, como en
## `jugador_test.gd`: alcanza para leer los grupos y los métodos, y está medido que
## `is_in_group` contesta bien afuera del árbol. Uno sí la entra y lo explica adentro: el de la
## interpolación, que pide lo que se dibuja.
extends GdUnitTestSuite

const ReglasDeLosObjetos := preload("res://src/dominio/almacen/reglas_de_los_objetos.gd")
const ReglasDelJugador := preload("res://src/dominio/jugador/reglas_del_jugador.gd")
const ESCENA_DEL_OBJETO := "res://src/escenas/objetos/objeto_agarrable.tscn"


func _objeto() -> Node3D:
	return auto_free(load(ESCENA_DEL_OBJETO).instantiate())


func test_el_objeto_esta_en_el_grupo_que_la_mira_busca() -> void:
	# Sin el grupo, la mira lo enfoca y contesta que no es interactuable: el objeto existe, se
	# ve, y el clic no hace nada. No hay error en ningún lado.
	assert_bool(_objeto().is_in_group(ReglasDelJugador.GRUPO_INTERACTUABLE)).is_true()


func test_el_objeto_responde_al_metodo_que_es_el_contrato() -> void:
	assert_bool(_objeto().has_method(ReglasDeLosObjetos.METODO_INTERACTUAR)).is_true()


func test_interactuar_devuelve_los_datos_de_dominio_del_objeto() -> void:
	# Es la única puerta por la que un `Node3D` de la escena entrega algo que el dominio pueda
	# mirar. Que la escena traiga los datos puestos es lo que hace que instanciarla alcance.
	var objeto := _objeto()
	var datos: Resource = objeto.call(ReglasDeLosObjetos.METODO_INTERACTUAR)
	assert_object(datos).is_not_null()
	assert_str(String(datos.id)).is_not_empty()
	assert_bool(datos.es_levantable()).is_true()


func test_el_objeto_simula_fisica_y_tiene_con_que_chocar() -> void:
	# Sin cuerpo físico no lo toca el rayo de la mira, y sin forma de colisión atraviesa el
	# piso al soltarlo: las dos fallas se ven como «el objeto no está».
	var objeto := _objeto()
	assert_object(objeto).is_instanceof(RigidBody3D)
	var con_forma := false
	for hijo in objeto.get_children():
		if hijo is CollisionShape3D and (hijo as CollisionShape3D).shape != null:
			con_forma = true
	assert_bool(con_forma).is_true()


func test_volver_a_su_lugar_no_dibuja_el_objeto_cruzando_el_almacen() -> void:
	# Este caso entra al árbol, al revés que el resto de la suite. `_lugar_de_origen` se guarda en
	# `_ready()` y la posición interpolada no existe fuera del árbol.
	#
	# Se mira lo que se dibuja y no el `transform`. El `transform` siempre fue correcto. Con la
	# interpolación encendida, el motor dibuja entre el paso anterior y el actual. Medido sin el
	# reseteo: entre 1,8 y 5,8 m de distancia sobre un salto de 10 m, 20 veces de 20.
	var mundo: Node3D = auto_free(Node3D.new())
	add_child(mundo)
	var objeto := _objeto()
	objeto.set("freeze", true)
	mundo.add_child(objeto)
	var origen := objeto.global_transform.origin
	objeto.transform = Transform3D(Basis.IDENTITY, Vector3(12, 3, -7))
	for _paso in 4:
		await get_tree().physics_frame
		await get_tree().process_frame
	objeto.call("volver_a_su_lugar")
	await get_tree().process_frame
	(
		assert_vector(objeto.get_global_transform_interpolated().origin)
		. override_failure_message(
			"el objeto se dibuja viajando: viene de (12, 3, -7) y vuelve a %s" % origen
		)
		. is_equal_approx(origen, Vector3.ONE * 0.001)
	)


func test_cada_contacto_avisa_el_objeto_y_su_rapidez() -> void:
	# Sin el monitoreo de contactos, el cuerpo no emite nada al tocar el piso y soltar queda mudo.
	var objeto := _objeto()
	add_child(objeto)
	assert_bool(objeto.get("contact_monitor")).is_true()
	assert_int(objeto.get("max_contacts_reported")).is_greater(0)
	var avisos := []
	objeto.connect(
		"contacto_recibido",
		func(nodo: Node3D, rapidez: float) -> void: avisos.append([nodo, rapidez])
	)
	objeto.emit_signal("body_entered", auto_free(StaticBody3D.new()))
	assert_int(avisos.size()).is_equal(1)
	assert_object(avisos[0][0]).is_same(objeto)
	assert_float(avisos[0][1]).is_greater_equal(0.0)


func test_las_dos_acciones_del_006_estan_declaradas_en_el_proyecto() -> void:
	# El par de String entre `reglas_de_los_objetos.gd` y la sección `[input]` de
	# `project.godot` no lo verifica nadie más: renombrar la constante sin tocar el proyecto
	# deja el clic y la E sin responder, y el juego arranca igual.
	for accion in [ReglasDeLosObjetos.ACCION_AGARRAR, ReglasDeLosObjetos.ACCION_EXAMINAR]:
		(
			assert_bool(InputMap.has_action(accion))
			. override_failure_message(
				"falta la acción `%s` en la sección [input] de project.godot" % accion
			)
			. is_true()
		)
