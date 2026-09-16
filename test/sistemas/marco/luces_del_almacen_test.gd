## El traductor entre el estado del dominio y las luces de la escena.
##
## Lo que se ejerce acá es que **traduzca y no decida**: el nodo no elige qué luminaria
## corresponde apagar, sólo copia lo que `Iluminacion` ya resolvió.
extends GdUnitTestSuite

const LUCES := "res://src/sistemas/marco/luces_del_almacen.gd"


func _montado(iluminacion: Iluminacion = Iluminacion.new()) -> LucesDelAlmacen:
	var nodo: LucesDelAlmacen = auto_free(LucesDelAlmacen.new())
	var tiras: Array[Node3D] = []
	for _indice in Iluminacion.LUMINARIAS:
		var tira: Node3D = auto_free(Node3D.new())
		tira.add_child(auto_free(SpotLight3D.new()))
		nodo.add_child(tira)
		tiras.append(tira)
	nodo.luminarias = tiras
	nodo.iluminacion = iluminacion
	nodo.aplicar()
	return nodo


func _invisibles(nodo: LucesDelAlmacen) -> Array[int]:
	var apagadas: Array[int] = []
	for indice in nodo.luminarias.size():
		if not nodo.luminarias[indice].visible:
			apagadas.append(indice)
	return apagadas


func test_con_las_tres_encendidas_ninguna_queda_invisible() -> void:  # 048-AC4
	assert_array(_invisibles(_montado())).is_empty()


func test_apaga_exactamente_la_que_el_dominio_declara_apagada() -> void:  # 048-AC4
	# El borde que importa: no alcanza con que la apagada quede invisible, tienen que quedar
	# visibles **las otras dos**. Un traductor que apaga de más pasa la primera mitad.
	var iluminacion := Iluminacion.new()
	iluminacion.apagar(1)
	assert_array(_invisibles(_montado(iluminacion))).is_equal([1])


func test_con_las_tres_apagadas_las_tres_quedan_invisibles() -> void:  # 048-AC4
	var iluminacion := Iluminacion.new()
	for indice in Iluminacion.LUMINARIAS:
		iluminacion.apagar(indice)
	assert_array(_invisibles(_montado(iluminacion))).is_equal([0, 1, 2])


func test_volver_a_encender_la_devuelve_a_visible() -> void:  # 048-AC4
	# Sin esto, un traductor que sólo sabe apagar pasa los tres casos de arriba.
	var iluminacion := Iluminacion.new()
	iluminacion.apagar(2)
	var nodo := _montado(iluminacion)
	iluminacion.encender(2)
	nodo.aplicar()
	assert_array(_invisibles(nodo)).is_empty()


func test_el_traductor_no_decide_nada_del_juego() -> void:  # 048-AC4
	# Traduce y no decide: si acá aparece una tarea, una jornada o un turno, la regla se subió
	# de capa y el arreglo es bajarla a `dominio/`.
	var texto := FileAccess.get_file_as_string(LUCES)
	for prohibido in ["Tarea", "Jornada", "Turno", "Consecuencia"]:
		assert_str(texto).not_contains(prohibido)
