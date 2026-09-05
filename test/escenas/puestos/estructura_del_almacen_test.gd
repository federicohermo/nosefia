## El escenario modelado del almacén, afirmado contra la escena que lo declara.
##
## Desde que `estructura_del_almacen.tscn` heredó de `SEPT_JUEGOS_PROTOTIPO.blend`, la geometría
## y la colisión las decide Blender y no este repo: los nombres y los sufijos `-col` viven en el
## .blend y re-exportarlo los propaga solo. Por eso esta suite ya no afirma dónde está cada
## pared —eso cambia cada vez que se edita el modelo, y afirmarlo sería un rojo por cada mueble
## que alguien mueve—, sino **las tres cosas que un re-export rompe sin avisar**: que una malla
## se quede sin su `-col`, que el edificio entre con la escala sin aplicar, y que los anclajes
## que los specs siguientes buscan por nombre desaparezcan al renombrar.
##
## **ESTA SUITE INSTANCIA LA ESCENA Y NO LA ENTRA AL ÁRBOL, y es deliberado**, por lo mismo que
## `almacen_test.gd`: `instantiate()` alcanza para leer la jerarquía y las propiedades, mientras
## que `add_child()` haría correr los `_ready()` de todo lo que cuelgue.
extends GdUnitTestSuite

const ESCENA_DE_LA_ESTRUCTURA := "res://src/escenas/puestos/estructura_del_almacen.tscn"

## La malla que trae la cáscara del edificio: paredes, piso y techo en una sola pieza. Sin su
## colisión el jugador no se cae al vacío, atraviesa las paredes y sale del almacén, y el
## síntoma —«me fui afuera»— no la nombra.
const CASCARA_DEL_EDIFICIO := "almacen"

## Los anclajes que los specs 008 y 009 buscan por nombre. Son nombres de objeto de Blender:
## renombrarlos allá es lo único que los pone acá.
const ANCLAJE_DE_LA_ESTANTERIA := "Estanteria"
const ANCLAJES := [ANCLAJE_DE_LA_ESTANTERIA, "EscritorioDeLaComputadora"]

## Desde qué costado se le tira el rayo al anclaje para ver contra qué choca. La estantería mide
## 1,82 m en X, así que 2,2 m arrancan afuera de ella y adentro del pasillo.
const DESDE_EL_COSTADO := 2.2

## El almacén mide 21.7 x 22.7 m de planta. La banda es ancha a propósito: no está para detectar
## que alguien movió una pared, sino que el modelo entró con la escala sin aplicar —el modo de
## falla real de un re-export, donde el edificio llega mil veces más chico y todo lo demás sigue
## en verde—.
const PLANTA_MINIMA_EN_METROS := 10.0
const PLANTA_MAXIMA_EN_METROS := 100.0


func _estructura() -> Node3D:
	return auto_free(load(ESCENA_DE_LA_ESTRUCTURA).instantiate())


## Las mallas del modelo, a cualquier profundidad: las del board de tareas cuelgan de otra malla
## y no de la raíz, así que una recorrida de un solo nivel las dejaría sin mirar.
static func _mallas(nodo: Node) -> Array[MeshInstance3D]:
	var encontradas: Array[MeshInstance3D] = []
	for hijo in nodo.get_children():
		if hijo is MeshInstance3D:
			encontradas.append(hijo)
		encontradas.append_array(_mallas(hijo))
	return encontradas


## Los nombres de las mallas que no tienen un `StaticBody3D` con forma colgando.
##
## Sale a una función en vez de afirmar adentro del caso porque es lo único que la vuelve
## ejercible: una recorrida que sólo pasa por un modelo que ya cumple pasaría igual si no mirara
## nada, y el caso siguiente le pasa un árbol que sí la viola.
static func _mallas_sin_colision(raiz: Node) -> Array[String]:
	var sin_colision: Array[String] = []
	for malla in _mallas(raiz):
		if not _tiene_forma(malla):
			sin_colision.append(malla.name)
	return sin_colision


static func _tiene_forma(malla: MeshInstance3D) -> bool:
	for hijo in malla.get_children():
		if not hijo is StaticBody3D:
			continue
		for nieto in hijo.get_children():
			if nieto is CollisionShape3D and nieto.shape != null:
				return true
	return false


func test_la_estructura_carga_y_su_raiz_se_llama_estructura() -> void:
	# El nombre no es cosmético: `almacen.tscn` la instancia como `Estructura` y `almacen_test.gd`
	# navega con `has_node("Estructura/Estanteria")`. Renombrarla acá rompe allá.
	var estructura := _estructura()
	assert_object(estructura).is_instanceof(Node3D)
	assert_str(estructura.name).is_equal("Estructura")


func test_el_modelo_entro_con_sus_mallas() -> void:
	# Un import que falla no siempre da error: da una escena vacía, y todos los casos que
	# recorren mallas pasan por vacuidad. Éste es el que no deja que eso se lea como verde.
	assert_array(_mallas(_estructura())).is_not_empty()


