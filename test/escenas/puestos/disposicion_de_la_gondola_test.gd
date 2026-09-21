## La disposición de la góndola: que el recurso medido del modelo alcance para lo que el puesto
## le pide.
##
## **No se cuentan copias ni se comparan posiciones**: eso cambia con cada arreglo del artista.
## Se afirma lo que el puesto supone sin mirar, y que si falla rompe la noche sin un error que
## nombre al recurso.
extends GdUnitTestSuite

const DISPOSICION := "res://src/escenas/puestos/disposicion_de_la_gondola.tres"
const GUIA := "res://src/escenas/puestos/guia_del_estante.tscn"


func _disposicion() -> DisposicionDeLaGondola:
	return load(DISPOSICION) as DisposicionDeLaGondola


## El puesto indexa `principales` por `Producto.Id`. Un producto sin bloque revienta al preparar.
func test_hay_un_bloque_principal_por_producto() -> void:
	assert_int(_disposicion().principales.size()).is_equal(Producto.Id.size())


## Las últimas `umbral` copias de cada bloque son las reponibles. Un bloque más chico deja la
## primera reponible en un índice negativo, y la marca cae en el origen del local.
func test_cada_bloque_principal_alcanza_para_el_cupo() -> void:
	var disposicion := _disposicion()
	for producto in Catalogo.todos():
		var copias := DisposicionDeLaGondola.copias(disposicion.principales[producto.id])
		assert_int(copias).override_failure_message(producto.nombre).is_greater_equal(
			producto.umbral
		)


## El puesto toma la malla de cada guía del hijo con el mismo índice. Si las cuentas difieren,
## una guía se dibuja con la malla de otra o el puesto indexa de más.
func test_hay_una_malla_por_bloque_de_guia() -> void:
	var guia: Node = auto_free((load(GUIA) as PackedScene).instantiate())
	assert_int(guia.get_child_count()).is_equal(_disposicion().guias.size())
