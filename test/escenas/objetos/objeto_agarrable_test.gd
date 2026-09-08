## El contrato de «se puede interactuar con esto», que no es un tipo sino dos cosas sueltas: un
## grupo de Godot y un nombre de método.
##
## Tiene que ser así y no una clase base: `sistemas/` no puede nombrar un `class_name` de
## `escenas/` —el gate de capas lo caza sin que haya un solo `preload`— y `dominio/` tampoco,
## porque lo que se agarra es un `Node3D`. O sea que nadie puede escribir el contrato como tipo,
## y entonces lo único que lo sostiene es este test.
##
## **La escena se instancia y NO se entra al árbol**, como en `jugador_test.gd`: alcanza para
## leer los grupos y los métodos, y está medido que `is_in_group` contesta bien afuera del árbol.
extends GdUnitTestSuite

const ReglasDeLosObjetos := preload("res://src/dominio/almacen/reglas_de_los_objetos.gd")
const ReglasDelJugador := preload("res://src/dominio/jugador/reglas_del_jugador.gd")
const ESCENA_DEL_OBJETO := "res://src/escenas/objetos/objeto_agarrable.tscn"


func _objeto() -> Node3D:
	return auto_free(load(ESCENA_DEL_OBJETO).instantiate())


func test_el_objeto_esta_en_el_grupo_que_la_mira_busca() -> void:  # 006-AC10
	# Sin el grupo, la mira lo enfoca y contesta que no es interactuable: el objeto existe, se
	# ve, y el clic no hace nada. No hay error en ningún lado.
	assert_bool(_objeto().is_in_group(ReglasDelJugador.GRUPO_INTERACTUABLE)).is_true()


func test_el_objeto_responde_al_metodo_que_es_el_contrato() -> void:  # 006-AC10
	assert_bool(_objeto().has_method(ReglasDeLosObjetos.METODO_INTERACTUAR)).is_true()


func test_interactuar_devuelve_los_datos_de_dominio_del_objeto() -> void:  # 006-AC10
	# Es la única puerta por la que un `Node3D` de la escena entrega algo que el dominio pueda
	# mirar. Que la escena traiga los datos puestos es lo que hace que instanciarla alcance.
	var objeto := _objeto()
	var datos: Resource = objeto.call(ReglasDeLosObjetos.METODO_INTERACTUAR)
	assert_object(datos).is_not_null()
	assert_str(String(datos.id)).is_not_empty()
	assert_bool(datos.es_levantable()).is_true()


func test_el_objeto_simula_fisica_y_tiene_con_que_chocar() -> void:  # 006-AC10
	# Sin cuerpo físico no lo toca el rayo de la mira, y sin forma de colisión atraviesa el
	# piso al soltarlo: las dos fallas se ven como «el objeto no está».
	var objeto := _objeto()
	assert_object(objeto).is_instanceof(RigidBody3D)
	var con_forma := false
	for hijo in objeto.get_children():
		if hijo is CollisionShape3D and (hijo as CollisionShape3D).shape != null:
			con_forma = true
	assert_bool(con_forma).is_true()


func test_las_dos_acciones_del_006_estan_declaradas_en_el_proyecto() -> void:  # 006-AC10
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