func test_ninguna_malla_del_modelo_quedo_sin_colision() -> void:
	# Éste es EL caso de la suite. La colisión la genera el sufijo `-col` del nombre en Blender,
	# así que se pierde por olvidarlo al renombrar un objeto —ya pasó una vez—, y el síntoma en
	# el juego es atravesar una góndola: no nombra ni al objeto ni al sufijo.
	var sin_colision := _mallas_sin_colision(_estructura())
	(
		assert_array(sin_colision)
		. override_failure_message(
			(
				"estas mallas del .blend no tienen colisión, les falta el sufijo `-col`: %s"
				% ", ".join(sin_colision)
			)
		)
		. is_empty()
	)


func test_la_regla_del_sufijo_sabe_ver_una_malla_sin_colision() -> void:
	# El caso de arriba recorre un modelo que ya cumple, así que pasaría igual con una recorrida
	# rota. Éste le arma el defecto —una malla suelta, sin `StaticBody3D`— y afirma que la nombra.
	var raiz: Node3D = auto_free(Node3D.new())
	var malla := MeshInstance3D.new()
	malla.name = "gondola_sin_col"
	raiz.add_child(malla)
	assert_array(_mallas_sin_colision(raiz)).contains_exactly(["gondola_sin_col"])


func test_la_cascara_del_edificio_esta_y_frena_al_jugador() -> void:
	var estructura := _estructura()
	(
		assert_bool(estructura.has_node(NodePath(CASCARA_DEL_EDIFICIO)))
		. override_failure_message(
			"`%s` no está: el modelo entró sin la cáscara del edificio" % CASCARA_DEL_EDIFICIO
		)
		. is_true()
	)
	var cascara: MeshInstance3D = estructura.get_node(NodePath(CASCARA_DEL_EDIFICIO))
	(
		assert_bool(_tiene_forma(cascara))
		. override_failure_message(
			"`%s` no tiene colisión: las paredes se atraviesan" % CASCARA_DEL_EDIFICIO
		)
		. is_true()
	)


func test_el_edificio_no_vino_con_la_escala_rota() -> void:
	var cascara: MeshInstance3D = _estructura().get_node(NodePath(CASCARA_DEL_EDIFICIO))
	var planta := cascara.get_aabb().size * cascara.scale
	for lado in [planta.x, planta.z]:
		(
			assert_float(lado)
			. override_failure_message(
				(
					"la planta del almacén mide %s x %s m y eso no es un edificio"
					% [planta.x, planta.z]
				)
			)
			. is_between(PLANTA_MINIMA_EN_METROS, PLANTA_MAXIMA_EN_METROS)
		)


func test_los_anclajes_que_buscan_los_specs_siguientes_estan_por_nombre() -> void:
	# Se buscan por nombre y no por posición para que mover un mueble no rompa nada de lo que
	# viene después. Son anclajes de transform, NO muebles definitivos: el 008 reemplaza
	# `Estanteria` por su `estante.tscn` y el 009 `EscritorioDeLaComputadora` por su
	# `escritorio.tscn`, y este caso deja de aplicar en cuanto lo hagan.
	var estructura := _estructura()
	for anclaje in ANCLAJES:
		(
			assert_bool(estructura.has_node(NodePath(anclaje)))
			. override_failure_message(
				"`%s` no está en el modelo: falta renombrar su objeto en Blender" % anclaje
			)
			. is_true()
		)


func test_el_colisionador_de_un_anclaje_cuelga_del_nodo_que_lo_nombra() -> void:
	# Con el blockout el `StaticBody3D` **era** el nodo llamado `Estanteria`. Con el modelo el
	# import le cuelga uno anónimo debajo, así que `get_collider().name` dejó de servir para saber
	# qué mueble se está mirando. De esa forma dependen los specs 006, 008 y 009, y hasta acá no la
	# afirmaba nadie: se iban a enterar de golpe.
	#
	# **Éste es el único caso de la suite que entra la escena al árbol**, y es porque sin `World3D`
	# no hay espacio físico contra el que tirar un rayo. La escena no tiene un solo script
	# colgando, así que su `_ready()` no corre código que esta suite no escribió.
	var estructura := _estructura()
	add_child(estructura)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var anclaje: Node3D = estructura.get_node(NodePath(ANCLAJE_DE_LA_ESTANTERIA))
	var golpe := estructura.get_world_3d().direct_space_state.intersect_ray(
		PhysicsRayQueryParameters3D.create(
			anclaje.global_position + Vector3(DESDE_EL_COSTADO, 0.5, 0), anclaje.global_position
		)
	)
	(
		assert_dict(golpe)
		. override_failure_message(
			(
				"el rayo contra `%s` no chocó con nada: el anclaje no tiene colisión"
				% ANCLAJE_DE_LA_ESTANTERIA
			)
		)
		. is_not_empty()
	)
	var colisionador: Node = golpe["collider"]
	assert_object(colisionador).is_instanceof(StaticBody3D)
	(
		assert_str(colisionador.get_parent().name)
		. override_failure_message(
			(
				"el rayo contra `%s` devolvió un cuerpo colgado de `%s`"
				% [ANCLAJE_DE_LA_ESTANTERIA, colisionador.get_parent().name]
			)
		)
		. is_equal(ANCLAJE_DE_LA_ESTANTERIA)
	)
