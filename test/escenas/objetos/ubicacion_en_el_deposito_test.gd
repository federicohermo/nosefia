## Dónde arranca la noche cada cosa suelta: las cajas de reposición en el depósito y las bolsas
## de basura en el baño.
##
## Las dos habitaciones las abre el 043, y antes de él no se podía poner nada adentro: la puerta
## las dejaba inalcanzables.
extends GdUnitTestSuite

const ALMACEN := preload("res://src/escenas/almacen.tscn")

## Media caja, en metros. Es lo que separa el centro de una caja apoyada de la superficie que la
## sostiene, y sale del `0.3037077` de escala que el `.tscn` de la caja le pone a un cubo de dos.
const MEDIA_CAJA := 0.3037

## La caja del piso del baño, de `estructura_del_almacen.tscn`. El nombre de esa forma dice
## `Deposito` y nombra el baño: los dos cuartos están cambiados en el modelo, y renombrarlos es
## de otro spec.
const CENTRO_DEL_BANO := Vector3(10.86326, 0, -4.5818585)
const TAMANO_DEL_BANO := Vector3(5.1428, 0.206508, 6.608355)


func test_las_ocho_cajas_de_reposicion_estan_apoyadas_en_el_deposito() -> void:  # 043-AC10
	# Entran seis en los estantes y dos en el piso: entre estantes hay 0,477 m y la caja mide
	# 0,607, así que sólo el estante de arriba tiene aire. Lo que el caso afirma no es el reparto
	# sino que ninguna quede flotando ni clavada adentro de otra cosa.
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	await get_tree().physics_frame
	var espacio := almacen.get_world_3d().direct_space_state
	var cajas: Array = almacen.get("_cajas_de_productos")
	assert_int(cajas.size()).is_equal(Catalogo.todos().size())
	for caja: Node3D in cajas:
		var cuerpo := caja as StaticBody3D
		var consulta := PhysicsRayQueryParameters3D.create(
			cuerpo.global_position, cuerpo.global_position + Vector3.DOWN
		)
		consulta.exclude = [cuerpo.get_rid()]
		var golpe := espacio.intersect_ray(consulta)
		(
			assert_bool(golpe.has("position"))
			. override_failure_message("`%s` no se apoya en nada" % caja.name)
			. is_true()
		)
		var hueco: float = cuerpo.global_position.y - (golpe["position"] as Vector3).y
		(
			assert_float(hueco)
			. override_failure_message(
				(
					"`%s` está a %.4f m de su apoyo y media caja es %.4f"
					% [caja.name, hueco, MEDIA_CAJA]
				)
			)
			. is_equal_approx(MEDIA_CAJA, 0.001)
		)
		var apoyo: String = str(almacen.get_path_to(golpe["collider"]))
		(
			assert_bool(apoyo.contains("gondola_deposito") or apoyo.contains("Suelo"))
			. override_failure_message("`%s` se apoya en `%s`" % [caja.name, apoyo])
			. is_true()
		)
		assert_array(_lo_que_pisa(almacen, cuerpo, apoyo)).is_empty()


func test_las_tres_bolsas_arrancan_en_el_bano_y_lejos_del_descarte() -> void:  # 043-AC11
	# El baño es el otro cuarto que el 043 abre. Las bolsas estaban desparramadas por el local y
	# el pedido fue juntarlas ahí; el descarte sigue en el fondo, así que el viaje no se acorta.
	var almacen: Node3D = auto_free(ALMACEN.instantiate())
	add_child(almacen)
	await get_tree().physics_frame
	var descarte: Node3D = almacen.get_node("Objetos/ZonaDeDescarte")
	var bolsas: Array = almacen.get("_bolsas")
	assert_int(bolsas.size()).is_equal(ReglasDeLaBasura.BOLSAS_DE_LA_JORNADA)
	var piso := AABB(CENTRO_DEL_BANO - TAMANO_DEL_BANO / 2.0, TAMANO_DEL_BANO)
	for bolsa: Node3D in bolsas:
		var lugar := bolsa.global_position
		(
			assert_bool(piso.has_point(Vector3(lugar.x, CENTRO_DEL_BANO.y, lugar.z)))
			. override_failure_message("`%s` arranca en %v, fuera del baño" % [bolsa.name, lugar])
			. is_true()
		)
		var distancia := lugar.distance_to(descarte.global_position)
		(
			assert_float(distancia)
			. override_failure_message("`%s` está a %.2f m del descarte" % [bolsa.name, distancia])
			. is_greater(ReglasDeLaBasura.DISTANCIA_MINIMA_AL_DESCARTE)
		)


## Con qué se superpone un cuerpo, sin contar aquello sobre lo que se apoya.
func _lo_que_pisa(almacen: Node3D, cuerpo: StaticBody3D, apoyo: String) -> Array[String]:
	var forma := BoxShape3D.new()
	forma.size = Vector3.ONE * (MEDIA_CAJA * 2.0 - 0.01)
	var consulta := PhysicsShapeQueryParameters3D.new()
	consulta.shape = forma
	consulta.transform = Transform3D(Basis(), cuerpo.global_position)
	consulta.exclude = [cuerpo.get_rid()]
	var pisados: Array[String] = []
	for choque in almacen.get_world_3d().direct_space_state.intersect_shape(consulta, 8):
		var quien: String = str(almacen.get_path_to(choque["collider"]))
		if quien != apoyo:
			pisados.append("%s pisa %s" % [cuerpo.name, quien])
	return pisados
