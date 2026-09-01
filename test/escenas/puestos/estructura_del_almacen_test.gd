## El blockout del almacén, afirmado contra la escena que lo declara.
##
## Los dos primeros casos vivían en `almacen_test.gd` y se mudaron acá con su comentario: desde
## el spec 023 la geometría es su propia escena, y quien la declara es la que tiene que
## responder por ella. La de afuera la instancia y nada más.
##
## **ESTA SUITE INSTANCIA LA ESCENA Y NO LA ENTRA AL ÁRBOL, y es deliberado**, por lo mismo que
## `almacen_test.gd`: `instantiate()` alcanza para leer la jerarquía y las propiedades, mientras
## que `add_child()` haría correr los `_ready()` de todo lo que cuelgue. Y trae una consecuencia
## que el AC10 obliga a respetar: fuera del árbol `global_transform` aborta con
## `Condition "!is_inside_tree()" is true` y devuelve la identidad, así que acá se afirma el
## `transform` local. Como los diez cuerpos cuelgan directo de una raíz sin transform, el local
## es exactamente el número que detecta un rebase.
extends GdUnitTestSuite

const ESCENA_DE_LA_ESTRUCTURA := "res://src/escenas/puestos/estructura_del_almacen.tscn"

## Cinco es el piso, no el objetivo: piso, cuatro paredes —una partida en dos por el hueco de la
## ventanilla— y los dos anclajes. Menos que eso no es un cuarto cerrado.
const CUERPOS_MINIMOS := 5

## La tabla se copió de `almacen.tscn` **antes** de partirlo, porque después del corte ya no hay
## contra qué comparar. Es el modo de falla propio de sacar una rama a su propia escena: las
## transformadas se rebasan contra la raíz nueva y el cuarto queda corrido con todo lo demás en
## verde —los cuerpos están, las formas están, los nombres están—. La base es la identidad en los
## diez, así que la posición alcanza para reconstruir el `Transform3D` entero.
const POSICIONES := {
	"Piso": Vector3(0, -0.1, 0),
	"ParedNorte": Vector3(0, 1.5, -4),
	"ParedSur": Vector3(0, 1.5, 4),
	"ParedEste": Vector3(5, 1.5, 0),
	"ParedOesteIzquierda": Vector3(-5, 1.5, -2.5),
	"ParedOesteDerecha": Vector3(-5, 1.5, 2.5),
	"ParedOesteAntepecho": Vector3(-5, 0.6, 0),
	"ParedOesteDintel": Vector3(-5, 2.4, 0),
	"Estanteria": Vector3(3, 1, -3.4),
	"EscritorioDeLaComputadora": Vector3(-3, 0.4, 3.2),
}


func _estructura() -> Node3D:
	return auto_free(load(ESCENA_DE_LA_ESTRUCTURA).instantiate())


func test_la_estructura_carga_y_su_raiz_se_llama_estructura() -> void:
	# El nombre no es cosmético: `almacen.tscn` la instancia como `Estructura` y `almacen_test.gd`
	# navega con `has_node("Estructura/Estanteria")`. Renombrarla acá rompe allá.
	var estructura := _estructura()
	assert_object(estructura).is_instanceof(Node3D)
	assert_str(estructura.name).is_equal("Estructura")


func test_los_diez_cuerpos_del_blockout_estan_por_nombre() -> void:
	var estructura := _estructura()
	for nombre in POSICIONES:
		(
			assert_bool(estructura.has_node(NodePath(nombre)))
			. override_failure_message("`%s` no está en la estructura" % nombre)
			. is_true()
		)


func test_la_estructura_tiene_al_menos_cinco_cuerpos_estaticos() -> void:
	var cuerpos := 0
	for hijo in _estructura().get_children():
		if hijo is StaticBody3D:
			cuerpos += 1
	assert_int(cuerpos).is_greater_equal(CUERPOS_MINIMOS)


func test_ningun_cuerpo_de_la_estructura_quedo_sin_forma_de_colision() -> void:
	# Una pared sin forma es una pared que se atraviesa, y el síntoma —«me fui del almacén»— no
	# nombra al nodo que lo causó. Lo que este caso NO afirma es que `move_and_slide()` frene
	# contra ella: eso es comportamiento del motor, no una regla de este repo.
	for hijo in _estructura().get_children():
		if not hijo is StaticBody3D:
			continue
		var formas := 0
		for nieto in hijo.get_children():
			if nieto is CollisionShape3D and nieto.shape != null:
				formas += 1
		(
			assert_int(formas)
			. override_failure_message(
				"`%s` no tiene ningún CollisionShape3D con forma: se atraviesa" % hijo.name
			)
			. is_greater(0)
		)


func test_ningun_cuerpo_se_movio_al_salir_a_su_propia_escena() -> void:
	var estructura := _estructura()
	for nombre in POSICIONES:
		var cuerpo: Node3D = estructura.get_node(NodePath(nombre))
		var esperado := Transform3D(Basis.IDENTITY, POSICIONES[nombre])
		(
			assert_that(cuerpo.transform)
			. override_failure_message(
				(
					"`%s` está en %s y en `almacen.tscn` estaba en %s"
					% [nombre, cuerpo.transform, esperado]
				)
			)
			. is_equal(esperado)
		)
