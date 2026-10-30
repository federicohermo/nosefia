## Las bandejas de la góndola siguen al mapa de la jornada: con el de prueba se ven las de prueba y
## no las del mapa completo que reemplazan, y con el completo al revés.
extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.gd")
const ESTRUCTURA := preload("res://src/escenas/puestos/estructura_del_almacen.tscn")


func _pares(estructura: Node) -> Array[Array]:
	var pares: Array[Array] = []
	var sufijo: String = ALMACEN.SUFIJO_DE_PRUEBA
	for prueba: Node3D in estructura.find_children("*" + sufijo, "Node3D", true, false):
		var completa := prueba.get_parent().get_node(String(prueba.name).trim_suffix(sufijo))
		pares.append([prueba, completa])
	return pares


func test_con_el_mapa_de_prueba_se_ven_sus_bandejas() -> void:
	var estructura: Node = auto_free(ESTRUCTURA.instantiate())
	ALMACEN.mostrar_las_bandejas(estructura, true)
	var pares := _pares(estructura)
	assert_bool(pares.is_empty()).is_false()
	for par in pares:
		assert_bool((par[0] as Node3D).visible).override_failure_message(str(par[0].name)).is_true()
		(
			assert_bool((par[1] as Node3D).visible)
			. override_failure_message(str(par[1].name))
			. is_false()
		)


func test_con_el_mapa_completo_se_ven_las_suyas() -> void:
	var estructura: Node = auto_free(ESTRUCTURA.instantiate())
	ALMACEN.mostrar_las_bandejas(estructura, true)
	ALMACEN.mostrar_las_bandejas(estructura, false)
	var pares := _pares(estructura)
	assert_bool(pares.is_empty()).is_false()
	for par in pares:
		(
			assert_bool((par[0] as Node3D).visible)
			. override_failure_message(str(par[0].name))
			. is_false()
		)
		assert_bool((par[1] as Node3D).visible).override_failure_message(str(par[1].name)).is_true()
