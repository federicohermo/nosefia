## Qué luminarias del almacén están encendidas.
##
## Es dominio y no escena porque la respuesta decide cuánto cuesta una tarea: un pasillo a oscuras
## encarece cualquiera que pase por ahí. Que se pueda ejercer sin levantar una escena es la prueba
## de que está del lado correcto de la frontera, y este archivo la paga.
extends GdUnitTestSuite

const ILUMINACION := "res://src/dominio/ambiente/iluminacion.gd"


func test_una_iluminacion_nueva_tiene_las_tres_encendidas() -> void:  # 048-AC3
	# El estado de arranque es el local abierto y con luz: apagar es lo que cuesta algo.
	assert_int(Iluminacion.new().encendidas()).is_equal(Iluminacion.LUMINARIAS)


func test_apagar_las_tres_deja_cero() -> void:  # 048-AC3
	var iluminacion := Iluminacion.new()
	for indice in Iluminacion.LUMINARIAS:
		iluminacion.apagar(indice)
	assert_int(iluminacion.encendidas()).is_zero()


func test_con_una_sola_encendida_devuelve_uno() -> void:  # 048-AC3
	var iluminacion := Iluminacion.new()
	iluminacion.apagar(0)
	iluminacion.apagar(2)
	assert_int(iluminacion.encendidas()).is_equal(1)
	assert_bool(iluminacion.esta_encendida(1)).is_true()


func test_apagar_dos_veces_la_misma_no_descuenta_dos() -> void:  # 048-AC3
	# El borde que rompe una implementación que lleva un contador en vez de un estado por
	# luminaria: restar uno por llamada deja el número en 1 y no en 2.
	var iluminacion := Iluminacion.new()
	iluminacion.apagar(0)
	iluminacion.apagar(0)
	assert_int(iluminacion.encendidas()).is_equal(Iluminacion.LUMINARIAS - 1)


func test_encender_lo_que_ya_estaba_encendido_no_suma() -> void:  # 048-AC3
	var iluminacion := Iluminacion.new()
	iluminacion.encender(1)
	assert_int(iluminacion.encendidas()).is_equal(Iluminacion.LUMINARIAS)


func test_un_indice_afuera_del_rango_no_cambia_nada() -> void:  # 048-AC3
	# Un índice inventado no puede apagar media sala en silencio: el dominio lo ignora y el
	# número queda donde estaba.
	var iluminacion := Iluminacion.new()
	iluminacion.apagar(Iluminacion.LUMINARIAS)
	iluminacion.apagar(-1)
	assert_int(iluminacion.encendidas()).is_equal(Iluminacion.LUMINARIAS)
	assert_bool(iluminacion.esta_encendida(-1)).is_false()


func test_el_dominio_no_nombra_ningun_nodo_del_motor() -> void:  # 048-AC3
	# La frontera, afirmada sobre el archivo: si esto necesita un `Node`, un `get_tree()` o un
	# `_process`, la regla está del lado equivocado y el arreglo es bajarla, no subir el recurso.
	var texto := FileAccess.get_file_as_string(ILUMINACION)
	for prohibido in ["Light3D", "get_tree()", "func _process", "Node3D"]:
		assert_str(texto).not_contains(prohibido)
