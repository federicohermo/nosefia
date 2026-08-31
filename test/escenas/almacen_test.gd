## La estructura del blockout del almacén.
##
## No dice «se ve bien»: dice que los anclajes que los specs 006, 007, 008 y 009 van a buscar
## por nombre están, y que ninguna pared quedó sin forma de colisión — que es el modo de falla
## del blockout que un test sí puede cazar.
##
## **ESTA SUITE INSTANCIA LA ESCENA Y NO LA ENTRA AL ÁRBOL, y es deliberado.** `instantiate()`
## alcanza para leer la jerarquía y las propiedades —medido en headless—, mientras que
## `add_child()` haría correr los `_ready()` de todo lo que cuelgue de la escena. Hoy eso sería
## el `_ready()` del jugador; en cuanto el spec 007 le cuelgue un script a la raíz y un nodo con
## el reloj del turno, sería también código que esta suite no escribió. Un test que entra la
## escena al árbol le hereda al 007 un rojo que no es suyo; uno que la instancia y nada más
## queda estable. **Si algún día hace falta entrarla, es una decisión que se toma a propósito y
## se escribe acá.**
extends GdUnitTestSuite

const ESCENA_DEL_ALMACEN := "res://src/escenas/almacen.tscn"

## Cinco es el piso, no el objetivo: piso, cuatro paredes —una partida en dos por el hueco de la
## ventanilla— y los dos anclajes. Menos que eso no es un cuarto cerrado.
const CUERPOS_MINIMOS := 5


func _almacen() -> Node3D:
	return auto_free(load(ESCENA_DEL_ALMACEN).instantiate())


func test_el_almacen_carga_y_su_raiz_es_un_nodo_tridimensional() -> void:
	assert_object(_almacen()).is_instanceof(Node3D)


func test_la_estructura_tiene_al_menos_cinco_cuerpos_estaticos() -> void:
	var estructura: Node = _almacen().get_node("Estructura")
	var cuerpos := 0
	for hijo in estructura.get_children():
		if hijo is StaticBody3D:
			cuerpos += 1
	assert_int(cuerpos).is_greater_equal(CUERPOS_MINIMOS)


func test_ningun_cuerpo_de_la_estructura_quedo_sin_forma_de_colision() -> void:
	# Una pared sin forma es una pared que se atraviesa, y el síntoma —«me fui del almacén»— no
	# nombra al nodo que lo causó. Lo que este caso NO afirma es que `move_and_slide()` frene
	# contra ella: eso es comportamiento del motor, no una regla de este repo.
	var estructura: Node = _almacen().get_node("Estructura")
	for hijo in estructura.get_children():
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


func test_los_tres_anclajes_que_buscan_los_specs_siguientes_estan_por_nombre() -> void:
	# Se buscan por nombre y no por posición para que mover una caja no rompa nada de lo que
	# viene después. Los tres son anclajes de transform, NO muebles definitivos: el 008 reemplaza
	# `Estanteria` por su `estante.tscn` y el 009 `EscritorioDeLaComputadora` por su
	# `escritorio.tscn`, y este caso deja de aplicar en cuanto lo hagan.
	var almacen := _almacen()
	assert_bool(almacen.has_node("Estructura/Estanteria")).is_true()
	assert_bool(almacen.has_node("Estructura/EscritorioDeLaComputadora")).is_true()
	assert_bool(almacen.has_node("HuecoDeLaVentanilla")).is_true()


func test_el_proyecto_abre_el_almacen_al_correr() -> void:
	# Sin esto, correr el proyecto no abre nada y el síntoma es una ventana vacía que no nombra
	# a `project.godot`.
	assert_str(ProjectSettings.get_setting("application/run/main_scene")).is_equal(
		ESCENA_DEL_ALMACEN
	)


func test_el_almacen_instancia_al_jugador_en_vez_de_duplicar_el_cuerpo() -> void:
	assert_bool(_almacen().has_node("Jugador")).is_true()


func test_la_escena_trae_luz_propia() -> void:
	# El renderer es `forward_plus`: una escena sin luces sale NEGRA, y el síntoma no nombra la
	# causa. Por eso el entorno y el sol se afirman por nombre y por tipo en vez de dejarlos
	# librados a que alguien mire la escena.
	var almacen := _almacen()
	assert_bool(almacen.has_node("Entorno")).is_true()
	var entorno: Node = almacen.get_node("Entorno")
	assert_object(entorno).is_instanceof(WorldEnvironment)
	assert_object(entorno.environment).is_not_null()
	assert_bool(almacen.has_node("Sol")).is_true()
	assert_object(almacen.get_node("Sol")).is_instanceof(DirectionalLight3D)
